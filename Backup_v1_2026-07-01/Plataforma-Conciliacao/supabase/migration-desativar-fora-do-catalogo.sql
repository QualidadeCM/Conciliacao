-- =====================================================================
-- MIGRATION SIMPLES: Desativar produtos fora do catálogo da planilha
-- Confiance Medical · 18/06/2026
-- =====================================================================
-- Estratégia: apenas SOFT DELETE (ativo = FALSE) os produtos que NÃO
-- estão na planilha de catálogo E NÃO têm Ficha Mestre ativa associada.
--
-- O que esta migration NÃO faz (de propósito):
--   · NÃO insere novos produtos (cadastre manualmente via UI)
--   · NÃO atualiza dados de produtos existentes
--   · NÃO mexe em UNIQUE constraints
--
-- Regras:
--   · Catálogo = 87 pares únicos (modelo, derivação) da planilha
--   · Produto NO catálogo → preserva ativo atual
--   · Produto FORA do catálogo COM ficha mestre ativa → preserva ativo=TRUE
--   · Produto FORA do catálogo SEM ficha mestre ativa → ativo = FALSE
--
-- COMO EXECUTAR:
--   Supabase Studio → SQL Editor → New query → cole TUDO → Run
-- =====================================================================

BEGIN;

WITH catalogo (modelo, derivacao) AS (
  VALUES
  ('CM-LED', '001'),
  ('CM-LED', '002'),
  ('CM-100', '001'),
  ('CM-OTC0010A', '001'),
  ('CM-OTC0011A', '001'),
  ('CM-OTC0012A', '001'),
  ('CM-OTC0019A', '001'),
  ('CM-OTC0041A', '001'),
  ('CM-OTC0042A', '001'),
  ('CM-OTC0043A', '001'),
  ('CM-OTC0026C', '001'),
  ('CM-OTC0027C', '001'),
  ('CM-OTC0028C', '001'),
  ('CM-OTC0029C', '001'),
  ('CM-OTC0030C', '001'),
  ('CM-OTC0031C', '001'),
  ('CM-OTC0032C', '001'),
  ('CM-OTC0033C', '001'),
  ('CM-OTC0056C', '001'),
  ('CM-OTC0057C', '001'),
  ('CM-OTC0058C', '001'),
  ('CM-OTC0026H', '001'),
  ('CM-OTC0027H', '001'),
  ('CM-OTC0028H', '001'),
  ('CM-OTC0029H', '001'),
  ('CM-OTC0030H', '001'),
  ('CM-OTC0031H', '001'),
  ('CM-OTC0032H', '001'),
  ('CM-OTC0033H', '001'),
  ('CM-OTC0056H', '001'),
  ('CM-OTC0057H', '001'),
  ('CM-OTC0058H', '001'),
  ('CM-OTC0004L', '001'),
  ('CM-OTC0005L', '001'),
  ('CM-OTC0050L', '001'),
  ('CM-OTC0051L', '001'),
  ('CM-OTC0059L', '001'),
  ('CM-OTC0060L', '001'),
  ('CM-OTC0065L', '001'),
  ('CM-OTC0066L', '001'),
  ('CM-OTC0010N', '001'),
  ('CM-OTC0011N', '001'),
  ('CM-OTC0012N', '001'),
  ('CM-OTC0019N', '001'),
  ('CM-OTC0024N', '001'),
  ('CM-OTC0041N', '001'),
  ('CM-OTC0042N', '001'),
  ('CM-OTC0043N', '001'),
  ('CM-40L', '004'),
  ('CM-40L', '005'),
  ('CM-40L', '006'),
  ('CM-40L', '007'),
  ('CM-40L', '008'),
  ('CM-40L', '009'),
  ('CM-40L', '010'),
  ('CM-40L', '011'),
  ('CM-ENDOCO2', '001'),
  ('CM-FLOW', '001'),
  ('CM-CAM', '013'),
  ('CM-CAM', '014'),
  ('CM-CAM', '015'),
  ('CM-CAM', '016'),
  ('CM-SCAM', '010'),
  ('CM-SCAM', '011'),
  ('CM-SCAM', '012'),
  ('CM-SCAM', '002'),
  ('CM-SCAM', '018'),
  ('CM-SCAM3', '002'),
  ('CM-SCAM3', '010'),
  ('CM-SCAM3', '011'),
  ('CM-SCAM3', '012'),
  ('CM-CINEMED27F', '013'),
  ('CM-CINEMED27F', '014'),
  ('CM-CINEMED27F', '016'),
  ('CM-CINEMED27F', '017'),
  ('CM-CINEMED32F', '015'),
  ('CM-CINEMED32F', '017'),
  ('CM-CINEMED42F', '001'),
  ('CM-RECMASTER3', '001'),
  ('CM-RECMASTER3', '002'),
  ('CM-STATION', '001'),
  ('CM-STATION', '002'),
  ('CM-STATION', '003'),
  ('CM-STATION27', '001'),
  ('CM-STATION27', '002'),
  ('CM-UROVIEW', '001'),
  ('CM-UROLIT', '001')
),
produtos_com_ficha AS (
  SELECT DISTINCT produto_id
    FROM public.fichas_mestres
   WHERE ativa = TRUE
     AND produto_id IS NOT NULL
)
UPDATE public.produtos p
   SET ativo = FALSE
 WHERE p.ativo = TRUE
   AND NOT EXISTS (
     SELECT 1 FROM catalogo c
      WHERE c.modelo = p.modelo
        AND c.derivacao = p.derivacao
   )
   AND p.id NOT IN (SELECT produto_id FROM produtos_com_ficha);

COMMIT;

-- =====================================================================
-- VERIFICAÇÃO (rode após o commit)
-- =====================================================================
-- 1) Quantos produtos ativos sobraram:
--   SELECT COUNT(*) FROM public.produtos WHERE ativo = TRUE;
--
-- 2) Listar produtos que foram preservados por terem ficha ativa
--    (estão fora da planilha mas ficaram ativos):
--   SELECT p.modelo, p.derivacao, p.equipamento, p.codigo_sapiens
--     FROM public.produtos p
--     JOIN public.fichas_mestres fm ON fm.produto_id = p.id AND fm.ativa = TRUE
--    WHERE p.ativo = TRUE
--    ORDER BY p.modelo, p.derivacao;
--
-- 3) Listar produtos que foram desativados nesta operação:
--   SELECT modelo, derivacao, equipamento, codigo_sapiens
--     FROM public.produtos
--    WHERE ativo = FALSE
--    ORDER BY modelo, derivacao;
