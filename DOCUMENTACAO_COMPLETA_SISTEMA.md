# Documentação Completa — Sistema de Análise da Conciliação da Produção

**Empresa:** Confiance Medical Produtos Médicos S.A.
**Área responsável:** Garantia da Qualidade (GQ)
**Repositório analisado:** `C:\conciliacao`
**Data desta documentação:** 11/08/2026
**Base da análise:** leitura do código-fonte real — `plataforma.html` (15.393 linhas), `conversor-pdf-local/server.js` (352 linhas), `edge-function/*.ts`, 17 arquivos `migration-*.sql` e o schema base em `Backup_v1_2026-07-01/Plataforma-Conciliacao/supabase/schema.sql`.

> Todas as afirmações deste documento estão ancoradas em trechos de código citados por arquivo e linha. Onde uma funcionalidade existe no código mas **não está ligada à interface**, isso está explicitamente sinalizado.

---

## Resumo executivo

O sistema é uma plataforma interna da Garantia da Qualidade que automatiza a **conciliação documental de lotes de dispositivos médicos**: recebe os documentos de produção de uma OP (Ordem de Produção, Relação de Componentes, etiquetas externas e de acessórios, FORM-GQ-0047), extrai o texto no próprio navegador, confronta tudo contra a Ficha Mestre cadastrada e emite um parecer técnico em 3 camadas de verificação, com apontamentos classificados em Não Conformidade e Ressalva, referência normativa (ISO 13485:2016, RDC 665/2022, RDC 751/2022, IEC 60601/62304) e recomendação de correção. Ele também gera o FORM-GQ-0047 preenchido, anota a OP em PDF, monta o pacote assinável do lote, grava esse pacote na pasta da rede, alimenta um dashboard de indicadores (correções, reincidência, tendência, melhorias regulatórias) e dispara alertas de NC no Slack para PCP e Almoxarifado.

Está **em produção e resolve o problema de negócio**. O motor de conciliação tem cerca de 1.800 linhas de regras determinísticas em JavaScript (`plataforma.html:4530-6026`), calibradas incrementalmente ao longo de meses — os próprios comentários do código registram datas de decisão de negócio (16/06, 17/06, 18/06, 23/06, 29/06, 30/06, 01/07, 06/07, 10/07, 15/07, 22/07, 06/08/2026). É o ativo mais valioso e mais frágil do sistema.

Em relação ao **Padrão de Desenvolvimento de Sistemas da Confiance Medical**, o sistema é **majoritariamente não aderente**, por decisões estruturais e não por defeito de implementação. Dos requisitos do padrão: 2 atendem, 3 atendem parcialmente e 18 não atendem. Os quatro desvios críticos são: (1) **autenticação própria** via Supabase Auth, com tela de login, definição de senha e convite por e-mail — o padrão proíbe explicitamente login próprio em sistemas satélite; (2) **banco de dados e arquivos em nuvem** (Supabase Postgres + Storage), expressamente vedados; (3) **ausência de build e de TypeScript** — o arquivo único de 979 KB é transpilado por Babel dentro do navegador; (4) **ausência da API REST `/SIGLA/api/v1/`** — o navegador fala direto com o banco via PostgREST, com RLS permissiva (`for all to authenticated using (true)`), o que significa que **as permissões existem apenas na interface, não no banco**.

A adequação total é uma **reescrita, não um refactor**: estimativa de **14 a 20 semanas** de desenvolvimento dedicado (~3,5 a 5 meses), sendo a fase mais crítica a portabilidade 1:1 do motor de conciliação, que exige suíte de regressão comparando pareceres antes/depois nas mesmas OPs históricas antes de qualquer corte. Recomenda-se preservar o sistema atual em operação paralela até que a regressão feche em 100%.

---

## 1. Visão geral

### 1.1 O que o sistema faz

Automatiza a etapa de **conciliação da produção** (Estágio 60 do roteiro Sapiens) para dispositivos médicos fabricados pela Confiance Medical. Para cada lote produzido, a Garantia da Qualidade precisa conferir se os documentos de produção são internamente consistentes entre si e se estão conformes ao que a Ficha Mestre do produto especifica, antes de o Responsável Técnico liberar o lote para comercialização.

O sistema recebe os documentos do lote, lê o conteúdo, cruza os dados e devolve:

- um **parecer técnico** com resultado geral (`conforme` / `ressalva` / `nao_conforme`);
- um **checklist por camada** com o que foi verificado e os valores efetivamente lidos em cada documento;
- **apontamentos numerados** (`NC-01`, `R-01`, …) com documento afetado, referência normativa, descrição e recomendação;
- o **FORM-GQ-0047 preenchido** (XLSX gerado a partir do template oficial Rev. 8, preservando formatação);
- a **OP anotada em PDF** com ✓ nos checkboxes de inspeção e a data da conciliação;
- o **pacote do lote** (ZIP com todos os documentos em PDF assinável + resumo da análise), gravado direto na pasta da rede.

### 1.2 Para quem

Garantia da Qualidade da Confiance Medical. O cadastro de cargos no código (`plataforma.html:320-326`) define exatamente o público:

- Estagiário da Garantia da Qualidade
- Assistente da Garantia da Qualidade
- Analista da Garantia da Qualidade
- Responsável pela Qualidade / Responsável Técnico
- Responsável pela Produção

O e-mail `qualidade@confiancemedical.com.br` é administrador implícito do sistema (`plataforma.html:319`, `plataforma.html:15353`).

### 1.3 O problema que resolve

A conciliação manual exige conferir, campo a campo, quatro a seis documentos por lote:

| Documento | Origem | O que carrega |
|---|---|---|
| **OP** — Ordem de Produção | Sapiens (PDF/XLSX) | Nº da OP, série, derivação, estágios, operações com data/hora/operador, inspeções com inspetor e status, medições críticas, vistos de aprovação |
| **RC** — Relação de Componentes | Sapiens (PDF/XLSX/CSV) | Componentes e acessórios baixados no lote, com lote/série de cada um |
| **FORM-GQ-0047** | Formulário da GQ (XLSX/PDF) | Check-list de conciliação: 16 itens marcados SIM / NÃO / N/A, liberação para comercialização |
| **Etiqueta Externa** | Almoxarifado (DOCX) | Nome do produto, modelo, série, registro ANVISA, fabricante, CNPJ, endereço, telefone, RT, CREA, responsável legal, data de fabricação, validade |
| **Etiqueta de Acessório** (N por lote) | Almoxarifado (DOCX) | Descrição, código Sapiens, lote/série, data de fabricação, validade, fabricante ou fornecedor |
| **OP de Reprocesso / RNC** (condicionais) | Produção / GQ | Anexados quando houve retrabalho ou não conformidade |

O referencial de comparação é a **Ficha Mestre** do produto (por modelo **e derivação**), cadastrada na própria plataforma: convenção de nº de série, dados regulatórios do fabricante, quadro de acessórios (obrigatórios/opcionais, estéreis, fabricante Confiance × fornecedor, grupos alternativos), estágios aplicáveis e estágios com inspeção.

A conferência manual é lenta, sujeita a erro de leitura e não gera dado estatístico. O sistema transforma isso em verificação determinística, rastreável, com histórico e indicadores — o que atende diretamente ISO 13485:2016 §7.5.9 (rastreabilidade), §8.2.4 (monitoramento e medição do produto) e §4.2.4/§4.2.5 (controle de documentos e registros).

---

## 2. Funcionalidades e módulos

O sistema tem 7 páginas navegáveis (`plataforma.html:804-812`), filtradas por permissão: Dashboard, Análise, Histórico, Cadastro, Solicitações, Histórico de alterações (logs) e Configurações.

### 2.1 Importação e análise de lote

#### 2.1.1 Fila de OPs finalizadas pendentes — `BuscarOPsPendentes` (`plataforma.html:6344`)

Tela de entrada do fluxo de análise. A GQ importa o relatório `.xlsx` exportado do Sapiens (consulta "movimentos de O.P. com Inspeção pendente (SGQ)"), o sistema extrai os números de OP e monta uma fila de trabalho persistida na tabela `worklist_ops`. A leitura da planilha é feita manualmente via JSZip porque o Sapiens exporta um OOXML fora do padrão (usa `\` nos nomes internos do ZIP) — comentário explícito em `plataforma.html:6341-6342`. A fila remove automaticamente as OPs que foram (re)analisadas depois de entrarem na lista, comparando `analise.created_at > worklist.added_at`. Estar na fila é também o que libera a reanálise de uma OP já finalizada, contornando o bloqueio de duplicidade (`plataforma.html:6896-6899`).

#### 2.1.2 Upload por pasta com classificação automática — `processarPasta` / `classificarArquivo` (`plataforma.html:6767` / `6738`)

A GQ arrasta a pasta inteira da OP e o sistema distribui os arquivos nos slots corretos. A classificação (`classificarArquivo`) usa extensão, nome do arquivo e, quando ambíguo, o conteúdo extraído: `.xlsx`/`.csv` → RC; `.docx` com "Acessório Exclusivo" → etiqueta de acessório, senão etiqueta externa; `.pdf` → decide por padrão no nome (`reprocesso`, `rnc`, `form-gq-0047`, `rc_`, `op_`) e, se nada casar, por texto interno (`FORM-GQ-0047|CHECK-LIST`, `relação de componentes`, `O.P.:|Estágio:`, `não conformidade|RNC`).

Dois refinamentos importantes vivem aqui:

- **Regras de exceção da Ficha** (`plataforma.html:6780-6812`): antes de classificar, o sistema pré-lê a OP, identifica o produto, carrega `fichas_mestres.regras_negocio` e procura regras no formato "ignorar pasta: X". Todos os arquivos dentro de subpastas casadas são descartados da importação. Foi a solução para pastas de OP que trazem etiquetas de produtos associados.
- **Escolha da etiqueta externa por pontuação** (`plataforma.html:6828-6857`): quando mais de uma etiqueta externa é encontrada, o sistema pontua cada candidata — modelo idêntico ao da OP vale 100, modelo que contém o da OP vale 50, nome do arquivo contendo o modelo vale 40, mais desempate por especificidade. O comentário no código registra o caso que motivou a regra: `CM-STATION27` não pode ser confundida com `CM-STATION`.

#### 2.1.3 Extração de texto no navegador — `extractTextFromFile` (`plataforma.html:2347`)

Toda a extração acontece client-side, sem enviar arquivo para nenhum serviço de OCR:

- **PDF** via PDF.js: extrai cada item com coordenadas `transform[4]/[5]`, ordena por Y decrescente e X crescente e reconstrói as linhas, inserindo espaço duplo quando o gap horizontal passa de 30 pontos. Isso é o que permite ler o layout multi-coluna do Sapiens (`plataforma.html:2358-2397`).
- **DOCX** via Mammoth.js (`extractRawText`).
- **XLSX** via ExcelJS: percorre planilhas e linhas, resolvendo richText, fórmulas (`v.result`), hyperlinks e datas, e concatena as células com espaço duplo.
- **CSV** como texto bruto (a RC exportada do Sapiens em CSV é reconhecida pelos mesmos regex).

#### 2.1.4 Parsers determinísticos

Cinco parsers por regex, sem LLM:

| Parser | Linha | O que extrai |
|---|---|---|
| `parseOP` | `2453` | Nº OP (5 padrões alternativos, ordenados do mais específico ao mais genérico para não confundir o ano com o nº da OP), origem, código Sapiens, derivação, modelo, família, tipo (N/R), série, pedido, Rel. Prod., data de emissão, contagem de aprovados/reprovados, **estágios** (via marcadores `Estágio: N` como fonte autoritativa, com fallback por nome de operação só quando nenhum marcador existe), **operações** (nº, descrição, início, fim, tempo, matrícula e nome do operador, vinculadas ao estágio corrente por varredura linear), **inspeções detalhadas** (nº, plano, status, inspetor, data/hora, estágio — regex multi-linha calibrada em 01/07/2026 contra a OP 7499), **data/hora/inspetor da conciliação** (4 estratégias em cascata a partir do Estágio 60), **medições críticas** (descrição, valor medido, situação, min, max, alvo, unidade — calibrada em 26/06/2026 contra a OP 7436) e vistos de aprovação |
| `parseEtiqueta` | `2768` | Família (linha isolada entre o bloco CNPJ e "Modelo:", com fallback por lista de famílias conhecidas), modelo, série, registro ANVISA, data de fabricação, validade, fabricante, CNPJ, endereço, telefone, RT, CREA, responsável legal, e flags de conferência do endereço/CEP/CNPJ oficiais |
| `parseEtiquetaAcessorio` | `2830` | Descrição ("Acessório Exclusivo"), código Sapiens, lote/série, data de fabricação (com flag `dataFabNa`), validade (com `validadeIndeterminada` e `validadeISO`), tipo Fabricante (`F`) × Fornecedor (`Fo`), observação e registro ANVISA do equipamento |
| `parseForm0047` | `2873` | Família (por lista de 15 famílias conhecidas, porque os placeholders do template vêm vazios), modelo, série, data de revisão (bloco VALIDADORES), data da conciliação (última data que não é a de revisão), nº da revisão, liberação (`SIM`/`NAO`/`incerto` — o X é gráfico no PDF e não vem no texto), cópia controlada |
| `parseRC` | `2956` | Origem (com lookbehind para não capturar "819" dentro de "6.819"), situação, OP relacionada, produto, códigos Sapiens, lotes de 15 dígitos, séries alfanuméricas com prefixo e contagem de "Não Conforme" — com remoção prévia do cabeçalho de coluna repetido, que antes gerava falso positivo de "4 componentes NC" numa RC de 4 páginas (`plataforma.html:2992-2999`) |

#### 2.1.5 Identificação do produto — `detectarProdutoNoTexto` (`plataforma.html:3095`)

Casa o corpus dos documentos contra o catálogo em 4 níveis de especificidade decrescente: prefixo de série → código Sapiens → modelo → registro ANVISA. Em cada nível, coleta todos os candidatos e refina pela **derivação** extraída da OP (`refinarPorDerivacao`, `plataforma.html:3103`), devolvendo um status explícito: `match`, `orfa` (a OP referencia uma derivação sem Ficha cadastrada), `unica`, `op_omissa_padrao` (usa a derivação `000`) ou `op_omissa_ambigua`. O status `orfa` bloqueia as validações de acessórios e marcações N/A da Camada 2, porque não existe ficha técnica para comparar.

O carregamento do catálogo (`loadProdutosComFichas`, `plataforma.html:3007`) consulta as fichas ativas com produto e acessórios em um único `select` aninhado, e adiciona também os produtos ativos sem ficha — que aparecerão para bloquear a análise com mensagem específica.

#### 2.1.6 Orquestrador e bloqueios — `executarAnaliseLocal` (`plataforma.html:6031`)

Sequência: parseia os 5 slots → monta o corpus → carrega catálogo e identifica o produto → aplica bloqueios → carrega a data de aprovação do template do FORM → carrega o cadastro de operadores → roda o motor → persiste → gera o FORM → sobe os originais para o Storage.

Quatro bloqueios com códigos próprios de erro, todos exibidos como mensagem clara (sem stack trace) na interface (`plataforma.html:6906-6907`):

| Código | Condição | Linha |
|---|---|---|
| `PRODUTO_NAO_CADASTRADO` | Nenhum produto casou com os documentos | `6058` |
| `FICHA_MESTRE_AUSENTE` | Produto no catálogo, mas sem Ficha Mestre para a derivação | `6070` |
| `FICHA_MESTRE_NAO_APTA` | Ficha existe mas `apta_analise = false` (não foi revisada e liberada) | `6081` |
| `ANALISE_DUPLICADA` | Já existe análise finalizada (`conforme` ou `conforme_corrigido`) para o mesmo par (OP, série), e a OP não está na fila do Sapiens | `6096-6133` |

Os campos voláteis (`_formXlsxBytes`, `_slots`, qualquer `Uint8Array`) são removidos por um replacer do `JSON.stringify` antes de gravar em `parecer_completo` (`plataforma.html:6164-6168`). Os textos extraídos são persistidos em `parecer.slots_text`, o que é o que viabiliza reanálise sem exigir o arquivo original.

### 2.2 Motor de conciliação — `analisarConciliacao` (`plataforma.html:4530-6026`)

Função pura de ~1.500 linhas, sem I/O: recebe documentos parseados, produto/ficha, corpus, data de aprovação do template, flags de OP de Reprocesso e RNC, e o cadastro de operadores; devolve o parecer completo. Dois helpers estruturam a saída:

- `add(camada, oQue, status, valores, norma)` (`4575`) — registra uma linha do checklist: **o que foi verificado** (frase descritiva) e **os valores lidos** (dados efetivamente comparados). Status `conforme` / `ressalva` / `nao_conforme` / `na`. Incrementa os contadores `ncMaior` / `ncMenor`.
- `apontar(severidade, camada, documento, descricao, recomendacao, norma, extra)` (`4580`) — cria o apontamento numerado. O `extra` opcional carrega `estagios` e `inspecoes` (alimentam o gráfico "Problemas na OP"), `sugestaoCorreto` (valor de referência usado no alerta do Slack), `operacoesFlag` e `equipamento`.

O **resultado geral** é hierárquico e sem ponderação (`plataforma.html:5824-5827`): qualquer NC → `nao_conforme`; senão qualquer ressalva → `ressalva`; senão `conforme`. Itens `na` não entram no denominador do índice de conformidade (`5830-5833`).

#### Camada 1 — Consistência interna entre documentos (`plataforma.html:5126`)

Verifica os documentos entre si, sem consultar a Ficha:

- **OP presente e válida** — nº, origem, tipo.
- **Nº de série consolidado** (`5135-5170`) — compara OP × Etiqueta × FORM; divergência entre dois ou mais é NC; presença em apenas um documento é ressalva; ausência total é NC. Valida também a convenção `PREFIXO-AAAAMM-N` da Ficha (NC se fora do padrão).
- **Cronologia coerente entre inspeções e operações** (`5177-5246`) — regra de 30/06/2026: a inspeção do estágio N não pode ser posterior ao **início** de qualquer operação de estágio M > N. O caso que originou a regra está no comentário: inspeção do Estágio 50 concluída em 01/11/2024 10:52 com operações do Estágio 60 já iniciadas em 11/10/2024. Consolida por inspeção para não repetir o mesmo problema em cada operação subsequente.
- **Ordem de inspeções duplicadas** (`5248-5289`) — a mesma inspeção pode aparecer 2× com planos diferentes (prática do Sapiens). Se os inspetores são o mesmo, é normal; se diferentes, o segundo registro deve ser cronologicamente posterior, senão NC.
- **Status das inspeções** (`5359-5393`) — qualquer inspeção não-`Conforme`/`Aprovado` é NC exigindo OP de Reprocesso ou RNC, com o nº da inspeção, o estágio e o inspetor na descrição.
- **Aptidão do inspetor** (`5395-5469`) — cruza o inspetor de cada inspeção com o cadastro de operadores (por nome ou apelido). Cadastrado mas sem o estágio na lista de inspeção → **ressalva** (conforme se justificado, treinamento pontual), com sugestão automática de quem está apto. Não cadastrado → **ressalva** com pedido de cadastro; a reanálise após cadastrar não conta como correção. O comentário em `5415-5416` registra que a conferência de **operador** foi removida em 22/07/2026 por alinhamento com PCP/Almoxarifado — hoje só inspetores são conferidos.
- **Medições críticas dentro da faixa** (`5471-5501`) — para medições marcadas `Aprovado` no Sapiens, confere se o valor medido está em `[Vlr_Min, Vlr_Max]` com tolerância de 1e-6; fora da faixa é NC. Notação `<X` (limite de resolução do instrumento) é ignorada por decisão de 16/06/2026.
- **FORM-GQ-0047 consolidado** (`5503-5557`) — geração (plataforma × anexado), revisão vigente na data da conciliação, data da conciliação OP × FORM, cópia controlada. Todos os problemas aqui são ressalva.
- **Data da conciliação não identificada** (`5512-5515`) — ressalva explícita, para não pular checagens de data em silêncio.
- **RC** (`5559-5570`) — ausência é NC; componente marcado "Não Conforme" é NC exigindo RNC. Os antigos checks de "Origem e Situação" e "quantidades sem divergência" foram removidos em 16/06/2026 por não trazerem valor prático.
- **Correspondência RC × OP** (`5572-5587`) — a RC informa `O.P.: <número>`; se não bate com a OP analisada, NC de "RC de outro lote anexada". Se a OP não pôde ser lida da RC, ressalva.
- **Cruzamentos de acessórios** (`4891-5111`, gravados em C1) — lote/série RC × etiqueta (com normalização que resolve EAN-13 de 13 dígitos × barcode de 15 dígitos com zeros à esquerda, mas mantém divergência real em séries com barra); classificação Fabricante × Fornecedor etiqueta × Ficha; validade de acessórios estéreis obrigatoriamente posterior à data da conciliação (indeterminada, N/A ou ilegível é NC); descrição da etiqueta × código Sapiens (tokenização com stopwords — zero tokens em comum indica troca de código); data de fabricação obrigatória em acessórios fabricados pela Confiance (N/A ou ausente é NC).
- **Etiqueta de acessório sem correspondência na RC** (`4797-4810`) — um apontamento **por código**, para permitir corrigir a RC ou remover a etiqueta individualmente na reanálise.

#### Camada 2 — Conformidade contra a Ficha Mestre (`plataforma.html:4601`)

- **Identificação do produto** — código Sapiens da OP × Ficha.
- **Derivação OP × Ficha** (`4615-4646`) — o caso `orfa` é NC e bloqueia BOM/acessórios/roteiro.
- **Registro ANVISA na etiqueta** × Ficha.
- **Quadro de acessórios** (`4674-4889`) — a lógica de negócio mais densa do sistema, reescrita em 29/06/2026. Cada acessório da Ficha cai em uma de cinco categorias, e a regra-mestra é *"se está na RC, ou é obrigatório com 'pode sair na NF', precisa de etiqueta anexada"*:

  | Caso | Situação | Consequência |
  |---|---|---|
  | 1a | Na RC, com etiqueta | OK + cruzamentos etiqueta × RC × Ficha |
  | 1b | Na RC, sem etiqueta | **NC** — sem a etiqueta não há como conferir fabricante, CNPJ, validade e lote |
  | 2a | Obrigatório + "pode sair na NF", fora da RC, com etiqueta | OK + cruzamento etiqueta × Ficha |
  | 2b | Obrigatório + "pode sair na NF", sem etiqueta | **NC** |
  | 3 | Obrigatório sem "pode sair na NF", ausente na RC | **NC crítica** — item faltando na embalagem |
  | 4 | Opcional, fora da RC, com etiqueta | informativo + cruzamento etiqueta × Ficha |
  | 5 | Opcional, fora da RC, sem etiqueta | sem apontamento |

  A busca de "consta na RC?" olha **somente** a RC (`rc.codigos` + `rc._raw`), não o corpus inteiro — correção de 06/07/2026, porque o código do acessório também aparece na própria etiqueta e na BOM da OP, gerando falso positivo (`plataforma.html:4685-4690`).

- **Grupos alternativos de acessórios** (`4824-4889`) — itens com o mesmo `grupo_alternativo` são variantes mutuamente substituíveis. Pelo menos uma variante do grupo obrigatório deve constar na RC (ou ter etiqueta conferida, se o grupo pode sair na NF), senão NC. Mais de uma variante presente na mesma conciliação gera **ressalva** para confirmação.
- **Inspeções previstas pela Ficha** (`5291-5357`) — regra de 01/07/2026: a Ficha declara quais estágios têm inspeção associada. Estágio declarado e presente na OP mas sem inspeção → **NC**; inspeção na OP em estágio não declarado → **ressalva** pedindo atualização da Ficha. Os estágios **50 (Embalagem) e 60 (Conciliação)** são somados automaticamente aos declarados, porque têm inspeção em todo equipamento.
- **Etiqueta Externa × Ficha Mestre** (`5589-5748`) — verificação consolidada de 11 campos, com normalização tolerante (sem acentos, pontuação como espaço, maiúsculas) para nomes e apenas dígitos para CNPJ/telefone/CREA:

  | # | Campo | Severidade quando diverge |
  |---|---|---|
  | 0 | Família / nome do produto (aceita contido-em, ex.: "MICROCÂMERA" × "Microcâmera CM") | NC |
  | 1 | Modelo | NC |
  | 2 | Série × OP | NC |
  | 3 | Fabricante / razão social | NC (ausente = ressalva) |
  | 4 | CNPJ | NC (ausente = ressalva) |
  | 5 | Endereço da fábrica | NC desde 22/07/2026 (ausente = ressalva) |
  | 6 | Telefone | NC desde 22/07/2026 |
  | 7 | Responsável Técnico | NC |
  | 8 | CREA da RT | NC desde 22/07/2026 |
  | 9 | Responsável Legal | NC |
  | 10 | Data de fabricação = data de emissão da OP | NC desde 22/07/2026 |
  | 11 | Validade = `INDETERMINADO` | NC desde 22/07/2026 |

- **Marcações N/A do FORM × Ficha** (`5114-5124`) — lista os estágios variáveis que a Ficha marca como não aplicáveis (esperado N/A no FORM).

#### Camada 3 — Conformidade regulatória (`plataforma.html:5750`)

Camada com referência normativa em cada item: rastreabilidade do lote (ISO 13485 §7.5.9 e §8.3), rotulagem regulatória (RDC 665/2022 e 751/2022), checklist de liberação do FORM (§8.2.4), controle de processo/BPF (RDC 665/2022), OP de Reprocesso e RNCs associados (`conforme` se anexado, `na` se não).

Duas decisões documentadas no próprio código merecem registro:

- O check de **ensaios elétricos de segurança** foi removido em 03/06/2026 (`5795-5800`): gerava ressalva falso-positiva em eletromédicos, porque o Sapiens registra os ensaios em planos que não aparecem na exportação textual da OP.
- O campo "Liberado para comercialização" com valor `incerto` é tratado como **conforme com nota** (`5779-5781`): o parecer é emitido **antes** da assinatura do RT, então o X gráfico no checkbox naturalmente ainda não existe.

#### Saída do motor

`analisarConciliacao` devolve (`plataforma.html:5996-6025`): `produto` (12 campos de identificação), `resultado_geral`, `parecer_resumo`, `parecer_tecnico` (parágrafo redigido, com três variantes de texto conforme o resultado, sempre reafirmando que a decisão de liberação é prerrogativa exclusiva do RT humano — ISO 13485 §8.2.4), `documentos_analisados`, `cronologia` (operações com inspeção associada), `cronologia_ordem_inspecoes_ok`, `medicoes_criticas`, `cruzamento_marcacoes` (os 16 itens do FORM com esperado / roteiro na OP / status / nota), `camadas.{camada_1,camada_2,camada_3}`, `apontamentos`, `cadastros_pendentes`, `recomendacoes_melhoria` e `sugestoes_regulatorias`.

#### Sugestões de melhoria regulatória — `gerarSugestoesRegulatorias` (`plataforma.html:4403`)

Cinco detectores que procuram no corpus evidência **concreta** (não apenas o rótulo genérico, para evitar falso positivo) de práticas exigidas por norma:

| Código | Norma | Detecta a ausência de |
|---|---|---|
| M-01 | ISO 13485 §7.6(a) · RDC 665/2022 | Identificação do instrumento de medição (TAG / patrimônio / nº de série com valor preenchido) |
| M-02 | ISO 13485 §7.6(b) | Status/validade de calibração rastreável (certificado nº, "válida até DD/MM/AAAA") |
| M-03 | IEC 62304 §5.1.1 · IEC 60601-1 §14 · ISO 13485 §7.5.9 | Versão de firmware gravada — só para eletromédicos (`MONITOR|MICROC|FONTE DE LUZ|INSUFLADOR|CINEMED|LITOTRIT|BISTURI`) |
| M-04 | RDC 591/2021 · IMDRF UDI | UDI / GTIN na rotulagem |
| M-05 | ISO 13485 §4.2.5 · RDC 665/2022 | Registro de retenção de amostra do lote |

Cada sugestão nova é inserida em `melhorias_regulatorias` com dedup global por código (`upsert … onConflict: 'codigo', ignoreDuplicates: true`, `plataforma.html:6211`) e vira item pendente de decisão no Dashboard.

### 2.3 Parecer técnico, PDF e pacote do lote — `ParecerView` (`plataforma.html:7748`)

Tela de resultado da análise, reaproveitada pelo Dashboard e pelo Histórico para visualizar análises antigas.

- **Renderização do parecer** — cabeçalho de identificação, resumo por severidade, cards de apontamento (`CritiqueCard`, `10038`), checklist por camada (`CamadaCard`, `10342`, com `mostrarNorma` na Camada 3), **cronologia detalhada da OP** (`9572`), **medições críticas** (`9619`) e **cruzamento FORM-GQ-0047 × Ficha Mestre × Roteiro da OP** (`9664`).
- **Justificativa de ressalva** — `handleSubmitJustify` (`7857`). Grava texto, autor e timestamp no apontamento, marca o item correspondente da camada como conforme e **recalcula o resultado geral**: se todas as ressalvas foram justificadas e não há NC, o status vira `conforme` e o resumo é reescrito citando quantas ressalvas foram justificadas pelo RT (decisão de 01/07/2026).
- **Reanálise com documentos corrigidos** — `handleReanalisar` (`7939`). Reusa os textos de `slots_text` para os slots não corrigidos, **baixa os arquivos originais do Storage** para que o pacote final contenha os documentos conformes originais (decisão de 19/06/2026), substitui etiquetas de acessório **por código** e permite marcar etiquetas para remoção. Grava na nova análise `analise_origem_id`, `doc_substituido` (lista de slots) e `motivo_reanalise`. Dois modos especiais **não contam como correção** no Dashboard: `modoFicha` (`tipo_reanalise = 'atualizacao_ficha'` — a NC era ficha desatualizada) e `modoCadastro` (`'atualizacao_cadastro'` — faltava cadastrar inspetor).
- **Atualizar a Ficha direto do parecer** — `abrirAtualizarFicha` (`9230`). Abre o editor da Ficha Mestre em overlay; ao salvar, cria nova revisão e **refaz a análise automaticamente** em `modoFicha`. Em seguida oferece **reprocessar em lote** as outras análises pendentes da mesma derivação, que provavelmente têm a mesma NC (`detectarIrmasPendentes`, `plataforma.html:8067`).
- **Exportar parecer em PDF** — `handleExportPDF` (`8250`), via `window.print()` com folha de estilo `@media print` dedicada (`plataforma.html:133-209`): força modo claro, esconde sidebar e elementos `.no-print`, define A4 com margens de 1,5 cm, evita corte de linha em tabelas e preserva cores impressas.
- **Baixar o FORM-GQ-0047** — `handleDownloadForm` (`8308`), XLSX gerado.
- **Pacote do lote (ZIP)** — `handleDownloadZip` (`8656`), o fluxo mais longo do sistema, com indicador de estágio (`zipStage`) porque leva de 30 s a alguns minutos:
  1. restaura os arquivos originais do Storage;
  2. converte o FORM XLSX → PDF;
  3. **anota a OP** com ✓ nos colchetes de inspeção e a data da conciliação (via `pdf-lib`, preservando 100 % do layout original) e **re-converte o PDF** — passo essencial, porque o PDF do Sapiens vem com restrições embutidas que bloqueiam assinatura no Adobe; a re-conversão via Ghostscript/CloudConvert regenera o arquivo sem restrições (`8688-8723`);
  4. inclui RC, etiqueta externa, etiquetas de acessório (em subpasta, preservando os nomes originais com desambiguação de colisão), OP de Reprocesso, RNC e FORM manual;
  5. gera o **Resumo da Análise em PDF** a partir de HTML standalone com o design system embutido (`gerarResumoHTML`, `8383`), com fallback para TXT;
  6. grava o ZIP na pasta da rede via `POST /salvar-pacote` com `X-Extract: true` (descompacta na pasta), opcionalmente dentro da subpasta do **mês da análise** (`8820-8852`);
  7. sobe o ZIP para o bucket `pacotes-analise` para permitir re-download pelo Histórico sem regenerar.

  Cada falha parcial vira um `warning` acumulado e exibido ao final, sem abortar o pacote.
- **Alerta de NC no Slack** — `abrirAlertaSlack` (`8937`) e `confirmarEnvioSlack` (`9072`). Para cada NC aberta o sistema calcula o nível de reincidência da chave *(categoria + equipamento + alvo)* na janela de 30 dias contra a base histórica de ~12 meses, define o **setor responsável pelo documento** (etiqueta → Almoxarifado; OP/RC/FORM/reprocesso/RNC → PCP), extrai o "registro correto" da descrição ou usa `sugestao_correto`, separa a recomendação entre **ação imediata** e **causa raiz** (`separarRecomendacao`, `7741` — só a imediata vai ao Slack, por decisão de que o canal é operacional) e monta um card **editável antes do envio**. NCs classificadas como `pontual` vêm **desmarcadas** por padrão. Cada item pode ser enviado como *solicitação de correção* ou como *dúvida* ("verificar se a Ficha está desatualizada"), com perguntas sugeridas por categoria; dúvidas sobre acessório anexam automaticamente o **quadro atual de acessórios da Ficha** para conferência (`9107-9133`). A menção é resolvida por OP: quem **executou o Estágio 50** é mencionado no canal do Almoxarifado e quem executou o **Estágio 60** no canal do PCP, usando `operadores.slack_user_id` (`9042-9063`). Uma mensagem por canal, separando correções de dúvidas.

### 2.4 Dashboard — `DashboardPage` (`plataforma.html:963`)

Quatro abas (`plataforma.html:1692`): **Gráficos**, **Histórico de correções**, **Tendência e reincidência**, **Melhorias regulatórias**. Filtro temporal no topo (ano / semestre / trimestre / mês / tudo, `976-997`) e recarga em tempo real via Supabase Realtime nas tabelas `analises` e `melhorias_regulatorias` (`973-974`).

**Regra de contagem** (decisão de 18/06/2026, `1072-1105`): cada **lote** conta uma única vez, pelo **estado mais recente** — a análise mais nova daquele par (OP, série). Análises substituídas por reanálise não aparecem. Reanálises do tipo `atualizacao_ficha` e `atualizacao_cadastro` **não contam como correção** (`temCorrecaoReal`, `1088`).

**KPIs** (`1706-1714`): Total de análises (lotes únicos no período), Conforme (com % e nota de que inclui lotes corrigidos) e Conciliações corrigidas (com o documento mais corrigido).

**Gráficos** (todos com exportação individual em **PNG** via canvas e em **PDF** via impressão isolada do card):

| Gráfico | Linha | O que mostra |
|---|---|---|
| Conciliações realizadas (donut) | `1720` | 3 categorias mutuamente exclusivas: conformes sem correção, com ressalvas, precisaram correção |
| Correções por tipo de documento | `1760` | Contagem de `doc_substituido` das reanálises |
| Erros que motivaram correção | `1791` | 22 categorias por regex sobre a descrição do apontamento (Registro ANVISA, Modelo, Nome do produto, CNPJ, Fabricante, Endereço, Telefone, RT, CREA, Responsável Legal, Nº de série, Cronologia incoerente, Data, Validade, Lote/Código, Acessório, Componente/RC, Reprovação em inspeção, Cópia/revisão do FORM, Derivação, Documento ausente/ilegível, Inspeção/Medição), com filtro por documento (todos/OP/RC/etiqueta externa/etiqueta de acessório) |
| Problemas na OP | `1276-1311` | Alternável entre **por estágio** e **por inspeção**, usando as tags `estagios`/`inspecoes` dos apontamentos |
| Erros por tipo de equipamento | `1829` | NCs agrupadas pela família do produto (decisão de 23/06/2026), com lookup no catálogo por modelo/código Sapiens |

Detalhe metodológico relevante: o gráfico de erros usa os apontamentos da análise **original** da cadeia (o que motivou a correção), não do estado final já limpo (`1200-1203`). Apontamentos de aptidão de operador/inspetor são **excluídos** de todos os gráficos de erro (`ehErroOperador`, `1199`), porque deixaram de ser tratados como NC. Só severidade `nao_conforme` entra nas contagens; ressalvas ficam de fora.

**Histórico de correções** (`1861`) — tabela com data, equipamento, OP, modelo, documentos corrigidos, erros que motivaram e motivo, exportável em **XLSX** (`exportarCorrecoesXlsx`, `1547`).

**Tendência e reincidência** (`1924`, cálculo em `1366-1477`) — painel com recorte independente do filtro do topo (presets semana / 30 d / trimestre / semestre / ano + personalizado De–Até). Mostra:

- barras de correções por mês (incluindo meses com zero);
- top categorias de erro e top equipamentos no período;
- total, média mensal e **direção** (em alta / em queda / estável, comparando a soma da primeira metade dos meses com a da segunda, com limiar de ±15 %);
- **tabela de reincidência por chave** *(categoria + equipamento + alvo)*, com ocorrências no período, ocorrências na base histórica (12 meses anteriores ao início), incidência (ocorrências ÷ lotes analisados) e nível classificado por `classificarNivelReinc` (`7712`):
  - **reincidente**: ocorrências ≥ piso **e** incidência ≥ mínimo;
  - **emergente**: ≥ 2 ocorrências **e** (base ≈ 0 com incidência ≥ mínimo, **ou** incidência ≥ fator × base);
  - **possível**: apenas um dos dois gatilhos atingido;
  - **pontual**: nenhum.

  Os limiares (piso 3, incidência 3 %, fator 3×) vêm de `config_app` e são editáveis em Configurações. Para janelas maiores que 31 dias o painel fica **só para consulta**, sem exibir nível nem alerta — os limiares foram calibrados para ~30 dias (`1479-1485`).

**Melhorias regulatórias** (`2022`) — lista os itens M-01…M-05 detectados, com norma, descrição, evidência e ação sugerida. A GQ registra a decisão **acatar** / **não acatar** (`decidirMelhoria`, `1492`); a decisão **encerra o item** — ele sai dos pendentes e não retorna mesmo se detectado de novo. Itens decididos ficam em card separado (`2078`).

**Últimas análises** (`2110`) — as 5 mais recentes, com badge de status, chip de correção (`CorrecaoChip`, `931` — mostra "↻ Nx" com tooltip dos documentos corrigidos e a data da original, ou "✎ ficha atualizada" quando o ajuste foi só de ficha) e ações de abrir/excluir. Exportação do dashboard inteiro em PDF em `1536`.

### 2.5 Histórico — `HistoricoPage` (`plataforma.html:11498`)

Lista todas as análises, mostrando apenas a **mais recente por par (OP, série)** — originais substituídas por reanálise ficam ocultas (decisão de 18/06/2026).

- **Filtros** (`11519-11533`): período (tudo/ano/mês), pendentes, equipamento, modelo (dependente do equipamento selecionado), origem (agente/manual) e status. Ordenação clicável por coluna (decisão de 29/06/2026).
- **Baixar pacote** — `handleDownloadPacote` (`11763`), reaproveita o ZIP salvo no Storage quando existe.
- **Download em lote** (`11507-11511`) — percorre os pacotes pendentes gravando cada um na pasta da rede, com contagem de falhas.
- **Importar análises manuais** — `ImportarAnalisesManuaisModal` (`10446`), decisão de 23/06/2026. Importa XLSX com as conciliações feitas manualmente antes da plataforma, validando cada linha contra o catálogo (modelo e código Sapiens) e exigindo, para status `conforme_corrigido`, pelo menos um tipo de erro. Inclui geração do template de importação (`handleBaixarTemplate`, `10713`).
- **Nova análise manual individual** — `NovaAnaliseManualModal` (`11080`), mesmos campos, uma por vez, com edição posterior. Para `conforme_corrigido` cria o par NC + correção.
- **Marcar NC manual como corrigida** — `CorrigirManualModal` (`10920`), cria a reanálise manual conforme vinculada à NC original via `analise_origem_id`, com tipos de erro pré-preenchidos a partir dos apontamentos.
- **Exportar para auditoria** — `ExportarAuditoriaModal` (`11355`), decisão de 29/06/2026. Seleção de até 50 análises e geração de um super-ZIP com sumário executivo em PDF e uma subpasta por análise contendo o pacote completo.
- **Exportar XLSX** da tabela atual (`11958`) e **backup do histórico inteiro** (`handleBackupHistorico`, `11839`) — busca todas as análises do banco (sem os filtros de tela) e gera planilha com 13 colunas, orientando o envio para `qualidade@confiancemedical.com.br`.

### 2.6 Cadastro — `CadastroPage` (`plataforma.html:12224`)

Três abas: **Catálogo de Produtos**, **Fichas Mestres** e **Template FORM-GQ-0047**.

#### Catálogo de produtos — `CatalogoTab` (`12487`) / `ProdutoModal` (`12650`)

CRUD de `produtos`: equipamento (família), modelo (único), código de referência (prefixo do nº de série), registro ANVISA, código Sapiens, ativo. Corresponde ao FORM-GQ-0085 da empresa.

#### Fichas Mestres — `FichasTab` (`13984`) / `FichaMestreEditor` (`12795`)

Uma ficha por par **(produto, derivação)**. A derivação vive na ficha, não no produto (decisão de 18/06/2026, `plataforma.html:3008-3013`), então um mesmo modelo pode ter várias fichas — uma por variante. As fichas são exibidas agrupadas por produto (`FichasAgrupadas`, `14127`) e exportáveis em XLSX (`14089`).

Conteúdo da ficha:

- **Identificação**: nome comercial, derivação (3 dígitos, obrigatória) e sua descrição, convenção e exemplo de nº de série.
- **Dados regulatórios do fabricante**: razão social, CNPJ, endereço da fábrica, telefone, Responsável Técnico, CREA da RT, Responsável Legal — são exatamente os campos confrontados contra a etiqueta externa na Camada 2.
- **Estágios aplicáveis** — quais dos 10 estágios variáveis se aplicam ao produto (`ESTAGIOS_VARIAVEIS`, `12734`: Separação 5, Preparação de Componentes 7, Montagem 10, Fechamento da Tela 15, Preparação de Gabinete 20, Fechamento e Acabamento Gabinete Plástico 25, Montagem Eletrônica 30, Programação 35, Gravação 39, Finalização 40). Além deles existem 4 **fixos** (`ESTAGIOS_FIXOS`, `12748`: CQ do produto acabado, Embalagem, Conciliação da Produção, Verificação da rotulagem — sempre SIM) e 2 **condicionais** (`ESTAGIOS_CONDICIONAIS`, `12757`: OP de Reprocesso e RNCs associados — SIM se anexado). Total: 16 itens, exatamente as 16 linhas do FORM-GQ-0047.
- **Estágios com inspeção** — quais estágios têm inspeção associada (decisão de 01/07/2026); alimenta o cross-check da Camada 2.
- **Quadro de acessórios** — descrição, código Sapiens, obrigatório/opcional, fabricante Confiance × fornecedor, estéril, "pode sair apenas na NF".
- **Grupos alternativos de acessórios** — bloco com nome do grupo e N variantes (nome + código). Ao salvar, cada variante gera uma linha em `acessorios_aplicaveis` compartilhando `grupo_alternativo` e a mesma flag de obrigatoriedade, porque **a obrigatoriedade é do grupo** ("pelo menos uma variante", `13229-13249`).
- **Regras de negócio** — lista de texto livre (`13061`). Regras no formato "ignorar pasta: X" são interpretadas pela importação de lote (§2.1.2).
- **Ficha revisada e apta para análise** (`apta_analise`) — trava explícita: enquanto não marcada, nenhum lote daquele produto pode ser analisado.

**Revisões com changelog automático:** cada salvamento incrementa `versao` e grava um snapshot em `fichas_mestres_versoes` (`13167-13176`). O motivo da revisão é **pré-preenchido automaticamente** por `gerarResumoAlteracoes` (`13068`), que compara o estado atual com o snapshot anterior e descreve em português o que mudou: acessórios incluídos, acessórios "obsoletos e removidos", alterações de obrigatoriedade e mudanças em RT, CREA, Responsável Legal, convenção de série e descrição da derivação. O texto é editável antes de salvar. Existe também o **backfill retroativo** (`gerarDescricoesRetroativas`, `13121`): percorre as revisões cujo motivo é genérico ("Salvamento", "Criação") e reescreve cada uma comparando snapshots consecutivos via `diffSnapshots` (`13098`).

**Auxiliares de cadastro:**

- `ProdutoSelectorModal` (`13915`) — escolhe o produto ao criar nova ficha, listando só produtos sem ficha, com busca por modelo/equipamento/código.
- `ClonarDerivacaoModal` (`13626`) — cria uma nova derivação clonando os dados de uma derivação existente do mesmo produto.
- `ImportarDocumentosModal` (`13734`) + `handleImportFromDocs` (`12974`) — pré-preenche a ficha a partir de documentos de exemplo (OP + RC + etiqueta externa + etiquetas de acessório), reaproveitando os mesmos parsers da análise.

#### Template FORM-GQ-0047 — `TemplateFormTab` (`12247`)

Gerencia o template oficial usado na geração do FORM. Armazenado no bucket `form-templates` como `current.xlsx`; se o bucket não tiver template, usa a versão **embutida em base64 no HTML** (`plataforma.html:3322`). A tela mostra a origem ativa (bucket × embutido), data de atualização, tamanho e a **data de aprovação extraída da célula A35** do XLSX — que é o dado usado pelo motor para julgar se a revisão do FORM era vigente na data da conciliação (`plataforma.html:6141-6142`, `4555`). Permite upload, download e restauração para o embutido, com wrapper de timeout porque o SDK do Supabase às vezes trava sem retornar erro quando o bucket não existe (`12275-12281`).

O preenchimento (`fillFormXlsxTemplate`, `3447`) usa ExcelJS sobre o template real para **preservar 100 % da formatação** (bordas, fontes, mesclas, logo). Escreve `A9` PRODUTO, `A10` MODELO, `G9` Nº série/Lote e `G10` Data da Conciliação usando **rich text** — rótulo em negrito, valor sem negrito, Times New Roman 11 — e marca as colunas SIM (G) / NÃO (H) / N/A (I) nas 16 linhas de itens (14 a 29) conforme os estágios aplicáveis da Ficha e os flags de OP de Reprocesso/RNC. Também força `horizontalCentered` no `pageSetup` para o PDF sair centralizado.

### 2.7 Pré-preenchimento de documentos (anotação em PDF)

`openPrefill` (`6548`) + `PrefillModal` (`7426`). Duas saídas:

- **OP** → PDF anotado preservando o original: `computeOPAnnotations` (`3763`) localiza os colchetes vazios `[ ]` e os campos "Data" na última página; `annotatePdfPreserveOriginal` desenha ✓ (vetor via `drawCheckmark`, `3278`, evitando dependência de fonte Unicode externa) e a data da conciliação nas coordenadas exatas. A técnica combina PDF.js (extrai texto **com coordenadas**, agrupando itens em linhas via `buildLinesWithMap`, `3216`, para achar `[ ]` mesmo quando o PDF fragmenta os caracteres) com pdf-lib (desenha sobre o mesmo PDF, mesma origem bottom-left).
- **FORM-GQ-0047** → XLSX preenchido (§2.6). `computeFormAnnotations` (`3996`) existe para o caminho de anotação em PDF do FORM.

A pré-visualização do FORM é gerada **em background** assim que a OP é processada, antes de o usuário clicar em "Analisar lote" (`tryGenerateFormPreview`, `6610`).

### 2.8 Configurações — `ConfiguracoesPage` (`plataforma.html:14210`)

- **Pasta de destino do pacote** (`14305`) — caminho no servidor onde o serviço grava o ZIP. Salvo em `config_app` (compartilhado entre todos os usuários) com cache em `localStorage`. Orienta o uso de caminho UNC (`\\servidor\...`) em vez de letra de rede. Opção **"salvar dentro da subpasta do mês da análise"**, para que o download em lote distribua cada análise no mês correto. Botão **Testar serviço** que chama `GET /health` (`14266`).
- **Limiares de reincidência** (`14332`) — piso de ocorrências, incidência mínima (%) e fator de salto vs. histórico, gravados em `config_app` e lidos pelo Dashboard e pelo alerta do Slack.
- **Cadastro de operadores / inspetores** — `GestaoOperadores` (`14373`). Lista global (vale para todos os produtos), organizada por estágio expansível. Cada colaborador tem nome, matrícula (`codigo`), **apelidos** (para casar variações de nome na OP), `estagios` (operação), `estagios_inspecao` (inspeção) e **`slack_user_id`** (usado na menção automática do alerta). Demissão é **inativação**, nunca exclusão — preserva os vínculos de estágio para não invalidar OPs antigas na reanálise (`14370-14372`).
- **Usuários e permissões** — `GestaoUsuarios` (`14769`). Lista os perfis, atribui cargo (que carrega o conjunto padrão de permissões) e permite marcar permissões individuais. O **convite** de novo usuário é feito via `POST /convidar-usuario` no serviço Node (`14797-14801`), porque exige a `service_role` key, que só existe no servidor.

**Ponto de atenção verificado no código:** o componente `GestaoOperacoesLivres` (`14664-14769`) implementa o cadastro de "operações livres" (exceções de aptidão por equipamento/estágio/operação, tabela `operacoes_livres` com migration própria e Realtime habilitado), mas **não está renderizado em nenhum lugar** — `ConfiguracoesPage` monta apenas pasta de destino, reincidência, `GestaoOperadores` e `GestaoUsuarios` (`14301-14364`). A tabela também não é consultada pelo motor de conciliação. É código morto no estado atual, provavelmente resíduo da remoção da conferência de operador em 22/07/2026.

### 2.9 Histórico de alterações (logs) — `LogsPage` (`plataforma.html:14949`)

Trilha de auditoria em `logs_atividade`, gravada por `registrarLog` (`375`) em modo *best-effort* — nunca quebra a ação principal. Cada registro tem usuário (id, nome, e-mail), ação, entidade, referência da entidade, descrição em linguagem natural e metadata JSON. Ações efetivamente registradas no código incluem: `executar_analise`, `refazer_analise`, `atualizar_ficha_reanalise`, `atualizar_cadastro_reanalise`, `justificar_ressalva`, `excluir_analise`, `baixar_pacote`, `editar_config`, `decidir_melhoria`, `exportar_correcoes`, `exportar_logs`, `marcar_operacao_livre`, `remover_operacao_livre` e `solicitar_<ação>`.

A tela lista os 1.000 registros mais recentes com atualização em tempo real, filtro por usuário e por ação, e **exportação XLSX paginada** que busca **todos** os registros do banco em páginas de 1.000 (`14980-15017`) — descrita no próprio comentário como retenção antes da migração para o SCM.

### 2.10 Solicitações e aprovações

Mecanismo para que um usuário sem permissão peça autorização a quem tem, em vez de ficar bloqueado. `ACOES_SOLIC` (`414-425`) define 10 ações solicitáveis, cada uma com a chave de permissão e um **modo**:

- **`executar`** — o sistema executa a ação ao ser aprovada (excluir análise, excluir ficha), via `executarAcaoSolicitada` (`441`).
- **`desbloquear`** — a aprovação libera a ação para o solicitante realizar (refazer análise, justificar ressalva, remover etiqueta, correção manual, importar, baixar pacote, criar/editar ficha, criar/editar produto).

`SolicitacaoProvider` (`456`) expõe `pedirOuExecutar(info, execFn)`, usado em toda a interface: se o usuário tem a permissão, executa direto; se não tem mas já existe uma aprovação liberada e não usada para aquela ação+alvo, **consome a aprovação** (marca `status = 'usada'`) e executa; senão abre o modal de solicitação, listando como possíveis aprovadores os usuários que efetivamente têm a permissão (`usuariosComPermissao`, `436`). `SolicitacoesPage` (`15065`) mostra os pedidos a aprovar e as próprias solicitações.

### 2.11 Usuários, permissões e sessão

- **Login** — `LoginPage` (`734`), `supabase.auth.signInWithPassword`.
- **Primeiro acesso por convite** — `CompletarCadastro` (`15168`): detectado por `type=(invite|recovery|signup)` no hash da URL (`15216`); o usuário define nome completo e senha (mínimo 8 caracteres) via `supabase.auth.updateUser`.
- **Perfil** — `perfis` (id = `auth.users.id`), com `nome_completo`, `cargo`, `permissoes` (JSON de chaves booleanas), `ativo`, `convidado_por`.
- **Cargos e permissões** — 5 cargos (`320-326`), 6 grupos com 19 chaves de permissão (`329-356`) e um mapa cargo → permissões padrão (`358-364`). O administrador (`ADMIN_EMAIL`) tem tudo.
- **Sessão** — `getSession` + `onAuthStateChange` no `App` (`15228-15240`), com carregamento do perfil em seguida (`15243-15255`).
- **Tema claro/escuro** — `localStorage` + classe `dark` no `<html>` (`15217-15226`).
- **Roteamento** — `switch` sobre `currentPage` (`15340-15351`) sincronizado com `window.location.hash` (`15257-15265`).
- **Atalhos de teclado** (`15268-15306`) — prefixo `g` + `d`/`a`/`h`/`c` para navegar, `/` para focar a busca, `?` para a ajuda.
- **Tempo real** — hook `useRealtime(tabela, onChange)` (`393`) assina `postgres_changes` de uma tabela e dispara recarga; usado em `analises`, `melhorias_regulatorias`, `logs_atividade` e `operacoes_livres`.

**Divergência verificada:** a função `can()` do `App` (`15354-15357`) consulta **apenas** `perfil.permissoes[key]`, enquanto `temPermEfetiva` (`428`) — usada para descobrir quem pode aprovar uma solicitação — considera também as permissões padrão do cargo. Consequência prática: um usuário cujo cargo dá direito a uma ação, mas cujas permissões individuais não foram marcadas, aparece como aprovador válido para os outros e ainda assim vê a própria ação bloqueada na interface.

---

## 3. Integrações externas

### 3.1 Supabase (nuvem)

**Projeto:** `https://riqzwwbprdnjxodicxce.supabase.co`
**Autenticação no cliente:** URL e **anon key** em texto claro no topo do arquivo (`plataforma.html:290-291`) — versionadas no Git.
**SDK:** `@supabase/supabase-js@2` via CDN jsDelivr (`plataforma.html:221`), cliente criado em `plataforma.html:314`.

| Serviço | Uso |
|---|---|
| **Auth** | Login por e-mail/senha, sessão com refresh automático, definição de senha no convite, logout. Convite por e-mail via `auth.admin.inviteUserByEmail` no serviço Node (`server.js:200`) com a `service_role` key |
| **Postgres (PostgREST)** | 14 tabelas acessadas direto do navegador: `analises` (30 chamadas), `produtos` (13), `operadores` (10), `fichas_mestres` (9), `fichas_mestres_versoes` (8), `solicitacoes` (7), `acessorios_aplicaveis` (7), `worklist_ops` (6), `config_app` (6), `perfis` (5), `operacoes_livres` (4), `melhorias_regulatorias` (3), `logs_atividade` (3), `apontamentos` (2). A tabela `convites` é escrita pelo serviço Node |
| **Storage** | Bucket `pacotes-analise` — documentos originais de cada análise em `<analise_id>/originais/<slot>_<arquivo>` e o pacote ZIP em `<analise_id>/<nome>.zip`. Bucket `form-templates` — template oficial `current.xlsx` |
| **Realtime** | Publicação `supabase_realtime` nas tabelas `analises`, `perfis`, `solicitacoes`, `logs_atividade`, `worklist_ops`, `melhorias_regulatorias` e `operacoes_livres` (`migration-realtime.sql`, `migration-melhorias-regulatorias.sql`, `migration-operacoes-livres.sql`) |
| **Edge Functions** | `converter-para-pdf` (CloudConvert), chamada em `plataforma.html:8345` com `Authorization: Bearer <access_token do usuário>`, **apenas como fallback** quando o serviço Node local falha |

**Segurança verificada:** todas as políticas RLS conferidas seguem o padrão `for all to authenticated using (true) with check (true)` (`schema.sql`, `migration-usuarios-permissoes-logs.sql`, `migration-solicitacoes-aprovacao.sql`, `migration-config-app.sql`, `migration-fichas-revisoes.sql`, `migration-worklist.sql`, `migration-operadores.sql`, `migration-melhorias-regulatorias.sql`, `migration-operacoes-livres.sql`). Ou seja: **qualquer usuário autenticado pode ler e escrever qualquer registro de qualquer tabela**. O modelo de cargos e permissões descrito em §2.11 é aplicado **somente na interface** — não há enforcement no banco. Com a anon key pública e um usuário válido, o controle de acesso pode ser contornado.

### 3.2 Serviço Node local — `conversor-pdf-local`

Express 4 em `commonjs`, porta padrão 3001, `cors()` liberado, corpo bruto com limite de 80 MB (`server.js:98-100`). Dependências: `libreoffice-convert`, `puppeteer`, `adm-zip`, `dotenv`, `cors`, `express`, `@supabase/supabase-js` (`package.json`). Requer LibreOffice (`soffice`) e Ghostscript (`gswin64c`) instalados no host. No Windows, injeta `windowsHide: true` em todos os `child_process` para não piscar janelas de console (`server.js:29-51`).

| Endpoint | Linha | Função |
|---|---|---|
| `GET /` e `GET /plataforma.html` | `106` | **Serve a própria plataforma por HTTP.** Necessário porque o Supabase não aceita redirect de convite para `file://`. Caminho em `PLATAFORMA_HTML` no `.env` |
| `GET /health` | `113` | Diagnóstico; retorna `{ ok, servico, versao }`. Usado pelo botão "Testar serviço" |
| `POST /converter-pdf` | `118` | Converte para PDF. Office (xlsx/xls/docx/doc/pptx/ppt/odt/ods) via **LibreOffice**; PDF → PDF via **Ghostscript** (`-dPDFSETTINGS=/prepress`, `-dCompatibilityLevel=1.6`, `-dPreserveAnnots=true`) para **remover as restrições do Sapiens** e tornar o arquivo assinável no Adobe; HTML via **Chromium headless/Puppeteer** (A4, `printBackground`) |
| `POST /salvar-pacote` | `150` | Grava o pacote na pasta do servidor. Headers `X-Dest-Path`, `X-Filename`, `X-Extract`. Com `X-Extract: true`, descompacta o ZIP entrada por entrada com `writeFileSync` — extração manual deliberada, porque o `chmod` do `extractAllTo` falha em pastas de rede UNC com ENOENT (`server.js:161-172`). Bloqueia path traversal (`..`) e sanitiza o nome do arquivo |
| `POST /convidar-usuario` | `193` | Convida via `auth.admin.inviteUserByEmail`, faz upsert em `perfis` (cargo + permissões + `convidado_por`) e insere em `convites`. **Única razão de existir da `service_role` key** |
| `POST /notificar-slack` | `243` | Repassa o texto para o Incoming Webhook do canal escolhido. Nenhuma lógica de menção fica no servidor — o texto vem pronto da plataforma. Expõe `err.cause` no erro para diagnosticar ENOTFOUND/ETIMEDOUT/certificado |
| `POST /pcp-status` | `269` | Baixa o CSV publicado da planilha do PCP e devolve as OPs marcadas como OK |

**Endereço no cliente** (`plataforma.html:306-308`): se a plataforma é servida por HTTP/HTTPS, usa a **mesma origem** + `/converter-pdf` (funciona de qualquer máquina da rede); se aberta como `file://`, cai em `http://localhost:3001/converter-pdf`. Os outros endpoints são derivados removendo o sufixo `/converter-pdf` (`8835`, `9081`, `14270`, `14800`).

**Segurança verificada:** nenhum endpoint exige autenticação. `POST /salvar-pacote` aceita **qualquer caminho** em `X-Dest-Path` e cria a pasta com `mkdirSync({recursive:true})`. `POST /convidar-usuario` cria usuários no Supabase Auth sem verificar quem está chamando. Combinado com `cors()` totalmente aberto, qualquer origem que alcance a porta 3001 pode gravar arquivos no servidor e convidar usuários.

### 3.3 Slack

Dois canais, um **Incoming Webhook** por canal, todos em variáveis de ambiente do serviço Node (`server.js:229-237`):

| Variável | Canal | Recebe |
|---|---|---|
| `SLACK_WEBHOOK_PCP` | `pcp_gq` | NCs de OP, RC, FORM, OP de Reprocesso, RNC |
| `SLACK_WEBHOOK_ALMOXARIFADO` | `almoxarifado_gq` | NCs de etiqueta externa e de acessório |
| `SLACK_WEBHOOK_URL` | geral | Fallback usado quando o webhook específico não está configurado |

O roteamento por canal é decidido na plataforma pelo **dono do documento** (`responsavelPorSlot`, `plataforma.html:8923-8927`). A menção usa o formato nativo `<@U0123456789>`, montada no texto pela plataforma a partir de `operadores.slack_user_id`, resolvendo **quem executou o Estágio 50 ou 60 naquela OP específica** (§2.3). A `migration-slack-contatos.sql` está marcada como **SUPERSEDIDA** no próprio arquivo: a abordagem de lista solta de contatos por setor foi substituída, na mesma data (11/08/2026), por essa resolução automática — a migration válida é `migration-operadores-slack-id.sql`.

### 3.4 Planilha do PCP (CSV publicado do Google Sheets)

Implementada **apenas no serviço Node**: `POST /pcp-status` (`server.js:269-306`) recebe `{ csvUrl, colOP, colOK }`, baixa o CSV publicado (feito no servidor para evitar CORS), parseia com um parser CSV próprio que trata aspas e vírgulas dentro de campo (`server.js:59`), procura a linha de cabeçalho que contenha as duas colunas nas primeiras 15 linhas e devolve as OPs cujo valor na coluna de confirmação está em `{ok, sim, s, x, ✓, true, v}` — deduplicado, com timestamp.

**Estado verificado:** `plataforma.html` **não chama** este endpoint. Não há referência a `/pcp-status`, `csvUrl`, `colOP` ou `colOK` em nenhum ponto do frontend. A dupla checagem contra a planilha do PCP existe no backend, mas não está ligada à interface.

### 3.5 CloudConvert (via Edge Function) — dependência de fallback

`edge-function/converter-para-pdf.ts` chama a API v2 do CloudConvert com a secret `CLOUDCONVERT_API_KEY`, configurada no Supabase. É acionada por `convertToPdf` (`plataforma.html:8366-8375`) **somente** quando o serviço local está indisponível ou falha — para não travar a geração do pacote. É o caminho original, anterior ao serviço Node.

### 3.6 Google Gemini — presente no repositório, não utilizado

`edge-function/analisar-conciliacao.ts` (345 linhas) implementa a análise por LLM (Gemini Flash com o "Protocolo v1.1", secret `GEMINI_API_KEY`). **Não é chamada pelo código atual**: a única referência a `functions/v1` em `plataforma.html` é `converter-para-pdf` (`8345`). O comentário em `plataforma.html:6892-6893` é explícito: *"Análise 100 % local — regras determinísticas em JS aplicadas aos textos extraídos. Sem chamada a API externa de LLM."* A arquitetura migrou de LLM para regras determinísticas; a Edge Function permaneceu no repositório como histórico.

### 3.7 CDNs públicas

Onze recursos carregados de CDN em tempo de execução (`plataforma.html:9-246`) — Google Fonts (Montserrat, Raleway), `cdn.tailwindcss.com`, React 18 UMD e ReactDOM (unpkg), `@babel/standalone@7.24.7` (unpkg), `@supabase/supabase-js@2` (jsDelivr), PDF.js 3.11.174 + worker (cdnjs), pdf-lib 1.17.1 (unpkg), Mammoth 1.7.0 (cdnjs), SheetJS/xlsx 0.18.5 (jsDelivr), ExcelJS 4.4.0 (jsDelivr), JSZip 3.10.1 (jsDelivr).

Sem internet, ou com qualquer uma dessas CDNs bloqueada/fora do ar, **a aplicação não carrega**. O pin do Babel em 7.24.7 é deliberado e documentado (`plataforma.html:215-217`): versões 7.25+ geram `import` no output e a injeção de script inline quebra com *"Cannot use import statement outside a module"*.

---

## 4. Arquitetura técnica atual

### 4.1 Topologia

```
┌──────────────────────────────────────────────────────────────────────┐
│  NAVEGADOR (Chrome na estação da GQ)                                 │
│                                                                       │
│  plataforma.html — 979 KB / 15.393 linhas / arquivo único            │
│   ├─ <head>: 11 recursos de CDN + tokens CSS do design system        │
│   └─ <script type="text/babel">  ← transpilado por Babel EM RUNTIME  │
│        · React 18 (UMD, sem build)                                   │
│        · ~90 componentes e funções em um único escopo                │
│        · Extração de texto: PDF.js · Mammoth · ExcelJS · CSV         │
│        · MOTOR DE CONCILIAÇÃO (~1.500 linhas, 100 % client-side)     │
│        · Geração: FORM XLSX (ExcelJS) · OP anotada (pdf-lib)         │
│                  pacote ZIP (JSZip) · PNG (canvas) · PDF (print)     │
└───────┬──────────────────────────────────────────┬────────────────────┘
        │ HTTPS (supabase-js / PostgREST)          │ HTTP (rede interna)
        ▼                                           ▼
┌───────────────────────────────┐   ┌──────────────────────────────────┐
│  SUPABASE (nuvem)             │   │  SERVIÇO NODE LOCAL :3001        │
│   · Auth (e-mail/senha)       │   │   · GET  /  → serve o HTML       │
│   · Postgres — 14 tabelas     │   │   · POST /converter-pdf          │
│     RLS: authenticated=true   │   │     LibreOffice · Ghostscript    │
│   · Storage — 2 buckets       │   │     Chromium/Puppeteer           │
│   · Realtime — 7 tabelas      │   │   · POST /salvar-pacote → rede   │
│   · Edge Fn converter-para-pdf│   │   · POST /convidar-usuario       │
│     └─→ CloudConvert (fallbk) │   │   · POST /notificar-slack ──────┐│
└───────────────────────────────┘   │   · POST /pcp-status (não usado)││
                                     └──────────────────┬──────────────┘│
                                     ┌──────────────────▼─────┐  ┌──────▼────────┐
                                     │ Pasta da rede (UNC)    │  │ Slack Webhooks│
                                     │ Pendente de Assinatura │  │ pcp_gq        │
                                     │ └─ <MÊS>/              │  │ almoxarifado_gq│
                                     └────────────────────────┘  └───────────────┘
```

### 4.2 Frontend: arquivo único, sem build

- **Um arquivo**: `plataforma.html`, 979 KB, 15.393 linhas — HTML, CSS e todo o JavaScript da aplicação.
- **Sem build**: não há `package.json`, `vite.config`, `tsconfig` nem `node_modules` na raiz. O código JSX vive dentro de `<script type="text/babel" data-presets="env,react">` (`plataforma.html:285`) e é **transpilado pelo Babel dentro do navegador a cada carregamento da página**.
- **React 18 via CDN**: builds UMD `react.production.min.js` e `react-dom.production.min.js` do unpkg (`213-214`); montagem com `ReactDOM.createRoot` (`15385`).
- **Sem TypeScript**: JavaScript puro. Nenhuma anotação de tipo, nenhuma verificação estática.
- **Sem módulos**: as ~90 funções e componentes vivem no mesmo escopo do script. Não há `import`/`export` — o pin do Babel existe justamente porque versões novas emitem `import` e quebram esse modelo.
- **Estilização**: **Tailwind via CDN** (`cdn.tailwindcss.com`, linha 14), configurado inline em `tailwind.config` (`16-53`) com `darkMode: 'class'`, fontes Montserrat/Raleway e um mapa de cores que aponta para variáveis CSS. Sobre isso, um bloco de tokens CSS próprio (`57-210`) implementa o **design system Confiance** com a paleta oficial do Manual da Marca (Azul Marinho `#1F2C4E`, Azul Médico `#326A84`, Ciano `#64C3D1`, Turquesa `#1E9DBA`, Laranja `#FFA300`), tema claro e escuro, cores de status (conforme/ressalva/não conforme) e uma folha de estilo de impressão completa (`133-209`). Ou seja: **Tailwind CDN + CSS customizado**, sem passo de build e sem purge — a CDN inclui o compilador Tailwind inteiro no cliente.
- **Componentes de UI escritos à mão**: `Button` com 6 variantes e 4 tamanhos (`602`), `Card`/`CardHeader`/`CardTitle`/`CardDescription`/`CardContent` (`626-632`), `Input` (`634`), `Textarea` (`638`), `Label` (`642`), `StatusBadge` (`646`), `PageHeader` (`661`), `Modal` com 4 larguras e fechamento por Escape (`672`), `ToastProvider` próprio (`703`). A API imita shadcn/ui, mas nada vem de shadcn nem de Radix.
- **Ícones**: componente `Icon` (`559`) com 24 caminhos SVG inline. Não usa lucide-react.
- **Gráficos**: `DonutChart` (`2170`) é SVG puro (círculos com `strokeDasharray`/`strokeDashoffset` rotacionados −90°); `BarChart` (`2208`) são divs com largura proporcional. A exportação em PNG (`exportarBarChartPNG`, `2228`; `exportarDonutPNG`, `2265`) desenha o gráfico num `<canvas>` e baixa o blob. Nenhuma biblioteca de gráficos — verificado: zero ocorrências de Recharts, Chart.js, react-router, TanStack Query, react-hook-form, Zod ou lucide-react no arquivo.
- **Estado e dados**: `useState`/`useEffect`/`useMemo`/`useCallback`/`useRef` e chamadas diretas ao `supabase-js`. Sem gerenciador de estado e sem camada de cache; o padrão de recarga é um contador `reloadKey` incrementado por Realtime ou por ação do usuário.
- **Roteamento**: `switch` sobre `currentPage` (`15340-15351`) espelhado em `window.location.hash`.
- **Contextos**: `PermContext` (permissões), `SolicitacaoContext` (aprovações) e `ToastContext`.
- **Defesa contra vazamento de texto** (`plataforma.html:257-283`): CSS que oculta qualquer filho direto do `<body>` que não seja `#root`, mais um `MutationObserver` que remove text nodes soltos — proteção contra vazamentos do Babel e de extensões de navegador injetando conteúdo.

### 4.3 Persistência: onde os dados realmente ficam

**Não existe MySQL local. Não existe banco de dados na empresa.** Todo o dado de negócio está no **Supabase (PostgreSQL gerenciado, nuvem)**, projeto `riqzwwbprdnjxodicxce`.

| Tabela | Conteúdo | Origem do schema |
|---|---|---|
| `produtos` | Catálogo (equipamento, modelo único, código de referência, registro ANVISA, código Sapiens, ativo) | `schema.sql` |
| `fichas_mestres` | Ficha por (produto, derivação): dados regulatórios, convenção de série, `estagios_aplicaveis`, `estagios_com_inspecao`, `regras_negocio`, `produtos_associados`, `apta_analise`, `versao`, `ativa` | `schema.sql` + 5 migrations |
| `fichas_mestres_versoes` | Snapshot JSON + motivo de cada revisão | `migration-fichas-revisoes.sql` |
| `acessorios_aplicaveis` | Quadro de acessórios da ficha, com `grupo_alternativo`, `esteril`, `is_fabricante_confiance`, `pode_sair_apenas_na_nf` | `schema.sql` + `migration-grupo-alternativo-acessorios.sql` |
| `analises` | Uma linha por análise: OP, série, produto, status, `parecer_resumo`, **`parecer_completo` (jsonb — o parecer inteiro)**, `analise_origem_id`, `doc_substituido`, `motivo_reanalise`, `tipo_reanalise`, `origem_analise` | `schema.sql` + `migration-tipo-reanalise.sql` |
| `apontamentos` | NCs e ressalvas normalizadas (também duplicadas dentro de `parecer_completo`) | `schema.sql` |
| `perfis` | Usuário: cargo, `permissoes` (jsonb), ativo, convidado_por | `migration-usuarios-permissoes-logs.sql` |
| `convites` | Convites emitidos (escrita apenas pelo serviço Node) | idem |
| `logs_atividade` | Trilha de auditoria | idem |
| `solicitacoes` | Pedidos de aprovação com estado (`pendente`/`aprovada`/`usada`/`recusada`) | `migration-solicitacoes-aprovacao.sql` |
| `config_app` | Configuração compartilhada chave/valor (pasta de destino, por-mês, limiares de reincidência) | `migration-config-app.sql` |
| `operadores` | Colaboradores × estágios de operação e de inspeção, apelidos, matrícula, `slack_user_id` | `migration-operadores.sql` + 2 migrations |
| `operacoes_livres` | Exceções de aptidão (**tabela sem uso pela interface**) | `migration-operacoes-livres.sql` |
| `melhorias_regulatorias` | Sugestões M-01…M-05 com decisão (`pendente`/`acatada`/`nao_acatada`) | `migration-melhorias-regulatorias.sql` |
| `worklist_ops` | Fila de OPs finalizadas importadas do Sapiens | `migration-worklist.sql` |

Tabelas do schema original **não usadas** pelo código atual: `documentos_analise`, `roteiro_form_gq_0047`, `inspecoes_criterios`, `componentes_bom` — resíduos do modelo anterior, quando a BOM completa e o roteiro eram escopo da plataforma (hoje a análise da RC está restrita a acessórios, decisão de 29/05/2026 documentada em `plataforma.html:4660-4667`).

**Arquivos** ficam em dois lugares simultaneamente: no **Supabase Storage** (bucket `pacotes-analise`, para reanálise e re-download) e na **pasta da rede da empresa**, gravados pelo serviço Node (o destino operacional, onde o RT assina).

**Não há migração versionada nem controle de schema.** As 17 migrations são scripts soltos na raiz, aplicados manualmente no Supabase Studio, sem ordem declarada nem registro de quais já rodaram.

### 4.4 Backend: o que existe de fato

Duas peças, nenhuma delas uma API de aplicação:

1. **Serviço Node/Express local** (§3.2) — 352 linhas fazendo conversão de documentos, gravação em pasta de rede, convite de usuário, repasse ao Slack e leitura do CSV do PCP. Não tem camada de dados, não expõe recursos de negócio, não versiona rotas e não autentica requisições. É um utilitário de sistema operacional exposto por HTTP.
2. **Edge Function `converter-para-pdf`** — fallback de conversão via CloudConvert.

**Toda a lógica de negócio roda no navegador.** Parsing, motor de conciliação, cálculo de indicadores, reincidência, geração de documentos e decisão de status — tudo client-side. O banco é acessado diretamente pelo cliente via PostgREST, com RLS permissiva. Não existe camada de serviço, nem validação server-side, nem autorização no servidor.

### 4.5 Consequências operacionais desse desenho

- **Desempenho**: o Babel transpila 979 KB a cada carregamento; o console emite o aviso *"code generator has deoptimised the styling"*. O tempo de inicialização cresce linearmente com o arquivo.
- **Manutenção**: 15.393 linhas em um escopo único, sem tipos, sem testes e sem fronteiras de módulo. Uma renomeação errada só aparece em runtime.
- **Disponibilidade**: depende de internet (Supabase + 11 CDNs) **e** do serviço local no ar. A queda de qualquer um degrada ou impede o uso.
- **Segurança**: anon key versionada no Git; RLS permitindo tudo a qualquer autenticado; serviço local sem autenticação aceitando gravação em caminho arbitrário e criação de usuários.
- **Conformidade regulatória**: dado de qualidade de dispositivo médico (rastreabilidade ISO 13485 §7.5.9, registros §4.2.5) armazenado em provedor de nuvem externo, com controle de acesso apenas de interface. Isso é auditável negativamente e é a razão de fundo pela qual o padrão da empresa proíbe banco em nuvem.

---

## 5. Aderência ao Padrão de Desenvolvimento de Sistemas da Confiance Medical

Legenda: **ATENDE** · **PARCIAL** (atende parcialmente) · **NÃO ATENDE**.

### 5.1 Stack frontend

| # | Requisito do padrão | Status | Evidência no código | Risco / impacto de não atender |
|---|---|---|---|---|
| 1 | React 18 | **PARCIAL** | React 18 UMD via CDN unpkg (`plataforma.html:213-214`); `ReactDOM.createRoot` (`15385`) | Baixo. A versão é a correta, mas a forma de consumo (CDN, sem npm) impede lockfile, auditoria de dependências e build reproduzível |
| 2 | TypeScript (TSX) em todos os arquivos, evitando `any` | **NÃO ATENDE** | Todo o código em JS dentro de `<script type="text/babel" data-presets="env,react">` (`285`). Zero anotações de tipo | **Alto.** 15.393 linhas sem verificação estática. Erros de contrato (ex.: campo renomeado no parecer) só aparecem em runtime, potencialmente num parecer de lote real |
| 3 | Vite + `@vitejs/plugin-react-swc` | **NÃO ATENDE** | Nenhum `package.json`/`vite.config` na raiz. Babel standalone 7.24.7 transpila no navegador (`218`) | **Alto.** Sem build: sem tree-shaking, sem code splitting, sem minificação, sem source maps. O pin do Babel é uma trava técnica documentada (`215-217`) |
| 4 | Tailwind CSS | **PARCIAL** | Tailwind por CDN (`14`) + `tailwind.config` inline (`16-53`) + 154 linhas de tokens CSS próprios (`57-210`) | Médio. Tailwind é usado, mas via CDN o compilador roda no cliente, sem purge; o CSS final não é otimizado nem versionado |
| 5 | shadcn/ui (Radix UI) | **NÃO ATENDE** | `Button` (`602`), `Card` (`626`), `Input` (`634`), `Textarea` (`638`), `Label` (`642`), `Modal` (`672`) escritos à mão | Médio. Sem Radix, componentes interativos não têm o tratamento de acessibilidade (foco, ARIA, navegação por teclado) que o padrão pressupõe |
| 6 | lucide-react | **NÃO ATENDE** | Componente `Icon` com 24 SVGs inline (`559-597`) | Baixo. Divergência visual e de manutenção; adicionar ícone exige editar o switch |
| 7 | React Router DOM v6 | **NÃO ATENDE** | `switch (currentPage)` (`15340-15351`) + sincronização manual com `window.location.hash` (`15257-15265`) | Médio. Sem rotas reais: não há deep link para uma análise específica, nem parâmetros de rota, nem guards de rota |
| 8 | TanStack React Query v5 | **NÃO ATENDE** | `useState`/`useEffect` + `supabase-js` direto; recarga por contador `reloadKey` | Médio. Sem cache, sem dedupe, sem retry. O Histórico faz `select('*')` de **todas** as análises a cada recarga (`11538`) |
| 9 | React Hook Form + Zod | **NÃO ATENDE** | Formulários controlados manualmente; validação imperativa (ex.: `13143-13162` na Ficha Mestre) | Médio. Validação espalhada e não declarativa; sem schema único de verdade entre formulário e persistência |
| 10 | Recharts | **NÃO ATENDE** | `DonutChart` em SVG (`2170`), `BarChart` em divs (`2208`), PNG via canvas (`2228`/`2265`) | Baixo–médio. Funciona, mas sem tooltip, eixos, legenda interativa ou responsividade de biblioteca; cada novo gráfico é código novo |
| 11 | Sonner / shadcn Toaster | **NÃO ATENDE** | `ToastProvider` próprio (`703-729`) | Baixo |
| 12 | Alias `@/` → `src/` | **NÃO ATENDE** | Arquivo único, sem módulos nem imports | Consequência direta do item 3 |

### 5.2 Backend e persistência

| # | Requisito do padrão | Status | Evidência no código | Risco / impacto de não atender |
|---|---|---|---|---|
| 13 | MySQL no servidor local da empresa | **NÃO ATENDE** | Supabase PostgreSQL na nuvem, `riqzwwbprdnjxodicxce` (`290`); 14 tabelas acessadas do navegador | **CRÍTICO.** Violação de proibição explícita. Dado de qualidade de dispositivo médico fora do perímetro da empresa, com retenção e disponibilidade sob contrato de terceiro |
| 14 | API REST em `/SIGLA/api/v1/` | **NÃO ATENDE** | Nenhuma API de aplicação. Navegador → PostgREST via `supabase-js`. O serviço Node expõe 7 rotas sem prefixo nem versionamento (`server.js:106-306`) | **CRÍTICO.** Sem contrato de API não há como versionar, autorizar no servidor, auditar acesso, nem trocar o banco sem reescrever o cliente |
| 15 | URL base em `src/config/api.ts` | **NÃO ATENDE** | `SUPABASE_URL`/`SUPABASE_ANON_KEY` no topo do HTML (`290-291`); `CONVERSAO_PDF_LOCAL` derivado de `location.origin` (`306-308`) | Médio. Ambiente não é configurável sem editar o arquivo de produção; **a anon key está versionada no Git** |
| 16 | **PROIBIDO** banco em nuvem | **NÃO ATENDE** | Supabase Postgres | **CRÍTICO** — ver item 13 |
| 17 | **PROIBIDO** armazenamento persistente em serviço externo | **NÃO ATENDE** | Buckets `pacotes-analise` (originais + ZIPs) e `form-templates` (`current.xlsx`) | **CRÍTICO.** Documentos originais de lote — evidência de conformidade — residem em provedor externo |
| 18 | **PROIBIDO** backend serverless em nuvem como destino final de dados | **PARCIAL** | Edge Function `converter-para-pdf` (`8345`) é fallback de conversão, sem persistir dado. Mas ela chama **CloudConvert**, para onde o documento é enviado. `edge-function/analisar-conciliacao.ts` (Gemini) está no repositório e **não é chamada** | Médio–alto. Não é destino final de dados, mas há tráfego de documento de lote para dois terceiros (Supabase + CloudConvert) |
| — | Enforcement de autorização no banco | **NÃO ATENDE** | Todas as RLS conferidas: `for all to authenticated using (true) with check (true)` | **CRÍTICO.** Permissões só existem na interface. Qualquer usuário autenticado pode ler/alterar/apagar qualquer registro de qualquer tabela |

### 5.3 Autenticação

| # | Requisito do padrão | Status | Evidência no código | Risco / impacto de não atender |
|---|---|---|---|---|
| 19 | Autenticação **delegada ao SCM** | **NÃO ATENDE** | `LoginPage` própria com `supabase.auth.signInWithPassword` (`745`) | **CRÍTICO — é o maior desvio.** O padrão diz que sistemas satélite nunca implementam autenticação própria. Há um segundo diretório de identidades na empresa, com ciclo de vida (admissão, desligamento, troca de senha) desacoplado do SCM. Um desligamento no SCM não revoga o acesso aqui |
| 20 | Sem login / cadastro / senha próprios | **NÃO ATENDE** | Tela de login (`734`); `CompletarCadastro` define senha via `auth.updateUser` (`15181`); convite por e-mail com `auth.admin.inviteUserByEmail` usando `service_role` (`server.js:200`) | **CRÍTICO.** O sistema tem fluxo completo de gestão de credenciais — exatamente o que o padrão veda |
| 21 | Ler `auth_token`, `auth_refresh_token`, `auth_user`, `auth_permissoes` do `localStorage` | **NÃO ATENDE** | `localStorage` usado só para tema (`15218`) e cache da pasta de destino (`14215-14216`). Sessão gerenciada pelo Supabase | **Alto.** Sem SSO com o restante do ecossistema; o usuário faz login duas vezes |
| 22 | Enviar o JWT como Bearer token | **PARCIAL** (mecanismo diferente) | `supabase-js` envia automaticamente o JWT do Supabase; a Edge Function recebe `Authorization: Bearer <access_token>` (`8348`) | Médio. O mecanismo existe, mas o token é do Supabase, não do SCM — inútil para autorização centralizada |
| 23 | Redirecionar ao SCM quando o token está ausente | **NÃO ATENDE** | Sem sessão, renderiza `LoginPage` (`15331-15333`) | **Alto** — consequência dos itens 19–21 |
| 24 | Permissões em 3 níveis (1 = Usuário, 2 = Administrador, 3 = Gestor) via `auth_permissoes` | **NÃO ATENDE** | Modelo próprio: 5 cargos (`320-326`) × 19 chaves de permissão em 6 grupos (`329-356`), com mapa cargo → padrão (`358-364`), persistido em `perfis.permissoes` | **Alto.** Modelo mais granular que o padrão, mas incompatível: a migração exige mapear 19 chaves para 3 níveis, decidindo caso a caso o que cada nível pode. Agravante interno: `can()` (`15354`) ignora as permissões padrão do cargo, enquanto `temPermEfetiva` (`428`) as considera — comportamento inconsistente entre "quem pode aprovar" e "quem pode agir" |

### 5.4 Estrutura de pastas e convenções

| # | Requisito do padrão | Status | Evidência no código | Risco / impacto de não atender |
|---|---|---|---|---|
| 25 | `src/components`, `src/config`, `src/contexts`, `src/hooks`, `src/lib`, `src/pages/[modulo]`, `src/services/api/[modulo]` | **NÃO ATENDE** | Um arquivo, um escopo, ~90 funções e componentes (`plataforma.html`) | **Alto.** Impossível trabalhar em paralelo sem conflito de merge; impossível testar unidade isolada; impossível reaproveitar componente em outro sistema |
| 26 | Comentários e nomes em português | **ATENDE** | `analisarConciliacao`, `fichas_mestres`, `apontar`, `derivacaoOrfa`, `cadastrosPendentes`; comentários em pt-BR com data e autor das decisões de negócio | — |
| — | Rastreabilidade das decisões de negócio no código | **ATENDE** (boa prática além do padrão) | Comentários datados: 29/05, 03/06, 16/06, 17/06, 18/06, 23/06, 26/06, 29/06, 30/06, 01/07, 06/07, 10/07, 15/07, 22/07, 06/08/2026 | Esse registro é o que torna a migração 1:1 viável — deve ser **preservado** na reescrita |

### 5.5 Placar

| Categoria | Requisitos | ATENDE | PARCIAL | NÃO ATENDE |
|---|---|---|---|---|
| Stack frontend | 12 | 0 | 2 | 10 |
| Backend / persistência | 7 | 0 | 1 | 6 |
| Autenticação | 6 | 0 | 1 | 5 |
| Estrutura e convenções | 3 | 2 | 0 | 1 |
| **Total** | **28** | **2** | **4** | **22** |

### 5.6 Os quatro desvios que mandam no cronograma

1. **Autenticação própria (Supabase Auth)** — proibição explícita do padrão, com consequência de governança real: credenciais e ciclo de vida de acesso fora do SCM.
2. **Banco e Storage em nuvem** — proibição explícita, com consequência regulatória: evidência de conformidade de dispositivo médico fora do perímetro da empresa.
3. **Ausência de API REST + RLS permissiva** — a autorização não existe no servidor. Corrigir isso não é ajuste: é construir a camada que hoje não existe.
4. **Ausência de build e de TypeScript** — impede refatorar o motor de conciliação com segurança, que é justamente o que a migração exige fazer.

---

## 6. O que falta para adequação total

Priorizado do mais crítico ao menos crítico. "Esforço" é estimativa de desenvolvimento dedicado, sem validação com a GQ.

| # | Pendência | Por que é crítico | Esforço |
|---|---|---|---|
| 1 | **Substituir a autenticação própria pelo modelo SCM** — remover `LoginPage`, `CompletarCadastro`, o convite via `service_role` e toda a dependência do Supabase Auth; passar a ler `auth_token`/`auth_refresh_token`/`auth_user`/`auth_permissoes` do `localStorage`, enviar Bearer token e redirecionar ao SCM quando ausente | Proibição explícita do padrão. Enquanto existir, há um diretório paralelo de identidades: desligamento no SCM não revoga acesso ao sistema | 1–2 sem. |
| 2 | **Migrar o banco do Supabase Postgres para MySQL no servidor local** — modelar as 14 tabelas em MySQL 8, incluindo tratamento dos campos `jsonb` (`parecer_completo`, `permissoes`, `estagios_com_inspecao`, `regras_negocio`, snapshots de revisão) | Proibição explícita. Dado de qualidade regulada fora do perímetro | 2–3 sem. |
| 3 | **Construir a API REST `/SIGLA/api/v1/`** com autorização server-side por nível (1/2/3), substituindo todo o acesso direto do navegador ao banco | Sem isso, a permissão continua sendo só de interface — o problema de segurança mais grave hoje | 3–4 sem. |
| 4 | **Migrar o Storage para o servidor local** — documentos originais, pacotes ZIP e template do FORM saem dos buckets `pacotes-analise` e `form-templates` para o filesystem da empresa, servidos pela API | Proibição explícita. Evidência de conformidade em provedor externo | 1 sem. |
| 5 | **Portar o motor de conciliação para TypeScript, 1:1, com suíte de regressão** — `analisarConciliacao`, `gerarSugestoesRegulatorias`, os 5 parsers, `detectarProdutoNoTexto` e `loadProdutosComFichas`, preservando cada regra e cada comentário datado | É onde está o valor do sistema e onde uma regressão silenciosa causa dano regulatório: um lote liberado com NC não detectada | 3–4 sem. (inclui testes) |
| 6 | **Reescrever a interface na stack oficial** — Vite + React 18 + TS + Tailwind (build) + shadcn/ui + lucide-react + React Router v6 + TanStack Query v5 + React Hook Form/Zod + Recharts + Sonner, na estrutura `src/` prescrita | Item 25 do padrão; é também o que resolve desempenho e manutenibilidade | 4–6 sem. |
| 7 | **Mapear as 19 chaves de permissão para os 3 níveis do SCM** — decidir, chave por chave, o nível mínimo; corrigir a inconsistência entre `can()` e `temPermEfetiva`; decidir o destino do fluxo de Solicitações (10 ações), que não tem equivalente no padrão | Sem decisão explícita, a migração ou afrouxa (estagiário podendo excluir análise) ou trava a operação | 3–5 dias + decisão da GQ |
| 8 | **Substituir o serviço Node por endpoints REST versionados** — conversão de PDF, gravação de pacote, alerta Slack e status do PCP passam a viver em `/SIGLA/api/v1/`, com autenticação | Hoje o serviço é anônimo e aceita gravar em caminho arbitrário do servidor | 1–2 sem. |
| 9 | **Eliminar a dependência de CloudConvert** — o serviço local já cobre 100 % dos formatos (LibreOffice, Ghostscript, Chromium); remover o fallback que envia documento de lote a terceiro | Tráfego de documento regulado para fora da empresa | 1–2 dias |
| 10 | **Internalizar as 11 dependências de CDN** — passam a ser dependências npm resolvidas no build | Hoje a aplicação não abre sem internet, e nenhuma versão está travada em lockfile | incluído no item 6 |
| 11 | **Migrar os dados históricos** — análises (com `parecer_completo` inteiro), fichas e suas revisões, acessórios, apontamentos, operadores, logs, solicitações, melhorias, configuração e worklist, mais os arquivos do Storage | Sem histórico não há indicador, não há tendência, não há reincidência e não há evidência para auditoria | 1–2 sem. |
| 12 | **Instituir versionamento de schema** — as 17 migrations soltas, aplicadas manualmente, viram migrations ordenadas e rastreadas na ferramenta escolhida | Hoje não há como saber quais migrations rodaram em qual ambiente | 2–3 dias |
| 13 | **Remover o código morto** — `GestaoOperacoesLivres` e a tabela `operacoes_livres` (não renderizados/consultados), `edge-function/analisar-conciliacao.ts` (Gemini, não chamada), `migration-slack-contatos.sql` (já marcada como supersedida), tabelas `documentos_analise`, `roteiro_form_gq_0047`, `inspecoes_criterios` e `componentes_bom` | Reescrever código morto é desperdício e reintroduz ambiguidade | 1–2 dias |
| 14 | **Decidir o destino da integração com a planilha do PCP** — `POST /pcp-status` existe e funciona no servidor, mas nunca é chamado pelo frontend | Se a dupla checagem é requisito, precisa ser implementada; se não é, o endpoint deve sair | decisão da GQ |
| 15 | **Rotacionar credenciais expostas** — a anon key do Supabase está versionada no Git; a `service_role` key vive no `.env` do serviço (fora do Git, mas em máquina sem autenticação de rota) | Higiene mínima, independentemente da migração | 1 dia |

**Total estimado: 14 a 20 semanas** de desenvolvimento dedicado (~3,5 a 5 meses), assumindo um desenvolvedor em dedicação integral e considerando que os itens 5 e 6 podem correr em paralelo com 2 e 3. Validação e homologação com a GQ correm por fora.

---

## 7. Guia de migração

Premissa que atravessa todas as fases: **o sistema atual permanece em produção até a regressão fechar em 100 %.** Nenhum corte antes disso. Nada aqui é big-bang.

### Fase 1 — Levantamento de dados e mapeamento de schema

**Objetivo:** conhecer o dado real antes de modelar o destino.

1. **Extrair o schema efetivo do Supabase.** As 17 migrations soltas na raiz não descrevem o estado atual com segurança — foram aplicadas manualmente e há pelo menos uma supersedida (`migration-slack-contatos.sql`). Fazer dump do schema real e dos dados, e conciliar contra `Backup_v1_2026-07-01/.../schema.sql` + as migrations.
2. **Levantar volumetria e formato real** de cada tabela, com atenção especial a `analises.parecer_completo` — é um `jsonb` que carrega o parecer inteiro (produto, 3 camadas, apontamentos, cronologia, medições, cruzamento, `slots_text` e `arquivos_originais`). Medir tamanho médio e máximo; é o campo que define a estratégia de armazenamento em MySQL.
3. **Mapear tabela por tabela, coluna por coluna**, com decisão explícita de tipo:

   | Origem (Postgres) | Destino (MySQL 8) | Observação |
   |---|---|---|
   | `uuid` + `uuid_generate_v4()` | `CHAR(36)` ou `BINARY(16)` | Manter os UUIDs existentes é obrigatório: `analise_origem_id` forma a cadeia de correções e `ficha_id`/`produto_id` amarram tudo |
   | `jsonb` (`parecer_completo`, `permissoes`, `estagios_com_inspecao`, `regras_negocio`, `produtos_associados`, `snapshot`, `metadata`) | `JSON` | MySQL 8 tem tipo `JSON`, mas sem índices GIN. Verificar se alguma consulta filtra por conteúdo do JSON e, se sim, extrair coluna gerada |
   | `text[]` (`estagios_aplicaveis`, `apelidos`) | `JSON` | MySQL não tem array nativo |
   | `enum` (`analise_status`, `severidade_apontamento`, `marcacao_form`, `tipo_controle`, `tipo_documento`) | `ENUM` ou tabela de domínio | **Atenção:** o código usa também o status `conforme_corrigido` (24 ocorrências, ex.: `plataforma.html:6119`, `6433`, `10466`), que **não consta** no enum original de `schema.sql`. Confirmar no banco real o conjunto completo de valores |
   | `timestamptz` | `DATETIME(3)` + UTC explícito | Definir a política de fuso; hoje o código formata para `pt-BR` no cliente |
   | RLS | — | Não existe equivalente. **Toda** a autorização passa a ser responsabilidade da API (Fase 3) |

4. **Mapear os arquivos do Storage**: inventariar `pacotes-analise` (`<analise_id>/originais/*` e `<analise_id>/*.zip`) e `form-templates/current.xlsx`, definir a árvore de destino no servidor e a convenção de caminho que a API vai servir.
5. **Identificar e marcar o que não migra**: `documentos_analise`, `roteiro_form_gq_0047`, `inspecoes_criterios`, `componentes_bom` (não usadas), `operacoes_livres` (sem uso na interface — confirmar com a GQ antes de descartar) e `convites` (perde sentido quando a autenticação sai para o SCM).
6. **Entregável:** documento de mapeamento coluna-a-coluna aprovado, DDL MySQL inicial e inventário de arquivos.

**Riscos.** O maior é modelar em cima das migrations em vez do banco real e descobrir divergência só na carga. O segundo é subestimar `parecer_completo`: se o JSON for grande, a tabela `analises` fica pesada e as telas de Histórico e Dashboard — que hoje leem o parecer inteiro de todas as análises (`plataforma.html:1014-1016`, `11538`) — precisam de projeção seletiva desde o início. Mitigação: dump real como fonte da verdade e medição de volumetria antes de qualquer DDL.

### Fase 2 — Setup do projeto na stack oficial

**Objetivo:** o esqueleto pronto e validado, sem lógica de negócio ainda.

1. Projeto Vite + React 18 + TypeScript com `@vitejs/plugin-react-swc`; `tsconfig` com `strict` ligado e alias `@/` → `src/`.
2. Tailwind CSS com build local. **Portar o design system que já existe**: os tokens de `plataforma.html:57-210` (paleta oficial do Manual da Marca, tema claro/escuro, cores de status) vão para `src/index.css` e `tailwind.config.ts`; as fontes Montserrat/Raleway passam a ser locais. **Portar também a folha de impressão** (`133-209`) — ela é o mecanismo de exportação de PDF do parecer e do dashboard.
3. shadcn/ui + Radix, mapeando os componentes atuais um a um: `Button` → `button`, `Card`/`CardHeader`/… → `card`, `Input` → `input`, `Textarea` → `textarea`, `Label` → `label`, `Modal` → `dialog`, `ToastProvider` → Sonner. Os 24 SVGs de `Icon` → equivalentes lucide-react.
4. React Router v6 com as 7 rotas atuais, preservando os fragmentos de hash existentes (`#dashboard`, `#analise`, `#historico`, `#cadastro`) como redirects, porque a GQ tem links salvos. Reimplementar os atalhos `g+d/a/h/c`, `/` e `?` (`15268-15306`).
5. TanStack Query v5 e a estrutura de pastas prescrita:

```
src/
├── components/          # ui/ (shadcn) + compartilhados: StatusBadge, PageHeader, DropZone, CamadaCard…
├── config/api.ts        # URL base da API — exigência explícita do padrão
├── contexts/            # AuthContext (SCM), PermissoesContext, SolicitacoesContext
├── hooks/               # useAnalises, useFichas, useRealtimeSubstituto…
├── lib/
│   ├── conciliacao/     # ⟵ O MOTOR. Isolado, puro, sem I/O, 100% testável
│   │   ├── motor.ts             # analisarConciliacao
│   │   ├── parsers/             # op.ts, rc.ts, form0047.ts, etiqueta.ts, etiquetaAcessorio.ts
│   │   ├── produto.ts           # detectarProdutoNoTexto
│   │   ├── regulatorio.ts       # gerarSugestoesRegulatorias (M-01…M-05)
│   │   ├── estagios.ts          # ESTAGIOS_VARIAVEIS / FIXOS / CONDICIONAIS / OPERADOR
│   │   ├── reincidencia.ts      # chaveReincidencia, classificarNivelReinc
│   │   └── tipos.ts             # Parecer, Apontamento, ItemCamada, OPParsed, Ficha…
│   ├── extracao/        # PDF.js, Mammoth, ExcelJS, CSV
│   └── documentos/      # FORM XLSX (ExcelJS), anotação PDF (pdf-lib), pacote ZIP (JSZip)
├── pages/
│   ├── dashboard/  analise/  historico/  cadastro/
│   ├── configuracoes/  logs/  solicitacoes/
└── services/api/        # analises/ fichas/ produtos/ operadores/ config/ logs/ solicitacoes/
```

6. Definir a sigla do sistema para o prefixo `/SIGLA/api/v1/` (ex.: `CONC`) e criar `src/config/api.ts` com a URL base.
7. **Entregável:** projeto que builda, roteia entre 7 páginas vazias, com design system idêntico ao atual e tipos do domínio já declarados.

**Riscos.** Baixos, e é a fase que mais reduz risco depois: `strict: true` desde o primeiro dia e os tipos do parecer declarados **antes** de portar o motor evitam a maior fonte de regressão silenciosa. Cuidado com deriva visual — a GQ trabalha nesta tela todo dia; comparar lado a lado.

### Fase 3 — Autenticação no modelo SCM e API REST

**Objetivo:** fechar os dois desvios críticos de governança.

1. **Remover** `LoginPage` (`734`), `CompletarCadastro` (`15168`), a criação do cliente Supabase (`314`) e o endpoint `/convidar-usuario` (`server.js:193`) com a `service_role` key.
2. **Implementar o `AuthContext` do SCM**: ler `auth_token`, `auth_refresh_token`, `auth_user` e `auth_permissoes` do `localStorage`; enviar `Authorization: Bearer <auth_token>` em toda chamada; redirecionar ao SCM quando ausente ou inválido; tratar 401 com refresh e, na falha, redirect.
3. **Traduzir o modelo de permissões.** Decisão de negócio obrigatória: mapear as 19 chaves atuais (`plataforma.html:329-356`) para os 3 níveis do padrão. Proposta inicial a ser validada pela GQ:

   | Nível | Perfil equivalente hoje | Chaves sugeridas |
   |---|---|---|
   | **1 — Usuário** | Estagiário / Assistente GQ | `dashboard_ver`, `analise_executar`, `historico_ver`, `historico_baixar` |
   | **2 — Administrador** | Analista GQ | + `analise_refazer`, `analise_remover_etiqueta`, `historico_justificar`, `historico_correcao`, `historico_importar`, `cadastro_ver`, `cadastro_produtos`, `cadastro_fichas`, `logs_ver` |
   | **3 — Gestor** | Responsável pela Qualidade / RT | + `historico_excluir`, `cadastro_excluir_ficha`, `config_ver`, `config_editar`, `config_usuarios` |

   Decidir também o destino do fluxo de **Solicitações** (10 ações, §2.10), que não tem equivalente no padrão: mantê-lo como funcionalidade de aplicação (recomendado — está em uso e gera trilha de auditoria) ou descontinuá-lo. Se mantido, a tabela `solicitacoes` migra e a checagem passa a ser server-side.
4. **Construir a API REST** em `/SIGLA/api/v1/`, com um módulo por recurso e autorização por nível em **todo** endpoint — é aqui que se paga a dívida da RLS permissiva:

   ```
   /CONC/api/v1/analises            GET LIST · GET :id · POST · PATCH :id · DELETE :id
   /CONC/api/v1/analises/:id/apontamentos/:idx/justificar   POST
   /CONC/api/v1/analises/:id/pacote                        GET · POST (gerar)
   /CONC/api/v1/fichas              CRUD + GET :id/revisoes · POST :id/revisoes
   /CONC/api/v1/produtos            CRUD
   /CONC/api/v1/operadores          CRUD
   /CONC/api/v1/config              GET · PUT
   /CONC/api/v1/logs                GET LIST · POST
   /CONC/api/v1/solicitacoes        GET LIST · POST · PATCH :id (aprovar/recusar)
   /CONC/api/v1/melhorias           GET LIST · PATCH :id (decidir)
   /CONC/api/v1/worklist            GET · POST (importar) · DELETE :op
   /CONC/api/v1/arquivos            POST (upload) · GET :path (download)
   ```

5. **Substituir o Realtime.** Hoje `useRealtime` (`393`) mantém 4 telas sincronizadas via `postgres_changes`. Sem Supabase, escolher: polling do TanStack Query com `refetchInterval` (mais simples, suficiente para o volume da GQ) ou SSE/WebSocket na API (mais fiel). Recomendação: polling na primeira versão, com intervalo por tela.
6. **Entregável:** aplicação autenticada pelo SCM, falando com a API REST em MySQL, com autorização validada no servidor.

**Riscos.** **Alto.** É a fase com maior potencial de travar a operação: se o mapeamento de permissões estiver errado, ou a GQ perde acesso a algo que usava, ou alguém ganha acesso que não deveria ter. Mitigação: mapa aprovado formalmente pela GQ antes de codificar, e um relatório comparando, usuário por usuário, o que cada um podia fazer antes e depois. Risco secundário: o `parecer_completo` inteiro trafegando em endpoints de lista — definir projeções desde o início (a lista do Histórico não precisa do parecer completo).

### Fase 4 — Reescrita módulo a módulo

**Objetivo:** portar a aplicação, começando pelo que não pode quebrar.

**Ordem, por criticidade e uso:**

**4.1 — O motor de conciliação (primeiro, sempre).** Portar para `src/lib/conciliacao/` como código puro, sem I/O e sem React: os 5 parsers, `detectarProdutoNoTexto`, `analisarConciliacao`, `gerarSugestoesRegulatorias`, as constantes de estágio e as funções de reincidência.

Regras não negociáveis desta sub-fase:

- **Tradução literal, não "melhorada".** Cada regex, cada limiar, cada `if` encadeado, cada ordem de avaliação. Os regex do `parseOP` estão ordenados do mais específico ao mais genérico deliberadamente (`plataforma.html:2458-2472`); as 4 estratégias em cascata da data da conciliação existem porque cada uma cobriu um layout real de PDF (`2671-2731`); a normalização de lote/série resolve EAN-13 × barcode de 15 dígitos mas preserva divergência real em séries com barra (`4897-4946`). Nada disso é acidente.
- **Preservar os comentários datados.** Eles são o registro de por que a regra existe e qual falso positivo ela corrigiu. Perder o comentário é perder a justificativa de negócio — e, num sistema sob ISO 13485, a justificativa é parte do registro.
- **Suíte de regressão antes do corte.** Selecionar um conjunto de OPs históricas cobrindo os casos conhecidos — conforme limpo; NC de etiqueta; NC de acessório; acessório estéril vencido; grupo alternativo ausente; grupo alternativo com múltiplas variantes; derivação órfã; cronologia incoerente; inspeção duplicada fora de ordem; inspeção faltando vs. declarada na Ficha; inspetor fora da aptidão; inspetor não cadastrado; medição fora da faixa; RC de outro lote; ficha não apta; análise duplicada; reanálise por correção; reanálise por ficha; reanálise por cadastro. Para cada uma, rodar os dois motores sobre **os mesmos textos extraídos** (`slots_text` já está persistido em `parecer_completo` — é exatamente a fixture necessária) e comparar campo a campo: `resultado_geral`, número e conteúdo dos apontamentos, e cada item das 3 camadas com seu status.
- **Critério de aceite: divergência zero.** Qualquer diferença é investigada e explicada antes de seguir. Não há "diferença aceitável" aqui.

**4.2 — Análise (o fluxo mais usado).** Extração no navegador (PDF.js/Mammoth/ExcelJS/CSV), fila de OPs pendentes, upload por pasta com classificação automática (incluindo as regras de exceção e a pontuação de etiqueta externa), slots de upload, pré-preenchimento (FORM XLSX via ExcelJS e OP anotada via pdf-lib) e os 4 bloqueios de análise. Aqui é obrigatório testar com PDFs reais do Sapiens — a extração com coordenadas é sensível ao layout, e é o ponto onde uma diferença de versão de biblioteca aparece.

**4.3 — Parecer, pacote e Slack.** `ParecerView` e seus subcomponentes, justificativa de ressalva com recálculo de status, reanálise nos 3 modos (correção, ficha, cadastro), reprocessamento em lote de análises irmãs, exportação em PDF via impressão, geração do pacote ZIP (todos os 7 passos, incluindo a re-conversão que remove as restrições do Sapiens) e o alerta de NC no Slack com roteamento por setor, reincidência, cards editáveis e menção por estágio.

**4.4 — Histórico.** Lista com filtros e ordenação, download de pacote individual e em lote, importação de análises manuais, análise manual individual, marcação de NC manual como corrigida, exportação para auditoria (super-ZIP de até 50) e backup XLSX.

**4.5 — Cadastro.** Catálogo, Fichas Mestres (editor completo, grupos alternativos, estágios aplicáveis e com inspeção, regras, `apta_analise`), revisões com changelog automático e backfill retroativo, clonagem de derivação, importação a partir de documentos e template do FORM. Migrar os formulários para React Hook Form + Zod — o schema Zod da Ficha passa a ser a fonte única de validação, substituindo as checagens imperativas de `13143-13162`.

**4.6 — Dashboard.** Os 5 gráficos em Recharts (donut de conciliações, correções por documento, erros que motivaram correção com filtro por documento, problemas na OP alternando estágio/inspeção, erros por equipamento), a tabela de correções, o painel de tendência e reincidência e a aba de melhorias regulatórias. Preservar exatamente as regras de contagem: um lote conta uma vez pelo estado mais recente; ajuste de ficha/cadastro não é correção; o gráfico de erros usa os apontamentos da análise **original**; só severidade `nao_conforme` entra; apontamentos de aptidão ficam fora; a reincidência só exibe nível em janelas de até 31 dias. **Todo cálculo de indicador precisa de teste com dados históricos reais** — um indicador que muda de valor após a migração desmoraliza o sistema perante a GQ.

**4.7 — Configurações, Logs e Solicitações.** Pasta de destino, subpasta por mês, teste de serviço, limiares de reincidência, cadastro de operadores (com `slack_user_id`), gestão de usuários (agora só leitura de perfil vindo do SCM), trilha de auditoria com exportação paginada e fluxo de aprovações. Decidir aqui o destino de `GestaoOperacoesLivres` — hoje código morto.

**Entregável:** aplicação completa na stack oficial, com regressão do motor fechada e indicadores conferidos.

**Riscos.** **O mais alto de toda a migração.** Três frentes:

1. **Perda silenciosa de regra de negócio.** Uma condição sutil omitida — um `continue` que evita falso positivo, uma exclusão de aptidão nas contagens, a ordem dos regex do `parseOP` — produz um parecer plausível e errado. Um lote liberado com NC não detectada é dano regulatório. Mitigação: tradução literal, revisão linha a linha por segunda pessoa e a suíte de regressão com divergência zero.
2. **Divergência nos indicadores.** As regras de contagem do Dashboard são cheias de exceções acumuladas por decisão de negócio. Mitigação: testes com o histórico real, comparando cada KPI e cada série antes/depois.
3. **Regressão na extração de texto.** Trocar a versão do PDF.js, do Mammoth ou do ExcelJS pode alterar a ordem ou o espaçamento do texto extraído e quebrar regex calibrados. Mitigação: fixar as mesmas versões que estão em produção hoje (PDF.js 3.11.174, Mammoth 1.7.0, ExcelJS 4.4.0, pdf-lib 1.17.1, JSZip 3.10.1, xlsx 0.18.5) e só atualizar depois, uma por vez, com a regressão rodando.

### Fase 5 — Migração dos dados históricos

**Objetivo:** o histórico completo no MySQL local, íntegro e conferido.

1. **Ordem de carga**, respeitando as chaves estrangeiras: `produtos` → `fichas_mestres` → `acessorios_aplicaveis` → `fichas_mestres_versoes` → `perfis`/usuários → `analises` (ordenadas por `created_at`, para que `analise_origem_id` sempre referencie linha já inserida) → `apontamentos` → `logs_atividade` → `solicitacoes` → `operadores` → `config_app` → `melhorias_regulatorias` → `worklist_ops`.
2. **Preservar os UUIDs.** Não regerar identificadores: `analise_origem_id` é o que forma a cadeia de correções que alimenta todo o Dashboard, e os caminhos do Storage usam o `analise_id` como prefixo de pasta.
3. **Migrar os arquivos** de `pacotes-analise` e `form-templates` para a árvore no servidor, mantendo a relação com `analise_id` e atualizando os caminhos gravados em `parecer_completo.arquivos_originais`.
4. **Validar `parecer_completo`.** É o campo mais crítico da carga: para cada análise migrada, conferir que o JSON está parseável e que `resultado_geral`, contagem de apontamentos e itens por camada batem com a origem.
5. **Reconciliação obrigatória** antes do corte:
   - contagem de linhas por tabela, origem × destino;
   - soma de análises por status e por mês, origem × destino;
   - **cada KPI e cada série do Dashboard**, calculados nos dois sistemas para os mesmos filtros — total de análises, conformes, corrigidas, donut, correções por documento, erros que motivaram, erros por equipamento, tendência e a tabela de reincidência;
   - integridade das cadeias de reanálise: toda `analise_origem_id` aponta para uma análise existente;
   - contagem e checksum dos arquivos migrados.
6. **Janela de corte.** Congelar novas análises no sistema antigo, rodar a carga delta, reconciliar, liberar o novo. Manter o Supabase em modo leitura por um período de retenção definido pela GQ (sugestão: 90 dias), como plano de reversão. Antes disso, gerar os backups XLSX que o próprio sistema já oferece (`handleBackupHistorico`, `11839`; exportação de logs, `14980`) como cópia independente do processo de migração.
7. **Entregável:** MySQL local com o histórico íntegro e relatório de reconciliação assinado.

**Riscos.** **Alto.** A conversão `jsonb` → `JSON` pode alterar ordem de chaves ou normalizar valores; se algum cálculo do Dashboard depender de ordem (não deveria, mas precisa ser verificado), o indicador muda. UUIDs regerados quebram irreversivelmente as cadeias de correção. Diferença de fuso horário em `timestamptz` → `DATETIME` desloca análises entre meses e altera todos os recortes temporais — testar explicitamente análises criadas perto da meia-noite e perto da virada de mês. Mitigação: carga em ambiente de homologação primeiro, reconciliação completa antes de qualquer corte, e o Supabase preservado como fallback.

### Fase 6 — Substituição do serviço Node por endpoints REST

**Objetivo:** as capacidades do serviço local viram API padronizada e autenticada, sem perda de funcionalidade.

| Serviço hoje | Endpoint REST | Observações |
|---|---|---|
| `POST /converter-pdf` | `POST /CONC/api/v1/documentos/converter` | Manter LibreOffice (Office), Ghostscript (PDF → PDF sem restrições, assinável no Adobe) e Chromium/Puppeteer (HTML → PDF). **Os parâmetros do Ghostscript são exigência funcional**, não detalhe: `-dPDFSETTINGS=/prepress`, `-dCompatibilityLevel=1.6`, `-dPreserveAnnots=true` |
| `POST /salvar-pacote` | `POST /CONC/api/v1/analises/:id/pacote` | Manter a extração manual entrada por entrada — o `chmod` do `extractAllTo` falha em UNC com ENOENT (`server.js:161-172`). Manter a proteção contra path traversal e **restringir o destino a uma allowlist de pastas** em vez de aceitar caminho arbitrário |
| `POST /convidar-usuario` | **remover** | Gestão de usuários passa a ser do SCM |
| `POST /notificar-slack` | `POST /CONC/api/v1/notificacoes/slack` | Webhooks continuam em variável de ambiente do servidor, um por canal (`pcp_gq`, `almoxarifado_gq`) + fallback geral. Manter a decisão de canal e a montagem da menção `<@ID>` no cliente, como hoje |
| `POST /pcp-status` | `GET /CONC/api/v1/pcp/status` | Só implementar se a GQ confirmar que a dupla checagem é requisito — hoje o endpoint existe mas **nunca é chamado** |
| `GET /health` | `GET /CONC/api/v1/health` | Mantém o botão "Testar serviço" das Configurações |
| `GET /` (serve o HTML) | **remover** | O novo frontend é servido como build estático pelo servidor da empresa. Existia só porque o Supabase Auth não aceitava redirect de convite para `file://` — motivo que desaparece com o SCM |
| Fallback CloudConvert (Edge Function) | **remover** | O serviço local cobre todos os formatos. Elimina o envio de documento de lote a terceiro |

Todo endpoint passa a exigir `Authorization: Bearer` e a validar o nível de permissão.

**Entregável:** nenhuma dependência de nuvem no caminho crítico; todo o backend em `/CONC/api/v1/` sobre MySQL local.

**Riscos.** **Médios, mas com um ponto de atenção sério.** A conversão de PDF é o passo do qual depende a **assinatura digital do RT** — se o PDF gerado pelo novo endpoint mantiver as restrições do Sapiens, o RT não consegue assinar e a operação para. É obrigatório validar com PDFs reais do Sapiens, abrindo o resultado no Adobe Acrobat e efetivamente assinando, antes do corte. A gravação em pasta de rede é o segundo ponto: depende da conta que roda o serviço enxergar o caminho UNC — testar com a conta de produção, não com a do desenvolvedor. E confirmar que LibreOffice, Ghostscript e Chromium estão instalados e na versão certa no servidor de destino.

### 7.1 Sequenciamento e paralelização

```
Fase 1  Levantamento e mapeamento          ██████                          2 sem.
Fase 2  Setup do projeto                       ████                        1–2 sem.
Fase 3  Auth SCM + API REST                        ██████████             4–6 sem.
Fase 4.1 MOTOR + regressão  ──────────────────►    ██████████             3–4 sem. (paralelo à 3)
Fase 4.2-4.7 Módulos                                     ██████████████   6–8 sem.
Fase 5  Dados históricos                                        ██████     1–2 sem.
Fase 6  Endpoints REST                                     ██████         1–2 sem. (paralelo à 4)
        Homologação com a GQ + operação paralela                  ████████ 2–4 sem.
```

A Fase 4.1 (motor + regressão) pode e deve começar em paralelo à Fase 3: é código puro, não depende de API nem de autenticação, e é o item com maior risco — quanto mais cedo começar, mais tempo há para investigar divergências.

### 7.2 Critérios de corte (nenhum é opcional)

1. Suíte de regressão do motor com **divergência zero** no conjunto de OPs históricas selecionado.
2. Todos os KPIs e séries do Dashboard idênticos entre os dois sistemas, para os mesmos filtros.
3. Relatório de reconciliação de dados aprovado (contagens, integridade das cadeias de reanálise, arquivos).
4. Pacote de lote gerado pelo novo sistema **assinado com sucesso** no Adobe Acrobat pelo RT.
5. Gravação na pasta de rede funcionando com a conta de produção.
6. Mapa de permissões aprovado pela GQ e conferido usuário por usuário.
7. Alerta de NC chegando nos canais `pcp_gq` e `almoxarifado_gq`, com menção correta.
8. Supabase preservado em modo leitura pelo período de retenção definido, como plano de reversão.

---

## Apêndice A — Arquivos do repositório

| Arquivo | Papel |
|---|---|
| `plataforma.html` | **A aplicação inteira.** 979 KB, 15.393 linhas. Contém também o logo Confiance (linha 801) e o template do FORM-GQ-0047 (linha 3322) embutidos em base64 |
| `conversor-pdf-local/server.js` | Serviço Node/Express local, 352 linhas, 7 endpoints |
| `conversor-pdf-local/package.json` | Dependências do serviço |
| `conversor-pdf-local/README.md`, `MIGRAR_SERVICO_PARA_SERVIDOR.md` | Instalação e migração do serviço para o servidor |
| `edge-function/converter-para-pdf.ts` | Edge Function CloudConvert — **fallback ativo** |
| `edge-function/analisar-conciliacao.ts` | Edge Function Gemini — **não utilizada** pelo código atual |
| `migration-*.sql` (16 arquivos) + `migration_estagios_com_inspecao.sql` | Alterações de schema aplicadas manualmente. `migration-slack-contatos.sql` está marcada como **supersedida** |
| `Backup_v1_2026-07-01/` | Backup de 01/07/2026: versão anterior do `plataforma.html`, dump de dados, `schema.sql` base e uma **tentativa anterior de projeto Vite + React + TS** (`Plataforma-Conciliacao/`) com estrutura `src/` parcial — vale consultar na Fase 2 |
| `AUDITORIA_PADRAO_CONFIANCE.md` | Auditoria de 01/07/2026. **Parcialmente desatualizada**: afirma "Chart.js via CDN" (os gráficos são SVG/divs próprios) e "sem sistema de permissões implementado" (o sistema de cargos e permissões existe e está em uso) |
| `PLANO_MIGRACAO_P&D_SOFTWARE.md` / `.docx`, `PLANO_MIGRACAO_SCM.md` | Planos de migração anteriores |
| `COMO_FUNCIONA_TENDENCIA_E_REINCIDENCIA.md` | Documentação da metodologia de reincidência |
| `COMO_CONFIGURAR_ALERTA_SLACK.md` | Configuração dos webhooks |
| `CLASSIFICACAO_VERIFICACOES_NC_RESSALVA.md` | Critérios de classificação NC × ressalva |
| `FORM-GQ-0047_Rev9_mapa_celulas.md` | Mapa de células do FORM |
| `PROTOCOLO_AGENTE_CONCILIACAO.md`, `GUIA_*.md`, `ESPEC_PD_*.md` | Protocolo, guias e especificações |
| PDFs e XLSX de exemplo (`OP_6819_*`, `RC_6819.pdf`, `Ficha_Mestre_CM-LED.pdf`, etiquetas `.docx`, `Template_Fichas_Mestres.xlsx`) | Documentos reais usados na calibração dos parsers — **fixtures naturais para a suíte de regressão da Fase 4.1** |

## Apêndice B — Mapa rápido do código

| Função / componente | Linha | Papel |
|---|---|---|
| Configuração (Supabase, serviço local) | 290–308 | Credenciais e endpoints |
| Cargos, permissões, `PermContext` | 319–435 | Modelo de acesso |
| `registrarLog` · `useRealtime` | 375 · 393 | Auditoria e tempo real |
| `ACOES_SOLIC` · `SolicitacaoProvider` | 414 · 456 | Fluxo de aprovações |
| Componentes de UI (Button…Modal, Toast) | 559–729 | Design system |
| `LoginPage` · `Sidebar` | 734 · 802 | Autenticação e navegação |
| `DashboardPage` | 963 | Dashboard completo |
| `DonutChart` · `BarChart` · export PNG | 2170 · 2208 · 2228/2265 | Gráficos |
| `extractTextFromFile` | 2347 | Extração PDF/DOCX/XLSX/CSV |
| `parseOP` · `parseEtiqueta` · `parseEtiquetaAcessorio` · `parseForm0047` · `parseRC` | 2453 · 2768 · 2830 · 2873 · 2956 | Parsers |
| `loadProdutosComFichas` · `detectarProdutoNoTexto` | 3007 · 3095 | Catálogo e identificação |
| `buildLinesWithMap` · `fillFormXlsxTemplate` | 3216 · 3447 | Coordenadas em PDF e geração do FORM |
| `computeOPAnnotations` · `computeFormAnnotations` | 3763 · 3996 | Anotação em PDF |
| `gerarSugestoesRegulatorias` | 4403 | Melhorias M-01…M-05 |
| **`analisarConciliacao`** | **4530** | **Motor: Camada 2 (4601), Camada 1 (5126), Camada 3 (5750)** |
| `executarAnaliseLocal` | 6031 | Orquestrador e bloqueios |
| `BuscarOPsPendentes` · `AnalisePage` | 6344 · 6521 | Fila e tela de análise |
| `classificarArquivo` · `processarPasta` | 6738 · 6767 | Importação por pasta |
| `classificarNivelReinc` · `chaveReincidencia` | 7712 · 7709 | Reincidência |
| `ParecerView` | 7748 | Parecer, pacote, Slack |
| `handleDownloadZip` · `abrirAlertaSlack` | 8656 · 8937 | Pacote e alerta |
| `HistoricoPage` | 11498 | Histórico |
| `CadastroPage` · `FichaMestreEditor` | 12224 · 12795 | Cadastro e Ficha Mestre |
| `ESTAGIOS_VARIAVEIS/FIXOS/CONDICIONAIS` | 12734–12760 | Os 16 itens do FORM |
| `ConfiguracoesPage` · `GestaoOperadores` · `GestaoUsuarios` | 14210 · 14373 · 14769 | Configurações |
| `LogsPage` · `SolicitacoesPage` · `App` | 14949 · 15065 · 15211 | Logs, solicitações, raiz |

---

*Documento gerado a partir da leitura direta do código-fonte em 11/08/2026. Cada afirmação sobre comportamento do sistema referencia arquivo e linha. Funcionalidades presentes no código mas não ligadas à interface estão explicitamente marcadas como tal.*
