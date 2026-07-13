# FORM-GQ-0047 Rev. 9 — Mapa de Células e Lógica de Preenchimento

Documento de referência para a Plataforma de Conciliação da Produção da Confiance Medical.

## Visão geral

A Rev. 9 do FORM-GQ-0047 é um **checklist adaptativo**: o cabeçalho, rodapé e estrutura da tabela permanecem fixos como documento controlado, mas as linhas da tabela "Itens a verificar" são preenchidas dinamicamente pela plataforma conforme a Ficha Mestre do produto sendo analisado.

**Diferenças em relação à Rev. 8:**

1. **Revisão**: cabeçalho passou de "8" para "9" (célula H7).
2. **Linha 31 "Liberado para comercialização"**: a célula B31:I31 (texto único com colchetes em texto puro) foi desmesclada e reestruturada em 4 células separadas — A31:F31 (label + descrição) + G31 (Sim) + H31 (Não) + I31 (N/A), com cada checkbox em sua própria célula alinhada com as colunas da tabela acima. Resolve o problema do "X" aparecer fora dos colchetes.
3. **Bordas garantidas em todas as 16 linhas (14-29)**: mesmo as linhas que ficam vazias após o preenchimento dinâmico mantêm as bordas, preservando o visual do FORM.

## Mapa de células

### Cabeçalho fixo (não alterar)

| Célula | Conteúdo |
|---|---|
| A1:A5 | Logo Confiance Medical |
| B1:I5 | "SISTEMA DE GESTÃO DA QUALIDADE / FORMULÁRIO" |
| A6 | "Título:" |
| B6:D6 | "CHECK-LIST DE CONCILIAÇÃO DE RHL E LIBERAÇÃO PARA COMERCIALIZAÇÃO" |
| E6:G6 | "Código" |
| H6:I6 | "Revisão" |
| A7 | "Depto:" |
| B7:D7 | "GARANTIA DA QUALIDADE" |
| E7:G7 | "FORM-GQ-0047" |
| **H7** | **"9"** (revisão atual) |

### Identificação (preenchida pela plataforma)

| Célula | Conteúdo a inserir | Origem do dado |
|---|---|---|
| A9 | `"PRODUTO: <família>"` | Ficha Mestre — campo `familia` |
| A10 | `"MODELO: <modelo>"` | Ficha Mestre — campo `modelo` |
| E9 | `"Nº série/Lote: <serie>"` | OP — campo `serie` |
| E10 | `"Data da Conciliação: <dd/mm/aaaa>"` | OP — `dataConciliacao` (inspeção do Estágio 60) |

**Nota:** O label e o valor convivem na mesma célula (concatenação). Isso preserva o visual original do FORM e evita problema de mesclagem.

### Cabeçalho da tabela (não alterar)

| Célula | Conteúdo |
|---|---|
| A12:F13 | "Itens a verificar" |
| G12:I12 | "Conforme?" |
| G13 | "SIM" |
| H13 | "NÃO" |
| I13 | "N/A" |

### Tabela de itens (linhas 14-29 — 16 slots)

Cada linha tem A:F mesclado para o texto e G/H/I separados para os checkboxes.

| Coluna | Conteúdo |
|---|---|
| A(:F mesclado) | Texto do item (ex.: "Relatório Sapiens adequadamente preenchidos e assinados, contendo etapa de Separação de Componentes") |
| G | "X" se a marcação for SIM; senão vazio |
| H | "X" se a marcação for NÃO; senão vazio |
| I | "X" se a marcação for N/A; senão vazio |

**Linhas devem ser preenchidas a partir da L14, em ordem, conforme a lógica abaixo:**

#### Lógica do preenchimento dinâmico

A plataforma deve gerar a lista de itens combinando 3 fontes:

##### 1) Itens **específicos** do produto (vêm da Ficha Mestre)

Para cada item do `roteiro_form_gq_0047` cadastrado na Ficha Mestre do produto, classificado como tipo `especifica`:

- **Se** a marcação esperada na Ficha é `SIM` → entra no FORM com texto `"Relatório Sapiens adequadamente preenchidos e assinados, contendo etapa de <nome do estágio sem '(Estágio X)'>"`.
- **Se** é `N/A` → **NÃO entra no FORM** (a linha some).

Exemplos para o CM-LED Der. 001: Separação de Componentes, Preparação de Gabinete, Montagem Eletrônica, Finalização.

##### 2) Itens **fixos** (comuns a todos os produtos — sempre presentes)

Sempre adicionados ao FORM, na ordem abaixo, marcados como `SIM`:

| Texto |
|---|
| Relatórios Sapiens adequadamente preenchidos e assinados, contendo Controle de Qualidade do produto acabado |
| Relatórios Sapiens adequadamente preenchidos e assinados, contendo Etapa de Embalagem do produto acabado |
| Relatórios Sapiens adequadamente preenchidos e assinados, contendo Conciliação da Produção do produto acabado |
| Verificação da rotulagem do produto com a etiqueta devidamente preenchida |

##### 3) Itens **condicionais** (dependem de documentos anexados na análise)

Sempre adicionados ao FORM, na ordem abaixo. A marcação depende dos documentos opcionais anexados pelo usuário:

| Texto | Marcação |
|---|---|
| Ordem de Produção de Reprocesso adequadamente preenchida e assinada | `SIM` se `op_reprocesso` foi anexada na análise, senão `N/A` |
| RNCs associados | `SIM` se `rnc` foi anexada na análise, senão `N/A` |

#### Exemplo: CM-LED Der. 001 (lote 6819, sem reprocesso/RNC)

Total: 10 itens (4 específicos + 4 fixos + 2 condicionais), preenchendo as linhas L14 a L23. Linhas L24-L29 ficam vazias mas com bordas preservadas.

### Liberado para comercialização (linha 31)

| Célula | Conteúdo |
|---|---|
| A31:F31 (mesclado) | "Liberado para comercialização?" (label fixo) |
| **G31** | `"Sim: [ X ]"` se marcado SIM; `"Sim: [   ]"` se não |
| **H31** | `"Não: [ X ]"` se marcado NÃO; `"Não: [   ]"` se não |
| **I31** | `"N/A: [ X ]"` se marcado N/A; `"N/A: [   ]"` se não |

**Importante:** As células G31/H31/I31 contêm o texto inteiro (label + checkbox), garantindo que o "X" sempre apareça dentro do colchete. A plataforma só substitui o conteúdo da célula correspondente.

**Política da plataforma v1.1**: o parecer é emitido ANTES da assinatura do RT, então o "Liberado = Sim" só é marcado pela plataforma quando o RT confirmar manualmente. Por enquanto, a plataforma marca `"Sim: [ X ]"` em G31 como sugestão, e o RT pode rasurar/alterar no Excel antes de assinar. (Esse comportamento pode ser revisitado pela QG quando o fluxo de assinatura digital estiver consolidado.)

### Visto de Liberação (linha 33)

| Célula | Conteúdo |
|---|---|
| C33:J33 (mesclado) | "Visto de Liberação da Responsável Técnico ( RT) e Garantia da Qualidade : ___________________________________________" |

Esta linha permanece em branco — espaço para assinatura física ou eletrônica do RT após a análise.

## Justificativa documental (para registro no SGQ)

Esta revisão Rev. 9 substitui a Rev. 8 emitida em 02/04/2025. As mudanças têm como objetivo:

1. **Adequação operacional**: o FORM passa a apresentar apenas as etapas aplicáveis ao produto sendo conciliado, eliminando linhas N/A que poluem visualmente o documento e dificultam a auditoria.
2. **Robustez técnica do preenchimento automático**: a reestruturação da linha "Liberado para comercialização" em células separadas garante que as marcações fiquem visualmente alinhadas com a tabela e dentro dos colchetes.
3. **Manutenção do controle de documentos (ISO 13485 §4.2.4)**: o template Rev. 9 fica controlado e versionado no SGQ; a lógica de preenchimento adaptativo é descrita neste documento de mapa, também versionado.

**Aprovação**: Maria Luiza Zaccur Machado Brandão (a confirmar data de assinatura no SGQ).
