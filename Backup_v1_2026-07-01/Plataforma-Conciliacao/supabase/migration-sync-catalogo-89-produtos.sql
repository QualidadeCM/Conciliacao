-- =====================================================================
-- MIGRATION: Sincronizar Catálogo de Produtos com a planilha de 18/06/2026
-- Confiance Medical · Plataforma de Conciliação da Produção
-- =====================================================================
-- Decisão de 18/06/2026 (Maria Luiza):
-- 1. Catálogo oficial = 87 produtos únicos da planilha (89 - 2 duplicatas
--    LAP50P/LAP0035 e LAP51P/LAP0034 puladas até definir derivação correta).
-- 2. Produtos no catálogo: ativo = TRUE.
-- 3. Produtos FORA do catálogo MAS COM ficha mestre ativa: continuam ativos.
-- 4. Produtos FORA do catálogo SEM ficha mestre ativa: ativo = FALSE.
--
-- IMPORTANTE: A planilha permite múltiplas derivações do MESMO modelo
-- compartilharem o codigo_sapiens (ex.: CM-LED/001 e CM-LED/002 = FNT0001),
-- o que viola eventuais UNIQUE constraints em codigo_sapiens e
-- codigo_referencia. Esta migration REMOVE essas constraints (passo 0)
-- antes do UPSERT, deixando apenas (modelo, derivacao) como chave única —
-- que é o que a aplicação realmente usa para distinguir produtos.
--
-- COMO EXECUTAR:
--   Supabase Studio → SQL Editor → New query → cole TUDO → Run
-- =====================================================================

BEGIN;

-- 0) Remove UNIQUE constraints que conflitam com famílias compartilhando código
DO $$
DECLARE c RECORD;
BEGIN
  FOR c IN
    SELECT conname FROM pg_constraint
     WHERE conrelid = 'public.produtos'::regclass
       AND contype = 'u'
       AND conname IN (
         SELECT conname FROM pg_constraint
          WHERE conrelid = 'public.produtos'::regclass AND contype='u'
       )
  LOOP
    -- Mantém apenas a UNIQUE composta (modelo, derivacao). Remove todas as outras.
    IF c.conname NOT LIKE '%modelo%derivacao%' AND c.conname NOT LIKE '%derivacao%modelo%' THEN
      EXECUTE 'ALTER TABLE public.produtos DROP CONSTRAINT IF EXISTS ' || quote_ident(c.conname);
      RAISE NOTICE 'Removida constraint UNIQUE: %', c.conname;
    END IF;
  END LOOP;
END $$;

-- Garante que a constraint composta exista (idempotente)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conrelid='public.produtos'::regclass
       AND contype='u'
       AND pg_get_constraintdef(oid) ILIKE '%modelo%derivacao%'
  ) THEN
    ALTER TABLE public.produtos ADD CONSTRAINT produtos_modelo_derivacao_key UNIQUE (modelo, derivacao);
    RAISE NOTICE 'Criada constraint UNIQUE (modelo, derivacao)';
  END IF;
END $$;

-- 1) UPSERT dos 87 produtos únicos do catálogo
WITH catalogo (equipamento, modelo, codigo_referencia, registro_anvisa, codigo_sapiens, derivacao, derivacao_descricao) AS (
  VALUES
  ('FONTE DE LUZ LED', 'CM-LED', 'LEDT', '80337650008', 'FNT0001', '001', 'CONFIANCE'),
  ('FONTE DE LUZ LED', 'CM-LED', 'LEDT', '80337650008', 'FNT0001', '002', 'Com Fluorescência'),
  ('ACESSÓRIO PARA ESCAPE DE FUMAÇA', 'CM-100', 'CM100', '80337650003', 'ASP0001', '001', 'CONFIANCE'),
  ('ENDOSCÓPIO RÍGIDO PARA ARTROSCOPIA', 'CM-OTC0010A', 'ART10', '80337659009', 'ART0001', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA ARTROSCOPIA', 'CM-OTC0011A', 'ART11', '80337659009', 'ART0002', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA ARTROSCOPIA', 'CM-OTC0012A', 'ART12', '80337659009', 'ART0003', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA ARTROSCOPIA', 'CM-OTC0019A', 'ART19', '80337659009', 'ART0010', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA ARTROSCOPIA', 'CM-OTC0041A', 'ART41', '80337659009', 'ART0014', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA ARTROSCOPIA', 'CM-OTC0042A', 'ART42', '80337659009', 'ART0015', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA ARTROSCOPIA', 'CM-OTC0043A', 'ART43', '80337659009', 'ART0016', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA CISTOSCOPIA', 'CM-OTC0026C', 'CIS26', '80337659013', 'CIS0001', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA CISTOSCOPIA', 'CM-OTC0027C', 'CIS27', '80337659013', 'CIS0002', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA CISTOSCOPIA', 'CM-OTC0028C', 'CIS28', '80337659013', 'CIS0003', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA CISTOSCOPIA', 'CM-OTC0029C', 'CIS29', '80337659013', 'CIS0004', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA CISTOSCOPIA', 'CM-OTC0030C', 'CIS30', '80337659013', 'CIS0005', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA CISTOSCOPIA', 'CM-OTC0031C', 'CIS31', '80337659013', 'CIS0006', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA CISTOSCOPIA', 'CM-OTC0032C', 'CIS32', '80337659013', 'CIS0007', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA CISTOSCOPIA', 'CM-OTC0033C', 'CIS33', '80337659013', 'CIS0008', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA CISTOSCOPIA', 'CM-OTC0056C', 'CIS56', '80337659013', 'CIS0009', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA CISTOSCOPIA', 'CM-OTC0057C', 'CIS57', '80337659013', 'CIS0010', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA CISTOSCOPIA', 'CM-OTC0058C', 'CIS58', '80337659013', 'CIS0011', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA HISTEROSCOPIA', 'CM-OTC0026H', 'HIS26', '80337659012', 'HIS0001', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA HISTEROSCOPIA', 'CM-OTC0027H', 'HIS27', '80337659012', 'HIS0002', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA HISTEROSCOPIA', 'CM-OTC0028H', 'HIS28', '80337659012', 'HIS0003', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA HISTEROSCOPIA', 'CM-OTC0029H', 'HIS29', '80337659012', 'HIS0004', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA HISTEROSCOPIA', 'CM-OTC0030H', 'HIS30', '80337659012', 'HIS0005', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA HISTEROSCOPIA', 'CM-OTC0031H', 'HIS31', '80337659012', 'HIS0006', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA HISTEROSCOPIA', 'CM-OTC0032H', 'HIS32', '80337659012', 'HIS0007', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA HISTEROSCOPIA', 'CM-OTC0033H', 'HIS33', '80337659012', 'HIS0008', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA HISTEROSCOPIA', 'CM-OTC0056H', 'HIS56', '80337659012', 'HIS0009', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA HISTEROSCOPIA', 'CM-OTC0057H', 'HIS57', '80337659012', 'HIS0010', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA HISTEROSCOPIA', 'CM-OTC0058H', 'HIS58', '80337659012', 'HIS0011', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA LAPAROSCOPIA', 'CM-OTC0004L', 'LAP04', '80337659015', 'LAP0004', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA LAPAROSCOPIA', 'CM-OTC0005L', 'LAP05', '80337659015', 'LAP0005', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA LAPAROSCOPIA', 'CM-OTC0050L', 'LAP50', '80337659015', 'LAP0016', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA LAPAROSCOPIA', 'CM-OTC0051L', 'LAP51', '80337659015', 'LAP0017', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA LAPAROSCOPIA', 'CM-OTC0059L', 'LAP59', '80337659015', 'LAP0022', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA LAPAROSCOPIA', 'CM-OTC0060L', 'LAP60', '80337659015', 'LAP0023', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA LAPAROSCOPIA', 'CM-OTC0065L', 'LAP65', '80337659015', 'LAP0028', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA LAPAROSCOPIA', 'CM-OTC0066L', 'LAP66', '80337659015', 'LAP0029', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA NASOFARINGOLARINGOSCOPIA', 'CM-OTC0010N', 'NAS10', '80337659010', 'NAS0001', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA NASOFARINGOLARINGOSCOPIA', 'CM-OTC0011N', 'NAS11', '80337659010', 'NAS0002', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA NASOFARINGOLARINGOSCOPIA', 'CM-OTC0012N', 'NAS12', '80337659010', 'NAS0003', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA NASOFARINGOLARINGOSCOPIA', 'CM-OTC0019N', 'NAS19', '80337659010', 'NAS0008', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA NASOFARINGOLARINGOSCOPIA', 'CM-OTC0024N', 'NAS24', '80337659010', 'NAS0013', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA NASOFARINGOLARINGOSCOPIA', 'CM-OTC0041N', 'NAS41', '80337659010', 'NAS0015', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA NASOFARINGOLARINGOSCOPIA', 'CM-OTC0042N', 'NAS42', '80337659010', 'NAS0016', '001', 'Padrão'),
  ('ENDOSCÓPIO RÍGIDO PARA NASOFARINGOLARINGOSCOPIA', 'CM-OTC0043N', 'NAS43', '80337659010', 'NAS0017', '001', 'Padrão'),
  ('INSUFLADOR DE CO2', 'CM-40L', 'CM40T', '80337650003', 'INS0002', '004', 'Laparoscopia'),
  ('INSUFLADOR DE CO2', 'CM-40L', 'CM40T', '80337650003', 'INS0002', '005', 'Laparoscopia + Cardio'),
  ('INSUFLADOR DE CO2', 'CM-40L', 'CM40T', '80337650003', 'INS0002', '006', 'Laparoscopia + Cardio + Endoscopia'),
  ('INSUFLADOR DE CO2', 'CM-40L', 'CM40T', '80337650003', 'INS0002', '007', 'Endoscopia'),
  ('INSUFLADOR DE CO2', 'CM-40L', 'CM40T', '80337650003', 'INS0002', '008', 'Laparoscopia + Datalogger'),
  ('INSUFLADOR DE CO2', 'CM-40L', 'CM40T', '80337650003', 'INS0002', '009', 'Laparoscopia + Cardio + Datalogger'),
  ('INSUFLADOR DE CO2', 'CM-40L', 'CM40T', '80337650003', 'INS0002', '010', 'Laparoscopia + Cardio + Endoscopia + Datalogger'),
  ('INSUFLADOR DE CO2', 'CM-40L', 'CM40T', '80337650003', 'INS0002', '011', 'Endoscopia + Datalogger'),
  ('INSUFLADOR DE CO2 PARA ENDOSCOPIA', 'CM-ENDOCO2', 'CMEND', '80337650010', 'INS0003', '001', 'CONFIANCE'),
  ('INSUFLADOR DE LÍQUIDO PARA ENDOSCOPIA', 'CM-FLOW', 'CMFLOW', '80337659004', 'INS0004', '001', 'CONFIANCE'),
  ('MICROCÂMERA CM', 'CM-CAM', 'CMCAM', '80337650005', 'CAM0005', '013', 'Sem gravação e sem os botões da cabeça'),
  ('MICROCÂMERA CM', 'CM-CAM', 'CMCAM', '80337650005', 'CAM0005', '014', 'Sem gravação e com os botões da cabeça'),
  ('MICROCÂMERA CM', 'CM-CAM', 'CMCAM', '80337650005', 'CAM0005', '015', 'Com gravação e sem os botões da cabeça.'),
  ('MICROCÂMERA CM', 'CM-CAM', 'CMCAM', '80337650005', 'CAM0005', '016', 'Com gravação e com os botões da cabeça.'),
  ('MICROCÂMERA CM', 'CM-SCAM', 'SCFHDT', '80337650005', 'CAM0002', '010', '2 DVI + GRAVAÇÃO FHD'),
  ('MICROCÂMERA CM', 'CM-SCAM', 'SCFHDT', '80337650005', 'CAM0002', '011', '2 DVI + ANALÓGICO + GRAVAÇÃO FHD'),
  ('MICROCÂMERA CM', 'CM-SCAM', 'SCFHDT', '80337650005', 'CAM0002', '012', '2 DVI + ANALOGICO + GRAVACAO FHD + SDI'),
  ('MICROCÂMERA CM', 'CM-SCAM', 'SC4KT', '80337650005', 'CAM0006', '002', 'COM GRAVAÇÃO'),
  ('MICROCÂMERA CM', 'CM-SCAM', 'SC4KT', '80337650005', 'CAM0006', '018', 'Com gravação e com fluorescência'),
  ('MICROCÂMERA CM', 'CM-SCAM3', 'SC34KT', '80337650005', 'CAM0004', '002', 'COM GRAVAÇÃO'),
  ('MICROCÂMERA CM', 'CM-SCAM3', 'SC3FHDT', '80337650005', 'CAM0003', '010', '2 DVI + GRAVAÇÃO FHD'),
  ('MICROCÂMERA CM', 'CM-SCAM3', 'SC3FHDT', '80337650005', 'CAM0003', '011', '2 DVI + ANALÓGICO + GRAVAÇÃO FHD'),
  ('MICROCÂMERA CM', 'CM-SCAM3', 'SC3FHDT', '80337650005', 'CAM0003', '012', '2 DVI + ANALOGICO + GRAVACAO FHD + SDI'),
  ('MONITOR PROFISSIONAL GRAU MÉDICO', 'CM-CINEMED27F', 'CM27FC', '80337650007', 'MNT0014', '013', 'DVI'),
  ('MONITOR PROFISSIONAL GRAU MÉDICO', 'CM-CINEMED27F', 'CM27FC', '80337650007', 'MNT0014', '014', 'DVI Touch Screen'),
  ('MONITOR PROFISSIONAL GRAU MÉDICO', 'CM-CINEMED27F', 'CM27FC', '80337650007', 'MNT0014', '016', 'SDI'),
  ('MONITOR PROFISSIONAL GRAU MÉDICO', 'CM-CINEMED27F', 'CM27FC', '80337650007', 'MNT0014', '017', 'SDI PIP'),
  ('MONITOR PROFISSIONAL GRAU MÉDICO', 'CM-CINEMED32F', 'CM32FC', '80337650007', 'MNT0017', '015', 'HDMI'),
  ('MONITOR PROFISSIONAL GRAU MÉDICO', 'CM-CINEMED32F', 'CM32FC', '80337650007', 'MNT0017', '017', 'SDI PIP'),
  ('MONITOR PROFISSIONAL GRAU MÉDICO', 'CM-CINEMED42F', 'CM42FC', '80337650007', 'MNT0019', '001', 'CONFIANCE'),
  ('SISTEMA DE GRAVAÇÃO DE IMAGENS', 'CM-RECMASTER3', 'REC3FHD', '80337659002', 'GRA0003', '001', 'Full HD'),
  ('SISTEMA DE GRAVAÇÃO DE IMAGENS', 'CM-RECMASTER3', 'REC3UHD', '80337659002', 'GRA0004', '002', '4K'),
  ('SISTEMA INTEGRADO PARA ENDOSCOPIA', 'CM-STATION', 'CMST', '80337659003', 'STB0001', '001', 'Full HD'),
  ('SISTEMA INTEGRADO PARA ENDOSCOPIA', 'CM-STATION', 'CMST', '80337659003', 'STB0001', '002', 'Full HD Plus'),
  ('SISTEMA INTEGRADO PARA ENDOSCOPIA', 'CM-STATION', 'CMST', '80337659003', 'STB0001', '003', '4K'),
  ('SISTEMA INTEGRADO PARA ENDOSCOPIA', 'CM-STATION27', 'CMST27', '80337659003', 'SIC0002', '001', 'Full HD'),
  ('SISTEMA INTEGRADO PARA ENDOSCOPIA', 'CM-STATION27', 'CMST27', '80337659003', 'SIC0002', '002', 'Full HD Plus'),
  ('SISTEMA DE VÍDEO URETERORRENOSCÓPIO DIGITAL', 'CM-UROVIEW', 'CMFLEX', '80337659007', 'URL0001', '001', 'Confiance'),
  ('LITOTRITOR BALÍSTICO PNEUMÁTICO', 'CM-UROLIT', 'CMLIT', '80337659008', 'URL0002', '001', 'Confiance')
)
INSERT INTO public.produtos (equipamento, modelo, codigo_referencia, registro_anvisa, codigo_sapiens, derivacao, derivacao_descricao, ativo)
SELECT equipamento, modelo, codigo_referencia, registro_anvisa, codigo_sapiens, derivacao, derivacao_descricao, TRUE
FROM catalogo
ON CONFLICT (modelo, derivacao) DO UPDATE SET
  equipamento = EXCLUDED.equipamento,
  codigo_referencia = EXCLUDED.codigo_referencia,
  registro_anvisa = EXCLUDED.registro_anvisa,
  codigo_sapiens = EXCLUDED.codigo_sapiens,
  derivacao_descricao = EXCLUDED.derivacao_descricao,
  ativo = TRUE;

-- 2) Soft delete dos produtos fora do catálogo SEM ficha mestre ativa
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
  SELECT DISTINCT produto_id FROM public.fichas_mestres WHERE ativa = TRUE
)
UPDATE public.produtos p
   SET ativo = FALSE
 WHERE p.ativo = TRUE
   AND NOT EXISTS (SELECT 1 FROM catalogo c WHERE c.modelo = p.modelo AND c.derivacao = p.derivacao)
   AND p.id NOT IN (SELECT produto_id FROM produtos_com_ficha WHERE produto_id IS NOT NULL);

COMMIT;

-- =====================================================================
-- VERIFICAÇÃO (rode após o commit)
-- =====================================================================
-- Total ativos (deve dar ~87 + preservados por ficha ativa):
--   SELECT COUNT(*) FROM public.produtos WHERE ativo = TRUE;
-- Listar preservados (fora do catálogo mas com ficha ativa):
--   SELECT p.modelo, p.derivacao, p.equipamento
--     FROM public.produtos p
--     JOIN public.fichas_mestres fm ON fm.produto_id = p.id AND fm.ativa = TRUE
--    WHERE p.ativo = TRUE
--    ORDER BY p.modelo, p.derivacao;
-- Listar desativados nesta operação:
--   SELECT modelo, derivacao, equipamento FROM public.produtos WHERE ativo = FALSE ORDER BY modelo;
