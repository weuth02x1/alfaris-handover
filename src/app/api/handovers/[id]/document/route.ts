import { NextResponse, type NextRequest } from "next/server";
import { getHandoverFor } from "@/lib/queries";
import { currentUser } from "@/lib/session";
import { canonicalRecord } from "@/lib/workflow";

/** Structured record of a finalised handover (the same payload uploaded to the HRMS). */
export async function GET(_request: NextRequest, ctx: RouteContext<"/api/handovers/[id]/document">) {
  const user = await currentUser();
  if (!user) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const { id } = await ctx.params;
  const data = await getHandoverFor(user, id);
  if (!data || !(data.access.isOwner || data.access.isManager || data.access.isHr)) {
    return NextResponse.json({ error: "not found" }, { status: 404 });
  }
  const h = data.handover;
  if (h.status !== "approved") return NextResponse.json({ error: "not finalised" }, { status: 409 });
  return NextResponse.json({
    ...canonicalRecord(h),
    documentHash: h.documentHash,
    hrmsDocumentId: h.hrmsDocumentId,
    audit: data.audit,
  });
}
