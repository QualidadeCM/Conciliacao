-- ============================================================================
-- Migration: corrigir troca de modelo entre LAP0034 e LAP0035
-- Data: 21/08/2026
--
-- Achado: os produtos de código Sapiens LAP0034 (prefixo de série LAP51P)
-- e LAP0035 (prefixo de série LAP50P) estão com o campo "modelo" invertido
-- desde a reimportação do catálogo de 23/06/2026:
--   - LAP0034 (LAP51P) está como CM-OTC0050L  → deveria ser CM-OTC0051L
--   - LAP0035 (LAP50P) está como CM-OTC0051L  → deveria ser CM-OTC0050L
--
-- Isso faz o sistema identificar OPs do LAP51P (ex.: OP 7364) como se
-- fossem do produto CM-OTC0050L, bloqueando a análise por apontar a
-- Ficha Mestre errada como "não revisada".
--
-- Correção: troca os dois modelos entre si. Usa um valor temporário para
-- não violar a constraint de unicidade durante a troca.
-- ============================================================================

BEGIN;

-- Confira antes de aplicar (opcional):
-- select id, codigo_sapiens, modelo, codigo_referencia from produtos where codigo_sapiens in ('LAP0034','LAP0035');

UPDATE public.produtos SET modelo = '__TEMP_SWAP__' WHERE codigo_sapiens = 'LAP0034';
UPDATE public.produtos SET modelo = 'CM-OTC0050L'   WHERE codigo_sapiens = 'LAP0035';
UPDATE public.produtos SET modelo = 'CM-OTC0051L'   WHERE codigo_sapiens = 'LAP0034';

COMMIT;

-- Confira depois de aplicar:
-- select id, codigo_sapiens, modelo, codigo_referencia from produtos where codigo_sapiens in ('LAP0034','LAP0035');
-- Esperado: LAP0034 → CM-OTC0051L (prefixo LAP51P) · LAP0035 → CM-OTC0050L (prefixo LAP50P)
