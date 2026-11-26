// SPDX-License-Identifier: GPL-3.0-or-later
import { describe, expect, test } from "bun:test";
import { isAllowed, normalizePhone, parseAllowlist } from "./phone";

describe("normalizePhone", () => {
  test("accepts E.164, US 10-digit, and messy formatting", () => {
    expect(normalizePhone("+19142632426")).toBe("+19142632426");
    expect(normalizePhone("+1 914-263-2426")).toBe("+19142632426");
    expect(normalizePhone("9142632426")).toBe("+19142632426");
    expect(normalizePhone("1 914 263 2426")).toBe("+19142632426");
    expect(normalizePhone("(914) 263-2426")).toBe("+19142632426");
  });

  test("keeps emails, rejects empty", () => {
    expect(normalizePhone("carlton@example.com")).toBe("carlton@example.com");
    expect(normalizePhone("")).toBeNull();
    expect(normalizePhone("   ")).toBeNull();
  });
});

describe("allowlist", () => {
  test("matches only listed numbers", () => {
    const allow = parseAllowlist("+1 914-263-2426");
    expect(isAllowed("+19142632426", allow)).toBe("+19142632426");
    expect(isAllowed("9142632426", allow)).toBe("+19142632426");
    expect(isAllowed("+16282679185", allow)).toBeNull();
    expect(isAllowed(undefined, allow)).toBeNull();
  });
});
