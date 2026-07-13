-- ============================================================
-- Migration: Configuração compartilhada da aplicação
-- Data: 09/07/2026 — Maria Luiza
-- Objetivo:
--   Guardar configurações que valem para TODOS os usuários (não por navegador),
--   como a PASTA DE DESTINO do pacote. Antes ficava só no localStorage de cada
--   máquina — por isso cada usuário teria que configurar. Agora é central:
--   o admin define uma vez e todos usam a mesma pasta.
-- ============================================================

create table if not exists public.config_app (
  chave text primary key,          -- ex.: 'pasta_destino', 'pasta_por_mes'
  valor text,
  updated_at timestamptz not null default now(),
  updated_by text
);

alter table public.config_app enable row level security;
do $$ begin
  create policy "auth_all_config_app" on public.config_app for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;
