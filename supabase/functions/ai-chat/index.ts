// supabase/functions/ai-chat/index.ts
// Upgraded: quota enforcement, FTS RAG, cache, user key support

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GROQ_KEY     = Deno.env.get("GROQ_API_KEY") || "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ENCRYPTION_KEY = Deno.env.get("USER_KEY_ENCRYPTION_SECRET") || "";

const DAILY_FREE_LIMIT = 5;
const MAX_OUTPUT_TOKENS = 450;
const GROQ_MODEL   = "llama-3.1-8b-instant";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-user-groq-key",
  "Content-Type": "text/event-stream",
  "Cache-Control": "no-cache",
  "Connection": "keep-alive",
};

const JSON_HEADERS = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-user-groq-key",
  "Content-Type": "application/json",
};

// ── Helpers ───────────────────────────────────────────────────────────────────

async function md5(text: string): Promise<string> {
  const buf = new TextEncoder().encode(text.toLowerCase().trim());
  const hash = await crypto.subtle.digest("SHA-256", buf);
  return Array.from(new Uint8Array(hash))
    .map(b => b.toString(16).padStart(2, "0"))
    .join("").substring(0, 32);
}

async function decryptUserKey(iv: string, encrypted: string): Promise<string> {
  const keyMaterial = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(ENCRYPTION_KEY.substring(0, 32)),
    { name: "AES-GCM" },
    false,
    ["decrypt"]
  );

  const ivBuffer  = Uint8Array.from(atob(iv), c => c.charCodeAt(0));
  const dataBuffer = Uint8Array.from(atob(encrypted), c => c.charCodeAt(0));

  const decrypted = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: ivBuffer },
    keyMaterial,
    dataBuffer
  );

  return new TextDecoder().decode(decrypted);
}

function generateSuggestions(
  userPrompt: string,
  aiResponse: string
): Array<{ label: string; prompt: string }> {
  const lower = (userPrompt + " " + aiResponse).toLowerCase();

  const pool: Array<{ label: string; prompt: string }> = [
    { label: "📅 Today's schedule", prompt: "What classes do I have today?" },
    { label: "🎉 Upcoming events", prompt: "Are there any upcoming events?" },
    { label: "📢 Recent notices", prompt: "Show me the latest notices" },
    { label: "📦 Lost & Found", prompt: "Any open lost and found items?" },
    { label: "🔬 Active projects", prompt: "What projects are currently active?" },
    { label: "📚 Study resources", prompt: "What study resources are available?" },
    { label: "🏘️ My communities", prompt: "What communities am I part of?" },
    { label: "📦 Borrow items", prompt: "What items are available to borrow on Campus Share?" },
    { label: "🎓 Find a mentor", prompt: "Show me alumni available for mentorship" },
    { label: "💡 App help", prompt: "How do I use UniShareSync?" },
  ];

  const filtered = pool.filter(
    (s) => !lower.includes(s.prompt.toLowerCase().slice(0, 20))
  );

  const shuffled = filtered.sort(() => Math.random() - 0.5);
  return shuffled.slice(0, 4);
}

// ── Strip conversational filler to get FTS-friendly keywords ─────────────────
// e.g. "Tell me about the resource Paint Sheet for CHM 2101. What topics does it cover?"
//   →  "Paint Sheet CHM 2101"
function extractFtsKeywords(prompt: string): string {
  let q = prompt
    .replace(/tell me (about|what|how)/gi, " ")
    .replace(/what (topics?|does|is|are|do)/gi, " ")
    .replace(/does it cover\??/gi, " ")
    .replace(/it cover\??/gi, " ")
    .replace(/can you (explain|summarize|describe)/gi, " ")
    .replace(/summarize (the|this|a)/gi, " ")
    .replace(/explain (the|this|a)/gi, " ")
    .replace(/for (the resource|course|subject)/gi, " ")
    .replace(/\bthe resource\b/gi, " ")
    .replace(/\bresource\b/gi, " ")
    .replace(/\btopics?\b/gi, " ")
    .replace(/\bcover\b/gi, " ")
    .replace(/\babout\b/gi, " ")
    .replace(/["""''']/g, " ")
    .replace(/[?!.,;:()]/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  // Keep only words ≥ 3 chars to drop noise like "me", "it", "a"
  return q.split(" ").filter(w => w.length >= 3).join(" ");
}

// Extract text inside quotes from the original prompt (resource name hint)
function extractQuotedHint(prompt: string): string | null {
  const m = prompt.match(/["""']([^"""']+)["""']/);
  return m ? m[1].trim() : null;
}

// ── Main Handler ──────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: JSON_HEADERS });
  }

  try {
    const { prompt, context, session_id, course_code, semester } = await req.json() as {
      prompt:      string;
      context?:    string;
      session_id?: string;
      course_code?: string;
      semester?:   number;
    };

    if (!prompt || typeof prompt !== "string" || prompt.trim().length < 2) {
      return new Response(
        JSON.stringify({ error: "Missing or invalid 'prompt' field." }),
        { status: 400, headers: JSON_HEADERS }
      );
    }

    // ── Auth: get user from JWT ───────────────────────────────────────────────
    const authHeader = req.headers.get("Authorization") || "";
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace("Bearer ", "").trim()
    );
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: JSON_HEADERS }
      );
    }

    const userId = user.id;

    // ── Check for user-provided key via header (legacy support) ───────────────
    const headerKey = req.headers.get("x-user-groq-key");

    // ── STEP 1: Check daily quota ─────────────────────────────────────────────
    // Convert UTC to BDT date (UTC+6) to reset limit at midnight BDT
    const bdtDate = new Date(Date.now() + 6 * 60 * 60 * 1000);
    const today = bdtDate.toISOString().split("T")[0];
    let currentCount = 0;
    let hasOwnKey = false;
    let userKeyRow: any = null;

    try {
      const { data: usageRow } = await supabase
        .from("daily_ai_usage")
        .select("question_count")
        .eq("user_id", userId)
        .eq("date", today)
        .single();
      currentCount = usageRow?.question_count ?? 0;
    } catch (_) {}

    try {
      const { data } = await supabase
        .from("user_ai_keys")
        .select("groq_key_iv, groq_key_encrypted, is_active")
        .eq("user_id", userId)
        .single();
      userKeyRow = data;
      hasOwnKey = !!(userKeyRow?.groq_key_encrypted && userKeyRow?.is_active);
    } catch (_) {}

    const hasHeaderKey = !!(headerKey && headerKey.trim() !== "");
    const usingOwnKey = hasOwnKey || hasHeaderKey;

    if (currentCount >= DAILY_FREE_LIMIT && !usingOwnKey) {
      return new Response(
        JSON.stringify({
          error:           "quota_exceeded",
          message:         "Your 5 free questions for today are exhausted. Resets at midnight BDT.",
          questions_used:  currentCount,
          questions_limit: DAILY_FREE_LIMIT,
          can_add_own_key: true
        }),
        { status: 429, headers: JSON_HEADERS }
      );
    }

    // ── STEP 2: Check answer cache ────────────────────────────────────────────
    const cacheKey = prompt + (course_code || '') + String(semester || '');
    const qHash = await md5(cacheKey);
    let cached: any = null;

    try {
      const { data } = await supabase
        .from("cached_ai_responses")
        .select("*")
        .eq("question_hash", qHash)
        .single();
      cached = data;
    } catch (_) {}

    if (cached) {
      await supabase
        .from("cached_ai_responses")
        .update({ hit_count: (cached.hit_count || 0) + 1, last_hit_at: new Date().toISOString() })
        .eq("id", cached.id);

      if (session_id) {
        await supabase.from("ai_chat_messages").insert({
          user_id:    userId,
          session_id,
          role:       "assistant",
          content:    cached.response_text,
          used_rag:   cached.used_rag,
          model_used: cached.model_used,
          from_cache: true
        });
      }

      const encoder = new TextEncoder();
      const stream = new ReadableStream({
        start(controller) {
          controller.enqueue(
            encoder.encode(`data: ${JSON.stringify({ token: cached.response_text })}\n\n`)
          );
          const suggestions = generateSuggestions(prompt, cached.response_text);
          controller.enqueue(
            encoder.encode(`data: ${JSON.stringify({
              done: true,
              suggestions,
              from_cache: true,
              used_rag: cached.used_rag,
              questions_used: currentCount,
              questions_limit: usingOwnKey ? null : DAILY_FREE_LIMIT,
            })}\n\n`)
          );
          controller.close();
        }
      });

      return new Response(stream, { headers: CORS_HEADERS });
    }

    // ── STEP 3: Multi-pass RAG ────────────────────────────────────────────────
    let ragContext:       string | null = null;
    let citedFilename:   string | null = null;
    let citedResourceId: string | null = null;
    let chunkPreview:    string | null = null;
    let usedRag = false;

    try {
      const ftsQuery    = extractFtsKeywords(prompt);
      const filenameHint = extractQuotedHint(prompt);

      type Chunk = { chunk_text: string; source_filename: string; resource_id: string };

      const ftsSearch = async (q: string, courseFilter: string | null, semFilter: number | null): Promise<Chunk[] | null> => {
        if (q.length < 3) return null;
        const { data } = await supabase.rpc("search_resource_chunks_fts", {
          query_text:        q,
          filter_course:     courseFilter,
          filter_semester:   semFilter,
          filter_department: null,
          match_count:       5,
        });
        return data && data.length > 0 ? data : null;
      };

      let chunks: Chunk[] | null = null;

      // Pass 1: cleaned keywords + course + semester filters
      if (!chunks) chunks = await ftsSearch(ftsQuery, course_code || null, semester || null);

      // Pass 2: cleaned keywords, no filters
      if (!chunks) chunks = await ftsSearch(ftsQuery, null, null);

      // Pass 3: filename hint — match source_filename OR resource title
      if (!chunks && filenameHint) {
        // Try matching source_filename directly
        const { data: fnChunks } = await supabase
          .from("resource_chunks")
          .select("chunk_text, source_filename, resource_id")
          .ilike("source_filename", `%${filenameHint}%`)
          .limit(5);
        if (fnChunks && fnChunks.length > 0) {
          chunks = fnChunks as Chunk[];
        } else {
          // Try matching resource title in resources table, then get its chunks
          const { data: matchedResources } = await supabase
            .from("resources")
            .select("id")
            .ilike("title", `%${filenameHint}%`)
            .eq("approval_status", "approved")
            .limit(3);
          if (matchedResources && matchedResources.length > 0) {
            const ids = matchedResources.map((r: any) => r.id);
            const { data: titleChunks } = await supabase
              .from("resource_chunks")
              .select("chunk_text, source_filename, resource_id")
              .in("resource_id", ids)
              .limit(5);
            if (titleChunks && titleChunks.length > 0) chunks = titleChunks as Chunk[];
          }
        }
        // Try each word of the hint individually against source_filename
        if (!chunks) {
          for (const word of filenameHint.split(" ").filter((w: string) => w.length >= 3)) {
            const q = course_code
              ? supabase
                  .from("resource_chunks")
                  .select("chunk_text, source_filename, resource_id")
                  .ilike("source_filename", `%${word}%`)
                  .eq("course_code", course_code)
                  .limit(5)
              : supabase
                  .from("resource_chunks")
                  .select("chunk_text, source_filename, resource_id")
                  .ilike("source_filename", `%${word}%`)
                  .limit(5);
            const { data: wordChunks } = await q;
            if (wordChunks && wordChunks.length > 0) { chunks = wordChunks as Chunk[]; break; }
          }
        }
      }

      // Pass 4: course_code as keyword only (last resort)
      if (!chunks && course_code) chunks = await ftsSearch(course_code, null, null);

      if (chunks && chunks.length > 0) {
        ragContext = chunks
          .map((c, i) => `[Excerpt ${i + 1} from ${c.source_filename}]\n${c.chunk_text}`)
          .join("\n\n---\n\n");
        citedFilename   = chunks[0].source_filename;
        citedResourceId = chunks[0].resource_id;
        chunkPreview    = chunks[0].chunk_text.substring(0, 200);
        usedRag         = true;
      }
    } catch (ragError) {
      console.error("RAG search failed:", ragError);
    }

    // ── STEP 4: Build system prompt ───────────────────────────────────────────
    let systemInstruction: string;

    if (usedRag && ragContext) {
      systemInstruction = `You are UniShareSync AI, an academic assistant for SMUCT students.
The user is asking about an uploaded course document. The excerpts below ARE that document.
Speak confidently and directly — do NOT say "based on excerpts" or "we can infer" or "might cover".
Simply answer: "This resource covers..." and list the topics found in the excerpts.
Use bullet points for topic lists. Be direct and helpful.
Only mention something is missing if the user asks for a specific detail not present.
Do not make up information not in the excerpts.
Respond in Bangla if the question is in Bangla, English otherwise.

Document excerpts:
${ragContext}`;
    } else {
      systemInstruction = `You are UniShareSync AI Campus Assistant — a friendly, concise, and helpful chatbot for a university campus app called UniShareSync.

UniShareSync App Features you can help with:
- CLASS SCHEDULE: View today's and weekly class timetable filtered by semester/group.
- EVENTS: Browse, RSVP, and get reminders for campus events. Earn certificates for attended events.
- COMMUNITIES / CLUBS: Join or create student clubs and communities, post announcements, chat with members.
- CAMPUS SHARE (Item Share): Borrow or lend items (books, equipment, etc.) with other students. Manage loan requests, agreements, and disputes.
- RESOURCES: Upload and download study materials (notes, slides, past papers) filtered by course and semester. AI can answer questions from uploaded PDFs.
- PROJECTS (Project Hub): Create or join collaborative student projects, manage tasks on a Kanban board, use a shared whiteboard, and invite supervisors.
- ALUMNI CONNECT: Browse verified alumni profiles, find mentors, and connect with graduates by batch/industry.
- NOTICE BOARD: View official university notices and community announcements.
- LOST & FOUND: Report lost items or claim found ones on campus.\n- CLASS SCHEDULER: Build and export your personal weekly timetable.
- BUS TRACKER: Track campus shuttle buses in real-time.
- PROFILE: Manage your academic profile, avatar, and role (student/faculty/admin).
- NOTIFICATIONS: Get push notifications for events, notices, project updates, and community posts.

Rules:
- Be concise and clear. Use bullet points or numbered lists when appropriate.
- If the user asks about something not in the provided context, say you don't have that information right now and suggest they check the relevant section of the app.
- Never fabricate data. Only reference information from the context below.
- Be warm and encouraging. Use emoji sparingly (1-2 per response max).
- Always respond in the same language the user writes in.
- When asked about app features, explain them clearly even if not in the live context.

--- LIVE CAMPUS CONTEXT ---
${context || "No live context available at this time."}
--- END CONTEXT ---`;
    }

    // ── STEP 5: Determine API key ─────────────────────────────────────────────
    let groqApiKey = GROQ_KEY;

    if (hasHeaderKey) {
      groqApiKey = headerKey!.trim();
    } else if (hasOwnKey && ENCRYPTION_KEY) {
      try {
        groqApiKey = await decryptUserKey(userKeyRow.groq_key_iv, userKeyRow.groq_key_encrypted);
      } catch (e) {
        console.error("Failed to decrypt user key:", e);
      }
    }

    if (!groqApiKey) {
      return new Response(
        JSON.stringify({
          error: "API_KEY_REQUIRED",
          message: "No API key available. Please add your Groq API key in settings."
        }),
        { status: 400, headers: JSON_HEADERS }
      );
    }

    // ── STEP 6: Call Groq with streaming ──────────────────────────────────────
    const groqPayload = {
      model: GROQ_MODEL,
      messages: [
        { role: "system", content: systemInstruction },
        { role: "user", content: prompt }
      ],
      temperature: 0.7,
      max_tokens: MAX_OUTPUT_TOKENS,
      stream: true,
    };

    const groqRes = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${groqApiKey}`,
      },
      body: JSON.stringify(groqPayload),
    });

    if (!groqRes.ok) {
      const errText = await groqRes.text();
      console.error("Groq API error:", errText);
      return new Response(
        JSON.stringify({ error: "AI service error", details: errText }),
        { status: 502, headers: JSON_HEADERS }
      );
    }

    // ── Stream Groq response as SSE ──────────────────────────────────────────
    const reader = groqRes.body!.getReader();
    const encoder = new TextEncoder();
    const decoder = new TextDecoder();

    const stream = new ReadableStream({
      async start(controller) {
        let fullText = "";
        let buffer = "";

        try {
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;

            buffer += decoder.decode(value, { stream: true });
            const lines = buffer.split("\n");
            buffer = lines.pop() || "";

            for (const line of lines) {
              const cleaned = line.trim();
              if (!cleaned.startsWith("data: ")) continue;
              const jsonStr = cleaned.slice(6).trim();
              if (!jsonStr || jsonStr === "[DONE]") continue;

              try {
                const parsed = JSON.parse(jsonStr);
                const text = parsed?.choices?.[0]?.delta?.content ?? "";
                if (text) {
                  fullText += text;
                  controller.enqueue(
                    encoder.encode(`data: ${JSON.stringify({ token: text })}\n\n`)
                  );
                }
              } catch { /* skip parse errors */ }
            }
          }

          // ── Post-stream: cache, quota, history ───────────────────────────────
          const modelUsed = `groq/${GROQ_MODEL}`;

          // Only cache RAG-backed answers — never cache "I don't know" replies
          if (usedRag) {
            try {
              await supabase.from("cached_ai_responses").upsert({
                question_hash: qHash,
                question_text: prompt.substring(0, 500),
                response_text: fullText,
                used_rag:      true,
                model_used:    modelUsed
              }, { onConflict: "question_hash" });
            } catch (_) {}
          }

          // Increment daily usage (only for non-own-key users)
          let newCount = currentCount;
          if (!usingOwnKey) {
            try {
              const { data: countData } = await supabase
                .rpc("increment_ai_usage", { p_user_id: userId });
              newCount = countData ?? currentCount + 1;
            } catch (_) {}
          }

          // Save to chat history
          if (session_id) {
            try {
              await supabase.from("ai_chat_messages").insert({
                user_id:            userId,
                session_id,
                role:               "assistant",
                content:            fullText,
                used_rag:           usedRag,
                cited_resource_id:  citedResourceId,
                cited_filename:     citedFilename,
                cited_chunk_preview: chunkPreview,
                model_used:         modelUsed,
                from_cache:         false,
                questions_used:     usingOwnKey ? null : newCount
              });
            } catch (_) {}
          }

          const suggestions = generateSuggestions(prompt, fullText);
          controller.enqueue(
            encoder.encode(`data: ${JSON.stringify({
              done: true,
              suggestions,
              used_rag:        usedRag,
              citation:        usedRag ? {
                filename:    citedFilename,
                resource_id: citedResourceId,
                preview:     chunkPreview
              } : null,
              from_cache:      false,
              model_used:      modelUsed,
              questions_used:  usingOwnKey ? null : newCount,
              questions_limit: usingOwnKey ? null : DAILY_FREE_LIMIT,
              using_own_key:   usingOwnKey
            })}\n\n`)
          );
        } catch (err) {
          console.error("Stream error:", err);
          controller.enqueue(
            encoder.encode(`data: ${JSON.stringify({ error: "Stream interrupted" })}\n\n`)
          );
        } finally {
          controller.close();
        }
      },
    });

    return new Response(stream, { headers: CORS_HEADERS });

  } catch (err) {
    console.error("Function error:", err);
    return new Response(
      JSON.stringify({ error: "Internal function error" }),
      { status: 500, headers: JSON_HEADERS }
    );
  }
});
