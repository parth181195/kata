-- First-run answers (sensor, body, film-sim families) that seed the library filter.
ALTER TABLE "users" ADD COLUMN "preferences" JSONB NOT NULL DEFAULT '{}';
