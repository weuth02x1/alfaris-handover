export type Role = "employee" | "hr";

export interface Employee {
  id: string;
  nameAr: string;
  nameEn: string;
  jobTitleAr: string;
  jobTitleEn: string;
  departmentId: string;
  departmentAr: string;
  departmentEn: string;
  sectionAr: string;
  sectionEn: string;
  branchId: string;
  managerId: string | null;
  email: string;
  role: Role;
  /** Typed employee number for a sign-in account. Directory ids stay on `id`. */
  staffNumber?: string;
  /** Cursor viewer who created this local sign-in account. */
  viewerSub?: string;
}

export const EXIT_REASONS = ["annual_leave", "clearance", "resignation", "transfer", "contract_end"] as const;
export type ExitReason = (typeof EXIT_REASONS)[number];

/** A request already approved in the HRMS, waiting for HR to start clearance. */
export interface ApprovedRequest {
  ref: string;
  employeeId: string;
  type: ExitReason;
  startDate: string;
  endDate: string | null;
}

export type HandoverStatus =
  | "draft"
  | "pending_acceptance"
  | "pending_manager"
  | "pending_hr"
  | "returned"
  | "approved";

export type TaskStatus = "draft" | "pending" | "accepted" | "rejected";

export interface TaskRejection {
  recipientId: string;
  comment: string;
  at: string;
}

export interface HandoverTask {
  id: string;
  title: string;
  details: string;
  dueDate: string | null;
  assigneeId: string;
  status: TaskStatus;
  acceptedAt: string | null;
  acceptNote: string | null;
  rejections: TaskRejection[];
}

export interface EmployeeSnapshot {
  id: string;
  nameAr: string;
  nameEn: string;
  jobTitleAr: string;
  jobTitleEn: string;
  departmentAr: string;
  departmentEn: string;
  sectionAr: string;
  sectionEn: string;
  managerId: string | null;
  managerNameAr: string;
  managerNameEn: string;
}

export interface ReturnInfo {
  stage: "manager" | "hr";
  byId: string;
  comment: string;
  at: string;
}

export interface Approval {
  byId: string;
  at: string;
  comment: string | null;
}

export interface Handover {
  id: string;
  number: string;
  requestRef: string;
  type: ExitReason;
  lastWorkingDay: string;
  returnDate: string | null;
  employee: EmployeeSnapshot;
  status: HandoverStatus;
  generalNotes: string;
  tasks: HandoverTask[];
  lastReturn: ReturnInfo | null;
  managerApproval: Approval | null;
  hrApproval: Approval | null;
  initiatedById: string;
  createdAt: string;
  submittedAt: string | null;
  finalizedAt: string | null;
  documentHash: string | null;
  hrmsDocumentId: string | null;
}

export type AuditAction =
  | "clearance_initiated"
  | "link_sent"
  | "form_saved"
  | "form_submitted"
  | "task_assigned"
  | "task_accepted"
  | "task_rejected"
  | "task_reassigned"
  | "manager_approved"
  | "manager_rejected"
  | "hr_approved"
  | "hr_rejected"
  | "document_generated"
  | "document_uploaded";

export interface AuditEntry {
  id: string;
  handoverId: string;
  at: string;
  actorId: string;
  action: AuditAction;
  details: string;
}

export interface EmailMessage {
  id: string;
  to: string;
  toEmployeeId: string;
  subject: string;
  body: string;
  link: string | null;
  at: string;
  kind: "workflow" | "otp";
  delivered: boolean;
}

export interface OtpChallenge {
  employeeId: string;
  email: string;
  codeHash: string;
  expiresAt: string;
  sentAt: string;
  active: boolean;
}

/** Failed guesses stay counted even when a new code is issued. */
export interface OtpGuard {
  email: string;
  failures: number;
  windowStart: string;
}

export interface OtpSend {
  bucket: string;
  sentAt: string;
}

export interface AccessToken {
  token: string;
  handoverId: string;
  employeeId: string;
  expiresAt: string;
}

export interface Database {
  handovers: Handover[];
  audit: AuditEntry[];
  outbox: EmailMessage[];
  tokens: AccessToken[];
  otps: OtpChallenge[];
  otpGuards: OtpGuard[];
  otpSends: OtpSend[];
  accounts: Employee[];
  counter: number;
  sessionKey: string;
}
