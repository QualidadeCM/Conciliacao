-- ============================================================
-- Migration: Habilitar atualização em tempo real (Supabase Realtime)
-- Data: 09/07/2026 — Maria Luiza
-- Objetivo:
--   Permitir que mudanças feitas por um usuário apareçam automaticamente na
--   tela de outro (sem F5), nas telas de Histórico/Dashboard (análises),
--   Usuários (perfis), Solicitações e Logs.
--   Para o Realtime funcionar, as tabelas precisam estar na publicação
--   'supabase_realtime'.
-- ============================================================

do $$
begin
  -- adiciona cada tabela à publicação, ignorando se já estiver
  begin execute 'alter publication supabase_realtime add table public.analises';        exception when duplicate_object then null; when others then null; end;
  begin execute 'alter publication supabase_realtime add table public.perfis';          exception when duplicate_object then null; when others then null; end;
  begin execute 'alter publication supabase_realtime add table public.solicitacoes';    exception when duplicate_object then null; when others then null; end;
  begin execute 'alter publication supabase_realtime add table public.logs_atividade';  exception when duplicate_object then null; when others then null; end;
  begin execute 'alter publication supabase_realtime add table public.worklist_ops';    exception when duplicate_object then null; when others then null; end;
end $$;

-- Observação: no painel do Supabase também é possível ativar em
-- Database → Replication → supabase_realtime, marcando as mesmas tabelas.
