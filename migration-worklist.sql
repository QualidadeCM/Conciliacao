-- ============================================================
-- Migration: Worklist de OPs finalizadas pendentes de análise
-- Data: 10/07/2026 — Maria Luiza
-- Objetivo:
--   Guardar a lista de OPs importadas do Sapiens (pendentes de análise) de forma
--   PERSISTENTE (sobrevive a F5 / troca de máquina). É uma fila compartilhada da GQ.
--   Regra de saída: a OP deixa a lista quando é (re)analisada DEPOIS de ter entrado
--   (existe uma análise com created_at > added_at) — ou quando removida manualmente.
--   'added_at' registra quando a OP entrou na lista, permitindo distinguir a análise
--   antiga (que não conta) da reanálise nova (que remove da fila).
-- ============================================================

create table if not exists public.worklist_ops (
  op text primary key,                 -- número da OP (só dígitos), ex.: '7548'
  added_at timestamptz not null default now(),
  added_by text
);
create index if not exists idx_worklist_added on public.worklist_ops(added_at);

alter table public.worklist_ops enable row level security;
do $$ begin
  create policy "auth_all_worklist_ops" on public.worklist_ops for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;
