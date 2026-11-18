-- ============================================================================
-- Diagnóstico de espaço no Supabase (SOMENTE LEITURA — não altera nada)
--
-- Plano gratuito: 500 MB de banco de dados e 1 GB de Storage (arquivos).
-- Como usar: Supabase → SQL Editor → cole UM bloco por vez → Run.
-- Cada bloco devolve uma tabela de resultado. Me mande o print dos blocos
-- 1, 2, 3 e 4 que eu aponto onde está o peso e como reduzir.
-- ============================================================================

-- 1) TAMANHO TOTAL DO BANCO (limite do plano gratuito: 500 MB)
select pg_size_pretty(pg_database_size(current_database())) as banco_total,
       round(pg_database_size(current_database()) / 1024.0 / 1024.0, 1) as banco_mb,
       round(pg_database_size(current_database()) / 1024.0 / 1024.0 / 500 * 100, 1) as pct_do_limite_500mb;


-- 2) TABELAS MAIS PESADAS (dados + índices + TOAST dos campos grandes)
select c.relname as tabela,
       pg_size_pretty(pg_total_relation_size(c.oid)) as total,
       pg_size_pretty(pg_relation_size(c.oid)) as so_dados,
       pg_size_pretty(pg_indexes_size(c.oid)) as indices,
       pg_size_pretty(pg_total_relation_size(c.oid) - pg_relation_size(c.oid) - pg_indexes_size(c.oid)) as toast_campos_grandes,
       c.reltuples::bigint as linhas_estimadas,
       round(pg_total_relation_size(c.oid) / 1024.0 / 1024.0, 1) as total_mb
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind = 'r'
 order by pg_total_relation_size(c.oid) desc
 limit 25;


-- 3) ARQUIVOS NO STORAGE POR PASTA/BUCKET (limite do plano gratuito: 1 GB)
select bucket_id,
       count(*) as arquivos,
       pg_size_pretty(sum(coalesce((metadata->>'size')::bigint, 0))) as tamanho,
       round(sum(coalesce((metadata->>'size')::bigint, 0)) / 1024.0 / 1024.0, 1) as tamanho_mb
  from storage.objects
 group by bucket_id
 order by sum(coalesce((metadata->>'size')::bigint, 0)) desc;


-- 4) STORAGE: DENTRO DE CADA BUCKET, QUAIS PASTAS (1º nível) PESAM MAIS
select bucket_id,
       split_part(name, '/', 1) as pasta,
       count(*) as arquivos,
       round(sum(coalesce((metadata->>'size')::bigint, 0)) / 1024.0 / 1024.0, 1) as tamanho_mb
  from storage.objects
 group by bucket_id, split_part(name, '/', 1)
 order by sum(coalesce((metadata->>'size')::bigint, 0)) desc
 limit 25;


-- 5) ANÁLISES: PESO DOS CAMPOS GRANDES (parecer_completo, textos extraídos etc.)
--    Mostra quanto cada coluna jsonb/texto da tabela analises ocupa.
select a.attname as coluna,
       format_type(a.atttypid, a.atttypmod) as tipo
  from pg_attribute a
 where a.attrelid = 'public.analises'::regclass and a.attnum > 0 and not a.attisdropped
   and format_type(a.atttypid, a.atttypmod) in ('jsonb', 'json', 'text')
 order by a.attname;

-- (rode depois do 5; ajuste/adicione colunas conforme a lista acima devolver)
select count(*) as analises,
       pg_size_pretty(sum(pg_column_size(parecer_completo))) as parecer_completo_total,
       pg_size_pretty(avg(pg_column_size(parecer_completo))::bigint) as parecer_medio,
       pg_size_pretty(max(pg_column_size(parecer_completo))::bigint) as maior_parecer
  from analises;


-- 6) ANÁLISES MAIS PESADAS (top 15)
select id, numero_op, numero_serie, created_at, status,
       pg_size_pretty(pg_column_size(parecer_completo)::bigint) as parecer
  from analises
 order by pg_column_size(parecer_completo) desc nulls last
 limit 15;


-- 7) LOG DE AÇÕES / TABELAS QUE CRESCEM SOZINHAS (candidatas a limpeza)
--    Linhas por mês das tabelas de histórico mais comuns (ignora as que não existirem).
do $$
declare t text;
begin
  for t in select unnest(array['logs_atividade','log_atividades','logs','nfs_venda_falhas','envios_pacote','correcoes_solicitadas','apontamentos']) loop
    if to_regclass('public.' || t) is not null then
      raise notice '% → % linhas, % MB', t,
        (select reltuples::bigint from pg_class where oid = ('public.' || t)::regclass),
        round(pg_total_relation_size(('public.' || t)::regclass) / 1024.0 / 1024.0, 1);
    end if;
  end loop;
end $$;
-- (o resultado aparece na aba "Messages"/"Notices" do SQL Editor)


-- 8) ESPAÇO RECUPERÁVEL (linhas "mortas" que o VACUUM ainda não liberou)
select relname as tabela, n_live_tup as linhas_vivas, n_dead_tup as linhas_mortas,
       pg_size_pretty(pg_total_relation_size(relid)) as total
  from pg_stat_user_tables
 where schemaname = 'public'
 order by n_dead_tup desc
 limit 10;
-- Se houver muitas linhas mortas numa tabela grande, rode (uma por vez, fora de horário):
--   vacuum (full, analyze) public.NOME_DA_TABELA;
-- ATENÇÃO: o VACUUM FULL trava a tabela durante a execução — só use com a equipe fora do sistema.


-- ============================================================================
-- 9) STORAGE: O QUE PESA — pacote ZIP × documentos originais × análises antigas
--    (somente leitura). Cada análise tem uma pasta <id_da_análise>/ com:
--      • originais/…  → PDFs/planilhas enviados (usados para reanalisar)
--      • *.zip        → pacote gerado (cópia; dá para gerar de novo)
-- ============================================================================
with arq as (
  select o.name,
         coalesce((o.metadata->>'size')::bigint, 0) as bytes,
         case when o.name like '%/originais/%' then 'originais'
              when o.name like '%.zip' then 'pacote_zip'
              else 'outro' end as tipo,
         case when split_part(o.name, '/', 1) ~ '^[0-9a-f-]{36}$' then split_part(o.name, '/', 1)::uuid end as analise_id
    from storage.objects o
   where o.bucket_id = 'pacotes-analise'
), subst as (
  select distinct analise_origem_id as id from analises where analise_origem_id is not null
)
select arq.tipo,
       case when a.id is null then 'análise inexistente (órfã)'
            when s.id is not null then 'substituída por reanálise'
            else 'vigente' end as situacao_da_analise,
       count(*) as arquivos,
       round(sum(arq.bytes) / 1024.0 / 1024.0, 1) as mb
  from arq
  left join analises a on a.id = arq.analise_id
  left join subst s on s.id = arq.analise_id
 group by 1, 2
 order by 4 desc;
