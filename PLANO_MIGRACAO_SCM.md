# Plano de Migração para o SCM — Plataforma de Conciliação da Produção

**Área:** Garantia da Qualidade — Confiance Medical
**Data:** 09/07/2026 · Autora: Maria Luiza · Destinatário: **P&D Software**
**Natureza:** documento de hand-off. A versão em uso é **interina**; este plano lista,
de forma objetiva, o que precisa mudar para atender ao padrão da empresa.

---

## 1. Objetivo

Levar a plataforma do arranjo interino (app HTML único + **Supabase na nuvem** + serviço
Node local rodando na máquina da GQ) para o **padrão oficial**: stack React/TS com Vite,
**autenticação delegada ao SCM**, **persistência em MySQL local** e **API REST** própria —
sem nada em nuvem e sem autenticação própria.

---

## 2. Regras da empresa × situação atual × ação necessária  *(núcleo do documento)*

| # | Regra da empresa | Situação atual (interino) | Ação do P&D |
|---|---|---|---|
| 1 | **Sem banco em nuvem** (proibido Supabase, Firebase, etc.) | Dados no **Supabase (Postgres nuvem)** | Recriar schema em **MySQL local** e migrar os dados |
| 2 | **Sem storage externo**; arquivos no servidor local | Arquivos no **Supabase Storage** (bucket `pacotes-analise`) | Mover para pasta no servidor, servida pela API |
| 3 | **Autenticação só via SCM** (nunca própria) | **Supabase Auth** + tabelas `perfis`/`convites` | Remover auth própria; ler token do SCM (`localStorage`), enviar `Bearer`, redirecionar ao SCM |
| 4 | **API REST** por prefixo (`/SIGLA/api/v1/`), base em `src/config/api.ts` | Chamadas **diretas ao Supabase** no navegador | Criar backend REST próprio; frontend consome a API |
| 5 | **Stack padrão** (React 18 + TS + Vite + Tailwind + shadcn + React Router v6 + React Query v5 + RHF + Zod + Recharts + Sonner; alias `@/`) | Arquivo **HTML único** (React via Babel no navegador, sem build) | Reescrever como projeto Vite/TS estruturado |
| 6 | **Estrutura de pastas padrão** (`components`, `pages/[modulo]`, `services/api`, `config`, `hooks`, `lib`) | Tudo num só arquivo | Organizar conforme o padrão |
| 7 | **Permissões em 3 níveis** (1=Usuário, 2=Admin, 3=Gestor) lidas do SCM | Permissões finas próprias em `perfis.permissoes` | Mapear as permissões finas atuais para os níveis/permissões do SCM |
| 8 | **`localStorage` só para sessão do SCM** | Usado para config da pasta (já migrado p/ banco `config_app`) e tema | Ler config do backend; manter no `localStorage` só o que vier do SCM |
| 9 | Tratar 401/403/404/500; **401 → redireciona ao SCM** | Tratamento parcial (interino) | Implementar no `authFetch`/interceptors |
| 10 | TS sem `any`; nomes/comentários em português; nunca `<form>` direto; separar UI/dados | Código JS no HTML | Reescrever em TS seguindo o padrão |

> **Infra (não é regra, mas é urgente):** hoje o serviço roda na máquina da GQ
> (`cm-qualidade01`, 192.168.20.122). A plataforma **só fica no ar enquanto esse PC está
> ligado**. Alvo: rodar num **servidor sempre ligado** (ex.: 192.168.20.252). Ver roteiro em
> `conversor-pdf-local/MIGRAR_SERVICO_PARA_SERVIDOR.md`.

---

## 3. Inventário atual (o que existe hoje)

**Frontend:** `plataforma.html` (React/Babel), servido por HTTP pelo serviço Node em
`http://192.168.20.122:3001/`.

**Banco (Supabase Postgres) — tabelas:**

| Tabela | Papel | Destino na migração |
|---|---|---|
| `produtos` | Catálogo de equipamentos/derivações | MySQL |
| `fichas_mestres` | Ficha mestre por derivação (etiquetas, estágios, regras JSON) | MySQL |
| `acessorios_aplicaveis` | Acessórios da ficha (inclui `grupo_alternativo` JSON) | MySQL |
| `fichas_mestres_versoes` | Revisões/versionamento (snapshot JSON) — reverter versão | MySQL |
| `analises` | Conciliação: `parecer_completo` (JSON), `status`, OP/série, `analise_origem_id`, `doc_substituido`, `motivo_reanalise`, **`tipo_reanalise`** (`atualizacao_ficha`), `ficha_id`, `produto_id`, `pacote_zip_*` | MySQL |
| `apontamentos` | NC/ressalvas detalhadas por análise | MySQL |
| `logs_atividade` | Trilha de auditoria (autor, ação, entidade, descrição) | MySQL (reaproveitar) |
| `solicitacoes` | Pedidos de aprovação entre usuários (interino) | Avaliar (ver decisões) |
| `config_app` | Config compartilhada (pasta de destino do pacote, subpasta do mês) | MySQL (ou config do backend) |
| `perfis` | Usuário/cargo/permissões | **Descontinuar** → SCM |
| `convites` | Convite por e-mail | **Descontinuar** → SCM |

**Storage:** bucket `pacotes-analise` (ZIP/documentos originais). Colunas `pacote_zip_path/
filename/size/uploaded_at` em `analises` guardam a referência.

**Serviço Node (`conversor-pdf-local`, PM2) — endpoints:**

| Endpoint | Função | Destino |
|---|---|---|
| `POST /converter-pdf` | XLSX/DOCX/PDF/HTML → PDF (LibreOffice/Ghostscript/Chromium) | Manter (interno à API) |
| `POST /salvar-pacote` | Grava o pacote na pasta do servidor | Manter (interno à API) |
| `POST /notificar-slack` | Alerta de NC no Slack (webhook em `.env`) | Manter |
| `POST /convidar-usuario` | Convite via Supabase Admin | **Remover** (vira SCM) |
| `GET /health`, `GET /`, `/plataforma.html` | Saúde + hospedagem do HTML | Substituído pelo deploy padrão |

**Integrações:** Supabase (Auth/DB/Storage), Slack (webhook), LibreOffice + Ghostscript +
Chromium (conversão de PDF, tudo local).

---

## 4. Frentes de migração (checklist objetivo)

**A. Autenticação → SCM**
- [ ] Remover Supabase Auth e toda tela de login/convite/senha.
- [ ] Ler `auth_token`/`auth_refresh_token`/`auth_user`/`auth_permissoes` do `localStorage`.
- [ ] `authFetch` injeta `Authorization: Bearer`; 401 → redireciona ao SCM.
- [ ] Rotas protegidas verificam token; permissões via `auth_permissoes` (3 níveis).
- [ ] Descontinuar `perfis`, `convites` e o endpoint `/convidar-usuario`.

**B. Banco → MySQL local**
- [ ] Recriar schema (seção 3) em MySQL; campos JSON → tipo `JSON`.
- [ ] Substituir RLS do Postgres por controle de acesso na API.
- [ ] Migrar dados existentes (com data de corte) preservando histórico e revisões.

**C. Arquivos → servidor local**
- [ ] Trocar o bucket por pasta no servidor; ajustar upload/download via API.
- [ ] Reaproveitar o serviço de conversão/gravação (já grava local).

**D. API REST própria** (`/SIGLA/api/v1/`, base em `src/config/api.ts`)
- [ ] Endpoints por módulo (ver seção 6), validando o Bearer do SCM.

**E. Frontend → stack padrão**
- [ ] Projeto Vite/TS com a estrutura de pastas padrão.
- [ ] React Query (leituras), RHF + Zod (formulários), Recharts (gráficos), Sonner (toasts).
- [ ] **Reaproveitar a lógica de negócio** (motor de análise, regras de cruzamento, geração
      do parecer/FORM-GQ-0047, versionamento de ficha, grupo alternativo, ajuste por ficha
      desatualizada) — é a parte mais valiosa e não depende do backend.

---

## 5. De-para de dados (Supabase → MySQL)

- Chaves `uuid` → manter `CHAR(36)`/`BINARY(16)` ou migrar para `BIGINT` (decisão do P&D).
- `jsonb` (Postgres) → `JSON` (MySQL): `analises.parecer_completo`,
  `fichas_mestres_versoes.snapshot`, regras/estágios das fichas, `acessorios.grupo_alternativo`.
- `timestamptz` → `DATETIME`/`TIMESTAMP` (padronizar timezone).
- Exportar via CSV/dump do Supabase e importar no MySQL; validar contagens por tabela.

---

## 6. Endpoints REST sugeridos (por módulo)

- `…/produtos` (CRUD do catálogo)
- `…/fichas` (CRUD + `…/fichas/{id}/versoes` para revisões e reverter)
- `…/analises` (criar, listar, obter, excluir; `…/analises/{id}/reanalisar`)
- `…/apontamentos` (por análise)
- `…/pacotes` (gerar/baixar; converte e grava no servidor)
- `…/logs` (gravar/consultar)
- `…/config` (pasta de destino etc.)
- `…/solicitacoes` (se mantido)
- `…/slack/notificar` (alerta de NC)

Autenticação: todos exigem `Authorization: Bearer` validado contra o SCM.

---

## 7. Sequenciamento sugerido

0. **BACKUP DO HISTÓRICO (fazer ANTES de qualquer alteração de regra):** exportar toda a
   tabela `logs_atividade` e guardar em local seguro. A plataforma já tem o botão
   **"Baixar histórico (XLSX)"** na aba *Histórico de alterações* (baixa todos os
   registros). Recomenda-se também um dump SQL/CSV completo da tabela. Motivo: a migração
   pode reestruturar regras/identidade (SCM) e a trilha de auditoria não pode ser perdida
   (rastreabilidade ISO 13485 / RDC 665). A tabela `logs_atividade` deve ser **migrada
   para o MySQL preservando os registros existentes** (autor, ação, data, descrição).
1. Definições com o dono do SCM (seção 9).
2. Backend REST + MySQL no ar (schema + endpoints).
3. Migração de dados (Supabase → MySQL) com data de corte — incluindo `logs_atividade`.
4. Frontend padrão consumindo a API e a sessão do SCM.
5. Arquivos para o servidor local.
6. Desligar Supabase (Auth/DB/Storage) e endpoints interinos.
7. Validação lado a lado (paridade de pareceres) antes de aposentar o interino.

---

## 8. Riscos e pontos de atenção

- **Rastreabilidade (ISO 13485 / RDC 665):** preservar histórico de análises, revisões de
  ficha e logs na migração.
- **Paridade de comportamento:** a nova versão deve reproduzir exatamente os pareceres atuais.
- **Assinatura digital:** manter o PDF sem restrições (assinável, ICP-Brasil).
- **Janela de corte** para migrar dados sem perder análises em andamento.
- **Permissões finas → 3 níveis do SCM** sem perder granularidade (ex.: excluir análise).
- **Segredos** (ex.: `service_role` do Supabase) deixam de existir; nada de credencial no frontend.

---

## 9. Decisões em aberto (para P&D / dono do SCM)

- [ ] Sigla/prefixo do sistema na API (ex.: `/GQCP/api/v1/`).
- [ ] Como o SCM expõe permissões e o mapeamento dos cargos/permissões atuais.
- [ ] Reescrever o frontend do zero na stack padrão (recomendado) vs. adaptar o HTML.
- [ ] Migrar dados históricos do Supabase ou iniciar base nova no MySQL.
- [ ] Manter `solicitacoes` (aprovações entre usuários) ou usar fluxo do SCM.
- [ ] Estratégia de tipos de chave (uuid vs. inteiro) no MySQL.
