-- =====================================================================
-- MIGRATION: Simplificação das Fichas Mestres
-- Confiance Medical · Plataforma de Conciliação da Produção
-- =====================================================================
-- Decisão de negócio (Maria Luiza, 04/06/2026):
--
-- 1. Remover campo "Aplicação Clínica" da Ficha (não é usado pela análise).
--
-- 2. Remover Seção "Inspeções e Critérios de Aceitação" inteira — a análise
--    da OP já valida medições contra Min/Max e status Aprovado/Reprovado
--    direto dos dados do Sapiens. Não há valor em duplicar isso na Ficha.
--
-- 3. Remover campo "Observações Gerais" — não é usado.
--
-- 4. SIMPLIFICAR o Roteiro do FORM-GQ-0047:
--    Antes: tabela com 16 linhas por Ficha, cada uma com marcação SIM/N/A
--           e justificativa textual.
--    Depois: array text[] com APENAS os estágios variáveis aplicáveis ao
--           produto (subconjunto dos 10 possíveis).
--    Os 4 estágios FIXOS (sempre SIM em qualquer produto) e os 2
--    CONDICIONAIS (SIM se houver doc anexado) são lógica fixa no código,
--    não precisam ficar na Ficha.
--
-- 10 estágios VARIÁVEIS possíveis (a Ficha guarda só os aplicáveis):
--   1. Separação de Componentes
--   2. Preparação de Componentes
--   3. Montagem
--   4. Fechamento da Tela
--   5. Preparação de Gabinete
--   6. Fechamento e Acabamento Gabinete Plástico
--   7. Montagem Eletrônica
--   8. Programação
--   9. Gravação
--   10. Finalização
--
-- 4 estágios FIXOS (não vão para Ficha, marcados SIM no FORM sempre):
--   - Controle de Qualidade do produto acabado
--   - Etapa de Embalagem do produto acabado
--   - Conciliação da Produção do produto acabado
--   - Verificação da rotulagem do produto com a etiqueta devidamente preenchida
--
-- 2 estágios CONDICIONAIS (marcados SIM apenas se documento anexado):
--   - Ordem de Produção de Reprocesso
--   - RNCs associados
--
-- DESTRUTIVO: apaga tabelas e colunas existentes. Dados do CM-LED
-- previamente cadastrados na Seção 5/Roteiro são perdidos. Ela precisará
-- recadastrar os estágios aplicáveis na nova Seção 4 (1 clique cada).
--
-- COMO EXECUTAR:
--   Supabase Studio → SQL Editor → New query → cole TUDO → Run
-- =====================================================================

BEGIN;

-- 1) Remove coluna "aplicacao_clinica" (Seção 1 do editor)
ALTER TABLE public.fichas_mestres DROP COLUMN IF EXISTS aplicacao_clinica;

-- 2) Remove coluna "observacoes" (Seção 8 do editor)
ALTER TABLE public.fichas_mestres DROP COLUMN IF EXISTS observacoes;

-- 3) Remove tabela "inspecoes_criterios" (Seção 5 do editor) — CASCADE
DROP TABLE IF EXISTS public.inspecoes_criterios CASCADE;

-- 4) Remove tabela "roteiro_form_gq_0047" (Seção 4 antiga) — CASCADE
DROP TABLE IF EXISTS public.roteiro_form_gq_0047 CASCADE;

-- 5) Adiciona coluna "estagios_aplicaveis" (Seção 4 nova)
ALTER TABLE public.fichas_mestres
  ADD COLUMN IF NOT EXISTS estagios_aplicaveis text[] NOT NULL DEFAULT '{}'::text[];

COMMENT ON COLUMN public.fichas_mestres.estagios_aplicaveis IS
  'Array com os nomes dos estágios variáveis aplicáveis ao produto. Valores possíveis: "Separação de Componentes", "Preparação de Componentes", "Montagem", "Fechamento da Tela", "Preparação de Gabinete", "Fechamento e Acabamento Gabinete Plástico", "Montagem Eletrônica", "Programação", "Gravação", "Finalização".';

-- 6) Pré-popular CM-LED Der. 001 com os estágios padrão dele (Separação,
--    Preparação Gabinete, Montagem Eletrônica, Finalização) caso queira manter
--    o cadastro pré-existente que já estava lá:
UPDATE public.fichas_mestres fm
   SET estagios_aplicaveis = ARRAY[
     'Separação de Componentes',
     'Preparação de Gabinete',
     'Montagem Eletrônica',
     'Finalização'
   ]
  FROM public.produtos p
 WHERE fm.produto_id = p.id
   AND p.modelo = 'CM-LED'
   AND p.derivacao = '001'
   AND fm.ativa = true;

COMMIT;

-- =====================================================================
-- VERIFICAÇÃO (rode após o commit)
-- =====================================================================
-- Confere estrutura nova:
-- SELECT column_name, data_type FROM information_schema.columns
--  WHERE table_schema = 'public' AND table_name = 'fichas_mestres'
--  ORDER BY ordinal_position;
--
-- Confere CM-LED:
-- SELECT p.modelo, p.derivacao, fm.estagios_aplicaveis
--   FROM public.produtos p
--   JOIN public.fichas_mestres fm ON fm.produto_id = p.id AND fm.ativa = true
--  WHERE p.modelo = 'CM-LED';
