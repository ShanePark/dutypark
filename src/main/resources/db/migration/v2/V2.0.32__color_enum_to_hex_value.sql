-- Convert Color enum to hex color values
-- duty_type.color: Enum to VARCHAR(7)
-- team.default_duty_color: Enum to VARCHAR(7)

-- First, add new columns with VARCHAR(7) type
ALTER TABLE duty_type
    ADD COLUMN color_hex VARCHAR(7);
ALTER TABLE team
    ADD COLUMN default_duty_color_hex VARCHAR(7);

-- Update duty_type colors based on current enum values
UPDATE duty_type
SET color_hex =
        CASE color
            WHEN 'RED' THEN '#ffb3ba' -- lightpink
            WHEN 'BLUE' THEN '#f0f8ff' -- aliceblue
            WHEN 'PURPLE' THEN '#9370db' -- mediumpurple
            WHEN 'GREEN' THEN '#98fb98' -- palegreen
            WHEN 'YELLOW' THEN '#f5deb3' -- wheat
            WHEN 'GREY' THEN '#d3d3d3' -- lightgrey
            WHEN 'WHITE' THEN '#ffffff' -- white
            ELSE '#ffb3ba' -- default to lightpink
            END;

-- Update team default duty colors based on current enum values
UPDATE team
SET default_duty_color_hex =
        CASE default_duty_color
            WHEN 'RED' THEN '#ffb3ba' -- lightpink
            WHEN 'BLUE' THEN '#f0f8ff' -- aliceblue
            WHEN 'PURPLE' THEN '#9370db' -- mediumpurple
            WHEN 'GREEN' THEN '#98fb98' -- palegreen
            WHEN 'YELLOW' THEN '#f5deb3' -- wheat
            WHEN 'GREY' THEN '#d3d3d3' -- lightgrey
            WHEN 'WHITE' THEN '#ffffff' -- white
            ELSE '#ffb3ba' -- default to lightpink
            END;

-- Drop old enum columns
ALTER TABLE duty_type
    DROP COLUMN color;
ALTER TABLE team
    DROP COLUMN default_duty_color;

-- Rename new columns to original names
ALTER TABLE duty_type
    CHANGE color_hex color VARCHAR(7) NOT NULL;
ALTER TABLE team
    CHANGE default_duty_color_hex default_duty_color VARCHAR(7) NOT NULL;
