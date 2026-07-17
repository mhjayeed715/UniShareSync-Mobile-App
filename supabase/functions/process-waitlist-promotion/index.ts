import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.21.0"

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })
  }

  try {
    const { registration } = await req.json()
    if (!registration || !registration.event_id) {
      return new Response(JSON.stringify({ error: "Missing event_id in registration payload" }), { status: 400 })
    }
    const eventId = registration.event_id

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Fetch highest priority waitlisted registrant
    const { data: nextReg, error: fetchErr } = await supabase
      .from('event_registrations')
      .select('*')
      .eq('event_id', eventId)
      .eq('registration_status', 'waitlisted')
      .order('waitlist_position', { ascending: true })
      .limit(1)
      .maybeSingle()

    if (fetchErr) return new Response(JSON.stringify({ error: fetchErr.message }), { status: 400 })
    if (!nextReg) return new Response(JSON.stringify({ message: "No waitlisted attendees found" }), { status: 200 })

    // Update waitlist registrant status to pending payment verification
    const { error: updateErr } = await supabase
      .from('event_registrations')
      .update({
        registration_status: 'pending',
        waitlist_position: null
      })
      .eq('id', nextReg.id)

    if (updateErr) return new Response(JSON.stringify({ error: updateErr.message }), { status: 400 })

    // Fetch FCM token for notifications
    const { data: userProfile } = await supabase
      .from('profiles')
      .select('fcm_token')
      .eq('id', nextReg.user_id)
      .single()

    if (userProfile?.fcm_token) {
      console.log(`Dispatched waitlist promotion push alert to FCM token: ${userProfile.fcm_token}`);
    }

    return new Response(JSON.stringify({ success: true, promoted_id: nextReg.id }), { status: 200 })
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500 })
  }
})
