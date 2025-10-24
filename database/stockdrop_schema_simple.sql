-- StockDrop Database Schema (Simplified Version)
-- This is a simplified version without the auto-trigger for user settings
-- Use this if you encounter permission issues with the main script

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create st_favorites table
CREATE TABLE IF NOT EXISTS public.st_favorites (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    symbol TEXT NOT NULL,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, symbol)
);

-- Create st_settings table
CREATE TABLE IF NOT EXISTS public.st_settings (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    notification_threshold INT DEFAULT 5,
    theme TEXT DEFAULT 'light',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id),
    CONSTRAINT valid_theme CHECK (theme IN ('light', 'dark', 'system')),
    CONSTRAINT valid_threshold CHECK (notification_threshold >= 0 AND notification_threshold <= 100)
);

-- Enable RLS
ALTER TABLE public.st_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.st_settings ENABLE ROW LEVEL SECURITY;

-- RLS Policies for st_favorites
CREATE POLICY "Users can manage their own favorites" ON public.st_favorites
    FOR ALL USING (auth.uid() = user_id);

-- RLS Policies for st_settings  
CREATE POLICY "Users can manage their own settings" ON public.st_settings
    FOR ALL USING (auth.uid() = user_id);

-- Create indexes
CREATE INDEX idx_st_favorites_user_id ON public.st_favorites(user_id);
CREATE INDEX idx_st_settings_user_id ON public.st_settings(user_id);

-- Grant permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON public.st_favorites TO authenticated;
GRANT ALL ON public.st_settings TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;