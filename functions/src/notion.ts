/**
 * Sends captures to his Notion inbox. The Notion key lives only in Firebase
 * secrets. Lobby reads the inbox database once to find its title column and,
 * if there is one, a due-date column, so it works with whatever he's set up.
 */

const NOTION = "https://api.notion.com/v1";
const NOTION_VERSION = "2022-06-28";

export interface CaptureDoc {
  text: string;
  title: string;
  kind: "task" | "reminder" | "waitingOn";
  /** ISO 8601. */
  createdAt: string;
  due?: string | null;
  projectID?: string | null;
}

export interface InboxShape {
  titleProperty: string;
  dueProperty: string | null;
}

interface DatabaseResponse {
  properties: Record<string, { type: string }>;
}

/** Finds the title column and a date column called something like "Due". */
export function inboxShape(database: DatabaseResponse): InboxShape {
  const entries = Object.entries(database.properties);
  const title = entries.find(([, p]) => p.type === "title")?.[0] ?? "Name";
  const due =
    entries.find(([name, p]) => p.type === "date" && /due/i.test(name))?.[0] ??
    entries.find(([name, p]) => p.type === "date" && /date|when/i.test(name))?.[0] ??
    null;
  return { titleProperty: title, dueProperty: due };
}

/** The page Notion should create for a capture. Reminders stay on the Mac. */
export function pageFor(capture: CaptureDoc, databaseID: string, shape: InboxShape): Record<string, unknown> | null {
  if (capture.kind === "reminder") return null;
  const title = capture.kind === "waitingOn" ? `Waiting on: ${capture.title}` : capture.title;
  const properties: Record<string, unknown> = {
    [shape.titleProperty]: { title: [{ text: { content: title.slice(0, 2000) } }] },
  };
  if (shape.dueProperty && capture.due) {
    properties[shape.dueProperty] = { date: { start: capture.due.slice(0, 10) } };
  }
  return {
    parent: { database_id: databaseID },
    properties,
    children: capture.text !== capture.title
      ? [{ object: "block", type: "paragraph", paragraph: { rich_text: [{ text: { content: `Captured: ${capture.text}`.slice(0, 2000) } }] } }]
      : [],
  };
}

async function notion<T>(path: string, token: string, init: { method?: string; body?: unknown } = {}): Promise<T> {
  const response = await fetch(`${NOTION}${path}`, {
    method: init.method ?? "GET",
    headers: {
      Authorization: `Bearer ${token}`,
      "Notion-Version": NOTION_VERSION,
      "Content-Type": "application/json",
    },
    body: init.body ? JSON.stringify(init.body) : undefined,
    signal: AbortSignal.timeout(15_000),
  });
  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    throw new Error(`Notion answered ${response.status}: ${detail.slice(0, 300)}`);
  }
  return response.json() as Promise<T>;
}

interface BlockChildren {
  results: { id: string; type: string }[];
}

/** The first database living inside a page, if any. */
export function childDatabaseID(children: BlockChildren): string | null {
  return children.results.find((block) => block.type === "child_database")?.id ?? null;
}

let resolved: { input: string; databaseID: string; shape: InboxShape } | null = null;

/**
 * Accepts the ID of the inbox database itself, or of a page that holds it
 * (Notion gives the two different links, and a table typed into a page is
 * the second kind). Looked up once per function instance.
 */
async function resolveInbox(idOrPageID: string, token: string) {
  if (resolved && resolved.input === idOrPageID) return resolved;
  const clean = idOrPageID.trim().replace(/-/g, "");
  let databaseID = clean;
  let database: DatabaseResponse | null = null;
  try {
    database = await notion<DatabaseResponse>(`/databases/${clean}`, token);
  } catch {
    // Not a database: maybe a page with one inside.
  }
  if (!database) {
    const children = await notion<BlockChildren>(`/blocks/${clean}/children?page_size=50`, token);
    const inner = childDatabaseID(children);
    if (!inner) {
      throw new Error("NOTION_INBOX_DATABASE_ID is neither a database nor a page with a table in it. Check the link and that the Lobby integration has access to it.");
    }
    databaseID = inner;
    database = await notion<DatabaseResponse>(`/databases/${databaseID}`, token);
  }
  resolved = { input: idOrPageID, databaseID, shape: inboxShape(database) };
  return resolved;
}

export async function sendToNotion(capture: CaptureDoc, token: string, idOrPageID: string): Promise<string | null> {
  const inbox = await resolveInbox(idOrPageID, token);
  const page = pageFor(capture, inbox.databaseID, inbox.shape);
  if (!page) return null;
  const created = await notion<{ id: string }>("/pages", token, { method: "POST", body: page });
  return created.id;
}
