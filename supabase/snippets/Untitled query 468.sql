-- Add a unique constraint to prevent duplicate item rows for the same player
ALTER TABLE public.player_inventory 
ADD CONSTRAINT unique_player_item UNIQUE (uid, item_id, item_type);

-- Enable Row Level Security (if you haven't already)
ALTER TABLE public.player_inventory ENABLE ROW LEVEL SECURITY;

-- Allow players to only see and modify their own inventory
CREATE POLICY "Users manage their own inventory" 
ON public.player_inventory FOR ALL 
USING ( uid = (SELECT uid FROM player_profile WHERE account_id = auth.uid()) );