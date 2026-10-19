import { readFileSync } from "node:fs";
import { join } from "node:path";

export function fixture(name: string): string {
  return readFileSync(join(__dirname, "fixtures", name), "utf8");
}

export function json<T>(name: string): T {
  return JSON.parse(fixture(name)) as T;
}
