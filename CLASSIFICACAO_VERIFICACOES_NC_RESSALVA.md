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
| Nº de série — consistência e convenção | Série diverge entre OP / Etiqueta / FORM; ou série não extraída | Série não segue a convenção esperada | — |
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
| Grupo alternativo de acessórios ausente | Nenhum item do grupo alternativo presente | — | — |
| Etiqueta do grupo alternativo ausente | Falta etiqueta do item do grupo alternativo | — | — |
| Grupos alternativos de acessórios | — | — | Informativo (Conforme) |

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
| Endereço | Ressalva | Ressalva |
| Telefone | Ressalva | — |
| Responsável Técnico (RT) | **NC** | — |
| CREA da RT | Ressalva | — |
| Responsável Legal | **NC** | — |
| Data de fabricação (× Emissão OP) | **NC** | — | *(alterado 22/07: era Ressalva)* |
| Validade (esperado INDETERMINADO) | Ressalva | — |

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

Alguns campos podem merecer reavaliação de severidade — deixo sinalizados para a Qualidade decidir:

- **Endereço** e **Telefone** do fabricante divergentes hoje são **Ressalva**. Se for dado
  cadastral crítico na etiqueta, poderiam virar NC (como Fabricante/CNPJ já são).
- **CREA da RT** divergente é **Ressalva**, enquanto **RT** (nome) divergente é **NC**.
  Avaliar se a divergência do número do CREA deveria acompanhar o RT como NC.
- **Validade ≠ INDETERMINADO** é **Ressalva** — confirmar se algum produto pode ter
  validade determinada legítima (senão, poderia ser NC).
- **Aptidão do inspetor** e **Inspetor não cadastrado** são **Ressalva** por decisão
  (conforme se justificado / cadastrar e refazer) — mantido assim de propósito.

Se quiser, ajusto a severidade de qualquer um destes — é uma mudança pequena e pontual no motor.
