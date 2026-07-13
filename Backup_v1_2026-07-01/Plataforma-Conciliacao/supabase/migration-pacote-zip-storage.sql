-- =====================================================================
-- MIGRATION: Bucket de pacotes ZIP gerados + coluna em analises
-- Confiance Medical · 18/06/2026
-- =====================================================================
-- Permite re-download do pacote ZIP a partir do Histórico de Análises sem
-- precisar voltar pra página da análise para gerar de novo.
--
-- Fluxo:
--   1. Usuário clica em "Baixar pacote ZIP" no parecer → plataforma gera o
--      ZIP local, faz download pro computador, E em paralelo faz upload pro
--      bucket "pacotes-analise" no Supabase Storage.
--   2. O caminho do arquivo no Storage fica salvo em analises.pacote_zip_path.
--   3. No Histórico, se essa coluna estiver preenchida, aparece um ícone de
--      download que baixa direto do Storage (sem regenerar).
--
-- COMO EXECUTAR:
--   Supabase Studio → SQL Editor → New query → cole TUDO → Run
-- =====================================================================

BEGIN;

-- 1) Cria o bucket privado
INSERT INTO storage.buckets (id, name, public)
VALUES ('pacotes-analise', 'pacotes-analise', false)
ON CONFLICT (id) DO NOTHING;

-- 2) Policies RLS — usuários autenticados podem ler/escrever/atualizar/deletar
DO $$ BEGIN
  CREATE POLICY "auth_read_pacotes_analise" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'pacotes-analise');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "auth_insert_pacotes_analise" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'pacotes-analise');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "auth_update_pacotes_analise" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'pacotes-analise');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "auth_delete_pacotes_analise" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'pacotes-analise');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 3) Coluna nova em analises apontando para o arquivo no Storage
ALTER TABLE public.analises ADD COLUMN IF NOT EXISTS pacote_zip_path TEXT;
ALTER TABLE public.analises ADD COLUMN IF NOT EXISTS pacote_zip_filename TEXT;
ALTER TABLE public.analises ADD COLUMN IF NOT EXISTS pacote_zip_size BIGINT;
ALTER TABLE public.analises ADD COLUMN IF NOT EXISTS pacote_zip_uploaded_at TIMESTAMPTZ;

COMMENT ON COLUMN public.analises.pacote_zip_path IS
  'Caminho do arquivo ZIP no bucket pacotes-analise. NULL = ainda não foi gerado/baixado.';

COMMIT;

-- =====================================================================
-- VERIFICAÇÃO
-- =====================================================================
-- 1) Bucket criado:
--   SELECT id, name, public FROM storage.buckets WHERE id = 'pacotes-analise';
-- 2) Colunas novas em analises:
--   SELECT column_name FROM information_schema.columns
--    WHERE table_schema='public' AND table_name='analises' AND column_name LIKE 'pacote_zip%';
-- 3) Policies:
--   SELECT policyname FROM pg_policies WHERE tablename='objects' AND policyname LIKE '%pacotes_analise%';
