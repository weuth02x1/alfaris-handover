import "server-only";
import { promises as fs } from "fs";
import path from "path";
import type { Database } from "@/lib/types";

const DATA_FILE = process.env.DATA_FILE || path.join(process.cwd(), "data", "db.json");

const empty = (): Database => ({
  handovers: [],
  audit: [],
  outbox: [],
  tokens: [],
  counter: 0,
});

let queue: Promise<unknown> = Promise.resolve();

async function load(): Promise<Database> {
  try {
    return { ...empty(), ...JSON.parse(await fs.readFile(DATA_FILE, "utf8")) };
  } catch {
    return empty();
  }
}

async function save(db: Database) {
  await fs.mkdir(path.dirname(DATA_FILE), { recursive: true });
  const tmp = `${DATA_FILE}.${process.pid}.tmp`;
  await fs.writeFile(tmp, JSON.stringify(db, null, 2));
  await fs.rename(tmp, DATA_FILE);
}

export async function readDb(): Promise<Database> {
  await queue.catch(() => {});
  return load();
}

/** Serialises writes so concurrent actions never clobber each other. */
export function mutate<T>(fn: (db: Database) => T | Promise<T>): Promise<T> {
  const run = queue.catch(() => {}).then(async () => {
    const db = await load();
    const result = await fn(db);
    await save(db);
    return result;
  });
  queue = run;
  return run;
}
