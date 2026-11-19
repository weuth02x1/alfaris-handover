import "server-only";
import { randomUUID } from "crypto";
import { mutate, readDb } from "@/lib/db";
import { hr } from "@/lib/hr";
import { mockEmployees } from "@/lib/hr/mock-data";
import type { Employee } from "@/lib/types";

export const DEPARTMENTS = [
  {
    id: "D-HR",
    departmentAr: "الموارد البشرية",
    departmentEn: "Human Resources",
    sectionAr: "شؤون الموظفين",
    sectionEn: "Personnel Affairs",
  },
  {
    id: "D-TA",
    departmentAr: "استقطاب المواهب",
    departmentEn: "Talent Acquisition",
    sectionAr: "استقطاب المواهب",
    sectionEn: "Talent Acquisition",
  },
  {
    id: "D-ITD",
    departmentAr: "تطوير تقنية المعلومات",
    departmentEn: "IT Development",
    sectionAr: "تطوير الأنظمة",
    sectionEn: "Systems Development",
  },
] as const;

export type DepartmentId = (typeof DEPARTMENTS)[number]["id"];

export function normalizeEmail(value: string) {
  return value.trim().toLowerCase();
}

export function isEmail(value: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value) && value.length <= 160;
}

type DirectoryResult = { ok: true; people: Employee[] } | { ok: false };

/** Live HR directory. A failed HRMS call does not fall back to the sample list. */
async function loadDirectory(): Promise<DirectoryResult> {
  const provider = hr();
  if (provider.name !== "menaitech") return { ok: true, people: mockEmployees };
  try {
    return { ok: true, people: await provider.listEmployees() };
  } catch {
    return { ok: false };
  }
}

/** Employees from HR only. Sign-in accounts are not part of this directory. */
export async function listPeople(): Promise<Employee[]> {
  const directory = await loadDirectory();
  return directory.ok ? directory.people : [];
}

async function loginAccounts() {
  return mutate((db) => {
    db.accounts = db.accounts.map((account) => {
      if (account.id.startsWith("local-")) return { ...account, role: "employee" as const, managerId: null };
      return {
        ...account,
        id: `local-${account.id}`,
        staffNumber: account.staffNumber ?? account.id,
        role: "employee" as const,
        managerId: null,
      };
    });
    return db.accounts;
  });
}

export async function getPerson(id: string) {
  const directory = await loadDirectory();
  if (!directory.ok) return null;
  return directory.people.find((person) => person.id === id) ?? null;
}

/** Session lookup. Local accounts never resolve to an HR directory employee. */
export async function getSessionUser(id: string) {
  if (id.startsWith("local-")) {
    const account = (await readDb()).accounts.find((item) => item.id === id);
    return account ? { ...account, role: "employee" as const, managerId: null } : null;
  }
  return getPerson(id);
}

function asLoginAccount(account: Employee): Employee {
  return {
    ...account,
    id: account.id.startsWith("local-") ? account.id : `local-${account.id}`,
    staffNumber: account.staffNumber ?? account.id,
    role: "employee",
    managerId: null,
  };
}

/** Local accounts first, so sign-in does not wait on the HR directory. */
export async function findByEmail(email: string) {
  const target = normalizeEmail(email);
  const local = (await readDb()).accounts.find((item) => item.email.toLowerCase() === target);
  if (local) return asLoginAccount(local);
  const directory = await Promise.race([
    loadDirectory(),
    new Promise<DirectoryResult>((resolve) => setTimeout(() => resolve({ ok: false }), 4_000)),
  ]);
  if (!directory.ok) return null;
  return directory.people.find((item) => item.email.toLowerCase() === target) ?? null;
}

export function colleaguesOf(me: Employee, all: Employee[]) {
  const sameDept = all.filter((person) => person.id !== me.id && person.departmentId === me.departmentId);
  if (sameDept.length > 0) return sameDept;
  return all.filter((person) => person.id !== me.id && person.branchId === me.branchId);
}

export async function colleaguesFor(employeeId: string) {
  const all = await listPeople();
  const me = all.find((person) => person.id === employeeId);
  if (!me) return [];
  return colleaguesOf(me, all);
}

export interface SignupInput {
  email: string;
  name: string;
  employeeNo: string;
  jobTitle: string;
  departmentId: string;
}

export type SignupResult =
  | { ok: true; employee: Employee }
  | { ok: false; error: "invalid" | "emailTaken" | "idTaken" | "slow" | "unavailable" };

const SIGNUPS_PER_HOUR = 30;

export async function registerAccount(input: SignupInput): Promise<SignupResult> {
  const email = normalizeEmail(input.email);
  const name = input.name.trim();
  const employeeNo = input.employeeNo.trim();
  const jobTitle = input.jobTitle.trim();
  const department = DEPARTMENTS.find((item) => item.id === input.departmentId);
  if (!isEmail(email) || name.length < 2 || name.length > 80) return { ok: false, error: "invalid" };
  if (!/^\d{3,10}$/.test(employeeNo)) return { ok: false, error: "invalid" };
  if (jobTitle.length < 2 || jobTitle.length > 80) return { ok: false, error: "invalid" };
  if (!department) return { ok: false, error: "invalid" };

  const directory = await loadDirectory();
  if (!directory.ok) return { ok: false, error: "unavailable" };
  const accounts = await loginAccounts();
  const known = [...directory.people, ...accounts];
  if (known.some((person) => person.email.toLowerCase() === email)) return { ok: false, error: "emailTaken" };
  if (known.some((person) => person.id === employeeNo || person.staffNumber === employeeNo)) {
    return { ok: false, error: "idTaken" };
  }

  const employee: Employee = {
    id: `local-${randomUUID()}`,
    staffNumber: employeeNo,
    nameAr: name,
    nameEn: name,
    jobTitleAr: jobTitle,
    jobTitleEn: jobTitle,
    departmentId: department.id,
    departmentAr: department.departmentAr,
    departmentEn: department.departmentEn,
    sectionAr: department.sectionAr,
    sectionEn: department.sectionEn,
    branchId: "B-RUH",
    managerId: null,
    email,
    role: "employee",
  };

  const stored = await mutate((db) => {
    const hourAgo = Date.now() - 60 * 60 * 1000;
    const recentSignups = db.otpSends.filter(
      (item) => item.bucket === "signup" && new Date(item.sentAt).getTime() >= hourAgo,
    ).length;
    if (recentSignups >= SIGNUPS_PER_HOUR) return false;
    db.accounts = db.accounts.filter((account) => account.id !== employee.id && account.email.toLowerCase() !== email);
    db.accounts.push(employee);
    db.otpSends.push({ bucket: "signup", sentAt: new Date().toISOString() });
    return true;
  });
  if (!stored) return { ok: false, error: "slow" };
  return { ok: true, employee };
}
