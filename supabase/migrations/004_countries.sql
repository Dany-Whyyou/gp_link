-- ============================================================
-- GP LINK - Migration pays uniquement (les villes ne sont plus requises)
-- ============================================================

-- 1. Nouvelle table countries (référence, lecture publique)
CREATE TABLE IF NOT EXISTS countries (
  code TEXT PRIMARY KEY,           -- ISO 3166-1 alpha-2
  name TEXT NOT NULL,
  flag_emoji TEXT,
  is_popular BOOLEAN DEFAULT FALSE
);

ALTER TABLE countries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "countries_select_public"
  ON countries FOR SELECT
  USING (TRUE);

CREATE POLICY "countries_admin_all"
  ON countries FOR ALL
  USING (is_admin());

-- 2. Seed : les 9 existants + 6 nouveaux
INSERT INTO countries (code, name, flag_emoji, is_popular) VALUES
  ('GA', 'Gabon', '🇬🇦', TRUE),
  ('FR', 'France', '🇫🇷', TRUE),
  ('CM', 'Cameroun', '🇨🇲', TRUE),
  ('CG', 'Congo', '🇨🇬', TRUE),
  ('CI', 'Côte d''Ivoire', '🇨🇮', TRUE),
  ('SN', 'Sénégal', '🇸🇳', TRUE),
  ('US', 'États-Unis', '🇺🇸', TRUE),
  ('BE', 'Belgique', '🇧🇪', TRUE),
  ('CF', 'République Centrafricaine', '🇨🇫', FALSE),
  ('TG', 'Togo', '🇹🇬', FALSE),
  ('BJ', 'Bénin', '🇧🇯', FALSE),
  ('GH', 'Ghana', '🇬🇭', FALSE),
  ('MA', 'Maroc', '🇲🇦', FALSE),
  ('TR', 'Turquie', '🇹🇷', FALSE),
  ('AE', 'Émirats Arabes Unis', '🇦🇪', FALSE)
ON CONFLICT (code) DO UPDATE
  SET name = EXCLUDED.name,
      flag_emoji = EXCLUDED.flag_emoji,
      is_popular = EXCLUDED.is_popular;

-- 3. Rendre les colonnes city nullable (on ne les exige plus)
ALTER TABLE announcements ALTER COLUMN departure_city DROP NOT NULL;
ALTER TABLE announcements ALTER COLUMN arrival_city DROP NOT NULL;

-- 4. Mise à jour de la fonction de matching : on matche sur PAYS uniquement
CREATE OR REPLACE FUNCTION match_alerts_for_announcement(p_announcement_id UUID)
RETURNS TABLE(alert_id UUID, user_id UUID) AS $$
BEGIN
  RETURN QUERY
  SELECT a.id, a.user_id
  FROM alerts a
  JOIN announcements ann ON ann.id = p_announcement_id
  WHERE a.status = 'active'
    AND (a.departure_country IS NULL OR LOWER(a.departure_country) = LOWER(ann.departure_country))
    AND (a.arrival_country IS NULL OR LOWER(a.arrival_country) = LOWER(ann.arrival_country))
    AND (a.date_from IS NULL OR ann.departure_date >= a.date_from)
    AND (a.date_to IS NULL OR ann.departure_date <= a.date_to)
    AND (a.min_kg IS NULL OR (ann.available_kg - ann.reserved_kg) >= a.min_kg)
    AND (a.max_price_per_kg IS NULL OR ann.price_per_kg <= a.max_price_per_kg)
    AND a.user_id != ann.user_id;
END;
$$ LANGUAGE plpgsql;

-- 5. Index pour les recherches par pays
CREATE INDEX IF NOT EXISTS idx_announcements_departure_country
  ON announcements(departure_country);
CREATE INDEX IF NOT EXISTS idx_announcements_arrival_country
  ON announcements(arrival_country);
