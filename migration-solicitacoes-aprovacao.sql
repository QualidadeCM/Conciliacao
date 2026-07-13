-- ============================================================
-- Migration: Solicitações de aprovação (INTERINO)
-- Data: 08/07/2026 — Maria Luiza
-- Objetivo:
--   Permitir que um usuário sem determinada permissão SOLICITE a uma
--   pessoa que tenha a permissão. Ao aprovar:
--     · modo 'executar'    → o próprio sistema executa a ação (ex.: excluir análise);
--     · modo 'desbloquear' → libera a ação para o solicitante fazer (ações interativas).
--   O log registra "Fulano fez X com permissão de Ciclana".
-- ============================================================

create table if not exists public.solicitacoes (
  id uuid primary key default uuid_generate_v4(),
  acao text not null,                 -- id da ação (ex.: 'excluir_analise', 'refazer_analise')
  perm_key text not null,             -- permissão exigida (ex.: 'historico_excluir')
  modo text not null default 'executar',   -- 'executar' | 'desbloquear'
  entidade text,                      -- ex.: 'analise', 'ficha'
  entidade_ref text,                  -- ex.: 'OP 7545 / CMST-20266-10'
  payload jsonb not null default '{}'::jsonb,  -- dados p/ executar (ex.: { analise_id })

  solicitante_id uuid,
  solicitante_nome text,
  solicitante_email text,
  aprovador_sugerido_id uuid,
  aprovador_sugerido_nome text,
  motivo_solicitacao text,

  status text not null default 'pendente',  -- pendente | aprovada | recusada | executada | usada | cancelada
  aprovador_id uuid,
  aprovador_nome text,
  motivo_decisao text,

  created_at timestamptz not null default now(),
  decided_at timestamptz,
  used_at timestamptz
);
create index if not exists idx_solic_status on public.solicitacoes(status);
create index if not exists idx_solic_solicitante on public.solicitacoes(solicitante_id);
create index if not exists idx_solic_permkey on public.solicitacoes(perm_key);

alter table public.solicitacoes enable row level security;
do $$ begin
  create policy "auth_all_solicitacoes" on public.solicitacoes for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;
