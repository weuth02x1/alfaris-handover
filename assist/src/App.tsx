import { useState } from "react";
import {
  emptyDraft,
  intentLabel,
  opening,
  personLabel,
  samplePeople,
  turn,
  type Draft,
  type Person,
} from "./dialogue";

type Bubble = { from: "user" | "assist"; text: string };

const starters = ["إجازة", "استقالة", "نقل", "إخلاء طرف", "انتهاء العقد", "هوية"];

function rows(draft: Draft) {
  const who = samplePeople.find((person) => person.id === draft.recipientId);
  const items: [string, string][] = [];
  if (draft.intent) items.push(["الطلب", intentLabel(draft.intent)]);
  if (draft.start) items.push(["التاريخ", draft.start]);
  if (draft.end) items.push([draft.intent === "transfer" ? "الوجهة" : "الرجوع", draft.end]);
  if (draft.identityFor) items.push(["الهوية لـ", draft.identityFor]);
  if (draft.identityReason) items.push(["السبب", draft.identityReason]);
  if (draft.tasks) items.push(["المهام", draft.tasks]);
  if (draft.leftover) items.push(["الباقي", draft.leftover]);
  if (who) items.push(["يوصل إلى", personLabel(who)]);
  return items;
}

export function App() {
  const [draft, setDraft] = useState<Draft>(emptyDraft());
  const [bubbles, setBubbles] = useState<Bubble[]>([{ from: "assist", text: opening }]);
  const [text, setText] = useState("");
  const [choices, setChoices] = useState<Person[]>([]);
  const [ready, setReady] = useState(false);

  function say(value: string) {
    const clean = value.trim();
    if (!clean) return;
    const result = turn(draft, clean);
    setDraft(result.draft);
    setChoices(result.choices);
    setReady(result.ready);
    setBubbles((current) => [
      ...current,
      { from: "user", text: clean },
      { from: "assist", text: result.say },
    ]);
    setText("");
  }

  function reset() {
    setDraft(emptyDraft());
    setBubbles([{ from: "assist", text: opening }]);
    setChoices([]);
    setReady(false);
    setText("");
  }

  const filled = rows(draft);

  return (
    <div className="page">
      <header>
        <p className="mark">ALFARIS</p>
        <h1>مساعد الفارس</h1>
        <p className="note">
          مشروع تجهيز منفصل. يسأل عن الناقص ويطلع مسودة على هذا الجهاز. ما يرسل إيميل، وما هو مربوط بنظام التسليم.
        </p>
      </header>
      <main>
        <section className="chat" aria-label="المحادثة">
          <ol>
            {bubbles.map((bubble, index) => (
              <li key={index} className={bubble.from}>
                {bubble.text}
              </li>
            ))}
          </ol>
          {draft.intent === null && (
            <div className="chips">
              {starters.map((item) => (
                <button key={item} type="button" onClick={() => say(`أبي ${item}`)}>
                  {item}
                </button>
              ))}
            </div>
          )}
          {choices.length > 0 && (
            <div className="chips">
              {choices.map((person) => (
                <button key={person.id} type="button" onClick={() => say(person.name)}>
                  {personLabel(person)}
                </button>
              ))}
            </div>
          )}
          <form
            onSubmit={(event) => {
              event.preventDefault();
              say(text);
            }}
          >
            <input
              value={text}
              onChange={(event) => setText(event.target.value)}
              placeholder="اكتب طلبك هنا"
              aria-label="نص الطلب"
            />
            <button type="submit">إرسال للمحادثة</button>
          </form>
        </section>
        <aside>
          <div className="card">
            <h2>المسودة</h2>
            {filled.length === 0 ? (
              <p className="empty">تتعبّى هنا كلما جاوبت. ما تنحفظ في نظام التسليم.</p>
            ) : (
              <dl>
                {filled.map(([label, value]) => (
                  <div key={label}>
                    <dt>{label}</dt>
                    <dd>{value}</dd>
                  </div>
                ))}
              </dl>
            )}
            <p className={ready ? "ready" : "wait"}>
              {ready
                ? "المسودة مكتملة هنا فقط. الربط والإرسال الفعلي يجيان لاحقاً."
                : "الإرسال الفعلي مقفل إلى أن نربط هذا المشروع بنظام التسليم."}
            </p>
            <button type="button" className="ghost" onClick={reset}>
              طلب جديد
            </button>
          </div>
          <p className="sample">
            الأسماء في القائمة أمثلة داخل هذا المشروع: نورة، فهد، ولمى. ليست حسابات الشركة.
          </p>
        </aside>
      </main>
    </div>
  );
}
