# Guia — Conectar o agente Gemini Flash

Você vai fazer 3 movimentos para a plataforma analisar lotes de verdade. Tempo total: **~10 minutos**.

---

## Movimento 1 — Pegar a API key do Google AI Studio (2 min)

1. Acesse: **https://aistudio.google.com/apikey**
2. Faça login com a conta Google (recomendo a `qualidade@confiancemedical.com.br` ou outra corporativa)
3. Clique em **"Create API key"** (botão azul no topo direito)
4. Vai aparecer uma janela: **"Create API key in new project"** (escolha essa opção; "new project" é só uma divisão organizacional do Google, sem custo)
5. Em segundos vai aparecer sua chave: algo como `AIzaSyB...` (39 caracteres)
6. Clique no botão **"Copy"** e guarde em local seguro temporariamente (Bloco de Notas vazio, gerenciador de senhas — **não cole em mensagens públicas**)

**Nota:** o Gemini API tem tier gratuito generoso (1.500 análises por dia para o Flash). Você não precisa cadastrar cartão de crédito.

---

## Movimento 2 — Deployar a Edge Function no Supabase (5 min)

A Edge Function é a peça que fica entre o navegador (plataforma) e o Gemini. Ela é escrita em TypeScript, mas você não precisa programar nada — só copiar e colar.

### 2.1 Adicionar a API key como secret no Supabase

1. No painel do Supabase, sidebar esquerda, clique em **Settings** (engrenagem no rodapé)
2. Clique em **Edge Functions** no submenu
3. Vá em **Manage secrets** (ou **Secrets**, depende da versão)
4. Clique em **Add new secret**:
   - **Name:** `GEMINI_API_KEY`
   - **Value:** cole a chave que copiou no Movimento 1
5. Clique em **Save**

### 2.2 Criar a Edge Function

1. No Supabase, sidebar esquerda, clique no ícone de **Edge Functions** (parece um relâmpago ⚡)
2. Clique em **Deploy a new function** ou **Create a new function**
3. Em **Function name** digite exatamente: `analisar-conciliacao`
4. Vai abrir um editor de código com um exemplo `Hello World`
5. **Apague todo o conteúdo** do editor
6. Abra o arquivo `edge-function/analisar-conciliacao.ts` que está na pasta do projeto:
   - No Explorador de Arquivos, navegue até `Verificação da Conciliação da OP (Agente IA)\edge-function\`
   - Clique direito em `analisar-conciliacao.ts` → **Abrir com** → **Bloco de Notas**
7. **Selecione tudo** (`Ctrl + A`), **copie** (`Ctrl + C`)
8. Volte ao editor do Supabase, clique dentro do editor vazio e **cole** (`Ctrl + V`)
9. Clique em **Deploy function** (botão azul/verde no canto)
10. Espere uns 30 segundos. Vai aparecer **"Function deployed successfully"** ou similar
11. **Anote a URL da função.** Ela é algo como: `https://riqzwwbprdnjxodicxce.supabase.co/functions/v1/analisar-conciliacao`. Você verá essa URL na lista de funções

### 2.3 Conferir que a função está pública para usuários autenticados

Por padrão, Edge Functions exigem o JWT do usuário (que vem do login). Isso já está configurado no código que te passei. Você não precisa mudar nada.

---

## Movimento 3 — Atualizar o `plataforma.html` (eu já vou fazer)

Vou ajustar o HTML para:

1. Quando você clicar em **"Analisar lote"**, ele envia os textos extraídos para a sua Edge Function
2. Mostra um indicador de carregamento (a análise pode demorar 15-60 segundos)
3. Quando o Gemini responder, exibe o parecer estruturado na tela
4. Salva tudo no Supabase (já feito pela Edge Function)
5. Mostra um botão para abrir o relatório completo

A URL da Edge Function não precisa ser configurada à mão — o HTML monta automaticamente a partir da `SUPABASE_URL` que você já configurou.

---

## Como saber que está tudo certo

Depois dos 3 movimentos:

1. Recarregue o `plataforma.html` (F5)
2. Vá em **Análise**
3. Sobe os 4 documentos obrigatórios do lote 6819 que está na pasta do projeto
4. Clica em **"Analisar lote"**
5. Aparece um spinner por 15-60 segundos
6. Quando termina, mostra um cartão grande com o parecer (Conforme/Ressalvas/Não Conforme) + apontamentos
7. A análise aparece automaticamente na aba **Histórico** e os contadores do **Dashboard** atualizam

Se algo der erro, abra o Console do navegador (`F12`) e me manda o print da mensagem.

---

## Problemas comuns

**"Authorization header faltando"**
→ Você não está logada. Saia e entre de novo na plataforma.

**"Documentos obrigatórios faltando"**
→ Falta extrair algum dos 4 arquivos. Verifique se os 4 estão verdes (status "pronto").

**"Gemini API erro: ..."**
→ Sua chave Gemini pode estar inválida ou expirada. Vá em Google AI Studio → API keys e cria de novo. Atualiza o secret `GEMINI_API_KEY` no Supabase.

**"Resposta do Gemini não é JSON válido"**
→ O modelo retornou algo fora do formato. Esse é o tipo de instabilidade que justifica o fallback para Claude. Se acontecer com frequência, me avisa.

**Análise demora mais de 2 minutos**
→ Provavelmente algum documento ficou muito grande. Edge Functions do Supabase têm timeout de 25 segundos no plano gratuito, 150s no Pro. Se acontecer, podemos otimizar (reduzir tamanho do prompt) ou estender o timeout via plano.

**Erro 500 com mensagem genérica**
→ Provavelmente é a service role key. Verifica nas Edge Functions logs do Supabase (Logs → Edge Functions na sidebar). Manda print do erro completo.
