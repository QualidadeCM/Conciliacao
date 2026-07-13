-- ============================================================
-- Migration: Tipo de re-análise (ajuste de ficha mestre)
-- Data: 09/07/2026 — Maria Luiza
-- Objetivo:
--   Distinguir a re-análise motivada por FICHA MESTRE DESATUALIZADA das
--   re-análises por correção de documento.
--   Quando a NC foi um falso positivo causado por ficha desatualizada, a
--   usuária atualiza a ficha (gera nova revisão) e refaz a análise. Esse
--   caso NÃO deve contar como "correção" nas métricas — a documentação
--   nunca esteve não conforme. O registro é marcado com:
--       tipo_reanalise = 'atualizacao_ficha'
--   O vínculo (analise_origem_id) é mantido para RASTREABILIDADE (ISO 13485):
--   o histórico continua mostrando a análise NC original e a conforme.
-- ============================================================

alter table public.analises
  add column if not exists tipo_reanalise text;  -- null = análise/re-análise normal; 'atualizacao_ficha' = refeita por ficha desatualizada

comment on column public.analises.tipo_reanalise is
  'Tipo de re-análise. null=normal/correção de documento; atualizacao_ficha=refeita após atualizar a ficha mestre (não conta como correção nas métricas).';
