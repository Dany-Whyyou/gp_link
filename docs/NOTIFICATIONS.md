# GP Link - Systeme de Notifications

## Vue d'ensemble

GP Link utilise un systeme de notifications a deux niveaux :
1. **Notifications in-app** : stockees dans la table `notifications` et affichees dans l'application
2. **Notifications push** : envoyees via OneSignal pour alerter l'utilisateur meme quand l'app est fermee

---

## Quand les notifications sont envoyees

### 1. Correspondance d'alerte (`alert_match`)

**Declencheur** : Une annonce devient active apres paiement.

**Processus** :
- L'Edge Function `match-alerts` est appelee par `process-payment`
- Elle interroge la table `alerts` pour trouver les alertes correspondantes (ville depart/arrivee, dates, kg, prix)
- Une notification in-app + push est creee pour chaque utilisateur ayant une alerte correspondante

**Payload push** :
```json
{
  "headings": { "fr": "Nouvelle correspondance !" },
  "contents": { "fr": "Un voyageur propose 10kg Libreville -> Paris le 2026-05-15 a 5000 FCFA/kg" },
  "data": {
    "type": "alert_match",
    "announcement_id": "uuid-xxx"
  }
}
```

### 2. Mise a jour de reservation (`booking_update`)

**Declencheur** : Le statut d'une reservation change (acceptee, rejetee, annulee, completee).

**Exemple de notification** :
- "Votre reservation de 5kg a ete acceptee par [Voyageur]"
- "Votre reservation a ete refusee"

### 3. Message chat (`chat_message`)

**Declencheur** : Un nouveau message est envoye dans une conversation.

**Particularite** : La notification push n'est envoyee que si le destinataire n'est pas en train de lire la conversation (gere cote client via Realtime).

**Payload push** :
```json
{
  "headings": { "fr": "Nouveau message" },
  "contents": { "fr": "[Nom] : Debut du message..." },
  "data": {
    "type": "chat_message",
    "conversation_id": "uuid-xxx",
    "sender_id": "uuid-xxx"
  }
}
```

### 4. Confirmation de paiement (`payment`)

**Declencheur** : Un paiement est confirme ou echoue (webhook MyPvit).

**Notifications** :
- Succes : "Votre paiement de 1500 FCFA a ete confirme. Votre annonce est maintenant active !"
- Echec : "Votre paiement de 1500 FCFA a echoue. Veuillez reessayer."

### 5. Expiration d'annonce (`system`)

**Declencheur** : L'Edge Function `expire-announcements` detecte une annonce expiree.

**Notification** : "Votre annonce Libreville -> Paris du 2026-05-15 a expire. Vous pouvez la renouveler."

### 6. Action de moderation (`moderation`)

**Declencheur** : Un administrateur suspend ou approuve une annonce/un compte.

**Notifications** :
- "Votre annonce a ete suspendue pour : [raison]"
- "Votre compte a ete suspendu pour : [raison]"

---

## Integration OneSignal

### Configuration

Variables d'environnement requises :
```
ONESIGNAL_APP_ID=votre-app-id
ONESIGNAL_REST_API_KEY=votre-rest-api-key
```

### Enregistrement du Player ID

Au lancement de l'application Flutter, l'utilisateur est enregistre aupres de OneSignal et son `player_id` est sauvegarde dans `profiles.onesignal_player_id`.

```dart
// Exemple Flutter (simplifie)
OneSignal.shared.setExternalUserId(supabaseUser.id);
final status = await OneSignal.shared.getDeviceState();
final playerId = status?.userId;
if (playerId != null) {
  await supabase.from('profiles').update({
    'onesignal_player_id': playerId,
  }).eq('id', supabaseUser.id);
}
```

### Envoi de push (cote serveur)

Les Edge Functions utilisent l'API REST OneSignal :
```
POST https://onesignal.com/api/v1/notifications
Authorization: Basic {ONESIGNAL_REST_API_KEY}
```

Le champ `include_player_ids` cible les utilisateurs specifiques.

---

## Regles anti-spam

### Limite quotidienne par alerte
- Maximum **3 notifications** de type `alert_match` par utilisateur par jour
- Verificateur : comptage des notifications du jour pour l'utilisateur avant envoi

### Pas de doublons
- Avant de creer une notification `alert_match`, on verifie qu'il n'existe pas deja une notification pour le meme `announcement_id` et le meme `user_id`
- Empeche les notifications multiples si `match-alerts` est appelee plusieurs fois

### Expiration des alertes
- Les alertes expirent automatiquement apres 30 jours (configurable)
- Les alertes expirees ne declenchent plus de notifications

---

## Structure de la notification en base

```sql
CREATE TABLE notifications (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,        -- destinataire
  type notification_type,       -- alert_match, booking_update, chat_message, payment, system, moderation
  title TEXT NOT NULL,           -- titre affiche
  body TEXT NOT NULL,            -- contenu affiche
  data JSONB DEFAULT '{}',      -- donnees supplementaires pour la navigation
  is_read BOOLEAN DEFAULT FALSE,
  is_pushed BOOLEAN DEFAULT FALSE, -- push OneSignal envoye ?
  created_at TIMESTAMPTZ
);
```

### Champ `data` (exemples)

| Type | Contenu data |
|------|-------------|
| `alert_match` | `{ announcement_id, alert_id, departure_city, arrival_city, departure_date, available_kg, price_per_kg }` |
| `booking_update` | `{ booking_id, announcement_id, new_status }` |
| `chat_message` | `{ conversation_id, sender_id, message_preview }` |
| `payment` | `{ payment_id, announcement_id, amount, type }` |
| `system` | `{ announcement_id, action }` |
| `moderation` | `{ reason, entity_type, entity_id }` |

---

## Nettoyage automatique

L'Edge Function `cleanup-notifications` s'execute quotidiennement :
- Supprime les notifications **lues** de plus de **30 jours**
- Supprime les notifications **non lues** de plus de **90 jours**

Configuration cron recommandee :
```sql
-- Via pg_cron (si disponible sur le plan Supabase)
SELECT cron.schedule(
  'cleanup-notifications',
  '0 3 * * *',  -- tous les jours a 3h du matin
  $$SELECT net.http_post(
    url := 'https://votre-projet.supabase.co/functions/v1/cleanup-notifications',
    headers := '{"Authorization": "Bearer SERVICE_ROLE_KEY"}'::jsonb
  )$$
);
```
