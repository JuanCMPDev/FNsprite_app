import { describe, expect, it, vi } from "vitest";

const queryRawMock = vi.hoisted(() => vi.fn());

vi.mock("../../../src/server/db", () => ({
  prisma: {
    $queryRaw: queryRawMock,
  },
}));

const { GET } = await import("../../../app/api/health/route");

describe("GET /api/health", () => {
  it("returns 200 when Postgres responds", async () => {
    queryRawMock.mockResolvedValueOnce([{ ok: 1 }]);

    const response = await GET();

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({
      database: "ok",
      status: "ok",
    });
  });

  it("returns 503 when Postgres is unavailable", async () => {
    queryRawMock.mockRejectedValueOnce(new Error("database unavailable"));

    const response = await GET();

    expect(response.status).toBe(503);
    await expect(response.json()).resolves.toEqual({
      database: "unavailable",
      status: "error",
    });
  });
});
