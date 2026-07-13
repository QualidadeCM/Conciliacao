-- =====================================================================
-- MIGRAÇÃO — Derivação por produto (Confiance Medical)
-- =====================================================================
-- Esta migração viabiliza o cadastro de múltiplas derivações dentro
-- da mesma família/modelo. Cada par (modelo, derivacao) passa a ser uma
-- ficha técnica independente.
--
-- O que muda:
--   1. Adiciona coluna `derivacao_descricao` em `produtos`.
--   2. Aplica `derivacao = '000'` e `derivacao_descricao = 'Padrão'`
--      em todos os produtos pré-existentes (migração silenciosa).
--   3. Torna `derivacao` e `derivacao_descricao` NOT NULL.
--   4. Remove o UNIQUE de `modelo` e cria UNIQUE composto
--      `(modelo, derivacao)` — agora a chave do produto é o par.
--   5. Cria índices para lookups rápidos por (codigo_sapiens, derivacao).
--
-- Execute no SQL Editor do Supabase Studio. Idempotente.
-- =====================================================================

-- 1) Adicionar coluna derivacao_descricao se ainda não existir
alter table public.produtos
  add column if not exists derivacao_descricao text;

-- 2) Backfill: produtos sem derivação recebem "000" / "Padrão"
update public.produtos
   set derivacao = coalesce(nullif(trim(derivacao), ''), '000')
 where derivacao is null or trim(derivacao) = '';

update public.produtos
   set derivacao_descricao = coalesce(nullif(trim(derivacao_descricao), ''), 'Padrão')
 where derivacao_descricao is null or trim(derivacao_descricao) = '';

-- 3) Normalizar derivações para 3 dígitos (zero-pad)
update public.produtos
   set derivacao = lpad(regexp_replace(derivacao, '\D', '', 'g'), 3, '0')
 where derivacao ~ '^\d{1,3}$' and length(derivacao) < 3;

-- 4) Tornar campos obrigatórios
alter table public.produtos
  alter column derivacao set not null,
  alter column derivacao_descricao set not null;

-- 5) Aplicar defaults para novos registros
alter table public.produtos
  alter column derivacao set default '000',
  alter column derivacao_descricao set default 'Padrão';

-- 6) Remover unique constraint antiga de "modelo" (se existir)
do $$
declare
  rec record;
begin
  for rec in
    select conname
      from pg_constraint
     where conrelid = 'public.produtos'::regclass
       and contype = 'u'
       and pg_get_constraintdef(oid) ilike '%(modelo)%'
       and pg_get_constraintdef(oid) not ilike '%derivacao%'
  loop
    execute format('alter table public.produtos drop constraint %I', rec.conname);
  end loop;
end $$;

-- 7) Criar unique composto (modelo, derivacao)
do $$ begin
  alter table public.produtos
    add constraint uniq_produto_modelo_derivacao unique (modelo, derivacao);
exception
  when duplicate_table then null;
  when duplicate_object then null;
end $$;

-- 8) Índices auxiliares
create index if not exists idx_produtos_codigo_sapiens_derivacao
  on public.produtos(codigo_sapiens, derivacao);

create index if not exists idx_produtos_derivacao
  on public.produtos(derivacao);

-- =====================================================================
-- Verificação rápida (rode após a migração)
-- =====================================================================
-- select modelo, derivacao, derivacao_descricao, codigo_sapiens
--   from public.produtos
--  order by modelo, derivacao;
