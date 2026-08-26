# Publicar a Plataforma de Conciliação da Produção no servidor

Garantia da Qualidade · Confiance Medical
Documento para avaliação da TI · atualizado em 24/08/2026

---

# RESUMO PARA A TI

## O que é

Sistema interno usado pela Garantia da Qualidade para analisar a conciliação da
produção de dispositivos médicos (OP, Relação de Componentes, FORM-GQ-0047 e
etiquetas contra a Ficha Mestre). Já está em uso diário, com mais de mil análises
registradas.

Tem duas partes:

| Parte | O que é | Onde está hoje |
|---|---|---|
| Interface | Um arquivo HTML (`plataforma.html`) que roda no navegador | servido pelo serviço abaixo |
| Serviço | Aplicação Node.js/Express (`conversor-pdf-local`) | **PC da Maria Luiza**, via PM2 |

## O problema

O serviço roda no computador de uma pessoa. É ele que entrega a página aos demais
usuários na porta 3001. Com esse computador desligado, o setor perde: acesso à
plataforma, conversão de documentos para PDF, gravação dos pacotes na pasta da
rede, alertas no Slack, consulta ao PCP, convite de usuários e a varredura mensal
das notas fiscais.

## O que pedimos

Instalar e manter esse serviço no servidor **192.168.20.252** — o mesmo que já
hospeda os compartilhamentos que o sistema usa.

### Software a instalar no servidor (uma vez)

| Software | Para quê |
|---|---|
| Node.js 18+ (LTS) | executar o serviço |
| Git | clonar e atualizar o projeto |
| LibreOffice | converter XLSX/DOCX em PDF |
| Ghostscript 64 bits | regerar PDF sem restrição (assinável no Adobe) |

O Chromium usado na geração de PDF é baixado automaticamente na instalação das
dependências. Nada é instalado nas máquinas dos usuários — eles só acessam pelo
navegador.

### Rede

- Liberar a porta **TCP 3001** de entrada no firewall do servidor (acesso apenas pela rede interna).
- Reservar o IP **192.168.20.252** por DHCP, para não mudar e quebrar os endereços.
- Desejável: um nome de rede (ex.: `http://conciliacao:3001`) em vez do IP puro.

### Permissões

O serviço precisa ler e gravar em dois compartilhamentos que **já estão nesse
mesmo servidor** — portanto o acesso é local, sem credencial de rede:

| Compartilhamento | Acesso | Uso |
|---|---|---|
| `qualidade` | leitura e escrita | grava o pacote de documentos de cada OP |
| `confiance medical\nf-e 2.0` | leitura | lê as notas fiscais para rastrear nº de série |

### Execução contínua

Subir com PM2 e inicialização automática (`pm2-windows-startup`), para o serviço
voltar sozinho após reinicialização do servidor. Se a TI preferir, pode ser
registrado como Serviço do Windows — o resultado é o mesmo.

## Por que não pode ser na nuvem

Três razões independentes:

1. A conversão depende de LibreOffice, Ghostscript e Chromium — binários pesados, que não rodam em ambiente serverless.
2. Os pacotes de documentos são gravados numa pasta **interna** da rede, que a nuvem não alcança.
3. O padrão de desenvolvimento de sistemas da empresa proíbe dado persistente fora do servidor local.

"Publicar" aqui significa ficar acessível a todos na rede interna da empresa, sem
depender do computador de uma pessoa.

## Esforço estimado

Cerca de **1 hora** com acesso de administrador ao servidor: instalação dos quatro
programas, clone do repositório, um arquivo de configuração, subida do serviço,
liberação da porta e testes.

## Observação sobre dados

O banco de dados é o Supabase (Postgres gerenciado), já em uso e fora do escopo
desta migração — nada muda nele. A migração para MySQL local, conforme o padrão da
empresa, está prevista em documento separado (`PLANO_MIGRACAO_P&D_SOFTWARE.md`).

---

# ROTEIRO TÉCNICO DETALHADO

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

---
---

# APÊNDICE — OPERAÇÃO PROVISÓRIA (FÉRIAS) E VOLTA

Cenário: a TI não consegue subir no servidor antes das férias. O serviço passa
**provisoriamente** para o computador da pessoa que vai operar o sistema, e volta para
a máquina da Maria na retomada.

> Isto é paliativo. A fragilidade não desaparece, só troca de máquina: o computador
> dela também suspende, reinicia por atualização do Windows e é desligado no fim do
> dia. O destino definitivo continua sendo o servidor.

---

## PARTE A — Preparação (fazer ANTES, na máquina da Maria)

### A.1 Liberar os três endereços no Supabase, de uma vez

Painel do Supabase → **Authentication → URL Configuration** → **Redirect URLs**.
Deixe os três cadastrados agora; a lista aceita vários:

```
http://<IP-DO-PC-DA-MARIA>:3001/**
http://<IP-DO-PC-DA-COLEGA>:3001/**
http://192.168.20.252:3001/**
```

A plataforma usa o endereço da página aberta ao enviar convite. Com os três liberados,
convite funciona de qualquer um deles — e **não é preciso mexer no Supabase na ida nem
na volta**, nem quando a TI fizer a migração definitiva.

Em **Site URL**, deixe o endereço que estiver em uso no momento (é só o padrão de
reserva).

Para descobrir o IP de cada máquina, no Prompt: `ipconfig` → procure "Endereço IPv4".

### A.2 Publicar o código no GitHub

O repositório precisa estar atualizado, senão a máquina dela recebe versão antiga:

```
cd C:\conciliacao
git add -A
git commit -m "Ajustes antes da operacao provisoria"
git push
```

### A.3 Copiar o conteúdo do `.env`

Abra `C:\conversor-pdf-local\.env` e guarde o conteúdo (em local seguro, não por
e-mail aberto). Ele contém as chaves do Supabase e os webhooks do Slack, e **não** vem
pelo Git.

---

## PARTE B — Instalar na máquina da colega

### B.1 Programas (instalar uma vez, precisa de admin na máquina)

| # | Software | Onde baixar | Para quê |
|---|---|---|---|
| 1 | Node.js 18+ (LTS) | https://nodejs.org | executar o serviço (já traz o npm) |
| 2 | Git para Windows | https://git-scm.com/download/win | clonar e atualizar o projeto |
| 3 | LibreOffice | https://www.libreoffice.org/download | converter XLSX/DOCX em PDF |
| 4 | Ghostscript 64 bits | https://ghostscript.com/releases/gsdnld.html | gerar PDF assinável no Adobe |

Nas telas de instalação, aceite as opções padrão. O Chromium (usado no HTML → PDF) é
baixado sozinho no passo B.3.

Confira que instalou, abrindo um Prompt **novo**:

```
node -v
git --version
```

Se `node -v` não responder, reinicie o computador (o PATH não foi atualizado).

### B.2 Baixar o projeto

```
cd C:\
git clone https://github.com/QualidadeCM/Conciliacao.git conciliacao
```

Se o repositório for privado, o Git vai pedir login do GitHub na primeira vez.

> Sem Git também dá: copie a pasta `C:\conciliacao` inteira do PC da Maria, **exceto**
> `conversor-pdf-local\node_modules`. Mas com Git é mais fácil atualizar depois.

### B.3 Criar o arquivo de configuração

Crie `C:\conciliacao\conversor-pdf-local\.env` com o conteúdo que você guardou no passo
A.3, ajustando só esta linha:

```
PLATAFORMA_HTML=C:/conciliacao/plataforma.html
```

Atenção: barra normal `/`, não invertida. O arquivo tem que se chamar exatamente `.env`
(sem `.txt` no fim — no Bloco de Notas, salve com "Todos os arquivos").

### B.4 Instalar dependências e subir o serviço

```
cd C:\conciliacao\conversor-pdf-local
npm install
npm install -g pm2 pm2-windows-startup
pm2-startup install
pm2 start server.js --name conversor-pdf
pm2 save
```

O `npm install` demora alguns minutos (baixa o Chromium). O `pm2-startup install` +
`pm2 save` são o que faz o serviço voltar sozinho depois de reiniciar o computador.

Teste na própria máquina: abra `http://localhost:3001/health` no navegador. Deve
aparecer algo como `{"ok":true,"servico":"conversor-pdf-local",...}`.

### B.5 Liberar a porta no firewall

Prompt de Comando **como Administrador**:

```
netsh advfirewall firewall add rule name="Conciliacao 3001" dir=in action=allow protocol=TCP localport=3001
```

Sem isso, funciona só na própria máquina — ninguém mais na rede acessa.

### B.6 Impedir que a máquina suspenda

Prompt como Administrador:

```
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /change disk-timeout-ac 0
powercfg /change monitor-timeout-ac 10
```

A tela apaga em 10 minutos (normal), mas a máquina não dorme. Se ela dormir, o serviço
para de responder.

### B.7 Conferir as permissões de pasta — não pule este passo

O serviço acessa as pastas da rede com as credenciais de **quem está logado** na
máquina. Com a conta dela logada, confirme:

- [ ] Consegue **criar e apagar** um arquivo de teste em
      `\\192.168.20.252\qualidade\...\Origem 070\Pendente de Assinatura`
- [ ] Consegue **abrir** uma nota em `Y:\Rosana\DANFE\2026\CMRJ\VENDA\...`

Se faltar escrita na primeira, o download do pacote falha — e falha de um jeito que
parece defeito do sistema. Se faltar leitura na segunda, a varredura de NFs não acha
nada.

### B.8 Desligar o serviço no PC da Maria

Na máquina da Maria, antes de viajar:

```
pm2 delete conversor-pdf
pm2 save
```

Os dois comandos, sempre. Sem o `pm2 save`, o serviço volta no próximo logon e ficam
dois no ar — os dois rodando a varredura mensal e gravando pacotes ao mesmo tempo.

### B.9 Avisar os usuários

Novo endereço: `http://<IP-DO-PC-DA-COLEGA>:3001/`

Vale mandar o link no Slack e pedir que salvem nos favoritos. Quem tiver o endereço
antigo salvo vai achar que o sistema caiu.

---

## PARTE C — Validar (de OUTRO computador, com o PC da Maria desligado)

- [ ] Abrir `http://<IP-DO-PC-DA-COLEGA>:3001/` → a plataforma carrega
- [ ] Fazer login
- [ ] Abrir uma análise conforme e **baixar o pacote** → conferir que gravou na pasta da rede
- [ ] **NFs de venda → Varrer agora** → conclui e diz "já lido(s) antes, ignorado(s)" para quase tudo
- [ ] Enviar um alerta ao Slack de uma análise em aberto → chega no canal
- [ ] Gerar um **Parecer em PDF** → abre corretamente (testa o Chromium)
- [ ] Reiniciar o computador dela e conferir que o serviço voltou: `pm2 list` → status `online`

O último item é o mais importante. É o que garante que uma atualização do Windows no
meio das férias não derrube tudo.

---

## PARTE D — Enquanto você estiver fora

### Se a plataforma não abrir

Na máquina dela, Prompt de Comando:

```
pm2 list
```

- Status `online` → o serviço está de pé; o problema é outro (rede, navegador)
- Status `stopped` ou `errored` → `pm2 restart conversor-pdf`
- Não aparece nada → `cd C:\conciliacao\conversor-pdf-local` e `pm2 start server.js --name conversor-pdf`

Para ver o erro:

```
pm2 logs conversor-pdf --lines 30 --nostream
```

### Se aparecer "porta 3001 já em uso" (EADDRINUSE)

Sobrou um processo órfão:

```
pm2 stop conversor-pdf
for /f "tokens=5" %a in ('netstat -ano ^| findstr :3001 ^| findstr LISTENING') do taskkill /PID %a /F
pm2 restart conversor-pdf
```

### Publicar uma correção à distância

```
cd C:\conciliacao
git pull
pm2 restart conversor-pdf
```

Se mudou só o `plataforma.html`, o `git pull` basta e os usuários dão Ctrl+F5. Se mudou
o `package.json`, rode `npm install` em `conversor-pdf-local` antes do restart.

### Não convide usuários novos nesta janela

O link do convite aponta para o IP em uso no momento do envio. Se a pessoa clicar
depois da volta, o link não abre. Se for inevitável, reenvie o convite depois da
virada.

---

## PARTE E — Voltar para a máquina da Maria

Nesta ordem:

**1. Desligar na máquina dela** (primeiro isto, para nunca haver dois no ar):

```
pm2 delete conversor-pdf
pm2 save
```

**2. Sincronizar o código na sua máquina** — se algo foi publicado durante as férias:

```
cd C:\conciliacao
git pull
```

**3. Subir na sua máquina:**

```
cd C:\conversor-pdf-local
pm2 start server.js --name conversor-pdf
pm2 save
```

> Se você tiver passado a rodar do clone (`C:\conciliacao\conversor-pdf-local`), use
> essa pasta. O importante é que o `.env` esteja na mesma pasta do `server.js`.

**4. Conferir:** `http://localhost:3001/health` responde, e a plataforma abre no seu
endereço.

**5. Avisar os usuários** do endereço de volta.

**Supabase: nada a fazer** — os três endereços já estão liberados desde o passo A.1.

---

## Resumo do que muda em cada virada

| | Ida (para a colega) | Volta (para a Maria) |
|---|---|---|
| Instalar programas | sim, uma vez | não, já instalado |
| Baixar projeto e criar `.env` | sim | não |
| Firewall e energia | sim | não |
| Ligar o serviço | sim | sim |
| **Desligar o serviço do outro lado** | **sim** | **sim** |
| Mexer no Supabase | não (feito no A.1) | não |
| Avisar os usuários | sim | sim |
