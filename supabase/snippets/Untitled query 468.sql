-- Run this in Supabase SQL editor
ALTER TABLE player_profile 
ADD COLUMN party_loadouts JSONB DEFAULT '{}'::jsonb,
ADD COLUMN current_loadout INTEGER DEFAULT 1;