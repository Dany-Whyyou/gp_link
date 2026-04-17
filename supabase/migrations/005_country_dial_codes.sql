-- ============================================================
-- GP LINK - Dial codes, phone formats, payment capabilities par pays
-- ============================================================

ALTER TABLE countries ADD COLUMN IF NOT EXISTS dial_code TEXT;
ALTER TABLE countries ADD COLUMN IF NOT EXISTS phone_example TEXT;
ALTER TABLE countries ADD COLUMN IF NOT EXISTS phone_min_digits INTEGER;
ALTER TABLE countries ADD COLUMN IF NOT EXISTS phone_max_digits INTEGER;
ALTER TABLE countries ADD COLUMN IF NOT EXISTS supports_mobile_money BOOLEAN DEFAULT FALSE;

-- Seed / update
UPDATE countries SET dial_code='+241', phone_example='77 73 06 34', phone_min_digits=8,  phone_max_digits=8,  supports_mobile_money=TRUE  WHERE code='GA';
UPDATE countries SET dial_code='+33',  phone_example='6 12 34 56 78', phone_min_digits=9,  phone_max_digits=9                            WHERE code='FR';
UPDATE countries SET dial_code='+237', phone_example='6 12 34 56 78', phone_min_digits=9,  phone_max_digits=9                            WHERE code='CM';
UPDATE countries SET dial_code='+242', phone_example='06 123 45 67',  phone_min_digits=9,  phone_max_digits=9                            WHERE code='CG';
UPDATE countries SET dial_code='+225', phone_example='07 12 34 56 78', phone_min_digits=10, phone_max_digits=10                          WHERE code='CI';
UPDATE countries SET dial_code='+221', phone_example='77 123 45 67',  phone_min_digits=9,  phone_max_digits=9                            WHERE code='SN';
UPDATE countries SET dial_code='+1',   phone_example='555 123 4567',   phone_min_digits=10, phone_max_digits=10                          WHERE code='US';
UPDATE countries SET dial_code='+32',  phone_example='470 12 34 56',   phone_min_digits=9,  phone_max_digits=9                           WHERE code='BE';
UPDATE countries SET dial_code='+236', phone_example='70 12 34 56',    phone_min_digits=8,  phone_max_digits=8                           WHERE code='CF';
UPDATE countries SET dial_code='+228', phone_example='90 12 34 56',    phone_min_digits=8,  phone_max_digits=8                           WHERE code='TG';
UPDATE countries SET dial_code='+229', phone_example='97 12 34 56',    phone_min_digits=8,  phone_max_digits=8                           WHERE code='BJ';
UPDATE countries SET dial_code='+233', phone_example='24 123 4567',    phone_min_digits=9,  phone_max_digits=9                           WHERE code='GH';
UPDATE countries SET dial_code='+212', phone_example='6 12 34 56 78',  phone_min_digits=9,  phone_max_digits=9                           WHERE code='MA';
UPDATE countries SET dial_code='+90',  phone_example='532 123 45 67',  phone_min_digits=10, phone_max_digits=10                          WHERE code='TR';
UPDATE countries SET dial_code='+971', phone_example='50 123 4567',    phone_min_digits=9,  phone_max_digits=9                           WHERE code='AE';
