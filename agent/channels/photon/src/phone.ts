// SPDX-License-Identifier: GPL-3.0-or-later
/** Normalize phone numbers and check the iMessage allowlist. */

export function normalizePhone(raw: string): string | null {
  const trimmed = raw.trim();
  if (!trimmed) return null;
  if (trimmed.includes("@")) return trimmed.toLowerCase();
  const digits = trimmed.replace(/\D/g, "");
  if (digits.length === 10) return `+1${digits}`;
  if (digits.length === 11 && digits.startsWith("1")) return `+${digits}`;
  if (digits.length >= 8 && trimmed.startsWith("+")) return `+${digits}`;
  if (digits.length >= 11) return `+${digits}`;
  return null;
}

export function parseAllowlist(raw: string): Set<string> {
  const out = new Set<string>();
  for (const part of raw.split(/[,\s]+/)) {
    if (!part) continue;
    const normalized = normalizePhone(part);
    if (normalized) out.add(normalized);
  }
  return out;
}

export function isAllowed(raw: string | undefined, allowlist: Set<string>): string | null {
  if (!raw) return null;
  const normalized = normalizePhone(raw);
  if (!normalized) return null;
  return allowlist.has(normalized) ? normalized : null;
}
