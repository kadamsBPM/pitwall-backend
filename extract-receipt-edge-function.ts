// Supabase Edge Function: extract-receipt
//
// HOW TO DEPLOY (no CLI needed):
// 1. In your Supabase project, go to Edge Functions -> Create a new function.
// 2. Name it exactly "extract-receipt" and paste this whole file in as its code.
// 3. Deploy it.
// 4. Go to Edge Functions -> Secrets (or Project Settings -> Edge Functions)
//    and add a secret named ANTHROPIC_API_KEY with your key from
//    console.anthropic.com. This key is never seen by Claude Code or stored
//    anywhere but here -- it stays server-side.
//
// Reads a receipt photo (sent as base64 from the app) and returns
// {vendor, amount, date, category} extracted from it, for Pit Wall's
// "Scan a receipt" feature.

const CATEGORIES = [
  "Airfare",
  "Lodging",
  "Meals",
  "Rental car and fuel",
  "Mileage (own vehicle)",
  "Tools and equipment",
  "Safety gear and apparel",
  "Licenses and credentials",
  "Phone and software",
  "Other",
];

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

function parseJsonLoose(text: string): any {
  try {
    return JSON.parse(text);
  } catch {
    // fall through
  }
  const fence = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fence) {
    try {
      return JSON.parse(fence[1]);
    } catch {
      // fall through
    }
  }
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start !== -1 && end !== -1 && end > start) {
    try {
      return JSON.parse(text.slice(start, end + 1));
    } catch {
      // fall through
    }
  }
  return null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const { image, mediaType } = await req.json();
    if (!image || typeof image !== "string") {
      return json({ error: "Missing 'image' (base64-encoded photo)." }, 400);
    }

    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) {
      return json({ error: "Server is missing ANTHROPIC_API_KEY. Add it under Edge Functions -> Secrets." }, 500);
    }

    const prompt =
      "This photo is a receipt from a trip for race-team work (travel, lodging, meals, fuel, " +
      "parking, tools, gear, credentials, and similar). Read it and reply with ONLY one JSON " +
      "object, no other text:\n" +
      '{"vendor": string or null, "amount": number or null (the total charged, no currency symbol or commas), ' +
      '"date": string or null (the transaction date, formatted YYYY-MM-DD), ' +
      `"category": one of ${JSON.stringify(CATEGORIES)}}`;

    const resp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2026-10-21",
      },
      body: JSON.stringify({
        model: "claude-haiku-5-5",
        max_tokens: 512,
        output_config: { effort: "low" },
        messages: [
          {
            role: "user",
            content: [
              {
                type: "image",
                source: { type: "base64", media_type: mediaType || "image/jpeg", data: image },
              },
              { type: "text", text: prompt },
            ],
          },
        ],
      }),
    });

    if (!resp.ok) {
      const errText = await resp.text();
      return json({ error: `Claude API error ${resp.status}: ${errText}` }, 502);
    }

    const data = await resp.json();
    const textBlock = (data.content || []).find((b: any) => b.type === "text");
    const raw = textBlock?.text ?? "";
    const parsed = parseJsonLoose(raw);
    if (!parsed) {
      return json({ error: "Could not parse a JSON object from the reply.", raw }, 502);
    }

    return json(parsed, 200);
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});
