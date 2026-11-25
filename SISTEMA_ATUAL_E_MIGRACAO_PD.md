# Plataforma de Conciliação da Produção — Como funciona hoje e o que o P&D precisa para a migração

**Empresa:** Confiance Medical · **Área dona:** Garantia da Qualidade (GQ) · **Responsável:** Maria Luiza Zaccur
**Para:** P&D Software · **Data:** 19/11/2026
**Repositório:** `github.com/QualidadeCM/Conciliacao` (pasta `C:\conciliacao`)

Este documento substitui `DOCUMENTACAO_COMPLETA_SISTEMA.md`, `PLANO_MIGRACAO_P&D_SOFTWARE`, `PLANO_MIGRACAO_SCM.md`, `AUDITORIA_PADRAO_CONFIANCE.md`, `ESPEC_PD_PACOTE_SERVIDOR_E_PDF_LOCAL.md` e `COMO_FUNCIONA_TENDENCIA_E_REINCIDENCIA.md`. Eles foram removidos do repositório e continuam no histórico do git.

O documento tem duas partes:

- **Parte 1 (seções 1 a 7):** o que o sistema faz hoje, tela por tela, com regras, dados e integrações.
- **Parte 2 (seções 8 a 11):** o que o P&D precisa para reescrever o sistema no padrão da empresa e migrar os dados.

As melhorias e correções em discussão com a GQ estão em `MELHORIAS_E_CORRECOES.md`. Os itens marcados ali como **"Migração"** são requisitos deste documento. Este documento será atualizado depois que as melhorias decididas forem aplicadas.

---

# PARTE 1 — O SISTEMA HOJE

## 1. Visão geral

### 1.1 O que o sistema faz

A plataforma automatiza a **conciliação documental de cada lote produzido** (Estágio 60 do roteiro Sapiens), antes de o Responsável Técnico liberar o lote para comercialização.

Para cada lote, a GQ envia os documentos de produção. O sistema extrai o texto **no próprio navegador**, cruza os documentos entre si e contra a **Ficha Mestre** do produto, e devolve:

- **parecer técnico** com resultado: `conforme`, `ressalva` (conforme com ressalvas) ou `nao_conforme`;
- **checklist por camada**: o que foi verificado e os valores lidos em cada documento;
- **apontamentos numerados** (`NC-01`, `R-01`, …) com documento afetado, setor responsável, referência normativa, descrição e recomendação;
- **FORM-GQ-0047 preenchido** (Excel gerado a partir do template oficial, Rev. 9);
- **OP anotada em PDF** (✓ nas inspeções e data da conciliação);
- **pacote do lote**: documentos em PDF assinável e resumo da análise, gravados na pasta da rede, onde o RT assina.

Além disso, o sistema:

- mantém o **histórico** de lotes e a cadeia de correções (reanálises);
- envia **alertas de NC ao Slack** (PCP e Almoxarifado) e acompanha o **prazo de retorno** das correções;
- cruza os lotes com as **NFs de venda** (rastreabilidade da série e lotes que saíram com análise em aberto);
- gera **indicadores** (Dashboard) e **relatórios mensais automáticos** por setor.

### 1.2 Usuários

Equipe da GQ, gestores do PCP e do Almoxarifado, Responsável Técnico e Responsável pela Produção. Hoje há 5 cargos e 19 permissões próprias (ver 2.10). Na migração, isso passa para os 3 níveis do SCM (ver 10.3).

### 1.3 Documentos de um lote

| Documento | Origem | Formato | Obrigatório |
|---|---|---|---|
| OP (Ordem de Produção) | Sapiens | PDF (ou XLSX) | Sim |
| RC (Relação de Componentes) | Sapiens | PDF, XLSX ou CSV | Sim |
| Etiqueta externa | Almoxarifado | DOCX | Sim |
| Etiquetas de acessório (uma por acessório) | Almoxarifado | DOCX | Conforme a Ficha |
| FORM-GQ-0047 | GQ | Gerado pela plataforma (ou XLSX/PDF anexado) | Gerado |
| OP de reprocesso / RNC | Produção / GQ | PDF | Só quando houve retrabalho ou não conformidade |

### 1.4 Conceitos usados em todo o sistema

- **Lote:** OP + número de série.
- **Análise:** uma execução do motor sobre os documentos de um lote. Uma reanálise cria uma nova análise ligada à anterior (`analise_origem_id`), formando a **cadeia** do lote.
- **Análise vigente:** a última da cadeia, ou seja, a que não foi substituída por reanálise. É ela que define a situação atual do lote.
- **Mês do lote:** mês da **1ª análise** da cadeia. É usado nos indicadores e relatórios.
- **Status:**
  - `conforme`;
  - `ressalva` (conforme com ressalvas);
  - `nao_conforme`;
  - `conforme_corrigido`: usado em análises manuais. Nas análises da plataforma, a correção é identificada pela cadeia.
- **Categoria do lote nos indicadores:**
  - **conforme:** aprovado na 1ª análise;
  - **com ressalva:** aprovado na 1ª, com ressalvas;
  - **corrigida:** precisou de correção e foi corrigida;
  - **NC aberta:** ainda não conforme.
- **Aprovação de primeira:** (conforme + com ressalva na 1ª análise) ÷ lotes do mês. A meta é configurável (padrão 90%).
- **Setor responsável pelo apontamento:**
  - **Almoxarifado:** etiquetas (externa e de acessório), **tudo o que é RC** (RC ausente ou de outra OP, OP não identificada na RC, componente "Não Conforme", baixa de acessório, grupo alternativo, lote ou código do acessório RC × etiqueta) e tempo dos Estágios 5 e 50;
  - **PCP:** OP, FORM e os demais casos.
- **Quem é mencionado / cobrado (desde 25/11/2026, igual no envio individual, no envio em lote, na exportação "OPs em aberto" e em "NCs por operador"):** Almoxarifado → quem executou o **Estágio 50**; PCP → quem executou o **Estágio 60**; tempo do Estágio 5 → quem executou o Estágio 5.
- **Não vão ao Slack** (a própria GQ resolve): aptidão ou cadastro de inspetor, ressalvas do FORM (revisão, data OP × FORM, cópia controlada) e ajustes de cadastro/Ficha (inspeção em estágio não previsto, derivação sem Ficha, produto não identificado, data da conciliação não identificada).
- **Responsável pela correção em casos específicos:**
  - **cronologia incoerente:** a causa é do inspetor; quem corrige é o executor do Estágio 60;
  - **código de barras de apontamento:** a causa é do executor do estágio; quem corrige é o PCP (Estágio 60).

---

## 2. Telas e funcionalidades

O menu lateral mostra só as telas que o usuário tem permissão de ver:

- Dashboard
- Análise
- Histórico
- NFs de venda
- Cadastro
- Solicitações
- Histórico de alterações
- Configurações

Há também atalhos de teclado: `g`+`d`/`a`/`h`/`c`, `/` para buscar e `?` para ajuda, além de tema claro/escuro.

### 2.1 Login e primeiro acesso — *deixa de existir na migração*

- **Login:** e-mail e senha pelo Supabase Auth.
- **Convite:** Configurações → Usuários. O serviço local chama o Supabase com a chave de serviço e o convidado define nome e senha no primeiro acesso.

Na migração, **tudo isso sai** e a autenticação passa a ser do SCM.

### 2.2 Análise

**a) Fila de OPs pendentes**
- A GQ importa a planilha do Sapiens "movimentos de O.P. com Inspeção pendente". O sistema lê os números de OP e monta uma fila compartilhada (`worklist_ops`).
- A OP sai da fila sozinha quando é analisada depois de ter entrado nela.
- Estar na fila libera a reanálise de uma OP já finalizada (sem isso, o sistema bloqueia a análise como duplicada).
- O botão "Limpar lista" esvazia a fila para todos.

**b) Envio dos documentos**
- A usuária arrasta a **pasta inteira da OP** ou envia arquivo por arquivo.
- O sistema classifica cada arquivo (OP, RC, etiqueta externa, etiqueta de acessório, FORM, reprocesso, RNC) pela extensão, pelo nome e, quando há dúvida, pelo conteúdo.
- Regras de pasta:
  - subpastas "semiacabados" são ignoradas;
  - a Ficha pode ter regras "ignorar pasta X";
  - se houver mais de uma etiqueta externa, vence a que melhor casa com o modelo da OP.
- **Pré-visualização:**
  - a OP pode ser baixada já anotada (✓ e data);
  - o FORM preenchido é gerado em segundo plano assim que a OP é lida.

**c) Extração de texto (no navegador)**

| Formato | Biblioteca |
|---|---|
| PDF | PDF.js, com reconstrução das linhas pelo layout para ler o multi-coluna do Sapiens |
| DOCX | Mammoth |
| XLSX | ExcelJS |
| CSV | Lido como texto |

**d) Bloqueios antes de analisar**

| Código | Quando |
|---|---|
| `PRODUTO_NAO_CADASTRADO` | Nenhum produto do catálogo casa com os documentos |
| `FICHA_MESTRE_AUSENTE` | O produto existe, mas não há Ficha para a derivação |
| `FICHA_MESTRE_NAO_APTA` | A Ficha existe, mas não foi marcada como "revisada e apta" |
| `ANALISE_DUPLICADA` | O lote já tem análise finalizada e a OP não está na fila do Sapiens |

**e) Execução**
1. O motor roda (seção 3).
2. A análise é gravada (`analises` e `apontamentos`).
3. O FORM é gerado.
4. Os originais sobem para o Storage (`pacotes-analise/<id_análise>/originais/`).
5. As sugestões regulatórias novas entram em `melhorias_regulatorias`.

### 2.3 Parecer (tela de resultado)

Abre depois da análise e também a partir do Histórico e do Dashboard. Tem setas ← → para navegar entre os lotes da lista.

**Conteúdo:**
- identificação do lote;
- resumo por severidade;
- cards de apontamento;
- checklist por camada (C1, C2, C3);
- cronologia da OP;
- medições críticas;
- cruzamento FORM × Ficha × roteiro da OP;
- texto do parecer técnico.

**Ações:**

| Ação | O que faz |
|---|---|
| **Justificar ressalva** | Grava texto, autor e data no apontamento. Recalcula o resultado: se todas as ressalvas foram justificadas e não há NC, o lote vira conforme |
| **Refazer com documento corrigido** | Em cada apontamento, anexa o documento corrigido. Os outros documentos vêm do Storage ou do texto salvo. Cria a nova análise da cadeia (`doc_substituido`, `motivo_reanalise`) |
| **Remover etiqueta** | Tira uma etiqueta de acessório anexada por engano e refaz a análise |
| **Atualizar a Ficha a partir do parecer** | Abre o editor da Ficha, salva uma nova revisão e refaz em modo `atualizacao_ficha` (não conta como correção). Depois oferece reprocessar outras análises pendentes da mesma derivação ("irmãs") |
| **Cadastrar inspetor e refazer** | Cadastra o inspetor e refaz em modo `atualizacao_cadastro` (não conta como correção) |
| **Refazer — erro da plataforma** | Quando o apontamento foi erro de análise ou parametrização da plataforma (os documentos estavam certos). Refaz com os mesmos documentos em modo `erro_sistema`, com motivo obrigatório. O lote não conta como não conforme nem como corrigido. Também disponível em lote, na opção "Erro da plataforma" de "Reanalisar documentos corrigidos" |
| **Enviar alerta ao Slack** | Monta, por setor, a mensagem com as NCs (editável antes do envio): calcula a reincidência de cada NC, menciona quem executou o Estágio 50 (Almoxarifado) ou o Estágio 60 (PCP) e separa "solicitação de correção" de "dúvida sobre a Ficha". Registra o envio para o acompanhamento de prazo (2.4 e) |
| **Baixar FORM (Excel)** | Baixa o FORM preenchido |
| **Baixar pacote** | Monta o ZIP: restaura os originais, converte o FORM para PDF, anota a OP e regenera o PDF sem as restrições do Sapiens (para assinar no Adobe), inclui RC, etiquetas, reprocesso, RNC e o Resumo da análise em PDF. **Grava descompactado na pasta da rede** (opcionalmente na subpasta do mês) e também guarda o ZIP no Storage |
| **Parecer em PDF** | Impressão com folha de estilo própria (A4) |

### 2.4 Histórico

**a) Lista**
- Mostra **um lote por linha**, com a análise vigente.
- A data é a da 1ª análise; quando houve reanálise, aparece também "atualizada em".
- Colunas: data, OP, equipamento/produto, série, status, NF de venda e ações.
- Chips na linha:
  - correção (↻ N vezes, ou ✎ ficha atualizada);
  - análise manual (M);
  - pacote não baixado ("pendente");
  - correção enviada ("Aguardando {setor} · X d úteis" ou "Atrasada").

**b) Filtros e ordenação**
- Filtros: busca (OP, série, modelo), período (tudo, ano, mês), equipamento, modelo, origem (plataforma ou manual), status (inclui "em aberto", "aguardando retorno" e "correção atrasada"), documento com problema, sem NF e só pendentes.
- Ordenação por coluna.

**c) Menu Ações**

| Item | O que faz |
|---|---|
| Importar planilha | Importa as análises manuais feitas antes da plataforma (XLSX, com modelo para baixar) |
| Reanalisar documentos corrigidos | Recebe vários documentos corrigidos, soltos ou em pastas, e descobre a que lote cada um pertence (pelo nº da OP na OP/RC e pela série na etiqueta/FORM). Reanalisa cada lote substituindo só o que veio. Para análises sem originais guardados, aceita a pasta completa (OP + RC + etiqueta externa no mínimo) |
| Enviar problema em pacote | Agrupa os lotes em aberto pelo mesmo problema e envia uma única mensagem ao Slack do setor, com aviso de "já cobrado" quando o lote já foi enviado antes |
| Exportar OPs em aberto | Excel com os lotes NC/ressalva e seus apontamentos (uma linha por apontamento) |
| Exportar Histórico | Excel da lista filtrada |
| Exportar p/ auditoria | ZIP com sumário em PDF e uma pasta por análise (até 50) |
| Backup mensal | Excel com todas as análises do banco |

As três exportações em Excel (Exportar Histórico, Exportar OPs em aberto e Backup mensal) trazem a **NF de venda** vinculada ao lote pela série: número/série da nota, data de emissão, cliente e tipo de saída (venda ou outra saída). Se a série aparece em mais de uma nota, todas saem na mesma célula, em ordem de emissão, separadas por "; ".

**d) Outros recursos**
- Nova análise manual e "marcar NC manual como corrigida".
- Baixar pacote pela linha.
- "Baixar pendentes" grava na rede todos os pacotes conformes ainda não baixados.
- Excluir análise (com permissão, ou por solicitação aprovada).

**e) Acompanhamento das correções enviadas (desde 06/11/2026)**
- Cada envio ao Slack para correção grava uma linha em `correcoes_solicitadas` (lote, setor, origem, problema, data).
- **Prazo:** 1 dia útil se o equipamento já tem NF de venda, 3 dias úteis nos demais casos. Só conta de segunda a sexta; feriados não são descontados.
- **Retorno:** é a 1ª análise do lote depois do envio.
- **Situações:** aguardando, atrasada, retornou no prazo, retornou atrasada, resolvida sem reanálise.

### 2.5 NFs de venda

A tela mostra a rastreabilidade da série de cada equipamento até a nota fiscal de saída.

**Abas:**

| Aba | O que mostra |
|---|---|
| OPs sem NF | Lotes conciliados ainda sem nota, com filtro "sem NF há mais de X dias" |
| Vinculadas | Lotes com nota encontrada |
| Saiu com análise em aberto | Equipamento faturado com lote NC ou com ressalva |
| Não lidos | PDFs que a varredura não conseguiu ler |

**Ações:**
- "Varrer agora";
- "Vincular NF" (anexar o PDF da nota ou digitar os dados);
- histórico da série (todas as notas em que ela apareceu);
- exportar CSV.

**Varredura (serviço local):**
- Lê os DANFEs da pasta de rede configurada. Aceita várias pastas e os curingas `{ANO}` e `{ANO-1}`.
- Extrai nº da nota, data, cliente, natureza, CFOPs e as séries dos produtos do catálogo.
- Grava a nota em `nfs_venda`, ou em `nfs_venda_falhas` quando não consegue ler o arquivo.
- É incremental: só lê arquivos novos ou alterados.
- Roda **todo dia** no horário configurado (pode ser mudada para mensal) e também sob demanda.
- Desde 24/08, **todas as saídas** contam, e o tipo de movimento (venda ou outra saída) fica gravado.

### 2.6 Dashboard

**Topo da tela:**
- **Período:** ano, semestre, trimestre, mês ou tudo. O lote conta no mês da 1ª análise.
- **Gerar relatório:** relatório PDF configurável por seções:
  - recorte por setor, equipamento e operador;
  - orientação retrato/paisagem;
  - achados automáticos;
  - modelos salvos para todos os usuários: "Mensal — Gestor PCP", "Mensal — Gestor Almoxarifado" e "Mensal — Qualidade (completo)";
  - opção de geração automática mensal.

**Abas:**

| Aba | Conteúdo |
|---|---|
| **Visão executiva** | Indicadores: lotes conciliados, aprovação de primeira × meta, NCs, corrigidas e abertas, comparação com o período anterior. Linha "Taxa de conformidade — mês a mês" (12 meses, com marco de início do sistema). NCs abertas e envelhecimento. Principais causas, ponto mais crítico, equipamentos acima do limite. **Retorno das correções por setor** (enviadas, retornaram, % no prazo, tempo médio em dias úteis, aguardando, atrasadas e lista do que está pendente) |
| **Onde atacar** | Recorte por setor (todos, Almoxarifado, PCP). Pareto dos tipos de erro (% sobre lotes conciliados), matriz setor × onde ocorreu (estágio ou documento), taxa de NC por equipamento, NCs por operador (permissão própria), tempo de estágio por operador e quanto passou do tempo |
| **Gráficos** | Rosca de conciliações, correções por tipo de documento, erros que motivaram correção, erros por equipamento e últimas análises |
| **Histórico de correções** | Tabela das correções no período, com exportação em Excel |
| **Tendência e reincidência** | Situação de cada tipo de erro (subindo, caindo, recorrente, novo, zerou), mapa mês a mês, e reincidência por chave (categoria + equipamento + alvo) com níveis: reincidente, emergente, possível e pontual. Limiares configuráveis: piso 3, incidência 3%, fator 3× |
| **Melhorias regulatórias** | Sugestões M-01 a M-05 (identificação de instrumento, calibração, firmware, UDI e retenção de amostra) detectadas nos documentos, para a GQ acatar ou não |

### 2.7 Cadastro

**a) Catálogo de produtos**
- Campos: equipamento (família), modelo, código de referência (prefixo da série), registro ANVISA, código Sapiens e ativo. Corresponde ao FORM-GQ-0085.
- Permite importar por planilha.

**b) Fichas Mestres** — uma por **produto + derivação**:
- **Identificação:** nome comercial, derivação e descrição, convenção e exemplo da série.
- **Dados do fabricante:** razão social, CNPJ, endereço, telefone, RT, CREA e Responsável Legal. São os dados confrontados com a etiqueta externa.
- **Estágios:**
  - estágios aplicáveis (10 variáveis);
  - 4 fixos (CQ do produto acabado, Embalagem, Conciliação, Verificação da rotulagem);
  - 2 condicionais (OP de reprocesso, RNC);
  - estágios com inspeção.
  - Os 16 itens correspondem às linhas do FORM.
- **Quadro de acessórios:** obrigatório/opcional, fabricante Confiance × fornecedor, estéril, "pode sair só na NF" e **grupos alternativos** (pelo menos uma variante do grupo).
- **Regras de negócio:** texto livre. Hoje só "ignorar pasta X" tem efeito.
- **"Ficha revisada e apta para análise":** sem isso, nenhum lote do produto é analisado.
- **Revisões:** cada salvamento grava uma versão (`fichas_mestres_versoes`) com descrição automática do que mudou. É possível reverter para uma revisão anterior.
- **Auxiliares:**
  - clonar derivação;
  - pré-preencher a Ficha a partir de documentos de exemplo (OP, RC e etiquetas);
  - exportar fichas em Excel.

**c) Tempos de estágio**
- Para cada equipamento e estágio: tempo médio, tolerância e margem.
- O motor gera ressalva quando o tempo da OP passa da tolerância. O setor responsável é o Almoxarifado nos Estágios 5 e 50, e o PCP nos demais.
- A aba mostra a distribuição dos tempos reais para ajudar a calibrar.

**d) Template FORM-GQ-0047**
- Envio, download e restauração do template oficial (bucket `form-templates/current.xlsx`; há uma cópia embutida no código).
- Mostra a data de aprovação lida da célula A35, que o motor usa para conferir a revisão vigente.

### 2.8 Solicitações — *deixa de existir na migração*

Quem não tem permissão para uma ação pede autorização a quem tem.

- Há 10 ações previstas, e 5 são usadas: excluir análise, excluir ficha, justificar, refazer e remover etiqueta.
- A tela mostra "a aprovar" e "minhas solicitações".

### 2.9 Histórico de alterações (logs)

- Trilha de auditoria (`logs_atividade`): usuário, ação, entidade, descrição e metadados.
- A tela mostra os 1.000 registros mais recentes, com filtros, e exporta todos em Excel.

### 2.10 Configurações

| Card | O que configura |
|---|---|
| Pasta de destino do pacote | Caminho UNC no servidor e opção "subpasta do mês". Tem o botão "Testar serviço" |
| Meta de aprovação de primeira | Padrão 90% |
| Relatórios de qualidade automáticos | Pasta, dia e hora de geração, último resultado e "gerar agora" |
| Reincidência | Piso, incidência mínima e fator de salto |
| NFs de venda | Pastas (com `{ANO}`), frequência (diária ou mensal), dia, hora e ano mínimo |
| Operadores e inspetores | Nome, matrícula, apelidos, estágios de operação e de inspeção e ID do Slack. Desligamento = inativação, nunca exclusão |
| Usuários e permissões | Cargo, permissões individuais, convite e desativação. *Deixa de existir (SCM)* |

**Cargos atuais:** Estagiário GQ, Assistente GQ, Analista GQ, Responsável pela Qualidade/RT e Responsável pela Produção. O e-mail `qualidade@confiancemedical.com.br` é administrador implícito.

**Permissões atuais (19):**

| Grupo | Permissões |
|---|---|
| Dashboard | `dashboard_ver`, `dashboard_operadores` |
| Análise | `analise_executar`, `analise_refazer`, `analise_remover_etiqueta` |
| Histórico | `historico_ver`, `historico_baixar`, `historico_justificar`, `historico_correcao`, `historico_importar`, `historico_excluir` |
| Cadastro | `cadastro_ver`, `cadastro_produtos`, `cadastro_fichas`, `cadastro_excluir_ficha` |
| Configurações | `config_ver`, `config_editar`, `config_usuarios` |
| Logs | `logs_ver` |

---

## 3. Motor de análise (regras de negócio)

O motor é o ativo mais valioso do sistema.

- São regras determinísticas em JavaScript, sem IA, rodando hoje no navegador.
- O código traz comentários datados com cada decisão de negócio. **Esses comentários devem ser preservados** na reescrita.
- As referências de metodologia que continuam no repositório são `CLASSIFICACAO_VERIFICACOES_NC_RESSALVA.md` (severidade de cada verificação), `PROTOCOLO_AGENTE_CONCILIACAO.md` (protocolo original) e `FORM-GQ-0047_Rev9_mapa_celulas.md`.

### 3.1 Leitura dos documentos (parsers)

| Parser | Extrai |
|---|---|
| `parseOP` | Nº da OP, origem, código Sapiens, derivação, modelo, série, data de emissão, estágios, operações (início, fim, tempo, operador), inspeções (nº, status, inspetor, data/hora, estágio), data da conciliação, medições críticas e códigos de barras de apontamento (Início/Fim, Pausa) |
| `parseRC` | OP relacionada, códigos Sapiens, lotes e séries por linha, componentes não conformes |
| `parseEtiqueta` (externa) | Família, modelo, série, ANVISA, fabricante, CNPJ, endereço, telefone, RT, CREA, Responsável Legal, data de fabricação e validade |
| `parseEtiquetaAcessorio` | Descrição, código Sapiens, lote/série, data de fabricação, validade, Fabricante × Fornecedor |
| `parseForm0047` | Modelo, série, revisão, data da conciliação e liberação |

### 3.2 Identificação do produto

- O produto é identificado **pela OP**: código Sapiens e derivação.
- Se o código não estiver no catálogo, o sistema tenta prefixo da série, modelo e ANVISA. Esse comportamento está em revisão (item A12 de `MELHORIAS_E_CORRECOES.md`).
- A derivação sem Ficha ("órfã") bloqueia as conferências de acessórios.

### 3.3 Verificações por camada

**Camada 1 — consistência entre documentos**
- **Série:** OP × etiqueta × FORM e convenção `PREFIXO-AAAAMM-N`.
- **RC:** presente e da mesma OP.
- **Cronologia:** inspeção do estágio N não pode ser posterior ao início de um estágio seguinte.
- **Inspeções:** ordem das duplicadas; status reprovado exige OP de reprocesso ou RNC.
- **Aptidão do inspetor:** conforme o cadastro de operadores (ressalva).
- **Medições:** dentro da faixa.
- **FORM:** revisão vigente, data da conciliação e cópia controlada.
- **Tempo de estágio:** dentro da tolerância (ressalva).
- **Apontamento manual:** códigos Início/Fim e Pausa indicando estágio não finalizado.
- **Acessórios:**
  - lote/série RC × etiqueta (também quando a RC está em branco);
  - Fabricante/Fornecedor etiqueta × Ficha;
  - validade de estéril posterior à conciliação;
  - descrição × código;
  - data de fabricação obrigatória nos itens Confiance;
  - campos em branco na etiqueta (ressalva);
  - etiqueta sem correspondência na RC.

**Camada 2 — Ficha Mestre**
- Código e derivação da OP × Ficha e registro ANVISA.
- **Quadro de acessórios:**
  - na RC sem etiqueta = NC;
  - obrigatório ausente = NC;
  - "pode sair na NF" exige etiqueta;
  - grupo alternativo exige pelo menos uma variante.
- **Inspeções previstas:**
  - estágio com inspeção prevista e sem inspeção = NC;
  - inspeção não prevista = ressalva;
  - os Estágios 50 e 60 são sempre previstos.
- **Etiqueta externa × Ficha:** família, modelo, série, fabricante, CNPJ, endereço, telefone, RT, CREA, Responsável Legal, data de fabricação = emissão da OP e validade INDETERMINADO.

**Camada 3 — regulatória**
- Rastreabilidade, rotulagem, liberação, BPF, reprocesso e RNC, cada item com referência normativa.

### 3.4 Resultado, apontamentos e setor

- **Resultado:** qualquer NC → `nao_conforme`; senão, qualquer ressalva → `ressalva`; senão `conforme`. Itens N/A não entram no índice.
- **Apontamento:** guarda severidade, camada, documento, descrição, recomendação, norma e, quando se aplica, estágios, inspeções, setor responsável, estágio da causa e inspetor.
- **Setor:** segue as regras da seção 1.4.

### 3.5 Indicadores e relatórios (motor de relatório)

- O motor de relatório fica num bloco compartilhado entre o navegador e o serviço local (marcadores `@@MOTOR_RELATORIO_INICIO/FIM`).
- O serviço executa esse mesmo código para gerar os relatórios mensais.
- **`calcularBaseQualidade`:**
  - monta os lotes (vigente, cadeia, mês, equipamento, categoria, correções);
  - monta os registros de NC por apontamento (setor, onde ocorreu, operador);
  - monta os registros de tempo de estágio;
  - monta o acompanhamento das correções.
- **`gerarRelatorioQualidade`:** gera o HTML do relatório, que é convertido para PDF.
- **Ponto de atenção:** algumas telas ainda recalculam indicadores por conta própria (item C1 de `MELHORIAS_E_CORRECOES.md`). Na reescrita, **o motor deve ser a única fonte**.

---

## 4. Arquitetura atual

```
NAVEGADOR (Chrome)                                  MÁQUINA DO SERVIÇO LOCAL (rede da empresa)
plataforma.html — arquivo único, ~20.800 linhas     conversor-pdf-local (Node/Express, porta 3001, PM2)
 · React 18 + Babel no navegador (sem build)          · serve o plataforma.html
 · bibliotecas por CDN (internet)                     · conversão PDF: LibreOffice, Ghostscript, Chromium
 · extração de texto + MOTOR DE ANÁLISE               · grava o pacote na pasta da rede
 · geração FORM / OP anotada / ZIP                    · Slack (webhooks por canal)
 · Dashboard e relatórios (motor compartilhado)       · varredura diária de NFs (DANFE)
        │                                             · relatórios mensais automáticos (PDF na rede)
        │ supabase-js (HTTPS)                         · convite de usuário (Supabase Admin)
        ▼                                                     │
SUPABASE (NUVEM) — banco Postgres, Auth, Storage, Realtime,   │ grava em \\192.168.20.252\...
Edge Function converter-para-pdf → CloudConvert (fallback)    ▼
                                                     Pasta "Pendente de Assinatura" (RT assina)
```

**Características:**
- Toda a lógica de negócio roda no navegador, e o banco é acessado direto pelo navegador.
- As regras de acesso do banco (RLS) liberam tudo para qualquer usuário logado. As permissões só existem na interface.
- O sistema depende de internet: Supabase e CDNs.
- O serviço local roda numa máquina da rede da empresa, gerenciado pelo PM2 (implantação descrita em `MIGRAR_PLATAFORMA_PARA_SERVIDOR.md`). A plataforma é publicada com `git pull` nessa máquina, e `pm2 restart conversor-pdf` quando o `server.js` muda. Os compartilhamentos de rede (pacotes e NFs) ficam no servidor `192.168.20.252`.

---

## 5. Integrações

### 5.1 Serviço local (`conversor-pdf-local/server.js`)

| Rota | Função |
|---|---|
| `GET /` | Serve a plataforma |
| `GET /health` | Teste do serviço |
| `POST /converter-pdf` | Office → PDF (LibreOffice), PDF → PDF sem restrições (Ghostscript), HTML → PDF (Chromium) |
| `POST /salvar-pacote` | Grava ou descompacta o pacote na pasta da rede (cabeçalhos `X-Dest-Path`, `X-Filename`, `X-Extract`) |
| `POST /convidar-usuario` | Convite no Supabase Auth — *sai com o SCM* |
| `POST /notificar-slack` | Repassa a mensagem ao webhook do canal (PCP, Almoxarifado ou geral) |
| `POST /pcp-status` | Lê a planilha do PCP. **Não é chamada pela plataforma** |
| `POST /varrer-nfs` · `GET /varrer-nfs/status` | Varredura de NFs em segundo plano |
| `POST /relatorios-mensais/gerar` · `GET /relatorios-mensais/status` | Relatórios mensais |

**Agendamentos internos (verificados a cada hora):**
- varredura de NFs (diária, por padrão);
- relatórios mensais (dia e hora configurados).

**Scripts de manutenção:**
- `backup-banco.js`: cópia das tabelas;
- `arquivar-storage.js`: copia os arquivos do Storage para o servidor e libera espaço no Supabase.

**Variáveis do `.env`:**
- `SUPABASE_URL`;
- `SUPABASE_SERVICE_ROLE_KEY`;
- `PLATAFORMA_HTML`;
- `SLACK_WEBHOOK_PCP`, `SLACK_WEBHOOK_ALMOXARIFADO`, `SLACK_WEBHOOK_URL`;
- `PORT`.

**Segurança:** nenhuma rota exige autenticação, e o CORS está aberto. Ver item F1 de `MELHORIAS_E_CORRECOES.md`.

### 5.2 Slack

- Usa um Incoming Webhook por canal: `pcp_gq` e `almoxarifado_gq`.
- A menção usa o `slack_user_id` do cadastro de operadores. São mencionados o executor do Estágio 50 ou 60 e o gestor do Almoxarifado nas dúvidas.
- Configuração: `COMO_CONFIGURAR_ALERTA_SLACK.md`.

### 5.3 Pasta da rede

- O pacote do lote é gravado descompactado em `\\192.168.20.252\...\Pendente de Assinatura\<mês>\`.
- Os relatórios mensais vão para a pasta configurada.
- As NFs são lidas de `\\192.168.20.252\confiance medical\NF-e 2.0\...\DANFE\{ANO}`.

### 5.4 Serviços externos (nuvem)

- **Supabase:** banco, Auth, Storage e Realtime.
- **CloudConvert:** via Edge Function, só como reserva quando o conversor local falha.
- **CDNs:** React, Babel, Tailwind, PDF.js, pdf-lib, Mammoth, SheetJS, ExcelJS, JSZip e supabase-js.
- **Google Fonts.**

Todos devem ser eliminados na migração.

---

## 6. Dados

### 6.1 Volume (18/11/2026)

**Banco:** 69 MB no total.

| Tabela | Linhas | Tamanho |
|---|---|---|
| `analises` | ~1.850 | 26 MB, quase tudo no `parecer_completo` |
| `nfs_venda` | ~3.900 | — |
| `nfs_venda_falhas` | ~4.200 | — |
| `logs_atividade` | ~1.900 | — |
| `apontamentos` | ~600 | — |

**Storage:** ~1,4 GB, em ~9.700 arquivos.

| Conteúdo | Tamanho |
|---|---|
| Originais de análises vigentes | 490 MB |
| ZIPs de análises vigentes | 507 MB |
| Originais de análises substituídas | 246 MB |
| Arquivos de análises que não existem mais (órfãos) | 164 MB |

O Supabase bloqueou o Storage em 18/11/2026 por passar da cota do plano gratuito. A empresa vai pagar um mês para extrair os dados.

### 6.2 Tabelas

| Tabela | Conteúdo | Migrar? |
|---|---|---|
| `produtos` | Catálogo | Sim |
| `fichas_mestres` | Ficha por produto + derivação | Sim (ver 9.3: dados do fabricante e campos sem uso) |
| `fichas_mestres_versoes` | Revisões da Ficha (snapshot + motivo) | Sim |
| `acessorios_aplicaveis` | Quadro de acessórios | Sim |
| `analises` | Análises e parecer completo (jsonb) | Sim |
| `apontamentos` | Apontamentos (cópia parcial do jsonb, desatualizada) | Sim, como fonte única **completa** (ver 9.3) |
| `correcoes_solicitadas` | Envios para correção (prazo e retorno) | Sim |
| `envios_pacote` | Envios em pacote (repete `correcoes_solicitadas`) | Unir a `correcoes_solicitadas` |
| `worklist_ops` | Fila de OPs pendentes | Sim |
| `operadores` | Operadores e inspetores × estágios, Slack | Sim |
| `tempos_estagio` | Tempo médio e tolerância por equipamento × estágio | Sim |
| `melhorias_regulatorias` | Sugestões M-01 a M-05 e decisão | Sim |
| `nfs_venda` / `nfs_venda_falhas` | Notas lidas / arquivos não lidos | Sim |
| `config_app` | Configurações (chave/valor) e estado das rotinas | Sim, separando configuração de estado |
| `logs_atividade` | Auditoria | Sim, como legado |
| `perfis`, `convites`, `solicitacoes` | Usuários, convites e aprovações | Não (SCM). Exportar como registro e montar o de-para de usuários |
| `operacoes_livres` | Exceções de aptidão (tela nunca exibida) | Não, se confirmado (item E7) |
| `documentos_analise`, `v_dashboard_stats` e tabelas antigas da BOM/roteiro | Sem uso | Não |

**Buckets:**
- `pacotes-analise`: originais e ZIP. Migrar só os originais; o ZIP pode ser gerado de novo.
- `form-templates`: template do FORM. Migrar.

### 6.3 Pontos de atenção nos dados

- **Status:** usar a coluna `status`. Existe também `conforme_corrigido`, que não está no enum original.
- **Usuários:** os ids em `created_by`, `enviado_por_id`, `justificada_por` etc. são ids do Supabase Auth. É preciso exportar `auth.users` para montar o **de-para com o SCM**.
- **Datas:** estão em UTC (`timestamptz`). O "mês do lote" deve ser calculado no horário de Brasília.
- **Chave do lote:** OP só com dígitos + série em maiúsculas sem espaços. Hoje há telas que não normalizam (item C6).

---

## 7. Documentos de referência que ficam no repositório

| Arquivo | Para quê |
|---|---|
| `MELHORIAS_E_CORRECOES.md` | Melhorias e correções para decisão. Os itens marcados "Migração" são requisitos |
| `CLASSIFICACAO_VERIFICACOES_NC_RESSALVA.md` | Severidade de cada verificação |
| `PROTOCOLO_AGENTE_CONCILIACAO.md` | Protocolo de conciliação (base normativa) |
| `FORM-GQ-0047_Rev9_mapa_celulas.md` | Mapa de células do FORM |
| `MANUAL_DE_USO.md` | Manual da usuária |
| `MIGRAR_PLATAFORMA_PARA_SERVIDOR.md` | Implantação atual no servidor (TI) |
| `COMO_CONFIGURAR_ALERTA_SLACK.md` | Configuração do Slack |
| `conversor-pdf-local/README.md` e `MIGRAR_SERVICO_PARA_SERVIDOR.md` | Serviço local |
| `migration-*.sql` | Histórico de mudanças no banco (a estrutura real vem do dump; ver 9.1) |
| `diagnostico-espaco-supabase.sql` | Diagnóstico de espaço |
| PDFs e planilhas de exemplo | Documentos reais para testes: `OP_6819_*`, `RC_6819.pdf`, etiquetas `.docx`, `Ficha_Mestre_CM-LED.pdf`, `Template_Fichas_Mestres.xlsx`, FORM-GQ-0085, Manual de Conciliação, Guia para Análise da OP, Instrução do Projeto |

---

# PARTE 2 — O QUE O P&D PRECISA PARA A MIGRAÇÃO

## 8. Aderência ao padrão da empresa

| Item do padrão | Situação hoje | O que fazer |
|---|---|---|
| React 18 | Parcial: versão UMD por CDN | Projeto Vite |
| TypeScript, sem `any` | Não atende | Reescrever em TSX |
| Vite + `@vitejs/plugin-react-swc` | Não atende: sem build | Criar o projeto |
| Tailwind CSS | Parcial: por CDN; os tokens do Design System já existem | Portar tokens, tema claro/escuro e folha de impressão |
| shadcn/ui | Parcial: componentes próprios no estilo | Trocar por shadcn |
| lucide-react | Parcial: ícones copiados à mão | Trocar |
| React Router v6 | Não atende: navegação por hash | Rotas, mantendo `#dashboard`, `#historico` etc. como redirecionamento |
| TanStack Query v5 | Não atende | Usar em todas as leituras |
| React Hook Form + Zod, sem `<form>` | Não atende | Todos os formulários (Ficha, Catálogo, Configurações, análise manual) |
| Recharts | Não atende: SVG à mão | Trocar os gráficos |
| Sonner | Não atende: toasts próprios e `alert()` | Trocar |
| Alias `@/` e estrutura `src/...` | Não atende: arquivo único | Estrutura padrão (ver 9.2) |
| `src/config/api.ts` e `services/api/[modulo]` | Não atende: 165 chamadas ao Supabase espalhadas | Centralizar |
| Nomes e comentários em português | **Atende** | Manter, inclusive os comentários datados do motor |
| MySQL no servidor local | Não atende: Supabase (Postgres na nuvem) | Ver 9.3 |
| API REST `/SIGLA/api/v1/` | Não atende: o navegador acessa o banco direto | Ver 9.4 |
| Proibido nuvem | Não atende: Supabase, CloudConvert, CDNs, Google Fonts | Eliminar todos |
| Arquivos no servidor local | Parcial: o pacote vai para a rede; originais e ZIP estão no Supabase | Ver 9.5 |
| Autenticação pelo SCM | Não atende: login próprio | Ver 10 |
| 3 níveis de permissão | Não atende: 5 cargos e 19 permissões | Ver 10.3 |
| localStorage só para a sessão do SCM | Não atende: tema, menu, pasta de destino | Tema pode ir para preferência no backend ou ser aceito como exceção (decidir); pasta de destino só no backend |
| Tratar 401 (→ SCM), 403, 404, 500 | Não atende | `authFetch` com tratamento padrão |
| Documentação ao finalizar | Parcial | Este documento + documentação do P&D na entrega |

---

## 9. Arquitetura alvo

### 9.1 Extração dos dados do Supabase (no mês pago)

Fazer nesta ordem e **conferir antes de cancelar o plano**:

1. **Estrutura real do banco:** `pg_dump --schema-only`. As migrations soltas não descrevem o estado atual com segurança.
2. **Dados completos:** dump de todas as tabelas. O `backup-banco.js` atual **não inclui `correcoes_solicitadas`**; incluir.
3. **Usuários:** `auth.users` (id, e-mail, nome) para o de-para com o SCM.
4. **Arquivos:**
   - `arquivar-storage.js --arquivar`: copia o bucket `pacotes-analise` para o servidor, conferindo o tamanho de cada arquivo;
   - baixar também `form-templates/current.xlsx`.
5. **Conferência:** contagem de linhas por tabela e de arquivos por bucket, origem × destino.
6. **Depois da migração validada:** apagar o projeto Supabase, o que invalida as chaves expostas.

### 9.2 Frontend

- **Stack:** a do padrão da empresa.
- **Módulos (pastas `pages/` e `services/api/`):**
  - `analise` (fila, envio, parecer);
  - `historico`;
  - `nfs`;
  - `dashboard` (incluindo relatórios);
  - `cadastro` (catálogo, fichas, tempos, template);
  - `configuracoes`;
  - `auditoria` (logs).
- **Motor de análise e motor de relatório:**
  - portar para TypeScript **1:1**, como biblioteca (`src/lib/motor/`), preservando os comentários datados;
  - **recomendação:** o motor também deve rodar no backend, como fonte oficial do resultado. O backend reexecuta e grava, e o navegador só mostra. Assim o resultado não depende do cliente e o servidor valida o que é gravado. A decisão é do P&D.
- **Extração de texto:** PDF.js, Mammoth e ExcelJS como dependências npm, sem CDN.
- **Geração:** FORM (ExcelJS), OP anotada (pdf-lib) e ZIP (JSZip), ou no backend.

### 9.3 Banco MySQL (modelo)

- **Ids:** manter os **UUIDs atuais** (`CHAR(36)`). A cadeia de correções depende de `analise_origem_id`.
- **`analises`:**
  - gravar `ficha_versao` (versão da Ficha usada);
  - gravar `equipamento`;
  - gravar `mes_ref` (mês da 1ª análise, horário de Brasília);
  - gravar `op_norm` e `serie_norm` (chave normalizada);
  - `status` como fonte única;
  - `parecer_completo` em `JSON`, enxuto: sem `slots_text` e sem textos repetidos (item E5).
- **`apontamentos`:** fonte única e completa: setor, estágio da causa, inspetor, estágios, justificativa (texto, quem, quando). O parecer não guarda cópia.
- **Lotes:** tabela ou view `lotes` (uma linha por lote: vigente, 1ª análise, mês, categoria, aberto, corrigido em, equipamento, tem NF). As telas leem dela, paginado, em vez de baixar todas as análises.
- **`correcoes_solicitadas`:** absorve `envios_pacote` (com `problema_chave`, `canal`, `analise_id`).
- **Dados do fabricante:** cadastro único e versionado, em vez de repetir em cada Ficha (item A20).
- **Exclusão lógica:** `excluido_em`, `excluido_por`, `motivo` em análises, fichas e produtos. Nunca apagar o histórico de revisões.
- **Configuração:** tabela de configuração separada de uma tabela de estado das rotinas (última varredura, último relatório).
- **Auditoria:** gravada **pelo backend**, com o usuário do token do SCM, ação, entidade e antes/depois.
- **Equipamento:** tabela própria com id, usada por tempos de estágio, catálogo e (se mantida) operações livres. Hoje a ligação é pelo texto.
- **Versionamento:** migrations versionadas na ferramenta escolhida pelo P&D.

### 9.4 API REST (`/SIGLA/api/v1/`) — proposta de recursos

| Recurso | Operações principais |
|---|---|
| `/lotes` | Lista paginada com filtros (situação, correção enviada, documento com pendência, equipamento, período, NF) |
| `/analises` | Criar (executar), detalhar, reanalisar (com documentos substituídos), justificar ressalva, excluir (lógica) |
| `/analises/:id/arquivos` | Enviar e baixar originais; gerar FORM, pacote e parecer em PDF |
| `/analises/:id/pacote/rede` | Gravar o pacote na pasta da rede |
| `/worklist` | Importar a planilha do Sapiens, listar, remover |
| `/correcoes` | Registrar envio, situação e prazo por lote e por setor |
| `/slack` | Enviar alerta por setor (o webhook fica só no backend) |
| `/nfs` | Listar, varrer (assíncrono, com status), vincular manualmente, histórico da série |
| `/produtos`, `/fichas` (+ `/versoes`, `/apta`), `/acessorios`, `/fabricante` | Cadastros |
| `/operadores`, `/tempos-estagio` | Cadastros |
| `/template-form` | Versões do template do FORM (troca só pelo nível 3) |
| `/indicadores` | Base do Dashboard já agregada pelo motor |
| `/relatorios` | Modelos, gerar PDF, geração automática mensal |
| `/melhorias` | Sugestões regulatórias e decisão |
| `/config` | Configurações |
| `/auditoria` | Consulta e exportação dos logs |

Todas as rotas exigem o token do SCM. A permissão é aplicada **no backend**, por nível.

### 9.5 Arquivos no servidor

- **Estrutura sugerida:** `<raiz>/analises/<id_análise>/originais/<slot>_<arquivo>`, igual à atual, para reaproveitar o arquivamento.
- **Tabela `arquivos`:** id, análise, slot, caminho, tamanho, hash.
- **Reanálise:** **reaproveita** o arquivo da análise anterior quando o documento não mudou (item E2). Hoje cada reanálise duplica todos os originais.
- **Pacote ZIP:** não é guardado; é gerado sob demanda (item E3). O pacote oficial continua sendo gravado na pasta da rede.
- **Backup:** a raiz de arquivos precisa entrar no backup do servidor.

### 9.6 Serviço local

- O `conversor-pdf-local` é incorporado ao backend REST:
  - conversão PDF;
  - gravação na rede, só nas pastas configuradas;
  - Slack;
  - varredura de NFs;
  - relatórios automáticos.
- LibreOffice, Ghostscript e Chromium continuam necessários no servidor.
- **Remover:** `/convidar-usuario`, `/pcp-status` (não é usado), o fallback para o CloudConvert e a Edge Function no Supabase.

---

## 10. Autenticação e permissões (SCM)

### 10.1 O que sai

`LoginPage`, `CompletarCadastro`, convite por e-mail, as tabelas `perfis`, `convites` e `solicitacoes`, `ADMIN_EMAIL` fixo no código e a tela Usuários e permissões.

### 10.2 O que entra

- Ler `auth_token`, `auth_refresh_token`, `auth_user` e `auth_permissoes` do localStorage.
- `authFetch` com Bearer.
- 401 → redireciona ao SCM.
- Rotas protegidas.
- Nome e e-mail do usuário vêm de `auth_user`.

### 10.3 Proposta de mapa das permissões atuais para os 3 níveis (validar com a GQ)

| Nível | Pode |
|---|---|
| **1 — Usuário** | Ver Dashboard (sem "NCs por operador"), Histórico e NFs. Executar análise, refazer com documento corrigido, remover etiqueta. Baixar pacote e FORM. Enviar alerta ao Slack. Registrar correção manual |
| **2 — Administrador** | Tudo do nível 1, mais: justificar ressalva, importar análises manuais, ver "NCs por operador", criar e editar produtos, Fichas, operadores e tempos de estágio, editar configurações, varrer NFs, ver auditoria |
| **3 — Gestor** | Tudo do nível 2, mais: excluir análise e Ficha (exclusão lógica), marcar Ficha como "apta para análise", reverter revisão, trocar o template do FORM, configurar relatórios automáticos e metas |

**Decisões da GQ:**
- Justificar ressalva é prerrogativa do RT: nível 2 ou 3?
- O Responsável pela Produção precisa ver "NCs por operador" (hoje tem a permissão): nível 2 só leitura, ou exceção?
- Com o nível 3 cobrindo as ações sensíveis, o fluxo de Solicitações deixa de ser necessário.

---

## 11. Plano de migração e critérios de aceite

### 11.1 Fases

1. **Extração (mês pago):** ver 9.1.
2. **Modelo de dados e carga:** DDL MySQL, carga dos dados com a conversão dos ids de usuário e cópia dos arquivos.
3. **Backend:** API, autenticação SCM e serviço local incorporado.
4. **Motor em TypeScript + regressão.** Esta é a fase crítica:
   - reexecutar as análises históricas, com os originais arquivados, no motor novo;
   - comparar resultado e apontamentos (código, severidade, documento, setor) com o motor atual;
   - a meta é 100% de igualdade, exceto nas correções decididas em `MELHORIAS_E_CORRECOES.md`, que devem ser listadas e explicadas.
5. **Frontend:** as telas da seção 2, já com as simplificações decididas (itens D).
6. **Operação em paralelo:** a GQ usa os dois sistemas por um período combinado e compara pareceres, indicadores e pacotes.
7. **Corte:** desligar o Supabase e o sistema atual.

### 11.2 Critérios de aceite

- [ ] Nenhum dado ou arquivo em nuvem. Nenhuma biblioteca carregada da internet.
- [ ] Login só pelo SCM. 401 redireciona ao SCM. Permissões aplicadas no backend.
- [ ] Contagem de registros e arquivos migrados confere com a origem.
- [ ] Regressão do motor aprovada (ver 11.1, fase 4).
- [ ] Indicadores do Dashboard e dos relatórios iguais entre tela e PDF (mesma fonte).
- [ ] O pacote gravado na rede abre e é assinável no Adobe, como hoje.
- [ ] Alertas de Slack, varredura de NFs e relatórios mensais funcionando no servidor.
- [ ] Auditoria gravada pelo backend, com o usuário do SCM.
- [ ] Documentação técnica entregue pelo P&D.

### 11.3 Pendências de decisão que afetam a especificação

Itens de `MELHORIAS_E_CORRECOES.md` que precisam de decisão antes de o P&D especificar:

- **A2** (estágio ausente: NC ou ressalva), **A8** (regra de severidade), **A14**, **A16**;
- **C1** (unidade dos gráficos: lotes);
- **D1 a D3**, **D6**, **D8**, **D9**, **D13**, **D17** (telas e recursos que saem);
- **E1** (apontamentos: fonte única), **E3** (não guardar ZIP), **E7** (operações livres);
- o **Slack** é permitido pela regra da empresa? Se não, o P&D precisa prever outro canal de alerta.
