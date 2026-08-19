-- CreateTable
CREATE TABLE "user_cameras" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "model" TEXT NOT NULL,
    "firmware" TEXT NOT NULL,
    "pid" INTEGER,
    "slots" INTEGER NOT NULL,
    "props" INTEGER NOT NULL DEFAULT 0,
    "firstSeen" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastSeen" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "seenCount" INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT "user_cameras_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "user_cameras_model_idx" ON "user_cameras"("model");

-- CreateIndex
CREATE UNIQUE INDEX "user_cameras_userId_model_firmware_key" ON "user_cameras"("userId", "model", "firmware");

-- AddForeignKey
ALTER TABLE "user_cameras" ADD CONSTRAINT "user_cameras_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
