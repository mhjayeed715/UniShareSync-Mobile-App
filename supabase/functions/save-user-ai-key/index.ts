// supabase/functions/save-user-ai-key/index.ts

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ENCRYPTION_KEY   = Deno.env.get("USER_KEY_ENCRYPTION_SECRET")!;
const SUPABASE_URL     = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

async function encryptKey(plaintext: string): Promise<{ iv: string; encrypted: string }> {
  const keyMaterial = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(ENCRYPTION_KEY.substring(0, 32)),
    { name: "AES-GCM" },
    false,
    ["encrypt"]
  );

  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    keyMaterial,
    new TextEncoder().encode(plaintext)
  );

  return {
    iv:        btoa(String.fromCharCode(...iv)),
    encrypted: btoa(String.fromCharCode(...new Uint8Array(encrypted)))
  };
}

Deno.serve(async (req: Request) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin":  "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Content-Type": "application/json"
  };

  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const { groq_key, action } = await req.json() as {
      groq_key?: string;
      action?: "save" | "delete" | "verify";
    };

    const authHeader = req.headers.get("Authorization") || "";
    const supabaseUser = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error } = await supabaseUser.auth.getUser();
    if (error || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: corsHeaders });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE);

    if (action === "delete") {
      await supabase.from("user_ai_keys").delete().eq("user_id", user.id);
      return new Response(JSON.stringify({ success: true, message: "API key removed" }), { headers: corsHeaders });
    }

    if (action === "verify" || action === "save") {
      if (!groq_key || !groq_key.startsWith("gsk_")) {
        return new Response(
          JSON.stringify({ error: "Invalid Groq API key format. Must start with 'gsk_'" }),
          { status: 400, headers: corsHeaders }
        );
      }

      // Verify the key works by making a test call to Groq
      const testRes = await fetch("https://api.groq.com/openai/v1/models", {
        headers: { "Authorization": `Bearer ${groq_key}` }
      });

      if (!testRes.ok) {
        return new Response(
          JSON.stringify({ error: "API key verification failed. Key may be invalid or expired." }),
          { status: 400, headers: corsHeaders }
        );
      }

      if (action === "verify") {
        return new Response(JSON.stringify({ success: true, message: "Key is valid" }), { headers: corsHeaders });
      }

      // Encrypt and save
      const { iv, encrypted } = await encryptKey(groq_key);

      await supabase.from("user_ai_keys").upsert({
        user_id:           user.id,
        groq_key_iv:       iv,
        groq_key_encrypted: encrypted,
        is_active:         true,
        updated_at:        new Date().toISOString()
      }, { onConflict: "user_id" });

      return new Response(
        JSON.stringify({ success: true, message: "API key saved. You now have unlimited questions." }),
        { headers: corsHeaders }
      );
    }

    return new Response(JSON.stringify({ error: "Unknown action" }), { status: 400, headers: corsHeaders });

  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), { status: 500, headers: corsHeaders });
  }
});