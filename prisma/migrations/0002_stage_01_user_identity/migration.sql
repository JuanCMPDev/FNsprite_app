ALTER TABLE "User"
  ADD COLUMN "discordId" TEXT NOT NULL,
  ADD COLUMN "discordUsername" TEXT NOT NULL,
  ADD COLUMN "epicId" TEXT NOT NULL,
  ADD COLUMN "displayName" TEXT NOT NULL,
  ADD COLUMN "updatedAt" TIMESTAMP(3) NOT NULL;

CREATE UNIQUE INDEX "User_discordId_key" ON "User"("discordId");
CREATE UNIQUE INDEX "User_epicId_key" ON "User"("epicId");
