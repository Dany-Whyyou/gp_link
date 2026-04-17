# GP Link - Securite

## Vue d'ensemble

GP Link gere des transactions financieres et des donnees personnelles d'utilisateurs au Gabon. Ce document decrit les mesures de securite mises en place et les recommandations.

---

## 1. Authentification (Supabase Auth)

### Methodes supportees

| Methode | Usage | Implementation |
|---------|-------|---------------|
| Telephone (OTP) | Methode principale | SMS via Supabase Auth |
| Email + mot de passe | Methode secondaire | Supabase Auth natif |

### Flux d'authentification

```
Utilisateur -> Saisit numero de telephone -> OTP envoye par SMS
-> Saisit le code -> Token JWT genere -> Profil cree automatiquement
```

### Securite des tokens

- Tokens JWT signes par Supabase avec cle secrete
- Access token : duree de vie courte (1 heure par defaut)
- Refresh token : duree de vie longue, stocke de facon securisee sur le device
- Le refresh token est utilise pour obtenir un nouveau access token sans re-authentification

---

## 2. Row Level Security (RLS)

Toutes les tables ont RLS active. Voici un resume des politiques :

### Profiles
| Operation | Regle |
|-----------|-------|
| SELECT | Publique (tout le monde peut voir les profils) |
| UPDATE | Uniquement son propre profil |
| ALL | Administrateurs |

### Announcements
| Operation | Regle |
|-----------|-------|
| SELECT | Annonces actives visibles par tous ; les propres annonces toujours visibles |
| INSERT | Uniquement pour son propre user_id |
| UPDATE | Proprietaire ou administrateur |
| DELETE | Proprietaire ou administrateur |

### Alerts
| Operation | Regle |
|-----------|-------|
| SELECT | Uniquement ses propres alertes |
| INSERT | Uniquement pour son propre user_id |
| UPDATE/DELETE | Uniquement ses propres alertes |

### Bookings
| Operation | Regle |
|-----------|-------|
| SELECT | Client ou voyageur de la reservation |
| INSERT | Uniquement en tant que client |
| UPDATE | Client ou voyageur |

### Payments
| Operation | Regle |
|-----------|-------|
| SELECT | Uniquement ses propres paiements |
| INSERT | Uniquement pour son propre user_id |
| UPDATE | Administrateur uniquement (via service_role pour webhooks) |

### Conversations / Messages
| Operation | Regle |
|-----------|-------|
| SELECT | Participants de la conversation uniquement |
| INSERT | Participant de la conversation, sender = auth.uid() |

### Notifications
| Operation | Regle |
|-----------|-------|
| SELECT | Uniquement ses propres notifications |
| UPDATE | Uniquement ses propres notifications (marquer comme lu) |
| INSERT | Systeme (via service_role) |

---

## 3. Mesures anti-fraude

### Paiements

- **Webhook token anti-spoofing** : les webhooks MyPvit sont protégés par un token partagé (`MYPVIT_WEBHOOK_TOKEN`) en query param, comparé en timing-safe côté Edge Function
- **Pas de credentials côté mobile** : les clés MyPvit (password, account codes) ne sont jamais embarquées dans l'app — le mobile passe par `mypvit-initiate`, qui gère le secret côté serveur
- **Montant côté serveur** : le montant est dérivé de `app_config.pricing` par l'Edge Function (le client ne peut pas imposer un prix)
- **Idempotence** : `UPDATE ... WHERE status != 'completed'` garantit qu'un webhook rejoué ne retraite pas le paiement
- **Rotation automatique du secret** : la clé secrète MyPvit (TTL 50min) est rafraîchie automatiquement, invalidée sur 401/403

### Annonces

- **Une seule annonce active** : index unique `idx_one_active_per_user` empeche d'avoir plus d'une annonce active par utilisateur
- **Activation uniquement apres paiement** : une annonce ne peut devenir `active` qu'apres un paiement `completed`
- **Expiration automatique** : les annonces expirent automatiquement apres 7 jours

### Comptes

- **Bannissement** : un utilisateur banni (`is_banned = true`) ne peut plus acceder aux fonctionnalites (a implementer cote client et middleware)
- **Signalements** : apres 3 signalements (`max_reports_before_suspend`), une annonce peut etre automatiquement suspendue (configurable dans `app_config`)

---

## 4. Validation des donnees

### Contraintes SQL

| Table | Contrainte |
|-------|-----------|
| `announcements.available_kg` | `> 0` |
| `announcements.price_per_kg` | `> 0` |
| `bookings.kg_reserved` | `> 0` |
| `reviews.rating` | `BETWEEN 1 AND 5` |
| `conversations` | `UNIQUE (participant_1, participant_2, announcement_id)` |
| `reviews` | `UNIQUE (booking_id, reviewer_id)` |

### Validation cote application (Flutter)

- Numeros de telephone : format international (+241 pour le Gabon)
- Dates : la date de depart doit etre dans le futur
- Kilos disponibles : valeur positive, maximum raisonnable (ex: 50 kg)
- Prix : valeur positive en FCFA
- Texte : nettoyage des entrees (pas de HTML/scripts)
- Images : validation du type MIME, taille maximale

### Validation cote Edge Functions

- Verification de la presence des champs obligatoires
- Verification des types de donnees
- Verification de la coherence (montant paiement = prix annonce)

---

## 5. Rate limiting

### Recommandations

GP Link n'implemente pas nativement le rate limiting au niveau Supabase (non disponible sur tous les plans). Voici les recommandations :

| Endpoint/Action | Limite recommandee | Implementation |
|----------------|-------------------|---------------|
| Authentification (OTP) | 5 tentatives / 15 min / IP | Supabase Auth (natif) |
| Creation d'annonce | 1 / heure / utilisateur | Logique applicative |
| Envoi de message | 30 / minute / utilisateur | Logique applicative |
| Creation d'alerte | 5 / jour / utilisateur | Logique applicative |
| Signalement | 3 / jour / utilisateur | Logique applicative |
| Appels API generaux | 100 / minute / utilisateur | API Gateway / Cloudflare |

### Implementation suggeree

Pour les Edge Functions critiques (process-payment), utiliser un compteur Redis ou une table de rate limiting :

```sql
CREATE TABLE rate_limits (
  key TEXT PRIMARY KEY,         -- ex: "otp:+241XXXXXXX" ou "api:user-uuid"
  count INTEGER DEFAULT 1,
  window_start TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ
);
```

---

## 6. Protection des donnees (GDPR / Gabon)

### Contexte reglementaire

Le Gabon dispose de la **Commission Nationale pour la Protection des Donnees a Caractere Personnel (CNPDCP)** creee par la loi n°001/2011. GP Link doit respecter ces dispositions.

### Donnees collectees

| Donnee | Finalite | Base legale |
|--------|----------|-------------|
| Numero de telephone | Authentification, contact | Execution du contrat |
| Nom complet | Identification | Execution du contrat |
| Email (optionnel) | Communication secondaire | Consentement |
| Ville | Matching geographique | Interet legitime |
| Photo de profil | Confiance | Consentement |
| Historique de paiements | Suivi financier | Obligation legale |
| Messages chat | Communication entre utilisateurs | Execution du contrat |

### Droits des utilisateurs

| Droit | Implementation |
|-------|---------------|
| Droit d'acces | Export des donnees personnelles via l'app |
| Droit de rectification | Modification du profil a tout moment |
| Droit de suppression | Suppression du compte (CASCADE sur toutes les tables) |
| Droit a la portabilite | Export JSON des donnees |
| Droit d'opposition | Desactivation des notifications push |

### Mesures techniques

- **Chiffrement en transit** : HTTPS obligatoire (gere par Supabase)
- **Chiffrement au repos** : chiffrement AES-256 des donnees PostgreSQL (gere par Supabase/AWS)
- **Retention des donnees** :
  - Notifications lues : supprimees apres 30 jours
  - Notifications non lues : supprimees apres 90 jours
  - Messages : conserves tant que le compte existe
  - Paiements : conserves 5 ans (obligation legale)
- **Anonymisation** : a la suppression du compte, les donnees personnelles sont supprimees (CASCADE) mais les transactions financieres sont anonymisees

### Securite des cles

- Les credentials MyPvit (password, account codes, endpoint codes) et OneSignal sont stockes comme variables d'environnement Supabase (secrets), jamais dans le code source ni dans le mobile
- La `service_role_key` Supabase n'est jamais exposee cote client
- La `anon_key` est utilisee cote client avec RLS pour la protection

---

## 7. Checklist de securite pre-lancement

- [ ] Toutes les tables ont RLS active
- [ ] Les Edge Functions utilisent `service_role` uniquement cote serveur
- [ ] Les cles API sont dans les variables d'environnement Supabase
- [ ] La `service_role_key` n'est pas dans le code Flutter
- [ ] Les webhooks MyPvit sont verifies via token partagé (timing-safe)
- [ ] Le secret MyPvit tourne automatiquement toutes les 50 minutes
- [ ] Les contraintes SQL sont en place
- [ ] La validation des donnees est implementee cote Flutter
- [ ] Le rate limiting est configure sur les endpoints critiques
- [ ] La politique de confidentialite est publiee et accessible
- [ ] Les CGU mentionnent la collecte et l'utilisation des donnees
- [ ] Le mecanisme de suppression de compte fonctionne correctement
- [ ] Les logs d'audit sont actives pour les actions sensibles
- [ ] HTTPS est force sur toutes les communications
