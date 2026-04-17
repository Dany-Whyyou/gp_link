# GP Link - Procédure de tests paiement MyPvit

## Pré-requis

- Migrations appliquées (`supabase db push`)
- Secrets configurés (`supabase secrets set --env-file supabase/.env`)
- 3 Edge Functions déployées (voir `docs/PAYMENTS.md` §5)
- URLs `GEFEH` et `8LRT4` configurées dans le dashboard MyPvit
- Un utilisateur authentifié en base avec son JWT

## Test 1 — Webhook secret (smoke test)

Vérifier que l'Edge Function reçoit bien un secret.

```bash
curl -X POST https://vppdjobdmeuoqnqlxaez.supabase.co/functions/v1/mypvit-secret \
  -H "Content-Type: application/json" \
  -d '{"secret":"sk_test_FAKE_SECRET_123456"}'
```

**Attendu** : `{"responseCode":200,"message":"Secret received"}`

Vérifier en DB :
```sql
SELECT id, substring(secret, 1, 10) AS secret_preview, expires_at
FROM mypvit_secrets;
```

## Test 2 — Webhook paiement sans token (doit échouer)

```bash
curl -X POST https://vppdjobdmeuoqnqlxaez.supabase.co/functions/v1/mypvit-webhook \
  -H "Content-Type: application/json" \
  -d '{"transactionId":"PAY123","status":"SUCCESS"}'
```

**Attendu** : `403 {"error":"Forbidden"}`

## Test 3 — Webhook paiement avec token (silent si paiement inconnu)

```bash
curl -X POST "https://vppdjobdmeuoqnqlxaez.supabase.co/functions/v1/mypvit-webhook?token=954ae94834389c621f823ea68a271a4477a30427874eba93bd5e87c2d4b5a2bc" \
  -H "Content-Type: application/json" \
  -d '{"transactionId":"PAY_UNKNOWN_123","merchantReferenceId":"REF_UNKNOWN","status":"SUCCESS"}'
```

**Attendu** : `200 {"responseCode":200,"transactionId":"PAY_UNKNOWN_123"}`
En logs : `mypvit-webhook: payment not found`

## Test 4 — Initiation paiement (requiert JWT utilisateur)

```bash
USER_JWT="<copier depuis l'app mobile>"
ANNOUNCEMENT_ID="<uuid d'une annonce en pending_payment appartenant à l'utilisateur>"

curl -X POST https://vppdjobdmeuoqnqlxaez.supabase.co/functions/v1/mypvit-initiate \
  -H "Authorization: Bearer $USER_JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "announcement_id":"'$ANNOUNCEMENT_ID'",
    "payment_type":"announcement",
    "operator":"TEST",
    "phone_number":"077000001"
  }'
```

**Attendu (200)** :
```json
{
  "payment_id":"<uuid>",
  "reference":"GPL<userShort><timestamp>",
  "amount":1500,
  "currency":"XAF",
  "mypvit_transaction_id":"PAY...",
  "status":"pending",
  "message":"Confirmez le paiement sur votre telephone."
}
```

Erreurs possibles :
- `401 Unauthorized` : JWT invalide/expiré
- `404 Announcement not found` : annonce non trouvée ou n'appartient pas à l'utilisateur
- `502 MyPvit rejected the payment` : MyPvit a refusé (voir `details` dans la réponse)
- `500 Payment initialization failed` : échec technique (voir les logs)

## Test 5 — Paiement Airtel nominal (via l'app mobile)

1. Connecte-toi sur l'app avec un compte KYC OK
2. Crée une annonce
3. À l'écran paiement, sélectionne **Airtel Money**, saisis `077000001`
4. Tape "Payer"
5. Confirme le USSD sur le téléphone avec le code PIN
6. L'app doit afficher "Paiement confirmé"

**Vérification DB** :
```sql
SELECT id, status, reference, mypvit_transaction_id, operator, phone_number, paid_at
FROM payments
ORDER BY created_at DESC LIMIT 1;
```
Attendu : `status='completed'`, `paid_at IS NOT NULL`, `operator='AIRTEL_MONEY'`

**Vérification annonce** :
```sql
SELECT id, status, published_at, expires_at
FROM announcements
WHERE id = '<annonce>';
```
Attendu : `status='active'`, `expires_at = published_at + 7 jours`

## Test 6 — Paiement Moov nominal

Identique au test 5, opérateur **Moov Money**, numéro format `062XXXXXX`/`066XXXXXX`.

## Test 7 — Échec paiement (refus client)

1. Initie un paiement
2. Sur le téléphone : annule le USSD au lieu de confirmer

**Attendu** :
- Écran Flutter passe à "Paiement échoué"
- `payments.status = 'failed'`
- Annonce reste en `pending_payment`

## Test 8 — Timeout (client n'agit pas)

1. Initie un paiement
2. Laisse le USSD non confirmé pendant 3+ minutes

**Attendu** :
- Écran Flutter passe à "Délai dépassé" (fin du polling)
- `payments.status = 'pending'` (webhook n'est jamais arrivé)
- Après exécution de `expire_stale_payments()` : `status='expired'`

Tester manuellement :
```sql
SELECT expire_stale_payments();
```

## Test 9 — Rotation du secret

1. Force l'expiration du secret en DB :
```sql
UPDATE mypvit_secrets SET expires_at = NOW() - INTERVAL '1 minute';
```
2. Initie un paiement via test 4

**Attendu** :
- L'Edge Function appelle `/renew-secret`, attend le webhook, puis continue
- Logs `mypvit-initiate: secret rejected, rotating` si 401/403
- Latence augmentée de quelques secondes

## Checklist de validation pré-production

- [ ] Test 1 : secret reçu
- [ ] Test 2 : webhook sans token rejeté
- [ ] Test 3 : webhook avec token accepté
- [ ] Test 4 : initiation via API
- [ ] Test 5 : Airtel nominal complet
- [ ] Test 6 : Moov nominal complet
- [ ] Test 7 : gestion de l'échec
- [ ] Test 8 : expiration automatique
- [ ] Test 9 : rotation du secret
- [ ] Les notifications "Paiement confirmé" arrivent à l'utilisateur
- [ ] Le dashboard BO affiche correctement les paiements (opérateur + référence)
- [ ] Changement des tarifs dans le BO → répercuté sur l'app mobile après refresh
