import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.21.0"

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const now = new Date()
    
    // Check 1: Paid registrations older than 24 hours with payment_status = 'pending'
    const twentyFourHoursAgo = new Date(now.getTime() - (24 * 60 * 60 * 1000))
    const { data: pendingPayments } = await supabase
      .from('event_registrations')
      .select('*, profiles(fcm_token)')
      .eq('payment_status', 'pending')
      .lt('registered_at', twentyFourHoursAgo.toISOString())

    if (pendingPayments) {
      for (const reg of pendingPayments) {
        const token = (reg.profiles as any)?.fcm_token
        if (token) {
          console.log(`Payment reminder sent to token: ${token} for event ${reg.event_id}`)
        }
      }
    }

    // Check 2: Events starting in 2 hours
    const twoHoursFromNow = new Date(now.getTime() + (2 * 60 * 60 * 1000))
    const { data: startingEvents } = await supabase
      .from('events')
      .select('id, title')
      .gte('event_date', now.toISOString())
      .lte('event_date', twoHoursFromNow.toISOString())

    if (startingEvents) {
      for (const e of startingEvents) {
        const { data: attendees } = await supabase
          .from('event_registrations')
          .select('profiles(fcm_token)')
          .eq('event_id', e.id)
          .eq('registration_status', 'confirmed')

        if (attendees) {
          for (const att of attendees) {
            const token = (att.profiles as any)?.fcm_token
            if (token) {
              console.log(`Event starting soon alert sent to token: ${token}`)
            }
          }
        }
      }
    }

    return new Response(JSON.stringify({ success: true }), { status: 200 })
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500 })
  }
})
