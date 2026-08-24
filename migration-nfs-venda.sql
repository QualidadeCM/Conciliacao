-- ============================================================================
-- Migration: rastreabilidade da NF de venda por número de série
-- Data: 21/08/2026 — Maria Luiza
--
-- Contexto: antes do sistema, as pastas eram renomeadas com o número da NF de
-- venda para dar rastreabilidade série → nota. Isso se perdeu. As NFs de venda
-- ficam todas numa pasta de rede e trazem o número de série no corpo do DANFE
-- (ex.: "STB0001 · CM-STATION · CMST-20266-6").
--
-- Esta migration cria a tabela que guarda o vínculo. O serviço local
-- (conversor-pdf-local) varre a pasta uma vez por mês, extrai os dados de cada
-- NF e faz upsert aqui. A ligação com a análise é pelo numero_serie.
--
-- Uma linha por par (NF, número de série) — uma NF pode faturar mais de um
-- equipamento, e cada equipamento tem sua própria série.
-- ============================================================================

create table if not exists public.nfs_venda (
  id uuid primary key default gen_random_uuid(),

  -- Identificação da nota
  numero_nf        text not null,          -- ex.: '28033'
  -- serie_nf faz parte da chave de deduplicação. O ON CONFLICT do Postgres só
  -- reconhece índice único sobre COLUNAS (não sobre expressão), por isso a
  -- coluna não pode ser nula — usa string vazia quando a nota não traz série.
  serie_nf         text not null default '', -- ex.: '1'
  chave_acesso     text,                   -- 44 dígitos da NF-e (quando legível)
  data_emissao     date,
  natureza         text,                   -- ex.: 'Venda de Producao do Estabelecimento'
  cfops            text,                   -- CFOPs encontrados, separados por vírgula
  cliente_nome     text,
  cliente_cnpj     text,
  valor_total      numeric,

  -- Item / equipamento
  numero_serie     text not null,          -- ex.: 'CMST-20266-6'
  codigo_produto   text,                   -- ex.: 'STB0001'
  modelo           text,                   -- ex.: 'CM-STATION'

  -- Origem do dado
  arquivo_nome     text,
  arquivo_path     text,
  arquivo_mtime    timestamptz,            -- data de modificação do PDF na rede

  -- Situação do vínculo com a análise (resolvido na leitura, não é FK rígida
  -- porque a análise pode ser refeita/substituída e o vínculo é pela série)
  tem_analise      boolean not null default false,

  detectada_em     timestamptz not null default now(),
  detectada_por    text default 'varredura_automatica'
);

-- Correção 21/08/2026: a versão anterior desta migration criava o índice sobre
-- a EXPRESSÃO coalesce(serie_nf, ''), e o ON CONFLICT do Postgres não casa com
-- índice de expressão ("there is no unique or exclusion constraint matching the
-- ON CONFLICT specification"). Agora serie_nf é NOT NULL DEFAULT '' e o índice
-- é sobre colunas. Estes comandos são seguros de rodar novamente.
update public.nfs_venda set serie_nf = '' where serie_nf is null;
alter table public.nfs_venda alter column serie_nf set default '';
alter table public.nfs_venda alter column serie_nf set not null;
drop index if exists uniq_nfs_venda_nf_serie;

-- Uma linha por (NF, série). Reprocessar a mesma pasta é idempotente.
create unique index if not exists uniq_nfs_venda_nf_serie
  on public.nfs_venda (numero_nf, serie_nf, numero_serie);

-- Decisão de 24/08/2026: passam a valer TODAS as notas de saída, não só venda.
-- Demonstração, comodato, consignação e empréstimo também tiram o equipamento
-- da fábrica. Esta coluna guarda a distinção ('venda' | 'outra_saida') para a
-- tela poder mostrar de que tipo de saída se trata.
alter table public.nfs_venda
  add column if not exists tipo_movimento text not null default 'venda';

create index if not exists idx_nfs_venda_serie   on public.nfs_venda (numero_serie);
create index if not exists idx_nfs_venda_tipomov on public.nfs_venda (tipo_movimento);
create index if not exists idx_nfs_venda_emissao on public.nfs_venda (data_emissao);
create index if not exists idx_nfs_venda_semanal on public.nfs_venda (tem_analise);

alter table public.nfs_venda enable row level security;
do $$ begin
  create policy "auth_all_nfs_venda" on public.nfs_venda for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;

-- Permite ao serviço local (service role) gravar sem sessão de usuário.
do $$ begin
  create policy "service_all_nfs_venda" on public.nfs_venda for all to service_role using (true) with check (true);
exception when duplicate_object then null; end $$;

-- ----------------------------------------------------------------------------
-- Arquivos que não puderam ser lidos (PDF escaneado/sem texto, corrompido,
-- sem número de série reconhecível). Ficam registrados para não desaparecerem
-- silenciosamente da varredura.
-- ----------------------------------------------------------------------------
create table if not exists public.nfs_venda_falhas (
  id uuid primary key default gen_random_uuid(),
  arquivo_nome  text not null,
  arquivo_path  text,
  arquivo_mtime timestamptz,
  motivo        text not null,   -- 'sem_texto' | 'sem_serie' | 'nao_venda' | 'erro_leitura'
  detalhe       text,
  detectada_em  timestamptz not null default now()
);

create unique index if not exists uniq_nfs_venda_falhas_arquivo
  on public.nfs_venda_falhas (arquivo_path);

alter table public.nfs_venda_falhas enable row level security;
do $$ begin
  create policy "auth_all_nfs_venda_falhas" on public.nfs_venda_falhas for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "service_all_nfs_venda_falhas" on public.nfs_venda_falhas for all to service_role using (true) with check (true);
exception when duplicate_object then null; end $$;

-- ----------------------------------------------------------------------------
-- Configuração da varredura (usa a tabela config_app já existente)
--   nf_pasta_rede       → caminho UNC da pasta onde ficam as NFs de venda
--   nf_ultima_varredura → timestamp ISO da última varredura concluída
--   nf_ultimo_resumo    → JSON com o resumo da última varredura (para a tela)
--   nf_dia_mes / nf_hora → quando a varredura automática roda (default: dia 1º, 06h)
-- ----------------------------------------------------------------------------
insert into public.config_app (chave, valor, updated_by)
values
  ('nf_pasta_rede',       '',  'migration-nfs-venda'),
  ('nf_ultima_varredura', '',  'migration-nfs-venda'),
  ('nf_ultimo_resumo',    '',  'migration-nfs-venda'),
  ('nf_dia_mes',          '1', 'migration-nfs-venda'),
  ('nf_hora',             '6', 'migration-nfs-venda'),
  -- Ano mínimo: descarta pastas de anos anteriores ao início da plataforma.
  -- Todo equipamento analisado foi fabricado a partir de 2026, então notas de
  -- 2025 para trás não têm série que casaria com alguma análise.
  ('nf_ano_minimo',       '2026', 'migration-nfs-venda')
on conflict (chave) do nothing;
