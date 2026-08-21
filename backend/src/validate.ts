import type { VisionFoodItemDTO, VisionMealDraftDTO } from "./types";

export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ValidationError";
  }
}

function clamp01(n: number): number {
  if (!Number.isFinite(n)) return 0;
  return Math.min(1, Math.max(0, n));
}

function boundGrams(n: number): number {
  if (!Number.isFinite(n) || n <= 0) throw new ValidationError("grams must be > 0");
  if (n > 5000) throw new ValidationError("grams out of bounds");
  return n;
}

function cleanString(value: unknown, field: string, max = 120): string {
  if (typeof value !== "string") throw new ValidationError(`${field} must be a string`);
  const trimmed = value.trim();
  if (!trimmed) throw new ValidationError(`${field} is empty`);
  if (trimmed.length > max) throw new ValidationError(`${field} too long`);
  return trimmed;
}

export function validateDraft(raw: unknown): VisionMealDraftDTO {
  if (!raw || typeof raw !== "object") throw new ValidationError("draft must be an object");
  const draft = raw as Record<string, unknown>;

  const schemaVersion = Number(draft.schema_version ?? draft.schemaVersion ?? 1);
  if (schemaVersion !== 1) throw new ValidationError("unsupported schema_version");

  const mealName = cleanString(draft.meal_name ?? draft.mealName ?? "Meal", "meal_name", 80);
  const itemsRaw = draft.items;
  if (!Array.isArray(itemsRaw)) throw new ValidationError("items must be an array");
  if (itemsRaw.length < 0 || itemsRaw.length > 20) {
    throw new ValidationError("items count must be 0…20");
  }

  const items: VisionFoodItemDTO[] = itemsRaw.map((item, index) => {
    if (!item || typeof item !== "object") throw new ValidationError(`item[${index}] invalid`);
    const row = item as Record<string, unknown>;
    const estimated = boundGrams(Number(row.estimated_grams ?? row.estimatedGrams));
    const low = boundGrams(Number(row.gram_range_low ?? row.gramRangeLow ?? estimated * 0.8));
    const high = boundGrams(Number(row.gram_range_high ?? row.gramRangeHigh ?? estimated * 1.2));
    if (low > estimated || estimated > high) {
      throw new ValidationError(`item[${index}] gram range invalid`);
    }
    return {
      id: typeof row.id === "string" ? row.id : crypto.randomUUID(),
      display_name: cleanString(row.display_name ?? row.displayName, `item[${index}].display_name`),
      canonical_query: cleanString(
        row.canonical_query ?? row.canonicalQuery,
        `item[${index}].canonical_query`,
      ),
      estimated_grams: estimated,
      gram_range_low: low,
      gram_range_high: high,
      preparation:
        row.preparation == null ? null : cleanString(String(row.preparation), "preparation", 60),
      brand_or_restaurant:
        row.brand_or_restaurant == null && row.brandOrRestaurant == null
          ? null
          : cleanString(
              String(row.brand_or_restaurant ?? row.brandOrRestaurant),
              "brand_or_restaurant",
              80,
            ),
      visible_additions: Array.isArray(row.visible_additions)
        ? row.visible_additions.map(String).slice(0, 12)
        : Array.isArray(row.visibleAdditions)
          ? row.visibleAdditions.map(String).slice(0, 12)
          : [],
      confidence: clamp01(Number(row.confidence ?? 0.5)),
      notes: row.notes == null ? null : String(row.notes).slice(0, 200),
    };
  });

  return {
    schema_version: 1,
    meal_name: mealName,
    items,
    overall_confidence: clamp01(Number(draft.overall_confidence ?? draft.overallConfidence ?? 0.7)),
    clarifying_question:
      draft.clarifying_question == null && draft.clarifyingQuestion == null
        ? null
        : String(draft.clarifying_question ?? draft.clarifyingQuestion).slice(0, 200),
    uncertainty_notes: Array.isArray(draft.uncertainty_notes)
      ? draft.uncertainty_notes.map(String).slice(0, 8)
      : Array.isArray(draft.uncertaintyNotes)
        ? draft.uncertaintyNotes.map(String).slice(0, 8)
        : [],
  };
}
