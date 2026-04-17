-- Rename price_extra_kg → price_extra_announcement
-- La valeur correspond au prix d'une annonce supplémentaire (au-delà
-- de la limite de 1 annonce active), pas au prix au kg.

UPDATE app_config
SET key = 'price_extra_announcement',
    description = 'Prix annonce supplémentaire (FCFA)'
WHERE key = 'price_extra_kg';
