import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.21.0"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { record } = await req.json()

    if (!record) {
      return new Response(JSON.stringify({ error: "Missing record" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    }

    const { full_name: alumniName, batch_year: batchYear, id: alumniId } = record

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Fetch all admin profiles
    const { data: admins, error: adminErr } = await supabase
      .from('profiles')
      .select('id')
      .eq('role', 'admin')

    if (adminErr) {
      return new Response(JSON.stringify({ error: adminErr.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    }

    const adminIds = (admins ?? []).map(admin => admin.id)

    if (adminIds.length > 0) {
      const title = "New Alumni Pending Approval";
      const body = `${alumniName} (Batch ${batchYear}) submitted their profile for review`;

      // 1. Create in-app notifications for all admins
      const notifications = adminIds.map(adminId => ({
        user_id: adminId,
        title: title,
        body: body,
        notification_type: 'info',
        data: {
          type: 'alumni_pending_approval',
          deep_link: 'unisharesync://alumni/admin',
          alumni_id: alumniId
        }
      }))

      try {
        await supabase
          .from('notifications')
          .insert(notifications)
      } catch (e: any) {
        console.error(`Error inserting admin notifications: ${e.message}`);
      }

      // 2. Trigger push notification for admin roles
      try {
        const pushUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/send-push-notification`;
        await fetch(pushUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
            'apikey': Deno.env.get('SUPABASE_ANON_KEY') ?? ''
          },
          body: JSON.stringify({
            targetRoles: ['admin'],
            title: title,
            body: body,
            type: "alumni_pending_approval",
            data: {
              deep_link: "unisharesync://alumni/admin"
            }
          })
        });
      } catch (e: any) {
        console.error(`Error triggering admin push notification: ${e.message}`);
      }
    }

    return new Response(JSON.stringify({ success: true, notified: adminIds.length }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    })

  } catch (e: any) {
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    })
  }
})
