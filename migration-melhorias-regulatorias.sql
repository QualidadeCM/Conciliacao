-- ============================================================================
-- Migration: MELHORIAS REGULATÓRIAS (sugestões proativas de melhoria)
-- Data: 2026-07-22
--
-- As análises geram sugestões de melhoria regulatória (códigos M-01, M-02…).
-- Antes eram exibidas apenas no parecer de cada análise. Agora são migradas
-- para uma lista consolidada no Dashboard, onde a Qualidade decide se cada
-- melhoria será ACATADA ou NÃO ACATADA.
--
-- Regras de negócio:
--  - Deduplicação GLOBAL por `codigo`: uma vez identificada a M-01, ela não
--    volta a ser cadastrada, independentemente do produto/OP.
--  - A captura na análise faz INSERT apenas de códigos novos (ON CONFLICT DO
--    NOTHING) — nunca sobrescreve um item já decidido.
--  - Decisão (acatada/nao_acatada) ENCERRA o item: ele sai da lista de
--    pendentes e não reaparece, mesmo se detectado de novo em análises futuras.
-- ============================================================================

create table if not exists public.melhorias_regulatorias (
  id                    uuid primary key default gen_random_uuid(),
  codigo                text not null unique,          -- M-01, M-02… (chave de dedup global)
  titulo                text not null,
  norma                 text,
  descricao             text,                          -- fundamentação normativa
  evidencia             text,                          -- evidência da 1ª detecção
  acao_sugerida         text,
  status                text not null default 'pendente',  -- pendente | acatada | nao_acatada
  primeira_analise_id   uuid,                          -- análise onde foi detectada 1ª vez
  primeira_op           text,                          -- OP onde foi detectada 1ª vez
  decidido_por          text,                          -- quem decidiu (nome/email)
  decidido_em           timestamptz,
  observacao_decisao    text,                          -- nota opcional da decisão
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create index if not exists idx_melhorias_status on public.melhorias_regulatorias (status);

-- RLS permissiva para usuários autenticados (mesmo padrão das demais tabelas)
alter table public.melhorias_regulatorias enable row level security;
drop policy if exists melhorias_regulatorias_all on public.melhorias_regulatorias;
create policy melhorias_regulatorias_all on public.melhorias_regulatorias
  for all to authenticated using (true) with check (true);

-- Realtime (a lista reflete capturas/decisões feitas por outro usuário)
alter publication supabase_realtime add table public.melhorias_regulatorias;
