# Plataforma de Conciliação da Produção — Guia de Funcionalidades e Adequação

**Para:** P&D Software — Confiance Medical
**Solicitante:** Maria Luiza Zaccur (Garantia da Qualidade)
**Data:** 29/07/2026 (atualiza a versão de 01/07/2026)
**Objetivo:** Apresentar o sistema, como ele funciona hoje, e o que falta para adequá-lo ao **Padrão de Desenvolvimento de Sistemas da Confiance Medical** (React 18 + TypeScript + Vite + shadcn/ui + MySQL local + integração SCM).

---

## 1. Visão geral

A plataforma de Conciliação da Produção é usada pela Garantia da Qualidade (QG) para validar automaticamente os documentos de fechamento de Ordens de Produção (OP, RC, Etiquetas, FORM-GQ-0047) e emitir um **parecer técnico de liberação** do lote. O sistema está em uso operacional e resolve o problema de negócio; foi desenvolvido fora do padrão oficial e está sendo submetido ao P&D para adequação.

A análise é **determinística** (regras + parsers, sem IA no motor de decisão) e organizada em três camadas:

- **Camada 1 — Consistência interna entre documentos** (série igual entre OP/Etiqueta/FORM, cronologia de estágios/inspeções, RC × etiqueta de acessório, medições dentro da faixa, aptidão do inspetor, FORM-GQ-0047).
- **Camada 2 — Conformidade contra a Ficha Mestre** (identificação do produto, derivação, registro ANVISA, acessórios obrigatórios, grupos alternativos, inspeções previstas, Etiqueta Externa × Ficha).
- **Camada 3 — Conformidade regulatória** (rastreabilidade, rotulagem, checklist de liberação, BPF, OP de reprocesso, RNC).

Cada verificação é exibida em três colunas — **O que foi verificado / Valores lidos / Status** — e classificada como Conforme, Ressalva, Não Conformidade (NC) ou N/A.

---

## 2. Como funciona hoje (inventário de funcionalidades)

### 2.1 Análise e parecer

- Upload de documentos por "slots": OP, RC, Etiqueta do produto, N × Etiqueta de acessório, FORM-GQ-0047 (opcional), OP de Reprocesso e RNC (condicionais). Todos aceitam **arrastar ou selecionar** (inclusive pasta).
- Parsers heurísticos: `parseOP`, `parseRC`, `parseEtiqueta`, `parseEtiquetaAcessorio` (validados com dezenas de OPs de referência).
- Motor `analisarConciliacao` (Camadas 1/2/3) → parecer com apontamentos, resultado geral e checklist por camada.
- **Detecção automática** da data de conciliação e da **OP a que a RC se refere** (cruzamento RC × OP).
- Justificativa de ressalva pelo RT → reclassifica como conforme (não conta como correção).
- Correção de documento NC → re-análise reusando os slots não corrigidos e os arquivos originais armazenados.
- Geração automática do **FORM-GQ-0047** pré-preenchido (XLSX com formatação preservada).
- **Parecer técnico em PDF** e **empacotamento em ZIP** (OP + FORM + Parecer + documentos originais convertidos em PDF).
- Bloqueios: download com bloqueador/ressalva sem justificativa; análise duplicada (OP+Série); importação de produto sem Ficha Mestre.

### 2.2 Cadastros

- **Catálogo de produtos** (~89 produtos).
- **Fichas Mestres**: derivações, acessórios aplicáveis, estágios variáveis aplicáveis, estágios com inspeção, convenção do nº de série, dados regulatórios.
- **Acessórios alternativos (grupos)**: cada grupo tem nome, flag **obrigatório/opcional** e variantes com **nome na etiqueta + código Sapiens**; casamento sempre por código Sapiens.
- **Inspetores por estágio** (o "Ni"): lista global de quem está autorizado a inspecionar cada estágio (admissão = adicionar, demissão = inativar preservando histórico). *(A conferência de operador foi descontinuada — só inspetor.)*

### 2.3 Histórico, dashboard e análises

- **Histórico** com filtros (data, mês/ano, equipamento, modelo encadeado, origem agente/manual, correções, busca textual), ordenação clicável e cabeçalho fixo.
- **Download em lote** dos pacotes de OPs conformes pendentes para a pasta de rede, com indicador de progresso; subpasta do mês pela **data da análise**.
- **Importação em massa** de análises manuais retroativas (XLSX).
- **Dashboard em abas**:
  - **Gráficos** — KPIs, donut de conformidade, erros por tipo de documento, erros por equipamento (ressalvas ficam fora das contagens dos gráficos).
  - **Histórico de correções**.
  - **Tendência e reincidência** — reincidência por chave (categoria + equipamento + alvo), níveis Pontual / Possível reincidente / Reincidente / Em alta (só na janela de até 30 dias; períodos maiores = consulta). **Tela apenas de consulta.**
  - **Melhorias regulatórias** — oportunidades de melhoria (M-01, M-02…) capturadas nas análises, com deduplicação por código; a Qualidade marca **Acatar / Não acatar** (decisão encerra o item).

### 2.4 Governança e integrações

- **Permissões em 3 níveis** (1 Usuário, 2 Administrador, 3 Gestor) com perfis, convites e **log de atividades**.
- **Solicitações/aprovações**: ações sensíveis (excluir/refazer) podem exigir aprovação.
- **Alerta de NC no Slack** com card editável, roteado **por canal do setor responsável**: correção do PCP → canal `pcp_gq`; correção do Almoxarifado → canal `almoxarifado_gq` (uma mensagem por canal). Aviso de reincidência opcional junto da NC (checkbox, ligado por padrão).

---

## 3. Arquitetura atual

### 3.1 Frontend

- **Arquivo único** `plataforma.html` (~14.400 linhas): React 18 + JSX inline **sem TypeScript**, compilado por **Babel-standalone no browser** (em runtime).
- Tailwind via CDN; componentes shadcn-like escritos à mão (Card, Button, Input, Modal, Toaster…); ícones SVG inline.
- Roteamento por estado + `window.location.hash`. Estado com `useState` + chamadas diretas ao **Supabase JS SDK**.
- Gráficos custom (SVG) e Chart.js via CDN; PDF/Excel/ZIP via pdf.js, pdf-lib, ExcelJS, JSZip (CDN).

### 3.2 Backend / persistência

- **Supabase** (PostgreSQL na nuvem + Storage + Auth + Realtime). Tabelas principais: `produtos`, `fichas_mestres`, `acessorios_aplicaveis`, `analises`, `apontamentos`, `config_app`, `perfis`, `logs_atividade`, `solicitacoes`, `operadores`, `melhorias_regulatorias` (e `operacoes_livres`, dormente). Buckets: `pacotes-analise`, `form-templates`.
- **Autenticação própria** via Supabase Auth (tela de login própria).

### 3.3 Serviço local `conversor-pdf-local` (Node/Express + PM2)

Já roda **on-premise** no servidor da empresa e **substituiu o CloudConvert** por conversão local:

- `POST /converter-pdf` — conversão de documentos para PDF via **LibreOffice/Ghostscript/Chromium** (sem serviço de nuvem).
- `POST /salvar-pacote` — grava o ZIP do pacote na pasta de rede.
- `POST /convidar-usuario` — provisiona usuário (Supabase Admin).
- `POST /notificar-slack` — envia alerta ao Slack, **roteando por canal** (`SLACK_WEBHOOK_PCP` / `SLACK_WEBHOOK_ALMOXARIFADO`).
- `POST /pcp-status` — integração com planilha do PCP (dormente).
- `GET /health`.

Segredos (service_role, webhooks do Slack) ficam **apenas** no `.env` do serviço, fora do Git e do navegador.

---

## 4. Adequação às regras da empresa — status atual

Comparação com o **Padrão de Desenvolvimento de Sistemas — Confiance Medical**.

| # | Regra da empresa | Status | O que falta |
|---|---|---|---|
| Stack front | React 18 + **TypeScript + Vite + shadcn/ui + React Router + React Query + RHF+Zod + Recharts** | ❌ Não atende | Hoje é HTML único com Babel no browser, sem TS/Vite/build. Reescrever no stack oficial. |
| Estilo | Tailwind (build local) | 🟡 Parcial | Usa Tailwind, mas via CDN (sem build). |
| Banco | **MySQL local** no servidor | ❌ Não atende | Hoje PostgreSQL na nuvem (Supabase). Modelar e migrar para MySQL local. |
| Proibição de nuvem | Nenhum dado persistente fora do servidor | ❌ Não atende | Dados e arquivos ainda no Supabase (Postgres + Storage). Mover tudo para servidor local. |
| Conversão de documentos | On-premise | ✅ **Já adequado** | Serviço local com LibreOffice/Ghostscript já substituiu o CloudConvert. |
| Armazenamento de arquivos | Servidor local | 🟡 Parcial | O ZIP do pacote já é salvo na rede via `/salvar-pacote`; os **originais** ainda sobem para o Storage do Supabase. Migrar para filesystem local. |
| API | REST por prefixo `/SIGLA/api/v1/` | ❌ Não atende | Não há API REST própria; o front fala direto com o Supabase. Criar backend REST (`/CONC/api/v1/`). |
| Autenticação | **Delegada ao SCM** (JWT, sem auth próprio) | ❌ Não atende | Hoje login próprio (Supabase Auth). Trocar por leitura de `auth_token`/`auth_permissoes` do SCM + `authFetch` + redirect em 401. Remover auth próprio. |
| Estrutura de pastas | `src/components|config|contexts|hooks|lib|pages|services/api` | ❌ Não atende | Arquivo único. Reorganizar na estrutura padrão. |
| Aliases `@/` → `src/` | — | ❌ Não atende | Introduzir no Vite. |
| Tratamento de erros (401→SCM, 403/404/500) | — | ❌ Não atende | Implementar no cliente HTTP. |
| TypeScript sem `any`; nomes em português | — | ❌ Não atende | Tipar entidades (`Analise`, `Produto`, `FichaMestre`, `Apontamento`, `Parecer`…). |
| Documentação ao finalizar | — | 🟡 Parcial | Já existem vários `.md`; consolidar README + guia de manutenção no fim. |

Resumo: a **lógica de negócio e a conversão local já estão prontas e comprovadas**; o gap é de **plataforma** (TS/Vite/shadcn), **persistência** (MySQL local no lugar do Supabase), **API REST própria** e **autenticação via SCM**.

---

## 5. Regras de negócio que NÃO podem regredir

Referência canônica: `PROTOCOLO_AGENTE_CONCILIACAO.md` e `CLASSIFICACAO_VERIFICACOES_NC_RESSALVA.md`.

- **Parsers** (formato do texto do pdf.js UMD é **multi-linha** — preservar os regexes exatamente).
- **Camada 1**: série consistente entre OP/Etiqueta/FORM **e dentro da convenção da Ficha** (fora da convenção = NC); cronologia coerente; inspeções duplicadas ordenadas; medições dentro da faixa; aptidão do inspetor (ressalva); FORM-GQ-0047.
- **Camada 2**: identificação do produto; derivação; registro ANVISA; acessórios obrigatórios; **grupos alternativos** (obrigatório/opcional, variante por nome+código, ≥1 obrigatória, >1 presente = ressalva); inspeções previstas pela Ficha; Etiqueta Externa × Ficha (família, modelo, série, fabricante, CNPJ, endereço, telefone, RT, CREA, resp. legal, data de fabricação, validade).
- **Camada 3**: rastreabilidade, rotulagem, checklist de liberação, BPF, OP de reprocesso/RNC guiados por anexo.
- **Classificação NC × Ressalva** documentada e revisada (ver `CLASSIFICACAO_VERIFICACOES_NC_RESSALVA.md`) — inclui as decisões de 22/07 (endereço, telefone, CREA, validade e data de fabricação divergentes = NC; série fora da convenção = NC).
- **Datas exibidas em DD/MM/AAAA**; internamente ISO para comparação.
- **Estágios**: variáveis declarados pela ficha; fixos universais (CQ, Embalagem 50, Conciliação 60, Verificação da rotulagem); inspeção obrigatória universal nos 50 e 60; estágios 5 e 7 sem inspeção.
- Reincidência por chave (categoria+equipamento+alvo), níveis e janelas conforme `COMO_FUNCIONA_TENDENCIA_E_REINCIDENCIA.md`.
- Roteamento de Slack por setor responsável (PCP × Almoxarifado).

---

## 6. Padrão alvo (destino)

**Frontend:** React 18 + TypeScript (TSX) · Vite (`@vitejs/plugin-react-swc`) · Tailwind (build local) · shadcn/ui (Radix) · lucide-react · React Router DOM v6 · TanStack React Query v5 · React Hook Form + Zod · Recharts · Sonner + shadcn Toaster · alias `@/` → `src/`.

**Backend:** MySQL local · API REST `/CONC/api/v1/` · URL base em `src/config/api.ts` · **autenticação delegada ao SCM** (Bearer token do localStorage, `authFetch`, redirect em 401) · arquivos no filesystem local.

**Estrutura:** `src/{components,config,contexts,hooks,lib,pages,services/api}` (páginas por módulo: dashboard, analise, historico, cadastro, tendencia, melhorias).

---

## 7. Fases sugeridas

- **Fase 0 — Preparação (2 dias):** servidor MySQL local; servidor de aplicação (Node/nginx); confirmar URL/credenciais do SCM; definir prefixo `/CONC/api/v1/`; repositório Git. *(Conversão local já resolvida pelo serviço atual — reaproveitar.)*
- **Fase 1 — Fundação do frontend (3–4 dias):** Vite react-ts, Tailwind, aliases, ESLint/Prettier, shadcn/ui, libs; rotas base; layout (sidebar + main); contratos TypeScript das entidades; Vitest.
- **Fase 2 — Autenticação SCM (2 dias):** remover login próprio; `authFetch` com Bearer; `useAuth()` lendo `auth_user`/`auth_permissoes`; `<Protected level={n}>`; interceptor 401 → SCM; remover Supabase Auth.
- **Fase 3 — Backend REST + MySQL (2–3 semanas):** schema MySQL equivalente (incluindo `perfis`, `logs_atividade`, `solicitacoes`, `operadores`, `melhorias_regulatorias`, `config_app`); endpoints REST (seção 8); arquivos no filesystem local; **integrar o serviço de conversão/Slack já existente** atrás da API; `audit_log`.
- **Fase 4 — Migração de dados (2 dias):** dump do Supabase → adaptar Postgres→MySQL (jsonb→JSON); baixar arquivos dos buckets; importar; validar contagens; testar re-análise e download.
- **Fase 5 — Reescrita da UI (2–3 semanas):** migrar cada módulo para `.tsx` com React Query + shadcn/Recharts, **preservando os algoritmos exatos** (parseOP/RC/Etiqueta/Acessorio, analisarConciliacao, fillFormXlsxTemplate, gerarParecerPDF); Sonner; lucide-react; JSZip; RHF+Zod.
- **Fase 6 — Backup automatizado (2 dias):** endpoint de backup XLSX consolidado + cron mensal por SMTP interno para `qualidade@confiancemedical.com.br`.
- **Fase 7 — Corte e validação (1 semana):** homologação; validar com OPs de referência (6673, 7318, 7430, 7436, 7499, 6819); dual-write 3–5 dias; corte; desligar Supabase; atualizar documentação.

**Total estimado: ~6–8 semanas.**

---

## 8. Endpoints REST sugeridos

| Método | Endpoint | Descrição |
|---|---|---|
| GET/POST/PUT/DELETE | `/CONC/api/v1/produtos[/:id]` | Catálogo de produtos |
| GET/POST/PUT/DELETE | `/CONC/api/v1/fichas-mestres[/:id]` | Fichas mestres (com acessórios e grupos alternativos) |
| GET/POST | `/CONC/api/v1/analises[/:id]` | Análises (lista com filtros, detalhe, criação) |
| PATCH | `/CONC/api/v1/analises/:id/justificar` | Justificativa de ressalva |
| POST | `/CONC/api/v1/analises/importar` | Importação em massa (XLSX) |
| GET/POST/PUT | `/CONC/api/v1/operadores` | Inspetores por estágio |
| GET/PATCH | `/CONC/api/v1/melhorias` | Melhorias regulatórias (listar / acatar-não acatar) |
| GET/POST/PATCH | `/CONC/api/v1/solicitacoes` | Solicitações/aprovações |
| GET | `/CONC/api/v1/logs` | Log de atividades |
| POST/GET | `/CONC/api/v1/uploads[/:path]` | Upload/download de arquivos (filesystem local) |
| POST | `/CONC/api/v1/converter/pdf` | Conversão para PDF (serviço local existente) |
| POST | `/CONC/api/v1/notificar-slack` | Alerta ao Slack por canal (PCP/Almoxarifado) |
| POST | `/CONC/api/v1/backup/executar` | Backup XLSX + e-mail |
| GET | `/CONC/api/v1/dashboard/metricas` | Métricas do dashboard |

Todas exigem Bearer token JWT do SCM; 401 → redirect SCM.

---

## 9. Riscos e mitigações

1. **Regressão nas regras de negócio** → suíte de testes (Vitest) com as OPs de referência **antes** de migrar, validando os apontamentos esperados.
2. **Migração de dados** → dual-write 3–5 dias + hash de comparação; nenhuma análise pode ser perdida (rastreabilidade ISO 13485).
3. **Storage de arquivos** → baixar tudo do Supabase com verificação de integridade antes de subir ao filesystem local.
4. **Formato multi-linha do texto do pdf.js** → preservar os regexes exatamente (documentado no código).
5. **Janela de indisponibilidade no corte** → avisar QG com antecedência; corte fora do horário comercial + plano de rollback.

---

## 10. Perguntas abertas para o P&D

1. URL do SCM em produção e documentação da integração (login/logout/validação de token)?
2. Existe outro sistema satélite já no padrão para copiar a estrutura?
3. Onde hospedar front (build Vite) e back (API REST)?
4. SMTP interno para o backup mensal (servidor/porta/credencial)?
5. Restrição de licenciamento para LibreOffice server-side?
6. CI/CD e padrões de log/monitoramento a integrar?
7. Padrão de versionamento para o release?

---

## 11. Documentos de apoio (nesta pasta)

- `PROTOCOLO_AGENTE_CONCILIACAO.md` — regras de negócio consolidadas.
- `CLASSIFICACAO_VERIFICACOES_NC_RESSALVA.md` — o que é NC × Ressalva por verificação.
- `COMO_FUNCIONA_TENDENCIA_E_REINCIDENCIA.md` — reincidência (chave, níveis, janelas).
- `COMO_CONFIGURAR_ALERTA_SLACK.md` — webhooks por canal.
- `ESPEC_PD_PACOTE_SERVIDOR_E_PDF_LOCAL.md` — serviço de conversão/pacote local.
- `AUDITORIA_PADRAO_CONFIANCE.md` — comparativo item a item com o padrão.

---

## 12. Contato

**Maria Luiza Zaccur** — Garantia da Qualidade · mzaccur@confiancemedical.com.br
