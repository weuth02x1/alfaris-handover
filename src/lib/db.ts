import "server-only";
import { promises as fs } from "fs";
import path from "path";
import { randomBytes } from "crypto";
import { Pool } from "pg";
import type { Database } from "@/lib/types";

const DATA_FILE = process.env.DATA_FILE || path.join(process.cwd(), "data", "db.json");

const empty = (): Database => ({
  handovers: [],
  audit: [],
  outbox: [],
  tokens: [],
  counter: 0,
  sessionKey: randomBytes(32).toString("base64url"),
});

const normalize = (raw: Partial<Database> | null): Database => {
  const base = empty();
  return { ...base, ...(raw ?? {}), sessionKey: raw?.sessionKey || base.sessionKey };
};

interface Store {
  read(): Promise<Database>;
  mutate<T>(fn: (db: Database) => T | Promise<T>): Promise<T>;
}

/** Local development: one JSON file, writes serialised in-process. */
class FileStore implements Store {
  private queue: Promise<unknown> = Promise.resolve();

  private async load() {
    try {
      return normalize(JSON.parse(await fs.readFile(/*turbopackIgnore: true*/ DATA_FILE, "utf8")));
    } catch {
      return normalize(null);
    }
  }

  private async save(db: Database) {
    await fs.mkdir(/*turbopackIgnore: true*/ path.dirname(DATA_FILE), { recursive: true });
    const tmp = `${DATA_FILE}.${process.pid}.tmp`;
    await fs.writeFile(/*turbopackIgnore: true*/ tmp, JSON.stringify(db, null, 2));
    await fs.rename(/*turbopackIgnore: true*/ tmp, DATA_FILE);
  }

  async read() {
    await this.queue.catch(() => {});
    return this.load();
  }

  mutate<T>(fn: (db: Database) => T | Promise<T>): Promise<T> {
    const run = this.queue.catch(() => {}).then(async () => {
      const db = await this.load();
      const result = await fn(db);
      await this.save(db);
      return result;
    });
    this.queue = run;
    return run;
  }
}

/** Hosted: the whole state in one jsonb row, writes serialised with a row lock. */
class PgStore implements Store {
  private pool: Pool;
  private ready: Promise<void>;

  constructor(url: string) {
    this.pool = new Pool({ connectionString: url, max: 5 });
    this.ready = this.pool
      .query(
        `CREATE TABLE IF NOT EXISTS app_state (id int PRIMARY KEY, data jsonb NOT NULL);
         INSERT INTO app_state (id, data) VALUES (1, '{}'::jsonb) ON CONFLICT (id) DO NOTHING;`,
      )
      .then(() => undefined);
  }

  async read() {
    await this.ready;
    const { rows } = await this.pool.query("SELECT data FROM app_state WHERE id = 1");
    return normalize(rows[0]?.data ?? null);
  }

  async mutate<T>(fn: (db: Database) => T | Promise<T>): Promise<T> {
    await this.ready;
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const { rows } = await client.query("SELECT data FROM app_state WHERE id = 1 FOR UPDATE");
      const db = normalize(rows[0]?.data ?? null);
      const result = await fn(db);
      await client.query("UPDATE app_state SET data = $1 WHERE id = 1", [JSON.stringify(db)]);
      await client.query("COMMIT");
      return result;
    } catch (e) {
      await client.query("ROLLBACK").catch(() => {});
      throw e;
    } finally {
      client.release();
    }
  }
}

let store: Store | null = null;
function getStore() {
  if (!store) store = process.env.DATABASE_URL ? new PgStore(process.env.DATABASE_URL) : new FileStore();
  return store;
}

export const readDb = () => getStore().read();
export const mutate = <T>(fn: (db: Database) => T | Promise<T>) => getStore().mutate(fn);

let cachedKey: string | null = null;
/** Signing key for sessions: SESSION_SECRET when set, otherwise one generated and persisted on first use. */
export async function sessionKey() {
  if (process.env.SESSION_SECRET) return process.env.SESSION_SECRET;
  cachedKey ??= await mutate((d) => d.sessionKey);
  return cachedKey;
}
