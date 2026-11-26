// Suggests handover tasks for one form. The browser calls this function;
// the model key stays in the secret GEMINI_API_KEY. One click is one short
// call to Gemini Flash-Lite. The person reviews the text before sending.

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

const model = "gemini-2.5-flash-lite";

function clip(value: unknown, max: number) {
  return `${value ?? ""}`.replace(/\s+/g, " ").trim().slice(0, max);
}

function tasksFromModel(text: string) {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start < 0 || end <= start) return [];
  const parsed = JSON.parse(text.slice(start, end + 1));
  const raw = Array.isArray(parsed?.tasks) ? parsed.tasks : [];
  const tasks: { title: string; details: string }[] = [];
  for (const item of raw) {
    const title = clip(item?.title, 120);
    const details = clip(item?.details, 400);
    if (title.length < 3) continue;
    tasks.push({ title, details });
    if (tasks.length === 5) break;
  }
  return tasks;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return new Response("method", { status: 405, headers: cors });

  const auth = req.headers.get("Authorization") ?? "";
  const apiKey = req.headers.get("apikey") ?? "";
  if (!auth.startsWith("Bearer ") || apiKey.length < 20) {
    return new Response("unauthorized", { status: 401, headers: cors });
  }

  let payload: {
    type?: string;
    job?: string;
    department?: string;
    lastWorkingDay?: string;
    notes?: string;
    existing?: unknown[];
  };
  try {
    payload = await req.json();
  } catch {
    return new Response("invalid", { status: 400, headers: cors });
  }

  const type = clip(payload.type, 40);
  const job = clip(payload.job, 80);
  const department = clip(payload.department, 80);
  const lastDay = clip(payload.lastWorkingDay, 20);
  const notes = clip(payload.notes, 600);
  const existing = Array.isArray(payload.existing)
    ? payload.existing.map((item) => clip(item, 120)).filter((item) => item.length >= 2).slice(0, 8)
    : [];
  if (type.length < 2 || job.length < 2) return new Response("invalid", { status: 400, headers: cors });

  const key = Deno.env.get("GEMINI_API_KEY") ?? "";
  if (!key) return new Response("assist", { status: 503, headers: cors });

  const prompt = [
    "اقترح 3 إلى 5 مهام تسليم لموظف في مجموعة الفارس.",
    'أعد JSON فقط: {"tasks":[{"title":"","details":""}]}',
    "العنوان بالعربية، والتفاصيل جملة أو جملتين عن الوضع الحالي وما المتبقي.",
    "لا تخترع أسماء موظفين. لا تكتب كلمة مرور أو رقم سري. لا تكرر مهمة مكتوبة مسبقاً.",
    `نوع الطلب: ${type}`,
    `المسمى: ${job}`,
    `القسم: ${department || "غير محدد"}`,
    lastDay ? `آخر يوم عمل: ${lastDay}` : "",
    notes ? `ملاحظات الموظف: ${notes}` : "",
    existing.length ? `مهام مكتوبة: ${existing.join(" | ")}` : "",
  ].filter(Boolean).join("\n");

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": key },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.3,
          maxOutputTokens: 700,
          responseMimeType: "application/json",
        },
      }),
    },
  );
  if (!response.ok) return new Response("assist", { status: 502, headers: cors });

  let data: { candidates?: { content?: { parts?: { text?: string }[] } }[] };
  try {
    data = await response.json();
  } catch {
    return new Response("assist", { status: 502, headers: cors });
  }
  const text = (data.candidates?.[0]?.content?.parts ?? []).map((part) => part.text ?? "").join("");
  let tasks: { title: string; details: string }[] = [];
  try {
    tasks = tasksFromModel(text);
  } catch {
    return new Response("assist", { status: 502, headers: cors });
  }
  return new Response(JSON.stringify({ tasks }), {
    status: 200,
    headers: { ...cors, "Content-Type": "application/json" },
  });
});
