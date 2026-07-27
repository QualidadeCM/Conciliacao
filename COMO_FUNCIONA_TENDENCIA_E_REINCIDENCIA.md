# Como funciona a análise de tendência e reincidência

Este documento explica, em texto corrido, a regra que o painel **"Análise de tendência e reincidência"** (no Dashboard) usa hoje, para você revisar e decidir se quer mudar algum parâmetro. Tudo o que está descrito aqui reflete o comportamento atual da plataforma.

## O recorte de período

O painel tem um seletor de período próprio (os campos **De** e **Até**), que é independente do filtro de período do topo do Dashboard. Tudo que o painel mostra — tanto a parte de tendência quanto a de reincidência — é calculado dentro desse intervalo que você escolhe. Se você quiser olhar por trimestre, por semestre ou por um mês específico, basta ajustar essas duas datas. A recomendação prática é comparar períodos com volume parecido (por exemplo, trimestre contra trimestre), porque períodos muito curtos, com poucos lotes, deixam os percentuais instáveis.

## A parte de tendência (correções)

A tendência olha para as **correções** feitas no período. Uma correção, aqui, é uma reanálise que de fato corrigiu um documento — ou seja, uma reanálise vinculada a uma análise original. Reanálises que foram apenas ajuste de ficha mestre ou cadastro de operador não contam como correção, porque nesses casos a documentação do lote já estava conforme. O gráfico "Correções por mês" conta essas correções mês a mês dentro do período (inclusive meses com zero), e a média é simplesmente o total de correções dividido pela quantidade de meses do intervalo.

A palavra **tendência** ("em alta", "em queda" ou "estável") vem de uma comparação simples entre a primeira e a segunda metade dos meses do período. A plataforma soma as correções da metade inicial dos meses e compara com a soma da metade final. Se a segunda metade tiver mais de 15% a mais que a primeira, a tendência é dita "em alta"; se tiver mais de 15% a menos, "em queda"; entre esses dois limites, "estável". É um indicador grosseiro de direção, pensado só para dar uma leitura rápida — não é uma projeção estatística.

Ainda nessa parte, as listas "Erros que mais motivaram" e "Equipamentos com mais correções" olham para as análises **originais** das correções do período e contam, respectivamente, as categorias de erro que motivaram cada correção e os equipamentos envolvidos.

## A parte de reincidência (o coração da análise)

A reincidência foi desenhada para responder à pergunta "esse mesmo problema está se repetindo, ou está aparecendo mais do que costumava?". Ela não olha para o tipo de documento; olha para o **erro** que motivou a não conformidade.

### A chave: o que conta como "o mesmo problema"

Cada erro é resumido numa **chave em três camadas**: a categoria do erro, o equipamento e o alvo específico. A categoria é aquela classificação que a plataforma já faz (Nº de série, Registro ANVISA, Nome do produto, Cronologia, Lote/Código, Inspeção/Medição, Operador/estágio, e assim por diante). O equipamento vem do produto do lote (a família/equipamento cadastrado). O alvo é o detalhe específico extraído da descrição da NC — tipicamente o acessório e seu código, quando existe, como "Cabeça de Câmera CM-SCAM (IPM0023)". Quando o erro não tem um alvo específico identificável (por exemplo, "Nome do produto"), a chave fica só com categoria + equipamento.

Juntando as três camadas, "Nº de série no insuflador" é tratado como um problema diferente de "Nº de série na microcâmera", e cada um tem sua própria contagem e sua própria linha de histórico. É isso que torna a análise acionável para causa raiz: você enxerga exatamente onde o problema se concentra, e não só "deu erro de série em algum lugar".

Vale saber que a extração do alvo é feita por leitura do texto da NC, então ela é confiável quando o código aparece no padrão esperado (como "(IPM0023)"); quando não há um código claro, a chave recai para categoria + equipamento, que é o comportamento pretendido.

### Como as ocorrências são contadas

A reincidência conta a análise **original** de cada lote (a que registrou os erros de fábrica), nunca as reanálises, para não contar o mesmo lote duas vezes. Dentro do período que você escolheu, para cada chave a plataforma conta em quantos lotes distintos aquele erro apareceu. Se o mesmo erro aparecer várias vezes no mesmo lote, conta como um só — o que importa é em quantos lotes o problema ocorreu.

A **incidência** é a peça que normaliza pelo volume: é o número de lotes com aquele erro dividido pelo total de lotes analisados no período. Ou seja, é a frequência do erro sobre a produção do período, não sobre o total de não conformidades. Assim, "5 ocorrências" significa coisas diferentes se você analisou 30 ou 300 lotes, e a incidência captura essa diferença.

### A base histórica

Para saber se algo "está aparecendo mais do que costumava", a plataforma calcula a mesma incidência daquela chave nos **12 meses anteriores** ao início do período escolhido. Essa é a base histórica. Comparar o período atual com a base é o que permite dizer que um erro que praticamente não existia passou a acontecer com frequência — o sinal de que alguma coisa mudou (uma falha humana, uma mudança de processo, um problema de sistema).

### Os três níveis

Com a incidência do período e a base histórica em mãos, cada chave recebe um de três níveis. É **reincidente** quando bate o piso de ocorrências e a incidência fica igual ou acima do mínimo — ou seja, é um problema recorrente e relevante no período, que pede análise de causa raiz e ação corretiva. É **tendência emergente (em alta)** quando a incidência atual pula muito acima da base histórica — seja porque a base era praticamente zero e agora passou do mínimo, seja porque a incidência ficou várias vezes maior que a base — mesmo que a contagem absoluta ainda seja modesta; é o alerta precoce de que algo mudou. E é **pontual** quando não se enquadra em nenhum dos dois, indicando um caso isolado que se resolve só com a correção imediata, sem abrir causa raiz.

Um mesmo erro pode, ao longo do tempo, começar como pontual, virar emergente quando a frequência sobe acima do histórico e, se persistir com volume, ser classificado como reincidente.

## Os parâmetros que você pode ajustar

Três números controlam essa classificação, e todos estão editáveis em **Configurações → Reincidência (janela de 30 dias)**, sem depender de programação:

O **piso de ocorrências** é o mínimo de lotes com o erro para ele poder ser chamado de reincidente. Está em **3** por padrão. Ele existe para evitar que uma ou duas ocorrências, que podem ser acaso, já disparem um alerta forte.

A **incidência mínima** é o percentual sobre os lotes do período a partir do qual o erro é considerado relevante. Está em **3%** por padrão. Subir esse número deixa a análise mais exigente (menos alertas); baixar deixa mais sensível.

O **fator de salto** é quantas vezes acima da base histórica a incidência precisa estar para virar "em alta". Está em **3×** por padrão. É o que governa a detecção de tendência emergente.

Esses defaults foram calibrados para um volume de 100 a 300 OPs por mês. Se o volume mudar bastante, faz sentido revisitá-los.

## Exemplos práticos de cada nível

Os exemplos abaixo usam dados fictícios, considerando um período (por exemplo, um mês) em que foram analisados **150 lotes**, e os parâmetros padrão: piso de 3 ocorrências, incidência mínima de 3% e fator de salto de 3×.

**Pontual.** Numa análise, o agente não conseguiu detectar a data de conciliação de um lote do Insuflador de CO₂. No período, esse erro apareceu em **1 lote** (incidência de 1÷150 ≈ 0,7%) e, historicamente, é algo raro. Como a contagem está abaixo do piso (1 < 3) e a incidência abaixo do mínimo (0,7% < 3%), a chave "Data · Insuflador de CO₂" fica como **pontual**: é um caso isolado, resolvido com a correção imediata daquele documento, sem necessidade de abrir análise de causa raiz.

**Reincidente.** A cronologia incoerente de estágios no Insuflador de CO₂ é um problema que já vem acontecendo há meses; a base histórica dessa chave gira em torno de 3,5%. Neste período, ela apareceu em **6 lotes** (incidência de 6÷150 = 4%). Como bateu o piso (6 ≥ 3) e a incidência ficou acima do mínimo (4% ≥ 3%), a chave "Cronologia incoerente · Insuflador de CO₂" é marcada como **reincidente**. Aqui a mensagem é clara: não é acaso, é um problema recorrente e relevante — o certo é tratar a causa raiz e definir uma ação corretiva, não só corrigir lote a lote.

**Tendência emergente (em alta).** O número de série da Cabeça de Câmera CM-SCAM, na Microcâmera CM, praticamente nunca deu problema — a base histórica é de cerca de 0,3% (quase zero). Neste período, ele apareceu em **4 lotes** (incidência de 4÷150 ≈ 2,7%). Repare que a contagem é modesta e a incidência ficou até abaixo do mínimo de 3% — então **não** é reincidente. Mas 2,7% é cerca de **9× a base histórica** de 0,3%, muito acima do fator de 3×, então a chave "Nº de série · Microcâmera CM · Cabeça de Câmera CM-SCAM (IPM0023)" é marcada como **em alta**. É o alerta precoce: algo mudou naquele ponto específico (provavelmente na gravação do número de série desse acessório) e vale investigar agora, antes que o problema cresça e vire reincidente nos próximos meses.

Em resumo: o **pontual** é o caso isolado; o **reincidente** é o problema conhecido que se repete com volume; e o **em alta** é o problema novo que dispara em relação ao que era normal — cada um pede uma resposta diferente.

## Minha opinião sobre os parâmetros, dado o volume e o histórico

Considerando o volume atual de 100 a 300 OPs por mês, os defaults (piso 3, incidência 3%, fator 3×) são um ponto de partida equilibrado, mas cabe uma ressalva importante sobre o histórico. Segue meu raciocínio para cada número.

Sobre o **piso de 3 ocorrências**: num mês típico esse piso é sensato — três lotes com o mesmo erro dificilmente são acaso. O ponto de atenção é o extremo de baixo do seu volume: se num mês você analisar perto de 100 lotes e usar um recorte curto (uma semana, por exemplo), 3 ocorrências podem demorar a acumular e um problema real pode ficar "escondido" como pontual por um tempo. Se você sentir que recorrências reais estão passando, baixar o piso para 2 ajuda — ao custo de um pouco mais de ruído. No extremo de cima (perto de 300/mês), manter 3, ou até subir para 4, evita excesso de alertas.

Sobre a **incidência mínima de 3%**: em 150 lotes, 3% equivale a cerca de 4 a 5 lotes, o que combina bem com o piso de 3 e faz o "reincidente" exigir um padrão de verdade. Acho 3% adequado para o seu volume. Se a meta for ser mais conservador (menos alertas, focar só no que é grande), 4–5% faz sentido; se a intenção for pegar recorrências menores mais cedo, 2% deixa mais sensível. Eu começaria em 3% e só mexeria depois de observar alguns meses.

Sobre o **fator de salto de 3×** (o que define "em alta"): esse é o parâmetro mais valioso para o seu caso, porque é ele que captura o "nunca deu problema e começou a dar". 3× é um bom equilíbrio. Mas aqui entra a ressalva central: **a qualidade do "em alta" depende de você ter histórico suficiente**. A base é calculada nos 12 meses anteriores, e a plataforma é recente — então, enquanto você não tiver perto de um ano de dados acumulados, a base histórica de cada chave é pequena e instável, e o "em alta" vai oscilar mais (às vezes disparando por pouca coisa, às vezes deixando passar). Isso não é defeito da regra; é falta de lastro histórico, que se resolve sozinho com o tempo.

Minha recomendação prática, então, é a seguinte. Nos **primeiros meses**, enquanto o histórico ainda é curto, dê mais peso ao **reincidente** (piso + incidência, que dependem só do período atual e são estáveis) e trate o **em alta** como um radar a ser confirmado — não como veredito. Mantenha os defaults (3, 3%, 3×) e resista à tentação de calibrar fino cedo demais, porque com pouco dado qualquer ajuste é baseado em ruído. Depois de acumular uns **6 a 12 meses**, revise: olhe no painel quantas chaves caem em cada nível por mês e ajuste — se estiver alertando demais, suba o piso ou a incidência; se estiver deixando passar recorrências que você reconhece na prática, baixe a incidência para 2%. E, para a decisão formal de causa raiz e ação corretiva, prefira confirmar a tendência num recorte maior (trimestral) antes de fechar a ação, usando o mês como radar operacional.

Por fim, dois parâmetros hoje fixos no código que, dado o seu contexto, podem valer a pena tornar ajustáveis mais adiante: o tamanho da **base histórica** (hoje 12 meses — enquanto o sistema é novo, uma base de 3–6 meses talvez seja mais realista) e a **janela do alerta do Slack** (hoje 30 dias). Se quiser, deixo os dois configuráveis também.

## Duas observações importantes sobre onde a regra é aplicada

O **painel do Dashboard** usa exatamente o período que você escolhe nos campos De/Até, e compara com os 12 meses anteriores a esse início. É a visão para análise e decisão, onde você controla o recorte.

O **alerta de NC no Slack**, que aparece na tela de análise, usa a mesma ideia de chave e os mesmos três níveis e limiares, mas com uma janela fixa dos **últimos 30 dias** (comparada com os cerca de 12 meses anteriores a esses 30 dias), porque ali o objetivo é classificar o problema no instante em que ele acontece, não navegar por períodos. É por isso que o badge no Slack e a lista do Dashboard podem, ocasionalmente, divergir: são recortes de tempo diferentes para propósitos diferentes.

## O que você pode querer mudar

Pontos naturais de ajuste, se algo não estiver do seu gosto: os três limiares (piso, incidência mínima, fator de salto), que já são editáveis; a janela do alerta do Slack (hoje 30 dias fixos) e o tamanho da base histórica (hoje 12 meses), que hoje são fixos no código; a granularidade da chave (hoje categoria + equipamento + alvo); e a regra da "tendência" das correções (hoje a comparação simples de metades com o limite de 15%). Qualquer um desses pode ser alterado — é só me dizer qual e como você prefere.
