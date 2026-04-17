-- Système de promotions : N annonces gratuites par user pendant une période
INSERT INTO app_config (key, value, description) VALUES
  ('promo_active', '"false"'::jsonb, 'Promo : N annonces gratuites pendant une periode'),
  ('promo_free_count', '"3"'::jsonb, 'Promo : nombre d''annonces gratuites par user'),
  ('promo_start_date', '"2026-05-01"'::jsonb, 'Promo : date de debut (AAAA-MM-JJ)'),
  ('promo_end_date', '"2026-05-31"'::jsonb, 'Promo : date de fin (AAAA-MM-JJ)')
ON CONFLICT (key) DO NOTHING;
