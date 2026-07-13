-- =====================================================================
-- Plataforma de Conciliação da Produção - Confiance Medical
-- Schema do Supabase (Postgres)
-- Versão: 1.0 (Fase 1 - Fundação)
-- =====================================================================
-- Execute este script no SQL Editor do Supabase Studio na ordem em que está.
-- Idempotente: pode rodar várias vezes sem quebrar nada existente.

-- ============================
-- 1. Extensões
-- ============================
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ============================
-- 2. Enums
-- ============================
do $$ begin
  create type analise_status as enum ('em_andamento', 'conforme', 'ressalva', 'nao_conforme');
exception when duplicate_object then null; end $$;

do $$ begin
  create type tipo_documento as enum (
    'op',
    'rc',
    'form_gq_0047',
    'etiqueta_externa',
    'etiqueta_acessorio',
    'op_reprocesso',
    'rnc'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type tipo_controle as enum ('serie', 'lote');
exception when duplicate_object then null; end $$;

do $$ begin
  create type marcacao_form as enum ('SIM', 'NAO', 'N/A');
exception when duplicate_object then null; end $$;

do $$ begin
  create type severidade_apontamento as enum ('conforme', 'ressalva', 'nao_conforme');
exception when duplicate_object then null; end $$;

-- ============================
-- 3. Catálogo de Produtos (FORM-GQ-0085)
-- ============================
create table if not exists public.produtos (
  id uuid primary key default uuid_generate_v4(),
  equipamento text not null,                    -- ex.: "FONTE DE LUZ LED"
  modelo text not null unique,                  -- ex.: "CM-LED"
  codigo_referencia text not null,              -- prefixo do nº de série; ex.: "LEDT"
  registro_anvisa text not null,                -- ex.: "80337650008"
  codigo_sapiens text,                          -- ex.: "FNT0001"
  derivacao text,                               -- ex.: "001"
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_produtos_modelo on public.produtos(modelo);
create index if not exists idx_produtos_codigo_referencia on public.produtos(codigo_referencia);

-- ============================
-- 4. Fichas Mestres dos produtos
-- ============================
create table if not exists public.fichas_mestres (
  id uuid primary key default uuid_generate_v4(),
  produto_id uuid not null references public.produtos(id) on delete cascade,
  versao int not null default 1,                -- versionamento p/ auditoria ISO 13485
  ativa boolean not null default true,          -- apenas 1 ficha ativa por produto

  -- Seção 1 - Identificação do produto (espelha estrutura da Ficha CM-LED)
  familia text,
  nome_comercial text,                          -- "Fonte de Luz LED"
  convencao_nro_serie text,                     -- "LEDT-AAAAMM-N"
  exemplo_nro_serie text,
  aplicacao_clinica text,
  data_concessao_anvisa text,
  aplicabilidade_udi text,
  inmetro_aplicavel boolean default false,
  inmetro_observacao text,

  -- Seção 2 - Fabricante e Responsáveis
  razao_social text default 'Confiance Medical Produtos Médicos S.A.',
  cnpj text default '05.209.279/0001-31',
  endereco_fabrica text default 'Rua Bela, 852, São Cristóvão, Rio de Janeiro – RJ – CEP: 20930-380',
  telefone text default '(21) 3293-1650',
  responsavel_tecnico text default 'Samara Campos',
  crea_rt text default '2019108911',
  responsavel_legal text default 'Cristiano Mendes Brega',

  -- Seção 3 - Etiqueta Externa padrão (campos esperados em formato JSON)
  etiqueta_externa_campos jsonb default '{}'::jsonb,

  -- Seção 8 - Regras específicas e seção 9 - Regras de Negócio (livre)
  regras_negocio jsonb default '[]'::jsonb,
  observacoes text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);

create unique index if not exists uniq_ficha_ativa_por_produto
  on public.fichas_mestres(produto_id) where ativa = true;

create index if not exists idx_fichas_produto on public.fichas_mestres(produto_id);

-- ============================
-- 5. Acessórios aplicáveis ao modelo (Ficha Mestre seção 4)
-- ============================
create table if not exists public.acessorios_aplicaveis (
  id uuid primary key default uuid_generate_v4(),
  ficha_id uuid not null references public.fichas_mestres(id) on delete cascade,
  ordem int not null default 1,
  descricao text not null,                      -- "Cabo de Força Padrão Brasil — 1,8 m"
  codigo_sapiens text not null,                 -- "CBR0038"
  obrigatorio boolean not null default true,
  is_fabricante_confiance boolean not null,     -- true = Confiance é Fabricante; false = Fornecedor
  esteril boolean not null default false,
  observacao text
);

create index if not exists idx_acessorios_ficha on public.acessorios_aplicaveis(ficha_id);

-- ============================
-- 6. Roteiro / mapeamento para FORM-GQ-0047 (Ficha Mestre seção 5)
-- ============================
create table if not exists public.roteiro_form_gq_0047 (
  id uuid primary key default uuid_generate_v4(),
  ficha_id uuid not null references public.fichas_mestres(id) on delete cascade,
  ordem int not null,
  item_checklist text not null,                 -- "Separação de Componentes (Estágio 5)"
  marcacao_esperada marcacao_form not null,
  justificativa text
);

create index if not exists idx_roteiro_ficha on public.roteiro_form_gq_0047(ficha_id, ordem);

-- ============================
-- 7. Inspeções e critérios de aceitação por estágio (Ficha seção 6)
-- ============================
create table if not exists public.inspecoes_criterios (
  id uuid primary key default uuid_generate_v4(),
  ficha_id uuid not null references public.fichas_mestres(id) on delete cascade,
  estagio_codigo text not null,                 -- "20", "30", "40-Finalização", "40-CQFinal", etc.
  estagio_nome text not null,
  criterio_aceitacao text not null
);

create index if not exists idx_inspecoes_ficha on public.inspecoes_criterios(ficha_id);

-- ============================
-- 8. BOM aprovada (Ficha seção 7)
-- ============================
create table if not exists public.componentes_bom (
  id uuid primary key default uuid_generate_v4(),
  ficha_id uuid not null references public.fichas_mestres(id) on delete cascade,
  codigo_sapiens text not null,                 -- "ACE0005"
  descricao text not null,                      -- "Módulo de LED (interno)"
  tipo_controle tipo_controle not null,         -- serie | lote
  prefixo_serie text,                           -- "MLED-AAAAMM-N" se serie
  quantidade int not null default 1,
  critico boolean not null default false,
  observacao text
);

create index if not exists idx_bom_ficha on public.componentes_bom(ficha_id);
create index if not exists idx_bom_codigo on public.componentes_bom(codigo_sapiens);

-- ============================
-- 9. Análises (cabeçalho)
-- ============================
create table if not exists public.analises (
  id uuid primary key default uuid_generate_v4(),
  produto_id uuid references public.produtos(id),
  ficha_id uuid references public.fichas_mestres(id),

  numero_op text,                               -- "6819"
  numero_serie text,                            -- "LEDT-20261-6"
  nome_produto text,                            -- "Fonte de Luz LED"
  modelo text,                                  -- "CM-LED"
  registro_anvisa text,

  status analise_status not null default 'em_andamento',
  parecer_resumo text,                          -- texto curto exibido na tela
  parecer_completo jsonb,                       -- relatório completo em JSON estruturado

  iniciada_em timestamptz not null default now(),
  finalizada_em timestamptz,
  tempo_execucao_ms int,

  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create index if not exists idx_analises_status on public.analises(status);
create index if not exists idx_analises_produto on public.analises(produto_id);
create index if not exists idx_analises_created on public.analises(created_at desc);
create index if not exists idx_analises_op on public.analises(numero_op);

-- ============================
-- 10. Documentos da análise (upload)
-- ============================
create table if not exists public.documentos_analise (
  id uuid primary key default uuid_generate_v4(),
  analise_id uuid not null references public.analises(id) on delete cascade,
  tipo tipo_documento not null,
  nome_arquivo text not null,
  storage_path text not null,                   -- caminho no Supabase Storage
  tamanho_bytes bigint,
  texto_extraido text,                          -- conteúdo extraído (pdf-parse/mammoth)
  created_at timestamptz not null default now()
);

create index if not exists idx_documentos_analise on public.documentos_analise(analise_id);

-- ============================
-- 11. Apontamentos (achados do agente — NC e ressalvas)
-- ============================
create table if not exists public.apontamentos (
  id uuid primary key default uuid_generate_v4(),
  analise_id uuid not null references public.analises(id) on delete cascade,
  ordem int not null default 1,
  codigo text,                                  -- "NC-01", "R-01"
  severidade severidade_apontamento not null,
  camada int not null,                          -- 1, 2 ou 3
  documento_afetado text,
  referencia_normativa text,
  descricao text not null,
  recomendacao text
);

create index if not exists idx_apontamentos_analise on public.apontamentos(analise_id, ordem);

-- ============================
-- 12. Trigger de updated_at
-- ============================
create or replace function public.tg_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_updated_at on public.produtos;
create trigger set_updated_at before update on public.produtos
  for each row execute function public.tg_set_updated_at();

drop trigger if exists set_updated_at on public.fichas_mestres;
create trigger set_updated_at before update on public.fichas_mestres
  for each row execute function public.tg_set_updated_at();

-- ============================
-- 13. Storage Buckets
-- ============================
-- Bucket para os documentos enviados na análise. Privado.
insert into storage.buckets (id, name, public)
values ('documentos-analise', 'documentos-analise', false)
on conflict (id) do nothing;

-- Bucket para PDFs dos relatórios gerados. Privado.
insert into storage.buckets (id, name, public)
values ('relatorios', 'relatorios', false)
on conflict (id) do nothing;

-- ============================
-- 14. Row Level Security
-- ============================
-- Política inicial: qualquer usuário autenticado pode tudo.
-- Quando criarmos múltiplos perfis, refinamos por role.

alter table public.produtos enable row level security;
alter table public.fichas_mestres enable row level security;
alter table public.acessorios_aplicaveis enable row level security;
alter table public.roteiro_form_gq_0047 enable row level security;
alter table public.inspecoes_criterios enable row level security;
alter table public.componentes_bom enable row level security;
alter table public.analises enable row level security;
alter table public.documentos_analise enable row level security;
alter table public.apontamentos enable row level security;

do $$ begin
  -- Produtos
  create policy "auth_all_produtos" on public.produtos
    for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "auth_all_fichas" on public.fichas_mestres
    for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "auth_all_acessorios" on public.acessorios_aplicaveis
    for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "auth_all_roteiro" on public.roteiro_form_gq_0047
    for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "auth_all_inspecoes" on public.inspecoes_criterios
    for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "auth_all_bom" on public.componentes_bom
    for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "auth_all_analises" on public.analises
    for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "auth_all_documentos" on public.documentos_analise
    for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "auth_all_apontamentos" on public.apontamentos
    for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;

-- Storage RLS: usuários autenticados podem ler/escrever nos buckets
do $$ begin
  create policy "auth_read_documentos" on storage.objects
    for select to authenticated using (bucket_id in ('documentos-analise', 'relatorios'));
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "auth_write_documentos" on storage.objects
    for insert to authenticated with check (bucket_id in ('documentos-analise', 'relatorios'));
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "auth_delete_documentos" on storage.objects
    for delete to authenticated using (bucket_id in ('documentos-analise', 'relatorios'));
exception when duplicate_object then null; end $$;

-- ============================
-- 15. View de dashboard
-- ============================
create or replace view public.v_dashboard_stats as
select
  count(*) filter (where status = 'conforme')        as total_conforme,
  count(*) filter (where status = 'ressalva')        as total_ressalva,
  count(*) filter (where status = 'nao_conforme')    as total_nao_conforme,
  count(*) filter (where status = 'em_andamento')    as total_em_andamento,
  count(*)                                            as total_analises,
  avg(tempo_execucao_ms) filter (where tempo_execucao_ms is not null) as tempo_medio_ms
from public.analises;
