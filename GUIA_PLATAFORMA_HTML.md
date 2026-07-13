# Guia rápido — plataforma.html

Versão single-file da plataforma. Roda direto no navegador, sem instalações.

## Passo 1 — Preencher as credenciais do Supabase

1. No Explorador de Arquivos, abra `plataforma.html` no **Bloco de Notas** (clique direito → Abrir com → Bloco de Notas)
2. Aperte `Ctrl + F` (localizar) e digite `SEU_PROJETO`
3. Você vai cair nestas duas linhas no início do bloco de script:
   ```
   const SUPABASE_URL = 'https://SEU_PROJETO.supabase.co';
   const SUPABASE_ANON_KEY = 'SUA_ANON_KEY_AQUI';
   ```
4. Substitua:
   - `'https://SEU_PROJETO.supabase.co'` → cole sua **Project URL** (Supabase → Settings → API)
   - `'SUA_ANON_KEY_AQUI'` → cole sua **anon public key** (mesmo lugar)
5. Mantenha as **aspas simples** ao redor de cada valor
6. `Ctrl + S` para salvar
7. Feche o Bloco de Notas

## Passo 2 — Abrir a plataforma

1. No Explorador de Arquivos, dê **duplo clique** em `plataforma.html`
2. Vai abrir no seu navegador padrão
3. Se não abrir no Chrome/Edge, clique com o botão direito → **Abrir com** → escolha Chrome ou Edge (evite Internet Explorer)
4. A primeira carga demora uns 3-5 segundos enquanto carrega React e compila o JSX. Tela de "Carregando plataforma…" enquanto isso

## Passo 3 — Login

1. Vai aparecer a tela de login com email preenchido `qualidade@confiancemedical.com.br`
2. Digite a senha que você definiu quando criou o usuário no Supabase
3. Clica em **Entrar**
4. Se der erro "Email ou senha incorretos", confira no Supabase → Authentication → Users se o usuário existe e se a senha está correta

## Passo 4 — Explorar

Você vai entrar na plataforma com:

- **Dashboard** — visão geral das análises (vazio até você fazer a primeira)
- **Análise** — tela de upload dos 4 documentos obrigatórios + opcionais. O botão "Analisar" mostra um aviso de que o agente real será conectado via Supabase Edge Function (próxima fase)
- **Histórico** — lista vazia até a primeira análise
- **Cadastro** — duas abas:
  - **Catálogo de Produtos** — CRUD completo. Você já vai ver os 19 produtos que vieram do seed. Pode criar/editar/excluir
  - **Fichas Mestres** — listagem da Ficha do CM-LED (editor completo virá em seguida)

Toggle de modo claro/escuro no rodapé da sidebar.

## Próximos passos

Quando você confirmar que tudo está funcionando, partimos para:

1. **Editor de Ficha Mestre completo** — para cadastrar fichas de outros produtos (CM-30L, CM-40L, monitores, etc.) dentro da própria plataforma
2. **Supabase Edge Function** com o agente real — chamada à API do Claude usando o protocolo v1.1, com extração de PDF e DOCX server-side
3. **Geração de PDF do relatório**
4. **Dashboard com gráficos** (Recharts)

## Problemas comuns

**"Configuração necessária" aparece direto:**
→ Você não substituiu uma das credenciais. Volte ao Passo 1.

**Tela em branco / nada acontece:**
→ Aperte `F12` no navegador para abrir o Console. Erros aparecem em vermelho. Tire um print e me manda.

**Erro de CORS em chamadas do Supabase:**
→ Em alguns casos, o navegador bloqueia chamadas a partir do protocolo `file://`. Se acontecer, abra um terminal na pasta do projeto e rode:
```
python -m http.server 8000
```
Depois acesse `http://localhost:8000/plataforma.html`. Se você não tem Python, instale o **Five Server** no VS Code (extensão), ou use qualquer servidor estático de sua preferência.

**Login fica girando:**
→ A URL ou anon key do Supabase está errada. Volte ao Passo 1 e confira.

**Não consigo cadastrar/editar produto:**
→ Verifique no Supabase → Authentication → Users se você está logado. Se sim, e mesmo assim falha, verifique no Console do navegador (F12) o erro específico — geralmente é uma policy de RLS bloqueando.
