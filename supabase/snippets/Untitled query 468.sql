
CREATE SEQUENCE player_uid_seq START 10000;

-- Player Profile
CREATE TABLE player_profile (
    uid BIGINT PRIMARY KEY DEFAULT nextval('player_uid_seq'),
    account_id UUID REFERENCES auth.users(id) UNIQUE NOT NULL,
    username TEXT UNIQUE NOT NULL,
    display_name TEXT,
    account_level INTEGER DEFAULT 1,
    account_exp INTEGER DEFAULT 0,
    world_level INTEGER DEFAULT 1,
    gold INTEGER DEFAULT 0,
    pulls INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Player Characters (owned characters)
CREATE TABLE player_characters (
    id SERIAL PRIMARY KEY,
    uid BIGINT REFERENCES player_profile(uid),
    character_id INTEGER NOT NULL,
    current_level INTEGER DEFAULT 1,
    current_exp INTEGER DEFAULT 0,
    basic_level INTEGER DEFAULT 1,
    skill_level INTEGER DEFAULT 1,
    ult_level INTEGER DEFAULT 1,
    talent_level INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Player Cards (word cards owned)
CREATE TABLE player_cards (
    id SERIAL PRIMARY KEY,
    uid BIGINT REFERENCES player_profile(uid),
    card_id INTEGER NOT NULL,
    times_used INTEGER DEFAULT 0,
    is_mastered BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Player Inventory
CREATE TABLE player_inventory (
    id SERIAL PRIMARY KEY,
    uid BIGINT REFERENCES player_profile(uid),
    item_type TEXT NOT NULL,
    item_id INTEGER NOT NULL,
    quantity INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Battle Log
CREATE TABLE battle_log (
    id SERIAL PRIMARY KEY,
    uid BIGINT REFERENCES player_profile(uid),
    enemy_id INTEGER NOT NULL,
    sentence_used TEXT NOT NULL,
    was_valid BOOLEAN NOT NULL,
    damage_dealt INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Row Level Security
ALTER TABLE player_profile ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_characters ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE battle_log ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view own profile" ON player_profile
    FOR ALL USING (auth.uid() = account_id);

CREATE POLICY "Users can view own characters" ON player_characters
    FOR ALL USING (uid IN (
        SELECT uid FROM player_profile WHERE account_id = auth.uid()
    ));

CREATE POLICY "Users can view own cards" ON player_cards
    FOR ALL USING (uid IN (
        SELECT uid FROM player_profile WHERE account_id = auth.uid()
    ));

CREATE POLICY "Users can view own inventory" ON player_inventory
    FOR ALL USING (uid IN (
        SELECT uid FROM player_profile WHERE account_id = auth.uid()
    ));

CREATE POLICY "Users can view own battle log" ON battle_log
    FOR ALL USING (uid IN (
        SELECT uid FROM player_profile WHERE account_id = auth.uid()
    ));

