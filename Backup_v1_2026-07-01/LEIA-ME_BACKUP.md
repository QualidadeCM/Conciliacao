# Backup v1 — Plataforma de Conciliação da Produção (pré-migração ao padrão Confiance)

**Data do backup:** 01/07/2026
**Motivo:** proteção antes da migração da arquitetura para o padrão oficial da Confiance Medical (React+TS+Vite+MySQL+SCM).

## Conteúdo

| Arquivo | O que é | Como usar |
|---|---|---|
| `plataforma.html` | Aplicação completa (React 18 inline + Babel-standalone). ~615 KB. | Abrir com duplo clique no navegador. Já é funcional sem servidor. |
| `AUDITORIA_PADRAO_CONFIANCE.md` | Documento auditando gap entre plataforma atual e padrão da empresa. | Referência para P&D. |
| `PROTOCOLO_AGENTE_CONCILIACAO.md` | Regras de negócio consolidadas do agente de conciliação. | Referência para reescrita — todos os critérios de análise estão aqui. |
| `GUIA_PLATAFORMA_HTML.md` | Documentação técnica da plataforma HTML atual. | Referência para P&D entender o arquivo. |
| `GUIA_GEMINI_EDGE_FUNCTION.md` | Documentação da Edge Function CloudConvert. | Referência para substituição por serviço on-premise. |
| `FORM-GQ-0047_Rev9_mapa_celulas.md` | Mapa das células do FORM-GQ-0047 (importante para o gerador de FORM). | Referência para reescrita do preenchimento automático. |
| `migration_estagios_com_inspecao.sql` | Última migration aplicada (01/07/2026). | Rodar no Supabase se restaurar do zero. |
| `Template_Fichas_Mestres.xlsx` | Template Excel para cadastro em massa das fichas mestres. | Referência do modelo de dados. |
| `FORM-GQ-0047-8_CheckList_Conciliacao_Fonte_de_Luz_Led.pdf` | Template original do formulário. | Referência do layout do FORM. |
| `Ficha_Mestre_CM-LED.pdf` | Exemplo de Ficha Mestre preenchida. | Referência do produto CM-LED. |
| `edge-function/` | Código da Edge Function `converter-para-pdf` no Supabase (CloudConvert). | Referência para reescrita on-premise. |
| `Plataforma-Conciliacao/` | Versões antigas/artefatos intermediários (se houver). | Histórico. |
| `dump_dados_supabase.sql` | **VOCÊ PRECISA GERAR** — passos abaixo. | Restauração dos dados. |

## Como restaurar em caso de emergência

### Restaurar código
1. Copie `plataforma.html` para uma pasta e abra no navegador. Funciona standalone.
2. Se precisar do banco: o `plataforma.html` está configurado com URL do Supabase embutida. Todos os dados continuam lá enquanto o projeto Supabase estiver ativo.

### Restaurar banco de dados (Supabase → MySQL ou Supabase novo)
1. Rode o script `dump_dados_supabase.sql` no Supabase Studio da instância ORIGINAL para gerar comandos INSERT com os dados atuais.
2. Salve o output como `dados.sql`.
3. Rode o `dados.sql` numa nova instância (Supabase ou MySQL) depois de criar as tabelas com o schema atual.

## Checklist para gerar o dump de dados no Supabase Studio

- [ ] Abrir Supabase Studio → SQL Editor
- [ ] Rodar cada query do arquivo `dump_dados_supabase.sql` uma por uma
- [ ] Copiar o resultado (que já vem em formato INSERT) e salvar em `dados_YYYY-MM-DD.sql`
- [ ] Guardar esse arquivo junto do backup

## Baixar arquivos do Supabase Storage

O sistema hoje guarda arquivos em 2 buckets:
- `pacotes-analise` — ZIPs finais das análises
- `form-templates` — Template do FORM-GQ-0047

Baixe todos os arquivos desses buckets manualmente no Supabase Studio → Storage e coloque numa pasta `storage_backup/` junto deste backup.

## Chave anon do Supabase

A URL e a chave `anon` estão hardcoded no `plataforma.html` na função `createClient`. **Isso não é segredo** (o anon key é público por design). O que precisa ficar seguro é o `service_role` key, que NÃO está em nenhum lugar do frontend.
