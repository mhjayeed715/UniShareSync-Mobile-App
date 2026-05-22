// supabase/functions/send-notice-push/index.ts
// Deploy with: supabase functions deploy send-notice-push
// Set secret:  supabase secrets set FCM_SERVER_KEY=<your_fcm_server_key>

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const FCM_URL = "https://fcm.googleapis.com/fcm/send";

serve(async (req) => {
  const { title, body, priority, topic } = await req.json();

  const fcmKey = Deno.env.get("FCM_SERVER_KEY");
  if (!fcmKey) {
    return new Response(JSON.stringify({ error: "FCM_SERVER_KEY not set" }), {
      status: 500,
    });
  }

  const priorityLabel =
    priority === "urgent"
      ? "🚨 URGENT"
      : priority === "important"
      ? "⚠️ Important"
      : "📢 Notice";

  const payload = {
    to: `/topics/${topic ?? "campus_notices"}`,
    notification: {
      title: `${priorityLabel}: ${title}`,
      body,
      sound: "default",
    },
    data: {
      type: "notice",
      priority,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: { priority: priority === "urgent" ? "high" : "normal" },
    apns: {
      payload: { aps: { sound: "default" } },
    },
  };

  const res = await fetch(FCM_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `key=${fcmKey}`,
    },
    body: JSON.stringify(payload),
  });

  const result = await res.json();
  return new Response(JSON.stringify(result), { status: 200 });
});
