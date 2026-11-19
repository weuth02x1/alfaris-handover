import { NextResponse, type NextRequest } from "next/server";
import { timingSafeEqual } from "crypto";
import { hr } from "@/lib/hr";
import { initiateClearance, WorkflowError } from "@/lib/workflow";
import { appOrigin } from "@/lib/origin";

/**
 * Called by Menaitech HRMS when HR starts the clearance process.
 * Body: { "requestRef": "VAC-2026-0412", "initiatedBy": "<HR employee id>" }
 * Header: x-api-key: <INTEGRATION_API_KEY>
 */
export async function POST(request: NextRequest) {
  const expected = process.env.INTEGRATION_API_KEY;
  const given = request.headers.get("x-api-key") ?? "";
  if (!expected || given.length !== expected.length || !timingSafeEqual(Buffer.from(given), Buffer.from(expected))) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const body = (await request.json().catch(() => null)) as { requestRef?: string; initiatedBy?: string } | null;
  if (!body?.requestRef || !body.initiatedBy) {
    return NextResponse.json({ error: "requestRef and initiatedBy are required" }, { status: 400 });
  }
  const actor = await hr().getEmployee(body.initiatedBy);
  if (!actor) return NextResponse.json({ error: "unknown initiatedBy" }, { status: 400 });

  const base = await appOrigin();
  try {
    const handoverId = await initiateClearance(actor, body.requestRef, base);
    return NextResponse.json({ handoverId, url: `${base}/handovers/${handoverId}` }, { status: 201 });
  } catch (e) {
    if (e instanceof WorkflowError) {
      return NextResponse.json({ error: e.code }, { status: e.code === "notFound" ? 404 : 403 });
    }
    throw e;
  }
}
