export type Intent =
  | "vacation"
  | "resignation"
  | "transfer"
  | "clearance"
  | "contract_end"
  | "identity"
  | "other";

export type Person = {
  id: string;
  name: string;
  department: string;
};

/** Sample names for this side project only. They are not company accounts. */
export const samplePeople: Person[] = [
  { id: "noura", name: "نورة", department: "تطوير تقنية المعلومات" },
  { id: "fahad", name: "فهد", department: "استقطاب المواهب" },
  { id: "lama", name: "لمى", department: "الموارد البشرية" },
];

export type Field =
  | "intent"
  | "start"
  | "end"
  | "tasks"
  | "leftover"
  | "recipientId"
  | "identityFor"
  | "identityReason";

export type Draft = {
  intent: Intent | null;
  start: string | null;
  end: string | null;
  tasks: string | null;
  leftover: string | null;
  recipientId: string | null;
  identityFor: string | null;
  identityReason: string | null;
};

export type Turn = {
  draft: Draft;
  say: string;
  ready: boolean;
  choices: Person[];
};

const intentWords: [Intent, string[]][] = [
  ["vacation", ["اجازه", "vacation"]],
  ["resignation", ["استقاله"]],
  ["transfer", ["نقل"]],
  ["clearance", ["اخلاء"]],
  ["contract_end", ["انتهاء العقد", "نهايه العقد"]],
  ["identity", ["هويه"]],
];

export function emptyDraft(): Draft {
  return {
    intent: null,
    start: null,
    end: null,
    tasks: null,
    leftover: null,
    recipientId: null,
    identityFor: null,
    identityReason: null,
  };
}

export function personLabel(person: Person) {
  return `${person.name} · ${person.department}`;
}

export function intentLabel(intent: Intent) {
  switch (intent) {
    case "vacation":
      return "إجازة";
    case "resignation":
      return "استقالة";
    case "transfer":
      return "نقل";
    case "clearance":
      return "إخلاء طرف";
    case "contract_end":
      return "انتهاء العقد";
    case "identity":
      return "هوية";
    case "other":
      return "طلب آخر";
  }
}

function fold(value: string) {
  const eastern = "٠١٢٣٤٥٦٧٨٩";
  let out = "";
  for (const ch of value) {
    const at = eastern.indexOf(ch);
    out += at >= 0 ? String(at) : ch;
  }
  return out
    .trim()
    .replace(/[أإآ]/g, "ا")
    .replace(/ة/g, "ه")
    .replace(/ى/g, "ي")
    .replace(/\s+/g, " ");
}

function clean(value: string) {
  return value.replace(/^[\s،,:\-]+|[\s،,\.]+$/g, "").trim();
}

function findIntent(text: string): Intent | null {
  const folded = fold(text);
  for (const [intent, words] of intentWords) {
    if (words.some((word) => folded.includes(word))) return intent;
  }
  return null;
}

function findPerson(text: string): string | null {
  const folded = fold(text);
  for (const person of samplePeople) {
    if (folded.includes(fold(person.name))) return person.id;
  }
  return null;
}

function grabRange(text: string) {
  const match = text.match(/من\s+(.+?)\s+(?:إلى|الى)\s+([^،,\n]+)/);
  if (!match) return {};
  return { start: clean(match[1]), end: clean(match[2]) };
}

function grabTasks(text: string) {
  const match = text.match(/(?:أسلم|اسلم|اسلّم|المهمة|المهام)\s+(.+)/);
  if (!match) return null;
  const piece = match[1].split(/و?\s*باقي|الباقي/)[0];
  const withoutPerson = piece.replace(/\s+ل(?:نورة|فهد|لمى)[\s،,.]*.*$/, "");
  const value = clean(withoutPerson);
  return value.length >= 2 ? value : null;
}

function grabLeftover(text: string) {
  const match = text.match(/(?:الباقي|باقي|المتبقي|المتبقى)\s+(.+)/);
  if (!match) return null;
  const value = clean(match[1]);
  return value.length >= 2 ? value : null;
}

function needed(intent: Intent): Field[] {
  switch (intent) {
    case "vacation":
      return ["start", "end", "tasks", "leftover", "recipientId"];
    case "transfer":
      return ["start", "end", "tasks", "leftover", "recipientId"];
    case "resignation":
    case "clearance":
    case "contract_end":
      return ["start", "tasks", "leftover", "recipientId"];
    case "identity":
      return ["identityFor", "identityReason", "recipientId"];
    case "other":
      return ["tasks", "recipientId"];
  }
}

export function missing(draft: Draft): Field | null {
  if (!draft.intent) return "intent";
  for (const field of needed(draft.intent)) {
    if (!draft[field]) return field;
  }
  return null;
}

function question(draft: Draft, field: Field) {
  const intent = draft.intent;
  switch (field) {
    case "intent":
      return "وش تبي؟ إجازة، استقالة، نقل، إخلاء طرف، انتهاء عقد، أو هوية.";
    case "start":
      return intent === "vacation"
        ? "من متى الإجازة، ومتى الرجوع؟"
        : "متى آخر يوم عمل؟";
    case "end":
      return intent === "transfer"
        ? "النقل إلى أي قسم أو فرع؟"
        : "ومتى تاريخ الرجوع؟";
    case "tasks":
      return intent === "other"
        ? "اشرح الطلب بجملة."
        : "وش المهام اللي بتسلمها؟";
    case "leftover":
      return "وش الباقي على هالمهمة؟";
    case "recipientId":
      return "لمين يروح الطلب؟ الاسم ومعه القسم.";
    case "identityFor":
      return "الهوية لمين؟";
    case "identityReason":
      return "وش سبب طلب الهوية؟";
  }
}

function summary(draft: Draft) {
  const who = samplePeople.find((person) => person.id === draft.recipientId);
  const receiver = who ? personLabel(who) : "";
  return `مسودة ${intentLabel(draft.intent!)} جاهزة${receiver ? `، وتوصل إلى ${receiver}` : ""}. راجعها تحت. ما انرسل شيء، والربط بنظام التسليم يكون لاحقاً.`;
}

export function turn(draft: Draft, text: string): Turn {
  const saying = text.trim();
  const next: Draft = { ...draft };
  if (!saying) {
    const field = missing(next);
    return {
      draft: next,
      say: field ? question(next, field) : summary(next),
      ready: field === null,
      choices: field === "recipientId" ? samplePeople : [],
    };
  }

  const asked = missing(next);
  const intent = findIntent(saying);
  if (intent && (next.intent === null || asked === "intent")) next.intent = intent;

  const range = grabRange(saying);
  if (range.start && !next.start) next.start = range.start;
  if (range.end && !next.end) next.end = range.end;

  const tasks = grabTasks(saying);
  if (tasks && !next.tasks) next.tasks = tasks;
  const leftover = grabLeftover(saying);
  if (leftover && !next.leftover) next.leftover = leftover;
  const because = saying.match(/(?:لأن|لان|بسبب)\s+(.+)/);
  if (because && !next.identityReason) next.identityReason = clean(because[1]);

  const person = findPerson(saying);
  if (person && next.intent === "identity" && !next.identityFor) {
    next.identityFor = samplePeople.find((item) => item.id === person)!.name;
  } else if (person && !next.recipientId) {
    next.recipientId = person;
  }
  if (!next.intent && saying.length > 8) {
    next.intent = "other";
    next.tasks = clean(saying);
  }

  const still = missing(next);
  const onlyIntent =
    intent !== null &&
    fold(saying).replace(/ابي|ابغى|طلب|ال|من فضلك/g, "").trim().length <=
      (intent === "contract_end" ? 14 : 8);
  if (
    still &&
    still === asked &&
    asked !== "intent" &&
    asked !== "recipientId" &&
    !onlyIntent &&
    saying.length >= 2
  ) {
    if (asked === "start" && range.start) {
      /* already stored */
    } else {
      next[asked] = clean(saying);
    }
  }

  const field = missing(next);
  return {
    draft: next,
    say: field ? question(next, field) : summary(next),
    ready: field === null,
    choices: field === "recipientId" ? samplePeople : [],
  };
}

export const opening =
  "اكتب طلبك بكلامك. مثال: أبي إجازة من 1 يونيو إلى 15 يونيو، وأسلم متابعة الرواتب لنورة، وباقي تقرير الأسبوع.";
