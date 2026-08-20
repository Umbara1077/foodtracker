import type { Env, VisionMealDraftDTO } from "./types";
import { validateDraft, ValidationError } from "./validate";

const SYSTEM_PROMPT = `You are a meal photo parser for a calorie tracker.
Return ONLY structured recognition facts: food names, portions in grams, confidence.
Do NOT invent authoritative nutrition facts (calories/macros).
Prefer common grocery/restaurant names suitable for USDA-style search.
If unsure, lower confidence and add uncertainty notes.
Keep meal_name short. Max 20 items.`;

export async function openAIAnalyze(
  env: Env,
  imageBase64: string,
  mimeType: string,
  locale: string,
  mealHint: string | null,
): Promise<{ draft: VisionMealDraftDTO; model: string }> {
  const apiKey = env.OPENAI_API_KEY;
  if (!apiKey) throw new Error("OPENAI_API_KEY missing");

  const model = env.PRIMARY_MODEL || "gpt-5.6-luna";
  const userText = [
    `Locale: ${locale}`,
    mealHint ? `Meal hint: ${mealHint}` : null,
    "Identify foods and estimate edible portion grams for each visible item.",
  ]
    .filter(Boolean)
    .join("\n");

  const schema = {
    type: "object",
    additionalProperties: false,
    required: [
      "schema_version",
      "meal_name",
      "items",
      "overall_confidence",
      "clarifying_question",
      "uncertainty_notes",
    ],
    properties: {
      schema_version: { type: "integer" },
      meal_name: { type: "string" },
      overall_confidence: { type: "number" },
      clarifying_question: { type: ["string", "null"] },
      uncertainty_notes: { type: "array", items: { type: "string" } },
        items: {
          type: "array",
          minItems: 0,
          maxItems: 20,
        items: {
          type: "object",
          additionalProperties: false,
          required: [
            "display_name",
            "canonical_query",
            "estimated_grams",
            "gram_range_low",
            "gram_range_high",
            "preparation",
            "brand_or_restaurant",
            "visible_additions",
            "confidence",
          ],
          properties: {
            display_name: { type: "string" },
            canonical_query: { type: "string" },
            estimated_grams: { type: "number" },
            gram_range_low: { type: "number" },
            gram_range_high: { type: "number" },
            preparation: { type: ["string", "null"] },
            brand_or_restaurant: { type: ["string", "null"] },
            visible_additions: { type: "array", items: { type: "string" } },
            confidence: { type: "number" },
          },
        },
      },
    },
  };

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      store: false,
      reasoning: { effort: "low" },
      input: [
        {
          role: "system",
          content: [{ type: "input_text", text: SYSTEM_PROMPT }],
        },
        {
          role: "user",
          content: [
            { type: "input_text", text: userText },
            {
              type: "input_image",
              image_url: `data:${mimeType};base64,${imageBase64}`,
              detail: "auto",
            },
          ],
        },
      ],
      text: {
        format: {
          type: "json_schema",
          name: "meal_vision_draft",
          schema,
          strict: true,
        },
      },
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`OpenAI error ${response.status}: ${body.slice(0, 400)}`);
  }

  const payload = (await response.json()) as {
    output_text?: string;
    output?: Array<{
      type?: string;
      content?: Array<{ type?: string; text?: string }>;
    }>;
  };

  const text =
    payload.output_text ??
    payload.output
      ?.flatMap((block) => block.content ?? [])
      .find((c) => c.type === "output_text" || typeof c.text === "string")?.text;

  if (!text) throw new ValidationError("OpenAI returned empty structured output");

  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    throw new ValidationError("OpenAI returned non-JSON structured output");
  }

  return { draft: validateDraft(parsed), model };
}
