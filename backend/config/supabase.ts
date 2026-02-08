/**
 * Supabase client configuration.
 * Use createClient from @supabase/supabase-js in app; this module holds URL/key resolution.
 */

export type SupabaseConfig = {
  url: string;
  anonKey: string;
  serviceRoleKey?: string;
};

/**
 * Resolve Supabase config from environment.
 * Prefer SUPABASE_URL / SUPABASE_ANON_KEY (Vercel/Netlify) or NEXT_PUBLIC_* for client.
 */
export function getSupabaseConfig(): SupabaseConfig {
  const url =
    process.env.SUPABASE_URL ??
    process.env.NEXT_PUBLIC_SUPABASE_URL ??
    '';
  const anonKey =
    process.env.SUPABASE_ANON_KEY ??
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??
    '';
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY ?? undefined;

  if (!url || !anonKey) {
    throw new Error(
      'Missing Supabase config: set SUPABASE_URL and SUPABASE_ANON_KEY (or NEXT_PUBLIC_* equivalents).'
    );
  }

  return { url, anonKey, serviceRoleKey };
}
