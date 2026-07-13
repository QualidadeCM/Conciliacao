# Plano de Migração — Plataforma de Conciliação da Produção

**Para:** P&D Software — Confiance Medical
**Solicitante:** Maria Luiza Zaccur (Garantia da Qualidade)
**Data:** 01/07/2026
**Objetivo:** Migrar a plataforma atual (arquivo HTML monolítico + Supabase) para o padrão oficial de desenvolvimento da Confiance (React 18 + TypeScript + Vite + shadcn/ui + MySQL local + integração SCM).

---

## 1. Contexto e visão geral

A plataforma de Conciliação da Produção é usada pela Garantia da Qualidade (QG) para validar automaticamente os documentos de fechamento de OPs (Ordem de Produção, RC, Etiquetas, FORM-GQ-0047) e emitir parecer técnico de liberação. O sistema já está em uso operacional e resolve o problema de negócio, mas foi desenvolvido fora do padrão oficial e agora precisa ser adequado.

**Escopo funcional (a preservar 100%):**
- Análise automática de OPs baseada em regras determinísticas (3 camadas — Camada 1 = validação técnica; Camada 2 = cruzamento de documentos; Camada 3 = anexos condicionais)
- Cadastro de Fichas Mestres com derivações, acessórios aplicáveis, roteiros de produção
- Cadastro do catálogo de 89 produtos
- Geração automática de FORM-GQ-0047 pré-preenchido
- Empacotamento em ZIP com OP + FORM + Parecer + Documentos originais convertidos em PDF
- Histórico completo com filtros, ordenação, re-análise com documentos corrigidos, justificativas de ressalvas
- Dashboard com métricas mensais/anuais e gráficos de conformidade
- Importação em massa de análises manuais (retroativas)
- Exportação consolidada para auditoria

---

## 2. Estado atual (o que existe)

### 2.1 Arquivos entregues no backup

Todos estão em `Backup_v1_2026-07-01/`:

| Arquivo | Descrição | Uso na migração |
|---|---|---|
| `plataforma.html` (615 KB, ~10.700 linhas) | Aplicação completa React 18 inline + Babel-standalone no browser | Fonte única de verdade da lógica de negócio — todos os regexes, parsers e regras estão aqui |
| `PROTOCOLO_AGENTE_CONCILIACAO.md` | Documento com todas as regras de negócio consolidadas | Referência canônica das regras a preservar |
| `AUDITORIA_PADRAO_CONFIANCE.md` | Comparativo item a item entre estado atual e padrão | Referência do gap |
| `dump_dados_supabase.sql` | Script para extrair dados atuais do Supabase | Migração de dados |
| `edge-function/` | Código da Edge Function `converter-para-pdf` (CloudConvert) | Referência para substituição |
| `migration_estagios_com_inspecao.sql` | Última migration aplicada | Contexto do schema atual |
| `Template_Fichas_Mestres.xlsx` | Template Excel para cadastro em massa | Preservar essa funcionalidade |
| `FORM-GQ-0047-8_CheckList_Conciliacao_Fonte_de_Luz_Led.pdf` | Template original do FORM | Recurso do gerador de FORM |
| `Ficha_Mestre_CM-LED.pdf` | Exemplo de ficha preenchida | Referência de dados |

### 2.2 Stack atual (o que NÃO é aderente)

**Frontend:**
- React 18 + JSX inline (SEM TypeScript)
- Babel-standalone compilando JSX em runtime no browser (warning: passou de 500KB, deoptimizando)
- Tailwind via CDN (sem build local)
- Componentes shadcn-like escritos manualmente (Card, Button, Input, Textarea, ToastProvider)
- Ícones inline em SVG (função `Icon` com dicionário)
- Roteamento: state manual + `window.location.hash`
- Estado: `useState` + chamadas diretas ao Supabase JS SDK
- Formulários: JSX controlado + validação ad-hoc
- Gráficos: Chart.js via CDN
- PDF/Excel: pdf.js, pdf-lib, ExcelJS, JSZip via CDN
- Executado com `file://` (duplo clique no arquivo abre no navegador)

**Backend:**
- Supabase (PostgreSQL nuvem + Storage + Auth + Edge Functions)
- Tabelas: `produtos`, `fichas_mestres`, `acessorios_aplicaveis`, `analises`, `analises_apontamentos`
- Buckets: `pacotes-analise`, `form-templates`
- Edge Function: `converter-para-pdf` chamando CloudConvert
- Auth próprio via Supabase Auth (tela de login própria)

### 2.3 Regras de negócio implementadas (não pode regredir)

**Parsers (heurísticos, com muitas OPs de referência já validadas):**
- `parseOP` — extrai da OP: número, série, produto, modelo, derivação, estágios, operações (com estagio_numero, inicio, fim, tempo, operador), inspeções detalhadas (numero, plano, inspetor, data, hora, status, estagio), medições críticas, componentes conferidos, aprovações. Formato do texto extraído pelo pdf.js UMD é MULTI-LINHA — regex atual capta `Estágio: NN Nome\nInspeção: NNNNNN N PLANO Status: XXX Usuário Inspeção: NOME\nData / Hora Exec. Plano: DD/MM/AAAA HH:MM`
- `parseRC` — extrai da Requisição de Componentes: número, código, descrição, quantidade, lote, aceita PDF/XLSX/CSV
- `parseEtiqueta` — extrai da etiqueta do produto: família, fabricante, CNPJ, endereço, telefone, RT, CREA, responsável legal, validade
- `parseEtiquetaAcessorio` — extrai de etiqueta de acessório: código, descrição, lote, validade, fabricante/fornecedor

**Cruzamentos (analisarConciliacao — Camadas 1/2/3):**
- Nº série: consistência entre OP, FORM, Etiqueta + convenção da Ficha
- Cronologia: estágios em ordem + inspeção do estágio N não pode ser posterior ao início de operações do estágio M>N
- Duplicatas: mesma inspeção 2× com inspetores diferentes → 2ª deve ser posterior
- Ficha × OP: estágios declarados com inspeção presentes + estágios fixos universais 50 (Embalagem) e 60 (Conciliação) + detecta faltas (NC) e extras (ressalva)
- Medições: aprovadas dentro do range Vlr_Min/Vlr_Max
- RC × Etiqueta acessório × Ficha: lógica de 4 categorias (obrigatório, opcional, fabricante Confiance, estéril, pode_sair_apenas_na_nf)
- Datas: fabricação Confiance vs data do lote; validade estéril; validade indeterminada
- OP de Reprocesso/RNC: guiado por anexo, não por tipo da OP

**Fluxos:**
- Upload de slots (OP + RC + Etiqueta produto + N × Etiqueta acessório + opcionalmente FORM já preenchido + OP Reprocesso + RNC)
- Análise → parecer com 3 camadas + apontamentos + resultado geral (conforme/ressalva/nao_conforme)
- Justificativa de ressalva pelo RT → re-classifica como conforme + recalcula resultado geral
- Correção de documento NC → re-análise reusando slots não corrigidos + arquivos do Storage
- Empacotamento em ZIP: OP+FORM(XLSX+PDF)+Parecer(PDF)+demais docs convertidos para PDF via CloudConvert
- Bloqueio de download quando há bloqueador/ressalva sem justificativa
- Bloqueio de análise duplicada (OP+Série já analisada)
- Bloqueio de importação de produto sem Ficha Mestre

**Filtros/relatórios:**
- Histórico: filtros por data, mês/ano, equipamento, modelo (encadeado), origem (agente/manual), correções, busca textual
- Ordenação clicável nas colunas
- Cabeçalho sticky no scroll
- Dashboard: cards agregados, gráfico donut de conformidade, gráfico de erros por tipo de equipamento, últimas análises, breakdown de correções, exportação em PDF por gráfico
- Exportação consolidada para auditoria (múltiplas análises → ZIP unificado)
- Importação em massa de análises manuais retroativas (XLSX)

**Estágios do processo produtivo:**
- **Variáveis** (a ficha declara aplicáveis): 5 Separação, 7 Preparação Componentes, 10 Montagem, 15 Fechamento Tela, 20 Prep. Gabinete, 25 Fech.+Acab. Gabinete Plástico, 30 Montagem Eletrônica, 35 Programação, 39 Gravação, 40 Finalização
- **Fixos** (todo produto): CQ produto acabado, Embalagem, Conciliação, Verificação da rotulagem
- **Condicionais** (só se anexado): OP de Reprocesso, RNCs
- **Com inspeção obrigatória universal**: 50, 60 (regra global 01/07/2026)

---

## 3. Padrão alvo (o que deve virar)

Conforme "PADRÃO DE DESENVOLVIMENTO DE SISTEMAS — CONFIANCE MEDICAL":

**Frontend:**
- React 18 + TypeScript (TSX)
- Vite + `@vitejs/plugin-react-swc`
- Tailwind CSS (build local)
- shadcn/ui (Radix UI)
- lucide-react
- React Router DOM v6
- TanStack React Query v5
- React Hook Form + Zod
- Recharts
- Sonner + shadcn Toaster
- Aliases: `@/` → `src/`

**Backend:**
- MySQL local no servidor da empresa
- API REST com prefixo `/CONC/api/v1/` (sugerido)
- URL base em `src/config/api.ts`
- Autenticação delegada ao SCM (ler `auth_token` do localStorage + `authFetch` + redirect ao SCM em 401)
- Storage de arquivos em servidor local (endpoint próprio de upload/download)

**Estrutura de pastas:**
```
src/
├── components/           # UI reutilizável (Card, Button, etc. via shadcn)
├── config/
│   └── api.ts            # URLs e endpoints
├── contexts/             # Contextos sem AuthContext próprio
├── hooks/                # Custom hooks (ex.: useAnalises, useProdutos)
├── lib/                  # Utils (formatDate, parseNumeroSerie, etc.)
├── pages/
│   ├── dashboard/
│   ├── analise/
│   ├── historico/
│   └── cadastro/
└── services/
    └── api/
        ├── analises.ts
        ├── produtos.ts
        ├── fichas.ts
        └── uploads.ts
```

---

## 4. Fases sugeridas

### Fase 0 — Preparação (2 dias)
- Provisionar servidor MySQL local
- Provisionar servidor de aplicação (Node/nginx) para servir o build Vite
- Confirmar URL e credenciais do SCM (login, logout, endpoint que valida token)
- Verificar disponibilidade de alternativa on-premise ao CloudConvert (LibreOffice headless recomendado)
- Definir prefixo da API (`/CONC/api/v1/` sugerido)
- Criar repositório Git do novo projeto

### Fase 1 — Fundação do frontend (3-4 dias)
- `npm create vite@latest plataforma-conciliacao -- --template react-ts`
- Configurar Tailwind, path aliases `@/`, ESLint, Prettier
- Instalar shadcn/ui, lucide-react, TanStack Query, React Hook Form, Zod, Recharts, Sonner
- Configurar `src/config/api.ts`
- Configurar rotas base com React Router DOM v6
- Criar layout base (Sidebar + main) usando componentes shadcn
- Definir contratos TypeScript das entidades: `Analise`, `Produto`, `FichaMestre`, `Acessorio`, `Apontamento`, `SlotUpload`, `Parecer`, `Camada`, `Cronologia`

### Fase 2 — Autenticação SCM (2 dias)
- Substituir tela de login própria por leitura do `auth_token` do localStorage
- Implementar `authFetch(url, options)` que injeta Bearer token
- Criar hook `useAuth()` que lê `auth_user` e `auth_permissoes`
- Criar `<Protected level={n}>` que checa nível (1 usuário / 2 admin / 3 gestor)
- Interceptor 401 → redirect para SCM
- Remover código Supabase Auth por completo

### Fase 3 — Backend REST + MySQL (2-3 semanas)
- Modelar schema MySQL equivalente ao Supabase atual:
  - `produtos` (id, equipamento, modelo, codigo_referencia, codigo_sapiens, registro_anvisa, ativo, created_at)
  - `fichas_mestres` (todos os campos atuais + `estagios_aplicaveis` como TEXT/JSON, `estagios_com_inspecao` como JSON)
  - `acessorios_aplicaveis`
  - `analises` (com `parecer_completo` como JSON/LONGTEXT)
  - `analises_apontamentos`
  - `pacotes_analise` (metadata dos ZIPs)
  - `arquivos_analise` (referência aos arquivos no filesystem)
- Endpoints REST (ver seção 5)
- Salvar arquivos no filesystem local em `/var/conciliacao/uploads/` com paths versionados por data
- Substituir Edge Function CloudConvert por LibreOffice headless (ex.: `libreoffice --headless --convert-to pdf`)
- Log de auditoria: tabela `audit_log` com quem alterou o quê (compliance ISO 13485)

### Fase 4 — Migração de dados (2 dias)
- Rodar `dump_dados_supabase.sql` no Supabase Studio para gerar inserts
- Adaptar sintaxe PostgreSQL → MySQL onde necessário (jsonb → JSON, quote functions)
- Baixar manualmente todos os arquivos dos buckets `pacotes-analise` e `form-templates`
- Copiar para o servidor local
- Rodar imports no MySQL local
- Validar contagens (esperado: ~89 produtos, ~40+ fichas parciais, dezenas de análises)
- Testar re-análise e download de pacotes com dados migrados

### Fase 5 — Reescrita da UI (2-3 semanas)
Migrar cada módulo para `.tsx` com React Query + shadcn/ui:
- `pages/dashboard/` — DashboardPage, com Recharts substituindo Chart.js
- `pages/analise/` — AnalisePage (upload de slots), ParecerView
- `pages/historico/` — HistoricoPage com filtros, ordenação, sticky header, import/export
- `pages/cadastro/` — CatalogoTab, FichasTab, ProdutoSelectorModal, FichaMestreEditor
- Componentes compartilhados em `components/`: DocumentoSlot, ApontamentoCard, ResumoStat, EmptyState, etc.
- Migrar toda a lógica de negócio (parseOP, parseRC, parseEtiqueta, parseEtiquetaAcessorio, analisarConciliacao, fillFormXlsxTemplate, gerarParecerPDF) preservando os algoritmos exatos
- Substituir ToastProvider próprio por Sonner
- Substituir ícones inline por lucide-react
- Migrar geração de ZIP mantendo JSZip
- Formulários com React Hook Form + Zod (schemas por entidade)

### Fase 6 — Backup automatizado (2 dias)
- Endpoint `POST /CONC/api/v1/backup/executar` gera XLSX consolidado
- Cron mensal (dia 1) no servidor chama o endpoint + envia por e-mail via SMTP interno para `qualidade@confiancemedical.com.br`
- Anexo XLSX + resumo textual (total de análises, período coberto, hash SHA-256 do arquivo)
- Log da execução do cron em `audit_log`

### Fase 7 — Corte, validação e desligamento (1 semana)
- Deploy em ambiente de homologação
- Validação com Maria Luiza (QG) usando OPs de referência: 6673, 7318, 7430, 7436, 7499, 6819
- Rodar dual-write por 3-5 dias (novas análises entram nas duas versões) para comparar resultados
- Após validação: cortar tráfego para a nova versão
- Desligar projeto Supabase
- Atualizar documentação (README, guia de operação, guia de manutenção)

---

## 5. Endpoints REST sugeridos

| Método | Endpoint | Descrição |
|---|---|---|
| GET | `/CONC/api/v1/produtos` | Lista produtos ativos |
| POST | `/CONC/api/v1/produtos` | Cria produto |
| PUT | `/CONC/api/v1/produtos/:id` | Atualiza produto |
| DELETE | `/CONC/api/v1/produtos/:id` | Soft delete |
| GET | `/CONC/api/v1/fichas-mestres` | Lista fichas ativas com JOIN produto |
| GET | `/CONC/api/v1/fichas-mestres/:id` | Detalhes de uma ficha (com acessórios) |
| POST | `/CONC/api/v1/fichas-mestres` | Cria ficha |
| PUT | `/CONC/api/v1/fichas-mestres/:id` | Atualiza ficha (substitui acessórios) |
| DELETE | `/CONC/api/v1/fichas-mestres/:id` | Exclui ficha |
| GET | `/CONC/api/v1/analises` | Lista análises (com filtros por query params) |
| GET | `/CONC/api/v1/analises/:id` | Detalhes de análise |
| POST | `/CONC/api/v1/analises` | Salva nova análise |
| PATCH | `/CONC/api/v1/analises/:id/justificar` | Registra justificativa em apontamento |
| POST | `/CONC/api/v1/analises/importar` | Importa em massa (XLSX de análises manuais) |
| POST | `/CONC/api/v1/uploads` | Upload de arquivo → retorna path armazenado |
| GET | `/CONC/api/v1/uploads/:path` | Download de arquivo |
| POST | `/CONC/api/v1/converter/pdf` | Converte DOCX/XLSX para PDF (LibreOffice headless) |
| POST | `/CONC/api/v1/backup/executar` | Gera XLSX de backup e envia por e-mail |
| GET | `/CONC/api/v1/dashboard/metricas` | Métricas agregadas para o Dashboard |

Todas as rotas exigem Bearer token JWT do SCM. 401 → redirect SCM.

---

## 6. Estimativas

| Fase | Duração | Dependências |
|---|---|---|
| 0 — Preparação | 2 dias | Infra + P&D |
| 1 — Fundação frontend | 3-4 dias | P&D |
| 2 — Auth SCM | 2 dias | SCM em produção |
| 3 — Backend REST + MySQL | 2-3 semanas | P&D + Infra |
| 4 — Migração dados | 2 dias | Fase 3 concluída |
| 5 — Reescrita UI | 2-3 semanas | Fase 1 e 3 concluídas |
| 6 — Backup automatizado | 2 dias | Fase 3 concluída + SMTP interno |
| 7 — Corte e validação | 1 semana | Todas anteriores + validação QG |
| **Total** | **~6-8 semanas** | |

---

## 7. Riscos e mitigações

1. **Regressão nas regras de negócio.**
   - **Mitigação:** criar suíte de testes automatizados com as OPs de referência (6673, 7318, 7430, 7436, 7499, 6819) ANTES de migrar. Cada teste roda `analisarConciliacao` e valida os apontamentos esperados. Sem essa suíte, migrar cegamente é alto risco.

2. **CloudConvert como dependência externa.**
   - **Mitigação:** validar LibreOffice headless com as OPs reais antes do corte (Fase 3). Se não gerar PDFs equivalentes, procurar alternativa (aspose, gotenberg, etc.).

3. **Migração de dados corrompida.**
   - **Mitigação:** dual-write por 3-5 dias após corte + hash de comparação. Regulatório exige rastreabilidade — nenhuma análise pode ser perdida.

4. **Storage: milhares de PDFs anexados às análises.**
   - **Mitigação:** script paralelo que baixa tudo do Supabase antes do corte + verifica integridade por hash antes de subir no filesystem local.

5. **Falta de testes automatizados hoje.**
   - **Mitigação:** aproveitar a Fase 1 pra criar Vitest + testes das funções de parse + integração. Sem isso a Fase 5 vira aventura.

6. **Formato do texto extraído pelo pdf.js UMD (browser) é diferente do pdf.js legacy (Node).**
   - **Mitigação:** documentado no `plataforma.html` que o formato real do PDF vem multi-linha (`Estágio: NN\nInspeção: NNN N PLANO Status: XXX Usuário Inspeção: NOME\nData / Hora...`). Preservar exatamente esse regex ao reescrever.

7. **Janela de indisponibilidade no corte final.**
   - **Mitigação:** avisar QG com 1 semana de antecedência. Corte fora do horário comercial + rollback plan documentado.

---

## 8. Checklist de aceite (final da migração)

- [ ] Todas as 6 OPs de referência passam nos testes automatizados com resultado idêntico à versão v1
- [ ] Todos os 89 produtos do catálogo estão no MySQL local
- [ ] Todas as fichas mestres pré-cadastradas estão preservadas
- [ ] Histórico completo migrado (mesmo total de linhas + parecer_completo idêntico)
- [ ] Arquivos anexados (ZIPs de pacote, documentos originais) todos baixáveis
- [ ] Autenticação 100% via SCM (nenhum código de login próprio)
- [ ] LibreOffice headless gera PDFs equivalentes aos do CloudConvert
- [ ] Backup mensal automatizado enviado para `qualidade@confiancemedical.com.br` no dia 1
- [ ] Dashboard mostra mesmos números (sanity check)
- [ ] QG (Maria Luiza) valida com 3-5 OPs reais em produção
- [ ] Documentação (README + guia de manutenção) atualizada
- [ ] Projeto Supabase pode ser desligado

---

## 9. Perguntas abertas para o P&D

1. Qual é a URL do SCM em produção? Existe documentação da integração?
2. Existe algum outro sistema satélite Confiance funcionando com o padrão? (Se sim, quero copiar a estrutura.)
3. Onde ficarão hospedados: front (build Vite estático) e back (API REST)?
4. Confiance tem SMTP interno para envio do backup? Qual servidor/porta/credencial?
5. Existe restrição de licenciamento para LibreOffice server-side?
6. Confiance tem CI/CD estabelecido? Vou usar o mesmo pipeline?
7. Existe padrão de logs e monitoramento (Grafana? ELK?) que eu preciso integrar?
8. Existe padrão de versionamento (SemVer? CalVer?) para o release do sistema?

---

## 10. Contato

**Maria Luiza Zaccur** — Garantia da Qualidade
📧 mzaccur@confiancemedical.com.br

Backup completo do sistema atual disponível em `Backup_v1_2026-07-01/`.
