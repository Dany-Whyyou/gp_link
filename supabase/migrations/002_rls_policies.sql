-- ============================================================
-- GP LINK - Row Level Security Policies
-- ============================================================

-- Activer RLS sur toutes les tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE cities ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Helper : verifier si admin
-- ============================================================

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- PROFILES
-- ============================================================

-- Tout le monde peut voir les profils publics
CREATE POLICY "profiles_select_public"
  ON profiles FOR SELECT
  USING (TRUE);

-- Un utilisateur peut modifier son propre profil
CREATE POLICY "profiles_update_own"
  ON profiles FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Les admins peuvent tout modifier
CREATE POLICY "profiles_admin_all"
  ON profiles FOR ALL
  USING (is_admin());

-- ============================================================
-- ANNOUNCEMENTS
-- ============================================================

-- Tout le monde peut voir les annonces actives
CREATE POLICY "announcements_select_active"
  ON announcements FOR SELECT
  USING (status = 'active' OR user_id = auth.uid() OR is_admin());

-- Un utilisateur peut creer une annonce
CREATE POLICY "announcements_insert_own"
  ON announcements FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Un utilisateur peut modifier ses propres annonces
CREATE POLICY "announcements_update_own"
  ON announcements FOR UPDATE
  USING (user_id = auth.uid() OR is_admin());

-- Un utilisateur peut supprimer ses propres annonces
CREATE POLICY "announcements_delete_own"
  ON announcements FOR DELETE
  USING (user_id = auth.uid() OR is_admin());

-- ============================================================
-- ALERTS
-- ============================================================

-- Un utilisateur voit ses propres alertes
CREATE POLICY "alerts_select_own"
  ON alerts FOR SELECT
  USING (user_id = auth.uid() OR is_admin());

-- Un utilisateur peut creer ses alertes
CREATE POLICY "alerts_insert_own"
  ON alerts FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Un utilisateur peut modifier ses alertes
CREATE POLICY "alerts_update_own"
  ON alerts FOR UPDATE
  USING (user_id = auth.uid());

-- Un utilisateur peut supprimer ses alertes
CREATE POLICY "alerts_delete_own"
  ON alerts FOR DELETE
  USING (user_id = auth.uid());

-- ============================================================
-- BOOKINGS
-- ============================================================

-- Les participants voient leurs bookings
CREATE POLICY "bookings_select_own"
  ON bookings FOR SELECT
  USING (client_id = auth.uid() OR voyageur_id = auth.uid() OR is_admin());

-- Un client peut creer un booking
CREATE POLICY "bookings_insert_client"
  ON bookings FOR INSERT
  WITH CHECK (client_id = auth.uid());

-- Les participants peuvent mettre a jour
CREATE POLICY "bookings_update_participants"
  ON bookings FOR UPDATE
  USING (client_id = auth.uid() OR voyageur_id = auth.uid() OR is_admin());

-- ============================================================
-- PAYMENTS
-- ============================================================

-- Un utilisateur voit ses propres paiements
CREATE POLICY "payments_select_own"
  ON payments FOR SELECT
  USING (user_id = auth.uid() OR is_admin());

-- Un utilisateur peut creer un paiement
CREATE POLICY "payments_insert_own"
  ON payments FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Seul le systeme/admin peut mettre a jour un paiement
CREATE POLICY "payments_update_admin"
  ON payments FOR UPDATE
  USING (is_admin());

-- ============================================================
-- CONVERSATIONS
-- ============================================================

-- Les participants voient leurs conversations
CREATE POLICY "conversations_select_own"
  ON conversations FOR SELECT
  USING (participant_1 = auth.uid() OR participant_2 = auth.uid() OR is_admin());

-- Un utilisateur peut creer une conversation
CREATE POLICY "conversations_insert_participant"
  ON conversations FOR INSERT
  WITH CHECK (participant_1 = auth.uid() OR participant_2 = auth.uid());

-- ============================================================
-- MESSAGES
-- ============================================================

-- Les participants de la conversation voient les messages
CREATE POLICY "messages_select_conversation"
  ON messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = messages.conversation_id
      AND (c.participant_1 = auth.uid() OR c.participant_2 = auth.uid())
    )
    OR is_admin()
  );

-- Un participant peut envoyer un message
CREATE POLICY "messages_insert_sender"
  ON messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = conversation_id
      AND (c.participant_1 = auth.uid() OR c.participant_2 = auth.uid())
    )
  );

-- Mettre a jour le statut lu
CREATE POLICY "messages_update_read"
  ON messages FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = messages.conversation_id
      AND (c.participant_1 = auth.uid() OR c.participant_2 = auth.uid())
    )
  );

-- ============================================================
-- REVIEWS
-- ============================================================

-- Tout le monde peut voir les avis
CREATE POLICY "reviews_select_public"
  ON reviews FOR SELECT
  USING (TRUE);

-- Un utilisateur peut laisser un avis
CREATE POLICY "reviews_insert_own"
  ON reviews FOR INSERT
  WITH CHECK (reviewer_id = auth.uid());

-- ============================================================
-- REPORTS
-- ============================================================

-- Un utilisateur voit ses propres signalements
CREATE POLICY "reports_select_own"
  ON reports FOR SELECT
  USING (reporter_id = auth.uid() OR is_admin());

-- Un utilisateur peut creer un signalement
CREATE POLICY "reports_insert_own"
  ON reports FOR INSERT
  WITH CHECK (reporter_id = auth.uid());

-- Admin peut modifier
CREATE POLICY "reports_update_admin"
  ON reports FOR UPDATE
  USING (is_admin());

-- ============================================================
-- NOTIFICATIONS
-- ============================================================

-- Un utilisateur voit ses propres notifications
CREATE POLICY "notifications_select_own"
  ON notifications FOR SELECT
  USING (user_id = auth.uid());

-- Systeme peut inserer (via service_role)
CREATE POLICY "notifications_insert_system"
  ON notifications FOR INSERT
  WITH CHECK (user_id = auth.uid() OR is_admin());

-- Un utilisateur peut marquer comme lu
CREATE POLICY "notifications_update_own"
  ON notifications FOR UPDATE
  USING (user_id = auth.uid());

-- ============================================================
-- CITIES (lecture publique)
-- ============================================================

CREATE POLICY "cities_select_public"
  ON cities FOR SELECT
  USING (TRUE);

CREATE POLICY "cities_admin_all"
  ON cities FOR ALL
  USING (is_admin());

-- ============================================================
-- APP_CONFIG (lecture publique, ecriture admin)
-- ============================================================

CREATE POLICY "app_config_select_public"
  ON app_config FOR SELECT
  USING (TRUE);

CREATE POLICY "app_config_admin_all"
  ON app_config FOR ALL
  USING (is_admin());
