"use client";

import { useEffect, useState, useCallback } from "react";
import { createClient } from "@/lib/supabase-client";
import DataTable, { Column } from "@/components/DataTable";
import Badge from "@/components/Badge";
import StatsCard from "@/components/StatsCard";
import { formatDate, formatCurrency, getStatusColor } from "@/lib/utils";
import type { Payment, PaymentStatus } from "@/types";

type PaymentWithProfile = Payment & {
  profiles: { full_name: string; email: string } | null;
};

export default function PaymentsPage() {
  const [payments, setPayments] = useState<PaymentWithProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [revenueStats, setRevenueStats] = useState({
    total: 0,
    completed: 0,
    pending: 0,
    failed: 0,
  });

  const loadPayments = useCallback(async () => {
    setLoading(true);
    const supabase = createClient();

    let query = supabase
      .from("payments")
      .select("*, profiles(full_name, email)")
      .order("created_at", { ascending: false });

    if (statusFilter !== "all") {
      query = query.eq("status", statusFilter);
    }

    const { data } = await query.limit(200);
    const paymentsList = (data as PaymentWithProfile[]) || [];
    setPayments(paymentsList);

    // Calculate stats from all payments (not filtered)
    const allPaymentsRes = await supabase.from("payments").select("amount, status");
    const all = allPaymentsRes.data || [];

    setRevenueStats({
      total: all.reduce((s, p) => s + (p.amount || 0), 0),
      completed: all.filter((p) => p.status === "completed").reduce((s, p) => s + (p.amount || 0), 0),
      pending: all.filter((p) => p.status === "pending").reduce((s, p) => s + (p.amount || 0), 0),
      failed: all.filter((p) => p.status === "failed").reduce((s, p) => s + (p.amount || 0), 0),
    });

    setLoading(false);
  }, [statusFilter]);

  useEffect(() => {
    loadPayments();
  }, [loadPayments]);

  const columns: Column<PaymentWithProfile>[] = [
    {
      key: "reference",
      label: "Reference",
      render: (p) => (
        <div>
          <p className="font-mono text-sm text-gray-900">
            {p.reference ? p.reference.slice(0, 14) + "..." : p.id.slice(0, 8)}
          </p>
          {p.mypvit_transaction_id && (
            <p className="font-mono text-xs text-gray-500">
              {p.mypvit_transaction_id}
            </p>
          )}
        </div>
      ),
    },
    {
      key: "user",
      label: "Utilisateur",
      render: (p) => (
        <div>
          <p className="text-sm font-medium">{p.profiles?.full_name || "Inconnu"}</p>
          <p className="text-xs text-gray-500">{p.profiles?.email}</p>
        </div>
      ),
    },
    {
      key: "amount",
      label: "Montant",
      sortable: true,
      render: (p) => (
        <span className="font-semibold text-gray-900">{formatCurrency(p.amount)}</span>
      ),
    },
    {
      key: "operator",
      label: "Operateur",
      render: (p) => {
        const label =
          p.operator === "AIRTEL_MONEY"
            ? "Airtel Money"
            : p.operator === "MOOV_MONEY"
              ? "Moov Money"
              : p.operator === "TEST"
                ? "Test"
                : "MyPvit";
        return <span className="text-sm">{label}</span>;
      },
    },
    {
      key: "status",
      label: "Statut",
      render: (p) => (
        <Badge color={getStatusColor(p.status)}>{p.status}</Badge>
      ),
    },
    {
      key: "created_at",
      label: "Date",
      sortable: true,
      render: (p) => <span className="text-gray-500">{formatDate(p.created_at)}</span>,
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Paiements</h1>
        <p className="text-gray-500 mt-1">Suivi des transactions et revenus</p>
      </div>

      {/* Revenue stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <StatsCard
          title="Revenus totaux"
          value={formatCurrency(revenueStats.total)}
          color="blue"
          icon={
            <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 6v12m-3-2.818l.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          }
        />
        <StatsCard
          title="Payes"
          value={formatCurrency(revenueStats.completed)}
          color="green"
          icon={
            <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          }
        />
        <StatsCard
          title="En attente"
          value={formatCurrency(revenueStats.pending)}
          color="yellow"
          icon={
            <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          }
        />
        <StatsCard
          title="Echoues"
          value={formatCurrency(revenueStats.failed)}
          color="red"
          icon={
            <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M9.75 9.75l4.5 4.5m0-4.5l-4.5 4.5M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          }
        />
      </div>

      <div className="flex gap-4">
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="px-4 py-2.5 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none bg-white"
        >
          <option value="all">Tous les statuts</option>
          <option value="completed">Complets</option>
          <option value="pending">En attente</option>
          <option value="failed">Echoues</option>
          <option value="expired">Expires</option>
          <option value="refunded">Rembourses</option>
        </select>
      </div>

      <DataTable
        columns={columns}
        data={payments}
        keyField="id"
        loading={loading}
        emptyMessage="Aucun paiement trouve"
      />
    </div>
  );
}
