import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

const rootDir = join(import.meta.dirname, "../../..");
const schema = readFileSync(join(rootDir, "prisma/schema.prisma"), "utf8");
const migrationsDir = join(rootDir, "prisma/migrations");
const migrationsSql = readdirSync(migrationsDir, { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) =>
    readFileSync(join(migrationsDir, entry.name, "migration.sql"), "utf8"),
  )
  .join("\n");

function userModelBody() {
  const match = schema.match(/model User \{(?<body>[\s\S]*?)\n\}/);

  expect(match?.groups?.body).toBeDefined();

  return match?.groups?.body ?? "";
}

describe("@stage-01 User model", () => {
  it("stores unique public identity fields for Discord and Epic", () => {
    const userModel = userModelBody();

    expect(userModel).toMatch(/\bdiscordId\s+String\s+@unique\b/);
    expect(userModel).toMatch(/\bdiscordUsername\s+String\b/);
    expect(userModel).toMatch(/\bepicId\s+String\s+@unique\b/);
    expect(userModel).toMatch(/\bdisplayName\s+String\b/);
    expect(migrationsSql).toMatch(/UNIQUE INDEX "User_discordId_key"/);
    expect(migrationsSql).toMatch(/UNIQUE INDEX "User_epicId_key"/);
  });

  it("does not persist Epic credentials or secret material", () => {
    const forbiddenCredentialFields =
      /epic.*(password|passphrase|secret|token|credential)/i;

    expect(schema).not.toMatch(forbiddenCredentialFields);
    expect(migrationsSql).not.toMatch(forbiddenCredentialFields);
  });
});
