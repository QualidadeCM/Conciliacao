# Auditoria — apontamento manual "Início/Fim" / "Pausa" nas OPs

**Data:** 17/08/2026
**Escopo:** pasta "Pendente de Assinatura" (H:) — meses de JANEIRO a AGOSTO/2026.
**Objetivo:** localizar OPs que apresentam os códigos de barras de apontamento
manual ("Início/Fim" e "Pausa") — sinal de estágio **não finalizado corretamente**
(dois operadores iniciaram o mesmo estágio, ou uma pausa foi aberta e não
encerrada) — que possam ter passado sem apontamento, na análise manual ou pelo agente.

## Método

Extração do texto de cada PDF de OP (`OP_*_preenchida.pdf`) e busca da legenda
**"Início/Fim"** associada a cada estágio — a mesma regra que o agente passou a
usar. A imagem do código de barras não é extraída do PDF, mas a legenda fica no
texto e só aparece quando o estágio não foi finalizado corretamente.

## Cobertura

- **1.029 OPs auditadas** (JAN–AGO/2026).
- **2 pastas** sem PDF de OP para auditar (ver observações).

## Resultado — 7 OPs com apontamento detectado

Todas foram conferidas manualmente no texto do PDF e são positivos reais.

| Mês | OP | Série | Estágio com apontamento |
|---|---|---|---|
| Julho | 7551 | CM40T-20266-14 | 30 — Montagem Eletrônica |
| Julho | 7622 | LEDT-20266-18 | 30 — Montagem Eletrônica |
| Julho | 7635 | CM32FC-20267-2 | 10 — Montagem |
| Julho | 7651 | SC3FHDT-20267-1 | 40 — Finalização |
| Julho | 7673 | LEDT-20267-10 | 30 — Montagem Eletrônica |
| Agosto | 7725 | LEDT-20267-20 | 30 — Montagem Eletrônica |
| Agosto | 7761 | SC4KT-20267-13 | 40 — Finalização |

Como o apontamento não gerava NC até agora, essas 7 OPs passaram pela conciliação
(estão aguardando assinatura) **sem** que a ocorrência fosse registrada. Recomenda-se
verificar com o PCP o que ocasionou o apontamento manual em cada uma e regularizar
a finalização do estágio antes da assinatura/liberação.

## Observações

- **2 pastas sem PDF de OP** (não auditáveis):
  - `ABRIL / OP_7201_CONFIG-20264-4` — pasta sem documentos (aparenta ser de configuração).
  - `AGOSTO / OP_7731_CMEND-20267-2` — contém apenas o Resumo da Análise, sem o PDF da OP.
- Setembro a Dezembro estavam vazios na pasta.
- A regra do agente agora captura automaticamente esse apontamento nas próximas
  análises, gerando NC por estágio (Camada 1 — "Finalização correta dos estágios").
