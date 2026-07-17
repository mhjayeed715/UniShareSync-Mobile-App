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

    const thirtyDaysAgo = new Date()
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)
    const dateStr = thirtyDaysAgo.toISOString()

    const { data: communities, error: commErr } = await supabase
      .from('communities')
      .select('id, member_count')
      .eq('is_active', true)

    if (commErr || !communities) {
      return new Response(JSON.stringify({ error: commErr?.message || "Failed to fetch communities" }), { status: 400 })
    }

    for (const c of communities) {
      const { count: notices } = await supabase.from('community_notices')
        .select('*', { count: 'exact', head: true }).eq('community_id', c.id).gte('created_at', dateStr)

      const { count: posts } = await supabase.from('community_activity_posts')
        .select('*', { count: 'exact', head: true }).eq('community_id', c.id).gte('created_at', dateStr)

      const { count: events } = await supabase.from('events')
        .select('*', { count: 'exact', head: true }).eq('organizing_community_id', c.id).gte('created_at', dateStr)

      const { count: newMembers } = await supabase.from('community_members')
        .select('*', { count: 'exact', head: true }).eq('community_id', c.id).gte('joined_at', dateStr)

      const score = Math.min(100, ((notices || 0) * 3) + ((posts || 0) * 5) + ((events || 0) * 10) + ((newMembers || 0) * 2))

      await supabase.from('communities').update({ activity_score: score }).eq('id', c.id)

      await supabase.from('community_analytics_snapshots').insert({
        community_id: c.id,
        member_count: c.member_count,
        new_members_this_month: newMembers || 0,
        notices_posted: notices || 0,
        events_organized: events || 0,
        activity_posts_count: posts || 0,
        activity_score: score
      })
    }

    return new Response(JSON.stringify({ success: true, count: communities.length }), { status: 200 })
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500 })
  }
})
