-- =====================================================================
-- MIGRATION: Bucket de templates do FORM-GQ-0047 (versionado no Storage)
-- =====================================================================
-- Cria bucket privado para armazenar o template oficial do FORM-GQ-0047
-- (e templates futuros, se vierem). A plataforma carrega o template deste
-- bucket; se não houver, faz fallback para a versão embutida no HTML.
--
-- Vantagens vs. template embutido inline:
--  · QG pode trocar o template sem precisar editar código
--  · Versionamento automático pelo Supabase Storage (histórico de cada
--    versão, com timestamps — auditável para ISO 13485 §4.2.4)
--  · Compartilhado entre todos os usuários da plataforma (não localStorage)
--
-- COMO EXECUTAR:
--   Supabase Studio → SQL Editor → New query → cole TUDO → Run
-- =====================================================================

BEGIN;

-- 1) Cria o bucket (privado — sem acesso público)
INSERT INTO storage.buckets (id, name, public)
VALUES ('form-templates', 'form-templates', false)
ON CONFLICT (id) DO NOTHING;

-- 2) Policies de RLS — usuários autenticados podem ler/escrever/atualizar/deletar
DO $$ BEGIN
  CREATE POLICY "auth_read_form_templates" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'form-templates');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "auth_insert_form_templates" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'form-templates');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "auth_update_form_templates" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'form-templates');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "auth_delete_form_templates" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'form-templates');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

COMMIT;

-- =====================================================================
-- VERIFICAÇÃO
-- =====================================================================
-- SELECT id, name, public FROM storage.buckets WHERE id = 'form-templates';
-- SELECT * FROM storage.objects WHERE bucket_id = 'form-templates';
