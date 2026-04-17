"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase-client";
import StatsCard from "@/components/StatsCard";
import Badge from "@/components/Badge";
import { formatCurrency, formatDate, getStatusColor } from "@/lib/utils";
import type { DashboardStats, Report, Payment } from "@/types";

export default function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [recentPayments, setRecentPayments] = useState<Payment[]>([]);
  const [recentReports, setRecentReports] = useState<Report[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadDashboard();
  }, []);

  async function loadDashboard() {
    const supabase = createClient();

    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();

    const [
      usersRes,
      newUsersRes,
      announcementsRes,
      revenueRes,
      reportsRes,
      paymentsRes,
      recentReportsRes,
    ] = await Promise.all([
      supabase.from("profiles").select("id", { count: "exact", head: true }),
      supabase.from("profiles").select("id", { count: "exact", head: true }).gte("created_at", startOfMonth),
      supabase.from("announcements").select("id", { count: "exact", head: true }).eq("status", "active"),
      supabase.from("payments").select("amount").eq("status", "completed"),
      supabase.from("reports").select("id", { count: "exact", head: true }).eq("status", "pending"),
      supabase.from("payments").select("*, profiles(full_name, email)").order("created_at", { ascending: false }).limit(5),
      supabase.from("reports").select("*, reporter:profiles!reports_reporter_id_fkey(full_name), reported_user:profiles!reports_reported_user_id_fkey(full_name)").order("created_at", { ascending: false }).limit(5),
    ]);

    const totalRevenue = (revenueRes.data || []).reduce((sum, p) => sum + (p.amount || 0), 0);

    setStats({
      totalUsers: usersRes.count || 0,
      activeAnnouncements: announcementsRes.count || 0,
      totalRevenue,
      pendingReports: reportsRes.count || 0,
      newUsersThisMonth: newUsersRes.count || 0,
      completedPayments: (revenueRes.data || []).length,
    });

    setRecentPayments((paymentsRes.data as unknown as Payment[]) || []);
    setRecentReports((recentReportsRes.data as unknown as Report[]) || []);
    setLoading(false);
  }

  if (loading) {
    return (
      <div className="space-y-6">
        <h1 className="text-2xl font-bold text-gray-900">Tableau de bord</h1>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className="bg-white rounded-xl border border-gray-200 p-6 animate-pulse">
              <div className="h-4 bg-gray-200 rounded w-1/2 mb-4" />
              <div className="h-8 bg-gray-200 rounded w-1/3" />
            </div>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Tableau de bord</h1>
        <p className="text-gray-500 mt-1">Vue d&apos;ensemble de la plateforme GP Link</p>
      </div>

      {/* Stats grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatsCard
          title="Utilisateurs"
          value={stats?.totalUsers || 0}
          subtitle={`+${stats?.newUsersThisMonth || 0} ce mois`}
          color="blue"
          icon={
            <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z" />
            </svg>
          }
        />
        <StatsCard
          title="Annonces actives"
          value={stats?.activeAnnouncements || 0}
          color="green"
          icon={
            <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M10.34 15.84c-.688-.06-1.386-.09-2.09-.09H7.5a4.5 4.5 0 110-9h.75c.704 0 1.402-.03 2.09-.09m0 9.18c.253.962.584 1.892.985 2.783.247.55.06 1.21-.463 1.511l-.657.38c-.551.318-1.26.117-1.527-.461a20.845 20.845 0 01-1.44-4.282m3.102.069a18.03 18.03 0 01-.59-4.59c0-1.586.205-3.124.59-4.59m0 9.18a23.848 23.848 0 018.835 2.535M10.34 6.66a23.847 23.847 0 008.835-2.535m0 0A23.74 23.74 0 0018.795 3m.38 1.125a23.91 23.91 0 011.014 5.395m-1.014 8.855c-.118.38-.245.754-.38 1.125m.38-1.125a23.91 23.91 0 001.014-5.395m0-3.46c.495.413.811 1.035.811 1.73 0 .695-.316 1.317-.811 1.73m0-3.46a24.347 24.347 0 010 3.46" />
            </svg>
          }
        />
        <StatsCard
          title="Revenus totaux"
          value={formatCurrency(stats?.totalRevenue || 0)}
          subtitle={`${stats?.completedPayments || 0} paiements`}
          color="purple"
          icon={
            <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M2.25 18.75a60.07 60.07 0 0115.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 013 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 00-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 01-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 003 15h-.75M15 10.5a3 3 0 11-6 0 3 3 0 016 0zm3 0h.008v.008H18V10.5zm-12 0h.008v.008H6V10.5z" />
            </svg>
          }
        />
        <StatsCard
          title="Signalements en attente"
          value={stats?.pendingReports || 0}
          color={stats?.pendingReports ? "red" : "green"}
          icon={
            <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M3 3v1.5M3 21v-6m0 0l2.77-.693a9 9 0 016.208.682l.108.054a9 9 0 006.086.71l3.114-.732a48.524 48.524 0 01-.005-10.499l-3.11.732a9 9 0 01-6.085-.711l-.108-.054a9 9 0 00-6.208-.682L3 4.5M3 15V4.5" />
            </svg>
          }
        />
      </div>

      {/* Recent activity */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent payments */}
        <div className="bg-white rounded-xl border border-gray-200">
          <div className="px-6 py-4 border-b border-gray-200">
            <h2 className="font-semibold text-gray-900">Paiements recents</h2>
          </div>
          <div className="divide-y divide-gray-100">
            {recentPayments.length === 0 ? (
              <p className="px-6 py-8 text-center text-gray-500 text-sm">Aucun paiement</p>
            ) : (
              recentPayments.map((p) => (
                <div key={p.id} className="px-6 py-3 flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-gray-900">
                      {(p.profiles as unknown as { full_name: string })?.full_name || "Utilisateur"}
                    </p>
                    <p className="text-xs text-gray-500">{formatDate(p.created_at)}</p>
                  </div>
                  <div className="flex items-center gap-3">
                    <Badge color={getStatusColor(p.status)}>{p.status}</Badge>
                    <span className="text-sm font-semibold text-gray-900">
                      {formatCurrency(p.amount)}
                    </span>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Recent reports */}
        <div className="bg-white rounded-xl border border-gray-200">
          <div className="px-6 py-4 border-b border-gray-200">
            <h2 className="font-semibold text-gray-900">Signalements recents</h2>
          </div>
          <div className="divide-y divide-gray-100">
            {recentReports.length === 0 ? (
              <p className="px-6 py-8 text-center text-gray-500 text-sm">Aucun signalement</p>
            ) : (
              recentReports.map((r) => (
                <div key={r.id} className="px-6 py-3 flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-gray-900">{r.reason}</p>
                    <p className="text-xs text-gray-500">
                      Par {(r.reporter as unknown as { full_name: string })?.full_name || "Inconnu"} - {formatDate(r.created_at)}
                    </p>
                  </div>
                  <Badge color={getStatusColor(r.status)}>{r.status}</Badge>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
