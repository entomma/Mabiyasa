-- Drop old columns if they exist
ALTER TABLE player_profile
DROP COLUMN IF EXISTS last_pos_x,
DROP COLUMN IF EXISTS last_pos_y,
DROP COLUMN IF EXISTS last_pos_z;

-- Add new zone + position tracking
ALTER TABLE player_profile
ADD COLUMN IF NOT EXISTS current_scene TEXT DEFAULT 'HubTown',
ADD COLUMN IF NOT EXISTS last_checkpoint TEXT DEFAULT 'start',
ADD COLUMN IF NOT EXISTS last_pos_x FLOAT DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_pos_y FLOAT DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_pos_z FLOAT DEFAULT 0,
ADD COLUMN IF NOT EXISTS saved_party INTEGER[] DEFAULT '{}';