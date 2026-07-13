-- =====================================================================
-- IMPORTAÇÃO DE CATÁLOGO COMPLETO + SOFT DELETE — Confiance Medical
-- =====================================================================
-- 89 produtos do catálogo Confiance (gerado em 01/06/2026 a partir do
-- Template_Fichas_Mestres preenchido por Maria Luiza Zaccur).
--
-- OPERAÇÕES:
--  1. UPSERT por (modelo, derivacao) dos 89 produtos da nova lista.
--  2. Soft delete (ativo=false) de TODOS os produtos cujo par
--     (modelo, derivacao) NÃO está na lista nova.
--     → Preserva histórico para auditoria ISO 13485 §4.2.5
--     → Produtos desativados não aparecem mais nas queries da plataforma
--       (que filtram por ativo=true), mas continuam no banco para
--       rastreabilidade de análises antigas.
--
-- DUPLICATAS RESOLVIDAS:
--   CM-OTC0050L (LAP50  / LAP0016) → derivação 001 'Padrão'
--   CM-OTC0050L (LAP50P / LAP0035) → derivação 002 'Plus'
--   CM-OTC0051L (LAP51  / LAP0017) → derivação 001 'Padrão'
--   CM-OTC0051L (LAP51P / LAP0034) → derivação 002 'Plus'
--
-- Próximos cadastros de produtos serão feitos pela plataforma (UI),
-- não mais por importação SQL.
--
-- PRÉ-REQUISITO: migration-derivacao.sql já executada (UNIQUE composto
-- (modelo, derivacao) presente, coluna derivacao_descricao existe).
--
-- COMO EXECUTAR:
--   Supabase Studio → SQL Editor → New query → cole TUDO → Run
-- =====================================================================

BEGIN;

-- =====================================================================
-- 1) UPSERT dos 89 produtos da nova lista
-- =====================================================================
INSERT INTO public.produtos
  (equipamento, modelo, codigo_referencia, registro_anvisa,
   codigo_sapiens, derivacao, derivacao_descricao, ativo)
VALUES
  ('FONTE DE LUZ LED', 'CM-LED', 'LEDT', '80337650008', 'FNT0001', '001', 'CONFIANCE', true),  ('FONTE DE LUZ LED', 'CM-LED', 'LEDT', '80337650008', 'FNT0001', '002', 'Com Fluorescência', true),  ('ACESSÓRIO PARA ESCAPE DE FUMAÇA', 'CM-100', 'CM100', '80337650003', 'ASP0001', '001', 'CONFIANCE', true),  ('ENDOSCÓPIO RÍGIDO PARA ARTROSCOPIA', 'CM-OTC0010A', 'ART10', '80337659009', 'ART0001', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA ARTROSCOPIA', 'CM-OTC0011A', 'ART11', '80337659009', 'ART0002', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA ARTROSCOPIA', 'CM-OTC0012A', 'ART12', '80337659009', 'ART0003', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA ARTROSCOPIA', 'CM-OTC0019A', 'ART19', '80337659009', 'ART0010', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA ARTROSCOPIA', 'CM-OTC0041A', 'ART41', '80337659009', 'ART0014', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA ARTROSCOPIA', 'CM-OTC0042A', 'ART42', '80337659009', 'ART0015', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA ARTROSCOPIA', 'CM-OTC0043A', 'ART43', '80337659009', 'ART0016', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA CISTOSCOPIA', 'CM-OTC0026C', 'CIS26', '80337659013', 'CIS0001', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA CISTOSCOPIA', 'CM-OTC0027C', 'CIS27', '80337659013', 'CIS0002', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA CISTOSCOPIA', 'CM-OTC0028C', 'CIS28', '80337659013', 'CIS0003', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA CISTOSCOPIA', 'CM-OTC0029C', 'CIS29', '80337659013', 'CIS0004', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA CISTOSCOPIA', 'CM-OTC0030C', 'CIS30', '80337659013', 'CIS0005', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA CISTOSCOPIA', 'CM-OTC0031C', 'CIS31', '80337659013', 'CIS0006', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA CISTOSCOPIA', 'CM-OTC0032C', 'CIS32', '80337659013', 'CIS0007', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA CISTOSCOPIA', 'CM-OTC0033C', 'CIS33', '80337659013', 'CIS0008', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA CISTOSCOPIA', 'CM-OTC0056C', 'CIS56', '80337659013', 'CIS0009', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA CISTOSCOPIA', 'CM-OTC0057C', 'CIS57', '80337659013', 'CIS0010', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA CISTOSCOPIA', 'CM-OTC0058C', 'CIS58', '80337659013', 'CIS0011', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA HISTEROSCOPIA', 'CM-OTC0026H', 'HIS26', '80337659012', 'HIS0001', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA HISTEROSCOPIA', 'CM-OTC0027H', 'HIS27', '80337659012', 'HIS0002', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA HISTEROSCOPIA', 'CM-OTC0028H', 'HIS28', '80337659012', 'HIS0003', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA HISTEROSCOPIA', 'CM-OTC0029H', 'HIS29', '80337659012', 'HIS0004', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA HISTEROSCOPIA', 'CM-OTC0030H', 'HIS30', '80337659012', 'HIS0005', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA HISTEROSCOPIA', 'CM-OTC0031H', 'HIS31', '80337659012', 'HIS0006', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA HISTEROSCOPIA', 'CM-OTC0032H', 'HIS32', '80337659012', 'HIS0007', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA HISTEROSCOPIA', 'CM-OTC0033H', 'HIS33', '80337659012', 'HIS0008', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA HISTEROSCOPIA', 'CM-OTC0056H', 'HIS56', '80337659012', 'HIS0009', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA HISTEROSCOPIA', 'CM-OTC0057H', 'HIS57', '80337659012', 'HIS0010', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA HISTEROSCOPIA', 'CM-OTC0058H', 'HIS58', '80337659012', 'HIS0011', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA LAPAROSCOPIA', 'CM-OTC0004L', 'LAP04', '80337659015', 'LAP0004', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA LAPAROSCOPIA', 'CM-OTC0005L', 'LAP05', '80337659015', 'LAP0005', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA LAPAROSCOPIA', 'CM-OTC0050L', 'LAP50', '80337659015', 'LAP0016', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA LAPAROSCOPIA', 'CM-OTC0051L', 'LAP51', '80337659015', 'LAP0017', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA LAPAROSCOPIA', 'CM-OTC0059L', 'LAP59', '80337659015', 'LAP0022', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA LAPAROSCOPIA', 'CM-OTC0060L', 'LAP60', '80337659015', 'LAP0023', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA LAPAROSCOPIA', 'CM-OTC0065L', 'LAP65', '80337659015', 'LAP0028', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA LAPAROSCOPIA', 'CM-OTC0066L', 'LAP66', '80337659015', 'LAP0029', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA LAPAROSCOPIA', 'CM-OTC0051L', 'LAP51P', '80337659015', 'LAP0034', '002', 'Plus', true),  ('ENDOSCÓPIO RÍGIDO PARA LAPAROSCOPIA', 'CM-OTC0050L', 'LAP50P', '80337659015', 'LAP0035', '002', 'Plus', true),  ('ENDOSCÓPIO RÍGIDO PARA NASOFARINGOLARINGOSCOPIA', 'CM-OTC0010N', 'NAS10', '80337659010', 'NAS0001', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA NASOFARINGOLARINGOSCOPIA', 'CM-OTC0011N', 'NAS11', '80337659010', 'NAS0002', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA NASOFARINGOLARINGOSCOPIA', 'CM-OTC0012N', 'NAS12', '80337659010', 'NAS0003', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA NASOFARINGOLARINGOSCOPIA', 'CM-OTC0019N', 'NAS19', '80337659010', 'NAS0008', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA NASOFARINGOLARINGOSCOPIA', 'CM-OTC0024N', 'NAS24', '80337659010', 'NAS0013', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA NASOFARINGOLARINGOSCOPIA', 'CM-OTC0041N', 'NAS41', '80337659010', 'NAS0015', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA NASOFARINGOLARINGOSCOPIA', 'CM-OTC0042N', 'NAS42', '80337659010', 'NAS0016', '001', 'Padrão', true),  ('ENDOSCÓPIO RÍGIDO PARA NASOFARINGOLARINGOSCOPIA', 'CM-OTC0043N', 'NAS43', '80337659010', 'NAS0017', '001', 'Padrão', true),  ('INSUFLADOR DE CO2', 'CM-40L', 'CM40T', '80337650003', 'INS0002', '004', 'Laparoscopia', true),  ('INSUFLADOR DE CO2', 'CM-40L', 'CM40T', '80337650003', 'INS0002', '005', 'Laparoscopia + Cardio', true),  ('INSUFLADOR DE CO2', 'CM-40L', 'CM40T', '80337650003', 'INS0002', '006', 'Laparoscopia + Cardio + Endoscopia', true),  ('INSUFLADOR DE CO2', 'CM-40L', 'CM40T', '80337650003', 'INS0002', '007', 'Endoscopia', true),  ('INSUFLADOR DE CO2', 'CM-40L', 'CM40T', '80337650003', 'INS0002', '008', 'Laparoscopia + Datalogger', true),  ('INSUFLADOR DE CO2', 'CM-40L', 'CM40T', '80337650003', 'INS0002', '009', 'Laparoscopia + Cardio + Datalogger', true),  ('INSUFLADOR DE CO2', 'CM-40L', 'CM40T', '80337650003', 'INS0002', '010', 'Laparoscopia + Cardio + Endoscopia + Datalogger', true),  ('INSUFLADOR DE CO2', 'CM-40L', 'CM40T', '80337650003', 'INS0002', '011', 'Endoscopia + Datalogger', true),  ('INSUFLADOR DE CO2 PARA ENDOSCOPIA', 'CM-ENDOCO2', 'CMEND', '80337650010', 'INS0003', '001', 'CONFIANCE', true),  ('INSUFLADOR DE LÍQUIDO PARA ENDOSCOPIA', 'CM-FLOW', 'CMFLOW', '80337659004', 'INS0004', '001', 'CONFIANCE', true),  ('MICROCÂMERA CM', 'CM-CAM', 'CMCAM', '80337650005', 'CAM0005', '013', 'Sem gravação e sem os botões da cabeça', true),  ('MICROCÂMERA CM', 'CM-CAM', 'CMCAM', '80337650005', 'CAM0005', '014', 'Sem gravação e com os botões da cabeça', true),  ('MICROCÂMERA CM', 'CM-CAM', 'CMCAM', '80337650005', 'CAM0005', '015', 'Com gravação e sem os botões da cabeça.', true),  ('MICROCÂMERA CM', 'CM-CAM', 'CMCAM', '80337650005', 'CAM0005', '016', 'Com gravação e com os botões da cabeça.', true),  ('MICROCÂMERA CM', 'CM-SCAM', 'SCFHDT', '80337650005', 'CAM0002', '010', '2 DVI + GRAVAÇÃO FHD', true),  ('MICROCÂMERA CM', 'CM-SCAM', 'SCFHDT', '80337650005', 'CAM0002', '011', '2 DVI + ANALÓGICO + GRAVAÇÃO FHD', true),  ('MICROCÂMERA CM', 'CM-SCAM', 'SCFHDT', '80337650005', 'CAM0002', '012', '2 DVI + ANALOGICO + GRAVACAO FHD + SDI', true),  ('MICROCÂMERA CM', 'CM-SCAM', 'SC4KT', '80337650005', 'CAM0006', '002', 'COM GRAVAÇÃO', true),  ('MICROCÂMERA CM', 'CM-SCAM', 'SC4KT', '80337650005', 'CAM0006', '018', 'Com gravação e com fluorescência', true),  ('MICROCÂMERA CM', 'CM-SCAM3', 'SC34KT', '80337650005', 'CAM0004', '002', 'COM GRAVAÇÃO', true),  ('MICROCÂMERA CM', 'CM-SCAM3', 'SC3FHDT', '80337650005', 'CAM0003', '010', '2 DVI + GRAVAÇÃO FHD', true),  ('MICROCÂMERA CM', 'CM-SCAM3', 'SC3FHDT', '80337650005', 'CAM0003', '011', '2 DVI + ANALÓGICO + GRAVAÇÃO FHD', true),  ('MICROCÂMERA CM', 'CM-SCAM3', 'SC3FHDT', '80337650005', 'CAM0003', '012', '2 DVI + ANALOGICO + GRAVACAO FHD + SDI', true),  ('MONITOR PROFISSIONAL GRAU MÉDICO', 'CM-CINEMED-27F', 'CM27FC', '80337650007', 'MNT0014', '013', 'DVI', true),  ('MONITOR PROFISSIONAL GRAU MÉDICO', 'CM-CINEMED-27F', 'CM27FC', '80337650007', 'MNT0014', '014', 'DVI Touch Screen', true),  ('MONITOR PROFISSIONAL GRAU MÉDICO', 'CM-CINEMED-27F', 'CM27FC', '80337650007', 'MNT0014', '016', 'SDI', true),  ('MONITOR PROFISSIONAL GRAU MÉDICO', 'CM-CINEMED-27F', 'CM27FC', '80337650007', 'MNT0014', '017', 'SDI PIP', true),  ('MONITOR PROFISSIONAL GRAU MÉDICO', 'CM-CINEMED-32F', 'CM32FC', '80337650007', 'MNT0017', '015', 'HDMI', true),  ('MONITOR PROFISSIONAL GRAU MÉDICO', 'CM-CINEMED-32F', 'CM32FC', '80337650007', 'MNT0017', '017', 'SDI PIP', true),  ('MONITOR PROFISSIONAL GRAU MÉDICO', 'CM-CINEMED-42F', 'CM42FC', '80337650007', 'MNT0019', '001', 'CONFIANCE', true),  ('SISTEMA DE GRAVAÇÃO DE IMAGENS', 'CM-RECMASTER 3', 'REC3FHD', '80337659002', 'GRA0003', '001', 'Full HD', true),  ('SISTEMA DE GRAVAÇÃO DE IMAGENS', 'CM-RECMASTER 3', 'REC3UHD', '80337659002', 'GRA0004', '002', '4K', true),  ('SISTEMA INTEGRADO PARA ENDOSCOPIA', 'CM-STATION', 'CMST', '80337659003', 'STB0001', '001', 'Full HD', true),  ('SISTEMA INTEGRADO PARA ENDOSCOPIA', 'CM-STATION', 'CMST', '80337659003', 'STB0001', '002', 'Full HD Plus', true),  ('SISTEMA INTEGRADO PARA ENDOSCOPIA', 'CM-STATION', 'CMST', '80337659003', 'STB0001', '003', '4K', true),  ('SISTEMA INTEGRADO PARA ENDOSCOPIA', 'CM-STATION27', 'CMST27', '80337659003', 'SIC0002', '001', 'Full HD', true),  ('SISTEMA INTEGRADO PARA ENDOSCOPIA', 'CM-STATION27', 'CMST27', '80337659003', 'SIC0002', '002', 'Full HD Plus', true),  ('SISTEMA DE VÍDEO URETERORRENOSCÓPIO DIGITAL', 'CM-UROVIEW', 'CMFLEX', '80337659007', 'URL0001', '001', 'Confiance', true),  ('LITOTRITOR BALÍSTICO PNEUMÁTICO', 'CM-UROLIT', 'CMLIT', '80337659008', 'URL0002', '001', 'Confiance', true)
ON CONFLICT (modelo, derivacao) DO UPDATE
  SET equipamento         = EXCLUDED.equipamento,
      codigo_referencia   = EXCLUDED.codigo_referencia,
      registro_anvisa     = EXCLUDED.registro_anvisa,
      codigo_sapiens      = EXCLUDED.codigo_sapiens,
      derivacao_descricao = EXCLUDED.derivacao_descricao,
      ativo               = true,
      updated_at          = now();

-- =====================================================================
-- 2) Soft delete (ativo=false) dos produtos FORA da lista nova
-- =====================================================================
-- A CTE `catalogo_atual` contém os 89 pares (modelo, derivacao) da nova
-- lista. Tudo que está em public.produtos e NÃO está nessa CTE vira inativo.
WITH catalogo_atual (modelo, derivacao) AS (
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
  ('CM-OTC0051L', '002'),
  ('CM-OTC0050L', '002'),
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
  ('CM-CINEMED-27F', '013'),
  ('CM-CINEMED-27F', '014'),
  ('CM-CINEMED-27F', '016'),
  ('CM-CINEMED-27F', '017'),
  ('CM-CINEMED-32F', '015'),
  ('CM-CINEMED-32F', '017'),
  ('CM-CINEMED-42F', '001'),
  ('CM-RECMASTER 3', '001'),
  ('CM-RECMASTER 3', '002'),
  ('CM-STATION', '001'),
  ('CM-STATION', '002'),
  ('CM-STATION', '003'),
  ('CM-STATION27', '001'),
  ('CM-STATION27', '002'),
  ('CM-UROVIEW', '001'),
  ('CM-UROLIT', '001')
)
UPDATE public.produtos AS p
   SET ativo      = false,
       updated_at = now()
  FROM (SELECT modelo, derivacao FROM catalogo_atual) AS atual
 WHERE p.ativo = true
   AND NOT EXISTS (
     SELECT 1 FROM catalogo_atual c
      WHERE c.modelo = p.modelo
        AND c.derivacao = p.derivacao
   );

COMMIT;

-- =====================================================================
-- Verificação (rode após o commit)
-- =====================================================================
-- Total ativos (esperado: 89):
--   SELECT count(*) FROM public.produtos WHERE ativo = true;
--
-- Total inativos (soft-deleted nesta operação):
--   SELECT count(*) FROM public.produtos WHERE ativo = false;
--
-- Listar inativos para conferência:
--   SELECT modelo, derivacao, equipamento, updated_at
--     FROM public.produtos
--    WHERE ativo = false
--    ORDER BY updated_at DESC;
