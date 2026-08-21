import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.8/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const NOTIFICATION_CHANNEL = "campus_notices_channel";

type ProfileRow = {
  id: string;
  role: string;
  semester: string | number | null;
  is_active?: boolean | null;
  fcm_token?: string | null;
};

// In-memory cache for Firebase OAuth2 access token across warm Edge Function invocations
let cachedOAuthToken: { token: string; expiresAt: number } | null = null;

function stringifyData(
  data: Record<string, unknown> | undefined,
  type: string,
): Record<string, string> {
  const result: Record<string, string> = { type };
  for (const [key, value] of Object.entries(data ?? {})) {
    if (value != null) result[key] = String(value);
  }
  return result;
}

// Deduplicates and cleans token arrays so no device receives duplicate pushes
function sanitizeTokens(tokens: (string | null | undefined)[]): string[] {
  return Array.from(
    new Set(
      tokens
        .filter((t): t is string => typeof t === "string" && t.trim().length > 0)
        .map((t) => t.trim())
    )
  );
}

// Returns both resolved userIds and their unique fcm_tokens
async function resolveTargets(
  body: Record<string, unknown>,
  adminClient: ReturnType<typeof createClient>,
): Promise<{ userIds: string[]; tokens: string[] }> {
  // Direct token(s) provided — no userId resolution possible
  const fcmTokens = body.fcmTokens as string[] | undefined;
  if (fcmTokens?.length) {
    return { userIds: [], tokens: sanitizeTokens(fcmTokens) };
  }
  const fcmToken = body.fcmToken as string | undefined;
  if (fcmToken) return { userIds: [], tokens: sanitizeTokens([fcmToken]) };

  // Resolve by userId(s)
  const userIds = body.userIds as string[] | undefined;
  const userId = body.userId as string | undefined;
  const directIds = userIds?.length ? userIds : userId ? [userId] : null;

  if (directIds?.length) {
    const { data } = await adminClient
      .from("profiles")
      .select("id, fcm_token")
      .in("id", directIds);
    const rows = (data ?? []) as { id: string; fcm_token?: string | null }[];
    return {
      userIds: rows.map((r) => r.id),
      tokens: sanitizeTokens(rows.map((r) => r.fcm_token)),
    };
  }

  // Resolve by role/semester
  const targetRoles = body.targetRoles as string[] | undefined;
  const targetSemesters = body.targetSemesters as number[] | undefined;
  const semesterNo = body.semesterNo as number | undefined;

  if (!targetRoles?.length && semesterNo == null) return { userIds: [], tokens: [] };

  let query = adminClient
    .from("profiles")
    .select("id, role, semester, is_active, fcm_token");
  if (targetRoles?.length) query = query.in("role", targetRoles);

  const { data: profiles, error } = await query;
  if (error) throw new Error(`Failed to resolve recipients: ${error.message}`);

  const semesters = targetSemesters?.length
    ? targetSemesters
    : semesterNo != null
    ? [semesterNo]
    : [];

  const matched = ((profiles as ProfileRow[]) ?? [])
    .filter((p) => p.is_active !== false)
    .filter((p) => {
      if (!semesters.length) return true;
      if (p.role !== "student") return true;
      // Extract numeric part from semester — handles both "9" and "Semester 9"
      const semStr = String(p.semester ?? "");
      const semNum = parseInt(semStr.replace(/[^0-9]/g, ""), 10);
      return !isNaN(semNum) && semesters.includes(semNum);
    });

  return {
    userIds: matched.map((p) => p.id),
    tokens: sanitizeTokens(matched.map((p) => p.fcm_token)),
  };
}

function notificationTypeFromEventType(type: string, data?: Record<string, unknown>): string {
  const status = data?.status as string | undefined;
  if (type === "project_request") {
    return status === "approved" ? "success" : status === "rejected" ? "warning" : "info";
  }
  if (type === "resource_update") {
    return status === "approved" ? "success" : status === "rejected" ? "warning" : "info";
  }
  if (type === "event") return "info";
  if (type === "resource_pending") return "info";
  return "info";
}

async function insertInAppNotifications(
  adminClient: ReturnType<typeof createClient>,
  userIds: string[],
  title: string,
  body: string,
  type: string,
  data?: Record<string, unknown>,
) {
  if (!userIds.length) return;
  const rows = userIds.map((uid) => ({
    user_id: uid,
    title,
    body,
    notification_type: notificationTypeFromEventType(type, data),
  }));
  const { error } = await adminClient.from("notifications").insert(rows);
  if (error) {
    console.error("Failed to insert in-app notifications:", error.message);
  }
}

function buildTokenMessage(
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
) {
  return {
    token,
    notification: { title, body },
    data,
    android: {
      priority: "HIGH",
      notification: {
        sound: "default",
        channel_id: NOTIFICATION_CHANNEL,
        notification_priority: "PRIORITY_HIGH",
        visibility: "PUBLIC",
        default_vibrate_timings: true,
      },
    },
    webpush: {
      headers: {
        Urgency: "high",
        TTL: "86400",
      },
      notification: {
        title,
        body,
        icon: "/icons/Icon-192.png",
        tag: data.type ? `${data.type}_${data.id ?? Date.now()}` : undefined,
      },
      fcm_options: {
        link: "/",
      },
    },
    apns: {
      headers: { "apns-priority": "10" },
      payload: { aps: { sound: "default", alert: { title, body } } },
    },
  };
}

async function sendFcmMessage(
  accessToken: string,
  projectId: string,
  message: Record<string, unknown>,
): Promise<unknown> {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify({ message }),
  });
  const result = await res.json();
  if (!res.ok) throw new Error(`FCM error: ${JSON.stringify(result)}`);
  return result;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = (await req.json()) as Record<string, unknown>;
    const { type, title, body: msgBody, data } = body as {
      type?: string;
      title: string;
      body: string;
      data?: Record<string, unknown>;
    };

    if (!title || !msgBody) throw new Error("title and body are required");

    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountJson) throw new Error("FIREBASE_SERVICE_ACCOUNT secret is not set");

    const sa = JSON.parse(serviceAccountJson);
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { userIds, tokens } = await resolveTargets(body, adminClient);
    const eventType = type ?? "notice";

    // Insert in-app notifications unless the caller signals the DB already did it
    // (e.g. SECURITY DEFINER triggers on project_join_requests / resources).
    // Notices appear in the dedicated Notices tab — no insert needed there either.
    const skipInApp = (body.skipInApp as boolean | undefined) === true;
    if (!skipInApp && eventType !== "notice") {
      await insertInAppNotifications(
        adminClient,
        userIds,
        title,
        msgBody,
        eventType,
        data as Record<string, unknown> | undefined,
      );
    }

    if (!tokens.length) {
      return new Response(
        JSON.stringify({ success: true, sent: 0, failed: 0, total: 0, info: "No FCM tokens found" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const accessToken = await getCachedAccessToken(sa.client_email, sa.private_key);
    const projectId = sa.project_id;
    const stringData = stringifyData(data as Record<string, unknown> | undefined, eventType);

    const results = await Promise.allSettled(
      tokens.map((token) =>
        sendFcmMessage(accessToken, projectId, buildTokenMessage(token, title, msgBody, stringData))
      ),
    );

    const failed = results.filter((r) => r.status === "rejected");
    const succeeded = results.length - failed.length;

    if (failed.length > 0) {
      console.error(
        "Some FCM sends failed:",
        failed.map((r) => (r.status === "rejected" ? r.reason : null)),
      );
    }

    return new Response(
      JSON.stringify({
        success: failed.length === 0,
        sent: succeeded,
        failed: failed.length,
        total: results.length,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: failed.length === results.length ? 400 : 200,
      },
    );
  } catch (error) {
    console.error("send-push-notification error:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : String(error) }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 },
    );
  }
});

async function getCachedAccessToken(clientEmail: string, privateKey: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedOAuthToken && cachedOAuthToken.expiresAt > now + 60) {
    return cachedOAuthToken.token;
  }
  const token = await getAccessToken(clientEmail, privateKey);
  // Cache token for 50 minutes (valid for 60 min)
  cachedOAuthToken = { token, expiresAt: now + 3000 };
  return token;
}

async function getAccessToken(clientEmail: string, privateKey: string): Promise<string> {
  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";

  let pem = privateKey.replace(/\\n/g, "\n");
  if (pem.includes(pemHeader)) {
    pem = pem.substring(pem.indexOf(pemHeader) + pemHeader.length, pem.indexOf(pemFooter));
  }
  pem = pem.replace(/\s/g, "");

  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    true,
    ["sign"],
  );

  const jwt = await create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: clientEmail,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      exp: getNumericDate(3600),
      iat: getNumericDate(0),
    },
    key,
  );

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }).toString(),
  });

  const tokenData = await res.json();
  if (!res.ok) throw new Error(`OAuth failed: ${JSON.stringify(tokenData)}`);
  return tokenData.access_token;
}

