# Plataforma de Conciliação da Produção — Confiance Medical

Sistema interno da Garantia da Qualidade para verificação automatizada da conciliação de produção de lotes fabricados pela Confiance Medical, conforme protocolo v1.1 (ISO 13485:2016, RDC 665/2022, RDC 751/2022, IEC 60601 quando aplicável).

## Stack

| Camada | Tecnologia |
|--------|------------|
| Frontend | React 18 + Vite + TypeScript |
| Estilo | Tailwind CSS + shadcn/ui + design system Confiance (Navy / Cyan / Turquoise · Montserrat / Raleway) |
| Estado servidor | TanStack Query (React Query) |
| Roteamento | React Router v6 |
| Backend | Supabase (Postgres + Auth + Storage + Edge Functions) |
| Agente IA | Edge Function chamando a API da Anthropic (Claude Sonnet 4.6) |
| PDF do relatório | @react-pdf/renderer (server-side) |
| Notificações | Sonner |
| Validação de forms | React Hook Form + Zod |

## Status de implementação

- [x] **Fase 1 — Fundação:** projeto + design system + layout + rotas + schema Supabase + páginas iniciais
- [ ] **Fase 2 — Cadastro:** CRUD de produtos e editor completo de Ficha Mestre (9 seções)
- [ ] **Fase 3 — Análise:** upload + Edge Function do agente + exibição do parecer
- [ ] **Fase 4 — Histórico + Dashboard:** listagem, filtros, métricas, gráficos
- [ ] **Fase 5 — Relatório em PDF + polimento final**

## Setup

### 1. Pré-requisitos

- Node.js 18+ (recomendado 20 LTS)
- npm (ou pnpm/yarn — ajuste o lockfile)
- Conta no [Supabase](https://supabase.com/) (free tier funciona para começar)
- Chave da API da Anthropic (`sk-ant-…`) — apenas para Fase 3

### 2. Instalar dependências

```bash
cd Plataforma-Conciliacao
npm install
```

### 3. Configurar Supabase

1. Crie um projeto no Supabase.
2. No SQL Editor, execute `supabase/schema.sql` (cria tabelas, enums, storage buckets, RLS).
3. (Opcional, recomendado) Execute `supabase/seed-cm-led.sql` para carregar o catálogo completo do FORM-GQ-0085 e a Ficha Mestre do CM-LED como modelo de referência.
4. Em **Authentication → Users**, crie o usuário `qualidade@confiancemedical.com.br` com senha definida por você.
5. Copie URL do projeto e a **anon key** (não a service_role) e coloque no `.env.local`:

```bash
cp .env.example .env.local
# edite .env.local
```

### 4. Rodar em desenvolvimento

```bash
npm run dev
```

Abre em `http://localhost:5173`. A navegação entre Dashboard / Análise / Histórico / Cadastro já funciona; as funcionalidades internas serão preenchidas nas próximas fases.

### 5. Build de produção

```bash
npm run build
npm run preview
```

## Estrutura do projeto

```
Plataforma-Conciliacao/
├── index.html
├── package.json
├── vite.config.ts
├── tailwind.config.ts        ← tokens do design system
├── tsconfig.json
├── components.json           ← shadcn/ui config
├── .env.example
├── README.md
├── src/
│   ├── main.tsx
│   ├── App.tsx               ← rotas + providers
│   ├── index.css             ← tokens CSS + dark mode
│   ├── components/
│   │   ├── ui/               ← componentes shadcn (Button, Card…)
│   │   ├── layout/           ← AppLayout, Sidebar
│   │   ├── PageHeader.tsx
│   │   └── StatusBadge.tsx
│   ├── contexts/
│   │   └── ThemeProvider.tsx ← dark mode (light/dark/system)
│   ├── lib/
│   │   ├── utils.ts          ← cn(), formatDate…
│   │   └── supabase.ts       ← client tipado
│   ├── pages/
│   │   ├── Dashboard.tsx
│   │   ├── Analise.tsx
│   │   ├── Historico.tsx
│   │   └── Cadastro.tsx
│   └── types/
│       └── database.ts       ← tipos sincronizados com schema.sql
└── supabase/
    ├── schema.sql            ← tabelas, enums, RLS, buckets
    └── seed-cm-led.sql       ← dados iniciais (FORM-GQ-0085 + Ficha CM-LED)
```

## Modelo de dados (resumo)

- **produtos** — catálogo (FORM-GQ-0085): equipamento, modelo, código de referência, registro ANVISA
- **fichas_mestres** — uma ficha por produto/versão (versionamento mantido para auditoria ISO 13485)
- **acessorios_aplicaveis** — acessórios obrigatórios/opcionais do produto (seção 4 da ficha)
- **roteiro_form_gq_0047** — mapeamento de marcações esperadas (seção 5 da ficha)
- **inspecoes_criterios** — critérios de aceitação por estágio (seção 6 da ficha)
- **componentes_bom** — BOM aprovada (seção 7 da ficha)
- **analises** — cabeçalho de cada conciliação executada pelo agente
- **documentos_analise** — arquivos enviados (referência ao Storage)
- **apontamentos** — achados do agente (NCs e ressalvas)

## Design system

Cores principais (HSL):

| Token | Valor | Uso |
|-------|-------|-----|
| `--primary` | `222 45% 22%` (Navy) | Sidebar, botões primários, títulos |
| `--accent` | `188 52% 61%` (Cyan) | Destaques, focus rings, links |
| `--secondary` | `189 72% 42%` (Turquoise) | Botões secundários |
| `--status-conforme` | `142 65% 42%` | Badge ✅ Conforme |
| `--status-ressalva` | `38 92% 50%` | Badge ⚠️ Ressalva |
| `--status-nao-conforme` | `0 72% 50%` | Badge ❌ Não Conforme |

Fontes: **Montserrat** (títulos/H1-H6), **Raleway** (corpo). Border-radius padrão: `0.75rem`. Dark mode completo via classe `.dark`.

## Protocolo do agente

A lógica de análise segue o `PROTOCOLO_AGENTE_CONCILIACAO.md` na raiz do projeto principal. Quando a Fase 3 for implementada, o protocolo será incorporado como system prompt da Edge Function.

## Roadmap

- **v1.0** — protocolo validado em texto (já feito)
- **v1.1 (em curso)** — plataforma com análise manual via agente
- **v2.0** — auto-preenchimento da OP e do FORM-GQ-0047 pelo agente
- **v2.1** — análise de tempos médios por estágio/operação
- **v3.0** — integração com Adobe Sign para assinaturas digitais certificadas

## Convenções

- UI em pt-BR; comentários em código em inglês ou pt-BR (consistente por arquivo)
- Commits em pt-BR no padrão `[Fase X] descrição curta`
- Componentes shadcn em `src/components/ui/` — adicionados com `npx shadcn-ui@latest add <nome>`
