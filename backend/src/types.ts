export interface Env {
  OPENAI_API_KEY?: string;
  APP_API_TOKEN?: string;
  PRIMARY_MODEL: string;
  ESCALATION_MODEL: string;
  FREE_DAILY_SCANS: string;
  /** auto | mock | openai */
  PROVIDER_MODE: string;
  SCAN_QUOTA: KVNamespace;
}

export interface VisionFoodItemDTO {
  id?: string;
  display_name: string;
  canonical_query: string;
  estimated_grams: number;
  gram_range_low: number;
  gram_range_high: number;
  preparation?: string | null;
  brand_or_restaurant?: string | null;
  visible_additions?: string[];
  confidence: number;
  notes?: string | null;
}

export interface VisionMealDraftDTO {
  schema_version: number;
  meal_name: string;
  items: VisionFoodItemDTO[];
  overall_confidence: number;
  clarifying_question?: string | null;
  uncertainty_notes?: string[];
}

export interface AnalyzeRequestBody {
  image_base64: string;
  mime_type?: string;
  meal_hint?: string | null;
  locale?: string;
  units?: string;
}

export interface AnalyzeResponseBody {
  request_id: string;
  provider: string;
  model: string;
  latency_ms: number;
  draft: VisionMealDraftDTO;
  quota: { remaining: number; daily_limit: number };
}

export interface RemoteConfigResponse {
  schema_version: number;
  primary_model: string;
  escalation_model: string;
  free_daily_scans: number;
  provider_mode: string;
  max_image_bytes: number;
}
