# Tirar a plataforma do PC da Maria e colocar no servidor

**Objetivo:** o sistema continuar funcionando para todo o setor com o computador da
Maria desligado (férias, fim de semana, atualização do Windows).

**Situação hoje:** o serviço `conversor-pdf` roda no PC da Maria
(`C:\conversor-pdf-local`, PM2 em `C:\Users\maria.zaccur\.pm2`). É ele que **entrega a
página** da plataforma na porta 3001. Com o PC desligado, os outros usuários perdem:

- a própria plataforma (a página não abre)
- conversão de documentos para PDF (FORM-GQ-0047, OP assinável, resumo)
- gravação do pacote na pasta da rede
- alertas do Slack (individuais e em pacote)
- consulta do status do PCP
- convite de novos usuários
- varredura das NFs de venda (manual e a mensal automática)

**Destino:** servidor **192.168.20.252** — o mesmo que hospeda os compartilhamentos
`qualidade` (onde os pacotes são gravados) e `confiance medical\nf-e 2.0` (onde ficam
as NFs). Como o serviço vai rodar *no* servidor, ele acessa as duas pastas
**localmente**: mais rápido e sem depender de permissão de rede.

> Requer acesso de administrador ao servidor e permissão para instalar programas.
> Se a TI cuida do servidor, faça junto com eles.

> **Por que não na nuvem:** a conversão depende de LibreOffice, Ghostscript e Chromium
> (binários pesados, que não rodam em serverless); o pacote é gravado numa pasta interna
> da rede que a nuvem não alcança; e o padrão de desenvolvimento da empresa proíbe dado
> persistente fora do servidor local. "Online" aqui significa acessível a todos na rede
> da empresa, sem depender de um PC específico.

---

## ETAPA 0 — Fazer no PC da Maria, ANTES de tocar no servidor

### 0.1 Resolver as chaves do Supabase no repositório (segurança)

O arquivo `Backup_v1_2026-07-01/Plataforma-Conciliacao/Supabase API Keys.txt` está
**rastreado no Git**, ou seja, foi enviado ao GitHub. Se contiver a chave
`service_role`, ela dá acesso total ao banco ignorando as políticas de segurança (RLS).

```
git rm --cached "Backup_v1_2026-07-01/Plataforma-Conciliacao/Supabase API Keys.txt"
```

Depois acrescente ao `.gitignore`:

```
Supabase API Keys.txt
*.env
```

> Atenção: isso remove o arquivo dos commits **futuros**, mas ele continua no histórico
> do repositório. Se a chave `service_role` estiver ali, o certo é **rotacioná-la** no
> painel do Supabase (Settings → API → gerar nova service_role) e atualizar o `.env` do
> serviço. Vale confirmar com a TI se o repositório é privado.

### 0.2 Publicar tudo no GitHub

O repositório está no commit de 19/08; todo o trabalho recente está apenas na máquina.
Sem este passo, o servidor vai clonar uma versão antiga.

```
cd C:\conciliacao
git add -A
git commit -m "NFs de venda (varredura + rastreabilidade), menu de acoes, navegacao entre analises, correcoes do Dashboard"
git push
```

### 0.3 Anotar os valores do `.env` atual

Abra `C:\conversor-pdf-local\.env` e copie o conteúdo — você vai recriá-lo no servidor.
Os campos usados hoje:

```
PORT, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, PLATAFORMA_HTML,
SLACK_WEBHOOK_URL, SLACK_WEBHOOK_PCP, SLACK_WEBHOOK_ALMOXARIFADO,
SOFFICE_BIN, GHOSTSCRIPT_BIN
```

---

## ETAPA 1 — Preparar o servidor (uma vez)

Instalar no **192.168.20.252**:

1. **Node.js 18+ (LTS)** — https://nodejs.org (já inclui o npm)
2. **Git** — https://git-scm.com/download/win
3. **LibreOffice** — https://www.libreoffice.org/download (XLSX/DOCX → PDF)
4. **Ghostscript 64 bits** — https://ghostscript.com/releases/gsdnld.html (PDF assinável)

O Chromium (HTML → PDF) é baixado automaticamente no `npm install`.

### Descobrir os caminhos LOCAIS dos compartilhamentos

No servidor, no Prompt:

```
net share
```

Anote o caminho físico de **dois** compartilhamentos:

| Compartilhamento de rede | Caminho local (exemplo) | Usado para |
|---|---|---|
| `\\192.168.20.252\qualidade` | `D:\qualidade` | gravar o pacote da OP |
| `\\192.168.20.252\confiance medical\nf-e 2.0` | `D:\confiance medical\nf-e 2.0` | ler as NFs de venda |

---

## ETAPA 2 — Instalar o serviço no servidor

### 2.1 Clonar o projeto num disco local

```
cd C:\
git clone https://github.com/QualidadeCM/Conciliacao.git conciliacao
```

> Rode a partir do disco local do servidor, não de uma unidade de rede.

### 2.2 Criar `C:\conciliacao\conversor-pdf-local\.env`

Use barra normal `/` nos caminhos. Este arquivo **não** vem do GitHub — crie-o à mão,
com os valores que você anotou na etapa 0.3.

```
PORT=3001

# Supabase — ficam SOMENTE no servidor, nunca no navegador
SUPABASE_URL=<https://SEU-PROJETO.supabase.co>
SUPABASE_SERVICE_ROLE_KEY=<chave service_role>

# Página servida pela rede (o serviço entrega este arquivo do próprio clone)
PLATAFORMA_HTML=C:/conciliacao/plataforma.html

# Slack — um webhook por canal
SLACK_WEBHOOK_PCP=<https://hooks.slack.com/services/...>
SLACK_WEBHOOK_ALMOXARIFADO=<https://hooks.slack.com/services/...>
SLACK_WEBHOOK_URL=<webhook geral, usado como reserva>

# Só se não estiverem no PATH
# SOFFICE_BIN=C:/Program Files/LibreOffice/program/soffice.exe
# GHOSTSCRIPT_BIN=C:/Program Files/gs/gs10.03.1/bin/gswin64c.exe
```

### 2.3 Instalar dependências e subir com inicialização automática

```
cd C:\conciliacao\conversor-pdf-local
npm install
npm install -g pm2 pm2-windows-startup
pm2-startup install
pm2 start server.js --name conversor-pdf
pm2 save
```

O `pm2-startup install` + `pm2 save` são o que garante que o serviço **volte sozinho**
depois de reiniciar o servidor. Sem isso, uma atualização do Windows derruba tudo.

Teste no próprio servidor: `http://localhost:3001/health` deve responder
`{ "ok": true, ... }`.

### 2.4 Liberar a porta no firewall (Prompt como Administrador)

```
netsh advfirewall firewall add rule name="Conciliacao 3001" dir=in action=allow protocol=TCP localport=3001
```

---

## ETAPA 3 — Ajustar os endereços e caminhos

### 3.1 Supabase — URLs de redirecionamento

Painel do Supabase → **Authentication → URL Configuration**:

- **Site URL:** `http://192.168.20.252:3001`
- **Redirect URLs:** adicionar `http://192.168.20.252:3001/**`
- Remover os endereços antigos (o IP do PC da Maria)

Sem isso, o link do e-mail de convite aponta para o endereço velho e o novo usuário
não consegue criar a conta.

### 3.2 Configurações da plataforma — trocar para caminhos LOCAIS

Abra `http://192.168.20.252:3001/`, entre em **Configurações** e ajuste:

- **Pasta de destino do pacote:** o caminho local, ex.
  `D:\qualidade\REGISTROS DO SISTEMA DE GESTÃO DA QUALIDADE\2026\GARANTIA DA QUALIDADE DE PRODUTOS PRODUZIDOS\Origem 070\Pendente de Assinatura`
- **Pasta das NFs de venda:** o caminho local, ex.
  `D:\confiance medical\nf-e 2.0\Rosana\DANFE\{ANO};D:\confiance medical\nf-e 2.0\Rosana\DANFE\{ANO-1}`
- Confirmar **Ano mínimo = 2026** e o dia/hora da varredura mensal

Essas configurações ficam no banco (`config_app`), então valem para todos os usuários.

---

## ETAPA 4 — Desligar o serviço do PC da Maria

Passo obrigatório, não opcional: com dois serviços no ar, os dois rodariam a varredura
mensal das NFs e gravariam pacotes ao mesmo tempo.

```
pm2 delete conversor-pdf
pm2 save
```

---

## ETAPA 5 — Validar (de OUTRO computador, com o PC da Maria desligado)

- [ ] Abrir `http://192.168.20.252:3001/` → a plataforma carrega
- [ ] Fazer login normalmente
- [ ] Abrir uma análise conforme e **baixar o pacote** → conferir que gravou na pasta certa da rede
- [ ] **NFs de venda → Varrer agora** → deve terminar dizendo "já lido(s) antes, ignorado(s)" para quase tudo
- [ ] Enviar um alerta ao Slack a partir de uma análise em aberto → mensagem chega no canal
- [ ] Convidar um usuário de teste → o link do e-mail aponta para `192.168.20.252:3001`
- [ ] Reiniciar o servidor e conferir que o serviço voltou sozinho (`pm2 list`)

---

## Depois disso: publicar deixa de ser cópia manual

Fim do `copy /Y`. Para publicar qualquer mudança:

1. No ambiente de desenvolvimento: `git add -A && git commit -m "..." && git push`
2. No servidor, em `C:\conciliacao`:
   ```
   git pull
   pm2 restart conversor-pdf
   ```

- Mudou só o `plataforma.html`? O `git pull` basta — os usuários dão **Ctrl+F5**
  (o serviço entrega o arquivo direto do clone).
- Mudou o `server.js`? Precisa do `pm2 restart`.
- Mudou o `package.json`? Rode `npm install` em `conversor-pdf-local` antes do restart.

---

## Pendências para combinar com a TI

- **Fixar o IP** do servidor por reserva de DHCP, para `192.168.20.252` não mudar e
  quebrar os endereços e convites.
- **Confirmar se o repositório do GitHub é privado** e decidir sobre rotacionar a chave
  `service_role` (etapa 0.1).
- Avaliar um **nome de rede** em vez do IP puro (ex.: `http://conciliacao:3001`), que
  sobrevive a uma eventual troca de IP.
