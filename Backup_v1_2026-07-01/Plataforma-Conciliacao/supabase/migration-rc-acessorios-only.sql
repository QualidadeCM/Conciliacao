-- =====================================================================
-- MIGRAÇÃO — RC restrita a acessórios + flag "pode sair só na NF"
-- Confiance Medical · Plataforma de Conciliação da Produção
-- =====================================================================
-- Decisão de negócio (Maria Luiza, 29/05/2026):
--   A análise da Relação de Componentes (RC) passa a verificar APENAS:
--     1. Se os acessórios obrigatórios da Ficha Mestre estão presentes na RC;
--     2. Se o lote/série de cada acessório na RC bate com o que está na
--        etiqueta do acessório correspondente.
--
--   A BOM completa de componentes internos (placa mãe, ventoinha, gabinete,
--   módulo LED, etc.) deixa de ser cadastrada na Ficha Mestre — ela permanece
--   sob controle do FORM-GQ-0085 e demais documentos de engenharia, mas NÃO
--   é mais parte do escopo de validação da plataforma de conciliação.
--
-- Adicionalmente: alguns acessórios podem sair apenas na Nota Fiscal de
-- venda (não constam na RC do lote). Para evitar Não Conformidade falsa,
-- a Ficha Mestre passa a marcar esses casos com `pode_sair_apenas_na_nf`.
-- Quando essa flag está ativa e o acessório falta na RC, a plataforma
-- emite RESSALVA (não NC) para que o RT confirme manualmente.
--
-- COMPORTAMENTO:
-- · Idempotente — pode ser executado várias vezes sem efeitos colaterais.
-- · DESTRUTIVO sobre componentes_bom (DROP TABLE CASCADE). Os dados de BOM
--   já cadastrados (ex.: 14 componentes do CM-LED) são REMOVIDOS.
--   Justificativa documental: ISO 13485 §4.2.4 exige controle de mudança
--   de documentos. Esta migration é a evidência da mudança de escopo.
-- · Transação atômica — se algo falhar, nada é gravado.
--
-- COMO EXECUTAR:
--   1. Supabase Studio → SQL Editor → New query
--   2. Cole TODO este arquivo
--   3. Clique RUN
-- =====================================================================

BEGIN;

-- 1) Adicionar coluna pode_sair_apenas_na_nf em acessorios_aplicaveis
ALTER TABLE public.acessorios_aplicaveis
  ADD COLUMN IF NOT EXISTS pode_sair_apenas_na_nf boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.acessorios_aplicaveis.pode_sair_apenas_na_nf IS
  'Quando true, o acessório pode sair apenas na NF de venda (não consta na RC do lote). Falta na RC vira RESSALVA, não NC.';

-- 2) Remover tabela componentes_bom (CASCADE — destrói índices e FK dependentes)
DROP TABLE IF EXISTS public.componentes_bom CASCADE;

-- 3) (opcional) Conservar evidência da remoção — registra na tabela de migrations futuras.
--    Se você ainda não tem uma tabela de migrations, este comando não faz nada.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'schema_migrations'
  ) THEN
    INSERT INTO public.schema_migrations (name, executed_at)
    VALUES ('migration-rc-acessorios-only', now())
    ON CONFLICT DO NOTHING;
  END IF;
END $$;

COMMIT;

-- =====================================================================
-- VERIFICAÇÃO (opcional)
-- =====================================================================
-- Confere que componentes_bom não existe mais e que acessorios tem a flag:
-- SELECT column_name, data_type, column_default
--   FROM information_schema.columns
--  WHERE table_schema = 'public'
--    AND table_name = 'acessorios_aplicaveis'
--  ORDER BY ordinal_position;
--
-- SELECT EXISTS (
--   SELECT 1 FROM information_schema.tables
--    WHERE table_schema = 'public' AND table_name = 'componentes_bom'
-- ) AS bom_ainda_existe;
