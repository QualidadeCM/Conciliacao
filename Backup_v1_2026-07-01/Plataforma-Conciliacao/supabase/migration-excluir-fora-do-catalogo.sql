-- =====================================================================
-- MIGRATION: Excluir PERMANENTEMENTE produtos fora do catálogo
-- Confiance Medical · 18/06/2026
-- =====================================================================
-- Apaga (DELETE) os produtos da tabela `produtos` que NÃO estão na planilha
-- de catálogo E NÃO têm Ficha Mestre ativa associada.
--
-- COMPARAÇÃO TOLERANTE: TRIM + UPPER no modelo, TRIM na derivação. Resolve
-- problemas como "CM-LED " (com espaço) vs "CM-LED", "cm-led" vs "CM-LED",
-- "1" vs "001", etc.
--
-- COMPORTAMENTO DE EXCLUSÃO EM CASCATA:
--   1. Análises (analises) que referenciam o produto → produto_id = NULL
--      (preserva o histórico da análise, perde só o link com o produto).
--   2. Fichas mestres INATIVAS desses produtos → DELETE.
--      (Não tem ficha ativa porque o filtro já garante isso.)
--   3. Acessórios das fichas que serão removidas → DELETE (cascade).
--   4. Produtos → DELETE.
--
-- SEGURANÇA: Roda DENTRO de transação. Se algo der errado, faz ROLLBACK
-- automático. Antes do COMMIT mostra contagem do que será apagado via NOTICE.
--
-- COMO EXECUTAR:
--   Supabase Studio → SQL Editor → New query → cole TUDO → Run
-- =====================================================================

BEGIN;

-- Tabela temporária com os IDs dos produtos a excluir
CREATE TEMP TABLE _produtos_para_excluir AS
SELECT p.id, p.modelo, p.derivacao, p.equipamento, p.codigo_sapiens
  FROM public.produtos p
 WHERE NOT EXISTS (
   SELECT 1
     FROM (VALUES
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
     ) AS c(modelo_norm, deriv_norm)
    WHERE c.modelo_norm = TRIM(UPPER(p.modelo))
      AND c.deriv_norm  = TRIM(COALESCE(p.derivacao, '000'))
 )
   AND p.id NOT IN (
     SELECT DISTINCT produto_id
       FROM public.fichas_mestres
      WHERE ativa = TRUE
        AND produto_id IS NOT NULL
   );

-- Log: quantos serão removidos
DO $$
DECLARE n INT;
BEGIN
  SELECT COUNT(*) INTO n FROM _produtos_para_excluir;
  RAISE NOTICE 'Produtos que serão APAGADOS: %', n;
END $$;

-- 1) Desreferencia análises (preserva histórico)
UPDATE public.analises
   SET produto_id = NULL
 WHERE produto_id IN (SELECT id FROM _produtos_para_excluir);

-- 2) Remove fichas mestres inativas desses produtos (cascade limpa acessórios)
DELETE FROM public.fichas_mestres
 WHERE produto_id IN (SELECT id FROM _produtos_para_excluir);

-- 3) Remove os produtos definitivamente
DELETE FROM public.produtos
 WHERE id IN (SELECT id FROM _produtos_para_excluir);

-- Limpa a tabela temporária (Postgres faz isso automaticamente no fim da sessão,
-- mas explicito por boa prática)
DROP TABLE _produtos_para_excluir;

COMMIT;

-- =====================================================================
-- VERIFICAÇÃO (rode após o commit)
-- =====================================================================
-- Total de produtos restantes (deve estar próximo de 87 + preservados por ficha):
--   SELECT COUNT(*) FROM public.produtos;
--
-- Total com ficha mestre ativa (preservados mesmo fora do catálogo):
--   SELECT COUNT(*) FROM public.produtos p
--     WHERE EXISTS (SELECT 1 FROM public.fichas_mestres f WHERE f.produto_id = p.id AND f.ativa = TRUE);
--
-- Listar os 10 produtos mais recentes (sanity check):
--   SELECT modelo, derivacao, equipamento, codigo_sapiens
--     FROM public.produtos ORDER BY modelo, derivacao LIMIT 10;
