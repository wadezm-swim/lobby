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

export async function sendToNotion(capture: CaptureDoc, token: string, databaseID: string): Promise<string | null> {
  const shape = inboxShape(await notion<DatabaseResponse>(`/databases/${databaseID}`, token));
  const page = pageFor(capture, databaseID, shape);
  if (!page) return null;
  const created = await notion<{ id: string }>("/pages", token, { method: "POST", body: page });
  return created.id;
}
