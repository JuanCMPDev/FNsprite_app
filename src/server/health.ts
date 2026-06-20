import { prisma } from "./db";

type DatabaseProbe = Pick<typeof prisma, "$queryRaw">;

export type HealthResponseBody =
  | {
      database: "ok";
      status: "ok";
    }
  | {
      database: "unavailable";
      status: "error";
    };

export async function readHealth(
  database: DatabaseProbe = prisma,
): Promise<{ body: HealthResponseBody; status: 200 | 503 }> {
  try {
    await database.$queryRaw`SELECT 1`;

    return {
      body: {
        database: "ok",
        status: "ok",
      },
      status: 200,
    };
  } catch {
    return {
      body: {
        database: "unavailable",
        status: "error",
      },
      status: 503,
    };
  }
}
