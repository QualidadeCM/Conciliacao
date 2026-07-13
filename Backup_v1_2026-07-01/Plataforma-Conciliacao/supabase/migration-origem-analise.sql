-- =====================================================================
-- MIGRATION: Adicionar coluna origem_analise em analises
-- Confiance Medical · 23/06/2026
-- =====================================================================
-- Permite registrar se a análise foi feita pelo Agente IA ou se foi
-- IMPORTADA do histórico manual anterior. Refletido no Histórico (com
-- ícone diferenciador) e no Dashboard (contagem combinada).
-- =====================================================================

ALTER TABLE public.analises
  ADD COLUMN IF NOT EXISTS origem_analise TEXT NOT NULL DEFAULT 'agente';

-- Atualiza registros existentes (todos = agente)
UPDATE public.analises
   SET origem_analise = 'agente'
 WHERE origem_analise IS NULL;

COMMENT ON COLUMN public.analises.origem_analise IS
  'Origem da análise: "agente" (gerada pela plataforma) ou "manual" (importada do histórico anterior via planilha).';

-- Index pra filtrar rápido
CREATE INDEX IF NOT EXISTS idx_analises_origem ON public.analises (origem_analise);
