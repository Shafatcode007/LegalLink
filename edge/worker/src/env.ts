export interface Bindings {
  AI_PROVIDER?: 'local' | 'huggingface';
  HF_API_KEY?: string;
  LOCAL_LLM_URL?: string;
  SUPABASE_URL?: string;
  /** Optional static JWKS JSON; defaults to `${SUPABASE_URL}/auth/v1/.well-known/jwks.json`. */
  SUPABASE_JWKS?: string;
  RATE_LIMIT?: KVNamespace;
}
