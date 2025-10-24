-- StockDrop Database Schema for Supabase PostgreSQL
-- This script creates the necessary tables and security policies for the StockDrop stock market app
-- Run this script in the Supabase SQL Editor

-- Enable UUID extension for generating UUIDs
-- This extension is required for UUID functions used in the tables
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create st_favorites table
-- This table stores user's favorite stock symbols
CREATE TABLE IF NOT EXISTS public.st_favorites (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    symbol TEXT NOT NULL,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure a user can't favorite the same symbol twice
    UNIQUE(user_id, symbol)
);

-- Add comments to st_favorites table and columns
COMMENT ON TABLE public.st_favorites IS 'Stores user favorite stock symbols for the StockDrop app';
COMMENT ON COLUMN public.st_favorites.id IS 'Primary key, auto-incrementing identifier';
COMMENT ON COLUMN public.st_favorites.user_id IS 'Foreign key referencing auth.users, identifies the user who favorited the stock';
COMMENT ON COLUMN public.st_favorites.symbol IS 'Stock symbol (e.g., AAPL, GOOGL, TSLA)';
COMMENT ON COLUMN public.st_favorites.added_at IS 'Timestamp when the stock was added to favorites';

-- Create st_settings table
-- This table stores user preferences and settings
CREATE TABLE IF NOT EXISTS public.st_settings (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    notification_threshold INT DEFAULT 5,
    theme TEXT DEFAULT 'light',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure each user has only one settings record
    UNIQUE(user_id),
    
    -- Add constraints for valid values
    CONSTRAINT valid_theme CHECK (theme IN ('light', 'dark', 'system')),
    CONSTRAINT valid_threshold CHECK (notification_threshold >= 0 AND notification_threshold <= 100)
);

-- Add comments to st_settings table and columns
COMMENT ON TABLE public.st_settings IS 'Stores user preferences and settings for the StockDrop app';
COMMENT ON COLUMN public.st_settings.id IS 'Primary key, auto-incrementing identifier';
COMMENT ON COLUMN public.st_settings.user_id IS 'Foreign key referencing auth.users, identifies the user who owns these settings';
COMMENT ON COLUMN public.st_settings.notification_threshold IS 'Percentage threshold for stock price change notifications (0-100)';
COMMENT ON COLUMN public.st_settings.theme IS 'User preferred theme: light, dark, or system';
COMMENT ON COLUMN public.st_settings.created_at IS 'Timestamp when the settings record was created';
COMMENT ON COLUMN public.st_settings.updated_at IS 'Timestamp when the settings were last updated';

-- Enable Row Level Security (RLS) for st_favorites table
ALTER TABLE public.st_favorites ENABLE ROW LEVEL SECURITY;

-- Create RLS policy for st_favorites: Users can only access their own favorites
CREATE POLICY "Users can view their own favorites" ON public.st_favorites
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own favorites" ON public.st_favorites
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own favorites" ON public.st_favorites
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own favorites" ON public.st_favorites
    FOR DELETE USING (auth.uid() = user_id);

-- Enable Row Level Security (RLS) for st_settings table
ALTER TABLE public.st_settings ENABLE ROW LEVEL SECURITY;

-- Create RLS policy for st_settings: Users can only access their own settings
CREATE POLICY "Users can view their own settings" ON public.st_settings
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own settings" ON public.st_settings
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own settings" ON public.st_settings
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own settings" ON public.st_settings
    FOR DELETE USING (auth.uid() = user_id);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_st_favorites_user_id ON public.st_favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_st_favorites_symbol ON public.st_favorites(symbol);
CREATE INDEX IF NOT EXISTS idx_st_favorites_added_at ON public.st_favorites(added_at);
CREATE INDEX IF NOT EXISTS idx_st_settings_user_id ON public.st_settings(user_id);

-- Function to automatically update the updated_at timestamp in st_settings
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at when st_settings is modified
CREATE TRIGGER update_st_settings_updated_at 
    BEFORE UPDATE ON public.st_settings
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Function to create default settings when a new user signs up
CREATE OR REPLACE FUNCTION create_default_user_settings()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.st_settings (user_id, notification_threshold, theme)
    VALUES (NEW.id, 5, 'light')
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ language 'plpgsql' SECURITY DEFINER;

-- Create trigger to automatically create default settings for new users
-- Note: This trigger works on the auth.users table, so it requires appropriate permissions
-- You may need to run this separately with elevated permissions
CREATE TRIGGER create_user_settings_trigger
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION create_default_user_settings();

-- Grant necessary permissions
-- These grants ensure that authenticated users can access the tables
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON public.st_favorites TO authenticated;
GRANT ALL ON public.st_settings TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'StockDrop database schema created successfully!';
    RAISE NOTICE 'Tables created: st_favorites, st_settings';
    RAISE NOTICE 'Row Level Security enabled with user-specific policies';
    RAISE NOTICE 'Indexes and triggers configured for optimal performance';
END $$;