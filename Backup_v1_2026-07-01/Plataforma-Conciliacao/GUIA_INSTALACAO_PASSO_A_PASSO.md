# Guia de Instalação — Passo a Passo

Guia para colocar a Plataforma de Conciliação da Produção rodando no seu computador, do zero, sem precisar de conhecimento técnico em programação. Tempo estimado: **30 a 45 minutos**, sendo a maior parte do tempo o computador trabalhando enquanto você espera.

---

## Visão geral do que você vai fazer

1. Instalar o Node.js (se ainda não tem)
2. Abrir o terminal na pasta do projeto
3. Rodar `npm install` (computador baixa as dependências)
4. Criar uma conta gratuita no Supabase
5. Executar o `schema.sql` no Supabase (cria as tabelas)
6. Executar o `seed-cm-led.sql` no Supabase (carrega os dados iniciais)
7. Copiar as credenciais do Supabase
8. Criar o usuário `qualidade@confiancemedical.com.br` no Supabase
9. Criar o arquivo `.env.local` com as credenciais
10. Rodar `npm run dev` e abrir a plataforma no navegador

---

## Passo 1 — Verificar/Instalar o Node.js

O Node.js é o programa que faz o React rodar no seu computador. Sem ele, nada funciona.

### 1.1 Verificar se já está instalado

1. Aperte `Windows + R` no teclado
2. Digite `cmd` e aperte Enter (abre o Prompt de Comando)
3. Na janela preta que abrir, digite:
   ```
   node --version
   ```
4. Aperte Enter.

**Se aparecer algo como `v20.10.0` (ou qualquer número 18 ou maior):** já está instalado, pode pular para o Passo 2.

**Se aparecer "node não é reconhecido" ou versão menor que 18:** precisa instalar/atualizar.

### 1.2 Instalar o Node.js

1. Abra o navegador e vá em: **https://nodejs.org/pt-br/download**
2. Clique no botão grande do meio: **"LTS"** (versão recomendada, mais estável)
3. Vai baixar um arquivo `node-vXX.X.X-x64.msi`
4. Dê duplo clique no arquivo baixado
5. Vai abrir um assistente de instalação. Clique em **"Next"** em todas as telas, aceite os termos, e em **"Install"** no final
6. Pode aparecer uma janela do Windows pedindo permissão de administrador — clique em **Sim**
7. Quando terminar, clique em **"Finish"**

### 1.3 Confirmar a instalação

1. **Feche** o Prompt de Comando se estiver aberto (importante, ele precisa ser reaberto pra reconhecer o Node)
2. Aperte `Windows + R` novamente, digite `cmd` e Enter
3. Digite `node --version` e Enter — deve aparecer algo como `v20.10.0`
4. Digite `npm --version` e Enter — deve aparecer algo como `10.2.3`

Pronto, Node.js instalado.

---

## Passo 2 — Abrir o terminal na pasta do projeto

Aqui você vai abrir uma janela de terminal **já dentro da pasta certa**, para os comandos rodarem no lugar correto.

### Método mais simples

1. Abra o **Explorador de Arquivos** do Windows (o ícone amarelo de pasta na barra de tarefas)
2. Navegue até a pasta:
   `C:\Users\maria.zaccur\Documents\Claude\Projects\Verificação da Conciliação da OP (Agente IA)\Plataforma-Conciliacao`
3. **Clique uma vez na barra de endereço** (em cima, onde aparece o caminho da pasta)
4. Apague tudo, digite `cmd` e aperte Enter
5. Vai abrir uma janela preta de Prompt de Comando **já dentro da pasta do projeto** — você vai ver o caminho da pasta antes do `>`

Outra forma: clique com o **botão direito do mouse na pasta `Plataforma-Conciliacao`** e procure por algo como "Abrir no Terminal" ou "Open in Terminal" no menu (depende da versão do Windows).

**Mantenha essa janela do terminal aberta** — você vai voltar nela várias vezes.

---

## Passo 3 — Instalar as dependências (npm install)

Esse comando lê o arquivo `package.json` e baixa todas as bibliotecas que a plataforma precisa (React, Tailwind, Supabase client, etc.). Tudo fica numa pasta `node_modules` que vai aparecer dentro do projeto.

1. Na janela do terminal aberta no Passo 2, digite:
   ```
   npm install
   ```
2. Aperte Enter.
3. Vai aparecer um monte de texto descendo na tela, com palavras como `added`, `WARN`, `deprecated`. **Isso é normal.** Os avisos `WARN` não impedem o funcionamento.
4. Espere o comando terminar. Demora entre **1 e 3 minutos** dependendo da sua internet.
5. Quando terminar, você verá o terminal de volta no estado de "esperando comando" (o `>` piscando no final).
6. Para confirmar que deu certo, no Explorador de Arquivos, vai aparecer uma nova pasta `node_modules` dentro de `Plataforma-Conciliacao` (com **muitos** subarquivos — pode ser pesada, ~300 MB).

**Se aparecer erro vermelho:** copie o texto do erro e me manda, eu te ajudo a resolver. Os erros mais comuns são de permissão (rodar como administrador resolve) ou de proxy/firewall (geralmente em redes corporativas).

---

## Passo 4 — Criar conta no Supabase

O Supabase é onde os dados da plataforma vão ficar armazenados: tabelas de produtos, fichas mestres, análises feitas, arquivos enviados. **É gratuito** para o nosso volume de uso.

1. Abra o navegador e vá em: **https://supabase.com**
2. Clique em **"Start your project"** (canto superior direito)
3. Vai pedir para se cadastrar. Escolha **"Continue with GitHub"** ou **"Continue with Google"** ou crie uma conta com email. **Recomendo Google** se você tem uma conta corporativa, é o mais rápido
4. Faça o cadastro/login normalmente
5. Quando entrar no painel, você vai ver uma tela inicial pedindo para criar uma **organização**. Pode chamar de "Confiance Medical" mesmo. Tipo: **Personal** (free)
6. Depois de criar a organização, clique em **"New Project"**
7. Preencha:
   - **Project name:** `conciliacao-confiance`
   - **Database Password:** clique em "Generate a password" para criar uma forte. **COPIE essa senha e salve em algum lugar seguro** (gerenciador de senhas, anotação confidencial). Você não vai usar essa senha no dia a dia, mas pode precisar dela um dia para administração avançada
   - **Region:** escolha **"South America (São Paulo)"** — fica mais rápido no Brasil
   - **Pricing Plan:** Free
8. Clique em **"Create new project"**
9. O Supabase vai levar **1 a 2 minutos** provisionando o banco de dados. Espere terminar (a tela vai mudar sozinha).

---

## Passo 5 — Executar o schema.sql

Aqui você vai criar todas as tabelas, enums e configurações de segurança da plataforma no Supabase.

1. No painel do Supabase, na barra lateral esquerda, clique no ícone que parece um banco de dados com a sigla **"SQL"** (chama-se **SQL Editor**). Costuma ser o 4º ou 5º ícone de cima
2. Clique em **"New query"** (botão verde ou roxo, depende da versão)
3. Vai abrir um editor de texto grande, vazio
4. Agora abra o arquivo `schema.sql` que está em `Plataforma-Conciliacao/supabase/schema.sql`:
   - No Explorador de Arquivos do Windows, vá até a pasta `Plataforma-Conciliacao/supabase/`
   - Clique com o botão direito em `schema.sql` → **Abrir com** → **Bloco de Notas** (ou VS Code se tiver)
5. **Selecione tudo** (`Ctrl + A`) e **copie** (`Ctrl + C`)
6. Volte para o navegador do Supabase, clique dentro do editor SQL e **cole** (`Ctrl + V`)
7. Clique no botão **"Run"** no canto inferior direito (ou aperte `Ctrl + Enter`)
8. Espere alguns segundos. No final, deve aparecer uma mensagem verde tipo **"Success. No rows returned"** ou um resumo dos comandos executados
9. **Se aparecer erro em vermelho:** geralmente é porque o script já foi rodado antes. O script é "idempotente" (pode rodar várias vezes), mas se quiser começar do zero, peça pra Supabase Support ou rode `drop schema public cascade; create schema public;` antes (cuidado: isso apaga tudo)

---

## Passo 6 — Executar o seed-cm-led.sql

Esse script popula o banco com o catálogo completo do FORM-GQ-0085 (19 produtos) e a Ficha Mestre completa do CM-LED como modelo de referência. Sem isso, a plataforma fica vazia.

1. No Supabase, ainda no SQL Editor, clique novamente em **"New query"**
2. Abra o arquivo `seed-cm-led.sql` no Bloco de Notas (`Plataforma-Conciliacao/supabase/seed-cm-led.sql`)
3. Selecione tudo (`Ctrl + A`), copie (`Ctrl + C`)
4. Cole no editor SQL do Supabase (`Ctrl + V`)
5. Clique em **"Run"**
6. Espere alguns segundos. Deve aparecer "Success"
7. **Para conferir se deu certo:** na barra lateral, clique no ícone de **Table Editor** (parece uma tabela). Você vai ver as tabelas listadas (`produtos`, `fichas_mestres`, etc). Clique em `produtos` — deve mostrar 19 linhas. Clique em `fichas_mestres` — deve ter 1 linha (a do CM-LED)

---

## Passo 7 — Copiar as credenciais do Supabase

A plataforma precisa de duas coisas para conversar com o Supabase: a URL do projeto e uma chave de acesso pública (anon key).

1. No painel do Supabase, na barra lateral esquerda, clique no ícone de engrenagem **(Settings)** no rodapé
2. No submenu que abrir, clique em **"API"**
3. Vai aparecer uma página com várias informações. Você precisa de duas:
   - **Project URL** — algo como `https://abcdefghij.supabase.co`. Tem um botão "Copy" do lado, copie
   - **Project API keys → anon public** — uma chave grande começando com `eyJ…`. Tem um botão "Copy", copie

**ATENÇÃO:** existe outra chave chamada **service_role** logo abaixo. **NUNCA use ela no frontend** e nunca compartilhe — ela tem acesso total ao banco e é só para servidor.

4. Cole essas duas informações em um bloco de notas temporário pra usar daqui a pouco

---

## Passo 8 — Criar o usuário no Supabase

1. No Supabase, na barra lateral, clique no ícone **"Authentication"** (parece um cadeado ou pessoa)
2. Vá em **"Users"** no submenu
3. Clique no botão **"Add user"** → **"Create new user"**
4. Preencha:
   - **Email:** `qualidade@confiancemedical.com.br`
   - **Password:** escolha uma senha forte (essa será a senha de login na plataforma)
   - Marque a opção **"Auto Confirm User"** (assim você não precisa confirmar por email)
5. Clique em **"Create user"**
6. O usuário aparece na listagem. Anote a senha em local seguro

---

## Passo 9 — Criar o arquivo .env.local

Esse arquivo guarda as credenciais do Supabase localmente no seu computador. Ele **não** é versionado/compartilhado.

1. No Explorador de Arquivos, vá até `Plataforma-Conciliacao/`
2. Procure o arquivo `.env.example` — abra com Bloco de Notas (clique com botão direito → Abrir com → Bloco de Notas)
3. No Bloco de Notas, vá em **Arquivo → Salvar como…**
4. Mude o nome do arquivo de `.env.example` para `.env.local`
   - **Importante:** no campo "Tipo", escolha **"Todos os arquivos (*.*)"** senão o Windows adiciona `.txt` no final
   - **Salve na mesma pasta `Plataforma-Conciliacao`**
5. Agora você tem o arquivo `.env.local` (idêntico ao `.env.example` no momento). Edite o conteúdo:

   ```
   VITE_SUPABASE_URL=https://abcdefghij.supabase.co
   VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```

   Substitua os valores depois do `=` pelos que você copiou no Passo 7.
6. **Salve** o arquivo (`Ctrl + S`)
7. Feche o Bloco de Notas

**Verificar se o arquivo foi salvo certo:** no Explorador de Arquivos, o arquivo deve aparecer como `.env.local` (não `.env.local.txt`). Se aparecer com `.txt`, renomeie tirando o `.txt`.

> Dica: por padrão o Windows esconde as extensões de arquivo. Se quiser ver, no Explorador de Arquivos vá em **Exibir → Mostrar → Extensões de nome de arquivo**.

---

## Passo 10 — Rodar a plataforma

Pronto, tudo configurado. Hora de iniciar:

1. Volte na **janela do terminal** que você abriu no Passo 2 (ou abra de novo na pasta `Plataforma-Conciliacao` se fechou — veja Passo 2)
2. Digite:
   ```
   npm run dev
   ```
3. Aperte Enter
4. Vai aparecer um texto verde dizendo:
   ```
   VITE v5.x.x  ready in XXX ms
   ➜  Local:   http://localhost:5173/
   ➜  Network: ...
   ```
5. O navegador deve **abrir sozinho** na plataforma (porque configuramos isso no Vite). Se não abrir, abra qualquer navegador (Chrome, Edge) e digite na barra de endereço: **`http://localhost:5173`**
6. Você vai ver a plataforma com a sidebar Navy à esquerda e a tela de Dashboard à direita

**Para parar a plataforma:** volte no terminal e aperte `Ctrl + C`. O servidor para. Para rodar de novo, é só dar `npm run dev` outra vez.

**Para rodar nos próximos dias:** abre o terminal na pasta, dá `npm run dev`. Só isso. Os passos 1-9 só fazem uma vez.

---

## Solução de problemas comuns

**`'node' não é reconhecido como comando interno ou externo`**
→ Node.js não está instalado ou não está no PATH. Reinstale pelo Passo 1.

**`npm install` trava ou dá erro de rede**
→ Está numa rede corporativa com proxy? Tente em casa, ou peça pro TI liberar o acesso a `registry.npmjs.org`.

**`npm install` reclama de permissão (`EPERM`)**
→ Feche o terminal e abra como administrador (botão direito → Executar como administrador), tente de novo.

**O navegador abre mas a página fica em branco**
→ Abra o **Console do navegador** (`F12` → aba **Console**). Geralmente é por causa de `.env.local` faltando ou com credenciais erradas. Verifique o Passo 9.

**Erro "supabase URL not configured" no console**
→ Confira se o arquivo `.env.local` está dentro da pasta `Plataforma-Conciliacao` (no mesmo lugar do `package.json`) e se o nome está **exato** (sem `.txt` no final, com o ponto no começo).

**`port 5173 already in use`**
→ Você já tem outra coisa rodando na porta. Feche tudo, mate o processo (Ctrl+C em terminais abertos) e tente de novo. Ou edite `vite.config.ts` mudando `port: 5173` para outro número (`port: 5174`).

**Esqueci a senha do banco do Supabase (Passo 4)**
→ Tudo bem, dá pra resetar nas configurações do projeto. Mas a chave anon que você usa no dia a dia continua a mesma.

**Esqueci a senha do usuário `qualidade@confiancemedical.com.br`**
→ Vai em **Authentication → Users** no Supabase, clica nos três pontinhos do usuário → **Reset password** ou **Send password recovery**.

---

## O que esperar de funcionalidade nesta fase

Você vai ver a plataforma com:

- Sidebar Navy à esquerda com 4 itens (Dashboard, Análise, Histórico, Cadastro)
- Toggle de modo claro/escuro no rodapé da sidebar
- Email `qualidade@confiancemedical.com.br` exibido no rodapé
- Cada um dos 4 itens leva a uma tela com estrutura já desenhada mas **funcionalidade interna ainda não implementada** (vamos fazer nas Fases 2 a 5)
- O design system Confiance está completamente aplicado (Navy/Cyan/Turquoise, Montserrat/Raleway, dark mode)

Se algo parecer estranho, tire um print da tela e me manda — eu identifico o que ajustar.
