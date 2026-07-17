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
    const { record, action, rejection_note } = await req.json()

    if (!record || !action) {
      return new Response(JSON.stringify({ error: "Missing required parameters" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    }

    const { id: alumniId, full_name: alumniName, email: alumniEmail, entry_source, added_by: addedBy } = record

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const resendApiKey = Deno.env.get('RESEND_API_KEY');
    let emailSubject = "";
    let emailBody = "";

    if (action === 'approve') {
      emailSubject = "Your AlumniConnect Profile is Approved!";
      emailBody = `Hi ${alumniName},

Congratulations! Your alumni profile has been reviewed and approved by the SMUCT administration.

It is now live in the UniShareSync mobile app's AlumniConnect directory, where students can discover you for mentorship and professional networking.

You can view the directory inside the app.

Best regards,
SMUCT Administration`;
    } else {
      emailSubject = "Update on your AlumniConnect Profile Submission";
      emailBody = `Hi ${alumniName},

Thank you for submitting your profile to the SMUCT AlumniConnect directory.

Unfortunately, your profile could not be approved at this time.
Reason/Note: ${rejection_note || "Profile details did not meet directory verification standards. Please verify your student ID and details."}

If you have any questions, please contact the SMUCT CSE department.

Best regards,
SMUCT Administration`;
    }

    // Send email to alumni
    if (alumniEmail) {
      if (resendApiKey) {
        try {
          await fetch('https://api.resend.com/emails', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${resendApiKey}`,
            },
            body: JSON.stringify({
              from: 'UniShareSync <onboarding@resend.dev>',
              to: alumniEmail,
              subject: emailSubject,
              text: emailBody,
            }),
          });
        } catch (e: any) {
          console.error(`Error sending email to alumni: ${e.message}`);
        }
      } else {
        console.log(`[Email Mock] Sending approval/rejection email to: ${alumniEmail}\nSubject: ${emailSubject}`);
      }
    }

    // Send FCM and insert in-app notification to Faculty if they added it
    if (entry_source === 'faculty_added' && addedBy && action === 'approve') {
      const title = "Alumni Profile Approved";
      const body = `${alumniName}'s alumni profile is now live on AlumniConnect`;

      // 1. Insert in-app notification
      try {
        await supabase
          .from('notifications')
          .insert({
            user_id: addedBy,
            title: title,
            body: body,
            notification_type: 'success',
            data: {
              type: 'alumni_approved',
              deep_link: `unisharesync://alumni/${alumniId}`,
              alumni_id: alumniId
            }
          })
      } catch (e: any) {
        console.error(`Error inserting notification for faculty: ${e.message}`);
      }

      // 2. Delegate to push notification function
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
            userId: addedBy,
            title: title,
            body: body,
            type: "alumni_approved",
            data: {
              deep_link: `unisharesync://alumni/${alumniId}`
            }
          })
        });
      } catch (e: any) {
        console.error(`Error calling push notification Edge Function: ${e.message}`);
      }
    }

    return new Response(JSON.stringify({ success: true }), {
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
