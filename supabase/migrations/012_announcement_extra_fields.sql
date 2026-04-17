-- Ajout des colonnes optionnelles utilisées par le mobile mais manquantes en DB
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS airline TEXT;
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS flight_number TEXT;
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS collect_at_airport BOOLEAN DEFAULT TRUE;
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS deliver_to_address BOOLEAN DEFAULT FALSE;
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS meeting_point TEXT;
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS booked_kg DECIMAL(5,2) DEFAULT 0;

-- Rename rejected_items → refused_items (ou plutôt, le service utilise rejected_items
-- mais le schéma initial a refused_items ; on ajoute rejected_items pour compat)
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS rejected_items TEXT[];
UPDATE announcements SET rejected_items = refused_items WHERE rejected_items IS NULL AND refused_items IS NOT NULL;
