-- =====================================================================
-- IMPORTAÇÃO: Ficha Mestre CM-LED Derivação 001 (dados oficiais do PDF)
-- Confiance Medical · Plataforma de Conciliação da Produção
-- =====================================================================
-- Este script importa a Ficha Mestre completa do CM-LED Derivação 001
-- conforme extraída do PDF oficial "Ficha_Mestre_CM-LED.pdf".
--
-- COMPORTAMENTO:
-- · Idempotente — pode ser executado várias vezes sem efeitos colaterais.
-- · AUTO-MIGRATION: o script faz primeiro a migration de derivação
--   (adiciona derivacao_descricao, troca unique de modelo para o par
--   modelo+derivacao). Se já estiver migrado, não faz nada.
-- · Versionamento: marca a ficha mestre ATIVA atual como inativa
--   (preserva histórico para auditoria ISO 13485 §4.2.5) e cria uma
--   nova ficha versão = max(versao)+1, ATIVA.
-- · Dependentes (acessórios, roteiro, inspeções, BOM) são SEMPRE
--   vinculados à ficha nova — as antigas permanecem vinculadas à ficha
--   anterior (inativa) para rastreabilidade.
-- · Tudo em transação atômica — se algo falhar, nada é gravado.
--
-- COMO EXECUTAR:
--   1. Abra o Supabase Studio do seu projeto
--   2. Vá em SQL Editor → New query
--   3. Cole TODO este arquivo
--   4. Clique em RUN
--   5. Confira o NOTICE no final ("Importação concluída")
-- =====================================================================

BEGIN;

-- =====================================================================
-- BLOCO 0 — MIGRATION DE DERIVAÇÃO (auto-aplicada se faltar)
-- =====================================================================
-- Garante que existe a coluna derivacao_descricao e que a chave única
-- da tabela `produtos` é o par (modelo, derivacao) em vez de só (modelo).
-- Cada bloco é idempotente: roda sem efeito se já estiver aplicado.

-- 0.1) Adicionar coluna derivacao se faltar (compatibilidade com schemas antigos)
ALTER TABLE public.produtos
  ADD COLUMN IF NOT EXISTS derivacao text;

-- 0.2) Adicionar coluna derivacao_descricao se faltar
ALTER TABLE public.produtos
  ADD COLUMN IF NOT EXISTS derivacao_descricao text;

-- 0.3) Backfill: produtos sem derivação recebem "000" / "Padrão"
UPDATE public.produtos
   SET derivacao = COALESCE(NULLIF(TRIM(derivacao), ''), '000')
 WHERE derivacao IS NULL OR TRIM(derivacao) = '';

UPDATE public.produtos
   SET derivacao_descricao = COALESCE(NULLIF(TRIM(derivacao_descricao), ''), 'Padrão')
 WHERE derivacao_descricao IS NULL OR TRIM(derivacao_descricao) = '';

-- 0.4) Normalizar derivações para 3 dígitos (zero-pad)
UPDATE public.produtos
   SET derivacao = LPAD(REGEXP_REPLACE(derivacao, '\D', '', 'g'), 3, '0')
 WHERE derivacao ~ '^\d{1,3}$' AND LENGTH(derivacao) < 3;

-- 0.5) Tornar NOT NULL e aplicar defaults
ALTER TABLE public.produtos
  ALTER COLUMN derivacao SET NOT NULL,
  ALTER COLUMN derivacao_descricao SET NOT NULL,
  ALTER COLUMN derivacao SET DEFAULT '000',
  ALTER COLUMN derivacao_descricao SET DEFAULT 'Padrão';

-- 0.6) Remover unique antiga de "modelo" (se ainda existir só do `modelo`)
DO $$
DECLARE
  rec record;
BEGIN
  FOR rec IN
    SELECT conname
      FROM pg_constraint
     WHERE conrelid = 'public.produtos'::regclass
       AND contype = 'u'
       AND pg_get_constraintdef(oid) ILIKE '%(modelo)%'
       AND pg_get_constraintdef(oid) NOT ILIKE '%derivacao%'
  LOOP
    EXECUTE FORMAT('ALTER TABLE public.produtos DROP CONSTRAINT %I', rec.conname);
    RAISE NOTICE 'Constraint antiga "%": removida.', rec.conname;
  END LOOP;
END $$;

-- 0.7) Criar unique composto (modelo, derivacao)
DO $$ BEGIN
  ALTER TABLE public.produtos
    ADD CONSTRAINT uniq_produto_modelo_derivacao UNIQUE (modelo, derivacao);
EXCEPTION
  WHEN duplicate_table THEN NULL;
  WHEN duplicate_object THEN NULL;
END $$;

-- 0.8) Índices auxiliares
CREATE INDEX IF NOT EXISTS idx_produtos_codigo_sapiens_derivacao
  ON public.produtos(codigo_sapiens, derivacao);
CREATE INDEX IF NOT EXISTS idx_produtos_derivacao
  ON public.produtos(derivacao);

-- =====================================================================
-- BLOCO 1 — IMPORTAÇÃO DA FICHA
-- =====================================================================

DO $$
DECLARE
  v_produto_id  uuid;
  v_old_ficha   uuid;
  v_new_ficha   uuid;
  v_new_versao  int;
BEGIN
  -- =================================================================
  -- 1) PRODUTO — UPSERT do par (modelo, derivacao)
  -- =================================================================
  INSERT INTO public.produtos
    (equipamento, modelo, codigo_referencia, registro_anvisa,
     codigo_sapiens, derivacao, derivacao_descricao, ativo)
  VALUES
    ('FONTE DE LUZ LED', 'CM-LED', 'LEDT', '80337650008',
     'FNT0001', '001', 'Fonte de Luz Led - CM-LED - CONFIANCE', true)
  ON CONFLICT (modelo, derivacao) DO UPDATE
    SET equipamento         = EXCLUDED.equipamento,
        codigo_referencia   = EXCLUDED.codigo_referencia,
        registro_anvisa     = EXCLUDED.registro_anvisa,
        codigo_sapiens      = EXCLUDED.codigo_sapiens,
        derivacao_descricao = EXCLUDED.derivacao_descricao,
        ativo               = true,
        updated_at          = now();

  SELECT id INTO v_produto_id
    FROM public.produtos
   WHERE modelo = 'CM-LED' AND derivacao = '001';

  IF v_produto_id IS NULL THEN
    RAISE EXCEPTION 'Falha ao inserir/recuperar o produto CM-LED Derivação 001.';
  END IF;

  -- =================================================================
  -- 2) FICHA MESTRE — versionamento
  -- =================================================================
  -- 2.1) Pega a ficha ativa atual (se existir)
  SELECT id INTO v_old_ficha
    FROM public.fichas_mestres
   WHERE produto_id = v_produto_id AND ativa = true
   LIMIT 1;

  -- 2.2) Calcula próxima versão
  SELECT COALESCE(MAX(versao), 0) + 1 INTO v_new_versao
    FROM public.fichas_mestres
   WHERE produto_id = v_produto_id;

  -- 2.3) Desativa a ficha atual (preserva histórico)
  IF v_old_ficha IS NOT NULL THEN
    UPDATE public.fichas_mestres
       SET ativa = false, updated_at = now()
     WHERE id = v_old_ficha;
    RAISE NOTICE 'Ficha anterior (id %, versão %) marcada como INATIVA — preservada para histórico.',
                 v_old_ficha, v_new_versao - 1;
  END IF;

  -- 2.4) Insere a nova ficha
  INSERT INTO public.fichas_mestres (
    produto_id, versao, ativa,
    familia, nome_comercial, convencao_nro_serie, exemplo_nro_serie,
    aplicacao_clinica, data_concessao_anvisa, aplicabilidade_udi,
    inmetro_aplicavel, inmetro_observacao,
    etiqueta_externa_campos, regras_negocio, observacoes
  )
  VALUES (
    v_produto_id,
    v_new_versao,
    true,
    'Fonte de Luz LED',
    'CM-LED',
    'LEDT-<ano-AAAA><mês-MM>-<sequência>',
    'LEDT-202512-7 (CM-LED, dezembro/2025, série 7)',
    'Iluminação por LED para procedimentos endoscópicos e cirúrgicos (saída padrão Storz Touch para cabo de fibra óptica).',
    'INDETERMINADO',
    'A implementação ainda não foi realizada (RDC 591/2021).',
    true,
    'Executar a instalação da etiqueta de certificação INMETRO está presente na inspeção final do Estágio 40.',

    -- Etiqueta Externa (Seção 3 do PDF) — 14 campos
    jsonb_build_object(
      'logo',                    'Confiance Medical',
      'fabricante',              'Confiance Medical Produtos Médicos S.A.',
      'endereco',                'Rua Bela, 852, São Cristóvão, Rio de Janeiro – RJ – CEP: 20930-380',
      'cnpj',                    '05.209.279/0001-31',
      'nome_familia',            'FONTE DE LUZ LED',
      'modelo',                  'CM-LED',
      'numero_serie_convencao',  'Conforme convenção do item 1 da Ficha (ex.: LEDT-202512-7).',
      'registro_anvisa',         '80337650008',
      'data_fabricacao_regra',   'Igual à data de emissão da OP.',
      'validade',                'INDETERMINADO',
      'rt',                      'Samara Campos — CREA RJ: 2019108911',
      'rl',                      'Cristiano Mendes Brega',
      'instrucoes_uso',          'Remete ao Manual de Instruções.',
      'udi_datamatrix',          'A implementação ainda não foi realizada.'
    ),

    -- Regras de Negócio (Seção 9 do PDF) — 4 regras
    jsonb_build_array(
      jsonb_build_object(
        'ordem', 1,
        'regra', 'Convenção do nº de série utiliza prefixo "LEDT" + ano-AAAA + mês-MM + sequência.'
      ),
      jsonb_build_object(
        'ordem', 2,
        'regra', 'Embalagem contém apenas 2 acessórios obrigatórios: Cabo de Força (CBR0038) e Cabo SCM (ACE0004).'
      ),
      jsonb_build_object(
        'ordem', 3,
        'regra', 'O Módulo de LED (ACE0005) é tratado como "Acessório" no Sapiens (depto ES) porém é componente interno, não é embalado solto. Atenção para não conferir como acessório na embalagem.'
      ),
      jsonb_build_object(
        'ordem', 4,
        'regra', 'O CM-LED utiliza o mesmo gabinete (GAB0050) que o Insuflador, porém painel traseiro específico (PDA0003) e painel mole específico (PMB0046 frontal / PMB0032 traseiro).'
      )
    ),

    -- Observações operacionais consolidadas (do PDF + protocolo v1.1)
    'Notação <X Ohm para resistência de aterramento é padrão do Sapiens — tratar como Aprovado. Inspeção com múltiplos planos (ex.: 119267 com CMLED.001.03 + CMLED.01) é prática padrão. Não existe tempo médio esperado por operação no momento — quando há pausas, conta apenas o "Tempo (M)" registrado na OP. No futuro, com histórico considerável de OPs, será possível evidenciar tempo médio por operação e sinalizar operações que destoam.'
  )
  RETURNING id INTO v_new_ficha;

  RAISE NOTICE 'Nova ficha criada (id %, versão %, ATIVA).', v_new_ficha, v_new_versao;

  -- =================================================================
  -- 3) ACESSÓRIOS APLICÁVEIS (Seção 4 do PDF) — 2 itens
  -- =================================================================
  INSERT INTO public.acessorios_aplicaveis
    (ficha_id, ordem, descricao, codigo_sapiens, obrigatorio,
     is_fabricante_confiance, esteril, observacao)
  VALUES
    (v_new_ficha, 1, 'Cabo de Força Padrão Brasil — 1,8 m', 'CBR0038',
     true, false, false,
     'Fornecedor (Fo). Item de prateleira. Etiqueta com Lote, Data Fab. = N/A, Validade Indeterminada.'),
    (v_new_ficha, 2, 'Cabo SCM', 'ACE0004',
     true, true, false,
     'Confiance é Fabricante (F). Etiqueta deve trazer Data de Fabricação. Identificação por Série (prefixo CSCM-AAAAMM-N).');

  -- =================================================================
  -- 4) ROTEIRO FORM-GQ-0047 (Seção 5 do PDF) — 16 itens
  -- =================================================================
  INSERT INTO public.roteiro_form_gq_0047
    (ficha_id, ordem, item_checklist, marcacao_esperada, justificativa)
  VALUES
    (v_new_ficha, 1,  'Separação de Componentes (Estágio 5)',         'SIM'::marcacao_form, NULL),
    (v_new_ficha, 2,  'Preparação de Componentes (Estágio 7)',        'N/A'::marcacao_form,
     'Roteiro do CM-LED Derivação 001 não contém estágio dedicado de Preparação de Componentes (a montagem de cabos é consolidada na Preparação de Gabinete). Porém, poderão haver outras derivações que contém essa etapa e, por isso, deverá ser relatado um ponto de atenção nesses casos.'),
    (v_new_ficha, 3,  'Montagem (estágio dedicado)',                  'N/A'::marcacao_form, 'Não aplicável a este produto.'),
    (v_new_ficha, 4,  'Fechamento da Tela',                           'N/A'::marcacao_form, 'Não aplicável a este produto.'),
    (v_new_ficha, 5,  'Preparação de Gabinete (Estágio 20)',          'SIM'::marcacao_form,
     'Inclui vedação de frestas, fixação de display, módulo de LED, painel mole, ventoinhas, conectores SCM, painel traseiro.'),
    (v_new_ficha, 6,  'Fechamento e Acabamento Gabinete Plástico',    'N/A'::marcacao_form, 'Gabinete metálico.'),
    (v_new_ficha, 7,  'Montagem Eletrônica (Estágio 30)',             'SIM'::marcacao_form,
     'Conexão de rabichos AC, módulo LED, fototransistor, display, SCM, ventoinhas; programação e teste preliminar.'),
    (v_new_ficha, 8,  'Programação (firmware)',                       'N/A'::marcacao_form, NULL),
    (v_new_ficha, 9,  'Gravação (firmware)',                          'N/A'::marcacao_form, NULL),
    (v_new_ficha, 10, 'Finalização (Estágio 40)',                     'SIM'::marcacao_form,
     'Inclui CQ Final com testes de segurança elétrica e luminosidade.'),
    (v_new_ficha, 11, 'Controle de Qualidade do produto acabado',     'SIM'::marcacao_form, NULL),
    (v_new_ficha, 12, 'Embalagem (Estágio 50)',                       'SIM'::marcacao_form, NULL),
    (v_new_ficha, 13, 'Conciliação da Produção (Estágio 60)',         'SIM'::marcacao_form, NULL),
    (v_new_ficha, 14, 'Verificação da rotulagem',                     'SIM'::marcacao_form, NULL),
    (v_new_ficha, 15, 'OP de Reprocesso',                             'N/A'::marcacao_form,
     'OP tipo N (Normal). Marcar SIM apenas se houver reprocesso, ou seja, deverá ser incluída a OP de reprocesso na análise.'),
    (v_new_ficha, 16, 'RNCs associados',                              'N/A'::marcacao_form,
     'Marcar SIM se houver RNC vinculada ao nº de série / OP, ou seja, deverá ser incluído o RNC na análise.');

  -- =================================================================
  -- 5) INSPEÇÕES E CRITÉRIOS (Seção 6 do PDF) — 6 estágios
  -- =================================================================
  INSERT INTO public.inspecoes_criterios
    (ficha_id, estagio_codigo, estagio_nome, criterio_aceitacao)
  VALUES
    (v_new_ficha, '20',             'Preparação de Gabinete',
     'Se todas as medições estiverem dentro do limite especificado: Aprovado. Para casos que não tenha medições, verificar se está com o Status Aprovado. Se não estiver, está errado.'),
    (v_new_ficha, '30',             'Montagem Eletrônica',
     'Se todas as medições estiverem dentro do limite especificado: Aprovado. Para casos que não tenha medições, verificar se está com o Status Aprovado. Se não estiver, está errado.'),
    (v_new_ficha, '40-Finalização', 'Finalização (intermediária)',
     'Se todas as medições estiverem dentro do limite especificado: Aprovado. Para casos que não tenha medições, verificar se está com o Status Aprovado. Se não estiver, está errado.'),
    (v_new_ficha, '40-CQFinal',     'CQ Final',
     'Se todas as medições estiverem dentro do limite especificado: Aprovado. Para casos que não tenha medições, verificar se está com o Status Aprovado. Se não estiver, está errado. Inclui bateria de ensaios IEC 60601: correntes de fuga, rigidez dielétrica, resistência de aterramento, luminosidade.'),
    (v_new_ficha, '50',             'Embalagem',
     'Se todas as medições estiverem dentro do limite especificado: Aprovado. Para casos que não tenha medições, verificar se está com o Status Aprovado. Se não estiver, está errado.'),
    (v_new_ficha, '60',             'Conciliação da Produção',
     'Se todas as medições estiverem dentro do limite especificado: Aprovado. Para casos que não tenha medições, verificar se está com o Status Aprovado. Se não estiver, está errado. Conferência documental completa.');

  -- =================================================================
  -- 6) BOM (Seção 7 do PDF) — 14 componentes
  -- =================================================================
  INSERT INTO public.componentes_bom
    (ficha_id, codigo_sapiens, descricao, tipo_controle,
     prefixo_serie, quantidade, critico, observacao)
  VALUES
    (v_new_ficha, 'ACE0005', 'Módulo de LED (interno)',                              'serie'::tipo_controle, 'MLED-AAAAMM-N',  1, true,  'Conjunto fabricado pela Confiance. Crítico para desempenho essencial (luminosidade).'),
    (v_new_ficha, 'CKP0020', 'CKT Placa Mãe LED',                                    'serie'::tipo_controle, 'PML-AAAAMM-N',   1, true,  'Crítico (controle e segurança elétrica).'),
    (v_new_ficha, 'CKP0061', 'CKT Aparador frontal Fonte de Luz',                    'serie'::tipo_controle, 'CAF-AAAAMM-N',   1, false, 'Contém fototransistor para realimentação da intensidade.'),
    (v_new_ficha, 'CKP0045', 'CKT Aterramento chave L/D',                            'serie'::tipo_controle, 'CACH-AAAAMM-N',  1, false, NULL),
    (v_new_ficha, 'DIS0004', 'Display Gráfico FP056VIA04-00R 5,6"',                  'lote'::tipo_controle,  NULL,             1, false, 'Comum a vários produtos da família.'),
    (v_new_ficha, 'FIL0006', 'Módulo de Entrada de Potência c/ Filtro 1A 5220',      'lote'::tipo_controle,  NULL,             1, true,  'Crítico para EMC e segurança elétrica.'),
    (v_new_ficha, 'VEN0008', 'Ventoinha 12V Q90SD4',                                 'lote'::tipo_controle,  NULL,             2, true,  'Crítico para refrigeração do módulo LED (2 unidades).'),
    (v_new_ficha, 'INT0008', 'Interruptor Elétrico Corpo Aço Inox',                  'lote'::tipo_controle,  NULL,             1, false, 'Comum a vários produtos da família.'),
    (v_new_ficha, 'CCI0020', 'PIC 18F4685 - IMP',                                    'lote'::tipo_controle,  NULL,             1, false, 'Microcontrolador principal — rastreabilidade de firmware.'),
    (v_new_ficha, 'GAB0050', 'Gabinete com Rack sem pintura',                        'lote'::tipo_controle,  NULL,             1, false, 'Compartilhado com outros produtos da linha.'),
    (v_new_ficha, 'PCU0005', 'Adaptador Storz Touch 0Z00186',                        'lote'::tipo_controle,  NULL,             1, false, 'Interface mecânica para o cabo de fibra óptica.'),
    (v_new_ficha, 'PDA0003', 'Painel Traseiro de Alumínio Fonte de Luz (120007)',    'lote'::tipo_controle,  NULL,             1, false, 'Específico do CM-LED.'),
    (v_new_ficha, 'PMB0046', 'Painel de Membrana CMLED Touch V.2',                   'lote'::tipo_controle,  NULL,             1, false, 'Frontal — específico do CM-LED.'),
    (v_new_ficha, 'PMB0032', 'Painel de Membrana Traseiro Fonte de Luz Touch',       'lote'::tipo_controle,  NULL,             1, false, 'Específico do CM-LED.');

  RAISE NOTICE '----------------------------------------------------------';
  RAISE NOTICE 'Importação concluída com sucesso:';
  RAISE NOTICE '  Produto:           CM-LED Derivação 001 (id %)', v_produto_id;
  RAISE NOTICE '  Ficha ATIVA:       versão % (id %)', v_new_versao, v_new_ficha;
  RAISE NOTICE '  Acessórios:        2 inseridos';
  RAISE NOTICE '  Roteiro FORM-0047: 16 itens inseridos';
  RAISE NOTICE '  Inspeções:         6 estágios inseridos';
  RAISE NOTICE '  BOM:               14 componentes inseridos';
  IF v_old_ficha IS NOT NULL THEN
    RAISE NOTICE '  Ficha anterior:    preservada como INATIVA (id %)', v_old_ficha;
  END IF;
  RAISE NOTICE '----------------------------------------------------------';
END $$;

COMMIT;

-- =====================================================================
-- VERIFICAÇÃO (opcional) — rode após a importação para conferir
-- =====================================================================
-- select p.modelo, p.derivacao, p.derivacao_descricao,
--        fm.versao, fm.ativa, fm.nome_comercial,
--        (select count(*) from acessorios_aplicaveis where ficha_id = fm.id) as acessorios,
--        (select count(*) from roteiro_form_gq_0047  where ficha_id = fm.id) as roteiro_itens,
--        (select count(*) from inspecoes_criterios    where ficha_id = fm.id) as inspecoes,
--        (select count(*) from componentes_bom        where ficha_id = fm.id) as bom_itens
--   from produtos p
--   join fichas_mestres fm on fm.produto_id = p.id
--  where p.modelo = 'CM-LED' and p.derivacao = '001'
--  order by fm.versao desc;
