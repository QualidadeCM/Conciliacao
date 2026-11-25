-- ============================================================================
-- Falso "RC sem número de lote/série" — 25/11/2026 (SOMENTE LEITURA)
--
-- Entre 12/11 e 25/11/2026 a plataforma apontava NC "Acessório ... está na RC
-- sem número de lote/série" quando o lote/série da RC estava num formato que
-- ela não lia (ex.: só números, como "901606" do Kit Câmera IPM0023). Corrigido.
-- Esta consulta lista os lotes cuja análise VIGENTE ainda tem esse apontamento,
-- para conferir na RC e reanalisar os que forem falsos.
-- ============================================================================
select a.numero_op, a.numero_serie, a.status, a.created_at,
       ap->>'descricao' as apontamento
  from analises a
  cross join lateral jsonb_array_elements(a.parecer_completo->'apontamentos') ap
 where ap->>'descricao' ilike '%está na RC sem número de lote/série%'
   and not exists (select 1 from analises r where r.analise_origem_id = a.id)  -- só a vigente
 order by a.created_at;
