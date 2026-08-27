-- ============================================================================
-- Migration: registro dos apontamentos enviados em pacote ao Slack
-- Data: 27/08/2026 — Maria Luiza
--
-- Antes: o envio em pacote só deixava rastro em logs_atividade (texto livre).
-- Não havia como saber, ao abrir o modal de novo, quais OPs já tinham sido
-- cobradas por aquele mesmo problema — o risco era reenviar a mesma cobrança.
--
-- Agora: cada OP enviada grava uma linha aqui, amarrada à CHAVE DO PROBLEMA
-- (a mesma chave de agrupamento usada no modal). Ao reabrir, o modal marca as
-- OPs já cobradas e deixa desmarcadas por padrão — a decisão de reenviar passa
-- a ser explícita.
--
-- Só registra; não altera apontamento nem status da análise.
-- ============================================================================

create table if not exists public.envios_pacote (
  id uuid primary key default gen_random_uuid(),

  -- Chave de agrupamento do problema, gerada pelo modal (ex.: 'TEMPO|5|acima|0–14 min (média 7 min...)'
  -- ou 'ressalva|OP :: descrição normalizada'). Igual chave = mesma cobrança.
  problema_chave  text not null,
  problema_label  text,            -- rótulo legível, para consulta/auditoria
  severidade      text,
  setor           text,            -- 'Almoxarifado' | 'PCP'
  canal           text,            -- canal do Slack usado

  numero_op       text not null,
  numero_serie    text not null default '',
  operador_nome   text,

  enviado_em      timestamptz not null default now(),
  enviado_por_id  uuid,
  enviado_por     text
);

-- Consulta principal do modal: por problema, e por OP.
create index if not exists idx_envios_pacote_problema on public.envios_pacote (problema_chave);
create index if not exists idx_envios_pacote_op       on public.envios_pacote (numero_op);
create index if not exists idx_envios_pacote_data     on public.envios_pacote (enviado_em desc);

alter table public.envios_pacote enable row level security;
do $$ begin
  create policy "auth_all_envios_pacote" on public.envios_pacote for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "service_all_envios_pacote" on public.envios_pacote for all to service_role using (true) with check (true);
exception when duplicate_object then null; end $$;

-- Conferência sugerida depois de rodar:
-- select numero_op, numero_serie, problema_label, setor, enviado_em, enviado_por
--   from envios_pacote order by enviado_em desc limit 50;
