# Conversor PDF Local — Confiance Medical

Serviço local que substitui o **CloudConvert** na Plataforma de Conciliação da Produção.
Converte, no **servidor da empresa** (sem nuvem), os documentos do pacote para PDF:

| Entrada | Motor | Uso na plataforma |
|---|---|---|
| `xlsx` / `docx` | LibreOffice headless | FORM-GQ-0047 (XLSX → PDF) |
| `pdf` | Ghostscript (regenera sem restrições) | OP do Sapiens → PDF assinável no Adobe |
| `html` | Chromium headless (puppeteer) | Resumo/Parecer (HTML → PDF com layout) |

RC entra no pacote como PDF original; as **etiquetas continuam em Word (.docx)**.

O serviço expõe o **mesmo contrato** da antiga Edge Function, então a plataforma só troca a URL.

---

## 1. Pré-requisitos no servidor (Windows)

Instalar uma vez:

1. **Node.js 18 ou superior** — https://nodejs.org (versão LTS).
2. **LibreOffice** — https://www.libreoffice.org/download . Após instalar, garanta que o `soffice.exe` esteja acessível (normalmente em `C:\Program Files\LibreOffice\program\`). Se não estiver no PATH, defina a variável `SOFFICE_BIN` (ver seção 4).
3. **Ghostscript (64 bits)** — https://ghostscript.com/releases/gsdnld.html . O executável é `gswin64c.exe`. Se não estiver no PATH, defina `GHOSTSCRIPT_BIN`.

> O Chromium usado no HTML→PDF é baixado automaticamente pelo `puppeteer` no passo de instalação.

---

## 2. Instalação

Abra o **Prompt de Comando** na pasta `conversor-pdf-local` e rode:

```
npm install
```

Isso baixa as dependências (express, cors, libreoffice-convert, puppeteer + Chromium).

---

## 3. Executar

```
npm start
```

Deve aparecer:

```
Conversor PDF local ouvindo em http://0.0.0.0:3001
```

Teste no navegador do servidor: `http://localhost:3001/health` → deve responder `{ "ok": true, ... }`.

---

## 4. Variáveis de ambiente (opcionais)

| Variável | Default | Para quê |
|---|---|---|
| `PORT` | `3001` | Porta HTTP do serviço |
| `GHOSTSCRIPT_BIN` | `gswin64c` (Win) / `gs` (Linux) | Caminho do Ghostscript se não estiver no PATH |
| `SOFFICE_BIN` | auto | Caminho do `soffice.exe` se não estiver no PATH |

Exemplo (Prompt de Comando), caso precise apontar os caminhos:

```
set GHOSTSCRIPT_BIN=C:\Program Files\gs\gs10.03.1\bin\gswin64c.exe
set SOFFICE_BIN=C:\Program Files\LibreOffice\program\soffice.exe
npm start
```

---

## 5. Deixar no ar sempre (serviço do Windows)

Para o serviço subir sozinho com o servidor, use o **PM2** (gerenciador de processos Node):

```
npm install -g pm2 pm2-windows-startup
pm2-startup install
pm2 start server.js --name conversor-pdf
pm2 save
```

A partir daí o serviço reinicia automaticamente ao ligar o servidor. Comandos úteis:
`pm2 logs conversor-pdf` (ver logs), `pm2 restart conversor-pdf`, `pm2 stop conversor-pdf`.

---

## 6. Apontar a plataforma para este serviço

No `plataforma.html`, na seção de configuração (perto de `SUPABASE_URL`), existe a constante:

```js
const CONVERSAO_PDF_LOCAL = 'http://IP_DO_SERVIDOR:3001/converter-pdf';
```

- Troque `IP_DO_SERVIDOR` pelo IP do servidor na rede interna (ex.: `http://192.168.0.10:3001/converter-pdf`).
- Se a plataforma rodar **no próprio servidor**, pode usar `http://localhost:3001/converter-pdf`.
- Deixe em branco (`''`) para voltar a usar o CloudConvert.

A plataforma tenta o serviço local primeiro e, se ele estiver fora do ar, **cai automaticamente no CloudConvert** (fallback), para não travar o download do pacote.

---

## 7. Rede / Firewall

- Libere a porta (ex.: 3001) no firewall do servidor para a rede interna.
- O serviço é **HTTP** e de uso **interno**. Não exponha para a internet.
- Se a plataforma for servida por **HTTPS** e o serviço por HTTP, o navegador pode bloquear "mixed content". Nesse caso, sirva a plataforma por HTTP na rede interna, ou coloque o serviço atrás de um proxy HTTPS. (Confirmar com o P&D na migração definitiva.)

---

## 8. Observações

- Nenhum documento sai da rede da empresa — alinhado às regras de armazenamento do SGQ.
- O PDF gerado é **sem criptografia/restrições**, compatível com assinatura digital (ICP-Brasil) no Adobe Acrobat.
- Este serviço é a versão interina da conversão descrita em `ESPEC_PD_PACOTE_SERVIDOR_E_PDF_LOCAL.md`; na migração, o P&D pode incorporá-lo ao backend REST oficial.

---

## 9. Salvar pacote como pasta + Convite de usuários (v1.2)

Novas dependências no serviço:
```
npm install adm-zip @supabase/supabase-js
```

Variáveis de ambiente adicionais (para o convite de usuários por e-mail):
- `SUPABASE_URL` — URL do projeto Supabase.
- `SUPABASE_SERVICE_ROLE_KEY` — chave **service_role** (Supabase → Settings → API). Mantenha SOMENTE no servidor; nunca no navegador.

Exemplo (Prompt de Comando) e restart pegando as variáveis:
```
set SUPABASE_URL=https://SEU-PROJETO.supabase.co
set SUPABASE_SERVICE_ROLE_KEY=eyJ... (service_role)
pm2 restart conversor-pdf --update-env
```

Endpoints novos:
- `POST /salvar-pacote` (X-Extract: true → grava o pacote como PASTA, não .zip).
- `POST /convidar-usuario` (usa a service_role para inviteUserByEmail + grava perfil/convite).
- `POST /notificar-slack` (posta um alerta de NC no canal do Slack — ver seção 10).

No Supabase, rode a migration `migration-usuarios-permissoes-logs.sql` e configure em Authentication → URL Configuration o **Site URL / Redirect URLs** apontando para o endereço da plataforma (para o link do convite funcionar).

---

## 10. Alerta de NC no Slack (v1.3)

Na tela do parecer, quando há **não conformidades**, aparece o botão **"Enviar NC ao Slack"**.
Ele monta a mensagem (OP, série, modelo e, para cada NC, o documento a corrigir + o
responsável) e pede ao serviço para postar no canal. Regra de responsável:
- **Etiquetas** (externa/acessório) → **Almoxarifado**;
- **OP, RC, FORM, reprocesso, RNC** → **PCP**.

Configuração (uma vez):

1. No Slack: **crie um Incoming Webhook** para o canal desejado
   (https://api.slack.com/messaging/webhooks → *Create an app* → *Incoming Webhooks* →
   *Add New Webhook to Workspace* → escolha o canal). Copie a URL
   `https://hooks.slack.com/services/T.../B.../xxxx`.
   > Só adicionar o app do Claude ao canal **não** basta: o serviço precisa dessa URL de webhook.
2. No servidor, no `.env` do serviço, acrescente a linha:
   ```
   SLACK_WEBHOOK_URL=https://hooks.slack.com/services/T.../B.../xxxx
   ```
3. Reinicie pegando as variáveis:
   ```
   pm2 restart conversor-pdf --update-env
   ```

Teste rápido (Prompt de Comando):
```
curl -X POST http://localhost:3001/notificar-slack -H "Content-Type: application/json" -d "{\"texto\":\"teste da plataforma\"}"
```
Deve responder `{"ok":true}` e a mensagem aparecer no canal.
