/**
 * Format amount in FCFA
 */
export function formatCurrency(amount: number): string {
  return new Intl.NumberFormat("fr-FR", {
    style: "decimal",
    minimumFractionDigits: 0,
  }).format(amount) + " FCFA";
}

/**
 * Format date to locale string
 */
export function formatDate(dateStr: string): string {
  return new Date(dateStr).toLocaleDateString("fr-FR", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

/**
 * Format relative time
 */
export function timeAgo(dateStr: string): string {
  const now = new Date();
  const date = new Date(dateStr);
  const seconds = Math.floor((now.getTime() - date.getTime()) / 1000);

  if (seconds < 60) return "il y a quelques secondes";
  if (seconds < 3600) return `il y a ${Math.floor(seconds / 60)} min`;
  if (seconds < 86400) return `il y a ${Math.floor(seconds / 3600)}h`;
  if (seconds < 2592000) return `il y a ${Math.floor(seconds / 86400)}j`;
  return formatDate(dateStr);
}

/**
 * Truncate text
 */
export function truncate(str: string, length: number): string {
  if (str.length <= length) return str;
  return str.slice(0, length) + "...";
}

/**
 * Get initials from name
 */
export function getInitials(name: string): string {
  return name
    .split(" ")
    .map((n) => n[0])
    .join("")
    .toUpperCase()
    .slice(0, 2);
}

/**
 * Status color map for badges
 */
export function getStatusColor(
  status: string
): "green" | "red" | "yellow" | "blue" | "gray" | "purple" {
  const map: Record<string, "green" | "red" | "yellow" | "blue" | "gray" | "purple"> = {
    active: "green",
    completed: "green",
    resolved: "green",
    accepted: "green",
    verified: "green",
    pending: "yellow",
    pending_payment: "yellow",
    reviewed: "blue",
    boosted: "purple",
    suspended: "red",
    banned: "red",
    failed: "red",
    rejected: "red",
    cancelled: "gray",
    expired: "gray",
    dismissed: "gray",
    refunded: "blue",
  };
  return map[status] || "gray";
}
