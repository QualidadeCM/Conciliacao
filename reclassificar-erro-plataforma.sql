-- ============================================================================
-- Reclassificar reanálises já feitas como "erro da plataforma" — 25/11/2026
--
-- Para lotes que JÁ foram reanalisados como correção, mas cujo apontamento
-- original era erro da plataforma (os documentos estavam certos). Depois disso,
-- o lote deixa de contar como não conforme/corrigido nos indicadores.
-- Nada é apagado: só muda o tipo e o motivo da reanálise.
--
-- Como usar: troque a lista de OPs no bloco 1, confira o resultado e, se estiver
-- certo, rode o bloco 2 com a MESMA lista e o motivo.
-- ============================================================================

-- 1) Conferência (somente leitura): reanálises desses lotes
select r.id, r.numero_op, r.numero_serie, r.created_at, r.tipo_reanalise, r.doc_substituido, r.motivo_reanalise
  from analises r
 where r.analise_origem_id is not null
   and r.numero_op in ('0000', '0000')          -- ← coloque aqui as OPs
 order by r.numero_op, r.created_at;

-- 2) Reclassifica (só as reanálises de correção desses lotes)
update analises r
   set tipo_reanalise   = 'erro_sistema',
       motivo_reanalise = 'Erro de análise da plataforma: ' || 'descreva aqui o erro'   -- ← motivo
 where r.analise_origem_id is not null
   and coalesce(r.tipo_reanalise, '') not in ('atualizacao_ficha', 'atualizacao_cadastro', 'erro_sistema')
   and r.numero_op in ('0000', '0000');         -- ← mesmas OPs do bloco 1
