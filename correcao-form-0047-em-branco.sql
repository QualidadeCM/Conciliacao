-- ============================================================================
-- FORM-GQ-0047 saindo em branco ("[object Object]") no pacote — 24/11/2026
--
-- Causa: ao JUSTIFICAR UMA RESSALVA, a plataforma copiava o parecer com
-- JSON.parse(JSON.stringify()). Isso transformava os bytes do FORM gerado
-- (_formXlsxBytes) num objeto comum e ainda GRAVAVA esse objeto no banco,
-- junto com outros campos internos (_slots…). No "Baixar pacote", esse
-- objeto ia para o conversor, que gerava um PDF com o texto "[object Object]"
-- — sem o conteúdo do FORM e sem a linha "Garantia da Qualidade" para assinar.
--
-- A plataforma já foi corrigida. Este script:
--   1) LISTA os lotes afetados (para regerar o pacote de cada um);
--   2) LIMPA do banco os campos internos gravados por engano.
-- Rode o bloco 1, guarde a lista, depois rode o bloco 2.
-- ============================================================================

-- 1) Lotes afetados (somente leitura)
select a.numero_op, a.numero_serie, a.status, a.created_at,
       a.pacote_zip_uploaded_at, a.id
  from analises a
 where a.parecer_completo ? '_formXlsxBytes'
 order by a.created_at;

-- Quantos e quanto espaço ocupam (somente leitura)
select count(*) as analises_afetadas,
       pg_size_pretty(sum(pg_column_size(parecer_completo))::bigint) as tamanho_dos_pareceres
  from analises
 where exists (select 1 from jsonb_object_keys(parecer_completo) k where k like '\_%');


-- 2) Limpeza: remove do parecer todas as chaves internas (começam com "_").
--    Não altera nenhuma informação da análise (resultado, apontamentos,
--    justificativas continuam iguais).
update analises a
   set parecer_completo = (
         select coalesce(jsonb_object_agg(t.k, t.v), '{}'::jsonb)
           from jsonb_each(a.parecer_completo) as t(k, v)
          where t.k not like '\_%'
       )
 where exists (select 1 from jsonb_object_keys(a.parecer_completo) k where k like '\_%');

-- Conferência (deve dar 0):
-- select count(*) from analises where exists (select 1 from jsonb_object_keys(parecer_completo) k where k like '\_%');
