-- ============================================================
-- Migration: grupo alternativo de acessórios
-- Data: 06/07/2026 — Maria Luiza
-- Objetivo:
--   Permitir acessórios "alternativos" (o cliente escolhe um dentre
--   variantes, ex.: Cabeça de Câmera CM-STATION IPM0009 vs IPM0023).
--   Regra de negócio: itens que compartilham o mesmo grupo_alternativo
--   formam um conjunto em que PELO MENOS UM deve constar na RC, com a
--   etiqueta conferida. Individualmente não são obrigatórios.
--   NULL/vazio = acessório comum (comportamento antigo preservado).
--
-- NOTA P&D SOFTWARE: replicar esta coluna no schema MySQL na migração
--   da stack (VARCHAR(120) NULL) — mesma semântica.
-- ============================================================

alter table public.acessorios_aplicaveis
  add column if not exists grupo_alternativo text;

comment on column public.acessorios_aplicaveis.grupo_alternativo is
  'Nome do grupo de acessórios alternativos. Itens com o mesmo valor são '
  'mutuamente substituíveis: pelo menos um deve constar na RC com etiqueta. '
  'NULL = acessório comum.';
