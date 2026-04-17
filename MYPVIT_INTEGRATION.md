# MyPvit - Documentation d'integration complete

**Derniere mise a jour** : 2026-04-16
**Version** : 2.0 (apres migration vers nouveau compte MyPvit + Supabase)

---

## Table des matieres

1. [Vue d'ensemble](#1-vue-densemble)
2. [Architecture](#2-architecture)
3. [Configuration](#3-configuration)
4. [Flux de paiement detaille](#4-flux-de-paiement-detaille)
5. [Endpoints API MyPvit utilises](#5-endpoints-api-mypvit-utilises)
6. [Webhooks](#6-webhooks)
7. [Securite](#7-securite)
8. [Base de donnees](#8-base-de-donnees)
9. [Gestion des erreurs](#9-gestion-des-erreurs)
10. [Procedure de tests](#10-procedure-de-tests)
11. [Depannage](#11-depannage)
12. [Reference des fichiers](#12-reference-des-fichiers)

---

## 1. Vue d'ensemble

LotoTrading utilise **MyPvit** comme agregateur de paiement Mobile Money pour le Gabon. Les clients peuvent payer leurs tickets de loterie via :
- **Airtel Money** (compte `ACC_69D7B82555A85`)
- **Moov Money** (compte `ACC_69CE613678748`)

Le flux est **asynchrone** : le client declenche un paiement, recoit un USSD push sur son telephone, confirme avec son code PIN, et le systeme est notifie via webhook + polling.

### Caracteristiques cles

- Rotation automatique du secret d'authentification (TTL 50 minutes)
- Verification webhook par token partage (anti-spoofing)
- Double verification : webhook + polling client (fallback)
- Protection contre les race conditions via locks DB
- Gestion automatique des paiements expires (>30 minutes)
- Support **deux comptes marchands** : un pour Airtel, un pour Moov

---

## 2. Architecture

### Vue d'ensemble du flux

```
┌─────────────┐       ┌──────────────┐       ┌─────────────┐       ┌──────────┐
│ App Mobile  │──1───▶│ Backend API  │──2───▶│  MyPvit API │──3───▶│ Operator │
│  (Flutter)  │       │   (Laravel)  │       │             │       │ (Airtel) │
└─────────────┘       └──────────────┘       └─────────────┘       └──────────┘
       ▲                     ▲                      │                    │
       │                     │                      │                    │
       │                     │                      │                    ▼
       │              ┌──────┴──────┐               │              ┌──────────┐
       └────5─────────│  Supabase   │◀──────4───────┘              │  Client  │
                      │ PostgreSQL  │   (Webhook)                   │ (USSD)   │
                      └─────────────┘                               └──────────┘

1. Client soumet paiement (lottery + selection + phone + operator)
2. Backend initie paiement via MyPvit API
3. MyPvit envoie USSD push au telephone du client
4. MyPvit notifie backend via webhook (status SUCCESS/FAILED)
5. App mobile poll toutes les 5s + backend met a jour DB
```

### Composants

| Composant | Role | Fichier |
|---|---|---|
| `MyPvitService` | Client HTTP vers l'API MyPvit (initiation, status, KYC) | [MyPvitService.php](../backend-api/app/Services/MyPvitService.php) |
| `PaymentController` | Endpoints clients pour initier/checker les paiements | [PaymentController.php](../backend-api/app/Http/Controllers/Client/PaymentController.php) |
| `MyPvitWebhookController` | Reception des callbacks MyPvit (paiement + secret) | [MyPvitWebhookController.php](../backend-api/app/Http/Controllers/Webhook/MyPvitWebhookController.php) |
| `PaymentScreen` (Flutter) | UI de paiement + polling | [payment_screen.dart](../mobile-app/lib/presentation/screens/payment/payment_screen.dart) |

---

## 3. Configuration

### Variables d'environnement (.env serveur)

```env
# Comptes marchands par operateur
MYPVIT_ACCOUNT_CODE=ACC_69CE613678748          # Moov Money
MYPVIT_ACCOUNT_CODE_AIRTEL=ACC_69D7B82555A85   # Airtel Money
MYPVIT_PASSWORD=S@rdines88

# URLs webhook (codes configures dans le dashboard MyPvit)
MYPVIT_CALLBACK_CODE=XD8IK      # Reception des status de paiement
MYPVIT_RECEPTION_CODE=CUCKK     # Reception du secret d'authentification

# Codes endpoints API (valeurs par defaut dans config/services.php)
MYPVIT_RENEW_SECRET_CODE=PKA2U6B1JXJXBE5Z
MYPVIT_REST_CODE=0L7YQTRV8FRSYBCO
MYPVIT_STATUS_CODE=NB5ERMR2YUMJCRKO
MYPVIT_FEES_CODE=AXXPGF2ZXN3CDLGQ
MYPVIT_OPERATORS_CODE=E9QJIV5ZOYGZWF9A
MYPVIT_KYC_CODE=08NADA9GV5C9XFYH

# Token anti-spoofing pour le webhook (genere aleatoirement)
MYPVIT_WEBHOOK_TOKEN=69ae274f73bbcb30c895eeb06d77eb6660bb7d688feb3141d29316e3bae367fa
```

### URLs a configurer dans le dashboard MyPvit

Connecte-toi au dashboard MyPvit, section **URLs de callback** :

| Code | Type | URL |
|---|---|---|
| `XD8IK` | CALLBACK (statuts de paiement) | `https://loto-trading.project-preview.ovh/api/webhooks/mypvit?token=69ae274f73bbcb30c895eeb06d77eb6660bb7d688feb3141d29316e3bae367fa` |
| `CUCKK` | RECEPTION DE CLE SECRETE | `https://loto-trading.project-preview.ovh/api/webhooks/mypvit` |

**Important** : Le token en query param dans l'URL du CALLBACK permet la verification du webhook sans modifier les headers (MyPvit ne supporte pas les headers custom).

---

## 4. Flux de paiement detaille

### Etape 1 : Client initie le paiement

**Requete client** :
```http
POST /api/client/payments/mobile-money/create
Authorization: Bearer {client_token}
Content-Type: application/json

{
  "lottery_id": 1,
  "selections": [
    {"main_numbers": [5, 12, 23, 34, 45], "bonus_numbers": [3, 7]}
  ],
  "phone_number": "077000001",
  "operator": "AIRTEL_MONEY"
}
```

**Actions backend** :
1. Validation de la loterie et du cutoff de tirage
2. Annulation des paiements `pending` vieux de plus de 30 minutes
3. Verification KYC non-bloquante via `MyPvitService::verifyKyc()`
4. Initiation du paiement via `MyPvitService::initiatePayment()`
5. Creation d'un enregistrement `Payment` avec status `pending`

**Reponse** :
```json
{
  "payment_id": 48,
  "transaction_id": "LT-2-1774724664",
  "amount": 500,
  "currency": "XAF",
  "message": "Confirmez le paiement sur votre telephone."
}
```

### Etape 2 : MyPvit envoie USSD push au client

Le client recoit sur son telephone une demande de confirmation :
```
Confirmez le paiement de 500 FCFA a LOTOTRADING
Entrez votre code PIN Airtel Money : ____
```

### Etape 3 : Client confirme sur le telephone

Deux choses se passent en parallele :

**3a. Webhook MyPvit (serveur a serveur)** :
```http
POST https://loto-trading.project-preview.ovh/api/webhooks/mypvit?token=69ae274f...
Content-Type: application/json

{
  "transactionId": "PAY270326948181",
  "merchantReferenceId": "LT41774642448",
  "status": "SUCCESS",
  "amount": 500,
  "operator": "AIRTEL_MONEY",
  "code": 200
}
```

Le backend :
1. Verifie le token du webhook (hash_equals)
2. Trouve le paiement correspondant (par `transactionId` ou reference)
3. Lock la ligne en DB (`lockForUpdate()`)
4. Update `payment_status = 'completed'`
5. Cree le `TicketRequest` via `TicketService::createRequest()`
6. Envoie une notification push OneSignal au client

**3b. Polling client (toutes les 5 secondes)** :
```http
POST /api/client/payments/mobile-money/check
{
  "payment_id": 48
}
```

Reponses possibles :
- Si `completed` : retourne le ticket cree
- Si `failed`/`expired` : retourne l'erreur
- Si `pending` : appelle `MyPvitService::checkStatus()` en fallback (au cas ou le webhook ne serait pas arrive)

### Etape 4 : Mise a jour de l'app mobile

L'app mobile detecte le status `completed` dans le polling, redirige vers `/tickets` et affiche un toast de succes.

---

## 5. Endpoints API MyPvit utilises

Base URL : `https://api.mypvit.pro`

### 5.1 Renouvellement du secret (authentification)

**Usage** : Recuperer un token de session avant chaque appel

```http
POST /PKA2U6B1JXJXBE5Z/renew-secret
Content-Type: application/x-www-form-urlencoded

operationAccountCode=ACC_69CE613678748
password=S@rdines88
receptionUrlCode=CUCKK
```

**Reponse** : Le secret est envoye de facon **asynchrone** au webhook `CUCKK`, pas dans la reponse HTTP immediate.

Le backend attend jusqu'a 15 secondes que le webhook cache le secret.

### 5.2 Initiation de paiement

```http
POST /v2/0L7YQTRV8FRSYBCO/rest
X-Secret: {secret_recu_via_webhook}
Content-Type: application/json

{
  "agent": "LOTOTRADINGAPP",
  "amount": 500,
  "reference": "LT21774724664",
  "service": "RESTFUL",
  "callback_url_code": "XD8IK",
  "customer_account_number": "077000001",
  "merchant_operation_account_code": "ACC_69D7B82555A85",  // Airtel
  "transaction_type": "PAYMENT",
  "operator_code": "AIRTEL_MONEY",
  "owner_charge": "CUSTOMER",
  "owner_charge_operator": "CUSTOMER",
  "free_info": "LotoTrading",
  "product": "TICKET LOTO"
}
```

**Reponse succes** :
```json
{
  "status": "PENDING",
  "status_code": "200",
  "reference_id": "PAY280326956814",
  "merchant_reference_id": "LT21774724664",
  "merchant_operation_account_code": "ACC_69D7B82555A85",
  "operator": "AIRTEL_MONEY",
  "message": "Votre demande de paiement LT21774724664 a ete initiee avec succes..."
}
```

### 5.3 Verification de statut

```http
GET /NB5ERMR2YUMJCRKO/status?transactionId=LT21774724664&accountOperationCode=ACC_69D7B82555A85&transactionOperation=PAYMENT
X-Secret: {secret}
```

**Reponses possibles** :
- `{"status": "SUCCESS", ...}` : Paiement confirme
- `{"status": "FAILED", ...}` : Paiement refuse
- `{"status": "PENDING", ...}` : Toujours en attente

### 5.4 Verification KYC

```http
GET /v2/08NADA9GV5C9XFYH/kyc?customerAccountNumber=077000001&operatorCode=AIRTEL_MONEY
X-Secret: {secret}
```

**Usage** : Pre-verification du client avant paiement (non-bloquante actuellement).

### 5.5 Liste des operateurs

```http
GET /v2/E9QJIV5ZOYGZWF9A/get-operators?countryCode=GA
X-Secret: {secret}
```

### 5.6 Calcul des frais

```http
GET /v2/AXXPGF2ZXN3CDLGQ/get-fees?amount=500&transactionType=PAYMENT&operator=AIRTEL_MONEY
X-Secret: {secret}
```

---

## 6. Webhooks

### 6.1 Webhook de reception du secret (`CUCKK`)

**URL configuree** : `https://loto-trading.project-preview.ovh/api/webhooks/mypvit`
**Declenche par** : Appel a `/renew-secret`

**Payload possibles** (MyPvit varie selon la version) :
```json
{"secret": "<REDACTED>"}
{"secretKey": "..."}
{"secret_key": "..."}
{"key": "..."}
```

Ou parfois un body brut (string) sans JSON.

**Comportement** :
- Detection du secret **AVANT** la verification du token (le secret doit passer sans token)
- Cache pour 3000 secondes (50 minutes)
- Ce webhook ne requiert pas le token anti-spoofing (le secret lui-meme est une info sensible, mais le flux est declenche par notre backend)

### 6.2 Webhook de statut de paiement (`XD8IK`)

**URL configuree** : `https://loto-trading.project-preview.ovh/api/webhooks/mypvit?token=...`
**Declenche par** : Confirmation/echec d'un paiement par le client

**Payload** :
```json
{
  "transactionId": "PAY280326956814",
  "merchantReferenceId": "LT21774724664",
  "status": "SUCCESS",
  "amount": 500,
  "operator": "AIRTEL_MONEY",
  "code": 200
}
```

**Reponse attendue par MyPvit** :
```json
{
  "responseCode": 200,
  "transactionId": "PAY280326956814"
}
```

**Logique** :
1. Verifie le token (`hash_equals()` timing-safe)
2. Recherche le paiement par `transactionId` OU `merchantReferenceId`
3. Gere la normalisation de la reference (MyPvit retire les tirets : `LT-2-1774724664` devient `LT21774724664`)
4. Sur SUCCESS : lock DB + marque `completed` + cree le ticket + push notification
5. Sur FAILED : marque `failed`

---

## 7. Securite

### 7.1 Secret d'authentification MyPvit

- **Rotation automatique** : nouveau secret demande si cache expire ou si reponse 401/403
- **Stockage** : cache Laravel (Redis/DB) avec TTL 3000s
- **Non-persiste** en DB (jamais dans `.env`)
- **Retries** : 2 tentatives avec backoff 1 seconde

### 7.2 Token webhook anti-spoofing

- **Genere** aleatoirement (`openssl rand -hex 32`)
- **Verification** : `hash_equals()` pour eviter les timing attacks
- **Accepte via** :
  - Header `X-Webhook-Token`
  - Header `Authorization: Bearer <token>`
  - Query param `?token=<token>` (utilise actuellement car MyPvit ne supporte pas les headers custom)
- **Deploiement progressif** : si `MYPVIT_WEBHOOK_TOKEN` n'est pas defini, les webhooks passent avec warning log (backwards compat)

### 7.3 Protection contre les race conditions

Scenarios geres :
- Webhook arrive avant le polling : lock DB previent le double-processing
- Polling detecte SUCCESS avant le webhook : meme chose
- Webhook rejoue : idempotent (statut deja `completed`)

Code utilise `Payment::lockForUpdate()` dans une transaction.

### 7.4 Gestion des paiements expires

Un cron job marque les paiements `pending` vieux de plus de 30 minutes en `expired` :
```php
Payment::where('payment_status', 'pending')
    ->where('created_at', '<', now()->subMinutes(30))
    ->update(['payment_status' => 'expired']);
```

Commande artisan : `php artisan payments:clean-expired`

---

## 8. Base de donnees

### Table `lototrading_payments`

```sql
CREATE TABLE lototrading_payments (
  id BIGINT PRIMARY KEY,
  client_id BIGINT NOT NULL,
  ticket_request_id BIGINT NULL,
  amount NUMERIC(10,2) NOT NULL,
  currency VARCHAR(3) DEFAULT 'XAF',
  payment_method VARCHAR(20) NOT NULL,  -- 'airtel_money', 'moov_money', 'paypal'
  payment_status VARCHAR(20) DEFAULT 'pending',
  transaction_id VARCHAR(255) NULL,     -- Reference du paiement (ex: "LT-2-1774724664")
  paypal_order_id VARCHAR(255) NULL,
  metadata JSONB NULL,
  needs_review BOOLEAN DEFAULT FALSE,   -- Flag pour revision manuelle
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);
```

### Valeurs de `payment_status`

| Status | Description |
|---|---|
| `pending` | Paiement initie, en attente de confirmation du client |
| `completed` | Client a confirme, paiement reussi, ticket cree |
| `failed` | Client a refuse ou echec technique |
| `expired` | Pending depuis plus de 30 minutes, annule automatiquement |
| `refunded` | Reserve pour les remboursements (non utilise en Mobile Money) |

### Structure du `metadata` (JSONB)

```json
{
  "operator": "AIRTEL_MONEY",
  "play_date": "2026-03-28",
  "reference": "LT-4-1774642448",
  "lottery_id": 2,
  "selections": [
    {"main_numbers": [1, 2, 3, 4, 5], "bonus_numbers": [1]}
  ],
  "grids_count": 1,
  "phone_number": "077000001",
  "price_per_grid": 500,
  "mypvit_response": {
    "status": "PENDING",
    "message": "...",
    "reference_id": "PAY270326948181",
    "merchant_reference_id": "LT41774642448"
  }
}
```

### Transitions d'etat

```
                ┌──── (webhook SUCCESS) ──▶ completed
pending ────────┼──── (webhook FAILED)  ──▶ failed
                └──── (> 30 min)         ──▶ expired
```

---

## 9. Gestion des erreurs

### 9.1 Cote MyPvitService

| Erreur | Comportement |
|---|---|
| Secret expire (401/403) | Invalide le cache, re-fetch le secret, retry 1 fois |
| Timeout webhook secret | `RuntimeException` apres 2 tentatives + 15s d'attente chacune |
| Echec renew-secret | Log error + throw exception |
| Echec initiatePayment | Log error + throw exception |

### 9.2 Cote PaymentController

| Scenario | Response HTTP |
|---|---|
| Loterie inactive ou introuvable | 422 `"Ce loto n'est pas disponible."` |
| Cutoff depasse | 422 avec info sur le prochain tirage |
| Operateur invalide | 422 validation error |
| Echec MyPvit | 500 `"Erreur lors du paiement. Veuillez reessayer."` |
| Paiement cree + ticket OK | 200 avec `payment_id` |
| Paiement OK mais ticket KO | 201 + `needs_review = true` |

### 9.3 Cote Webhook

- Token invalide : 403 (sauf si `MYPVIT_WEBHOOK_TOKEN` vide)
- Paiement introuvable : 200 silent
- Creation de ticket echoue : 200 mais `needs_review = true`

### 9.4 Logs importants

```
[INFO]    MyPVit renew-secret attempt 1
[INFO]    MyPVit secret received after 2.5s
[INFO]    MyPVit initiatePayment {amount, phone: "077****", operator, reference}
[WARNING] MyPVit payment rejected (secret expired?)
[WARNING] MyPVit webhook token verification failed {ip}
[ERROR]   MyPVit secret not received within timeout
[ERROR]   MyPVit webhook ticket creation failed {payment_id, error}
```

Verifier avec :
```bash
tail -100 storage/logs/laravel.log | grep -i mypvit
```

---

## 10. Procedure de tests

### 10.1 Pre-requis

- [ ] `.env` configure avec toutes les variables `MYPVIT_*`
- [ ] Webhook URLs configurees dans le dashboard MyPvit
- [ ] Un client avec KYC approuve dans la DB
- [ ] Un solde Airtel/Moov test disponible sur le numero utilise
- [ ] `php artisan config:clear` execute apres toute modif du `.env`

### 10.2 Test 1 : Connectivite du secret (CUCKK)

**Objectif** : Verifier que le secret est bien recu via webhook

**Commande** :
```bash
# Forcer le renouvellement du secret
php artisan tinker
>>> \Cache::forget('mypvit_secret');
>>> $service = app(\App\Services\MyPvitService::class);
>>> $service->getOperators();
```

**Attendu** :
- Logs `MyPVit renew-secret attempt 1`
- Logs `MyPVit secret received after X.Xs`
- Retour d'une liste d'operateurs

**Si echec** :
- Verifier l'URL `CUCKK` dans le dashboard MyPvit
- Verifier que le webhook `/api/webhooks/mypvit/secret` repond 200
- Verifier `MYPVIT_PASSWORD` dans `.env`

### 10.3 Test 2 : Paiement Airtel Money (nominal)

**Pre-requis** : Numero Airtel avec solde >= montant du ticket

**Procedure** :
1. Connecte-toi sur l'app mobile avec un compte KYC approuve
2. Selectionne une loterie (ex: Loto France a 500 FCFA)
3. Choisis 5 numeros + 1 bonus
4. Ecran paiement : selectionne **Airtel Money**, entre le numero
5. Confirme

**Attendu** :
- Message `"Confirmez le paiement sur votre telephone."`
- USSD push recu sur le telephone dans les 10 secondes
- Apres confirmation PIN : l'app affiche `"Paiement reussi! Ticket cree."`
- Redirection vers l'ecran tickets

**Verification en DB** :
```sql
SELECT id, payment_status, transaction_id, metadata->>'operator' AS operator, ticket_request_id, created_at
FROM lototrading_payments
ORDER BY created_at DESC LIMIT 1;
```

Attendu :
- `payment_status = 'completed'`
- `ticket_request_id` non nul
- `needs_review = false`

### 10.4 Test 3 : Paiement Moov Money (nominal)

Idem Test 2 mais avec un numero Moov (prefixes 062/066).

**Verification** : `metadata->>'operator' = 'MOOV_MONEY'` et `payment_method = 'moov_money'`.

### 10.5 Test 4 : Echec paiement (client refuse)

**Procedure** :
1. Initie un paiement (voir Test 2)
2. Sur le telephone : rejette le USSD push (annuler au lieu de confirmer)

**Attendu** :
- Backend recoit webhook avec `status: FAILED`
- App mobile affiche message d'erreur apres polling
- `payment_status = 'failed'` en DB
- Pas de ticket cree

### 10.6 Test 5 : Timeout (client n'agit pas)

**Procedure** :
1. Initie un paiement
2. Ne confirme PAS le USSD pendant 2 minutes

**Attendu** :
- App mobile : message `"Delai de paiement depasse"`
- Paiement reste en `pending` en DB
- Apres 30 minutes : cron marque en `expired`

### 10.7 Test 6 : Race condition (webhook + polling)

**Procedure** :
1. Initie un paiement
2. Confirme rapidement sur le telephone
3. Webhook et polling client arrivent simultanement

**Attendu** :
- Un seul ticket cree
- Pas d'erreur dans les logs
- `payment_status = 'completed'` (une seule fois)

### 10.8 Test 7 : Verification du token webhook

**Objectif** : S'assurer que les requetes sans token sont rejetees

**Commande** :
```bash
# Webhook sans token - devrait echouer (403)
curl -X POST https://loto-trading.project-preview.ovh/api/webhooks/mypvit \
  -H "Content-Type: application/json" \
  -d '{"transactionId":"TEST","merchantReferenceId":"TEST","status":"SUCCESS"}'

# Webhook avec bon token - devrait reussir (200)
curl -X POST "https://loto-trading.project-preview.ovh/api/webhooks/mypvit?token=69ae274f73bbcb30c895eeb06d77eb6660bb7d688feb3141d29316e3bae367fa" \
  -H "Content-Type: application/json" \
  -d '{"transactionId":"TEST","merchantReferenceId":"TEST","status":"SUCCESS"}'
```

### 10.9 Test 8 : Basculement entre operateurs

**Objectif** : Verifier que le bon compte marchand est utilise selon l'operateur

**Procedure** :
1. Paiement Airtel : check les logs `merchant_operation_account_code = ACC_69D7B82555A85`
2. Paiement Moov : check les logs `merchant_operation_account_code = ACC_69CE613678748`

### 10.10 Checklist de validation pre-production

- [ ] Test 1 passe : secret recu en moins de 15 secondes
- [ ] Test 2 passe : paiement Airtel nominal complet
- [ ] Test 3 passe : paiement Moov nominal complet
- [ ] Test 4 passe : gestion de l'echec paiement
- [ ] Test 5 passe : expiration apres timeout
- [ ] Test 6 passe : pas de double traitement en race condition
- [ ] Test 7 passe : webhook sans token rejete avec 403
- [ ] Test 8 passe : bon compte marchand utilise par operateur
- [ ] Les notifications OneSignal arrivent bien sur le telephone
- [ ] L'historique des paiements s'affiche correctement dans l'app
- [ ] Les logs ne contiennent pas d'erreurs recurrentes

---

## 11. Depannage

### Probleme : "MyPVit secret not received within timeout"

**Causes possibles** :
1. L'URL du webhook `CUCKK` n'est pas configuree ou incorrecte dans le dashboard MyPvit
2. Le backend n'est pas accessible depuis internet (firewall)
3. La detection du payload secret se fait apres la verification du token

**Solutions** :
1. Verifier dans le dashboard MyPvit que `CUCKK` pointe vers `https://loto-trading.project-preview.ovh/api/webhooks/mypvit` (sans token)
2. Tester manuellement :
   ```bash
   curl -X POST https://loto-trading.project-preview.ovh/api/webhooks/mypvit \
     -H "Content-Type: application/json" \
     -d '{"secret":"test123"}'
   ```
   Doit retourner `{"responseCode": 200, "message": "Secret received"}`
3. Verifier les logs Laravel : `tail -f storage/logs/laravel.log | grep MyPVit`

### Probleme : Paiement 500 FCFA bloque, erreur de paiement

**Cause classique** : Solde insuffisant sur le compte Mobile Money du client, ou numero incorrect.

**Diagnostic** :
```sql
SELECT id, metadata->>'mypvit_response' as mypvit_response
FROM lototrading_payments
WHERE id = <payment_id>;
```

Regarder le champ `message` de la reponse MyPvit.

### Probleme : Webhook arrive mais ticket pas cree

**Causes possibles** :
1. La loterie a ete desactivee entre-temps
2. Le cutoff de tirage est depasse
3. Erreur dans `TicketService::createRequest()`

**Diagnostic** :
```sql
SELECT needs_review, metadata FROM lototrading_payments WHERE id = X;
```

Si `needs_review = true` : consulter les logs pour voir l'erreur exacte.

### Probleme : Double creation de ticket

Ce ne devrait pas arriver grace au lock DB. Si ca se produit :
1. Verifier que la migration `needs_review` a bien ete executee
2. Verifier que le code utilise bien `lockForUpdate()` dans PaymentController et WebhookController

### Probleme : Le token webhook echoue mais les parametres sont bons

Causes :
1. Le token a des espaces/sauts de ligne invisibles dans le `.env`
2. Le cache de config n'a pas ete vide : `php artisan config:clear`
3. L'URL dans le dashboard MyPvit a un espace en trop ou un caractere encode

---

## 12. Reference des fichiers

### Backend Laravel

| Fichier | Role |
|---|---|
| [`app/Services/MyPvitService.php`](../backend-api/app/Services/MyPvitService.php) | Client HTTP MyPvit, rotation du secret, methodes initiatePayment/checkStatus/verifyKyc |
| [`app/Http/Controllers/Client/PaymentController.php`](../backend-api/app/Http/Controllers/Client/PaymentController.php) | Endpoints `createMobileMoneyPayment`, `checkMobileMoneyStatus` |
| [`app/Http/Controllers/Webhook/MyPvitWebhookController.php`](../backend-api/app/Http/Controllers/Webhook/MyPvitWebhookController.php) | Webhook paiement + webhook secret |
| [`app/Console/Commands/CleanExpiredPayments.php`](../backend-api/app/Console/Commands/CleanExpiredPayments.php) | Cron d'expiration des paiements pending |
| [`app/Models/Payment.php`](../backend-api/app/Models/Payment.php) | Modele Eloquent avec relations |
| [`config/services.php`](../backend-api/config/services.php) | Configuration MyPvit (ligne 50-63) |
| [`routes/api.php`](../backend-api/routes/api.php) | Routes webhook + client |

### Frontend Flutter

| Fichier | Role |
|---|---|
| [`lib/presentation/screens/payment/payment_screen.dart`](../mobile-app/lib/presentation/screens/payment/payment_screen.dart) | UI paiement + polling |
| [`lib/presentation/screens/payment/payment_history_screen.dart`](../mobile-app/lib/presentation/screens/payment/payment_history_screen.dart) | Historique des paiements |
| [`lib/core/constants/api_constants.dart`](../mobile-app/lib/core/constants/api_constants.dart) | URLs d'API mobile money |

### Documentation et scripts

| Fichier | Role |
|---|---|
| [`docs/MYPVIT_INTEGRATION.md`](MYPVIT_INTEGRATION.md) | Ce document |
| [`docs/alter_payment_security.sql`](alter_payment_security.sql) | Ajout colonne `needs_review` |
| [`docs/supabase_migration.sql`](supabase_migration.sql) | Migration complete MySQL -> PostgreSQL |

---

## Annexe : Evolution de l'integration

| Date | Changement |
|---|---|
| 2026-03 | Integration initiale MyPvit (compte unique) |
| 2026-03-28 | Bug secret webhook bloque par verification token - corrige en detectant les payloads secret avant la verification |
| 2026-04-01 | Migration vers nouveau compte MyPvit (XD8IK/CUCKK, compte Moov `ACC_69CE613678748`) |
| 2026-04-16 | Ajout du compte Airtel separe (`ACC_69D7B82555A85`) + selection dynamique selon operateur |
| 2026-04-16 | Passage a Supabase PostgreSQL |
