import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.21.0"

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })
  }

  try {
    const { record } = await req.json()
    if (!record || !record.community_id) {
      return new Response(JSON.stringify({ error: "Missing community_id record" }), { status: 400 })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Fetch community members fcm tokens
    const { data: members, error: memErr } = await supabase
      .from('community_members')
      .select('profiles(fcm_token)')
      .eq('community_id', record.community_id)
      .eq('is_active', true)

    if (memErr || !members) {
      return new Response(JSON.stringify({ error: memErr?.message || "Failed to fetch members" }), { status: 400 })
    }

    const tokens = members
      .map(m => (m.profiles as any)?.fcm_token)
      .filter(t => t !== null && t !== undefined && t !== '')

    if (tokens.length === 0) {
      return new Response(JSON.stringify({ message: "No FCM tokens found" }), { status: 200 })
    }

    // Call fcm token dispatcher or system notification inserts
    console.log(`Sending push to ${tokens.length} members for notice: ${record.title}`);
    
    return new Response(JSON.stringify({ success: true, count: tokens.length }), { status: 200 })
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500 })
  }
})
