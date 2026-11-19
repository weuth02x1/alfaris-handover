import "server-only";
import { mutate, readDb } from "@/lib/db";
import { hr } from "@/lib/hr";
import { mockEmployees } from "@/lib/hr/mock-data";
import type { Employee, Role } from "@/lib/types";

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

async function remotePeople() {
  try {
    return await hr().listEmployees();
  } catch {
    return mockEmployees;
  }
}

/** HR directory plus accounts people created with their own email. */
export async function listPeople(): Promise<Employee[]> {
  const remote = await remotePeople();
  const accounts = (await readDb()).accounts ?? [];
  const byId = new Map<string, Employee>();
  for (const person of remote) byId.set(person.id, person);
  for (const account of accounts) byId.set(account.id, account);
  return [...byId.values()];
}

export async function getPerson(id: string) {
  return (await listPeople()).find((person) => person.id === id) ?? null;
}

export async function findByEmail(email: string) {
  const target = normalizeEmail(email);
  return (await listPeople()).find((person) => person.email.toLowerCase() === target) ?? null;
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
  role: Role;
}

export type SignupResult =
  | { ok: true; employee: Employee }
  | { ok: false; error: "invalid" | "emailTaken" | "idTaken" };

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
  if (input.role !== "employee" && input.role !== "hr") return { ok: false, error: "invalid" };

  const existing = await listPeople();
  if (existing.some((person) => person.email.toLowerCase() === email)) return { ok: false, error: "emailTaken" };
  if (existing.some((person) => person.id === employeeNo)) return { ok: false, error: "idTaken" };

  const manager = existing.find((person) => person.departmentId === department.id && person.managerId === null);
  const employee: Employee = {
    id: employeeNo,
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
    managerId: manager && manager.id !== employeeNo ? manager.id : null,
    email,
    role: input.role,
  };

  await mutate((db) => {
    db.accounts = db.accounts.filter((account) => account.id !== employee.id && account.email.toLowerCase() !== email);
    db.accounts.push(employee);
  });
  return { ok: true, employee };
}
