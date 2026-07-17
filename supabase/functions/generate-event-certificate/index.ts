import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.21.0"

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })
  }

  try {
    const { registration_id } = await req.json()
    if (!registration_id) {
      return new Response(JSON.stringify({ error: "Missing registration_id" }), { status: 400 })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { data: reg, error: regErr } = await supabase
      .from('event_registrations')
      .select('*, event:event_id(title, event_date)')
      .eq('id', registration_id)
      .single()

    if (regErr || !reg) {
      return new Response(JSON.stringify({ error: "Registration not found" }), { status: 400 })
    }

    // PDF compilation schema mock
    const htmlContent = `
      <html>
        <body style="font-family: Arial; padding: 50px; text-align: center; border: 10px solid #4F9EFF;">
          <h1>SHANTO-MARIAM UNIVERSITY OF CREATIVE TECHNOLOGY</h1>
          <h3>Certificate of Attendance</h3>
          <p>Presented to ${reg.full_name} for participating in the workshop:</p>
          <h2>${(reg.event as any).title}</h2>
          <p>on ${new Date((reg.event as any).event_date).toLocaleDateString()}</p>
        </body>
      </html>
    `

    const pdfBuffer = new TextEncoder().encode(htmlContent)
    const path = `certificates/${reg.event_id}/${registration_id}/certificate.pdf`
    
    const { error: uploadErr } = await supabase.storage.from('certificates').upload(path, pdfBuffer, {
      contentType: 'application/pdf',
      upsert: true
    })

    if (uploadErr) return new Response(JSON.stringify({ error: uploadErr.message }), { status: 400 })

    const certificateUrl = supabase.storage.from('certificates').getPublicUrl(path).data.publicUrl

    await supabase.from('event_registrations').update({
      certificate_issued: true,
      certificate_url: certificateUrl
    }).eq('id', registration_id)

    return new Response(JSON.stringify({ success: true, url: certificateUrl }), { status: 200 })
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500 })
  }
})
