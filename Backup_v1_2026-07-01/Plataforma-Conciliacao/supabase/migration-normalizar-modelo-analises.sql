-- =====================================================================
-- MIGRATION: Normalizar coluna modelo nas análises pelo catálogo
-- Confiance Medical · 29/06/2026
-- =====================================================================
-- Problema observado:
--   • Análises antigas têm modelo "CM-CINEMED-27F", "CM-CINEMED-32F", etc.
--   • Catálogo tem o canônico SEM o segundo hífen: "CM-CINEMED27F",
--     "CM-CINEMED32F", "CM-CINEMED42F", "CM-CINEMED26F", "CM-CINEMED23F",
--     "CM-CINEMED55F".
--
-- Resultado: o filtro de Modelo no Histórico mostra duas versões do mesmo
-- modelo, e a UI exibe o valor "antigo" — confundindo o usuário.
--
-- Esta migration atualiza analises.modelo (e o JSONB parecer_completo)
-- para o valor CANÔNICO do catálogo, comparando sem hífens.
--
-- Idempotente: pode rodar várias vezes; segunda vez não faz nada.
--
-- COMO EXECUTAR:
--   Supabase Studio → SQL Editor → New query → cole TUDO → Run
-- =====================================================================

-- 1) Atualiza a coluna analises.modelo direto pelo catálogo
--    Só toca análises cujo modelo NÃO bate com nada no catálogo, mas que
--    BATEM com algum produto após remover todos os hífens (case-insensitive).
UPDATE public.analises a
   SET modelo = p.modelo
  FROM public.produtos p
 WHERE a.modelo IS NOT NULL
   AND a.modelo <> ''
   AND a.modelo <> p.modelo
   AND LOWER(REPLACE(a.modelo, '-', '')) = LOWER(REPLACE(p.modelo, '-', ''))
   AND NOT EXISTS (
     SELECT 1 FROM public.produtos p2 WHERE p2.modelo = a.modelo
   );

-- 2) Atualiza também o parecer_completo->'produto'->>'modelo' (JSONB),
--    que é usado em vários lugares da UI (parecer, dashboard, ZIP).
UPDATE public.analises a
   SET parecer_completo = jsonb_set(
         parecer_completo,
         '{produto,modelo}',
         to_jsonb(p.modelo)
       )
  FROM public.produtos p
 WHERE a.parecer_completo IS NOT NULL
   AND a.parecer_completo ? 'produto'
   AND a.parecer_completo->'produto' ? 'modelo'
   AND (a.parecer_completo->'produto'->>'modelo') <> ''
   AND (a.parecer_completo->'produto'->>'modelo') <> p.modelo
   AND LOWER(REPLACE(a.parecer_completo->'produto'->>'modelo', '-', ''))
       = LOWER(REPLACE(p.modelo, '-', ''))
   AND NOT EXISTS (
     SELECT 1 FROM public.produtos p2
      WHERE p2.modelo = a.parecer_completo->'produto'->>'modelo'
   );

-- =====================================================================
-- VERIFICAÇÃO (rode separadamente após Run)
-- =====================================================================
-- 1) Distintos de modelo em análises depois da migração — deve estar todo
--    presente no catálogo:
--   SELECT DISTINCT a.modelo FROM public.analises a
--    WHERE a.modelo IS NOT NULL AND a.modelo <> ''
--      AND NOT EXISTS (SELECT 1 FROM public.produtos p WHERE p.modelo = a.modelo)
--    ORDER BY a.modelo;
--
-- 2) Contagem por modelo após a migração:
--   SELECT modelo, COUNT(*) FROM public.analises
--    WHERE modelo IS NOT NULL GROUP BY modelo ORDER BY 2 DESC;
--
-- 3) Sanity: divergências entre coluna modelo e JSONB (deve dar 0):
--   SELECT COUNT(*) FROM public.analises
--    WHERE parecer_completo->'produto'->>'modelo' IS NOT NULL
--      AND parecer_completo->'produto'->>'modelo' <> modelo;
