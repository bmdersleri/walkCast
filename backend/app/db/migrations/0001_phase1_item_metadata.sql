-- Phase 1 schema updates for walkCast items table
-- Adds metadata and workflow fields required by PRODUCT_REQUIREMENTS.md

ALTER TABLE items
    ADD COLUMN IF NOT EXISTS duration VARCHAR,
    ADD COLUMN IF NOT EXISTS is_listened BOOLEAN NOT NULL DEFAULT FALSE;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'item_status') THEN
        CREATE TYPE item_status AS ENUM (
            'queued',
            'downloading',
            'converting_mp3',
            'ready',
            'error'
        );
    END IF;
END$$;

ALTER TABLE items
    ADD COLUMN IF NOT EXISTS status item_status NOT NULL DEFAULT 'queued';
