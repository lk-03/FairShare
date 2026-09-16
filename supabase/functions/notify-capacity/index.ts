// ============================================================================
// FAIRSHARE SUPABASE EDGE FUNCTION: NOTIFY CAPACITY
// ============================================================================
// Triggered on user registration. When non-guest user count reaches 150,
// sends an automated milestone notification to the admin via Resend,
// Discord webhook, or Telegram bot.
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

    if (!supabaseUrl || !supabaseServiceKey) {
      return new Response(
        JSON.stringify({ error: 'Supabase environment variables missing.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Fetch current non-guest user count
    const { count, error: countError } = await supabase
      .from('profiles')
      .select('*', { count: 'exact', head: true })
      .eq('is_guest', false);

    if (countError) {
      throw countError;
    }

    const userCount = count ?? 0;

    // 2. Fetch milestone settings
    const { data: settingsRow, error: settingsError } = await supabase
      .from('system_settings')
      .select('value')
      .eq('key', 'user_capacity')
      .maybeSingle();

    if (settingsError) {
      console.warn('Could not read system_settings:', settingsError);
    }

    const settings = settingsRow?.value ?? { max_users: 150, milestone_notified: false };
    const maxUsers = settings.max_users ?? 150;
    const alreadyNotified = settings.milestone_notified ?? false;

    let notificationSent = false;
    const notificationsAttempted: string[] = [];

    // 3. If count reached capacity and milestone hasn't been notified yet
    if (userCount >= maxUsers && !alreadyNotified) {
      const adminEmail = Deno.env.get('ADMIN_NOTIFICATION_EMAIL');
      const resendApiKey = Deno.env.get('RESEND_API_KEY');
      const discordWebhook = Deno.env.get('DISCORD_WEBHOOK_URL');
      const telegramToken = Deno.env.get('TELEGRAM_BOT_TOKEN');
      const telegramChatId = Deno.env.get('TELEGRAM_CHAT_ID');

      // (a) Resend Email Dispatch
      if (resendApiKey && adminEmail) {
        try {
          const res = await fetch('https://api.resend.com/emails', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${resendApiKey}`,
            },
            body: JSON.stringify({
              from: 'FairShare Alerts <onboarding@resend.dev>',
              to: [adminEmail],
              subject: `🚀 FairShare reached ${userCount} users! Time to scale.`,
              html: `
                <div style="font-family: sans-serif; max-width: 600px; margin: auto; padding: 24px; background: #0D131A; color: #E2E8F0; border-radius: 12px; border: 1px solid #243447;">
                  <h1 style="color: #38BDF8; margin-top: 0;">🚀 Milestone Achieved!</h1>
                  <p style="font-size: 16px; line-height: 1.5;">
                    <b>FairShare</b> has reached <b>${userCount} registered users</b>!
                  </p>
                  <p style="font-size: 14px; color: #94A3B8;">
                    The early-access hard cap of <b>${maxUsers} users</b> is now active. Any further registrations will be gracefully paused with the waitlist capacity modal.
                  </p>
                  <div style="margin: 24px 0; padding: 16px; background: #121A23; border-radius: 8px; border: 1px solid #1E293B;">
                    <p style="margin: 0; font-size: 14px; color: #10B981; font-weight: bold;">
                      ✓ Ready for public scaling & marketing
                    </p>
                  </div>
                  <p style="font-size: 12px; color: #64748B;">
                    Automated system notification dispatched by FairShare Supabase Edge Functions.
                  </p>
                </div>
              `,
            }),
          });
          if (res.ok) {
            notificationSent = true;
            notificationsAttempted.push('resend_email');
          }
        } catch (emailErr) {
          console.error('Error sending Resend email:', emailErr);
        }
      }

      // (b) Discord Webhook Dispatch
      if (discordWebhook) {
        try {
          const discordRes = await fetch(discordWebhook, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              content: `🚀 **FairShare Milestone:** The app has reached **${userCount}/${maxUsers} users**! Early-access cap is now active. Time to consider scaling!`,
            }),
          });
          if (discordRes.ok) {
            notificationSent = true;
            notificationsAttempted.push('discord');
          }
        } catch (discordErr) {
          console.error('Error sending Discord alert:', discordErr);
        }
      }

      // (c) Telegram Bot Dispatch
      if (telegramToken && telegramChatId) {
        try {
          const tgRes = await fetch(
            `https://api.telegram.org/bot${telegramToken}/sendMessage`,
            {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                chat_id: telegramChatId,
                text: `🚀 FairShare Milestone: The app has reached ${userCount}/${maxUsers} users! Early-access cap is now active. Time to consider scaling!`,
              }),
            }
          );
          if (tgRes.ok) {
            notificationSent = true;
            notificationsAttempted.push('telegram');
          }
        } catch (tgErr) {
          console.error('Error sending Telegram alert:', tgErr);
        }
      }

      // Mark as notified in system_settings so we don't spam
      await supabase
        .from('system_settings')
        .upsert({
          key: 'user_capacity',
          value: {
            ...settings,
            milestone_notified: true,
            notified_at: new Date().toISOString(),
            last_recorded_count: userCount,
          },
          updated_at: new Date().toISOString(),
        });
    }

    return new Response(
      JSON.stringify({
        success: true,
        userCount,
        maxUsers,
        alreadyNotified,
        notificationSent,
        channels: notificationsAttempted,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
