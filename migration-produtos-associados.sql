-- ============================================================================
-- Migration: PRODUTOS ASSOCIADOS na Ficha Mestre
-- Data: 2026-07-29
--
-- Alguns produtos têm outro(s) produto(s) "associado(s)" cujas etiquetas viajam
-- na MESMA pasta da OP, mas que serão conferidos quando ESSE outro produto for
-- analisado separadamente. Ex.: a pasta do CM-STATION27 traz a etiqueta externa
-- do CM-STATION e a etiqueta do acessório IPM0009 (do CM-STATION). Essas
-- etiquetas devem ser ignoradas na análise do CM-STATION27.
--
-- Guarda a lista de MODELOS dos produtos associados. A partir do modelo, o
-- sistema resolve o modelo da etiqueta externa (para escolher a etiqueta certa
-- na importação) e os códigos Sapiens dos acessórios (da ficha do associado)
-- que devem ser desconsiderados na análise.
-- ============================================================================

alter table public.fichas_mestres
  add column if not exists produtos_associados jsonb not null default '[]'::jsonb;
