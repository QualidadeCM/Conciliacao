-- ============================================================
-- Migration: Usuários, Permissões e Logs de Atividade (INTERINO)
-- Data: 08/07/2026 — Maria Luiza
-- Objetivo:
--   Gestão de usuários/cargos/permissões enquanto NÃO migramos para o SCM.
--   Autenticação é feita pelo Supabase Auth (senha/hash/e-mail ficam com o
--   Supabase — não guardamos senha). Aqui só ficam PERFIL, CONVITE e LOGS.
--
--   NOTA P&D / SCM: ao migrar, a identidade passa a vir do SCM. As tabelas
--   'perfis' e 'convites' serão substituídas pela gestão do SCM; a tabela
--   'logs_atividade' é reaproveitada (guarda nome/e-mail do autor).
-- ============================================================

-- 1) Perfil do usuário (1:1 com auth.users)
create table if not exists public.perfis (
  id uuid primary key references auth.users(id) on delete cascade,
  nome_completo text,
  email text,
  cargo text,                                   -- estagiario_gq | assistente_gq | analista_gq | responsavel_qualidade | responsavel_producao | admin
  permissoes jsonb not null default '{}'::jsonb, -- { "historico_excluir": true, ... }
  ativo boolean not null default true,
  convidado_por text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2) Convites (pré-autorização de e-mail + cargo + permissões)
create table if not exists public.convites (
  id uuid primary key default uuid_generate_v4(),
  email text not null,
  cargo text,
  permissoes jsonb not null default '{}'::jsonb,
  status text not null default 'pendente',       -- pendente | aceito | cancelado
  convidado_por text,
  created_at timestamptz not null default now(),
  aceito_em timestamptz
);
create index if not exists idx_convites_email on public.convites(lower(email));

-- 3) Logs de atividade
create table if not exists public.logs_atividade (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  user_nome text,
  user_email text,
  acao text not null,            -- ex.: 'excluir_analise', 'baixar_pacote', 'convidar_usuario'
  entidade text,                 -- ex.: 'analise', 'ficha', 'usuario', 'config'
  entidade_ref text,             -- ex.: 'OP 7545 / CMST-20266-10'
  descricao text not null,       -- frase pronta: "Maria Luiza excluiu a análise da OP 7545"
  metadata jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_logs_data on public.logs_atividade(created_at desc);
create index if not exists idx_logs_user on public.logs_atividade(user_id);

-- ============================================================
-- RLS — interino permissivo (qualquer usuário autenticado).
-- Endurecimento por cargo fica para o P&D/SCM (RLS fina).
-- ============================================================
alter table public.perfis           enable row level security;
alter table public.convites         enable row level security;
alter table public.logs_atividade   enable row level security;

do $$ begin
  create policy "auth_all_perfis" on public.perfis for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "auth_all_convites" on public.convites for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;

do $$ begin
  -- Logs: qualquer autenticado insere e lê; ninguém edita/apaga (trilha de auditoria).
  create policy "auth_insert_logs" on public.logs_atividade for insert to authenticated with check (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "auth_select_logs" on public.logs_atividade for select to authenticated using (true);
exception when duplicate_object then null; end $$;
