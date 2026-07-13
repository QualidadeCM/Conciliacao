-- ====================================================================
-- Migration: adicionar estagios_com_inspecao à tabela fichas_mestres
-- Data: 01/07/2026
--
-- Motivação (Maria Luiza):
--   Antes tínhamos a regra hardcoded "estágios 5 e 7 nunca têm inspeção;
--   todos os outros sim". A regra na verdade DEPENDE do produto — e novos
--   estágios podem passar a ter inspeção. Agora a Ficha Mestre declara
--   quais dos estágios variáveis aplicáveis TÊM inspeção associada, e o
--   agente cruza contra o que a OP realmente traz.
--
-- Semântica:
--   * jsonb array de números (int) — ex.: [10, 15, 20, 25, 30, 40, 50, 60]
--   * Cada número deve ser um estágio VARIÁVEL que também está listado
--     em estagios_aplicaveis (implicação: ter inspeção → é aplicável).
--   * Estágios 5 (Separação) e 7 (Preparação de Componentes) tipicamente
--     ficam fora, mas nada impede que futuramente entrem.
--   * NULL / [] = sem declaração → o agente cai no comportamento antigo
--     (regra hardcoded) para retrocompatibilidade das fichas existentes.
-- ====================================================================

ALTER TABLE fichas_mestres
  ADD COLUMN IF NOT EXISTS estagios_com_inspecao jsonb DEFAULT '[]'::jsonb;

COMMENT ON COLUMN fichas_mestres.estagios_com_inspecao IS
  'Números dos estágios variáveis que possuem inspeção associada na OP. Ex.: [10,15,20,25,30,40,50,60]. Vazio/NULL = usar regra padrão (5 e 7 sem inspeção).';

-- Índice GIN pra queries que filtram por estágio contendo inspeção
CREATE INDEX IF NOT EXISTS fichas_mestres_estagios_com_inspecao_idx
  ON fichas_mestres USING gin (estagios_com_inspecao);
