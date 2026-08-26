-- ============================================================================
-- Migration: tempos esperados por estágio, configuráveis por equipamento
-- Data: 24/08/2026 — Maria Luiza
--
-- Antes: a checagem de tempo estava FIXA no código, só para os Estágios 5 e 50,
-- com médias embutidas (endoscópio rígido 7/5 min, demais 25/17 min) e
-- tolerância fixa de 50%. Qualquer ajuste exigia mexer no plataforma.html.
--
-- Agora: o setor configura pela tela (Cadastro → Tempos de estágio), por
-- EQUIPAMENTO (a família, valendo para todos os modelos e derivações) e por
-- estágio, podendo ligar/desligar cada checagem.
--
-- Faixa aceita:
--     teto = media_min * (1 + tolerancia_pct/100) + margem_min
--     piso = media_min * (1 - tolerancia_pct/100) - margem_min   (nunca < 0)
--
-- A tolerância cuida da variação proporcional; a margem absorve arredondamento
-- de apontamento em estágios curtos (num estágio de 5 min, 100% já é ±5 min).
--
-- Sem linha ATIVA para o par (equipamento, estágio), o agente NÃO avalia o
-- tempo daquele estágio. Decisão de 24/08/2026: melhor não apontar do que
-- apontar contra um número que ninguém validou.
-- ============================================================================

create table if not exists public.tempos_estagio (
  id uuid primary key default gen_random_uuid(),

  -- Família do equipamento, como está em produtos.equipamento
  -- (ex.: 'ENDOSCÓPIO RÍGIDO PARA LAPAROSCOPIA'). Vale para todos os modelos
  -- e derivações dessa família.
  equipamento     text not null,
  estagio_numero  integer not null,

  media_min       numeric not null check (media_min > 0),
  tolerancia_pct  numeric not null default 100 check (tolerancia_pct >= 0),
  margem_min      numeric not null default 0   check (margem_min >= 0),
  ativo           boolean not null default true,

  observacao      text,
  updated_at      timestamptz not null default now(),
  updated_by      text
);

create unique index if not exists uniq_tempos_estagio_equip_estagio
  on public.tempos_estagio (equipamento, estagio_numero);

create index if not exists idx_tempos_estagio_ativo
  on public.tempos_estagio (ativo);

alter table public.tempos_estagio enable row level security;
do $$ begin
  create policy "auth_all_tempos_estagio" on public.tempos_estagio for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "service_all_tempos_estagio" on public.tempos_estagio for all to service_role using (true) with check (true);
exception when duplicate_object then null; end $$;

-- ----------------------------------------------------------------------------
-- Seed: reproduz o comportamento que estava no código, para nenhuma checagem
-- existente se perder — já com a tolerância de 100% decidida com o setor.
--
--   Endoscópios rígidos ....... Estágio 5 = 7 min · Estágio 50 = 5 min
--   Demais equipamentos ....... Estágio 5 = 25 min · Estágio 50 = 17 min
--
-- ATENÇÃO: a auditoria de jul/ago de 2026 mostrou que a média de 7 min para o
-- Estágio 5 dos endoscópios rígidos está muito distante da realidade (mediana
-- observada perto de 20 min). Revise os valores na tela usando a coluna de
-- média observada antes de considerar a checagem calibrada.
-- ----------------------------------------------------------------------------
insert into public.tempos_estagio (equipamento, estagio_numero, media_min, tolerancia_pct, margem_min, ativo, observacao, updated_by)
select p.equipamento,
       e.estagio_numero,
       case when p.equipamento ilike '%ENDOSC%RIGIDO%' or p.equipamento ilike '%ENDOSCÓPIO RÍGIDO%'
            then case e.estagio_numero when 5 then 7 else 5 end
            else case e.estagio_numero when 5 then 25 else 17 end
       end as media_min,
       100 as tolerancia_pct,
       0   as margem_min,
       true as ativo,
       'Semeado da regra que estava fixa no código (24/08/2026) — revisar com a média observada' as observacao,
       'migration-tempos-estagio' as updated_by
  from (select distinct equipamento from public.produtos where equipamento is not null and equipamento <> '') p
 cross join (values (5), (50)) as e(estagio_numero)
on conflict (equipamento, estagio_numero) do nothing;

-- Conferência sugerida depois de rodar:
-- select equipamento, estagio_numero, media_min, tolerancia_pct, margem_min, ativo
--   from tempos_estagio order by equipamento, estagio_numero;
