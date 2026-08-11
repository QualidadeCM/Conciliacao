# Como configurar o alerta do Slack

Guia passo a passo da integração de alertas com o Slack usada na plataforma de
conciliação. Data: 22/07/2026.

## Como funciona (visão geral)

A integração usa um **Incoming Webhook** do Slack — o jeito mais simples e seguro
de um sistema *postar* mensagens em um canal (sem ler nada, sem login de usuário).

O fluxo é:

```
Plataforma (navegador)
      │  POST /notificar-slack  { texto }
      ▼
Serviço local  (conversor-pdf-local, Node/PM2)
      │  POST { text }  →  SLACK_WEBHOOK_URL   (lida do .env)
      ▼
Slack  →  posta no canal configurado no webhook
```

Pontos importantes:

- A URL do webhook fica **só no `.env` do serviço** — nunca na `plataforma.html`,
  nunca no Git. Quem tem a URL consegue postar no canal, então ela é um segredo.
- O serviço já tem o endpoint `POST /notificar-slack` pronto (arquivo `server.js`).
  Você só precisa **criar o webhook no Slack e colar a URL no `.env`**.
- Cada webhook aponta para **um canal fixo**. Para postar em outro canal, cria-se
  outro webhook.

## Passo 1 — Criar o app (o "robô") no Slack

1. Acesse `https://api.slack.com/apps` logado na conta do workspace da empresa.
2. Clique em **Create New App** → **From scratch**.
3. Dê um nome (ex.: `Conciliação — Alertas`) e escolha o **workspace** da empresa.
4. Clique em **Create App**.

> Observação: criar app costuma exigir permissão de administrador do workspace.
> Se você não for admin, peça para o admin criar (ou liberar a criação de apps).

## Passo 2 — Ativar o Incoming Webhook e gerar a URL

1. Dentro do app recém-criado, no menu lateral, abra **Incoming Webhooks**.
2. Ligue a chave **Activate Incoming Webhooks** (On).
3. Role até o fim e clique em **Add New Webhook to Workspace**.
4. Escolha o **canal** onde os alertas devem cair (ex.: `#qualidade-alertas`) e
   confirme em **Allow**.
5. O Slack gera uma **Webhook URL** parecida com
   `https://hooks.slack.com/services/<ID-DO-WORKSPACE>/<ID-DO-APP>/<TOKEN-SECRETO>`
   (três partes separadas por barra, sendo a última um token secreto).

6. Clique em **Copy** para copiar essa URL. É ela que vai no `.env`.
   Nunca cole a URL real em documentos versionados no Git — ela é um segredo.

## Passo 3 — Colocar as URLs no `.env` do serviço

> Atualização 22/07/2026: os alertas de NC agora vão para **canais distintos por
> setor responsável** — PCP → canal `pcp_gq`; Almoxarifado → canal `almoxarifado_gq`.
> Cada canal tem seu **próprio Incoming Webhook** (repita os Passos 1–2 escolhendo
> o canal certo e gere uma URL para cada um).

1. No servidor, abra o arquivo `.env` da pasta do serviço:
   `C:\conversor-pdf-local\.env`
2. Adicione (ou atualize) as linhas, uma por canal:

   ```
   SLACK_WEBHOOK_PCP=<URL-do-webhook-do-canal-pcp_gq>
   SLACK_WEBHOOK_ALMOXARIFADO=<URL-do-webhook-do-canal-almoxarifado_gq>
   ```

   Opcional (fallback geral, usado se um canal específico não estiver definido):

   ```
   SLACK_WEBHOOK_URL=<URL-do-webhook-geral>
   ```

3. Salve o arquivo.

Como funciona o roteamento: a plataforma classifica cada NC por setor (rotulagem/
dados cadastrais → Almoxarifado; processo/produção → PCP) e envia **uma mensagem
por canal** com apenas as NCs daquele setor. O serviço escolhe o webhook pelo campo
`canal` (`pcp` / `almoxarifado`) recebido da plataforma.

> Garanta que `.env`, `.env.*` e afins estão no `.gitignore` (já estão no projeto),
> para a URL nunca ir para o Git.

## Passo 3.1 — Marcar quem executou o estágio responsável (opcional)

A mensagem de cada NC pode marcar automaticamente **quem executou, naquela OP
específica**, o estágio ligado ao problema — não é uma lista fixa de pessoas nem
uma escolha solta: é resolvido a cada análise, a partir da própria OP.

- Problema de **etiqueta** (Almoxarifado) → menciona quem executou o
  **Estágio 50 — Embalagem** nessa OP.
- Problema na **OP** (PCP) → menciona quem executou o
  **Estágio 60 — Conciliação da Produção** nessa OP.

Para isso funcionar, cadastre o Slack ID do colaborador uma vez:

1. Pegue o **ID de membro** dele no Slack: clique no nome/foto da pessoa →
   **⋯ (mais opções)** → **Copiar ID do membro**. Formato `U0123456789` — não é
   o `@nomedeusuario`.
2. Em Configurações → Operadores → "Todos os colaboradores", cadastre (ou edite)
   o colaborador e preencha o campo **Slack ID**. Se ele ainda não estiver na
   lista, use "Adicionar colaborador" (nome + código/matrícula + Slack ID).
   O código/matrícula é o mesmo número que aparece na cronologia da OP — é por
   ele que a plataforma casa "quem embalou/conciliou esta OP" com o cadastro.
3. Na caixa "Enviar ao Slack", a plataforma já identifica automaticamente quem
   executou o estágio naquela OP e mostra um checkbox "Marcar Fulano — executou
   o Estágio 50/60 nesta OP", ligado por padrão quando há Slack ID cadastrado.
   Desmarque se não quiser mencionar naquele envio.

Se o colaborador daquela OP ainda não tiver Slack ID cadastrado, a mensagem sai
normalmente, só sem a menção (com um aviso na caixa de envio).

Nenhuma configuração de `.env` é necessária para isso — fica tudo no cadastro de
Operadores da plataforma.

## Passo 4 — Reiniciar o serviço

O serviço só lê o `.env` ao iniciar. No prompt do servidor:

```
pm2 restart conversor-pdf
```

(Se o nome do processo for outro, veja com `pm2 list`.)

## Passo 5 — Testar

Opção A — pela plataforma: gere/abra uma análise com não conformidade e use o
botão de enviar alerta ao Slack (ou, na aba Tendência e reincidência, o botão
**Alertar**). A mensagem deve aparecer no canal escolhido.

Opção B — teste direto do endpoint (no servidor), para isolar problema:

```
curl -X POST http://localhost:80/notificar-slack ^
  -H "Content-Type: application/json" ^
  -d "{\"texto\":\"Teste de alerta da plataforma de conciliacao\"}"
```

Resposta esperada: `{"ok":true}` e a mensagem no canal.

## Solução de problemas

- **"SLACK_WEBHOOK_URL nao configurado no .env do servico."**
  A variável não foi lida — confira o `.env` e se o serviço foi reiniciado.

- **"fetch failed" / erro de certificado (rede corporativa)**
  A rede da empresa usa inspeção SSL (proxy que reassina os certificados), e o
  Node não confia no certificado interno. Aponte o Node para o certificado da CA
  corporativa no `.env` do serviço:

  ```
  NODE_EXTRA_CA_CERTS=C:\caminho\para\ca-corporativa.crt
  ```

  e reinicie (`pm2 restart conversor-pdf`). Peça o arquivo do certificado ao TI.

- **"Slack respondeu 404 / no_service"**
  A URL do webhook está errada, foi revogada ou o app foi removido. Gere um novo
  webhook (Passo 2) e atualize o `.env`.

- **Postar em outro canal**
  Crie um novo Incoming Webhook apontando para o canal desejado (Passo 2) e troque
  a URL no `.env`. Um webhook = um canal.

- **A menção aparece como texto cru (`<@U0123456789>`) em vez de marcar a pessoa**
  Confira se cadastrou o **ID do membro** (formato `U...`), não o `@nomedeusuario`
  nem o nome de exibição — só o ID faz o Slack converter em menção real.

- **A caixa de envio diz que não identificou quem executou o estágio**
  A OP não trouxe uma linha de operação para o Estágio 50/60 com o formato
  esperado, ou o colaborador daquela linha ainda não está cadastrado em
  Operadores (por nome, já que sem código a plataforma casa por nome
  normalizado). Cadastre-o ou confira o texto extraído da OP.

## Segurança e boas práticas

- A Webhook URL é um **segredo**: só no `.env` do servidor, fora do Git e do
  navegador.
- Se a URL vazar, **revogue** o webhook no painel do app (`api.slack.com/apps` →
  seu app → Incoming Webhooks → remover) e gere um novo.
- O webhook só **envia** mensagens — não lê o canal nem dá acesso a dados do Slack.
- Mensagens usam formatação *mrkdwn* do Slack (ex.: `*negrito*`, `:repeat:` para
  emoji). O texto é montado na plataforma e enviado no campo `texto`.

## Onde isso está no código

- Serviço: `conversor-pdf-local/server.js` → endpoint `POST /notificar-slack`
  (lê `SLACK_WEBHOOK_URL`/`SLACK_WEBHOOK_PCP`/`SLACK_WEBHOOK_ALMOXARIFADO` e
  repassa `{ text }` ao Slack, sem lógica de menção — isso fica na plataforma).
- Migration `migration-operadores-slack-id.sql`: coluna `slack_user_id` na
  tabela `operadores`.
- Plataforma: `parseOP` extrai quem executou cada operação/estágio da OP
  (`operador_id`/`operador_nome`, expostos em `parecer.cronologia`); em
  `abrirAlertaSlack`, resolve o executor do Estágio 50 e do Estágio 60 desta OP
  e casa com o cadastro de Operadores (por código, com fallback por nome) para
  achar o Slack ID; a caixa "Enviar ao Slack" mostra o checkbox de menção por
  setor, e `confirmarEnvioSlack` monta `<@ID>` no início do texto daquele setor
  antes de chamar `${base}/notificar-slack` com `{ texto, canal }`.
