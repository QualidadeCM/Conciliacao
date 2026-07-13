# Mover o serviço para o servidor (192.168.20.252)

Objetivo: rodar o `conversor-pdf-local` no servidor (que fica sempre ligado e hospeda
o compartilhamento H:), para que todos do setor usem a plataforma em
`http://192.168.20.252:3001/` — mesmo com o seu PC desligado — e sem precisar mais
copiar o `plataforma.html`.

> Requer acesso de **administrador** ao servidor (RDP/console) e permissão para
> instalar programas. Se a TI cuida do servidor, faça junto com eles.

---

> **Por que NÃO Vercel/nuvem:** a conversão usa LibreOffice/Ghostscript/Chromium (binários
> pesados que não rodam em serverless) e o pacote é gravado numa pasta INTERNA da rede
> (`\\192.168.20.252\qualidade\...`), que a nuvem não alcança — e que, pelas regras da
> empresa, não pode ir para a nuvem. Por isso o serviço roda num servidor INTERNO sempre
> ligado; "online" aqui = acessível a todos na rede da empresa, sem depender do seu PC.

---

## Pré-requisitos (instalar no servidor, uma vez)

1. **Node.js 18+** — https://nodejs.org (LTS). (o instalador já inclui o npm)
2. **Git** — https://git-scm.com/download/win (para clonar/atualizar do GitHub).
3. **LibreOffice** — https://www.libreoffice.org/download (para XLSX/DOCX → PDF).
4. **Ghostscript 64 bits** — https://ghostscript.com/releases/gsdnld.html (para PDF assinável).
   - O Chromium (para HTML→PDF) é baixado automaticamente pelo `npm install`.

---

## Passo a passo

### 1. Clonar o projeto do GitHub num disco local do servidor
No servidor, abra o Prompt de Comando num disco local (ex.: `C:\`) e clone o repositório:
```
cd C:\
git clone <URL-DO-SEU-REPOSITORIO-GITHUB> conciliacao
```
Isso cria `C:\conciliacao` com o projeto (incluindo `plataforma.html` e a pasta `conversor-pdf-local`).
Se o repositório for privado, o Git pedirá login/token do GitHub na primeira vez.
> Rode o serviço a partir do disco local do servidor (não do H:).

### 2. Descobrir o caminho LOCAL do compartilhamento no servidor
No servidor, rode no Prompt:
```
net share
```
Procure o compartilhamento `qualidade` e anote o caminho físico (ex.: `D:\qualidade` ou `E:\Dados\qualidade`).
Esse caminho substitui o `\\192.168.20.252\qualidade` — como o serviço roda NO servidor,
ele acessa a pasta localmente (mais rápido e sem problema de permissão de rede).

### 3. Criar o arquivo `.env` em `C:\conciliacao\conversor-pdf-local\.env`
Use o modelo abaixo, trocando os valores entre `< >`. Caminhos usam **barra normal** `/`.
> O `.env` NÃO fica no GitHub (contém segredos) — crie-o direto no servidor.

```
PORT=3001

# Supabase (mantidos SOMENTE no servidor — nunca no navegador)
SUPABASE_URL=<https://SEU-PROJETO.supabase.co>
SUPABASE_SERVICE_ROLE_KEY=<chave service_role do Supabase>

# Alerta de NC no Slack
SLACK_WEBHOOK_URL=<https://hooks.slack.com/services/...>

# Página servida pela rede — como o plataforma.html agora vem do próprio repositório
# clonado, aponte para o arquivo dentro do clone:
PLATAFORMA_HTML=C:/conciliacao/plataforma.html

# Se o LibreOffice/Ghostscript não estiverem no PATH, aponte aqui:
# SOFFICE_BIN=C:/Program Files/LibreOffice/program/soffice.exe
# GHOSTSCRIPT_BIN=C:/Program Files/gs/gs10.03.1/bin/gswin64c.exe
```

### 4. Instalar dependências e subir o serviço
No Prompt, dentro de `C:\conciliacao\conversor-pdf-local`:
```
npm install
npm install -g pm2 pm2-windows-startup
pm2-startup install
pm2 start server.js --name conversor-pdf
pm2 save
```
Teste no próprio servidor: `http://localhost:3001/health` deve responder `{ "ok": true, ... }`.

### 5. Liberar a porta 3001 no firewall do servidor (Prompt como Administrador)
```
netsh advfirewall firewall add rule name="Conciliacao 3001" dir=in action=allow protocol=TCP localport=3001
```

### 6. Ajustar o endereço no Supabase
Painel do Supabase → **Authentication → URL Configuration**:
- **Site URL:** `http://192.168.20.252:3001`
- **Redirect URLs:** adicione `http://192.168.20.252:3001/**`
- Remova os IPs antigos (`192.168.20.122`, `192.168.20.252` sem porta, etc.).

### 7. Reconfigurar a pasta de destino do pacote (na plataforma)
Como a configuração fica salva por endereço (localStorage), ao abrir a plataforma no novo
endereço `http://192.168.20.252:3001/` você precisa reabrir **Configurações** e informar de
novo a pasta de destino do pacote. No servidor, use o **caminho local** do share
(ex.: `D:\qualidade\...\Origem 070\Pendente de Assinatura`) em vez do `\\192.168.20.252\...`.

### 8. Desligar o serviço antigo do seu PC (192.168.20.122)
No seu PC, para não haver dois serviços concorrentes:
```
pm2 delete conversor-pdf
pm2 save
```

---

## Validação final
- Em **outro computador** da rede: abrir `http://192.168.20.252:3001/` → plataforma carrega.
- Enviar um convite (com a plataforma aberta em `http://192.168.20.252:3001/`) → o link do
  e-mail aponta para esse endereço e a pessoa consegue criar a conta.
- Baixar um pacote de uma OP → conferir que salvou na pasta do servidor.

## Atualizações futuras (via GitHub) — acabou a cópia manual
Com o projeto vindo do Git, publicar mudanças fica assim:
1. No ambiente de desenvolvimento, faça as alterações e envie ao GitHub: `git add -A && git commit -m "..." && git push`.
2. No servidor, dentro de `C:\conciliacao`:
   ```
   git pull
   pm2 restart conversor-pdf
   ```
   - Se mudou algo no `plataforma.html`, o `git pull` já atualiza — os usuários só dão **Ctrl+F5**. (Como o serviço serve o arquivo direto do clone, nem sempre precisa do restart; o restart só é necessário se mudou o `server.js`.)
   - Se mudaram as dependências (`package.json`), rode `npm install` na pasta `conversor-pdf-local` antes do restart.

> Assim, nunca mais é preciso copiar arquivos para o `C:` na mão: a "publicação" é `git pull`.

## Recomendação
Peça à TI para **fixar o IP do servidor** (reserva de DHCP) para `192.168.20.252` não mudar
e quebrar os convites/endereços no futuro.
