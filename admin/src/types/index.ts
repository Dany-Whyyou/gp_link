export type UserRole = "client" | "voyageur" | "admin";

export type AnnouncementStatus =
  | "pending_payment"
  | "active"
  | "expired"
  | "suspended"
  | "completed";

export type AnnouncementType = "standard" | "boosted";

export type PaymentStatus = "pending" | "completed" | "failed" | "expired" | "refunded";

export type PaymentType =
  | "announcement"
  | "boost"
  | "extension"
  | "extra_announcement";

export type MobileMoneyOperator = "AIRTEL_MONEY" | "MOOV_MONEY" | "TEST";

export type BookingStatus =
  | "pending"
  | "accepted"
  | "rejected"
  | "cancelled"
  | "completed";

export type ReportStatus = "pending" | "reviewed" | "resolved" | "dismissed";

export interface Profile {
  id: string;
  email: string;
  full_name: string;
  phone: string | null;
  avatar_url: string | null;
  role: UserRole;
  is_verified: boolean;
  is_banned: boolean;
  ban_reason: string | null;
  identity_document_url: string | null;
  created_at: string;
  updated_at: string;
}

export interface Announcement {
  id: string;
  user_id: string;
  type: AnnouncementType;
  status: AnnouncementStatus;
  departure_city_id: string | null;
  arrival_city_id: string | null;
  departure_city_name: string | null;
  arrival_city_name: string | null;
  departure_date: string;
  available_kg: number;
  price_per_kg: number;
  description: string | null;
  created_at: string;
  updated_at: string;
  expires_at: string | null;
  profiles?: Profile;
}

export interface Payment {
  id: string;
  user_id: string;
  announcement_id: string | null;
  type: PaymentType;
  amount: number;
  currency: string;
  provider: string;
  status: PaymentStatus;
  reference: string | null;
  mypvit_transaction_id: string | null;
  payment_method: string | null;
  operator: MobileMoneyOperator | null;
  phone_number: string | null;
  paid_at: string | null;
  failed_at: string | null;
  needs_review: boolean;
  metadata: Record<string, unknown> | null;
  created_at: string;
  profiles?: Profile;
  announcements?: Announcement;
}

export interface Booking {
  id: string;
  announcement_id: string;
  sender_id: string;
  traveler_id: string;
  kg_reserved: number;
  total_price: number;
  status: BookingStatus;
  created_at: string;
  updated_at: string;
}

export interface Report {
  id: string;
  reporter_id: string;
  reported_user_id: string | null;
  reported_announcement_id: string | null;
  reason: string;
  details: string | null;
  status: ReportStatus;
  admin_notes: string | null;
  resolved_by: string | null;
  resolved_at: string | null;
  created_at: string;
  updated_at: string;
  reporter?: Profile;
  reported_user?: Profile;
  reported_announcement?: Announcement;
}

export interface AppConfig {
  id: string;
  key: string;
  value: string;
  description: string | null;
  updated_at: string;
}

export interface City {
  id: string;
  name: string;
  country: string;
  country_code: string;
}

export interface DashboardStats {
  totalUsers: number;
  activeAnnouncements: number;
  totalRevenue: number;
  pendingReports: number;
  newUsersThisMonth: number;
  completedPayments: number;
}
