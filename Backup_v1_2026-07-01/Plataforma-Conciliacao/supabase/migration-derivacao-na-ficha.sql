-- =====================================================================
-- MIGRATION: Mover derivação de produtos → fichas_mestres (idempotente)
-- Confiance Medical · 18/06/2026 (v3 — idempotente, segura pra re-rodar)
-- =====================================================================
-- Refactor: a derivação deixa de ser uma propriedade do produto e passa
-- a ser uma propriedade da Ficha Mestre. Cada produto/modelo aparece UMA
-- vez no catálogo. Cada Ficha Mestre define sua própria derivação.
--
-- Esta versão é IDEMPOTENTE: pode ser rodada várias vezes sem erros.
-- Cada passo verifica se já foi feito antes de executar.
-- =====================================================================

BEGIN;

-- 0. Remove constraints e índices únicos antigos de fichas_mestres
DO $$
DECLARE c RECORD;
BEGIN
  FOR c IN
    SELECT conname FROM pg_constraint
     WHERE conrelid = 'public.fichas_mestres'::regclass
       AND contype = 'u'
  LOOP
    EXECUTE 'ALTER TABLE public.fichas_mestres DROP CONSTRAINT IF EXISTS ' || quote_ident(c.conname);
    RAISE NOTICE 'Removida UNIQUE de fichas_mestres: %', c.conname;
  END LOOP;
END $$;

DO $$
DECLARE i RECORD;
BEGIN
  FOR i IN
    SELECT (indexrelid::regclass)::text AS idx_name
      FROM pg_index
     WHERE indrelid = 'public.fichas_mestres'::regclass
       AND indisunique
       AND NOT indisprimary
  LOOP
    EXECUTE 'DROP INDEX IF EXISTS ' || i.idx_name;
    RAISE NOTICE 'Removido índice único de fichas_mestres: %', i.idx_name;
  END LOOP;
END $$;

-- 1. Adiciona colunas derivacao e derivacao_descricao em fichas_mestres
ALTER TABLE public.fichas_mestres ADD COLUMN IF NOT EXISTS derivacao TEXT;
ALTER TABLE public.fichas_mestres ADD COLUMN IF NOT EXISTS derivacao_descricao TEXT;

-- 2. Copia derivação do produto para ficha — APENAS se o produto ainda tem essa coluna
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'produtos' AND column_name = 'derivacao'
  ) THEN
    EXECUTE $sql$
      UPDATE public.fichas_mestres f
         SET derivacao = COALESCE(f.derivacao, p.derivacao, '000'),
             derivacao_descricao = COALESCE(f.derivacao_descricao, p.derivacao_descricao, 'Padrão')
        FROM public.produtos p
       WHERE p.id = f.produto_id;
    $sql$;
    RAISE NOTICE 'Derivações copiadas de produtos para fichas';
  ELSE
    RAISE NOTICE 'Coluna produtos.derivacao já foi removida — pulando passo 2';
  END IF;
END $$;

-- Backfill: qualquer ficha ainda sem derivacao recebe valor padrão
UPDATE public.fichas_mestres
   SET derivacao = '000'
 WHERE derivacao IS NULL OR derivacao = '';
UPDATE public.fichas_mestres
   SET derivacao_descricao = 'Padrão'
 WHERE derivacao_descricao IS NULL OR derivacao_descricao = '';

-- 3, 4, 5, 6: Consolidação de produtos duplicados (só se ainda houver duplicatas)
DO $$
DECLARE dups INT;
BEGIN
  SELECT COUNT(*) - COUNT(DISTINCT modelo) INTO dups FROM public.produtos;
  IF dups > 0 THEN
    -- Cria tabela temporária de representantes
    CREATE TEMP TABLE _representantes ON COMMIT DROP AS
    SELECT DISTINCT ON (modelo) modelo, id AS representante_id
      FROM public.produtos
     ORDER BY modelo, id;

    -- Migra fichas para o representante de cada modelo
    UPDATE public.fichas_mestres f
       SET produto_id = r.representante_id
      FROM _representantes r
      JOIN public.produtos p ON p.modelo = r.modelo
     WHERE f.produto_id = p.id
       AND p.id <> r.representante_id;

    -- Migra análises (preserva histórico)
    UPDATE public.analises a
       SET produto_id = r.representante_id
      FROM _representantes r
      JOIN public.produtos p ON p.modelo = r.modelo
     WHERE a.produto_id = p.id
       AND p.id <> r.representante_id;

    -- Deleta produtos duplicados
    DELETE FROM public.produtos p
     WHERE p.id NOT IN (SELECT representante_id FROM _representantes);

    RAISE NOTICE 'Consolidados % produtos duplicados', dups;
  ELSE
    RAISE NOTICE 'Sem produtos duplicados — pulando consolidação';
  END IF;
END $$;

-- 7. Remove constraints UNIQUE antigas de produtos
DO $$
DECLARE c RECORD;
BEGIN
  FOR c IN
    SELECT conname FROM pg_constraint
     WHERE conrelid = 'public.produtos'::regclass
       AND contype = 'u'
       AND conname <> 'produtos_modelo_unique'
  LOOP
    EXECUTE 'ALTER TABLE public.produtos DROP CONSTRAINT IF EXISTS ' || quote_ident(c.conname);
    RAISE NOTICE 'Removida UNIQUE de produtos: %', c.conname;
  END LOOP;
END $$;

-- 8. Cria UNIQUE em modelo (idempotente)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conrelid = 'public.produtos'::regclass
       AND conname = 'produtos_modelo_unique'
  ) THEN
    ALTER TABLE public.produtos ADD CONSTRAINT produtos_modelo_unique UNIQUE (modelo);
    RAISE NOTICE 'Criada UNIQUE produtos_modelo_unique';
  END IF;
END $$;

-- 9. Remove colunas derivacao e derivacao_descricao de produtos (idempotente)
ALTER TABLE public.produtos DROP COLUMN IF EXISTS derivacao;
ALTER TABLE public.produtos DROP COLUMN IF EXISTS derivacao_descricao;

-- 10. Cria índice único parcial: 1 ficha ativa por (produto_id, derivacao)
DROP INDEX IF EXISTS uniq_ficha_ativa_produto_derivacao;
CREATE UNIQUE INDEX uniq_ficha_ativa_produto_derivacao
  ON public.fichas_mestres (produto_id, derivacao)
  WHERE ativa = TRUE;

COMMIT;

-- =====================================================================
-- VERIFICAÇÃO (rode após o commit — descomente as queries que quiser usar)
-- =====================================================================
-- 1) Colunas atuais de produtos (não deve ter derivação):
--   SELECT column_name FROM information_schema.columns
--    WHERE table_schema = 'public' AND table_name = 'produtos' ORDER BY ordinal_position;
--
-- 2) Colunas atuais de fichas_mestres (deve ter derivacao e derivacao_descricao):
--   SELECT column_name FROM information_schema.columns
--    WHERE table_schema = 'public' AND table_name = 'fichas_mestres'
--      AND column_name LIKE 'derivacao%';
--
-- 3) Contagem de produtos:
--   SELECT COUNT(*) FROM public.produtos;
--
-- 4) Contagem de fichas (preservadas):
--   SELECT COUNT(*) FROM public.fichas_mestres;
--
-- 5) Cada ficha tem derivação preenchida agora? (deve dar 0)
--   SELECT COUNT(*) FROM public.fichas_mestres WHERE derivacao IS NULL OR derivacao = '';
--
-- 6) Produtos com múltiplas fichas (modelos que tinham várias derivações):
--   SELECT p.modelo, COUNT(f.id) AS num_fichas
--     FROM public.produtos p
--     JOIN public.fichas_mestres f ON f.produto_id = p.id AND f.ativa = TRUE
--    GROUP BY p.modelo
--    HAVING COUNT(f.id) > 1
--    ORDER BY p.modelo;
