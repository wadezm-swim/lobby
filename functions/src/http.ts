/** Small fetch helpers with a timeout and an honest User-Agent. */

export interface FetchOptions {
  userAgent?: string;
  timeoutMs?: number;
  headers?: Record<string, string>;
}

const DEFAULT_UA = "Lobby/0.1 (personal dashboard; https://github.com/wadezm-swim/lobby)";

async function request(url: string, options: FetchOptions = {}): Promise<Response> {
  const response = await fetch(url, {
    headers: { "User-Agent": options.userAgent ?? DEFAULT_UA, ...options.headers },
    signal: AbortSignal.timeout(options.timeoutMs ?? 15_000),
  });
  if (!response.ok) {
    throw new Error(`${url} answered ${response.status}`);
  }
  return response;
}

export async function getJson<T>(url: string, options?: FetchOptions): Promise<T> {
  return (await request(url, options)).json() as Promise<T>;
}

export async function getText(url: string, options?: FetchOptions): Promise<string> {
  return (await request(url, options)).text();
}

/** Squiggle asks for a descriptive User-Agent with a way to get in touch. */
export function squiggleUserAgent(contact: string): string {
  return `Lobby/0.1 (personal AFL dashboard; contact ${contact})`;
}
