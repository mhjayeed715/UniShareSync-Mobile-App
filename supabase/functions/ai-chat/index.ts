// supabase/functions/ai-chat/index.ts
// Deploy with: npx supabase functions deploy ai-chat
// Set secret:  npx supabase secrets set GROQ_API_KEY=<your_key>

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-user-gemini-key, x-user-groq-key",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const { prompt, context } = await req.json();

    if (!prompt || typeof prompt !== "string") {
      return new Response(
        JSON.stringify({ error: "Missing or invalid 'prompt' field." }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Support user-provided API Key (Groq or Gemini)
    let apiKey = req.headers.get("x-user-groq-key") || req.headers.get("x-user-gemini-key");
    let isGroq = false;

    if (apiKey && apiKey.trim() !== "") {
      isGroq = apiKey.startsWith("gsk_");
    } else {
      // Fallback to server secrets
      apiKey = Deno.env.get("GROQ_API_KEY") || "";
      if (apiKey) {
        isGroq = true;
      } else {
        apiKey = Deno.env.get("GEMINI_API_KEY") || "";
        isGroq = false;
      }
    }

    if (!apiKey) {
      return new Response(
        JSON.stringify({ 
          error: "API_KEY_REQUIRED", 
          message: "API key is required. Please set your Groq or Gemini API key in the AI Assistant settings." 
        }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Build the system instruction with campus context
    const systemInstruction = `You are UniShareSync AI Campus Assistant — a friendly, concise, and helpful chatbot for a university campus app called UniShareSync.

Your capabilities:
- Answer questions about today's class schedule, upcoming events, active projects, recent notices, and lost & found items.
- Provide guidance on using the UniShareSync app features.
- Give general academic and campus life advice.

Rules:
- Be concise and clear. Use bullet points or numbered lists when appropriate.
- If the user asks about something not in the provided context, say you don't have that information right now and suggest they check the relevant section of the app.
- Never fabricate data. Only reference information from the context below.
- Be warm and encouraging. Use emoji sparingly (1-2 per response max).
- Always respond in the same language the user writes in.

--- LIVE CAMPUS CONTEXT ---
${context || "No live context available at this time."}
--- END CONTEXT ---`;

    if (isGroq) {
      // ──────────────────────────────────────────────
      //  GROQ API Call
      // ──────────────────────────────────────────────
      const groqUrl = "https://api.groq.com/openai/v1/chat/completions";
      const groqPayload = {
        model: "llama-3.1-8b-instant",
        messages: [
          { role: "system", content: systemInstruction },
          { role: "user", content: prompt }
        ],
        temperature: 0.7,
        max_tokens: 300,
        stream: true,
      };

      const groqRes = await fetch(groqUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`,
        },
        body: JSON.stringify(groqPayload),
      });

      if (!groqRes.ok) {
        const errText = await groqRes.text();
        console.error("Groq API error:", errText);
        return new Response(
          JSON.stringify({ error: "AI service error", details: errText }),
          { status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
      }

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
                } catch {
                  // Skip parse errors on partial chunks
                }
              }
            }

            const suggestions = generateSuggestions(prompt, fullText);
            controller.enqueue(
              encoder.encode(
                `data: ${JSON.stringify({ done: true, suggestions })}\n\n`
              )
            );
          } catch (err) {
            console.error("Groq Stream error:", err);
            controller.enqueue(
              encoder.encode(
                `data: ${JSON.stringify({ error: "Stream interrupted" })}\n\n`
              )
            );
          } finally {
            controller.close();
          }
        },
      });

      return new Response(stream, {
        headers: {
          ...CORS_HEADERS,
          "Content-Type": "text/event-stream",
          "Cache-Control": "no-cache",
          Connection: "keep-alive",
        },
      });

    } else {
      // ──────────────────────────────────────────────
      //  GEMINI API Call
      // ──────────────────────────────────────────────
      let geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:streamGenerateContent?alt=sse&key=${apiKey}`;

      const geminiPayload = {
        system_instruction: {
          parts: [{ text: systemInstruction }],
        },
        contents: [
          {
            role: "user",
            parts: [{ text: prompt }],
          },
        ],
        generationConfig: {
          temperature: 0.7,
          topP: 0.9,
          topK: 40,
          maxOutputTokens: 300,
        },
      };

      let geminiRes = await fetch(geminiUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(geminiPayload),
      });

      if (!geminiRes.ok) {
        console.warn("Gemini 2.0 Flash failed or limit exceeded. Retrying with Gemini 1.5 Flash fallback...");
        geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:streamGenerateContent?alt=sse&key=${apiKey}`;
        geminiRes = await fetch(geminiUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(geminiPayload),
        });
      }

      if (!geminiRes.ok) {
        const errText = await geminiRes.text();
        console.error("Gemini API error (after fallback retry):", errText);
        return new Response(
          JSON.stringify({ error: "AI service error", details: errText }),
          { status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
      }

      const reader = geminiRes.body!.getReader();
      const encoder = new TextEncoder();
      const decoder = new TextDecoder();

      const stream = new ReadableStream({
        async start(controller) {
          let fullText = "";

          try {
            while (true) {
              const { done, value } = await reader.read();
              if (done) break;

              const chunk = decoder.decode(value, { stream: true });
              const lines = chunk.split("\n");

              for (const line of lines) {
                if (!line.startsWith("data: ")) continue;

                const jsonStr = line.slice(6).trim();
                if (!jsonStr || jsonStr === "[DONE]") continue;

                try {
                  const parsed = JSON.parse(jsonStr);
                  const text =
                    parsed?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

                  if (text) {
                    fullText += text;
                    controller.enqueue(
                      encoder.encode(`data: ${JSON.stringify({ token: text })}\n\n`)
                    );
                  }
                } catch {
                  // Skip malformed chunks
                }
              }
            }

            const suggestions = generateSuggestions(prompt, fullText);
            controller.enqueue(
              encoder.encode(
                `data: ${JSON.stringify({ done: true, suggestions })}\n\n`
              )
            );
          } catch (err) {
            console.error("Gemini Stream error:", err);
            controller.enqueue(
              encoder.encode(
                `data: ${JSON.stringify({ error: "Stream interrupted" })}\n\n`
              )
            );
          } finally {
            controller.close();
          }
        },
      });

      return new Response(stream, {
        headers: {
          ...CORS_HEADERS,
          "Content-Type": "text/event-stream",
          "Cache-Control": "no-cache",
          Connection: "keep-alive",
        },
      });
    }
  } catch (err) {
    console.error("Function error:", err);
    return new Response(
      JSON.stringify({ error: "Internal function error" }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});

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
    { label: "🏫 Campus info", prompt: "Tell me about campus facilities" },
    { label: "💡 App help", prompt: "How do I use UniShareSync?" },
  ];

  // Filter out suggestions that are too similar to the current prompt
  const filtered = pool.filter(
    (s) => !lower.includes(s.prompt.toLowerCase().slice(0, 20))
  );

  // Return 3-4 suggestions
  const shuffled = filtered.sort(() => Math.random() - 0.5);
  return shuffled.slice(0, 4);
}
