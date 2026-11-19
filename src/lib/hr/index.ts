import "server-only";
import type { ApprovedRequest, Employee } from "@/lib/types";
import { mockApprovedRequests, mockEmployees } from "./mock-data";

export interface FinalDocumentUpload {
  employeeId: string;
  handoverNumber: string;
  requestRef: string;
  fileName: string;
  contentHash: string;
  record: unknown;
}

/** Everything the handover workflow needs from the HR system (Menaitech HRMS). */
export interface HrProvider {
  readonly name: string;
  listEmployees(): Promise<Employee[]>;
  getEmployee(id: string): Promise<Employee | null>;
  /** Candidates who can receive tasks: same department or same branch. */
  listColleagues(employeeId: string): Promise<Employee[]>;
  listApprovedRequests(): Promise<ApprovedRequest[]>;
  uploadFinalDocument(doc: FinalDocumentUpload): Promise<{ documentId: string }>;
}

class MockHrProvider implements HrProvider {
  readonly name = "mock";

  async listEmployees() {
    return mockEmployees;
  }
  async getEmployee(id: string) {
    return mockEmployees.find((e) => e.id === id) ?? null;
  }
  async listColleagues(employeeId: string) {
    const me = await this.getEmployee(employeeId);
    if (!me) return [];
    return colleaguesOf(me, mockEmployees);
  }
  async listApprovedRequests() {
    return mockApprovedRequests;
  }
  async uploadFinalDocument(doc: FinalDocumentUpload) {
    return { documentId: `MOCK-DOC-${doc.handoverNumber}` };
  }
}

function colleaguesOf(me: Employee, all: Employee[]) {
  const sameDept = all.filter(
    (e) => e.id !== me.id && e.departmentId === me.departmentId,
  );
  if (sameDept.length > 0) return sameDept;
  return all.filter((e) => e.id !== me.id && e.branchId === me.branchId);
}

/**
 * Menaitech HRMS over REST. Endpoint paths are configurable because the exact
 * API contract is still to be confirmed with Menaitech.
 */
class MenaitechHrProvider implements HrProvider {
  readonly name = "menaitech";
  private base: string;
  private key: string;

  constructor(base: string, key: string) {
    this.base = base.replace(/\/$/, "");
    this.key = key;
  }

  private path(envName: string, fallback: string, params: Record<string, string> = {}) {
    let p = process.env[envName] || fallback;
    for (const [k, v] of Object.entries(params)) p = p.replace(`{${k}}`, encodeURIComponent(v));
    return `${this.base}${p}`;
  }

  private async call<T>(url: string, init?: RequestInit): Promise<T> {
    const res = await fetch(url, {
      ...init,
      cache: "no-store",
      signal: AbortSignal.timeout(8000),
      headers: {
        Authorization: `Bearer ${this.key}`,
        Accept: "application/json",
        "Content-Type": "application/json",
        ...(init?.headers ?? {}),
      },
    });
    if (!res.ok) throw new Error(`Menaitech API ${res.status} on ${url}`);
    return (await res.json()) as T;
  }

  async listEmployees() {
    return this.call<Employee[]>(this.path("MENAITECH_PATH_EMPLOYEES", "/employees"));
  }
  async getEmployee(id: string) {
    try {
      return await this.call<Employee>(
        this.path("MENAITECH_PATH_EMPLOYEE", "/employees/{id}", { id }),
      );
    } catch {
      return null;
    }
  }
  async listColleagues(employeeId: string) {
    const me = await this.getEmployee(employeeId);
    if (!me) return [];
    return colleaguesOf(me, await this.listEmployees());
  }
  async listApprovedRequests() {
    return this.call<ApprovedRequest[]>(
      this.path("MENAITECH_PATH_APPROVED_REQUESTS", "/leave-requests?status=approved"),
    );
  }
  async uploadFinalDocument(doc: FinalDocumentUpload) {
    return this.call<{ documentId: string }>(
      this.path("MENAITECH_PATH_DOCUMENTS", "/employees/{id}/documents", {
        id: doc.employeeId,
      }),
      { method: "POST", body: JSON.stringify(doc) },
    );
  }
}

let provider: HrProvider | null = null;

export function hr(): HrProvider {
  if (!provider) {
    const base = process.env.MENAITECH_API_BASE_URL;
    const key = process.env.MENAITECH_API_KEY;
    provider = base && key ? new MenaitechHrProvider(base, key) : new MockHrProvider();
  }
  return provider;
}
