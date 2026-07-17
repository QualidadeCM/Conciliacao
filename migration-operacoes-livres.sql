-- ============================================================================
-- Migration: OPERAÇÕES LIVRES (exceções da conferência de aptidão)
-- Data: 2026-07-16
--
-- Algumas operações dentro de um estágio podem ser executadas por colaboradores
-- que não estão aptos ao estágio como um todo (operações flexíveis / de apoio).
-- Esta tabela registra essas exceções POR EQUIPAMENTO/FAMÍLIA:
--   equipamento + estágio + operação (número/descrição) = "operação livre".
--
-- Efeito na análise: para uma operação marcada como livre, a conferência NÃO
-- exige aptidão do estágio (qualquer colaborador ATIVO pode executá-la). A regra
-- de "colaborador precisa estar cadastrado" continua valendo (não cadastrado =
-- ressalva).
-- ============================================================================

create table if not exists public.operacoes_livres (
  id               uuid primary key default gen_random_uuid(),
  equipamento      text not null,                 -- família/equipamento (produtos.equipamento)
  estagio          int  not null,                 -- número do estágio (ex.: 7, 20)
  operacao_numero  text,                          -- número da operação no estágio (ex.: "20")
  operacao_desc    text,                          -- descrição (referência e casamento secundário)
  ativo            boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  updated_by       text
);

create index if not exists idx_oplivres_equip on public.operacoes_livres (lower(equipamento));

alter table public.operacoes_livres enable row level security;
drop policy if exists operacoes_livres_all on public.operacoes_livres;
create policy operacoes_livres_all on public.operacoes_livres
  for all to authenticated using (true) with check (true);

alter publication supabase_realtime add table public.operacoes_livres;
