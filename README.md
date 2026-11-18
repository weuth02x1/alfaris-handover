# Employee Handover (نظام تسليم المهام)

Web app that automates the employee handover receipt for **vacation** and **termination** clearance, linked to **Menaitech HRMS**.

## Workflow

1. A vacation / termination request is approved in Menaitech and HR starts clearance (from the HR console, or by Menaitech calling the integration API).
2. The system creates the handover form, auto-fills the employee data from the HRMS, and emails the employee a secure, time-bound link.
3. The employee signs in, lists the tasks, and picks a recipient for each task (recipients come from the same department, falling back to the same branch).
4. Each recipient is notified and must **accept** the task, or **decline it with a mandatory reason**. A declined task goes back to the employee, who must pick a different colleague (people who already declined are excluded). The workflow only moves on when every task is accepted.
5. The direct manager reviews (read-only) and approves, or returns the form to the employee with a mandatory comment.
6. HR gives the final approval, or returns the form with a mandatory comment.
7. On HR approval the handover is locked, a bilingual report (Arabic / English, printable to PDF) is generated with a SHA-256 fingerprint, and the structured record is uploaded to the employee's file in the HRMS.

Every step is written to an append-only audit trail.

## Run locally

```bash
npm install
npm run dev        # http://localhost:4317
```

Without any configuration the app runs on built-in sample employees and requests, a demo sign-in screen (pick any employee), and a demo mail outbox at `/outbox` where every notification and its secure link can be opened.

Suggested demo: sign in as **Hind Alghamdi (HR)** → HR console → *Start clearance* for Sarah → open the link from the outbox as Sarah → add tasks → sign in as each recipient to accept/decline → approve as Fahad (manager) → approve as Hind (HR) → view report.

## Configuration

| Variable | Purpose |
| --- | --- |
| `MENAITECH_API_BASE_URL`, `MENAITECH_API_KEY` | Switch from sample data to the Menaitech REST API. |
| `MENAITECH_PATH_EMPLOYEES`, `MENAITECH_PATH_EMPLOYEE`, `MENAITECH_PATH_APPROVED_REQUESTS`, `MENAITECH_PATH_DOCUMENTS` | Override endpoint paths once the Menaitech API contract is confirmed (`{id}` is substituted). |
| `INTEGRATION_API_KEY` | Shared secret for `POST /api/integrations/menaitech/clearance` (header `x-api-key`). |
| `SESSION_SECRET` | Signs the session cookie. Set it in any shared environment. |
| `ALLOW_DEMO_LOGIN` | Set to `false` to hide the demo sign-in once HRMS authentication is wired in. |
| `APP_BASE_URL` | Base URL used in email links. Defaults to the request host. |
| `LINK_TTL_HOURS` | Lifetime of secure links (default 72). |
| `DATA_FILE` | JSON data store location (default `data/db.json`). |

## Integration endpoints

- `POST /api/integrations/menaitech/clearance` with `{ "requestRef": "VAC-2026-0412", "initiatedBy": "<HR employee id>" }` creates the handover and emails the employee.
- `GET /api/handovers/:id/document` returns the finalized structured record (same payload uploaded to the HRMS).

## Code map

- `src/lib/workflow.ts` holds the workflow rules (state transitions, notifications, audit, finalization).
- `src/lib/hr/` is the HRMS adapter: a sample-data provider and a Menaitech REST provider behind one interface.
- `src/app/` contains the pages: inbox, HR console, handover form, report, outbox, and sign-in.
