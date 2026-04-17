-- ============================================================
-- GP LINK - Migration MyPvit (remplace CinetPay)
-- ============================================================

-- Retirer l'ancien defaut CinetPay, renommer les colonnes generiques
ALTER TABLE payments ALTER COLUMN provider DROP DEFAULT;
ALTER TABLE payments ALTER COLUMN provider SET DEFAULT 'mypvit';
UPDATE payments SET provider = 'mypvit' WHERE provider = 'cinetpay';

-- Renommer provider_transaction_id -> reference (notre reference interne)
ALTER TABLE payments RENAME COLUMN provider_transaction_id TO reference;

-- Ajouter les colonnes MyPvit
ALTER TABLE payments ADD COLUMN IF NOT EXISTS mypvit_transaction_id TEXT;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS operator TEXT;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS phone_number TEXT;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS payment_method TEXT;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS failed_at TIMESTAMPTZ;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS needs_review BOOLEAN DEFAULT FALSE;

-- provider_payment_url ne sert plus (MyPvit utilise USSD push)
ALTER TABLE payments DROP COLUMN IF EXISTS provider_payment_url;

-- Ajouter 'expired' au enum payment_status
ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'expired';

-- Index pour les webhook lookups
CREATE INDEX IF NOT EXISTS idx_payments_reference ON payments(reference);
CREATE INDEX IF NOT EXISTS idx_payments_mypvit_tx ON payments(mypvit_transaction_id);
CREATE INDEX IF NOT EXISTS idx_payments_pending_recent ON payments(created_at) WHERE status = 'pending';

-- ============================================================
-- TABLE: mypvit_secrets (cache du secret avec TTL)
-- ============================================================

CREATE TABLE IF NOT EXISTS mypvit_secrets (
  id TEXT PRIMARY KEY DEFAULT 'current',
  secret TEXT NOT NULL,
  received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '50 minutes'),
  CHECK (id = 'current')
);

ALTER TABLE mypvit_secrets ENABLE ROW LEVEL SECURITY;

-- Seul le service_role peut y acceder (pas de policy = pas d'acces anon/authenticated)

-- ============================================================
-- FONCTION : marquer les paiements en attente comme expires (> 30 min)
-- ============================================================

CREATE OR REPLACE FUNCTION expire_stale_payments()
RETURNS INTEGER AS $$
DECLARE
  affected INTEGER;
BEGIN
  UPDATE payments
  SET status = 'expired',
      failed_at = NOW()
  WHERE status = 'pending'
    AND created_at < NOW() - INTERVAL '30 minutes';
  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- MISE A JOUR DES DUREES PAR DEFAUT DANS app_config
-- ============================================================

UPDATE app_config
SET value = jsonb_set(value, '{provider}', '"mypvit"'::jsonb)
WHERE key = 'pricing';
