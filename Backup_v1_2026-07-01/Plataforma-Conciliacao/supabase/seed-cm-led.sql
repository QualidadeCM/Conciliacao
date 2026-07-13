-- =====================================================================
-- SEED: Catálogo + Ficha Mestre CM-LED (modelo de referência)
-- Execute APÓS o schema.sql.
-- =====================================================================

-- 1) Catálogo (todos os produtos do FORM-GQ-0085-01)
insert into public.produtos (equipamento, modelo, codigo_referencia, registro_anvisa, codigo_sapiens, derivacao)
values
  ('FONTE DE LUZ LED', 'CM-LED', 'LEDT', '80337650008', 'FNT0001', '001'),
  ('INSUFLADOR CO2', 'CM-30L', 'CM30T', '80337650003', null, null),
  ('INSUFLADOR CO2', 'CM-40L', 'CM40T', '80337650003', null, null),
  ('INSUFLADOR DE CO2 PARA ENDOSCOPIA', 'CM-ENDOCO2', 'CMEND', '80337650010', null, null),
  ('INSUFLADOR DE LÍQUIDO PARA ENDOSCOPIA', 'CM-FLOW', 'CMFLOW', '80337659004', null, null),
  ('LITOTRITOR BALÍSTICO PNEUMÁTICO', 'CM-UROLIT', 'CMLIT', '80337659008', null, null),
  ('SISTEMA DE VÍDEO URETERORRENOSCÓPIO DIGITAL', 'CM-UROVIEW', 'CMFLEX', '80337659007', null, null),
  ('ACESSÓRIO PARA ESCAPE DE FUMAÇA', 'CM-100', 'CM100', '80337650003', null, null),
  ('SISTEMA INTEGRADO PARA ENDOSCOPIA', 'CM-STATION', 'CMST', '80337659003', null, null),
  ('SISTEMA INTEGRADO PARA ENDOSCOPIA', 'CM-STATION21', 'CMST21', '80337659003', null, null),
  ('SISTEMA INTEGRADO PARA ENDOSCOPIA', 'CM-STATION27', 'CMST27', '80337659003', null, null),
  ('SISTEMA DE GRAVAÇÃO DE IMAGENS', 'CM-RECMASTER 1', 'REC1', '80337659002', null, null),
  ('SISTEMA DE GRAVAÇÃO DE IMAGENS', 'CM-RECMASTER 2', 'REC2', '80337659002', null, null),
  ('SISTEMA DE GRAVAÇÃO DE IMAGENS', 'CM-RECMASTER 3', 'REC3FHD', '80337659002', null, null),
  ('MICROCÂMERA CM', 'CM-SCAM', 'SCFHDT', '80337650005', null, null),
  ('MICROCÂMERA CM', 'CM-SCAM3', 'SC3FHDT', '80337650005', null, null),
  ('MONITOR PROFISSIONAL GRAU MÉDICO', 'CM-CINEMED-32F', 'CM32FC', '80337650007', null, null),
  ('MONITOR PROFISSIONAL GRAU MÉDICO', 'CM-CINEMED-42F', 'CM42FC', '80337650007', null, null),
  ('MONITOR PROFISSIONAL GRAU MÉDICO', 'CM-CINEMED-27F', 'CM27FC', '80337650007', null, null)
on conflict (modelo) do nothing;

-- 2) Ficha Mestre do CM-LED (modelo completo de referência)
with prod as (
  select id from public.produtos where modelo = 'CM-LED'
)
insert into public.fichas_mestres (
  produto_id, versao, ativa,
  familia, nome_comercial, convencao_nro_serie, exemplo_nro_serie,
  aplicacao_clinica, data_concessao_anvisa, aplicabilidade_udi,
  inmetro_aplicavel, inmetro_observacao,
  etiqueta_externa_campos, regras_negocio, observacoes
)
select
  prod.id, 1, true,
  'Fonte de Luz LED',
  'CM-LED',
  'LEDT-<ano-AAAA><mês-M>-<sequência>',
  'LEDT-202512-7',
  'Iluminação por LED para procedimentos endoscópicos e cirúrgicos (saída padrão Storz Touch para cabo de fibra óptica)',
  'INDETERMINADO',
  'A implementação ainda não foi realizada',
  true,
  'Executar a instalação da etiqueta de certificação INMETRO está presente na inspeção final do Estágio 40',
  jsonb_build_object(
    'logo', 'Confiance Medical',
    'fabricante', 'Confiance Medical Produtos Médicos S.A.',
    'endereco', 'Rua Bela, 852, São Cristóvão, Rio de Janeiro – RJ – CEP: 20930-380',
    'cnpj', '05.209.279/0001-31',
    'nome_familia', 'FONTE DE LUZ LED',
    'modelo', 'CM-LED',
    'registro_anvisa', '80337650008',
    'data_fabricacao_regra', 'Igual à data de emissão da OP',
    'validade', 'INDETERMINADO',
    'rt', 'Samara Campos — CREA RJ: 2019108911',
    'rl', 'Cristiano Mendes Brega'
  ),
  jsonb_build_array(
    jsonb_build_object('regra', 'Convenção do nº de série utiliza prefixo "LEDT" + ano-AAAA + mês-M + sequência.'),
    jsonb_build_object('regra', 'Embalagem contém apenas 2 acessórios obrigatórios: Cabo de Força (CBR0038) e Cabo SCM (ACE0004).'),
    jsonb_build_object('regra', 'O Módulo de LED (ACE0005) é tratado como "Acessório" no Sapiens (depto ES) porém é componente interno, não é embalado solto.'),
    jsonb_build_object('regra', 'O CM-LED utiliza o mesmo gabinete (GAB0050) que o Insuflador, porém painel traseiro específico (PDA0003) e painel mole específico (PMB0046 frontal / PMB0032 traseiro).')
  ),
  'Notação <X Ohm para resistência de aterramento é padrão do Sapiens — tratar como Aprovado. Inspeção com múltiplos planos (ex.: 119267 com CMLED.001.03 + CMLED.01) é prática padrão.'
from prod
on conflict do nothing;

-- 3) Acessórios aplicáveis (Ficha seção 4)
with ficha as (
  select fm.id from public.fichas_mestres fm
  join public.produtos p on p.id = fm.produto_id
  where p.modelo = 'CM-LED' and fm.ativa = true
)
insert into public.acessorios_aplicaveis (ficha_id, ordem, descricao, codigo_sapiens, obrigatorio, is_fabricante_confiance, esteril, observacao)
select ficha.id, 1, 'Cabo de Força Padrão Brasil — 1,8 m', 'CBR0038', true, false, false, 'Item de prateleira; etiqueta com Lote, Data Fab. = N/A, Validade Indeterminada.' from ficha
union all
select ficha.id, 2, 'Cabo SCM', 'ACE0004', true, true, false, 'Acessório fabricado pela Confiance — etiqueta deve trazer Data de Fabricação.' from ficha;

-- 4) Roteiro FORM-GQ-0047 (Ficha seção 5)
with ficha as (
  select fm.id from public.fichas_mestres fm
  join public.produtos p on p.id = fm.produto_id
  where p.modelo = 'CM-LED' and fm.ativa = true
)
insert into public.roteiro_form_gq_0047 (ficha_id, ordem, item_checklist, marcacao_esperada, justificativa)
select ficha.id, 1, 'Separação de Componentes (Estágio 5)', 'SIM'::marcacao_form, null from ficha
union all select ficha.id, 2, 'Preparação de Componentes (Estágio 7)', 'N/A'::marcacao_form, 'Roteiro do CM-LED Derivação 001 não contém estágio dedicado de Preparação de Componentes (a montagem de cabos é consolidada na Preparação de Gabinete).' from ficha
union all select ficha.id, 3, 'Montagem (estágio dedicado)', 'N/A'::marcacao_form, 'Não aplicável a este produto.' from ficha
union all select ficha.id, 4, 'Fechamento da Tela', 'N/A'::marcacao_form, 'Não aplicável a este produto.' from ficha
union all select ficha.id, 5, 'Preparação de Gabinete (Estágio 20)', 'SIM'::marcacao_form, 'Inclui vedação de frestas, fixação de display, módulo de LED, painel mole, ventoinhas, conectores SCM, painel traseiro.' from ficha
union all select ficha.id, 6, 'Fechamento e Acabamento Gabinete Plástico', 'N/A'::marcacao_form, 'Gabinete metálico.' from ficha
union all select ficha.id, 7, 'Montagem Eletrônica (Estágio 30)', 'SIM'::marcacao_form, 'Conexão de rabichos AC, módulo LED, fototransistor, display, SCM, ventoinhas; programação e teste preliminar.' from ficha
union all select ficha.id, 8, 'Programação (firmware)', 'N/A'::marcacao_form, null from ficha
union all select ficha.id, 9, 'Gravação (firmware)', 'N/A'::marcacao_form, null from ficha
union all select ficha.id, 10, 'Finalização (Estágio 40)', 'SIM'::marcacao_form, 'Inclui CQ Final com testes de segurança elétrica e luminosidade.' from ficha
union all select ficha.id, 11, 'Controle de Qualidade do produto acabado', 'SIM'::marcacao_form, null from ficha
union all select ficha.id, 12, 'Embalagem (Estágio 50)', 'SIM'::marcacao_form, null from ficha
union all select ficha.id, 13, 'Conciliação da Produção (Estágio 60)', 'SIM'::marcacao_form, null from ficha
union all select ficha.id, 14, 'Verificação da rotulagem', 'SIM'::marcacao_form, null from ficha
union all select ficha.id, 15, 'OP de Reprocesso', 'N/A'::marcacao_form, 'OP tipo N (Normal). Marcar SIM apenas se houver reprocesso.' from ficha
union all select ficha.id, 16, 'RNCs associados', 'N/A'::marcacao_form, 'Marcar SIM se houver RNC vinculada ao nº de série / OP.' from ficha;

-- 5) Critérios de inspeção (Ficha seção 6)
with ficha as (
  select fm.id from public.fichas_mestres fm
  join public.produtos p on p.id = fm.produto_id
  where p.modelo = 'CM-LED' and fm.ativa = true
)
insert into public.inspecoes_criterios (ficha_id, estagio_codigo, estagio_nome, criterio_aceitacao)
select ficha.id, '20', 'Preparação de Gabinete', 'Se todas as medições estiverem dentro do limite especificado: Aprovado. Para casos que não tenha medições, verificar se está com o Status Aprovado.' from ficha
union all select ficha.id, '30', 'Montagem Eletrônica', 'Se todas as medições estiverem dentro do limite especificado: Aprovado. Para casos que não tenha medições, verificar se está com o Status Aprovado.' from ficha
union all select ficha.id, '40-Finalização', 'Finalização (intermediária)', 'Se todas as medições estiverem dentro do limite especificado: Aprovado.' from ficha
union all select ficha.id, '40-CQFinal', 'CQ Final', 'Bateria completa de ensaios IEC 60601: correntes de fuga, rigidez dielétrica, resistência de aterramento, luminosidade.' from ficha
union all select ficha.id, '50', 'Embalagem', 'Se todas as medições estiverem dentro do limite especificado: Aprovado.' from ficha
union all select ficha.id, '60', 'Conciliação da Produção', 'Conferência documental completa.' from ficha;

-- 6) BOM aprovada (Ficha seção 7)
with ficha as (
  select fm.id from public.fichas_mestres fm
  join public.produtos p on p.id = fm.produto_id
  where p.modelo = 'CM-LED' and fm.ativa = true
)
insert into public.componentes_bom (ficha_id, codigo_sapiens, descricao, tipo_controle, prefixo_serie, quantidade, critico, observacao)
select ficha.id, 'ACE0005', 'Módulo de LED (interno)', 'serie'::tipo_controle, 'MLED-AAAAMM-N', 1, true, 'Crítico para desempenho essencial (luminosidade).' from ficha
union all select ficha.id, 'CKP0020', 'CKT Placa Mãe LED', 'serie'::tipo_controle, 'PML-AAAAMM-N', 1, true, 'Crítico (controle e segurança elétrica).' from ficha
union all select ficha.id, 'CKP0061', 'CKT Aparador frontal Fonte de Luz', 'serie'::tipo_controle, 'CAF-AAAAMM-N', 1, false, 'Contém fototransistor para realimentação da intensidade.' from ficha
union all select ficha.id, 'CKP0045', 'CKT Aterramento chave L/D', 'serie'::tipo_controle, 'CACH-AAAAMM-N', 1, false, null from ficha
union all select ficha.id, 'DIS0004', 'Display Gráfico FP056VIA04-00R 5,6"', 'lote'::tipo_controle, null, 1, false, 'Comum a vários produtos da família.' from ficha
union all select ficha.id, 'FIL0006', 'Módulo de Entrada de Potência c/ Filtro 1A 5220', 'lote'::tipo_controle, null, 1, true, 'Crítico para EMC e segurança elétrica.' from ficha
union all select ficha.id, 'VEN0008', 'Ventoinha 12V Q90SD4', 'lote'::tipo_controle, null, 2, true, 'Crítico para refrigeração do módulo LED.' from ficha
union all select ficha.id, 'INT0008', 'Interruptor Elétrico Corpo Aço Inox', 'lote'::tipo_controle, null, 1, false, 'Comum a vários produtos da família.' from ficha
union all select ficha.id, 'CCI0020', 'PIC 18F4685 - IMP', 'lote'::tipo_controle, null, 1, false, 'Microcontrolador principal — rastreabilidade de firmware.' from ficha
union all select ficha.id, 'GAB0050', 'Gabinete com Rack sem pintura', 'lote'::tipo_controle, null, 1, false, 'Compartilhado com outros produtos da linha.' from ficha
union all select ficha.id, 'PCU0005', 'Adaptador Storz Touch 0Z00186', 'lote'::tipo_controle, null, 1, false, 'Interface mecânica para o cabo de fibra óptica.' from ficha
union all select ficha.id, 'PDA0003', 'Painel Traseiro de Alumínio Fonte de Luz (120007)', 'lote'::tipo_controle, null, 1, false, 'Específico do CM-LED.' from ficha
union all select ficha.id, 'PMB0046', 'Painel de Membrana CMLED Touch V.2', 'lote'::tipo_controle, null, 1, false, 'Frontal — específico do CM-LED.' from ficha
union all select ficha.id, 'PMB0032', 'Painel de Membrana Traseiro Fonte de Luz Touch', 'lote'::tipo_controle, null, 1, false, 'Específico do CM-LED.' from ficha;
