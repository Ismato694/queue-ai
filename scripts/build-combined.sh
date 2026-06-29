#!/usr/bin/env bash
# Regenerate supabase/combined.sql from migrations + seed (audit M7 — single source = migrations).
# Run after adding/editing a migration:  bash scripts/build-combined.sh
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=supabase/combined.sql
{
  echo "-- Queue.ai — GENERATED. Do not edit by hand. Source: supabase/migrations/* + seed.sql"
  echo "-- Regenerate: bash scripts/build-combined.sh"
  echo
  for f in supabase/migrations/0*.sql; do
    echo "-- ════════════════════════════════════════════════════════════"
    echo "-- $f"
    echo "-- ════════════════════════════════════════════════════════════"
    cat "$f"; echo
  done
  echo "-- ════════════════════════════════════════════════════════════"
  echo "-- supabase/seed.sql"
  echo "-- ════════════════════════════════════════════════════════════"
  cat supabase/seed.sql
} > "$OUT"
echo "wrote $OUT ($(wc -l < "$OUT" | tr -d ' ') lines)"
