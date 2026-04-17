"use client";

import { useEffect, useState, useCallback } from "react";
import { createClient } from "@/lib/supabase-client";
import DataTable, { Column } from "@/components/DataTable";
import Badge from "@/components/Badge";
import Modal from "@/components/Modal";
import { formatDate, getInitials, getStatusColor } from "@/lib/utils";
import type { Profile } from "@/types";

export default function UsersPage() {
  const [users, setUsers] = useState<Profile[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [roleFilter, setRoleFilter] = useState<string>("all");
  const [selectedUser, setSelectedUser] = useState<Profile | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [banReason, setBanReason] = useState("");

  const loadUsers = useCallback(async () => {
    setLoading(true);
    const supabase = createClient();

    let query = supabase
      .from("profiles")
      .select("*")
      .order("created_at", { ascending: false });

    if (roleFilter !== "all") {
      query = query.eq("role", roleFilter);
    }

    if (search) {
      query = query.or(`full_name.ilike.%${search}%,email.ilike.%${search}%,phone.ilike.%${search}%`);
    }

    const { data } = await query.limit(100);
    setUsers((data as Profile[]) || []);
    setLoading(false);
  }, [search, roleFilter]);

  useEffect(() => {
    loadUsers();
  }, [loadUsers]);

  async function toggleBan(user: Profile) {
    setActionLoading(true);
    const supabase = createClient();

    const updates: Partial<Profile> = {
      is_banned: !user.is_banned,
      ban_reason: user.is_banned ? null : banReason || null,
    };

    const { error } = await supabase
      .from("profiles")
      .update(updates)
      .eq("id", user.id);

    if (!error) {
      await loadUsers();
      setModalOpen(false);
      setSelectedUser(null);
      setBanReason("");
    }
    setActionLoading(false);
  }

  async function toggleVerify(user: Profile) {
    setActionLoading(true);
    const supabase = createClient();

    const { error } = await supabase
      .from("profiles")
      .update({ is_verified: !user.is_verified })
      .eq("id", user.id);

    if (!error) {
      await loadUsers();
      if (selectedUser?.id === user.id) {
        setSelectedUser({ ...user, is_verified: !user.is_verified });
      }
    }
    setActionLoading(false);
  }

  const columns: Column<Profile>[] = [
    {
      key: "full_name",
      label: "Utilisateur",
      render: (user) => (
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 bg-primary-100 text-primary-700 rounded-full flex items-center justify-center text-sm font-medium">
            {getInitials(user.full_name || "?")}
          </div>
          <div>
            <p className="font-medium text-gray-900">{user.full_name}</p>
            <p className="text-xs text-gray-500">{user.email}</p>
          </div>
        </div>
      ),
    },
    {
      key: "role",
      label: "Role",
      render: (user) => (
        <Badge color={user.role === "admin" ? "purple" : user.role === "voyageur" ? "blue" : "gray"}>
          {user.role}
        </Badge>
      ),
    },
    {
      key: "is_verified",
      label: "Verifie",
      render: (user) => (
        <Badge color={user.is_verified ? "green" : "yellow"}>
          {user.is_verified ? "Verifie" : "Non verifie"}
        </Badge>
      ),
    },
    {
      key: "is_banned",
      label: "Statut",
      render: (user) => (
        <Badge color={user.is_banned ? "red" : "green"}>
          {user.is_banned ? "Banni" : "Actif"}
        </Badge>
      ),
    },
    {
      key: "created_at",
      label: "Inscription",
      sortable: true,
      render: (user) => <span className="text-gray-500">{formatDate(user.created_at)}</span>,
    },
    {
      key: "actions",
      label: "Actions",
      render: (user) => (
        <div className="flex items-center gap-2">
          <button
            onClick={(e) => {
              e.stopPropagation();
              setSelectedUser(user);
              setModalOpen(true);
            }}
            className="text-primary-600 hover:text-primary-800 text-sm font-medium"
          >
            Details
          </button>
        </div>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Utilisateurs</h1>
        <p className="text-gray-500 mt-1">Gestion des utilisateurs de la plateforme</p>
      </div>

      {/* Filters */}
      <div className="flex flex-col sm:flex-row gap-4">
        <div className="flex-1">
          <input
            type="text"
            placeholder="Rechercher par nom, email ou telephone..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full px-4 py-2.5 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none"
          />
        </div>
        <select
          value={roleFilter}
          onChange={(e) => setRoleFilter(e.target.value)}
          className="px-4 py-2.5 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none bg-white"
        >
          <option value="all">Tous les roles</option>
          <option value="client">Clients</option>
          <option value="voyageur">Voyageurs</option>
          <option value="admin">Admins</option>
        </select>
      </div>

      <DataTable
        columns={columns}
        data={users}
        keyField="id"
        loading={loading}
        emptyMessage="Aucun utilisateur trouve"
      />

      {/* User detail modal */}
      <Modal
        open={modalOpen}
        onClose={() => {
          setModalOpen(false);
          setSelectedUser(null);
          setBanReason("");
        }}
        title="Details de l'utilisateur"
        size="lg"
      >
        {selectedUser && (
          <div className="space-y-6">
            <div className="flex items-center gap-4">
              <div className="w-16 h-16 bg-primary-100 text-primary-700 rounded-full flex items-center justify-center text-xl font-bold">
                {getInitials(selectedUser.full_name || "?")}
              </div>
              <div>
                <h3 className="text-lg font-semibold">{selectedUser.full_name}</h3>
                <p className="text-gray-500">{selectedUser.email}</p>
                {selectedUser.phone && (
                  <p className="text-gray-500 text-sm">{selectedUser.phone}</p>
                )}
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="bg-gray-50 rounded-lg p-4">
                <p className="text-xs text-gray-500 uppercase font-medium">Role</p>
                <p className="text-sm font-medium mt-1">{selectedUser.role}</p>
              </div>
              <div className="bg-gray-50 rounded-lg p-4">
                <p className="text-xs text-gray-500 uppercase font-medium">Inscription</p>
                <p className="text-sm font-medium mt-1">{formatDate(selectedUser.created_at)}</p>
              </div>
              <div className="bg-gray-50 rounded-lg p-4">
                <p className="text-xs text-gray-500 uppercase font-medium">Verification</p>
                <Badge color={selectedUser.is_verified ? "green" : "yellow"}>
                  {selectedUser.is_verified ? "Verifie" : "Non verifie"}
                </Badge>
              </div>
              <div className="bg-gray-50 rounded-lg p-4">
                <p className="text-xs text-gray-500 uppercase font-medium">Statut</p>
                <Badge color={selectedUser.is_banned ? "red" : "green"}>
                  {selectedUser.is_banned ? "Banni" : "Actif"}
                </Badge>
              </div>
            </div>

            {selectedUser.ban_reason && (
              <div className="bg-red-50 border border-red-200 rounded-lg p-4">
                <p className="text-xs text-red-500 uppercase font-medium">Raison du ban</p>
                <p className="text-sm text-red-700 mt-1">{selectedUser.ban_reason}</p>
              </div>
            )}

            {/* Ban reason input (when banning) */}
            {!selectedUser.is_banned && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Raison du ban (optionnel)
                </label>
                <textarea
                  value={banReason}
                  onChange={(e) => setBanReason(e.target.value)}
                  rows={2}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none"
                  placeholder="Indiquez la raison..."
                />
              </div>
            )}

            <div className="flex gap-3">
              <button
                onClick={() => toggleVerify(selectedUser)}
                disabled={actionLoading}
                className={`flex-1 py-2.5 rounded-lg text-sm font-medium transition-colors disabled:opacity-50 ${
                  selectedUser.is_verified
                    ? "bg-yellow-100 text-yellow-700 hover:bg-yellow-200"
                    : "bg-green-100 text-green-700 hover:bg-green-200"
                }`}
              >
                {selectedUser.is_verified ? "Retirer la verification" : "Verifier l'identite"}
              </button>
              <button
                onClick={() => toggleBan(selectedUser)}
                disabled={actionLoading}
                className={`flex-1 py-2.5 rounded-lg text-sm font-medium transition-colors disabled:opacity-50 ${
                  selectedUser.is_banned
                    ? "bg-green-600 text-white hover:bg-green-700"
                    : "bg-red-600 text-white hover:bg-red-700"
                }`}
              >
                {actionLoading
                  ? "Chargement..."
                  : selectedUser.is_banned
                  ? "Debannir"
                  : "Bannir l'utilisateur"}
              </button>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
}
