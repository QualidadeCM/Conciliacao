-- ============================================================================
-- Migration: acompanhamento das correções enviadas aos setores (06/11/2026)
--
-- Cada vez que uma NC/ressalva é enviada para correção (Slack individual pela
-- tela da análise, ou "Enviar problema em pacote"), grava-se uma linha aqui por
-- lote e setor. A plataforma calcula a partir disso:
--   • aguardando retorno / atrasada / retornou no prazo / retornou atrasada;
--   • prazo: 1 dia útil se o equipamento já tem NF de venda, 3 dias úteis
--     nos demais (sábado e domingo não contam; feriados não são descontados);
--   • retorno = primeira análise do lote feita DEPOIS do envio.
-- Só registra; não altera análises nem apontamentos.
-- ============================================================================

create table if not exists public.correcoes_solicitadas (
  id              uuid primary key default gen_random_uuid(),
  numero_op       text not null,
  numero_serie    text not null default '',
  analise_id      uuid,                   -- análise vigente no momento do envio
  setor           text,                   -- 'PCP' | 'Almoxarifado'
  origem          text,                   -- 'slack_individual' | 'slack_pacote'
  problema        text,                   -- resumo do que foi pedido
  enviado_em      timestamptz not null default now(),
  enviado_por_id  uuid,
  enviado_por     text
);

create index if not exists idx_correcoes_solic_lote on public.correcoes_solicitadas (numero_op, numero_serie);
create index if not exists idx_correcoes_solic_data on public.correcoes_solicitadas (enviado_em desc);

alter table public.correcoes_solicitadas enable row level security;
do $$ begin
  create policy "auth_all_correcoes_solicitadas" on public.correcoes_solicitadas for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "service_all_correcoes_solicitadas" on public.correcoes_solicitadas for all to service_role using (true) with check (true);
exception when duplicate_object then null; end $$;

-- Aproveita o histórico dos envios em pacote que já existiam (uma linha por
-- OP/série/setor/envio). Rodar de novo não duplica.
insert into public.correcoes_solicitadas (numero_op, numero_serie, setor, origem, problema, enviado_em, enviado_por_id, enviado_por)
select e.numero_op, coalesce(e.numero_serie, ''), e.setor, 'slack_pacote', e.problema_label, e.enviado_em, e.enviado_por_id, e.enviado_por
  from public.envios_pacote e
 where not exists (
   select 1 from public.correcoes_solicitadas c
    where c.numero_op = e.numero_op and c.numero_serie = coalesce(e.numero_serie, '')
      and c.enviado_em = e.enviado_em and coalesce(c.setor, '') = coalesce(e.setor, '')
 );

-- Conferência:
-- select numero_op, numero_serie, setor, origem, enviado_em from correcoes_solicitadas order by enviado_em desc limit 30;
