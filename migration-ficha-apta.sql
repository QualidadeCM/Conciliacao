-- ============================================================
-- Migration: Ficha mestre "apta para análise" (selo de revisão)
-- Data: 09/07/2026 — Maria Luiza
-- Objetivo:
--   A ficha mestre só pode ser usada na análise depois que a GQ confirmar que
--   está revisada e completa. Enquanto 'apta_analise' for false, a análise da OP
--   daquele equipamento é BARRADA com aviso. Assim evitamos pareceres gerados a
--   partir de fichas incompletas.
--   Fichas já existentes ficam como NÃO aptas por padrão — devem ser revisadas e
--   marcadas como aptas uma a uma (decisão consciente da qualidade).
-- ============================================================

alter table public.fichas_mestres
  add column if not exists apta_analise boolean not null default false;

comment on column public.fichas_mestres.apta_analise is
  'true = ficha revisada e liberada para uso na análise; false = pendente de revisão (análise barrada).';

-- Fichas JÁ EXISTENTES que têm estágios aplicáveis preenchidos são consideradas
-- configuradas → entram como APTAS (não travam a operação atual). As vazias/incompletas
-- e as novas continuam pendentes até revisão.
-- Bloco defensivo: funciona tanto se 'estagios_aplicaveis' for array (text[]) quanto jsonb.
do $$
begin
  begin
    -- caso a coluna seja array (text[])
    update public.fichas_mestres set apta_analise = true
     where coalesce(array_length(estagios_aplicaveis, 1), 0) > 0;
  exception when others then
    -- caso a coluna seja jsonb
    update public.fichas_mestres set apta_analise = true
     where estagios_aplicaveis is not null
       and jsonb_typeof(estagios_aplicaveis::jsonb) = 'array'
       and jsonb_array_length(estagios_aplicaveis::jsonb) > 0;
  end;
end $$;

