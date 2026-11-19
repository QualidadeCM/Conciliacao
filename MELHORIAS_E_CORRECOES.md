# Plataforma de Conciliação — Melhorias e correções (para decisão)

Data: 19/11/2026 · Base: `plataforma.html` e `conversor-pdf-local/server.js` atuais, migrations SQL e documentos da pasta.
Os números de linha citados são do `plataforma.html` atual e mudam conforme o arquivo for editado.
Como o sistema funciona hoje e o que o P&D precisa para a migração estão em `SISTEMA_ATUAL_E_MIGRACAO_PD.md`.

## Como usar este documento

Cada ponto tem uma **recomendação**:

- **Agora:** vale corrigir no sistema atual, porque afeta o resultado das análises, a integridade dos dados ou a extração para o servidor.
- **Migração:** não vale mexer no sistema atual, porque o P&D vai reescrever na stack da empresa. Entra como requisito em `SISTEMA_ATUAL_E_MIGRACAO_PD.md`.
- **Decidir:** depende de uma escolha sua, como remover uma tela ou definir uma regra.

Marque a decisão em cada ponto: **Aplicar**, **Não aplicar** ou **Levar para a migração**. Se preferir, me responda no chat com os códigos (ex.: "aplicar A1–A10, B1–B9; D1 não").

Itens marcados com (*) eu conferi diretamente no código. Os demais vieram da leitura das telas com referência de linha, e eu reviso cada um antes de alterar.

---

## Resumo

| Grupo | Pontos | O que é |
|---|---|---|
| A. Metodologia da análise | 22 | Conferências que pulam em silêncio, severidade, textos do parecer, regras fixas no código |
| B. Integridade dos dados | 9 | Situações em que o sistema grava dado errado ou incompleto |
| C. Indicadores que não batem entre telas | 9 | Dashboard, Histórico, PDF e NFs calculando o mesmo número de jeitos diferentes |
| D. Telas: enxugar e simplificar | 18 | Abas, filtros, botões e recursos repetidos ou que não fazem mais sentido |
| E. Dados duplicados ou em excesso | 11 | Define o que entra (e o que não entra) no banco novo |
| F. Segurança | 6 | Riscos atuais, para mitigar durante o mês pago |
| G. Extração do Supabase | 2 | O que precisa sair antes de desligar o Supabase |
| H. Desempenho | 1 | Lentidão, para resolver na migração |

**Sugestão de prioridade:**
1. B (bugs de gravação).
2. A1–A6 e A22 (conferências que hoje deixam passar erro).
3. F3, F1 e F2 (segurança).
4. G1 (extração completa).
5. E2 (reduzir Storage).

C e D ficam melhor resolvidos já na reescrita do P&D. Mas as decisões de D (o que remover) precisam ser tomadas agora, porque entram na especificação.

---

## A. Metodologia da análise

**A1 · Conferências das etiquetas de acessório só rodam se houver acessório na RC (\*)**
Impacto alto · Esforço P · **Agora**
- **Hoje:** quatro conferências ficam dentro da condição "existe acessório da Ficha na RC com etiqueta" (linha ~7052): Fabricante/Fornecedor, validade de estéril, descrição × código e data de fabricação Confiance. Se todos os acessórios saem na NF, ou a Ficha não tem acessórios cadastrados, as etiquetas anexadas não são conferidas e nada é apontado.
- **Proposta:** essas conferências passam a depender só de haver etiqueta anexada. Etiqueta anexada com a Ficha sem acessórios gera apontamento.

**A2 · Estágio exigido pela Ficha e ausente na OP não gera apontamento**
Impacto alto · Esforço M · **Agora + Decidir**
- **Hoje:** o cruzamento detecta "Ficha diz aplicável, mas o estágio não está na OP", porém não gera item nem apontamento. A conferência de inspeções pula estágios ausentes. O item "Marcações N/A do FORM × Ficha" sai sempre conforme e não lê o FORM quando ele é anexado.
- **Proposta:** estágio aplicável ausente na OP vira apontamento.
- **Decidir:** isso deve ser NC ou ressalva?

**A3 · Itens NC/ressalva sem apontamento: o resultado muda ao justificar outra coisa**
Impacto alto · Esforço M · **Agora**
- **Hoje:** alguns itens contam para o resultado, mas não viram apontamento. Exemplos: "Liberado para comercialização = NÃO", campos ausentes da etiqueta externa, derivação ambígua, ANVISA não lido. Ao justificar qualquer ressalva, o resultado é recalculado só pelos apontamentos. Assim, um lote com NC "Liberado = NÃO" pode virar **conforme**.
- **Proposta:** regra única. Todo item diferente de conforme gera apontamento, e o resultado e o resumo são calculados só pelos apontamentos.

**A4 · Etiqueta externa: campos em branco não são apontados**
Impacto alto · Esforço P · **Agora**
- **Hoje:** modelo, telefone, RT, CREA, Responsável Legal, data de fabricação e validade em branco não geram nada. Se o campo estiver vazio na Ficha, a conferência também é pulada sem aviso.
- **Proposta:** para cada campo, tratar três casos: vazio na etiqueta (ressalva), vazio na Ficha (aviso de Ficha incompleta) e divergente (NC).

**A5 · Inspeções fora do formato esperado desaparecem da leitura da OP**
Impacto alto · Esforço M · **Agora**
- **Hoje:** inspeção sem inspetor, com status diferente de Conforme/Aprovado/Reprovado ou sem hora é descartada inteira. Não entra na cronologia nem na aptidão, e nada é apontado.
- **Proposta:** ler a inspeção mesmo com campos vazios e apontar "inspetor/data em branco". Comparar quantas inspeções existem na OP com quantas foram lidas e gerar ressalva quando forem diferentes.

**A6 · FORM gerado marca "Liberado para comercialização = SIM" mesmo em lote NC (\*)**
Impacto alto · Esforço P · **Agora**
- **Hoje:** o "X" em "Sim" é marcado sempre (linhas 5708–5719). Os estágios aplicáveis recebem SIM mesmo quando não aparecem na OP.
- **Proposta:** marcar a liberação só se o resultado for conforme (senão, "Não" ou em branco). Marcar SIM só para estágio presente na OP.
- **A confirmar:** o FORM de lote NC chega a ser impresso ou arquivado?

**A7 · Data da conciliação substituída em silêncio quando falta a inspeção do Estágio 60**
Impacto médio · Esforço P · **Agora**
- **Hoje:** sem a inspeção do Est. 60, o sistema usa a data de outra inspeção ou a maior data do documento. A validade do estéril e a revisão do FORM passam a ser comparadas com uma data que não é a da conciliação.
- **Proposta:** quando a data não vier do Est. 60, gerar ressalva informando de onde ela veio.

**A8 · Severidade inconsistente para campo em branco e documento ausente**
Impacto médio · Esforço P · **Decidir**
- **Hoje:**
  - na etiqueta de acessório, data de fabricação e validade de estéril em branco são NC, enquanto lote, Fabricante/Fornecedor e descrição em branco são ressalva;
  - etiqueta externa ausente gera só ressalva e sem apontamento, enquanto RC ausente é NC.
- **Decidir:** qual a regra geral? Sugestão: em branco = ressalva, com exceção registrada para estéril e data de fabricação Confiance; documento obrigatório ausente = NC.

**A9 · O mesmo erro apontado em dobro**
Impacto médio · Esforço P · **Agora**
- **Hoje:** código que não está na Ficha nem na RC gera dois NCs. Série divergente aparece em dois blocos. ANVISA ausente aparece em C2 e em C3. Isso infla a contagem de NCs nos indicadores.
- **Proposta:** cada erro gera um único apontamento.

**A10 · FORM virtual "confere consigo mesmo"; revisão fixa no código**
Impacto médio · Esforço P · **Agora**
- **Hoje:** quando não há FORM anexado, o sistema monta um FORM com a série e a data copiadas da OP. Por isso sempre sai "série idêntica em OP e FORM" e "data OP = FORM". A revisão está fixa como '8' no código, mas o template é Rev. 9.
- **Proposta:** com FORM virtual, não comparar série nem data. Ler a revisão do próprio template.

**A11 · O texto do parecer afirma coisas que não foram verificadas**
Impacto médio · Esforço P · **Agora**
- **Hoje:**
  - o texto fala em "aderência à BOM aprovada", e a BOM está fora do escopo;
  - diz "campos de assinatura corretamente em branco", o que não é conferido;
  - "Rastreabilidade do lote" é sempre conforme;
  - liberação "incerta" conta como conforme.
- **Proposta:** ajustar os textos e tratar esses itens como informativos ou como verificação de fato. Isso é relevante em auditoria.

**A12 · O produto ainda pode ser identificado fora da OP**
Impacto médio · Esforço P · **Agora**
- **Hoje:** se o código da OP não está no catálogo, o sistema procura em todos os documentos e pode pegar um código de acessório. Isso contraria a regra "produto identificado pela OP".
- **Proposta:** código da OP não cadastrado bloqueia a análise. Identificação que não veio da OP vira ressalva.

**A13 · "Consta na RC" decidido por trecho de texto**
Impacto médio · Esforço P · **Agora**
- **Hoje:** "ACE0004" é considerado presente quando a RC tem "ACE00041". O lote do acessório é procurado só na primeira linha onde o código aparece.
- **Proposta:** comparar o código exato e percorrer todas as linhas do código.

**A14 · A conferência "Não Conforme" na RC praticamente nunca detecta caso real**
Impacto médio · Esforço M · **Decidir**
- **Hoje:** o sistema procura o texto "Não Conforme". Na RC, um componente não conforme aparece como quantidade na coluna, não como texto.
- **Decidir:** ler a coluna de quantidade não conforme ou remover a conferência e registrar a decisão.

**A15 · Medições: número lido errado e itens pulados sem aviso**
Impacto médio · Esforço P · **Agora**
- **Hoje:** "0.5" vira 5. Medições não numéricas são puladas e mesmo assim o parecer diz "Todas as N medições dentro da faixa". Medição reprovada não é conferida.
- **Proposta:** corrigir a conversão, contar e apontar as medições não avaliadas e ajustar o texto.

**A16 · Inspeção reprovada × OP de Reprocesso**
Impacto médio · Esforço M · **Decidir**
- **Hoje:** o NC "Exige OP de Reprocesso" continua mesmo com a OP de Reprocesso ou a RNC anexada. O anexo vira conforme sem leitura do conteúdo.
- **Proposta:** com o anexo presente, conferir ao menos o número da OP e a série nele, e então rebaixar ou encerrar o NC.

**A17 · Conferência some quando um cadastro não carrega**
Impacto médio · Esforço P · **Agora**
- **Hoje:** se a leitura de operadores ou de tempos de estágio falha, a conferência desaparece do parecer sem aviso.
- **Proposta:** incluir o item "conferência não realizada" como ressalva.

**A18 · Mapa de estágios divergente**
Impacto médio · Esforço P · **Agora**
- **Hoje:** a Gravação é o Est. 39 na Ficha e o 37 na leitura da OP. Fichas sem "estágios com inspeção" geram ressalva em todo estágio, porque a regra padrão prometida no código não existe.
- **Proposta:** unificar o mapa de estágios e exigir essa informação na Ficha.

**A19 · Etiqueta de acessório com código ilegível vira "etiqueta ausente"**
Impacto médio · Esforço P · **Agora**
- **Proposta:** usar a mesma leitura de código dos outros documentos e criar o apontamento "etiqueta anexada sem código legível" (ressalva).

**A20 · Regras e dados fixos no código, e dados do fabricante repetidos em cada Ficha**
Impacto médio · Esforço M · **Agora (parcial) + Migração**
- **Hoje:**
  - ficam fixos no código: validade "INDETERMINADO" obrigatória, endereço Rua Bela/CEP/CNPJ, valores padrão de RT/CREA/CNPJ quando a Ficha está vazia, nomes "Samara/Fernando" no texto do parecer, estágios de inspeção universais 50/60;
  - razão social, CNPJ, RT etc. são repetidos em cada Ficha, e "Importar de documentos" preenche RT/CREA a partir da própria etiqueta que depois é conferida.
- **Proposta:** cadastro único "Dados do fabricante", versionado. Ficha vazia gera aviso em vez de usar valor padrão. A importação não sobrescreve os dados do fabricante.

**A21 · Leituras frágeis**
Impacto médio · Esforço P · **Agora**
- **Hoje:**
  - a série da OP/FORM pega a primeira ocorrência, que pode ser de um acessório;
  - a data de emissão é a primeira data sem hora e alimenta o NC "data de fabricação ≠ emissão", com risco de falso NC;
  - o mês da série aceita valores de 13 a 19;
  - o ANVISA não é lido no formato "nº".
- **Proposta:** ancorar a leitura nos rótulos, validar o mês e testar com PDFs reais.

**A22 · A análise não registra qual revisão da Ficha foi usada**
Impacto alto · Esforço P · **Agora**
- **Hoje:** só o `ficha_id` é gravado. Depois de editar a Ficha, não dá para provar com qual versão o parecer foi gerado.
- **Proposta:** gravar a versão da Ficha na análise. Para as análises antigas, a versão pode ser reconstruída pela data.

---

## B. Integridade dos dados

**B1 · Depois de "Refazer análise", a tela continua gravando na análise antiga (\*)**
Impacto alto · Esforço P · **Agora**
- **Hoje:** depois de refazer, justificar uma ressalva grava o parecer novo por cima da análise original (linha 10493). O Slack e a busca de "irmãs" também usam o id antigo. Uma segunda reanálise aponta para a original, e a cadeia de correções vira um "galho".
- **Proposta:** usar o id da análise que está na tela em todas as ações.

**B2 · Reanálise grava em vários passos, sem garantia de que todos dão certo**
Impacto alto · Esforço M · **Agora (parcial) + Migração**
- **Hoje:**
  - a análise nova é criada solta e só depois recebe o vínculo, sem verificar erro;
  - se o resultado não mudou, a análise é apagada, mas os arquivos dela continuam no Storage (parte dos 164 MB "órfãos").
- **Proposta:** agora, verificar os erros e apagar também os arquivos. Na migração, gravar numa única transação.

**B3 · Alerta ao Slack: se o 2º canal falha, nada é registrado**
Impacto médio · Esforço P · **Agora**
- **Proposta:** registrar cada setor logo após o envio dele dar certo.

**B4 · "Nova análise manual" confere duplicidade só nas primeiras 1000 análises**
Impacto médio · Esforço P · **Agora**
- **Proposta:** consultar direto por OP e série.

**B5 · Envio em pacote: o aviso "já cobrado" lê só 1000 envios**
Impacto médio · Esforço P · **Agora**

**B6 · Salvar a Ficha apaga e reinsere os acessórios em passos separados**
Impacto médio · Esforço M · **Migração**
- **Hoje:** se falhar no meio, a Ficha fica sem acessórios e continua marcada como apta.
- **Proposta:** gravar tudo numa única transação no backend novo.

**B7 · "Desativar usuário" não bloqueia o acesso (\*)**
Impacto médio · Esforço P · **Agora**
- **Hoje:** o perfil é carregado sem conferir se está ativo (linha 20625). Deixa de existir com o SCM.

**B8 · O parecer e o Resumo em PDF mostram a data de hoje como "Data da análise"**
Impacto médio · Esforço P · **Agora**
- **Hoje:** ao abrir pelo Histórico ou gerar o pacote de novo, aparece a data do dia, não a da análise. Isso é relevante em auditoria.

**B9 · "Limpar lista" de OPs apaga a lista compartilhada de todos sem confirmação**
Impacto médio · Esforço P · **Agora**

---

## C. Indicadores que não batem entre telas

**C1 · Dashboard e PDF com o mesmo título e números diferentes**
Impacto alto · Esforço M · **Agora + Decidir**
- **Hoje:** a Visão executiva e o Onde atacar recalculam por conta própria, fora do motor do relatório. O Pareto, a matriz setor × onde, o mapa mês a mês e os erros por equipamento contam **lotes** na tela e **apontamentos** no PDF.
- **Decidir:** qual a unidade de cada gráfico? Recomendo **lotes** na tela e no PDF.
- **Proposta:** as telas passam a usar só o motor.

**C2 · O mês do lote depende do fuso horário**
Impacto médio · Esforço P · **Agora**
- **Hoje:** um lote analisado entre 21h e meia-noite do último dia do mês cai no mês seguinte no relatório e no gráfico mensal, e no mês certo nos cartões e no Histórico.
- **Proposta:** uma única regra de mês, no horário de Brasília.

**C3 · Quatro regras diferentes de "setor responsável"**
Impacto alto · Esforço P/M · **Agora**
- **Hoje:** o motor, o Slack, o tempo de estágio e a exportação usam regras diferentes. Exemplo: Data/Validade vai ao canal do PCP no Slack, mas o motor atribui ao Almoxarifado quando o documento é etiqueta. O "Retorno das correções por setor" cruza setores que não se correspondem.
- **Proposta:** regra única, gravada em cada apontamento no momento da análise.

**C4 · Equipamento obtido de 6 a 7 formas diferentes**
Impacto médio · Esforço P · **Agora**
- **Hoje:** o mesmo lote aparece em equipamentos diferentes conforme a tela. No Histórico, a coluna mostra um equipamento e o filtro filtra por outro.
- **Proposta:** gravar o equipamento na análise.

**C5 · Filtro "Conforme corrigido" do Histórico inclui lotes ainda NC (\*)**
Impacto alto · Esforço P · **Agora**
- **Hoje:** a regra é "mais de uma análise", então um lote que segue NC aparece em "corrigido" e em "Não conforme" ao mesmo tempo.

**C6 · O mesmo lote aparece "com NF" numa tela e "sem NF" em outra**
Impacto médio · Esforço P · **Agora**
- **Hoje:** a série é normalizada no Dashboard e não é normalizada no Histórico. Isso muda o prazo de correção (1 × 3 dias úteis). Eu introduzi essa diferença no acompanhamento de correções da semana passada, e corrijo.

**C7 · "Aguardando correção": Histórico e Dashboard calculam diferente**
Impacto médio · Esforço P · **Agora**
- **Hoje:** o Histórico olha só o último envio. Um lote que voltou, foi reanalisado e segue NC aparece "Aguardando" no Histórico e "Retornou" no Dashboard. Também foi introduzido por mim, e corrijo junto com o C6.

**C8 · Tela de NFs com contagens próprias**
Impacto médio · Esforço P · **Agora**
- **Hoje:**
  - "Dias sem NF" zera após uma reanálise, enquanto o Dashboard conta desde a 1ª análise;
  - "Conforme corrigido" aparece como conforme;
  - o CSV não bate com os cartões;
  - o texto ainda diz que a varredura é "mensal".

**C9 · Textos dos cartões da aba Gráficos não correspondem ao cálculo**
Impacto médio · Esforço P · **Agora ou junto com D1**
- **Hoje:** dizem "NC + ressalvas", mas contam só NC. O centro do donut diz "análises", mas conta lotes.

---

## D. Telas: enxugar e simplificar

**D1 · A aba Gráficos repete a Visão executiva e o Onde atacar**
**Decidir**
- **Proposta:** remover a aba. Mover "correções por documento" para a aba Correções e o tempo de estágio para o Onde atacar.

**D2 · A aba Tendência mede tendência de 3 jeitos diferentes**
**Decidir**
- **Hoje:** os três blocos são situação das causas, mapa de calor e reincidência. A mesma causa pode aparecer "subindo" num bloco e "caindo" no outro. A reincidência abre em "semana", mas os níveis valem para 30 dias. O Slack usa outra classificação.
- **Proposta:** uma régua única para os três blocos e para o Slack, com 30 dias como padrão.

**D3 · Aba "Histórico de correções" no Dashboard**
**Decidir**
- **Proposta:** virar um filtro "teve correção" no Histórico, com exportação.

**D4 · O filtro "Status" do Histórico mistura três coisas**
Impacto médio · **Agora**
- **Hoje:** num único filtro estão o resultado, "em aberto" e "correção enviada/atrasada", que eu incluí semana passada. Não dá para filtrar "NC + atrasada".
- **Proposta:** três filtros:
  - **Situação:** conforme, com ressalva, corrigido, NC aberta.
  - **Correção enviada:** todas, aguardando, atrasada.
  - **Documento com pendência:** OP, RC, etiqueta externa, etiqueta de acessório.

**D5 · "Pendente" tem três significados no Histórico**
**Agora**
- **Hoje:**
  - o chip "pendente" significa pacote não baixado;
  - "Baixar pendentes" considera só conformes;
  - há combinações de filtro que sempre dão vazio;
  - com nada encontrado, a tela diz "Nenhuma análise registrada";
  - o período abre em "Tudo" no Histórico e em "Ano" no Dashboard.
- **Proposta:** renomear para "Pacote não baixado", mostrar "Nenhum resultado — Limpar filtros" e usar o mesmo período padrão nas duas telas.

**D6 · Quatro jeitos de reanalisar, com regras diferentes**
**Decidir**
- **Hoje:** existem "Refazer" na tela do parecer, "Reprocessar irmãs", "Reanalisar documentos corrigidos" e uma função antiga sem uso. Uma apaga a análise quando nada muda, outra não.
- **Proposta:** um único fluxo. Na tela do parecer, abrir o mesmo modal já com o lote selecionado. Avisar antes de sair com documentos anexados e não reanalisados.

**D7 · Botões de download espalhados**
**Agora**
- **Hoje:** o FORM (Excel) some quando a análise é aberta pelo Histórico, embora esteja guardado.
- **Proposta:** um menu único "Baixar ▾" com Pacote, FORM e Parecer.

**D8 · Análises manuais em três telas (Importar, Nova, Corrigir)**
**Decidir**
- **Pergunta:** a importação de análises antigas ainda é usada? Se a carga histórica terminou, remover a importação e manter só "Nova análise manual".

**D9 · "Melhorias regulatórias" dentro do Dashboard**
**Decidir**
- **Proposta:** é uma fila de trabalho, não um indicador. Passar para um menu próprio.

**D10 · Exportações dispersas**
**Migração**
- **Hoje:** usam 2 bibliotecas, 3 formatos e regras próprias. (A coluna "Origem" do backup, que saía sempre "agente", foi corrigida em 19/11/2026.)
- **Proposta:** um módulo único de exportação.

**D11 · Textos antigos e mensagens técnicas para o usuário**
**Agora**
- **Hoje:** aparecem "o agente está analisando (15–60 s)", "CloudConvert", "sem estes 4 arquivos" (são 3) e alertas do tipo "rode migration-pacote-zip-storage.sql no Supabase Studio".
- **Proposta:** revisar os textos e trocar os `alert()` por avisos padrão.

**D12 · Selecionar linhas no Histórico e "ver estes lotes" a partir do Dashboard**
**Decidir (recurso novo)**
- **Proposta:** caixa de seleção por linha, com ações em lote (baixar, exportar, enviar para correção, vincular NF).

**D13 · Campos da Ficha que o motor não usa**
**Decidir**
- **Hoje:** "Nome comercial" é obrigatório e não tem efeito. "Convenção do nº de série", "exemplo" e "data de concessão ANVISA" também não são usados; a série é validada pelo código de referência do produto.
- **Proposta:** remover esses campos ou passar a usar a convenção da Ficha como fonte da validação da série.

**D14 · Produto e Ficha em telas separadas, ligados por texto**
**Migração**
- **Hoje:** tempos de estágio e exceções usam o **nome** do equipamento como ligação. Renomear um equipamento quebra esses vínculos.
- **Proposta:** uma tela Produto → Derivações (Fichas), com chaves de verdade no banco.

**D15 · "Regras de negócio" em texto livre na Ficha**
**Migração**
- **Hoje:** o sistema só entende frases do tipo "ignorar pasta X"; o resto é ignorado sem aviso.
- **Proposta:** um campo estruturado "subpastas a ignorar"; o texto livre fica só como observação.

**D16 · Template do FORM-GQ-0047 sem controle**
**Agora (permissão) + Migração**
- **Hoje:** qualquer usuário com acesso à tela consegue trocar ou apagar o template, sem versão e sem log. Existe ainda uma segunda cópia embutida no código.
- **Proposta:** template versionado, troca só por Gestor (nível 3) e com log.

**D17 · Solicitações de aprovação**
**Migração (remover)**
- **Hoje:** só 5 das 10 ações são usadas, e o recurso duplica o papel do SCM.
- **Proposta:** remover; ações sensíveis ficam para o nível 3. Exportar o histórico antes.

**D18 · Login, convites, cargos e permissões próprios**
**Migração (remover)**
- **Proposta:** substituir pelo SCM. As 19 permissões atuais precisam ser mapeadas para os 3 níveis (Usuário, Administrador, Gestor). A proposta de mapa está em `SISTEMA_ATUAL_E_MIGRACAO_PD.md`.

---

## E. Dados duplicados ou em excesso (definem o banco novo)

**E1 · Apontamentos guardados em dois lugares, que divergem**
Impacto alto · **Decidir + Migração**
- **Hoje:** os apontamentos estão na tabela `apontamentos` e dentro do parecer (jsonb). A justificativa vai só para o parecer. As análises manuais não gravam na tabela. A reincidência do Slack lê a tabela.
- **Decidir:** qual a fonte única? Recomendo uma tabela completa (com setor, estágio, justificativa), e o parecer guarda só o retrato.

**E2 · Cada reanálise reenvia todos os documentos originais**
Impacto alto · Esforço M · **Agora**
- **Hoje:** um lote com 3 reanálises tem 4 cópias da mesma RC no Storage. Isso explica boa parte dos 246 MB de "substituídas".
- **Proposta:** reaproveitar o arquivo da análise anterior para os documentos que não mudaram.

**E3 · Pacote ZIP guardado além dos originais**
Impacto alto · **Decidir**
- **Hoje:** são 507 MB de ZIP que podem ser gerados de novo. A exportação para auditoria só funciona com ZIP guardado.
- **Proposta:** não guardar mais o ZIP; gerar sob demanda, inclusive na auditoria. Não migrar os ZIPs. O pacote oficial continua indo para a pasta de rede.

**E4 · O mesmo envio de correção registrado em três lugares**
**Agora (simples) ou Migração**
- **Hoje:** cada envio grava em `envios_pacote`, `correcoes_solicitadas` e no log.
- **Proposta:** uma tabela só (`correcoes_solicitadas`).

**E5 · O parecer guarda informação em excesso**
**Migração**
- **Hoje:**
  - cada item do parecer guarda o mesmo texto duas vezes;
  - o texto bruto de todos os documentos fica dentro do parecer;
  - as 5 sugestões regulatórias se repetem em todo lote;
  - o resumo é gravado em coluna e no parecer.

**E6 · Status gravado em três lugares e lido de forma misturada**
**Agora (leitura) + Migração**
- **Hoje:** o status está na coluna, no `resultado_geral` e no resumo.
- **Proposta:** a coluna é a fonte única.

**E7 · Tabelas e colunas sem uso (não migrar)**
**Decidir**
- `operacoes_livres`: a tela existe no código, mas nunca é exibida (\*).
- `convites`, `documentos_analise`, `v_dashboard_stats`, buckets `documentos-analise` e `relatorios`.
- Colunas `tempo_execucao_ms`, `iniciada_em`, `etiqueta_externa_campos`, `produtos_associados` (recurso removido em agosto) e `nfs_venda.tem_analise` (fica desatualizada).
- **Decidir:** a tela de operações livres deveria estar visível? Se não, removemos.

**E8 · Configurações espalhadas**
**Agora (parcial) + Migração**
- **Hoje:**
  - a pasta de destino do pacote usa primeiro o que está guardado no navegador, então uma máquina pode gravar na pasta antiga depois que o admin trocou a configuração;
  - o estado das rotinas (última varredura etc.) está misturado com a configuração;
  - nomes e e-mails estão fixos no código;
  - o texto "Só notas de venda entram" contradiz a decisão de agosto (todas as saídas contam).

**E9 · Exclusão física de registros da qualidade**
Impacto alto · **Migração (Agora, se quiser)**
- **Hoje:** excluir uma análise apaga os apontamentos. Excluir uma Ficha apaga todo o **histórico de revisões**. Os arquivos ficam órfãos no Storage.
- **Proposta:** exclusão lógica (quem, quando, motivo), sem apagar o histórico. ISO 13485 §4.2.5.

**E10 · Logs gravados pelo navegador**
**Migração**
- **Hoje:** o autor do log é informado pelo próprio navegador, então pode ser falsificado. Se a gravação falha, ninguém fica sabendo.
- **Proposta:** a auditoria é gravada pelo backend, com o usuário do token do SCM.

**E11 · Código sem uso**
**Agora**
- **Exemplos:**
  - a função antiga de reanalisar OP corrigida;
  - a seção "Resumo da análise" (removida em julho e ainda no código);
  - gráficos de estágio/inspeção que nunca aparecem;
  - uma regra antiga de setor (`setorPorCategoria`);
  - campos lidos e nunca usados nos parsers;
  - avisos de "migration não rodada".
- **Proposta:** remover para o P&D não especificar o que não existe.

---

## F. Segurança (mitigar durante o mês pago)

**F1 · O serviço do servidor aceita qualquer requisição da rede**
Impacto alto · Esforço P · **Agora**
- **Hoje:** nenhuma rota exige identificação (\* CORS aberto, linha 99). Qualquer máquina da rede consegue:
  - criar usuário com permissões de administrador (`/convidar-usuario`);
  - gravar arquivo em qualquer pasta do servidor (`/salvar-pacote`);
  - fazer o servidor baixar qualquer endereço;
  - postar no Slack;
  - disparar varreduras.
- **Proposta:** exigir o token do usuário logado nas rotas, aceitar só as pastas configuradas e restringir à rede interna.

**F2 · Qualquer usuário logado consegue se dar permissão de administrador**
Impacto alto · Esforço M · **Agora (mínimo)**
- **Hoje:** as regras do banco permitem a qualquer logado alterar qualquer tabela, inclusive o próprio perfil e solicitações de aprovação.
- **Proposta:** no mínimo, bloquear a alteração de `perfis` e `solicitacoes` por usuários comuns.

**F3 · Documentos enviados ao CloudConvert (nuvem) sem aviso (\*)**
Impacto alto · Esforço P · **Agora**
- **Hoje:** se o conversor local falha, a OP e o FORM vão para um serviço externo (linhas 10940–10949). Isso fere a regra da empresa.
- **Proposta:** remover essa alternativa, mostrar erro claro e desligar a função no Supabase.

**F4 · Chaves e cópia do banco no repositório do GitHub**
Impacto alto · Esforço P · **Agora**
- **Hoje:** a pasta `Backup_v1_2026-07-01` (com `Supabase API Keys.txt` — chave pública, sem a chave de serviço — e um dump do banco) foi removida da versão atual em 19/11/2026, mas continua no **histórico** do git.
- **A confirmar:** o repositório é privado? O cadastro livre de usuários está desligado no Supabase?
- **Proposta:** se o repositório não for privado, limpar o histórico (`git filter-repo`). Ao final da migração, apagar o projeto Supabase, o que invalida as chaves.

**F5 · Cadastros sem controle de permissão**
Impacto alto · Esforço P · **Agora**
- **Hoje:** quem só tem permissão de ver consegue criar e excluir produtos, editar Fichas, marcar a Ficha como "apta", reverter revisões e trocar o template do FORM.
- **Proposta:** editar = Administrador; marcar apta, excluir e trocar template = Gestor.

**F6 · Endpoints e chaves do Slack/Supabase no código**
**Migração**
- **Proposta:** URLs e chaves vão para a configuração do backend (`config/api.ts` no frontend), conforme o padrão da empresa.

---

## G. Extração do Supabase

**G1 · O script de backup não leva tudo (\*)**
Impacto alto · Esforço P · **Agora**
- **Hoje:** faltam a tabela `correcoes_solicitadas`, o bucket `form-templates` (template do FORM), a lista de usuários do login (necessária para saber quem fez cada ação) e a estrutura real das tabelas.
- **Proposta:** dump completo (estrutura e dados), tabela de-para entre os usuários do Supabase e do SCM, cópia dos arquivos (script `arquivar-storage.js`) e conferência de contagem por tabela.

**G2 · Estrutura do banco: usar a do banco real**
**Agora**
- **Hoje:** as tabelas principais só estavam descritas num `schema.sql` antigo da pasta Backup (removida do repositório em 19/11/2026). As migrations soltas não descrevem o estado atual com segurança.
- **Proposta:** extrair a estrutura do banco real (`pg_dump --schema-only`) e entregar ao P&D junto com os dados.

---

## H. Desempenho

**H1 · Telas lentas porque carregam e recalculam tudo**
**Migração**
- **Hoje:**
  - Dashboard, Histórico e NFs baixam todas as análises a cada abertura e recalculam tudo a cada clique;
  - o Histórico recalcula a cadeia de cada linha (cresce ao quadrado);
  - qualquer gravação dispara recarga completa;
  - "Enviar ao Slack" lê a base inteira para calcular a reincidência;
  - a aba Tempos de estágio lê todos os pareceres.
- **Proposta:**
  - o backend calcula e guarda o estado de cada lote (vigente, mês, status, setor, equipamento, NF), e as telas leem pronto e paginado;
  - **agora**, só os ganhos rápidos se a lentidão estiver atrapalhando.

---

## Pontos a confirmar com você

1. O repositório `QualidadeCM/Conciliacao` no GitHub é privado?
2. O cadastro livre de usuários está desligado no Supabase (Authentication → Providers → "Allow new users to sign up")?
3. A importação de análises manuais (planilha) ainda é usada? (D8)
4. O FORM gerado de lote NC chega a ser impresso ou arquivado? (A6)
5. A tela "Operações livres" deveria estar visível? (E7)
6. O Slack é permitido pela regra da empresa ("proibido serviços externos")? Se não, o P&D precisa prever outro canal de alerta.
