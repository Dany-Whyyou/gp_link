-- ============================================================
-- GP LINK - Schema initial complet
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- pour recherche fuzzy

-- ============================================================
-- ENUMS
-- ============================================================

CREATE TYPE user_role AS ENUM ('client', 'voyageur', 'admin');
CREATE TYPE announcement_status AS ENUM ('pending_payment', 'active', 'expired', 'suspended', 'completed');
CREATE TYPE announcement_type AS ENUM ('standard', 'boosted');
CREATE TYPE payment_status AS ENUM ('pending', 'completed', 'failed', 'refunded');
CREATE TYPE payment_type AS ENUM ('announcement', 'boost', 'extension', 'extra_announcement');
CREATE TYPE booking_status AS ENUM ('pending', 'accepted', 'rejected', 'cancelled', 'completed');
CREATE TYPE report_status AS ENUM ('pending', 'reviewed', 'resolved', 'dismissed');
CREATE TYPE alert_status AS ENUM ('active', 'paused', 'expired');
CREATE TYPE notification_type AS ENUM ('alert_match', 'booking_update', 'chat_message', 'payment', 'system', 'moderation');

-- ============================================================
-- TABLE: profiles (extension de auth.users)
-- ============================================================

CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  email TEXT,
  avatar_url TEXT,
  role user_role NOT NULL DEFAULT 'client',
  bio TEXT,
  city TEXT,
  country TEXT DEFAULT 'Gabon',
  identity_verified BOOLEAN DEFAULT FALSE,
  phone_verified BOOLEAN DEFAULT FALSE,
  rating_avg DECIMAL(3,2) DEFAULT 0.00,
  rating_count INTEGER DEFAULT 0,
  onesignal_player_id TEXT, -- pour push notifications
  is_banned BOOLEAN DEFAULT FALSE,
  ban_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_profiles_phone ON profiles(phone);
CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_profiles_city ON profiles(city);

-- ============================================================
-- TABLE: announcements (annonces de voyageurs)
-- ============================================================

CREATE TABLE announcements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Trajet
  departure_city TEXT NOT NULL,
  departure_country TEXT NOT NULL DEFAULT 'Gabon',
  arrival_city TEXT NOT NULL,
  arrival_country TEXT NOT NULL,
  departure_date DATE NOT NULL,
  arrival_date DATE,

  -- Bagages
  available_kg DECIMAL(5,2) NOT NULL CHECK (available_kg > 0),
  reserved_kg DECIMAL(5,2) DEFAULT 0,
  price_per_kg INTEGER NOT NULL CHECK (price_per_kg > 0), -- en FCFA

  -- Details
  description TEXT,
  accepted_items TEXT[], -- types de colis acceptes
  refused_items TEXT[], -- types de colis refuses

  -- Annonce
  type announcement_type NOT NULL DEFAULT 'standard',
  status announcement_status NOT NULL DEFAULT 'pending_payment',
  published_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,

  -- Stats
  views_count INTEGER DEFAULT 0,
  contacts_count INTEGER DEFAULT 0,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_announcements_user ON announcements(user_id);
CREATE INDEX idx_announcements_status ON announcements(status);
CREATE INDEX idx_announcements_departure ON announcements(departure_city, departure_country);
CREATE INDEX idx_announcements_arrival ON announcements(arrival_city, arrival_country);
CREATE INDEX idx_announcements_date ON announcements(departure_date);
CREATE INDEX idx_announcements_expires ON announcements(expires_at);
CREATE INDEX idx_announcements_type ON announcements(type);

-- Contrainte : 1 seule annonce active par utilisateur
CREATE UNIQUE INDEX idx_one_active_per_user
  ON announcements(user_id)
  WHERE status = 'active';

-- ============================================================
-- TABLE: alerts (alertes des clients)
-- ============================================================

CREATE TABLE alerts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Criteres de recherche
  departure_city TEXT,
  departure_country TEXT,
  arrival_city TEXT,
  arrival_country TEXT,
  date_from DATE,
  date_to DATE,
  min_kg DECIMAL(5,2),
  max_price_per_kg INTEGER, -- en FCFA

  status alert_status NOT NULL DEFAULT 'active',
  last_matched_at TIMESTAMPTZ,
  match_count INTEGER DEFAULT 0,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '30 days')
);

CREATE INDEX idx_alerts_user ON alerts(user_id);
CREATE INDEX idx_alerts_status ON alerts(status);
CREATE INDEX idx_alerts_departure ON alerts(departure_city);
CREATE INDEX idx_alerts_arrival ON alerts(arrival_city);

-- ============================================================
-- TABLE: bookings (reservations de kilos)
-- ============================================================

CREATE TABLE bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  announcement_id UUID NOT NULL REFERENCES announcements(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  voyageur_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  kg_reserved DECIMAL(5,2) NOT NULL CHECK (kg_reserved > 0),
  total_price INTEGER NOT NULL, -- en FCFA

  status booking_status NOT NULL DEFAULT 'pending',

  client_note TEXT,
  voyageur_note TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_bookings_announcement ON bookings(announcement_id);
CREATE INDEX idx_bookings_client ON bookings(client_id);
CREATE INDEX idx_bookings_voyageur ON bookings(voyageur_id);
CREATE INDEX idx_bookings_status ON bookings(status);

-- ============================================================
-- TABLE: payments
-- ============================================================

CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  announcement_id UUID REFERENCES announcements(id) ON DELETE SET NULL,

  type payment_type NOT NULL,
  amount INTEGER NOT NULL, -- en FCFA
  currency TEXT NOT NULL DEFAULT 'XAF',

  -- CinetPay
  provider TEXT NOT NULL DEFAULT 'cinetpay',
  provider_transaction_id TEXT,
  provider_payment_url TEXT,

  status payment_status NOT NULL DEFAULT 'pending',

  paid_at TIMESTAMPTZ,
  metadata JSONB DEFAULT '{}',

  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_payments_user ON payments(user_id);
CREATE INDEX idx_payments_announcement ON payments(announcement_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_provider_tx ON payments(provider_transaction_id);

-- ============================================================
-- TABLE: conversations (chat)
-- ============================================================

CREATE TABLE conversations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  announcement_id UUID REFERENCES announcements(id) ON DELETE SET NULL,

  participant_1 UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  participant_2 UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  last_message_at TIMESTAMPTZ,
  last_message_preview TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW(),

  CONSTRAINT unique_conversation UNIQUE (participant_1, participant_2, announcement_id)
);

CREATE INDEX idx_conversations_p1 ON conversations(participant_1);
CREATE INDEX idx_conversations_p2 ON conversations(participant_2);
CREATE INDEX idx_conversations_last_msg ON conversations(last_message_at DESC);

-- ============================================================
-- TABLE: messages
-- ============================================================

CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  content TEXT NOT NULL,
  image_url TEXT,

  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_messages_conversation ON messages(conversation_id, created_at DESC);
CREATE INDEX idx_messages_sender ON messages(sender_id);
CREATE INDEX idx_messages_unread ON messages(conversation_id) WHERE is_read = FALSE;

-- ============================================================
-- TABLE: reviews (avis)
-- ============================================================

CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  reviewer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reviewed_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW(),

  CONSTRAINT unique_review UNIQUE (booking_id, reviewer_id)
);

CREATE INDEX idx_reviews_reviewed ON reviews(reviewed_id);

-- ============================================================
-- TABLE: reports (signalements)
-- ============================================================

CREATE TABLE reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reporter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reported_user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  reported_announcement_id UUID REFERENCES announcements(id) ON DELETE CASCADE,

  reason TEXT NOT NULL,
  description TEXT,
  status report_status NOT NULL DEFAULT 'pending',

  admin_note TEXT,
  reviewed_by UUID REFERENCES profiles(id),
  reviewed_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_reports_status ON reports(status);

-- ============================================================
-- TABLE: notifications
-- ============================================================

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  type notification_type NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,

  data JSONB DEFAULT '{}', -- donnees supplementaires (announcement_id, booking_id, etc.)

  is_read BOOLEAN DEFAULT FALSE,
  is_pushed BOOLEAN DEFAULT FALSE, -- envoyee via OneSignal?

  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id, created_at DESC);
CREATE INDEX idx_notifications_unread ON notifications(user_id) WHERE is_read = FALSE;

-- ============================================================
-- TABLE: cities (reference pour autocompletion)
-- ============================================================

CREATE TABLE cities (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  country TEXT NOT NULL,
  country_code TEXT NOT NULL,
  has_airport BOOLEAN DEFAULT FALSE,
  is_popular BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_cities_name ON cities USING gin (name gin_trgm_ops);
CREATE INDEX idx_cities_country ON cities(country);

-- ============================================================
-- TABLE: app_config (configuration globale)
-- ============================================================

CREATE TABLE app_config (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Inserer prix par defaut
INSERT INTO app_config (key, value) VALUES
  ('pricing', '{
    "standard_announcement": 1500,
    "boosted_announcement": 3000,
    "extension": 1000,
    "extra_announcement": 2000,
    "announcement_duration_days": 7,
    "boost_duration_days": 7,
    "extension_duration_days": 7,
    "currency": "XAF"
  }'),
  ('moderation', '{
    "auto_approve": false,
    "max_reports_before_suspend": 3
  }');

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Fonction : mettre a jour updated_at automatiquement
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_profiles_updated BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER tr_announcements_updated BEFORE UPDATE ON announcements
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER tr_bookings_updated BEFORE UPDATE ON bookings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Fonction : mettre a jour la moyenne de notation
CREATE OR REPLACE FUNCTION update_user_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE profiles SET
    rating_avg = (SELECT AVG(rating) FROM reviews WHERE reviewed_id = NEW.reviewed_id),
    rating_count = (SELECT COUNT(*) FROM reviews WHERE reviewed_id = NEW.reviewed_id)
  WHERE id = NEW.reviewed_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_review_rating AFTER INSERT ON reviews
  FOR EACH ROW EXECUTE FUNCTION update_user_rating();

-- Fonction : mettre a jour reserved_kg quand booking accepte
CREATE OR REPLACE FUNCTION update_reserved_kg()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'accepted' AND (OLD.status IS NULL OR OLD.status != 'accepted') THEN
    UPDATE announcements
    SET reserved_kg = reserved_kg + NEW.kg_reserved
    WHERE id = NEW.announcement_id;
  ELSIF OLD.status = 'accepted' AND NEW.status != 'accepted' THEN
    UPDATE announcements
    SET reserved_kg = GREATEST(0, reserved_kg - NEW.kg_reserved)
    WHERE id = NEW.announcement_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_booking_kg AFTER UPDATE ON bookings
  FOR EACH ROW EXECUTE FUNCTION update_reserved_kg();

-- Fonction : expirer les annonces
CREATE OR REPLACE FUNCTION expire_announcements()
RETURNS void AS $$
BEGIN
  UPDATE announcements
  SET status = 'expired'
  WHERE status = 'active' AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Fonction : matcher alertes avec nouvelle annonce
CREATE OR REPLACE FUNCTION match_alerts_for_announcement(p_announcement_id UUID)
RETURNS TABLE(alert_id UUID, user_id UUID) AS $$
BEGIN
  RETURN QUERY
  SELECT a.id, a.user_id
  FROM alerts a
  JOIN announcements ann ON ann.id = p_announcement_id
  WHERE a.status = 'active'
    AND (a.departure_city IS NULL OR LOWER(a.departure_city) = LOWER(ann.departure_city))
    AND (a.departure_country IS NULL OR LOWER(a.departure_country) = LOWER(ann.departure_country))
    AND (a.arrival_city IS NULL OR LOWER(a.arrival_city) = LOWER(ann.arrival_city))
    AND (a.arrival_country IS NULL OR LOWER(a.arrival_country) = LOWER(ann.arrival_country))
    AND (a.date_from IS NULL OR ann.departure_date >= a.date_from)
    AND (a.date_to IS NULL OR ann.departure_date <= a.date_to)
    AND (a.min_kg IS NULL OR (ann.available_kg - ann.reserved_kg) >= a.min_kg)
    AND (a.max_price_per_kg IS NULL OR ann.price_per_kg <= a.max_price_per_kg)
    AND a.user_id != ann.user_id; -- pas notifier le voyageur lui-meme
END;
$$ LANGUAGE plpgsql;

-- Fonction : creer le profil automatiquement a l'inscription
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, full_name, phone, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.phone, NEW.raw_user_meta_data->>'phone', ''),
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- DONNEES DE REFERENCE : Villes
-- ============================================================

INSERT INTO cities (name, country, country_code, has_airport, is_popular) VALUES
  -- Gabon
  ('Libreville', 'Gabon', 'GA', TRUE, TRUE),
  ('Port-Gentil', 'Gabon', 'GA', TRUE, TRUE),
  ('Franceville', 'Gabon', 'GA', TRUE, FALSE),
  ('Oyem', 'Gabon', 'GA', TRUE, FALSE),
  ('Lambarene', 'Gabon', 'GA', TRUE, FALSE),
  -- France
  ('Paris', 'France', 'FR', TRUE, TRUE),
  ('Marseille', 'France', 'FR', TRUE, FALSE),
  ('Lyon', 'France', 'FR', TRUE, FALSE),
  -- Cameroun
  ('Douala', 'Cameroun', 'CM', TRUE, TRUE),
  ('Yaounde', 'Cameroun', 'CM', TRUE, TRUE),
  -- Autres
  ('Casablanca', 'Maroc', 'MA', TRUE, FALSE),
  ('Istanbul', 'Turquie', 'TR', TRUE, FALSE),
  ('Dubai', 'Emirats Arabes Unis', 'AE', TRUE, TRUE),
  ('Brazzaville', 'Congo', 'CG', TRUE, FALSE),
  ('Dakar', 'Senegal', 'SN', TRUE, FALSE),
  ('Abidjan', 'Cote d''Ivoire', 'CI', TRUE, TRUE);
