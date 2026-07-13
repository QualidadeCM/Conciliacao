-- =====================================================================
-- MIGRATION: Excluir produtos sem registro ANVISA (equipamentos inativos)
-- Confiance Medical · 23/06/2026
-- =====================================================================
-- Decisão de 23/06/2026 (Maria Luiza):
-- Produtos sem registro_anvisa preenchido são equipamentos inativos e
-- devem ser removidos permanentemente do catálogo.
--
-- O QUE FAZ:
-- 1. Em ANÁLISES que referenciam esses produtos: seta produto_id e
--    ficha_id para NULL — preserva o histórico de análises mas desfaz o
--    vínculo (a FK não tem ON DELETE CASCADE em analises).
-- 2. Apaga os produtos. Isso aciona ON DELETE CASCADE em fichas_mestres,
--    acessorios_aplicaveis, etc., removendo tudo que estava ligado.
--
-- Idempotente: pode rodar várias vezes — nada acontece se já não há
-- produtos sem registro_anvisa.
--
-- COMO EXECUTAR:
--   Supabase Studio → SQL Editor → New query → cole TUDO → Run
-- =====================================================================

-- 1) Desvincula análises que apontam pra produtos a excluir
UPDATE public.analises
   SET produto_id = NULL,
       ficha_id   = NULL
 WHERE produto_id IN (
   SELECT id FROM public.produtos
    WHERE registro_anvisa IS NULL OR TRIM(registro_anvisa) = ''
 );

-- 2) DELETE dos produtos (CASCADE em fichas_mestres cuida das fichas vinculadas)
DELETE FROM public.produtos
 WHERE registro_anvisa IS NULL OR TRIM(registro_anvisa) = '';

-- =====================================================================
-- VERIFICAÇÃO (rode separadamente após Run)
-- =====================================================================
-- 1) Total restante de produtos (deve ter registro_anvisa preenchido):
--   SELECT COUNT(*) FROM public.produtos;
-- 2) Produtos sem registro_anvisa (deve dar 0):
--   SELECT COUNT(*) FROM public.produtos WHERE registro_anvisa IS NULL OR TRIM(registro_anvisa) = '';
-- 3) Total de fichas ativas restantes:
--   SELECT COUNT(*) FROM public.fichas_mestres WHERE ativa;
-- 4) Análises órfãs (com produto_id NULL após a limpeza):
--   SELECT COUNT(*) FROM public.analises WHERE produto_id IS NULL;
