-- ============================================================
-- Devise par pays + tarification multi-devises
-- ============================================================

-- 1. Ajouter currency_code + currency_symbol aux pays
ALTER TABLE countries ADD COLUMN IF NOT EXISTS currency_code TEXT NOT NULL DEFAULT 'XAF';
ALTER TABLE countries ADD COLUMN IF NOT EXISTS currency_symbol TEXT NOT NULL DEFAULT 'FCFA';

-- 2. Associer les devises aux pays existants
UPDATE countries SET currency_code='XAF', currency_symbol='FCFA' WHERE code IN ('GA','CM','CG','CF','TG','BJ','CI','SN');
UPDATE countries SET currency_code='EUR', currency_symbol='€' WHERE code IN ('FR','BE');
UPDATE countries SET currency_code='USD', currency_symbol='$' WHERE code='US';
UPDATE countries SET currency_code='GHS', currency_symbol='GH₵' WHERE code='GH';
UPDATE countries SET currency_code='MAD', currency_symbol='DH' WHERE code='MA';
UPDATE countries SET currency_code='TRY', currency_symbol='₺' WHERE code='TR';
UPDATE countries SET currency_code='AED', currency_symbol='AED' WHERE code='AE';

-- 3. Seed des prix par devise dans app_config (valeurs de référence, modifiables depuis le BO)
INSERT INTO app_config (key, value, description) VALUES
  -- XAF (FCFA) - déjà présents via price_standard etc. mais on dédouble pour cohérence
  ('price_standard_XAF', '"1500"'::jsonb, 'Prix annonce standard (FCFA)'),
  ('price_boosted_XAF', '"3000"'::jsonb, 'Prix annonce boostée (FCFA)'),
  ('price_extension_XAF', '"1000"'::jsonb, 'Prix extension (FCFA)'),
  ('price_extra_announcement_XAF', '"2000"'::jsonb, 'Prix annonce supplémentaire (FCFA)'),
  -- EUR
  ('price_standard_EUR', '"3"'::jsonb, 'Prix annonce standard (€)'),
  ('price_boosted_EUR', '"5"'::jsonb, 'Prix annonce boostée (€)'),
  ('price_extension_EUR', '"2"'::jsonb, 'Prix extension (€)'),
  ('price_extra_announcement_EUR', '"4"'::jsonb, 'Prix annonce supplémentaire (€)'),
  -- USD
  ('price_standard_USD', '"3"'::jsonb, 'Prix annonce standard ($)'),
  ('price_boosted_USD', '"5"'::jsonb, 'Prix annonce boostée ($)'),
  ('price_extension_USD', '"2"'::jsonb, 'Prix extension ($)'),
  ('price_extra_announcement_USD', '"4"'::jsonb, 'Prix annonce supplémentaire ($)')
ON CONFLICT (key) DO NOTHING;
