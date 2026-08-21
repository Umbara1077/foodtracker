import type { VisionMealDraftDTO } from "./types";
import { validateDraft } from "./validate";

/** Deterministic fixture drafts for local/CI when OpenAI is unavailable. */
export function mockAnalyze(imageBytes: Uint8Array): VisionMealDraftDTO {
  const sum = imageBytes.reduce((acc, b) => acc + b, 0);
  const bucket = sum % 3;

  if (bucket === 1) {
    return validateDraft({
      schema_version: 1,
      meal_name: "Yogurt bowl",
      overall_confidence: 0.8,
      items: [
        {
          display_name: "Greek yogurt",
          canonical_query: "greek yogurt",
          estimated_grams: 170,
          gram_range_low: 150,
          gram_range_high: 190,
          confidence: 0.88,
        },
        {
          display_name: "Granola",
          canonical_query: "granola",
          estimated_grams: 30,
          gram_range_low: 20,
          gram_range_high: 40,
          confidence: 0.74,
        },
        {
          display_name: "Blueberries",
          canonical_query: "blueberries",
          estimated_grams: 40,
          gram_range_low: 30,
          gram_range_high: 55,
          confidence: 0.8,
        },
      ],
    });
  }

  if (bucket === 2) {
    return validateDraft({
      schema_version: 1,
      meal_name: "Unclear meal",
      overall_confidence: 0.25,
      clarifying_question: "Retake with the whole plate visible?",
      uncertainty_notes: ["Low visibility"],
      items: [
        {
          display_name: "Unknown food",
          canonical_query: "mixed meal",
          estimated_grams: 200,
          gram_range_low: 120,
          gram_range_high: 280,
          confidence: 0.3,
        },
      ],
    });
  }

  return validateDraft({
    schema_version: 1,
    meal_name: "Chicken rice bowl",
    overall_confidence: 0.82,
    uncertainty_notes: ["Sauce amount is approximate."],
    items: [
      {
        display_name: "Grilled chicken",
        canonical_query: "chicken breast grilled",
        estimated_grams: 135,
        gram_range_low: 110,
        gram_range_high: 160,
        preparation: "grilled",
        confidence: 0.9,
      },
      {
        display_name: "White rice",
        canonical_query: "white rice cooked",
        estimated_grams: 180,
        gram_range_low: 150,
        gram_range_high: 210,
        preparation: "cooked",
        confidence: 0.86,
      },
      {
        display_name: "Avocado",
        canonical_query: "avocado",
        estimated_grams: 55,
        gram_range_low: 40,
        gram_range_high: 70,
        confidence: 0.78,
      },
      {
        display_name: "Sauce",
        canonical_query: "savory sauce",
        estimated_grams: 28,
        gram_range_low: 15,
        gram_range_high: 40,
        confidence: 0.62,
      },
    ],
  });
}
