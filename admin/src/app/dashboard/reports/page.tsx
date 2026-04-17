"use client";

import { useEffect, useState, useCallback } from "react";
import { createClient } from "@/lib/supabase-client";
import DataTable, { Column } from "@/components/DataTable";
import Badge from "@/components/Badge";
import Modal from "@/components/Modal";
import { formatDate, getStatusColor, truncate } from "@/lib/utils";
import type { Report, ReportStatus } from "@/types";

type ReportWithRelations = Report & {
  reporter: { full_name: string; email: string } | null;
  reported_user: { full_name: string; email: string } | null;
};

export default function ReportsPage() {
  const [reports, setReports] = useState<ReportWithRelations[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState<string>("pending");
  const [selectedReport, setSelectedReport] = useState<ReportWithRelations | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [adminNotes, setAdminNotes] = useState("");

  const loadReports = useCallback(async () => {
    setLoading(true);
    const supabase = createClient();

    let query = supabase
      .from("reports")
      .select(
        "*, reporter:profiles!reports_reporter_id_fkey(full_name, email), reported_user:profiles!reports_reported_user_id_fkey(full_name, email)"
      )
      .order("created_at", { ascending: false });

    if (statusFilter !== "all") {
      query = query.eq("status", statusFilter);
    }

    const { data } = await query.limit(100);
    setReports((data as ReportWithRelations[]) || []);
    setLoading(false);
  }, [statusFilter]);

  useEffect(() => {
    loadReports();
  }, [loadReports]);

  async function updateReport(id: string, status: ReportStatus) {
    setActionLoading(true);
    const supabase = createClient();

    const {
      data: { user },
    } = await supabase.auth.getUser();

    const { error } = await supabase
      .from("reports")
      .update({
        status,
        admin_notes: adminNotes || null,
        resolved_by: status === "resolved" || status === "dismissed" ? user?.id : null,
        resolved_at:
          status === "resolved" || status === "dismissed"
            ? new Date().toISOString()
            : null,
      })
      .eq("id", id);

    if (!error) {
      await loadReports();
      setModalOpen(false);
      setSelectedReport(null);
      setAdminNotes("");
    }
    setActionLoading(false);
  }

  async function banReportedUser(userId: string) {
    setActionLoading(true);
    const supabase = createClient();

    const { error } = await supabase
      .from("profiles")
      .update({
        is_banned: true,
        ban_reason: `Suite au signalement: ${selectedReport?.reason || ""}`,
      })
      .eq("id", userId);

    if (!error && selectedReport) {
      await updateReport(selectedReport.id, "resolved");
    }
    setActionLoading(false);
  }

  async function suspendAnnouncement(announcementId: string) {
    setActionLoading(true);
    const supabase = createClient();

    const { error } = await supabase
      .from("announcements")
      .update({ status: "suspended" })
      .eq("id", announcementId);

    if (!error && selectedReport) {
      await updateReport(selectedReport.id, "resolved");
    }
    setActionLoading(false);
  }

  const columns: Column<ReportWithRelations>[] = [
    {
      key: "reason",
      label: "Raison",
      render: (r) => (
        <div>
          <p className="font-medium text-gray-900">{r.reason}</p>
          {r.details && (
            <p className="text-xs text-gray-500 mt-0.5">
              {truncate(r.details, 60)}
            </p>
          )}
        </div>
      ),
    },
    {
      key: "reporter",
      label: "Signale par",
      render: (r) => (
        <span className="text-sm">{r.reporter?.full_name || "Inconnu"}</span>
      ),
    },
    {
      key: "reported_user",
      label: "Utilisateur signale",
      render: (r) => (
        <span className="text-sm">
          {r.reported_user?.full_name || (r.reported_announcement_id ? "Annonce" : "N/A")}
        </span>
      ),
    },
    {
      key: "status",
      label: "Statut",
      render: (r) => (
        <Badge color={getStatusColor(r.status)}>{r.status}</Badge>
      ),
    },
    {
      key: "created_at",
      label: "Date",
      sortable: true,
      render: (r) => <span className="text-gray-500">{formatDate(r.created_at)}</span>,
    },
    {
      key: "actions",
      label: "",
      render: (r) => (
        <button
          onClick={(e) => {
            e.stopPropagation();
            setSelectedReport(r);
            setAdminNotes(r.admin_notes || "");
            setModalOpen(true);
          }}
          className="text-primary-600 hover:text-primary-800 text-sm font-medium"
        >
          Traiter
        </button>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Signalements</h1>
        <p className="text-gray-500 mt-1">Moderation des signalements utilisateurs</p>
      </div>

      <div className="flex gap-4">
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="px-4 py-2.5 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none bg-white"
        >
          <option value="all">Tous</option>
          <option value="pending">En attente</option>
          <option value="reviewed">En revue</option>
          <option value="resolved">Resolus</option>
          <option value="dismissed">Rejetes</option>
        </select>
      </div>

      <DataTable
        columns={columns}
        data={reports as unknown as Record<string, unknown>[]}
        keyField="id"
        loading={loading}
        emptyMessage="Aucun signalement"
      />

      <Modal
        open={modalOpen}
        onClose={() => {
          setModalOpen(false);
          setSelectedReport(null);
          setAdminNotes("");
        }}
        title="Traitement du signalement"
        size="lg"
      >
        {selectedReport && (
          <div className="space-y-6">
            <div className="grid grid-cols-2 gap-4">
              <div className="bg-gray-50 rounded-lg p-4">
                <p className="text-xs text-gray-500 uppercase font-medium">Raison</p>
                <p className="text-sm font-medium mt-1">{selectedReport.reason}</p>
              </div>
              <div className="bg-gray-50 rounded-lg p-4">
                <p className="text-xs text-gray-500 uppercase font-medium">Statut</p>
                <Badge color={getStatusColor(selectedReport.status)}>
                  {selectedReport.status}
                </Badge>
              </div>
              <div className="bg-gray-50 rounded-lg p-4">
                <p className="text-xs text-gray-500 uppercase font-medium">Signale par</p>
                <p className="text-sm font-medium mt-1">
                  {selectedReport.reporter?.full_name || "Inconnu"}
                </p>
                <p className="text-xs text-gray-500">
                  {selectedReport.reporter?.email}
                </p>
              </div>
              <div className="bg-gray-50 rounded-lg p-4">
                <p className="text-xs text-gray-500 uppercase font-medium">Utilisateur signale</p>
                <p className="text-sm font-medium mt-1">
                  {selectedReport.reported_user?.full_name || "N/A"}
                </p>
                <p className="text-xs text-gray-500">
                  {selectedReport.reported_user?.email}
                </p>
              </div>
            </div>

            {selectedReport.details && (
              <div className="bg-gray-50 rounded-lg p-4">
                <p className="text-xs text-gray-500 uppercase font-medium">Details</p>
                <p className="text-sm mt-1">{selectedReport.details}</p>
              </div>
            )}

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Notes admin
              </label>
              <textarea
                value={adminNotes}
                onChange={(e) => setAdminNotes(e.target.value)}
                rows={3}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none"
                placeholder="Ajoutez vos notes..."
              />
            </div>

            {selectedReport.status === "pending" || selectedReport.status === "reviewed" ? (
              <div className="space-y-3">
                <div className="flex gap-3">
                  <button
                    onClick={() => updateReport(selectedReport.id, "reviewed")}
                    disabled={actionLoading || selectedReport.status === "reviewed"}
                    className="flex-1 py-2.5 rounded-lg text-sm font-medium bg-blue-100 text-blue-700 hover:bg-blue-200 transition-colors disabled:opacity-50"
                  >
                    Marquer en revue
                  </button>
                  <button
                    onClick={() => updateReport(selectedReport.id, "dismissed")}
                    disabled={actionLoading}
                    className="flex-1 py-2.5 rounded-lg text-sm font-medium bg-gray-100 text-gray-700 hover:bg-gray-200 transition-colors disabled:opacity-50"
                  >
                    Rejeter
                  </button>
                </div>

                <p className="text-xs text-gray-500 font-medium uppercase mt-4">Actions sur le signale</p>
                <div className="flex gap-3">
                  {selectedReport.reported_user_id && (
                    <button
                      onClick={() => banReportedUser(selectedReport.reported_user_id!)}
                      disabled={actionLoading}
                      className="flex-1 py-2.5 rounded-lg text-sm font-medium bg-red-600 text-white hover:bg-red-700 transition-colors disabled:opacity-50"
                    >
                      {actionLoading ? "..." : "Bannir l'utilisateur"}
                    </button>
                  )}
                  {selectedReport.reported_announcement_id && (
                    <button
                      onClick={() =>
                        suspendAnnouncement(selectedReport.reported_announcement_id!)
                      }
                      disabled={actionLoading}
                      className="flex-1 py-2.5 rounded-lg text-sm font-medium bg-orange-600 text-white hover:bg-orange-700 transition-colors disabled:opacity-50"
                    >
                      {actionLoading ? "..." : "Suspendre l'annonce"}
                    </button>
                  )}
                  <button
                    onClick={() => updateReport(selectedReport.id, "resolved")}
                    disabled={actionLoading}
                    className="flex-1 py-2.5 rounded-lg text-sm font-medium bg-green-600 text-white hover:bg-green-700 transition-colors disabled:opacity-50"
                  >
                    {actionLoading ? "..." : "Resoudre"}
                  </button>
                </div>
              </div>
            ) : (
              <div className="bg-gray-50 rounded-lg p-4 text-center text-sm text-gray-500">
                Ce signalement a ete {selectedReport.status === "resolved" ? "resolu" : "rejete"}.
                {selectedReport.resolved_at && (
                  <span> ({formatDate(selectedReport.resolved_at)})</span>
                )}
              </div>
            )}
          </div>
        )}
      </Modal>
    </div>
  );
}
