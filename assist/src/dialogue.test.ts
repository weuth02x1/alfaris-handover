import { describe, expect, it } from "vitest";
import { emptyDraft, personLabel, samplePeople, turn } from "./dialogue";

describe("side-project dialogue", () => {
  it("fills a vacation from one sentence and keeps the department on the recipient", () => {
    const result = turn(
      emptyDraft(),
      "أبي إجازة من 1 يونيو إلى 15 يونيو، وأسلم متابعة الرواتب لنورة، وباقي تقرير الأسبوع",
    );
    expect(result.ready).toBe(true);
    expect(result.draft.intent).toBe("vacation");
    expect(result.draft.start).toBe("1 يونيو");
    expect(result.draft.end).toBe("15 يونيو");
    expect(result.draft.tasks).toBe("متابعة الرواتب");
    expect(result.draft.leftover).toBe("تقرير الأسبوع");
    expect(result.draft.recipientId).toBe("noura");
    expect(result.say).toContain(personLabel(samplePeople[0]));
    expect(result.say).toContain("ما انرسل");
  });

  it("asks one missing piece at a time", () => {
    const first = turn(emptyDraft(), "أبي إجازة");
    expect(first.ready).toBe(false);
    expect(first.say).toContain("من متى");

    const dates = turn(first.draft, "من 1 يونيو إلى 15 يونيو");
    expect(dates.draft.start).toBe("1 يونيو");
    expect(dates.say).toContain("المهام");

    const tasks = turn(dates.draft, "متابعة الرواتب");
    expect(tasks.draft.tasks).toBe("متابعة الرواتب");
    expect(tasks.say).toContain("الباقي");

    const left = turn(tasks.draft, "تقرير الأسبوع");
    expect(left.choices.map(personLabel)).toEqual([
      "نورة · تطوير تقنية المعلومات",
      "فهد · استقطاب المواهب",
      "لمى · الموارد البشرية",
    ]);
    const done = turn(left.draft, "لمى");
    expect(done.ready).toBe(true);
    expect(done.draft.recipientId).toBe("lama");
  });

  it("treats a company identity as its own request", () => {
    const result = turn(emptyDraft(), "أبي طلب هوية لنورة لأن البطاقة ضاعت");
    expect(result.draft.intent).toBe("identity");
    expect(result.draft.identityFor).toBe("نورة");
    expect(result.draft.identityReason).toBe("البطاقة ضاعت");
    expect(result.draft.recipientId).toBeNull();
    expect(result.ready).toBe(false);
    expect(result.choices.map((person) => person.department)).toContain("الموارد البشرية");
  });

  it("keeps an unfamiliar request as a draft instead of sending it", () => {
    const result = turn(emptyDraft(), "أبي طلب طابعة جديدة للقسم");
    expect(result.draft.intent).toBe("other");
    expect(result.ready).toBe(false);
    expect(result.choices).toHaveLength(3);
  });
});
