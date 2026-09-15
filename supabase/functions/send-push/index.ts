// ============================================================================
// FAIRSHARE SUPABASE EDGE FUNCTION: SEND PUSH NOTIFICATION (FCM v1)
// ============================================================================
// Triggered via Supabase Database Webhooks on:
//   - expenses (INSERT)
//   - comments (INSERT)
//   - shared_list_items (INSERT)
// Sends free real-time push notifications to all other group members.
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

/**
 * Generates an OAuth2 access token for Google FCM v1 API using Web Crypto & Service Account
 */
async function getGoogleAccessToken(
  clientEmail: string,
  privateKeyPem: string
): Promise<string> {
  const cleanKey = privateKeyPem
    .replace(/\\n/g, '\n')
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '');

  const binaryDer = Uint8Array.from(atob(cleanKey), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryDer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const header = { alg: 'RS256', typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: clientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  };

  const encodeBase64Url = (obj: any) =>
    btoa(JSON.stringify(obj))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');

  const unsignedJwt = `${encodeBase64Url(header)}.${encodeBase64Url(claim)}`;
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(unsignedJwt)
  );

  const base64UrlSignature = btoa(
    String.fromCharCode(...new Uint8Array(signature))
  )
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');

  const jwt = `${unsignedJwt}.${base64UrlSignature}`;

  // Exchange JWT for Google OAuth2 Bearer token
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Google token exchange failed: ${text}`);
  }

  const json = await res.json();
  return json.access_token;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');

    if (!supabaseUrl || !supabaseServiceKey) {
      return new Response(
        JSON.stringify({ error: 'Supabase environment variables missing.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const payload = await req.json().catch(() => ({}));
    const { table, record, type } = payload;

    if (!record) {
      return new Response(
        JSON.stringify({ message: 'No record in payload.' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    let title = 'FairShare Alert';
    let body = 'You have a new update in your group.';
    let cohortId: string | null = null;
    let senderUserId: string | null = null;
    let clickRoute = '/activity';

    // 1. Determine notification details based on webhook table
    if (table === 'expenses') {
      cohortId = record.cohort_id;
      senderUserId = record.paid_by_user_id;
      const expenseTitle = record.title || 'Expense';
      const amount = record.total_amount != null ? `₹${record.total_amount}` : '';
      const payerName = record.paid_by_name || 'A member';
      title = `${expenseTitle} ${amount}`.trim();
      body = `${payerName} added a new expense.`;
      clickRoute = cohortId ? `/groups/${cohortId}` : '/activity';
    } else if (table === 'comments') {
      senderUserId = record.user_id;
      const expenseId = record.expense_id;
      const commentContent = record.content || '';

      // Get expense details to know cohort & title
      if (expenseId) {
        const { data: exp } = await supabase
          .from('expenses')
          .select('title, cohort_id')
          .eq('id', expenseId)
          .maybeSingle();

        if (exp) {
          cohortId = exp.cohort_id;
          title = `Comment on "${exp.title}"`;
        }
      }

      // Get commenter name
      const { data: commenter } = await supabase
        .from('profiles')
        .select('full_name, nickname')
        .eq('id', senderUserId)
        .maybeSingle();

      const name = commenter?.nickname || commenter?.full_name || 'Someone';
      body = `${name}: "${commentContent}"`;
      clickRoute = cohortId ? `/groups/${cohortId}` : '/activity';
    } else if (table === 'shared_list_items') {
      cohortId = record.cohort_id;
      senderUserId = record.user_id;
      const itemName = record.title || 'Item';
      title = 'House Cart Update';

      const { data: author } = await supabase
        .from('profiles')
        .select('full_name, nickname')
        .eq('id', senderUserId)
        .maybeSingle();

      const name = author?.nickname || author?.full_name || 'Someone';
      body = `${name} added "${itemName}" to the house cart.`;
      clickRoute = cohortId ? `/groups/${cohortId}` : '/activity';
    }

    if (!cohortId) {
      return new Response(
        JSON.stringify({ message: 'No cohort_id found for event, skipping push.' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 2. Fetch all group member user IDs (excluding sender)
    const { data: members, error: membersError } = await supabase
      .from('group_members')
      .select('user_id')
      .eq('cohort_id', cohortId);

    if (membersError || !members) {
      throw membersError || new Error('Could not fetch members.');
    }

    const recipientUserIds = members
      .map((m) => m.user_id)
      .filter((uid) => uid && uid !== senderUserId);

    if (recipientUserIds.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No other members to notify.' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 3. Fetch device tokens for recipients
    const { data: profiles, error: profilesError } = await supabase
      .from('profiles')
      .select('id, fcm_token')
      .in('id', recipientUserIds)
      .not('fcm_token', 'is', null);

    if (profilesError || !profiles || profiles.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No active device tokens found for recipients.' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const tokens = profiles
      .map((p) => p.fcm_token as string)
      .filter((t) => t && t.length > 10);

    // 4. Dispatch FCM v1 push if service account is configured
    let pushesSent = 0;
    if (serviceAccountJson && tokens.length > 0) {
      const sa = typeof serviceAccountJson === 'string'
        ? JSON.parse(serviceAccountJson)
        : serviceAccountJson;

      const accessToken = await getGoogleAccessToken(
        sa.client_email,
        sa.private_key
      );

      const fcmUrl = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

      for (const token of tokens) {
        try {
          const fcmRes = await fetch(fcmUrl, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify({
              message: {
                token: token,
                notification: {
                  title,
                  body,
                },
                data: {
                  cohort_id: cohortId,
                  route: clickRoute,
                },
                android: {
                  priority: 'high',
                  notification: {
                    channel_id: 'fairshare_high_importance',
                    sound: 'default',
                    default_vibrate_timings: true,
                  },
                },
              },
            }),
          });

          if (fcmRes.ok) {
            pushesSent++;
          } else {
            const errText = await fcmRes.text();
            console.warn(`[send-push] FCM push failed for token: ${errText}`);
          }
        } catch (pushErr) {
          console.error('[send-push] FCM network error:', pushErr);
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        event: table,
        title,
        body,
        recipientsCount: tokens.length,
        pushesSent,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error('[send-push] Error:', message);
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
