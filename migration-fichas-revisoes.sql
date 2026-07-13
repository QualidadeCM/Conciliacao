-- ============================================================
-- Migration: Revisões (versionamento) das Fichas Mestres
-- Data: 08/07/2026 — Maria Luiza
-- Objetivo:
--   Guardar um SNAPSHOT completo da ficha a cada salvamento, permitindo
--   consultar o histórico e REVERTER para uma versão obsoleta.
--   O snapshot inclui os campos da ficha + acessórios + estágios (JSON).
-- ============================================================

create table if not exists public.fichas_mestres_versoes (
  id uuid primary key default uuid_generate_v4(),
  ficha_id uuid not null references public.fichas_mestres(id) on delete cascade,
  versao int not null,                 -- 1, 2, 3... por ficha
  snapshot jsonb not null,             -- { ficha:{...}, acessorios:[...] }
  motivo text,                         -- ex.: 'Salvamento', 'Revertido para v2'
  criado_por_id uuid,
  criado_por_nome text,
  created_at timestamptz not null default now()
);
create index if not exists idx_fichas_versoes_ficha on public.fichas_mestres_versoes(ficha_id, versao desc);

alter table public.fichas_mestres_versoes enable row level security;
do $$ begin
  create policy "auth_all_fichas_versoes" on public.fichas_mestres_versoes for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;
