-- ============================================================================
-- Migration: cadastro de OPERADORES por estágio (lista global de colaboradores)
-- Data: 2026-07-15
--
-- Objetivo: registrar quais colaboradores estão autorizados a executar cada
-- estágio da OP. Base para a nova conferência "operador autorizado no estágio".
--
-- Regras de negócio:
--  - Lista GLOBAL (vale para todos os produtos).
--  - Admissão  = inserir (ativo = true).
--  - Demissão  = marcar ativo = false (NÃO apagar) — preserva a validade das
--    OPs já produzidas quando o colaborador ainda estava autorizado.
--  - `codigo`   = matrícula / operador_id do Sapiens (casa as OPERAÇÕES da OP).
--  - `apelidos` = variações do nome (casa as INSPEÇÕES, que só trazem nome).
--  - `estagios` = números dos estágios autorizados (ex.: [10, 30, 60]).
-- ============================================================================

create table if not exists public.operadores (
  id          uuid primary key default gen_random_uuid(),
  nome        text not null,
  codigo      text,                                   -- matrícula / operador_id do Sapiens
  apelidos    jsonb not null default '[]'::jsonb,     -- variações de nome para casar inspetor
  estagios    jsonb not null default '[]'::jsonb,     -- números de estágio autorizados
  ativo       boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  updated_by  text
);

-- Índice para busca por nome (case-insensitive) no casamento com a OP
create index if not exists idx_operadores_nome on public.operadores (lower(nome));
create index if not exists idx_operadores_codigo on public.operadores (codigo);

-- RLS permissiva para usuários autenticados (mesmo padrão das demais tabelas)
alter table public.operadores enable row level security;
drop policy if exists operadores_all on public.operadores;
create policy operadores_all on public.operadores
  for all to authenticated using (true) with check (true);

-- Realtime (a tela reflete cadastros/alterações feitos por outro admin)
alter publication supabase_realtime add table public.operadores;
