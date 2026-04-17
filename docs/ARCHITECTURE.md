# GP Link - Architecture Globale

## Nom : GP Link (Gabon Package Link)

> Plateforme de mise en relation entre voyageurs aeriens et expediteurs de colis (Gabon <-> International)

---

## 1. Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────┐
│                        CLIENTS                               │
│                                                              │
│   ┌──────────────┐              ┌──────────────────┐        │
│   │  App Mobile   │              │  Admin Panel     │        │
│   │  (Flutter)    │              │  (Next.js)       │        │
│   │  Android/iOS  │              │  Web Dashboard   │        │
│   └──────┬───────┘              └────────┬─────────┘        │
└──────────┼──────────────────────────────┼───────────────────┘
           │                              │
           ▼                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      SUPABASE                                │
│                                                              │
│   ┌──────────────┐  ┌──────────┐  ┌───────────────┐        │
│   │  Auth         │  │ Realtime │  │  Storage      │        │
│   │  (email/phone)│  │ (chat +  │  │  (photos,     │        │
│   │               │  │  alerts) │  │   docs)       │        │
│   └──────────────┘  └──────────┘  └───────────────┘        │
│                                                              │
│   ┌──────────────┐  ┌──────────┐  ┌───────────────┐        │
│   │  PostgreSQL   │  │ Edge     │  │  RLS Policies │        │
│   │  (data)       │  │ Functions│  │  (security)   │        │
│   └──────────────┘  └──────────┘  └───────────────┘        │
└─────────────────────────────────────────────────────────────┘
           │                              │
           ▼                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   SERVICES EXTERNES                          │
│                                                              │
│   ┌──────────────┐  ┌──────────┐  ┌───────────────┐        │
│   │  OneSignal    │  │ Mobile   │  │  Cloudinary   │        │
│   │  (push notif) │  │ Money API│  │  (images CDN) │        │
│   └──────────────┘  └──────────┘  └───────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## 2. Flux de donnees principaux

### Flux 1 : Publication d'annonce (Voyageur)
```
Voyageur → Cree annonce → Paiement Mobile Money → Validation paiement
→ Annonce publiee → Matching alertes → Push notifications aux clients
```

### Flux 2 : Recherche et reservation (Client)
```
Client → Recherche/Alerte → Notification match → Consulte annonce
→ Contact voyageur (chat) → Accord → Reservation confirmee
```

### Flux 3 : Moderation (Admin)
```
Admin → Dashboard → Voit annonces signalees → Modere (approuve/rejette)
→ Notification a l'utilisateur
```

## 3. Choix techniques justifies

| Composant | Choix | Justification |
|-----------|-------|---------------|
| Mobile | Flutter | Cross-platform, performant, une seule codebase |
| Backend | Supabase | PostgreSQL manage, Auth integre, Realtime, gratuit au depart |
| Admin | Next.js 14 (App Router) | SSR, API routes, React ecosystem |
| State mgmt | Riverpod | Recommande Flutter, type-safe, testable |
| Push notif | OneSignal | Gratuit jusqu'a 10k users, simple a integrer |
| Paiement | MyPvit | Supporte Airtel Money + Moov Money Gabon (comptes marchands séparés par opérateur) |
| Images | Supabase Storage | Integre, pas de service externe supplementaire |
| Chat | Supabase Realtime | Temps reel natif, pas de Firebase necessaire |

## 4. Environnements

| Env | Usage |
|-----|-------|
| Development | Local + Supabase project dev |
| Staging | Test pre-production |
| Production | Live |

## 5. Structure des dossiers

```
gp/
├── mobile/          # App Flutter (Android + iOS)
├── admin/           # Panel admin Next.js
├── supabase/        # Migrations SQL + Edge Functions
│   ├── migrations/  # Fichiers SQL ordonnees
│   └── functions/   # Edge Functions (webhooks paiement, matching)
└── docs/            # Documentation projet
```
