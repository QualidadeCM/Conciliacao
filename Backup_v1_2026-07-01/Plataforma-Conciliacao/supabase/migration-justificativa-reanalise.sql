-- =====================================================================
-- MIGRATION: Justificativa de ressalvas + re-análise com doc corrigido
-- Confiance Medical · Plataforma de Conciliação da Produção
-- =====================================================================
-- Decisão de 17/06/2026 (Maria Luiza):
--
-- 1. RESSALVAS justificáveis: quando uma análise gera uma ressalva, o RT
--    deve poder anexar uma justificativa textual. A ressalva passa a ser
--    "Justificada" (tratada como conforme no índice consolidado), mantendo
--    o histórico do que foi apontado e qual foi a justificativa.
--    Implementação: coluna `justificativa` (TEXT, nullable) +
--    `justificada_em` (timestamp) + `justificada_por` (user_id).
--
-- 2. RE-ANÁLISE com documento corrigido: quando uma análise gera uma NC,
--    o usuário pode reenviar o documento corrigido. Isso cria uma NOVA
--    análise (registro novo em `analises`) que referencia a anterior via
--    `analise_origem_id`. Permite trilha de auditoria do histórico de
--    correções.
-- =====================================================================

BEGIN;

-- 1) Justificativa nas ressalvas
ALTER TABLE public.apontamentos
  ADD COLUMN IF NOT EXISTS justificativa TEXT;
ALTER TABLE public.apontamentos
  ADD COLUMN IF NOT EXISTS justificada_em TIMESTAMPTZ;
ALTER TABLE public.apontamentos
  ADD COLUMN IF NOT EXISTS justificada_por UUID REFERENCES auth.users(id);

COMMENT ON COLUMN public.apontamentos.justificativa IS
  'Texto da justificativa registrada pelo RT quando a ressalva é considerada aceitável. Se preenchido, a ressalva passa a contar como conforme no índice consolidado.';

-- 2) Vínculo de re-análise (uma análise pode ter sido feita re-substituindo doc de outra)
ALTER TABLE public.analises
  ADD COLUMN IF NOT EXISTS analise_origem_id UUID REFERENCES public.analises(id) ON DELETE SET NULL;
ALTER TABLE public.analises
  ADD COLUMN IF NOT EXISTS doc_substituido TEXT;
ALTER TABLE public.analises
  ADD COLUMN IF NOT EXISTS motivo_reanalise TEXT;

COMMENT ON COLUMN public.analises.analise_origem_id IS
  'ID da análise anterior que originou esta re-análise (quando o usuário substituiu um documento e re-analisou o lote). NULL = análise original.';
COMMENT ON COLUMN public.analises.doc_substituido IS
  'Slot do documento que foi substituído nesta re-análise (ex.: "op", "rc", "etiqueta_externa", "etiqueta_acessorio").';
COMMENT ON COLUMN public.analises.motivo_reanalise IS
  'Texto livre explicando por que o documento foi substituído.';

-- 3) Índice pra buscar histórico de uma análise rapidamente
CREATE INDEX IF NOT EXISTS analises_origem_idx ON public.analises (analise_origem_id) WHERE analise_origem_id IS NOT NULL;

COMMIT;

-- =====================================================================
-- VERIFICAÇÃO
-- =====================================================================
-- SELECT column_name FROM information_schema.columns
--  WHERE table_schema='public' AND table_name='apontamentos' ORDER BY ordinal_position;
-- SELECT column_name FROM information_schema.columns
--  WHERE table_schema='public' AND table_name='analises' ORDER BY ordinal_position;
