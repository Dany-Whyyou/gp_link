"use client";

import { useEffect, useState, useCallback } from "react";
import { createClient } from "@/lib/supabase-client";
import DataTable, { Column } from "@/components/DataTable";
import Badge from "@/components/Badge";
import Modal from "@/components/Modal";
import { formatDate, formatCurrency, getStatusColor } from "@/lib/utils";
import type { Announcement, AnnouncementStatus } from "@/types";

type AnnouncementWithProfile = Announcement & {
  profiles: { full_name: string; email: string } | null;
};

export default function AnnouncementsPage() {
  const [announcements, setAnnouncements] = useState<AnnouncementWithProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [search, setSearch] = useState("");
  const [selectedAnnouncement, setSelectedAnnouncement] = useState<AnnouncementWithProfile | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);

  const loadAnnouncements = useCallback(async () => {
    setLoading(true);
    const supabase = createClient();

    let query = supabase
      .from("announcements")
      .select("*, profiles(full_name, email)")
      .order("created_at", { ascending: false });

    if (statusFilter !== "all") {
      query = query.eq("status", statusFilter);
    }

    if (search) {
      query = query.or(`description.ilike.%${search}%,departure_city_name.ilike.%${search}%,arrival_city_name.ilike.%${search}%`);
    }

    const { data } = await query.limit(100);
    setAnnouncements((data as AnnouncementWithProfile[]) || []);
    setLoading(false);
  }, [statusFilter, search]);

  useEffect(() => {
    loadAnnouncements();
  }, [loadAnnouncements]);

  async function updateStatus(id: string, status: AnnouncementStatus) {
    setActionLoading(true);
    const supabase = createClient();

    const { error } = await supabase
      .from("announcements")
      .update({ status })
      .eq("id", id);

    if (!error) {
      await loadAnnouncements();
      setModalOpen(false);
      setSelectedAnnouncement(null);
    }
    setActionLoading(false);
  }

  const columns: Column<AnnouncementWithProfile>[] = [
    {
      key: "route",
      label: "Trajet",
      render: (a) => (
        <div>
          <p className="font-medium text-gray-900">
            {a.departure_city_name || "?"} → {a.arrival_city_name || "?"}
          </p>
          <p className="text-xs text-gray-500">{formatDate(a.departure_date)}</p>
        </div>
      ),
    },
    {
      key: "user",
      label: "Voyageur",
      render: (a) => (
        <span className="text-sm">{a.profiles?.full_name || "Inconnu"}</span>
      ),
    },
    {
      key: "type",
      label: "Type",
      render: (a) => (
        <Badge color={a.type === "boosted" ? "purple" : "gray"}>{a.type}</Badge>
      ),
    },
    {
      key: "available_kg",
      label: "Kg dispo",
      render: (a) => <span>{a.available_kg} kg</span>,
    },
    {
      key: "price_per_kg",
      label: "Prix/kg",
      render: (a) => <span>{formatCurrency(a.price_per_kg)}</span>,
    },
    {
      key: "status",
      label: "Statut",
      render: (a) => (
        <Badge color={getStatusColor(a.status)}>{a.status}</Badge>
      ),
    },
    {
      key: "created_at",
      label: "Cree le",
      sortable: true,
      render: (a) => <span className="text-gray-500">{formatDate(a.created_at)}</span>,
    },
    {
      key: "actions",
      label: "",
      render: (a) => (
        <button
          onClick={(e) => {
            e.stopPropagation();
            setSelectedAnnouncement(a);
            setModalOpen(true);
          }}
          className="text-primary-600 hover:text-primary-800 text-sm font-medium"
        >
          Details
        </button>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Annonces</h1>
        <p className="text-gray-500 mt-1">Gestion des annonces de la plateforme</p>
      </div>

      <div className="flex flex-col sm:flex-row gap-4">
        <div className="flex-1">
          <input
            type="text"
            placeholder="Rechercher par ville ou description..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full px-4 py-2.5 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none"
          />
        </div>
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="px-4 py-2.5 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none bg-white"
        >
          <option value="all">Tous les statuts</option>
          <option value="active">Active</option>
          <option value="pending_payment">En attente de paiement</option>
          <option value="suspended">Suspendue</option>
          <option value="expired">Expiree</option>
          <option value="completed">Terminee</option>
        </select>
      </div>

      <DataTable
        columns={columns}
        data={announcements}
        keyField="id"
        loading={loading}
        emptyMessage="Aucune annonce trouvee"
      />

      <Modal
        open={modalOpen}
        onClose={() => {
          setModalOpen(false);
          setSelectedAnnouncement(null);
        }}
        title="Details de l'annonce"
        size="lg"
      >
        {selectedAnnouncement && (
          <div className="space-y-6">
            <div className="grid grid-cols-2 gap-4">
              <div className="bg-gray-50 rounded-lg p-4">
                <p className="text-xs text-gray-500 uppercase font-medium">Trajet</p>
                <p className="text-sm font-medium mt-1">
                  {selectedAnnouncement.departure_city_name} → {selectedAnnouncement.arrival_city_name}
                </p>
              </div>
              <div className="bg-gray-50 rounded-lg p-4">
                <p className="text-xs text-gray-500 uppercase font-medium">Date de depart</p>
                <p className="text-sm font-medium mt-1">{formatDate(selectedAnnouncement.departure_date)}</p>
              </div>
              <div className="bg-gray-50 rounded-lg p-4">
                <p className="text-xs text-gray-500 uppercase font-medium">Kg disponibles</p>
                <p className="text-sm font-medium mt-1">{selectedAnnouncement.available_kg} kg</p>
              </div>
              <div className="bg-gray-50 rounded-lg p-4">
                <p className="text-xs text-gray-500 uppercase font-medium">Prix par kg</p>
                <p className="text-sm font-medium mt-1">{formatCurrency(selectedAnnouncement.price_per_kg)}</p>
              </div>
              <div className="bg-gray-50 rounded-lg p-4">
                <p className="text-xs text-gray-500 uppercase font-medium">Type</p>
                <Badge color={selectedAnnouncement.type === "boosted" ? "purple" : "gray"}>
                  {selectedAnnouncement.type}
                </Badge>
              </div>
              <div className="bg-gray-50 rounded-lg p-4">
                <p className="text-xs text-gray-500 uppercase font-medium">Statut</p>
                <Badge color={getStatusColor(selectedAnnouncement.status)}>
                  {selectedAnnouncement.status}
                </Badge>
              </div>
            </div>

            <div className="bg-gray-50 rounded-lg p-4">
              <p className="text-xs text-gray-500 uppercase font-medium">Voyageur</p>
              <p className="text-sm font-medium mt-1">
                {selectedAnnouncement.profiles?.full_name || "Inconnu"}
              </p>
              <p className="text-xs text-gray-500">
                {selectedAnnouncement.profiles?.email}
              </p>
            </div>

            {selectedAnnouncement.description && (
              <div className="bg-gray-50 rounded-lg p-4">
                <p className="text-xs text-gray-500 uppercase font-medium">Description</p>
                <p className="text-sm mt-1">{selectedAnnouncement.description}</p>
              </div>
            )}

            <div className="flex gap-3">
              {selectedAnnouncement.status === "active" && (
                <button
                  onClick={() => updateStatus(selectedAnnouncement.id, "suspended")}
                  disabled={actionLoading}
                  className="flex-1 py-2.5 rounded-lg text-sm font-medium bg-red-600 text-white hover:bg-red-700 transition-colors disabled:opacity-50"
                >
                  {actionLoading ? "Chargement..." : "Suspendre"}
                </button>
              )}
              {selectedAnnouncement.status === "suspended" && (
                <button
                  onClick={() => updateStatus(selectedAnnouncement.id, "active")}
                  disabled={actionLoading}
                  className="flex-1 py-2.5 rounded-lg text-sm font-medium bg-green-600 text-white hover:bg-green-700 transition-colors disabled:opacity-50"
                >
                  {actionLoading ? "Chargement..." : "Reactiver"}
                </button>
              )}
              {selectedAnnouncement.status === "pending_payment" && (
                <button
                  onClick={() => updateStatus(selectedAnnouncement.id, "active")}
                  disabled={actionLoading}
                  className="flex-1 py-2.5 rounded-lg text-sm font-medium bg-green-600 text-white hover:bg-green-700 transition-colors disabled:opacity-50"
                >
                  {actionLoading ? "Chargement..." : "Activer manuellement"}
                </button>
              )}
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
}
