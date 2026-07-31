# Classificação das verificações — NC × Ressalva (para revisão)

Mapa de todas as verificações do motor de análise e como cada uma é classificada
hoje quando o resultado **não** é conforme. Serve para a Qualidade revisar se a
severidade está adequada. Data: 22/07/2026.

Legenda:
- **NC** = Não Conformidade (reprova o lote, exige correção/reanálise).
- **Ressalva** = ponto de atenção; pode ser justificado pelo RT e liberado.
- **N/A** = não aplicável (não entra no índice de conformidade).
- **Conforme** = verificação apenas informativa/positiva (não vira problema).

> Observação geral: campo **ausente/ilegível** na etiqueta costuma ser tratado como
> **Ressalva** (não dá para afirmar que está errado, só que não foi possível ler).
> Campo **presente e divergente** é que vira NC (quando aplicável).

---

## Camada 1 — Consistência interna entre documentos

| Verificação | É NC quando… | É Ressalva quando… | Obs. |
|---|---|---|---|
| Nº de série — consistência e convenção | Série diverge entre OP / Etiqueta / FORM; série não extraída; **ou série fora da convenção da Ficha Mestre** | Série extraída de um único documento (não dá para cruzar) | *(alterado 22/07: fora da convenção era Ressalva, virou NC)* |
| OP — número, origem e tipo | OP não identificada/parseada | — | — |
| Cronologia de estágios da OP | — | — | Só informativo (Conforme) |
| Cronologia coerente entre inspeções e operações | Inspeção começa antes de concluir o estágio anterior (incoerência) | — | — |
| Ordem de inspeções duplicadas | Há inspeções duplicadas fora de ordem | — | — |
| Status das inspeções da OP | Há inspeção "Reprovado" / reprovação detectada | — | Reprovação também gera apontamento §8.3 |
| Aptidão do inspetor à inspeção | — | Inspetor fez inspeção fora da aptidão cadastrada | "Conforme se justificado" |
| Colaboradores cadastrados | — | Inspetor não cadastrado no quadro | Cadastrar e refazer (não conta correção) |
| Medições críticas dentro da faixa | Valor medido fora da faixa Vlr_Min–Vlr_Max declarada | — | — |
| Data da conciliação (estágio 60) | — | Data da conciliação não identificada na OP nem no FORM | — |
| FORM-GQ-0047 (presença) | — | FORM não disponível | — |
| FORM-GQ-0047 — geração, revisão e datas | — | Revisão do FORM posterior à data da conciliação | — |
| RC anexada | RC não identificada/parseada | — | — |
| RC — sem componentes "Não Conforme" | RC traz componente marcado "Não Conforme" | — | — |
| Correspondência RC × OP | A O.P. informada na RC ≠ OP analisada | Não foi possível identificar a O.P. na RC | Conforme se bate |
| Lote/série dos acessórios — RC × Etiqueta | Lote/série do acessório diverge entre RC e etiqueta | — | — |
| Classificação Fabricante/Fornecedor dos acessórios | Rótulo Fabricante/Fornecedor da etiqueta ≠ ficha | — | — |
| Validade dos acessórios estéreis | Problema de validade em acessório estéril | — | — |
| Descrição do acessório × Código Sapiens | Descrição incompatível com o código | — | — |
| Data de fabricação — acessórios Confiance | Data de fabricação do acessório divergente | — | — |
| Etiqueta de acessório × RC | Etiqueta de acessório não bate com a RC | — | — |

---

## Camada 2 — Conformidade contra a Ficha Mestre

| Verificação | É NC quando… | É Ressalva quando… | Obs. |
|---|---|---|---|
| Identificação do produto | Código Sapiens da OP ≠ Ficha; ou produto não identificado | — | — |
| Derivação OP × Ficha | Derivação da OP não cadastrada (órfã) | OP não informa derivação e há várias cadastradas (ambígua) | — |
| Registro ANVISA na etiqueta | Registro ANVISA da etiqueta ≠ Ficha | Etiqueta não pôde ser parseada | — |
| Acessórios obrigatórios da Ficha | Acessório obrigatório ausente; ou validação bloqueada (derivação sem ficha) | — | — |
| Inspeções previstas pela Ficha Mestre | Estágio declarado com inspeção mas SEM inspeção na OP | — | Movido da Camada 1 (22/07) |
| Inspeções não previstas na Ficha Mestre | — | Inspeção na OP em estágio não declarado na ficha | Movido da Camada 1 (22/07) |
| Marcações N/A do FORM × Ficha Mestre | Validação bloqueada (derivação sem ficha) | — | Conforme se bate |
| Etiqueta do acessório ausente na análise | Falta a etiqueta de um acessório que exigia etiqueta | — | — |
| Acessórios opcionais não identificados | — | — | Informativo (Conforme) |
| Grupo alternativo de acessórios ausente | Grupo **obrigatório** e nenhuma variante presente na RC | — | Grupo opcional sem variante = sem NC *(22/07)* |
| Etiqueta do grupo alternativo ausente | Grupo **obrigatório** que sai na NF, mas sem etiqueta anexada | — | — |
| Grupo alternativo — múltiplas variantes | — | Mais de uma variante do mesmo grupo presente na conciliação | Confirmar se o lote usa mais de uma *(novo 22/07)* |
| Grupos alternativos de acessórios | — | — | Informativo (Conforme) — variante(s) presente(s) e conferida(s) |
| Grupos alternativos opcionais | — | — | Informativo (Conforme) — grupo opcional sem variante no lote |

### Etiqueta Externa × Ficha Mestre (verificação consolidada, campo a campo)

O item aparece como um só, mas o status vem do pior campo: se **qualquer** campo NC
diverge → o item é **NC**; se só houver campos de ressalva → **Ressalva**.

| Campo da etiqueta | Divergente = | Ausente/ilegível = |
|---|---|---|
| Família | **NC** | Ressalva |
| Modelo | **NC** | — |
| Série (× OP) | **NC** | — |
| Fabricante | **NC** | Ressalva |
| CNPJ | **NC** | Ressalva |
| Endereço | **NC** *(alterado 22/07: era Ressalva)* | Ressalva |
| Telefone | **NC** *(alterado 22/07: era Ressalva)* | — |
| Responsável Técnico (RT) | **NC** | — |
| CREA da RT | **NC** *(alterado 22/07: era Ressalva)* | — |
| Responsável Legal | **NC** | — |
| Data de fabricação (× Emissão OP) | **NC** *(alterado 22/07: era Ressalva)* | — |
| Validade (esperado INDETERMINADO) | **NC** *(alterado 22/07: era Ressalva)* | — |

---

## Camada 3 — Conformidade regulatória

| Verificação | É NC quando… | É Ressalva quando… | Obs. |
|---|---|---|---|
| Rastreabilidade do lote | — | — | Informativo (Conforme) |
| Rotulagem regulatória | — | Falta algum campo regulatório (endereço/CEP/CNPJ/ANVISA) ou etiqueta não parseada | — |
| Checklist de liberação (FORM-GQ-0047) | Campo "Liberado" marcado **NÃO** | FORM não parseável ou estado de preenchimento indeterminado | "SIM" e "incerto" = Conforme (parecer emitido antes da assinatura) |
| Controle de processo (BPF) | — | Estágios não detectados na OP | — |
| OP de Reprocesso | — | — | Conforme se anexada; N/A se não |
| RNCs associados | — | — | Conforme se anexado; N/A se não |

---

## Pontos que valem discussão na revisão

Decisões já aplicadas em 22/07/2026 (antes eram ressalva, agora são **NC** quando divergem):
**Endereço**, **Telefone**, **CREA da RT** e **Validade (≠ INDETERMINADO)** da etiqueta.
Campo **ausente/ilegível** continua ressalva.

Mantidos como **Ressalva** por decisão (não são candidatos a NC):

- **Aptidão do inspetor** e **Inspetor não cadastrado** — conforme se justificado /
  cadastrar e refazer.
- Campos da etiqueta **ausentes/ilegíveis** — não dá para afirmar que estão errados.

Se quiser rever a severidade de qualquer verificação, é uma mudança pequena e pontual no motor.
