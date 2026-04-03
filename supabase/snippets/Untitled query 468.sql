-- Run this in Supabase Studio SQL Editor

-- Add gacha/pity tracking to player_profile
ALTER TABLE player_profile
ADD COLUMN IF NOT EXISTS pity_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS pity_count_4star INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS guaranteed_featured BOOLEAN DEFAULT false;

-- pulls column may already exist, add if not
ALTER TABLE player_profile
ADD COLUMN IF NOT EXISTS pulls INTEGER DEFAULT 0;

-- Card collection table (light cone cards)
CREATE TABLE IF NOT EXISTS player_cards_owned (
    id BIGSERIAL PRIMARY KEY,
    uid BIGINT NOT NULL REFERENCES player_profile(uid),
    card_item_id INTEGER NOT NULL,   -- matches GachaCard resource card_item_id
    stack_count INTEGER DEFAULT 1,   -- duplicates = superimposition
    equipped_to_character_id INTEGER DEFAULT 0,  -- 0 = unequipped
    created_at TIMESTAMP DEFAULT NOW()
);

-- Index for fast lookup
CREATE INDEX IF NOT EXISTS idx_player_cards_uid ON player_cards_owned(uid);