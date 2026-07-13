# Auditoria — Plataforma de Conciliação × Padrão de Desenvolvimento Confiance

**Data:** 01/07/2026
**Solicitante:** Maria Luiza Zaccur (Garantia da Qualidade)
**Objetivo:** Comparar a plataforma atual com o padrão oficial de desenvolvimento de sistemas da Confiance Medical, identificar gaps críticos, dependências externas e propor um roadmap de migração.

---

## 1. Sumário executivo

A plataforma atual funciona bem e resolve o problema de negócio — mas **não está aderente ao padrão oficial** em pontos estruturais. Não há nada quebrado; há decisões de arquitetura que precisam ser refeitas quando houver janela para migração.

**Aderente ao padrão (poucos itens):**
- Uso de React 18
- Uso de Tailwind CSS
- Componentes com ideia próxima a shadcn/ui (Card, Button, Input, Textarea, Toast) — mas escritos manualmente

**NÃO aderente (a maioria):**
- Stack de build (falta Vite + TypeScript)
- Backend (Supabase em vez de MySQL local + REST próprio)
- Autenticação (Supabase Auth próprio em vez de delegar ao SCM)
- Estrutura de pastas (monolítico em `plataforma.html` em vez de `src/` modular)
- Armazenamento (Supabase Storage em vez de servidor local)
- TypeScript ausente (JavaScript inline com Babel-standalone no browser)

**Custo estimado de migração completa:** 4 a 8 semanas de desenvolvimento dedicado, sem contar validação/testes com a equipe de QG. É uma reescrita, não um refactor.

---

## 2. Comparação item a item

### 2.1 Stack frontend

| Item | Padrão Confiance | Estado atual | Aderente? |
|---|---|---|---|
| Framework | React 18 + TypeScript (TSX) | React 18 sem TS (JS inline) | Parcial |
| Build tool | Vite + `@vitejs/plugin-react-swc` | Nenhum. Babel-standalone em runtime no browser | Não |
| Estilização | Tailwind CSS | Tailwind CDN | Parcial (deveria ser build local) |
| UI | shadcn/ui (Radix UI) | Componentes manuais imitando shadcn | Não |
| Ícones | lucide-react | Ícones inline em SVG (função `Icon`) | Não |
| Roteamento | React Router DOM v6 | State manual (`currentPage`) + `window.location.hash` | Não |
| Estado/dados | TanStack React Query v5 | `useState` + chamadas diretas ao Supabase | Não |
| Formulários | React Hook Form + Zod | JSX controlado manual, validação ad-hoc | Não |
| Gráficos | Recharts | Chart.js via CDN | Parcial |
| Toasts | Sonner + shadcn Toaster | ToastProvider próprio | Não |
| Aliases de import | `@/` → `src/` | Não aplicável (arquivo único) | Não |

**Risco crítico:** o Babel roda em runtime no browser e o arquivo já passou de 500KB — o console emite warning "code generator has deoptimised the styling". Isso vai piorar conforme o produto cresce.

### 2.2 Backend e persistência

| Item | Padrão Confiance | Estado atual | Aderente? |
|---|---|---|---|
| Banco de dados | MySQL local no servidor da empresa | Supabase (PostgreSQL na nuvem) | **NÃO — proibido** |
| API | REST própria com prefixo `/SIGLA/api/v1/` | Supabase JS SDK direto no cliente | Não |
| URL base | `src/config/api.ts` (default `http://localhost:80`) | `SUPABASE_URL` embutida no HTML | Não |
| Storage de arquivos | Servidor local | Supabase Storage (buckets `pacotes-analise`, `form-templates`) | **NÃO — proibido** |
| Edge Functions | N/A no padrão | `converter-para-pdf` (CloudConvert) | Dependência externa |

**Este é o gap mais crítico.** O padrão proíbe explicitamente bancos em nuvem, serverless externo e Storage em serviço externo. Toda a persistência da plataforma hoje viola essa regra.

### 2.3 Autenticação

| Item | Padrão Confiance | Estado atual | Aderente? |
|---|---|---|---|
| Login | Delegar 100% ao SCM | Login próprio via Supabase Auth (`LoginPage`) | **NÃO — proibido** |
| Tokens JWT | Ler `auth_token` do localStorage (setado pelo SCM) | Sessão gerenciada pelo Supabase | Não |
| Refresh tokens | Fornecido pelo SCM | Fornecido pelo Supabase | Não |
| Cadastro de usuários | Não pode ter — é responsabilidade do SCM | Sem cadastro, mas com fluxo próprio de recuperação de senha do Supabase | Não |
| Permissões | Ler `auth_permissoes` do localStorage (níveis 1/2/3) | Sem sistema de permissões implementado | Falta |
| Redirect 401 | Redirecionar ao SCM | Fica na tela de login própria | Não |

**Risco crítico:** o padrão diz explicitamente "NUNCA implemente autenticação própria em sistemas satélite". A plataforma atual tem tela de login própria e depende do Supabase Auth. Isso é violação direta.

### 2.4 Estrutura de pastas

| Padrão Confiance | Estado atual |
|---|---|
| `src/components/` (UI reutilizável) | Tudo em `plataforma.html` |
| `src/config/api.ts` | URLs embutidas no HTML |
| `src/contexts/` | ToastContext inline |
| `src/hooks/` | Hooks inline |
| `src/lib/` | Utils inline |
| `src/pages/[modulo]/` | Componentes de página inline |
| `src/services/api/` | Chamadas Supabase espalhadas |

**Custo de migração:** partir de um arquivo único de ~10.700 linhas e quebrar em módulos leva 1 a 2 semanas, com risco significativo de regressão.

### 2.5 Padrões de desenvolvimento

| Regra | Aderência |
|---|---|
| Rotas protegidas verificam token | Não (usa sessão do Supabase) |
| Componente default export em `.tsx` | Não (funções inline em `.html`) |
| Permissões níveis 1/2/3 do localStorage | Falta |
| URLs em `src/config/api.ts` | Não |
| Funções de API em `src/services/api/` | Não |
| Tratamento 401 → redirect SCM | Não |
| TanStack Query para leitura | Não |
| React Hook Form + Zod | Não |
| Nunca `<form>` HTML direto | Já usa handlers React |
| TypeScript sem `any` | Não usa TypeScript |
| PT-BR em variáveis/comentários | ✅ Aderente |
| Separação UI / dados | Parcial (misturado hoje) |

---

## 3. Roadmap sugerido de migração

Ordem recomendada (do mais crítico ao menos crítico) — cada fase é independente e pode ser feita/pausada sem quebrar o que já existe.

### Fase 1 — Fundação (~1 semana)
- Criar projeto Vite + React 18 + TypeScript com estrutura `src/` do padrão
- Configurar Tailwind local, path aliases `@/`, ESLint, tsconfig
- Configurar `src/config/api.ts` apontando para servidor local
- Instalar shadcn/ui, lucide-react, TanStack Query, React Hook Form, Zod, Recharts, Sonner
- Definir contratos das entidades principais em TypeScript (`Analise`, `Produto`, `FichaMestre`, `Apontamento`)

### Fase 2 — Autenticação SCM (~3 dias)
- Substituir `LoginPage` própria por leitura do `auth_token` do localStorage
- Criar `authFetch` que injeta Bearer token em toda requisição
- Implementar redirect ao SCM quando token ausente/inválido/401
- Implementar leitura de `auth_permissoes` e componente `<Protected level={n}>`

### Fase 3 — Backend REST + MySQL (~2 a 3 semanas)
- Modelar schema MySQL equivalente (tabelas atuais do Supabase: `analises`, `produtos`, `fichas_mestres`, `acessorios_aplicaveis`, `roteiro`)
- Escrever API REST com prefixo `/CONC/api/v1/` (Concilação): endpoints CRUD + endpoints de upload/download de pacote ZIP
- Substituir Supabase Storage por upload direto ao servidor local (endpoint `POST /CONC/api/v1/arquivos`)
- Reescrever `src/services/api/` chamando os novos endpoints
- Substituir Edge Function CloudConvert por biblioteca local (LibreOffice headless ou similar) ou serviço interno equivalente

### Fase 4 — Migração de dados (~2 dias)
- Script one-off: dump do Supabase → importar no MySQL local
- Migrar arquivos do Supabase Storage para pasta do servidor local
- Testar re-análise e download de pacotes com dados migrados

### Fase 5 — Reescrita da UI (~2 semanas)
- Migrar cada página (`Dashboard`, `Análise`, `Histórico`, `Cadastro`) para `.tsx` com React Query
- Trocar componentes manuais por shadcn/ui equivalentes
- Substituir gráficos Chart.js por Recharts
- Formulários com React Hook Form + Zod
- Rotas com React Router DOM v6

### Fase 6 — Backup automático (~2 dias)
- Endpoint `POST /CONC/api/v1/backup/executar` que gera XLSX
- Job/cron mensal no servidor (dia 1) que chama o endpoint + envia por e-mail via SMTP interno para `qualidade@confiancemedical.com.br`
- Substitui o botão manual atual

### Fase 7 — Corte e desligamento do Supabase (~2 dias)
- Rodar em paralelo (dual-write) por 1 semana pra validar
- Após validação, deletar projeto Supabase e código legado
- Atualizar documentação

---

## 4. Riscos identificados

1. **Perda de recurso durante migração**: a plataforma tem hoje ~10.700 linhas de lógica de negócio (parseOP, parseRC, parseEtiqueta, analisarConciliacao, cronologia, cruzamentos). Reescrever isso em TypeScript sem regredir exige testes automatizados (que não existem hoje) — pode ser necessário criar suíte de testes antes de migrar.

2. **CloudConvert como dependência**: a conversão de OP DOCX→PDF hoje depende da Edge Function CloudConvert. Sem alternativa on-premise, o download de pacotes ZIP pára. Precisa validar LibreOffice headless ou outra opção antes do corte.

3. **Templates de FORM-GQ-0047 no bucket Supabase**: o template do FORM está armazenado no bucket `form-templates`. Precisa migrar para o servidor local antes de desligar o Supabase.

4. **Fichas Mestres pré-cadastradas**: hoje temos 89 produtos + fichas parciais no banco Supabase. O script de migração precisa preservar tudo isso 100% ou a QG perde a base de cadastro.

5. **Histórico de análises**: cada análise cadastrada tem parecer completo + pacote ZIP anexado. Migrar tudo sem corromper é crítico — regulatório exige rastreabilidade.

6. **Ausência de testes**: qualquer refactor cego risca regredir uma das dezenas de regras de negócio já validadas com você (cronologia, inspeção, acessórios, etc.). Recomendo criar suíte de testes automatizados com base nas OPs de referência (6673, 7318, 7430, 7436, 7499) antes de migrar.

7. **Janela de indisponibilidade**: durante o corte final (fase 7) a plataforma pode ficar indisponível algumas horas. Precisa combinar com a QG.

---

## 5. Recomendação

**Continuar operando na plataforma atual até que a migração seja aprovada e priorizada**, uma vez que ela resolve o problema hoje e evoluir novas features (Camada 1 completa, novos cruzamentos, etc.) na versão atual é mais rápido do que reescrever tudo agora.

Quando houver janela de 4 a 8 semanas dedicadas + apoio de infra pra provisionar o servidor MySQL + endpoint SCM disponível, executar o roadmap fase a fase, com deploy em paralelo para validação.

Enquanto isso, tratar como débito técnico documentado e evitar aprofundar dependências do Supabase (não adicionar novas Edge Functions, não expandir esquema, etc.).

---

## 6. Itens que já ficaram alinhados

Como parte desta interação:
- Removido o botão perigoso "Limpar histórico" da UI
- Adicionado botão "Backup mensal" que gera XLSX completo para envio manual à `qualidade@confiancemedical.com.br` (rotina mensal QG). O backup automático via cron ficará para depois da migração ao padrão.

---

*Este documento deve ser revisado e aprovado pela QG e pela área de infra antes de qualquer migração ser iniciada.*
