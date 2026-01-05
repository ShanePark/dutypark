-- Add profile_photo_version column for cache busting
ALTER TABLE member ADD COLUMN profile_photo_version BIGINT NOT NULL DEFAULT 0;

-- Set initial version for existing photos
UPDATE member SET profile_photo_version = 1 WHERE profile_photo_path IS NOT NULL;
