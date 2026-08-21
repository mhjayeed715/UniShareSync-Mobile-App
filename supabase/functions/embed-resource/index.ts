// supabase/functions/embed-resource/index.ts
// Extracts text from uploaded resources and chunks them for FTS RAG.
// Uses pdf.js via esm.sh for proper FlateDecode PDF text extraction.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { extractText } from "https://esm.sh/unpdf@0.11.0";

const SUPABASE_URL         = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

// ── PDF text extractor using unpdf ───────────────────────────────────────────
async function extractTextFromPdfBytes(bytes: Uint8Array): Promise<string> {
  try {
    const { text } = await extractText(bytes, { mergePages: true });
    return Array.isArray(text) ? (text as string[]).join("\n") : (text as string);
  } catch (e) {
    console.error("unpdf extraction failed:", e);
    return "";
  }
}

// ── Text chunker ──────────────────────────────────────────────────────────────
function chunkText(text: string, chunkSize = 400, overlap = 60): string[] {
  const words = text.split(/\s+/).filter(w => w.length > 0);
  const chunks: string[] = [];
  let i = 0;
  while (i < words.length) {
    const slice = words.slice(i, i + chunkSize);
    if (slice.length < 20 && chunks.length > 0) break;
    chunks.push(slice.join(" "));
    i += chunkSize - overlap;
  }
  return chunks;
}

// ── SHA-256 chunk hash ────────────────────────────────────────────────────────
async function sha256(text: string): Promise<string> {
  const buf  = new TextEncoder().encode(text);
  const hash = await crypto.subtle.digest("SHA-256", buf);
  return Array.from(new Uint8Array(hash))
    .map(b => b.toString(16).padStart(2, "0"))
    .join("");
}

// Helper to sanitize strings of null bytes and control characters
function sanitizeString(str: string): string;
function sanitizeString(str: undefined): undefined;
function sanitizeString(str: string | undefined): string | undefined {
  if (!str) return str;
  return str
    .replace(/\\u0000/gi, "")
    .replace(/\u0000/g, "")
    .replace(/\x00/g, "")
    .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, "")
    .trim();
}

// ── Main handler ──────────────────────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const rawBody = await req.text();
    // Strip literal \u0000 and unsupported unicode escapes before parsing
    const cleanBody = rawBody
      .replace(/\\u0000/gi, '')
      .replace(/\\u[0-9a-fA-F]{0,3}(?![0-9a-fA-F])/g, '')
      .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, '');

    const parsed = JSON.parse(cleanBody) as {
      resource_id:   string;
      storage_path?: string;
      drive_url?:    string;
      filename:      string;
      course_code?:  string;
      semester?:     number;
      department?:   string;
    };

    const resource_id  = sanitizeString(parsed.resource_id);
    const storage_path = sanitizeString(parsed.storage_path);
    const drive_url    = sanitizeString(parsed.drive_url);
    const filename     = sanitizeString(parsed.filename);
    const course_code  = sanitizeString(parsed.course_code);
    const semester     = parsed.semester;
    const department   = sanitizeString(parsed.department);

    if (!resource_id || !filename) {
      return new Response(
        JSON.stringify({ error: "resource_id and filename are required" }),
        { status: 400, headers: CORS_HEADERS }
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // Mark processing
    await supabase.from("resources")
      .update({ embedding_status: "processing" })
      .eq("id", resource_id);

    // Fetch file — from Supabase Storage or Google Drive
    let fileBlob: Blob | null = null;

    if (storage_path) {
      const { data, error: dlError } = await supabase.storage
        .from("resources")
        .download(storage_path);
      if (dlError || !data) {
        await supabase.from("resources").update({
          embedding_status: "failed",
          embedding_error:  `Storage download failed: ${dlError?.message}`
        }).eq("id", resource_id);
        return new Response(
          JSON.stringify({ error: `Download failed: ${dlError?.message}` }),
          { status: 500, headers: CORS_HEADERS }
        );
      }
      fileBlob = data;
    } else if (drive_url) {
      const fileIdMatch = drive_url.match(/\/d\/([a-zA-Z0-9_-]+)/);
      if (!fileIdMatch) {
        await supabase.from("resources").update({
          embedding_status: "failed",
          embedding_error: "Could not extract file ID from Drive URL"
        }).eq("id", resource_id);
        return new Response(JSON.stringify({ error: "Invalid Drive URL" }), { status: 400, headers: CORS_HEADERS });
      }
      const fileId = fileIdMatch[1];
      // Try usercontent download first, fall back to export URL for smaller files
      const downloadUrls = [
        `https://drive.usercontent.google.com/download?id=${fileId}&export=download&confirm=t&authuser=0`,
        `https://drive.google.com/uc?export=download&id=${fileId}&confirm=t`,
      ];
      let fetchErr: unknown;
      for (const downloadUrl of downloadUrls) {
        try {
          const res = await fetch(downloadUrl, {
            redirect: "follow",
            headers: { "User-Agent": "Mozilla/5.0" },
          });
          if (!res.ok) throw new Error(`HTTP ${res.status}`);
          const contentType = res.headers.get("content-type") ?? "";
          // Reject HTML responses (virus-scan interstitial page)
          if (contentType.includes("text/html")) throw new Error("Got HTML instead of file");
          fileBlob = await res.blob();
          break;
        } catch (err) {
          fetchErr = err;
        }
      }
      if (!fileBlob) {
        await supabase.from("resources").update({
          embedding_status: "failed",
          embedding_error:  `Drive fetch failed: ${fetchErr}`
        }).eq("id", resource_id);
        return new Response(
          JSON.stringify({ error: `Drive fetch failed: ${fetchErr}` }),
          { status: 500, headers: CORS_HEADERS }
        );
      }
    } else {
      await supabase.from("resources").update({
        embedding_status: "failed",
        embedding_error:  "No storage_path or drive_url provided"
      }).eq("id", resource_id);
      return new Response(
        JSON.stringify({ error: "Provide storage_path or drive_url" }),
        { status: 400, headers: CORS_HEADERS }
      );
    }

    // Extract text
    const ext = (filename.includes('.') ? filename.split(".").pop()?.toLowerCase() : "pdf") ?? "pdf";
    let fullText = "";

    if (ext === "pdf") {
      const buffer = await fileBlob.arrayBuffer();
      fullText = await extractTextFromPdfBytes(new Uint8Array(buffer));
    } else if (["txt", "md", "csv"].includes(ext)) {
      fullText = await fileBlob.text();
    } else {
      await supabase.from("resources").update({
        embedding_status: "skipped",
        embedding_error:  `Unsupported file type: .${ext}`
      }).eq("id", resource_id);
      return new Response(
        JSON.stringify({ skipped: true, reason: `Unsupported type: .${ext}` }),
        { status: 200, headers: CORS_HEADERS }
      );
    }

    fullText = sanitizeString(fullText).replace(/\s+/g, " ").trim();

    if (fullText.length < 50) {
      // PDF text extraction may yield nothing for scanned/image PDFs — skip gracefully
      await supabase.from("resources").update({
        embedding_status: "skipped",
        embedding_error:  "Extracted text too short — file may be a scanned image PDF"
      }).eq("id", resource_id);
      return new Response(
        JSON.stringify({ skipped: true, reason: "Text too short or scanned PDF" }),
        { status: 200, headers: CORS_HEADERS }
      );
    }

    // Chunk
    const chunks = chunkText(fullText).map(c => sanitizeString(c));

    // Delete old chunks
    await supabase.from("resource_chunks").delete().eq("resource_id", resource_id);

    // Build rows
    const rows = await Promise.all(
      chunks.map(async (chunk, idx) => ({
        resource_id,
        chunk_index:     idx,
        chunk_text:      chunk,
        chunk_hash:      await sha256(chunk),
        source_filename: filename,
        course_code:     course_code ?? null,
        semester:        semester    ?? null,
        department:      department ?? "CSE",
        token_count:     chunk.split(/\s+/).length,
      }))
    );

    // Insert in batches of 50
    for (let i = 0; i < rows.length; i += 50) {
      const { error: insertErr } = await supabase
        .from("resource_chunks")
        .insert(rows.slice(i, i + 50));

      if (insertErr) {
        await supabase.from("resources").update({
          embedding_status: "failed",
          embedding_error:  `Insert failed: ${insertErr.message}`
        }).eq("id", resource_id);
        return new Response(
          JSON.stringify({ error: insertErr.message }),
          { status: 500, headers: CORS_HEADERS }
        );
      }
    }

    // Mark done
    await supabase.from("resources").update({
      embedding_status:      "done",
      embedding_chunk_count: chunks.length,
      embedded_at:           new Date().toISOString(),
      embedding_error:       null,
    }).eq("id", resource_id);

    return new Response(
      JSON.stringify({ success: true, resource_id, chunks_count: chunks.length, text_length: fullText.length }),
      { status: 200, headers: CORS_HEADERS }
    );

  } catch (err) {
    console.error("embed-resource error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: CORS_HEADERS }
    );
  }
});