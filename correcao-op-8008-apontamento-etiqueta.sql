-- ============================================================================
-- Correção do apontamento da OP 8008 (HIS28-20269-1) — 11/10/2026
--
-- O que aconteceu: a etiqueta externa do lote veio com dados de OUTRO modelo
-- (HIS33). O agente identificou o produto pela etiqueta (HIS0008) em vez da OP
-- (HIS0003) e registrou duas NCs na OP/série que não eram o erro real:
--   • "Código Sapiens da OP (HIS0003) difere do cadastrado na Ficha (HIS0008)"
--   • "Número de série HIS28-20269-1 não segue a convenção (HIS33-AAAAMM-N)"
-- O erro real foi da ETIQUETA (Almoxarifado). A causa no agente já foi corrigida
-- (a identificação do produto agora usa a OP como referência).
--
-- Este script, na análise NÃO CONFORME da OP 8008:
--   1. troca as duas NCs pela NC correta de etiqueta (setor Almoxarifado);
--   2. guarda as NCs antigas em parecer_completo.apontamentos_originais
--      (rastreabilidade — nada é apagado sem registro);
--   3. corrige o produto/ficha da análise com os dados da análise corrigida;
--   4. ajusta a tabela `apontamentos`.
-- A análise continua NÃO CONFORME (houve NC real) e a correção continua valendo.
--
-- Como rodar: Supabase → SQL Editor → cole tudo → Run. Rode primeiro só o
-- bloco 0 (conferência) se quiser ver o que será alterado.
-- Se o erro da etiqueta foi outro (ex.: só a série, não o modelo), ajuste o
-- texto de v_descricao abaixo antes de rodar.
-- ============================================================================

-- 0) CONFERÊNCIA (só leitura)
select a.id, a.created_at, a.status, a.analise_origem_id, a.modelo,
       ap->>'descricao' as apontamento
  from analises a
  left join lateral jsonb_array_elements(a.parecer_completo->'apontamentos') ap on true
 where a.numero_op = '8008'
 order by a.created_at;

begin;

do $$
declare
  v_descricao   text := 'Etiqueta externa do lote HIS28-20269-1 com dados de outro modelo (HIS33): modelo/número de série não conferem com a OP 8008 (HIS0003). Por causa da etiqueta errada, o agente identificou o produto como HIS0008 e apontou divergência de código Sapiens e de série na OP — o erro real era da etiqueta.';
  v_recomend    text := 'Reimprimir/substituir a etiqueta externa com o modelo e a série da OP (HIS28-20269-1) antes da liberação.';
  v_nc          record;
  v_ok          record;
  v_aps_novos   jsonb;
begin
  -- Análise NC com os dois apontamentos errados
  select a.* into v_nc
    from analises a
   where a.numero_op = '8008'
     and exists (select 1 from jsonb_array_elements(a.parecer_completo->'apontamentos') ap
                  where ap->>'descricao' ilike 'Código Sapiens da OP (HIS0003)%'
                     or ap->>'descricao' ilike 'Número de série "HIS28-20269-1" não segue a convenção%')
   order by a.created_at
   limit 1;
  if v_nc.id is null then
    raise exception 'Análise da OP 8008 com os apontamentos errados não encontrada — nada alterado.';
  end if;

  -- Análise mais recente da mesma OP/série (a corrigida), para copiar o produto certo
  select a.* into v_ok
    from analises a
   where a.numero_op = '8008' and a.numero_serie = v_nc.numero_serie and a.id <> v_nc.id
   order by a.created_at desc
   limit 1;

  -- Apontamentos: remove os dois errados e inclui a NC de etiqueta
  select coalesce(jsonb_agg(ap order by ord), '[]'::jsonb) into v_aps_novos
    from jsonb_array_elements(v_nc.parecer_completo->'apontamentos') with ordinality t(ap, ord)
   where not (ap->>'descricao' ilike 'Código Sapiens da OP (HIS0003)%'
           or ap->>'descricao' ilike 'Número de série "HIS28-20269-1" não segue a convenção%');
  v_aps_novos := v_aps_novos || jsonb_build_array(jsonb_build_object(
    'codigo', 'NC-01', 'severidade', 'nao_conforme', 'camada', 1,
    'documento_afetado', 'Etiqueta Externa', 'setor_responsavel', 'Almoxarifado',
    'descricao', v_descricao, 'recomendacao', v_recomend,
    'referencia_normativa', 'RDC 751/2022 · ISO 13485 §7.5.9',
    'correcao_manual', jsonb_build_object('em', now(), 'por', 'Garantia da Qualidade',
      'motivo', 'Apontamentos de OP/série gerados por identificação errada do produto a partir da etiqueta; o erro real foi da etiqueta.')
  ));

  update analises set
    parecer_completo = jsonb_set(
      jsonb_set(
        jsonb_set(parecer_completo, '{apontamentos_originais}', parecer_completo->'apontamentos'),
        '{apontamentos}', v_aps_novos),
      '{produto}', coalesce(v_ok.parecer_completo->'produto', parecer_completo->'produto')),
    produto_id      = coalesce(v_ok.produto_id, produto_id),
    ficha_id        = coalesce(v_ok.ficha_id, ficha_id),
    modelo          = coalesce(v_ok.modelo, modelo),
    nome_produto    = coalesce(v_ok.nome_produto, nome_produto),
    registro_anvisa = coalesce(v_ok.registro_anvisa, registro_anvisa)
  where id = v_nc.id;

  -- Tabela de apontamentos (usada em relatórios antigos)
  delete from apontamentos
   where analise_id = v_nc.id
     and (descricao ilike 'Código Sapiens da OP (HIS0003)%'
       or descricao ilike 'Número de série "HIS28-20269-1" não segue a convenção%');
  insert into apontamentos (analise_id, ordem, codigo, severidade, camada, documento_afetado, referencia_normativa, descricao, recomendacao)
  values (v_nc.id, 1, 'NC-01', 'nao_conforme', 1, 'Etiqueta Externa', 'RDC 751/2022 · ISO 13485 §7.5.9', v_descricao, v_recomend);

  raise notice 'Análise % corrigida (produto copiado de %).', v_nc.id, coalesce(v_ok.id::text, '— sem análise corrigida —');
end $$;

commit;

-- Conferência depois de rodar:
-- select id, status, modelo, parecer_completo->'apontamentos' as apontamentos,
--        parecer_completo->'apontamentos_originais' as originais
--   from analises where numero_op = '8008' order by created_at;
