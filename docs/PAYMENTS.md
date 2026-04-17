# GP Link - Systeme de paiement (MyPvit)

**Dernière mise à jour** : 2026-04-17
**Version** : 1.0 (migration CinetPay → MyPvit)

---

## 1. Vue d'ensemble

GP Link utilise **MyPvit** (`https://api.mypvit.pro`) comme agrégateur Mobile Money pour le Gabon. Les paiements servent à publier/booster/prolonger des annonces de voyageurs.

### Moyens de paiement

| Méthode | Opérateur | Compte marchand |
|---------|-----------|----------------|
| Airtel Money | Airtel Gabon | `ACC_69E0129D41AEF` |
| Moov Money | Moov Africa Gabon | `ACC_69E012C052C9A` |
| Test (sandbox) | MyPvit test | `ACC_69C69B5449F96` |

### Grille tarifaire (configurable via le BO)

| Service | Prix (FCFA) | Durée |
|---------|-------------|-------|
| Annonce standard | 1 500 | 7 jours |
| Annonce boostée | 3 000 | 7 jours |
| Prolongation | 1 000 | +7 jours |
| Annonce supplémentaire | 2 000 | 7 jours |

Les prix sont stockés dans `app_config.pricing` (JSONB). Le mobile les lit via `pricingProvider` ([app_config_provider.dart](../mobile/lib/providers/app_config_provider.dart)).

---

## 2. Architecture

```
┌──────────┐        ┌──────────────┐       ┌──────────────┐        ┌──────────┐
│ Flutter  │──1────▶│  Edge Func   │──2───▶│  MyPvit API  │──3────▶│ Opérateur│
│ (mobile) │        │ mypvit-      │       │              │        │ (Airtel) │
│          │        │  initiate    │       │              │        │          │
└──────────┘        └──────────────┘       └──────────────┘        └────┬─────┘
     ▲                     ▲                      │                      │
     │                     │                      │                      │
     │ 5. Poll DB          │                      │                      ▼
     │    (status)         │                      │                ┌──────────┐
     │                     │                      │                │ Client   │
     │              ┌──────┴──────┐               │                │ (USSD)   │
     └──────────────│  Supabase   │◀──────4──────┘                 └──────────┘
                    │ PostgreSQL  │ (mypvit-webhook)
                    └─────────────┘
```

1. Flutter appelle `mypvit-initiate` (Edge Function) avec `announcement_id`, `operator`, `phone_number`
2. L'Edge Function récupère la clé secrète (cache DB ou renew), puis appelle MyPvit `/rest` → insère un `payment` en statut `pending`
3. MyPvit envoie un USSD push au téléphone du client
4. Après confirmation PIN, MyPvit POST le statut vers l'Edge Function `mypvit-webhook` → update `payments.status`
5. Flutter poll la table `payments` via Supabase toutes les 5s jusqu'à `completed` / `failed` / `expired`

### Composants

| Composant | Rôle | Fichier |
|-----------|------|---------|
| `mypvit-initiate` | Initier un paiement (serveur, JWT requis) | [supabase/functions/mypvit-initiate/index.ts](../supabase/functions/mypvit-initiate/index.ts) |
| `mypvit-secret` | Recevoir la clé secrète async (public) | [supabase/functions/mypvit-secret/index.ts](../supabase/functions/mypvit-secret/index.ts) |
| `mypvit-webhook` | Recevoir les statuts de paiement (token) | [supabase/functions/mypvit-webhook/index.ts](../supabase/functions/mypvit-webhook/index.ts) |
| `PaymentService` (Flutter) | Appel Edge Function + polling | [mobile/lib/services/payment_service.dart](../mobile/lib/services/payment_service.dart) |
| `PaymentScreen` | UI sélection opérateur + numéro | [mobile/lib/screens/payments/payment_screen.dart](../mobile/lib/screens/payments/payment_screen.dart) |
| `PaymentPollingScreen` | UI attente/succès/échec | [mobile/lib/screens/payments/payment_polling_screen.dart](../mobile/lib/screens/payments/payment_polling_screen.dart) |

---

## 3. URLs de webhook (dashboard MyPvit)

### RECEPTION DE CLE SECRETE (code `GEFEH`)
```
https://vppdjobdmeuoqnqlxaez.supabase.co/functions/v1/mypvit-secret
```
Pas de token (le secret lui-même est la donnée sensible reçue).

### CALLBACK statuts de paiement (code `8LRT4`)
```
https://vppdjobdmeuoqnqlxaez.supabase.co/functions/v1/mypvit-webhook?token=954ae94834389c621f823ea68a271a4477a30427874eba93bd5e87c2d4b5a2bc
```
Le token en query param protège contre les webhooks falsifiés (MyPvit ne supporte pas les headers custom).

---

## 4. Variables d'environnement

Voir [supabase/.env.example](../supabase/.env.example). À configurer via :

```bash
supabase secrets set --env-file supabase/.env
```

---

## 5. Déploiement

```bash
# 1. Appliquer les migrations
supabase db push

# 2. Configurer les secrets (une seule fois)
supabase secrets set --env-file supabase/.env

# 3. Déployer les Edge Functions
supabase functions deploy mypvit-secret --no-verify-jwt
supabase functions deploy mypvit-webhook --no-verify-jwt
supabase functions deploy mypvit-initiate

# 4. Configurer les 2 URLs webhook dans le dashboard MyPvit (voir §3)
```

---

## 6. Flux détaillé

### Étape 1 : Flutter initie le paiement

```dart
final service = PaymentService();
final result = await service.initiatePayment(
  announcementId: ann.id,
  paymentType: 'announcement',
  operator: MobileMoneyOperator.airtel,
  phoneNumber: '077000001',
);
// result.paymentId -> naviguer vers /payments/${id}/waiting
```

### Étape 2 : Edge Function appelle MyPvit

`mypvit-initiate` :
1. Vérifie le JWT utilisateur
2. Dérive le montant depuis `app_config.pricing` (ne fait PAS confiance au client)
3. Récupère/renouvelle la clé secrète MyPvit
4. Appelle `POST /v2/0UEXVLW6Q77SR820/rest` avec le compte marchand adapté à l'opérateur
5. Insère une ligne `payments` en `pending`, stocke `reference`, `mypvit_transaction_id`, `operator`, `phone_number`

### Étape 3 : Webhook MyPvit → Supabase

`mypvit-webhook` :
1. Vérifie le token en query param (timing-safe)
2. Retrouve le paiement par `mypvit_transaction_id` ou `reference` (normalisé sans tirets)
3. Si `SUCCESS` : passe à `completed`, active l'annonce (`status=active`, `published_at`, `expires_at`), déclenche `match-alerts`
4. Si `FAILED`/`REFUSED` : passe à `failed`
5. Crée une notification pour l'utilisateur dans tous les cas

### Étape 4 : Flutter poll la DB

`PaymentPollingScreen` utilise `PaymentService.watchPayment(paymentId)` qui interroge `payments` toutes les 5s (jusqu'à 3 min). Dès que `status != pending`, affiche l'écran résultat.

---

## 7. Sécurité

### Clé secrète MyPvit
- Rotation automatique (TTL 50 min)
- Stockée dans `mypvit_secrets` (service_role only, pas de RLS policy publique)
- Ré-obtention automatique si l'API retourne 401/403

### Webhook anti-spoofing
- Token généré via `openssl rand -hex 32`
- Comparaison timing-safe
- Le webhook `mypvit-secret` est volontairement ouvert (MyPvit ne peut pas y joindre de token)

### Montants
- **Le client ne transmet JAMAIS le montant** — il est dérivé côté serveur depuis `app_config.pricing`
- Protection contre la manipulation des prix par le mobile

### Idempotence
- Avant UPDATE : `.neq('status', 'completed')` garantit qu'un webhook rejoué ne peut pas retraiter

### Expiration automatique
Fonction SQL `expire_stale_payments()` marque les paiements `pending > 30min` en `expired`. À câbler sur un cron via `pg_cron` ou via la fonction existante `expire-announcements`.

---

## 8. Tests sandbox

Utiliser le compte `MYPVIT_ACCOUNT_TEST` et l'opérateur `TEST` depuis l'app mobile (option visible en debug uniquement).

Voir [TESTING_PAYMENTS.md](TESTING_PAYMENTS.md) pour les curl commands et la checklist.

---

## 9. Dépannage

### "Timeout waiting for MyPvit secret via webhook"
- Vérifier que l'URL `GEFEH` est bien configurée dans le dashboard MyPvit
- Tester manuellement : `curl -X POST https://vppdjobdmeuoqnqlxaez.supabase.co/functions/v1/mypvit-secret -d '{"secret":"test"}'`
- Vérifier les logs : `supabase functions logs mypvit-secret`

### Webhook reçu mais paiement pas trouvé
- MyPvit retire les tirets de la référence — déjà géré dans le code
- Vérifier que la référence stockée en DB correspond à ce que MyPvit renvoie

### Paiement reste en `pending` alors que l'app dit "confirmé"
- Le webhook n'est probablement pas arrivé — vérifier le token en query param
- Vérifier les logs webhook côté MyPvit et `supabase functions logs mypvit-webhook`
