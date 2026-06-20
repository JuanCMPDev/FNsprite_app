import { NextResponse } from "next/server";

import { readHealth } from "@/src/server/health";

export const dynamic = "force-dynamic";

export async function GET() {
  const health = await readHealth();

  return NextResponse.json(health.body, {
    status: health.status,
  });
}
