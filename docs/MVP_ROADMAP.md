# GP Link - Roadmap Produit

## Vision

GP Link connecte les voyageurs aeriens avec des expediteurs de colis entre le Gabon et l'international. La plateforme permet aux voyageurs de monetiser leurs kilos de bagages disponibles et aux expediteurs de trouver des solutions d'envoi fiables et abordables.

---

## MVP v1 - Fondations (3-4 mois)

**Objectif** : Lancer un produit fonctionnel sur le marche gabonais (Libreville principalement).

### Authentification et profils
- [x] Inscription par telephone (OTP SMS)
- [x] Inscription par email
- [x] Creation automatique du profil
- [x] Modification du profil (nom, ville, photo)
- [ ] Verification du numero de telephone
- [ ] Ecran d'onboarding (choix du role : voyageur / client)

### Annonces
- [x] Schema de donnees complet (depart, arrivee, kg, prix, dates)
- [x] Contrainte : 1 annonce active par utilisateur
- [ ] Creation d'annonce avec formulaire
- [ ] Liste des annonces actives (feed principal)
- [ ] Filtres de recherche (ville depart/arrivee, date, prix)
- [ ] Detail d'une annonce
- [ ] Expiration automatique apres 7 jours

### Systeme d'alertes
- [x] Schema de donnees (criteres de recherche)
- [x] Fonction SQL de matching
- [ ] Creation d'alerte par le client
- [ ] Notifications push lors d'un match
- [ ] Gestion des alertes (pause, suppression)

### Chat en temps reel
- [x] Schema conversations + messages
- [ ] Liste des conversations
- [ ] Ecran de chat (Supabase Realtime)
- [ ] Indicateur de messages non lus
- [ ] Notification push pour nouveaux messages

### Paiement Mobile Money
- [x] Integration MyPvit (Edge Functions : initiate, webhook, secret)
- [x] Webhook de validation avec token anti-spoofing
- [x] Activation d'annonce apres paiement
- [x] UI de paiement dans l'app (Airtel Money, Moov Money)
- [x] Ecran de polling avec resultats (succes/echec/expire)
- [x] Tarifs dynamiques via app_config
- [ ] Historique des paiements
- [ ] Ecran de confirmation / echec

### Administration
- [ ] Dashboard admin (Next.js)
- [ ] Liste des utilisateurs
- [ ] Liste des annonces (avec filtres par statut)
- [ ] Moderation : suspendre/approuver annonce
- [ ] Moderation : bannir utilisateur
- [ ] Gestion des signalements

### Infrastructure
- [x] Schema PostgreSQL complet
- [x] Politiques RLS
- [x] Edge Functions (paiement, matching, expiration, nettoyage)
- [ ] Configuration pg_cron pour les taches planifiees
- [ ] Configuration OneSignal
- [ ] Deploiement Supabase (production)
- [ ] Publication Play Store (Android)

---

## v2 - Confiance et engagement (2-3 mois apres v1)

**Objectif** : Augmenter la confiance entre utilisateurs et ameliorer la retention.

### Systeme d'avis
- [ ] Laisser un avis apres une reservation completee
- [ ] Note de 1 a 5 etoiles + commentaire
- [ ] Affichage de la note moyenne sur le profil
- [ ] Moderation des avis inappropries

### Verification d'identite
- [ ] Upload de piece d'identite (CNI, passeport)
- [ ] Verification manuelle par l'admin
- [ ] Badge "Identite verifiee" sur le profil
- [ ] Priorite dans les resultats pour les profils verifies

### Reservations
- [ ] Systeme de reservation de kilos
- [ ] Flux : demande -> acceptation/refus -> confirmation
- [ ] Mise a jour automatique des kg disponibles
- [ ] Historique des reservations

### Recherche avancee
- [ ] Recherche par ville avec autocompletion
- [ ] Filtres combines (prix max, kg min, date)
- [ ] Tri par pertinence, prix, date
- [ ] Recherche fuzzy sur les noms de ville

### Annonces boostees
- [ ] Mise en avant des annonces boostees dans le feed
- [ ] Badge visuel "Boostee"
- [ ] Statistiques detaillees (vues, contacts)

### Analytiques
- [ ] Dashboard admin : nombre d'annonces, utilisateurs, paiements
- [ ] Graphiques d'evolution (hebdomadaire, mensuel)
- [ ] Top trajets
- [ ] Taux de conversion (visite -> contact -> reservation)

### Ameliorations UX
- [ ] Mode sombre
- [ ] Langues : Francais (par defaut), Anglais
- [ ] Partage d'annonce (WhatsApp, lien direct)
- [ ] Favoris (sauvegarder des annonces)

---

## v3 - Expansion (4-6 mois apres v2)

**Objectif** : Etendre la plateforme au-dela du Gabon et creer un ecosysteme durable.

### Multi-pays
- [ ] Expansion vers le Cameroun (Douala, Yaounde)
- [ ] Expansion vers le Congo (Brazzaville)
- [ ] Expansion vers la Cote d'Ivoire (Abidjan)
- [ ] Expansion vers le Senegal (Dakar)
- [ ] Ajout de moyens de paiement locaux (Orange Money, MTN Money)
- [ ] Tarification par pays

### API pour partenaires
- [ ] API REST documentee (OpenAPI)
- [ ] Cles API pour partenaires
- [ ] Webhooks pour evenements (nouvelle annonce, reservation)
- [ ] Cas d'usage : agences de voyage, comparateurs

### Abonnements premium
- [ ] Abonnement voyageur pro : annonces illimitees, boost inclus
- [ ] Abonnement client premium : alertes illimitees, priorite de contact
- [ ] Gestion des abonnements recurrents

### Fonctionnalites avancees
- [ ] Suivi de colis (statuts : pris en charge, en transit, livre)
- [ ] Assurance colis (partenariat avec assureur local)
- [ ] Programme de fidelite (points a chaque transaction)
- [ ] Chat de groupe pour les envois groupes
- [ ] Publication sur iOS (App Store)

### Securite renforcee
- [ ] Authentification 2FA
- [ ] Detection de fraude automatisee (patterns suspects)
- [ ] Audit log complet pour conformite
- [ ] Pentest et certification securite

### Scalabilite
- [ ] CDN pour les images (Cloudinary ou equivalent)
- [ ] Cache Redis pour les requetes frequentes
- [ ] Monitoring et alerting (Sentry, Grafana)
- [ ] Tests de charge

---

## Indicateurs de succes (KPIs)

### MVP v1
| KPI | Objectif |
|-----|----------|
| Utilisateurs inscrits | 500 en 3 mois |
| Annonces publiees | 100 / mois |
| Taux de contact | 30% des annonces vues |
| Paiements reussis | > 90% |
| Note Play Store | > 4.0 |

### v2
| KPI | Objectif |
|-----|----------|
| Utilisateurs inscrits | 2 000 |
| Reservations completees | 50 / mois |
| Utilisateurs avec avis | 30% |
| Profils verifies | 20% |
| Retention J30 | > 25% |

### v3
| KPI | Objectif |
|-----|----------|
| Utilisateurs inscrits | 10 000+ |
| Pays actifs | 3+ |
| Revenus mensuels | Objectif a definir |
| Partenaires API | 2+ |
| Abonnements actifs | 100+ |

---

## Priorites techniques transversales

| Priorite | Description |
|----------|-------------|
| Performance | Temps de chargement < 2s, chat temps reel < 500ms |
| Fiabilite | Uptime 99.5%, zero perte de paiement |
| Securite | RLS partout, validation serveur, audit des cles |
| Testabilite | Tests unitaires Flutter, tests Edge Functions |
| Monitoring | Logs structures, alertes sur erreurs critiques |
