-- app_config.description : label humain utilisé par le dashboard admin
ALTER TABLE app_config ADD COLUMN IF NOT EXISTS description TEXT;
