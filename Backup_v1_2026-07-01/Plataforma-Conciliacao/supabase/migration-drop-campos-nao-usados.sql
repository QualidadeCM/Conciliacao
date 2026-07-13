-- =====================================================================
-- MIGRATION: Dropar 4 campos não usados na análise
-- Confiance Medical · Plataforma de Conciliação da Produção
-- =====================================================================
-- Decisão de 17/06/2026 (Maria Luiza, durante revisão do cobrir-tudo):
--
-- 1. aplicabilidade_udi — campo "A implementação ainda não foi realizada".
--    Não é confrontado com nenhum documento. Voltar quando o UDI for
--    obrigatório operacionalmente.
-- 2. inmetro_aplicavel + inmetro_observacao — não relevantes para a
--    família de produtos sob a regulação atual.
-- 3. acessorios_aplicaveis.observacao — texto livre, não vira check
--    determinístico. Quando há regra de negócio especial, ela vai para
--    fichas_mestres.regras_negocio (campo já existente).
--
-- COMO EXECUTAR:
--   Supabase Studio → SQL Editor → New query → cole TUDO → Run
-- =====================================================================

BEGIN;

ALTER TABLE public.fichas_mestres DROP COLUMN IF EXISTS aplicabilidade_udi;
ALTER TABLE public.fichas_mestres DROP COLUMN IF EXISTS inmetro_aplicavel;
ALTER TABLE public.fichas_mestres DROP COLUMN IF EXISTS inmetro_observacao;
ALTER TABLE public.acessorios_aplicaveis DROP COLUMN IF EXISTS observacao;

COMMIT;

-- =====================================================================
-- VERIFICAÇÃO (rode após o commit)
-- =====================================================================
-- SELECT column_name FROM information_schema.columns
--  WHERE table_schema='public' AND table_name='fichas_mestres' ORDER BY ordinal_position;
-- SELECT column_name FROM information_schema.columns
--  WHERE table_schema='public' AND table_name='acessorios_aplicaveis' ORDER BY ordinal_position;
