/**
 * Shared backend types and DTOs.
 * Keep domain-heavy types in respective services; use this for API boundaries and shared primitives.
 */

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type Timestamp = string; // ISO 8601

export interface ApiResult<T> {
  data?: T;
  error?: { code: string; message: string };
}

export interface PaginatedResult<T> {
  data: T[];
  total: number;
  page: number;
  pageSize: number;
}
