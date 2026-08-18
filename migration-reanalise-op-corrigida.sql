-- ============================================================================
-- Migration: reanálise por OP corrigida + substituição da pasta na rede
-- Data: 18/08/2026
--
-- Suporta o fluxo de "Substituir OP e reanalisar" (individual e em massa):
-- quando encontramos, numa OP já analisada, um erro que o agente não pegou,
-- subimos a OP corrigida, refazemos a análise e o pacote volta a ficar pendente
-- de download — substituindo, ao baixar, a pasta que já está na rede.
--
--  - pasta_rede_path: caminho EXATO da pasta onde o pacote foi gravado na rede
--    no download (devolvido pelo serviço /salvar-pacote). Permite, na reanálise,
--    gravar por cima da MESMA pasta.
--  - data_ref_original: data da análise ORIGINAL, usada para calcular a subpasta
--    do mês no download da reanálise (para cair no mesmo \MÊS\, não no mês atual)
--    quando não houver pasta_rede_path.
-- ============================================================================

alter table public.analises
  add column if not exists pasta_rede_path text,
  add column if not exists data_ref_original timestamptz;
