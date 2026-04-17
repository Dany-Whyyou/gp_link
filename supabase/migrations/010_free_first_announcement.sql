-- Config pour offrir la première annonce standard (campagne d'acquisition)
INSERT INTO app_config (key, value, description) VALUES
  ('free_first_announcement', '"true"'::jsonb, 'Premiere annonce standard gratuite (campagne d''acquisition)')
ON CONFLICT (key) DO NOTHING;
