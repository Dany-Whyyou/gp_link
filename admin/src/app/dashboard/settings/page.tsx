"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase-client";
import type { AppConfig } from "@/types";

const DEFAULT_CONFIGS = [
  { key: "price_standard", value: "1500", description: "Prix annonce standard (FCFA)" },
  { key: "price_boosted", value: "3000", description: "Prix annonce boostee (FCFA)" },
  { key: "price_extension", value: "1000", description: "Prix extension d'annonce (FCFA)" },
  { key: "price_extra_kg", value: "2000", description: "Prix par kg supplementaire (FCFA)" },
  { key: "announcement_duration_days", value: "30", description: "Duree d'une annonce (jours)" },
  { key: "max_kg_per_announcement", value: "50", description: "Kg max par annonce" },
  { key: "auto_expire_enabled", value: "true", description: "Expiration automatique des annonces" },
  { key: "moderation_auto_suspend_reports", value: "3", description: "Nombre de signalements avant suspension auto" },
  { key: "platform_commission_percent", value: "10", description: "Commission plateforme (%)" },
];

export default function SettingsPage() {
  const [configs, setConfigs] = useState<AppConfig[]>([]);
  const [editValues, setEditValues] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saveSuccess, setSaveSuccess] = useState(false);

  useEffect(() => {
    loadConfigs();
  }, []);

  async function loadConfigs() {
    const supabase = createClient();
    const { data } = await supabase
      .from("app_config")
      .select("*")
      .order("key");

    const existing = (data as AppConfig[]) || [];
    setConfigs(existing);

    const values: Record<string, string> = {};
    for (const c of existing) {
      values[c.key] = c.value;
    }
    // Fill defaults for missing keys
    for (const d of DEFAULT_CONFIGS) {
      if (!values[d.key]) {
        values[d.key] = d.value;
      }
    }
    setEditValues(values);
    setLoading(false);
  }

  async function handleSave() {
    setSaving(true);
    setSaveSuccess(false);
    const supabase = createClient();

    const existingKeys = new Set(configs.map((c) => c.key));

    const promises = Object.entries(editValues).map(([key, value]) => {
      if (existingKeys.has(key)) {
        return supabase
          .from("app_config")
          .update({ value, updated_at: new Date().toISOString() })
          .eq("key", key);
      } else {
        const defaultConfig = DEFAULT_CONFIGS.find((d) => d.key === key);
        return supabase.from("app_config").insert({
          key,
          value,
          description: defaultConfig?.description || null,
        });
      }
    });

    await Promise.all(promises);
    await loadConfigs();
    setSaving(false);
    setSaveSuccess(true);
    setTimeout(() => setSaveSuccess(false), 3000);
  }

  function getConfigDescription(key: string): string {
    const config = configs.find((c) => c.key === key);
    if (config?.description) return config.description;
    const defaultConfig = DEFAULT_CONFIGS.find((d) => d.key === key);
    return defaultConfig?.description || key;
  }

  // Group configs
  const pricingKeys = ["price_standard", "price_boosted", "price_extension", "price_extra_kg", "platform_commission_percent"];
  const announcementKeys = ["announcement_duration_days", "max_kg_per_announcement", "auto_expire_enabled"];
  const moderationKeys = ["moderation_auto_suspend_reports"];

  const allKeys = Array.from(new Set([
    ...DEFAULT_CONFIGS.map((d) => d.key),
    ...configs.map((c) => c.key),
  ]));
  const otherKeys = allKeys.filter(
    (k) => !pricingKeys.includes(k) && !announcementKeys.includes(k) && !moderationKeys.includes(k)
  );

  if (loading) {
    return (
      <div className="space-y-6">
        <h1 className="text-2xl font-bold text-gray-900">Parametres</h1>
        <div className="bg-white rounded-xl border border-gray-200 p-6 animate-pulse space-y-4">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="h-12 bg-gray-200 rounded" />
          ))}
        </div>
      </div>
    );
  }

  function renderGroup(title: string, keys: string[]) {
    const activeKeys = keys.filter((k) => allKeys.includes(k));
    if (activeKeys.length === 0) return null;

    return (
      <div className="bg-white rounded-xl border border-gray-200">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="font-semibold text-gray-900">{title}</h2>
        </div>
        <div className="p-6 space-y-4">
          {activeKeys.map((key) => (
            <div key={key} className="grid grid-cols-1 sm:grid-cols-3 gap-2 items-center">
              <div>
                <label className="text-sm font-medium text-gray-700">
                  {getConfigDescription(key)}
                </label>
                <p className="text-xs text-gray-400 font-mono">{key}</p>
              </div>
              <div className="sm:col-span-2">
                {editValues[key] === "true" || editValues[key] === "false" ? (
                  <select
                    value={editValues[key]}
                    onChange={(e) =>
                      setEditValues((prev) => ({ ...prev, [key]: e.target.value }))
                    }
                    className="w-full px-4 py-2.5 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none bg-white"
                  >
                    <option value="true">Actif</option>
                    <option value="false">Inactif</option>
                  </select>
                ) : (
                  <input
                    type="text"
                    value={editValues[key] || ""}
                    onChange={(e) =>
                      setEditValues((prev) => ({ ...prev, [key]: e.target.value }))
                    }
                    className="w-full px-4 py-2.5 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none"
                  />
                )}
              </div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Parametres</h1>
          <p className="text-gray-500 mt-1">Configuration de la plateforme</p>
        </div>
        <div className="flex items-center gap-3">
          {saveSuccess && (
            <span className="text-sm text-green-600 font-medium">
              Parametres sauvegardes
            </span>
          )}
          <button
            onClick={handleSave}
            disabled={saving}
            className="px-6 py-2.5 bg-primary-600 hover:bg-primary-700 text-white rounded-lg text-sm font-medium transition-colors disabled:opacity-50"
          >
            {saving ? "Sauvegarde..." : "Sauvegarder"}
          </button>
        </div>
      </div>

      {renderGroup("Tarification", pricingKeys)}
      {renderGroup("Annonces", announcementKeys)}
      {renderGroup("Moderation", moderationKeys)}
      {otherKeys.length > 0 && renderGroup("Autres", otherKeys)}
    </div>
  );
}
