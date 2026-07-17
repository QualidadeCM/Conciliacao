-- ============================================================================
-- Migration: autorização de INSPEÇÃO por estágio (o "Ni")
-- Data: 2026-07-15
--
-- Complementa a tabela `operadores`. Além dos estágios que o colaborador
-- EXECUTA (coluna `estagios` → "N"), passa a registrar os estágios cuja
-- INSPEÇÃO ele está autorizado a fazer (coluna `estagios_inspecao` → "Ni").
--
-- Exemplo: colaborador autorizado a inspecionar o estágio 50 → apto ao "50i".
-- São autorizações independentes (executar N ≠ inspecionar Ni).
-- ============================================================================

alter table public.operadores
  add column if not exists estagios_inspecao jsonb not null default '[]'::jsonb;
