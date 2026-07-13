-- ====================================================================
-- DUMP DE DADOS DO SUPABASE — Plataforma Conciliação v1
-- Data: 01/07/2026
-- Como usar:
--   1. Abra Supabase Studio → SQL Editor
--   2. Rode CADA bloco abaixo (um SELECT por vez)
--   3. Copie o resultado da coluna "insert_sql" e salve em dados_YYYY-MM-DD.sql
--   4. Guarde esse arquivo junto do backup do sistema
--
-- Alternativa mais rápida (recomendada se tiver acesso ao pg_dump):
--   pg_dump -h <host> -U postgres -d postgres --data-only \
--     -t produtos -t fichas_mestres -t acessorios_aplicaveis -t analises \
--     -t analises_apontamentos > dados_2026-07-01.sql
-- ====================================================================

-- =========================
-- BLOCO 1 — produtos
-- =========================
SELECT
  'INSERT INTO produtos (id, equipamento, modelo, codigo_referencia, codigo_sapiens, registro_anvisa, ativo, created_at) VALUES (' ||
    quote_literal(id) || ', ' ||
    quote_nullable(equipamento) || ', ' ||
    quote_nullable(modelo) || ', ' ||
    quote_nullable(codigo_referencia) || ', ' ||
    quote_nullable(codigo_sapiens) || ', ' ||
    quote_nullable(registro_anvisa) || ', ' ||
    ativo::text || ', ' ||
    quote_literal(created_at::text) ||
    ');' AS insert_sql
FROM produtos
ORDER BY modelo;

-- =========================
-- BLOCO 2 — fichas_mestres
-- =========================
SELECT
  'INSERT INTO fichas_mestres (id, produto_id, versao, ativa, derivacao, derivacao_descricao, nome_comercial, convencao_nro_serie, exemplo_nro_serie, data_concessao_anvisa, razao_social, cnpj, endereco_fabrica, telefone, responsavel_tecnico, crea_rt, responsavel_legal, estagios_aplicaveis, estagios_com_inspecao, regras_negocio, created_at) VALUES (' ||
    quote_literal(id) || ', ' ||
    quote_literal(produto_id) || ', ' ||
    versao::text || ', ' ||
    ativa::text || ', ' ||
    quote_nullable(derivacao) || ', ' ||
    quote_nullable(derivacao_descricao) || ', ' ||
    quote_nullable(nome_comercial) || ', ' ||
    quote_nullable(convencao_nro_serie) || ', ' ||
    quote_nullable(exemplo_nro_serie) || ', ' ||
    quote_nullable(data_concessao_anvisa) || ', ' ||
    quote_nullable(razao_social) || ', ' ||
    quote_nullable(cnpj) || ', ' ||
    quote_nullable(endereco_fabrica) || ', ' ||
    quote_nullable(telefone) || ', ' ||
    quote_nullable(responsavel_tecnico) || ', ' ||
    quote_nullable(crea_rt) || ', ' ||
    quote_nullable(responsavel_legal) || ', ' ||
    quote_literal(COALESCE(estagios_aplicaveis, ARRAY[]::text[])::text) || '::text[], ' ||
    quote_literal(COALESCE(estagios_com_inspecao, '[]'::jsonb)::text) || '::jsonb, ' ||
    quote_literal(COALESCE(regras_negocio, '[]'::jsonb)::text) || '::jsonb, ' ||
    quote_literal(created_at::text) ||
    ');' AS insert_sql
FROM fichas_mestres
ORDER BY created_at;

-- =========================
-- BLOCO 3 — acessorios_aplicaveis
-- =========================
SELECT
  'INSERT INTO acessorios_aplicaveis (id, ficha_id, ordem, descricao, codigo_sapiens, obrigatorio, is_fabricante_confiance, esteril, pode_sair_apenas_na_nf) VALUES (' ||
    quote_literal(id) || ', ' ||
    quote_literal(ficha_id) || ', ' ||
    COALESCE(ordem, 0)::text || ', ' ||
    quote_nullable(descricao) || ', ' ||
    quote_nullable(codigo_sapiens) || ', ' ||
    COALESCE(obrigatorio, true)::text || ', ' ||
    COALESCE(is_fabricante_confiance, false)::text || ', ' ||
    COALESCE(esteril, false)::text || ', ' ||
    COALESCE(pode_sair_apenas_na_nf, false)::text ||
    ');' AS insert_sql
FROM acessorios_aplicaveis
ORDER BY ficha_id, ordem;

-- =========================
-- BLOCO 4 — analises (só metadados; parecer_completo é JSONB grande)
-- =========================
SELECT
  'INSERT INTO analises (id, produto_id, ficha_id, numero_op, numero_serie, nome_produto, modelo, registro_anvisa, status, parecer_resumo, parecer_completo, finalizada_em, created_at, created_by, origem, analise_origem_id, pacote_zip_path) VALUES (' ||
    quote_literal(id) || ', ' ||
    quote_nullable(produto_id::text) || ', ' ||
    quote_nullable(ficha_id::text) || ', ' ||
    quote_nullable(numero_op) || ', ' ||
    quote_nullable(numero_serie) || ', ' ||
    quote_nullable(nome_produto) || ', ' ||
    quote_nullable(modelo) || ', ' ||
    quote_nullable(registro_anvisa) || ', ' ||
    quote_nullable(status) || ', ' ||
    quote_nullable(parecer_resumo) || ', ' ||
    quote_literal(COALESCE(parecer_completo, '{}'::jsonb)::text) || '::jsonb, ' ||
    quote_nullable(finalizada_em::text) || ', ' ||
    quote_literal(created_at::text) || ', ' ||
    quote_nullable(created_by::text) || ', ' ||
    quote_nullable(origem) || ', ' ||
    quote_nullable(analise_origem_id::text) || ', ' ||
    quote_nullable(pacote_zip_path) ||
    ');' AS insert_sql
FROM analises
ORDER BY created_at;

-- =========================
-- BLOCO 5 — analises_apontamentos
-- =========================
SELECT
  'INSERT INTO analises_apontamentos (id, analise_id, categoria, severidade, camada, descricao, acao_esperada, referencia, justificativa, justificada_em, justificada_por, ordem) VALUES (' ||
    quote_literal(id) || ', ' ||
    quote_literal(analise_id) || ', ' ||
    quote_nullable(categoria) || ', ' ||
    quote_nullable(severidade) || ', ' ||
    COALESCE(camada, 0)::text || ', ' ||
    quote_nullable(descricao) || ', ' ||
    quote_nullable(acao_esperada) || ', ' ||
    quote_nullable(referencia) || ', ' ||
    quote_nullable(justificativa) || ', ' ||
    quote_nullable(justificada_em::text) || ', ' ||
    quote_nullable(justificada_por) || ', ' ||
    COALESCE(ordem, 0)::text ||
    ');' AS insert_sql
FROM analises_apontamentos
ORDER BY analise_id, ordem;

-- =========================
-- BLOCO 6 — CONTAGEM (sanity check)
-- =========================
SELECT
  (SELECT COUNT(*) FROM produtos)               AS produtos,
  (SELECT COUNT(*) FROM fichas_mestres)         AS fichas_mestres,
  (SELECT COUNT(*) FROM acessorios_aplicaveis)  AS acessorios,
  (SELECT COUNT(*) FROM analises)               AS analises,
  (SELECT COUNT(*) FROM analises_apontamentos)  AS apontamentos;
