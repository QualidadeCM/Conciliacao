-- ============================================================================
-- Migration: operadores.slack_user_id
-- Data: 11/08/2026
--
-- Permite cadastrar o ID de membro do Slack de cada colaborador. Usado para
-- marcar automaticamente, ao enviar uma NC ao Slack, quem EXECUTOU o estágio
-- responsável pelo problema naquela OP específica:
--   - Problema de ETIQUETA  → menciona quem executou o Estágio 50 (Embalagem).
--   - Problema na OP        → menciona quem executou o Estágio 60
--                              (Conciliação da Produção).
-- O colaborador é casado pelo código/matrícula (campo já existente `codigo`,
-- que é o mesmo ID numérico que aparece na cronologia da OP) e, na ausência de
-- código, pelo nome.
--
-- Como pegar o ID do membro no Slack: clique no nome/foto da pessoa → "..."
-- (mais opções) → "Copiar ID do membro". Formato U0123456789 (não é @usuario).
-- ============================================================================

alter table public.operadores
  add column if not exists slack_user_id text;
