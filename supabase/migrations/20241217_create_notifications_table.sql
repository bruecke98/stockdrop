-- Create st_notifications table for tracking sent notifications and rate limiting
CREATE TABLE IF NOT EXISTS public.st_notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    symbol VARCHAR(10) NOT NULL,
    message TEXT NOT NULL,
    price DECIMAL(12,4) NOT NULL,
    change_percent DECIMAL(8,4) NOT NULL,
    threshold DECIMAL(8,4) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS st_notifications_user_id_idx ON public.st_notifications(user_id);
CREATE INDEX IF NOT EXISTS st_notifications_created_at_idx ON public.st_notifications(created_at);
CREATE INDEX IF NOT EXISTS st_notifications_symbol_idx ON public.st_notifications(symbol);
CREATE INDEX IF NOT EXISTS st_notifications_user_date_idx ON public.st_notifications(user_id, created_at);

-- Enable Row Level Security (RLS)
ALTER TABLE public.st_notifications ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Users can only view their own notifications
CREATE POLICY "Users can view own notifications" ON public.st_notifications
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own notifications (for app logging)
CREATE POLICY "Users can insert own notifications" ON public.st_notifications
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Service role can manage all notifications (for Edge Function)
CREATE POLICY "Service role can manage all notifications" ON public.st_notifications
    FOR ALL USING (auth.role() = 'service_role');

-- Grant necessary permissions
GRANT ALL ON public.st_notifications TO authenticated;
GRANT ALL ON public.st_notifications TO service_role;

-- Add helpful comments
COMMENT ON TABLE public.st_notifications IS 'Stores notifications sent to users for stock price alerts and rate limiting';
COMMENT ON COLUMN public.st_notifications.symbol IS 'Stock symbol that triggered the notification';
COMMENT ON COLUMN public.st_notifications.message IS 'Human-readable notification message';
COMMENT ON COLUMN public.st_notifications.price IS 'Stock price when notification was sent';
COMMENT ON COLUMN public.st_notifications.change_percent IS 'Percentage change that triggered the alert';
COMMENT ON COLUMN public.st_notifications.threshold IS 'User threshold that was exceeded';