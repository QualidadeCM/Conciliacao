# Especificação Técnica — Gravação do Pacote na Pasta da OP + Conversão de PDF Local

**Sistema:** Plataforma de Conciliação da Produção — Confiance Medical
**Destinatário:** P&D Software
**Autoria:** Garantia da Qualidade (Maria Luiza)
**Data:** 06/07/2026
**Contexto:** Documento para a migração da stack (Supabase → backend local MySQL + REST), abrangendo duas mudanças de metodologia do "pacote" da análise.

---

## 1. Objetivo

Hoje, ao concluir uma análise, a plataforma monta um pacote `.zip` no navegador e o usuário salva manualmente. Além disso, a conversão de documentos para PDF depende de um serviço de nuvem (CloudConvert). Esta especificação define duas mudanças:

1. **Gravar automaticamente a OP preenchida e o FORM-GQ-0047 (e demais itens do pacote) na pasta que já existe para cada OP em um caminho do servidor**, em vez de depender do download manual do ZIP.
2. **Substituir o CloudConvert por conversão local** (LibreOffice/Chromium headless no servidor), gerando PDF sem restrições — assinável e editável no Adobe Acrobat — sem enviar documentos para a nuvem.

Ambas as funções **não podem ser feitas pelo navegador** (o front web não escreve em caminho de servidor nem aciona conversores locais). Portanto, são responsabilidade do **backend REST local** a ser construído na migração.

---

## 2. Alinhamento com o padrão da empresa

Esta especificação segue o padrão de desenvolvimento interno:

- **Persistência:** MySQL local do servidor; arquivos gravados no filesystem do servidor local. **Nenhum dado ou documento persistente ou transitório vai para a nuvem** — o que já corrige o uso atual do CloudConvert, que envia os documentos do lote para um serviço externo.
- **API:** REST, sob o prefixo do sistema (usar `/CONC/api/v1/…` ou o prefixo definido para este sistema).
- **Autenticação:** delegada ao **SCM**. Todo endpoint valida o **Bearer token (JWT)** do header `Authorization`. Sem token válido → `401` (o front redireciona ao SCM). Permissões lidas de `auth_permissoes`.
- **Sem autenticação própria neste sistema.**

---

## 3. Estado atual (para referência)

- App 100% no navegador (`plataforma.html`) sobre Supabase.
- Pacote montado no cliente com **JSZip**, baixado como `OP_<op>_<serie>.zip` via File System Access API.
- Conversão via edge function **`converter-para-pdf`** que chama o **CloudConvert**:
  - Office (`xlsx`/`docx`) → PDF (engine LibreOffice).
  - PDF de entrada (OP do Sapiens) → operação `optimize` (qpdf/ghostscript) que **regenera o PDF sem as restrições embutidas pelo Sapiens**, habilitando assinatura/edição no Adobe.
  - HTML (Resumo da Análise) → PDF (engine Chromium, para respeitar o CSS).

### 3.1 Conteúdo e nomenclatura atuais do pacote

Pasta raiz do pacote: `OP_<numeroOP>_<numeroSerie>` (ex.: `OP_7541_CMST-20266-6`). Dentro dela:

| Arquivo | Origem | Formato hoje |
|---|---|---|
| `FORM-GQ-0047_<op>_<serie>.pdf` | XLSX gerado pela plataforma → convertido | PDF (assinável) |
| `OP_<op>_<serie>_preenchida.pdf` | PDF do Sapiens anotado com ✓ verde (pdf-lib) → re-convertido p/ remover restrições | PDF (assinável) |
| `RC_<op>.pdf` | Original do Sapiens | PDF |
| `Etiqueta_Externa_<modelo>.docx` | Original | DOCX |
| `Etiquetas_Acessorios/<nome>.docx` | Originais (subpasta) | DOCX |
| `OP_Reprocesso_<op>.pdf` | Original (se houver) | PDF |
| `RNC_<op>.pdf` | Original (se houver) | PDF |
| `FORM-GQ-0047_<op>_manual.pdf` | Anexado manualmente (se houver) | PDF |
| `Resumo_Analise_<base>.pdf` | HTML gerado pela plataforma → convertido | PDF |
| `_AVISOS.txt` | Gerado (se houver avisos) | TXT |

A nomenclatura acima deve ser **preservada** na gravação no servidor.

---

## 4. Escopo A — Conversão de PDF local (substituir CloudConvert)

Criar um serviço/endpoint de conversão que seja **drop-in** do contrato atual, para minimizar mudança no front.

### 4.1 Endpoint

```
POST /CONC/api/v1/converter-pdf
Headers:
  Authorization: Bearer <jwt do SCM>
  Content-Type: application/octet-stream
  X-Source-Format: xlsx | docx | pdf | html   (formato de entrada)
  X-Filename: FORM-GQ-0047_7541_CMST-20266-6.xlsx
Body: bytes brutos do arquivo
Resposta 200: Content-Type: application/pdf, body = bytes do PDF
Resposta 4xx/5xx: application/json { "error": "..." }
```

Mantém o mesmo contrato da edge function atual (mesmos headers `X-Source-Format`/`X-Filename`), então o front só troca a URL base e o cabeçalho de auth.

### 4.2 Motores de conversão por tipo de entrada

| Entrada | Ação no servidor | Ferramenta sugerida | Resultado exigido |
|---|---|---|---|
| `xlsx` / `docx` | Converter para PDF | **LibreOffice headless**: `soffice --headless --convert-to pdf --outdir <tmp> <arquivo>` | PDF sem senha/restrições, assinável |
| `pdf` (OP do Sapiens) | **Re-gerar** o PDF removendo restrições/proteções embutidas | **Ghostscript**: `gs -o saida.pdf -sDEVICE=pdfwrite -dPDFSETTINGS=/prepress entrada.pdf` (ou `qpdf --decrypt`) | PDF sem restrição de edição/assinatura; visual preservado |
| `html` (Resumo) | Renderizar com CSS moderno → PDF | **Chromium headless** (`--headless --print-to-pdf`, A4 retrato, `print_background`) ou wkhtmltopdf | PDF fiel ao design (cores/layout). LibreOffice **não** serve aqui (CSS fraco) |

**Requisitos do PDF de saída (crítico para o Adobe):** sem criptografia, sem senha de permissões, sem flags de restrição de edição/assinatura. É o que hoje o CloudConvert garante e o que permite a assinatura digital (ICP-Brasil) e edição no Acrobat.

**Sobre o Adobe "imprimir em PDF":** não é automatizável de forma robusta em servidor (exige licença e é frágil). O LibreOffice usa a **mesma engine** que o CloudConvert já usava para Office, e o Ghostscript/qpdf resolve a remoção de restrições do Sapiens. Recomenda-se esse conjunto em vez de automação do Acrobat.

### 4.3 Observação sobre a anotação da OP (✓ verde)

A OP recebe os ✓ verdes nos colchetes via **pdf-lib no próprio navegador** (isso pode continuar no front). O front então envia o **PDF já anotado** para `/converter-pdf` com `X-Source-Format: pdf`, e o backend faz o passo de remoção de restrições. Alternativamente, mover a anotação para o backend — decisão do P&D; o comportamento atual (anotar no front) funciona e pode ser mantido.

---

## 5. Escopo B — Gravação do pacote na pasta da OP no servidor

### 5.1 Endpoint

```
POST /CONC/api/v1/pacote/salvar
Headers:
  Authorization: Bearer <jwt do SCM>
  Content-Type: multipart/form-data
Campos (form-data):
  numero_op:    "7541"
  numero_serie: "CMST-20266-6"
  modelo:       "CM-STATION"
  analise_id:   <id da análise>            (para rastreabilidade)
  arquivos[]:   um ou mais arquivos, cada um com o nome final já definido
                (ex.: OP_7541_CMST-20266-6_preenchida.pdf,
                       FORM-GQ-0047_7541_CMST-20266-6.pdf, ...)
Resposta 200: { "ok": true, "pasta": "<caminho relativo/aboluto gravado>", "arquivos_gravados": [ ... ] }
Resposta 4xx/5xx: { "error": "..." }
```

O front reaproveita a mesma montagem de arquivos que hoje entra no ZIP (Seção 3.1) e, em vez de zipar, envia os arquivos para este endpoint.

### 5.2 Resolução da pasta da OP (DEFINIDO)

- **Caminho-base (configurável, com ano corrente dinâmico):**
  ```
  H:\REGISTROS DO SISTEMA DE GESTÃO DA QUALIDADE\<ANO>\GARANTIA DA QUALIDADE DE PRODUTOS PRODUZIDOS\Origem 070
  ```
  onde `<ANO>` é o **ano corrente** (ex.: em 2026 → `...\2026\...`). O ano deve ser resolvido dinamicamente na hora da gravação (não hardcode).

- **Nome da pasta da OP:** sempre no formato
  ```
  OP_<numeroOP>_<numeroSerie>
  ```
  Exemplo: OP 7359, série `SCFHDT-20265-6` → pasta `OP_7359_SCFHDT-20265-6`.
  (Coincide com o nome da raiz do pacote já usado hoje — Seção 3.1.)

- **Caminho final de gravação:**
  ```
  H:\REGISTROS DO SISTEMA DE GESTÃO DA QUALIDADE\<ANO>\GARANTIA DA QUALIDADE DE PRODUTOS PRODUZIDOS\Origem 070\OP_<numeroOP>_<numeroSerie>\
  ```

- **A pasta deve existir previamente.** O backend **não cria** a pasta automaticamente. Se a pasta não existir, retornar erro (`404`/`409`) com mensagem clara (ex.: *"Pasta da OP não encontrada: OP_7359_SCFHDT-20265-6. Crie a pasta antes de salvar o pacote."*). Ver Seção 5.2.1.

#### 5.2.1 Erro quando a pasta não existe

```
Resposta 409: { "error": "Pasta da OP não encontrada", "pasta_esperada": "OP_7359_SCFHDT-20265-6", "caminho_base": "H:\\...\\2026\\...\\Origem 070" }
```

### 5.3 Política de sobrescrita (DEFINIDO)

- **Sobrescrever** os arquivos existentes com o mesmo nome (mantém sempre a versão mais recente). Não versionar.
- Ainda assim, registrar em log/auditoria cada sobrescrita (arquivo, usuário, data/hora) para rastreabilidade.

### 5.4 Segurança e permissões

- Validar JWT do SCM em toda chamada; `401` se ausente/inválido.
- Restringir gravação a usuários com **nível de permissão adequado** (ler de `auth_permissoes`). **Nível mínimo ainda a definir pela QG** — deixar o valor configurável (ex.: constante/config `NIVEL_MINIMO_SALVAR_PACOTE`).
- Validar `numero_op`/`numero_serie` (sanitizar contra path traversal — não permitir `..`, barras, etc. no nome).
- Registrar em log/auditoria quem gravou, quando, quais arquivos e em qual pasta (rastreabilidade ISO 13485 §4.2.5).

---

## 6. Fluxo alvo (resumo)

1. Analista conclui a análise na plataforma.
2. Front gera os artefatos (OP anotada, FORM XLSX, Resumo HTML) como hoje.
3. Front chama `POST /CONC/api/v1/converter-pdf` para cada item que precisa virar PDF (FORM, OP, Resumo) — **conversão local, sem nuvem**.
4. Front chama `POST /CONC/api/v1/pacote/salvar` com todos os arquivos finais → backend grava na **pasta da OP no servidor**.
5. (Opcional) Manter o botão "Baixar ZIP" como alternativa, reaproveitando os mesmos PDFs.

---

## 7. Impacto no frontend (o que muda)

- Trocar a URL da conversão (de `.../functions/v1/converter-para-pdf` para `/CONC/api/v1/converter-pdf`) e usar o `authFetch`/Bearer do SCM. Contrato idêntico → mudança mínima.
- Adicionar a chamada de gravação (`/pacote/salvar`) no fluxo de conclusão, reutilizando a coleta de arquivos que hoje alimenta o ZIP (função `handleDownloadZip` em `plataforma.html`).
- Remover a dependência do CloudConvert (edge function e secret `CLOUDCONVERT_API_KEY`).

---

## 8. Dependências novas a instalar no servidor

- **LibreOffice** (headless) — conversão Office→PDF.
- **Ghostscript** e/ou **qpdf** — remoção de restrições em PDFs do Sapiens.
- **Chromium headless** (ou wkhtmltopdf) — HTML→PDF do Resumo com fidelidade de CSS.

---

## 9. Checklist de aceite

- [ ] `POST /converter-pdf` converte `xlsx`/`docx`/`pdf`/`html` para PDF **sem restrições**, assinável no Adobe (validar com ICP-Brasil).
- [ ] PDF do Sapiens (OP) passa a permitir edição/assinatura após o processamento.
- [ ] Resumo HTML sai com layout/cores corretos.
- [ ] `POST /pacote/salvar` grava todos os arquivos na pasta correta da OP, com a nomenclatura da Seção 3.1.
- [ ] Pasta resolvida como `<base>\<ANO corrente>\...\Origem 070\OP_<op>_<serie>`; erro `409` se não existir (não cria).
- [ ] Arquivos existentes são sobrescritos; sobrescrita registrada em auditoria.
- [ ] JWT do SCM validado; permissões respeitadas; auditoria registrada.
- [ ] Nenhum documento trafega para serviços de nuvem.

---

## 10. Definições da QG

| # | Item | Definição |
|---|---|---|
| 1 | Nome da pasta da OP | `OP_<numeroOP>_<numeroSerie>` (ex.: `OP_7359_SCFHDT-20265-6`) |
| 2 | Caminho-base | `H:\REGISTROS DO SISTEMA DE GESTÃO DA QUALIDADE\<ANO corrente>\GARANTIA DA QUALIDADE DE PRODUTOS PRODUZIDOS\Origem 070` |
| 3 | Sobrescrita | Sobrescrever arquivos existentes (sem versionar) |
| 4 | Nível de permissão mínimo | **A definir** — deixar configurável |
| 5 | Pasta inexistente | Exigir criação prévia; backend retorna erro, não cria |
