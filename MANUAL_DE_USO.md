# Manual de Uso — Plataforma de Conciliação da Produção

Guia rápido de como usar o dia a dia da plataforma. Para instalação/migração do
serviço, veja `MIGRAR_PLATAFORMA_PARA_SERVIDOR.md`.

---

## 1. Acesso

Abra a plataforma pelo endereço combinado com a Garantia da Qualidade
(ex.: `http://192.168.21.28:3001/`). O acesso é feito com e-mail e senha da
Confiance — não existe cadastro próprio na tela de login: quem precisa de
conta nova recebe um **convite por e-mail** (feito em Configurações →
Usuários, por quem tem permissão de admin/gestor).

Se aparecer "conexão recusada" ou a página não carregar, o serviço pode estar
fora do ar — avise a Qualidade.

---

## 2. Menu lateral

| Item | Para quê |
|---|---|
| **Dashboard** | Indicadores gerais: total de análises, conformes/ressalvas/corrigidas, documentos mais corrigidos, melhorias regulatórias sugeridas. |
| **Análise** | Onde se sobe os documentos de um lote e roda a conciliação. |
| **Histórico** | Lista de todas as análises já feitas, com filtros, exportações e reenvio de cobranças. |
| **NFs de venda** | Rastreabilidade: liga cada número de série a sua nota fiscal de saída. |
| **Cadastro** | Catálogo de produtos, Fichas Mestres, Tempos de estágio e o template do FORM-GQ-0047. |
| **Solicitações** | Pedidos de ações sensíveis (excluir, refazer etc.) que precisam de aprovação de quem tem mais permissão. |
| **Configurações** | Pasta de destino do pacote, usuários, operadores, planilha do PCP, pasta de rede das NFs. |

Clique no ícone de seta ao lado do logo para recolher o menu e ganhar mais
espaço de tela.

Atalhos de teclado: `g d` Dashboard, `g a` Análise, `g h` Histórico,
`g c` Cadastro, `/` foca a busca, `?` mostra a lista de atalhos.

---

## 3. Fazer uma análise (tela "Análise")

1. Escolha uma OP pendente na lista, ou clique em "Nova análise avulsa".
2. Envie os documentos do lote — pode **arrastar a pasta inteira**: a
   plataforma separa sozinha OP, RC, etiqueta externa, etiquetas de
   acessório, reprocesso, RNC e FORM. Se preferir, anexe um por um nos
   quadros à direita.
3. Os 4 primeiros documentos (OP, RC, Etiqueta Externa, FORM-GQ-0047) são
   obrigatórios; os demais só se existirem no lote.
4. Clique em **Analisar lote**. O resultado (parecer) aparece na tela, com
   os apontamentos encontrados, se houver.
5. Se a análise for bloqueada com a mensagem de que a **Ficha Mestre** do
   produto não existe ou não está apta, aparece um aviso com o botão
   **"Abrir a Ficha Mestre"** — ele abre o cadastro por cima da tela, já
   com os documentos anexados prontos para pré-preencher a ficha. Ao salvar
   e fechar, clique em "Analisar lote" de novo.
6. Com o parecer pronto, é possível: baixar o pacote completo (ZIP), enviar
   NC ao Slack, justificar ressalvas, ou navegar para a próxima/anterior
   análise do histórico sem sair da tela (setas do teclado).

---

## 4. Histórico

Lista todas as análises. Filtros disponíveis: período, equipamento, modelo,
origem, status, e (quando o status é "Em aberto", "Não conforme" ou
"Conforme com ressalvas") um filtro extra por **Problema** — Etiqueta, OP ou
os dois juntos. Também dá para filtrar só pendentes ou só lotes sem NF de
venda vinculada.

Botão **Ações** reúne:

- **Importar planilha** — dá entrada em várias OPs de uma vez via XLSX.
- **Reanalisar OP corrigida** — reprocessa uma OP que já foi corrigida.
- **Enviar problema em pacote** — agrupa o mesmo apontamento em várias OPs e
  manda uma única mensagem ao Slack do setor responsável, marcando os
  operadores. OPs já cobradas por aquele mesmo problema aparecem com a marca
  "já enviada há X dias" e vêm desmarcadas — só reenvia se você marcar de
  novo.
- **Exportar OPs em aberto** — planilha com uma linha por apontamento
  pendente (o que falta corrigir, de quem e onde).
- **Exportar Histórico** — planilha com todas as análises do período filtrado.
- **Exportar p/ auditoria** — formato específico para auditoria externa.
- **Backup mensal** — gera um arquivo de backup das análises do mês.

---

## 5. NFs de venda

Cruza os números de série analisados com as notas fiscais de saída (venda,
comodato, demonstração etc.) lidas da pasta de rede configurada.

Abas:

- **OPs sem NF** — série já analisada, mas nenhuma nota encontrada ainda.
- **Vinculadas** — nota encontrada e análise já encerrada (conforme).
- **Saiu com análise em aberto** — saiu numa nota, mas a análise ainda tem
  pendência (ressalva ou não conformidade) — atenção redobrada.
- **Não lidos** — arquivos que a plataforma tentou ler e não conseguiu
  (nota corrompida, formato inesperado etc.).

Botão **Varrer agora** dispara uma nova leitura da pasta de rede (só lê
arquivo novo ou alterado — não reprocessa o que já foi lido). Se a nota não
foi lida corretamente, use **Vincular NF** na aba "OPs sem NF" para informar
manualmente ou reenviar o PDF daquela nota.

Clique no número de série de qualquer linha para ver a linha do tempo de
todas as notas daquele equipamento.

---

## 6. Cadastro

- **Catálogo de Produtos** — cadastro de cada modelo (código Sapiens,
  registro ANVISA etc.). Sem produto cadastrado, a análise não roda.
- **Fichas Mestres** — cada ficha define uma derivação de um produto:
  acessórios esperados, estágios aplicáveis, dados do fabricante. Uma ficha
  precisa estar marcada como **"Ficha revisada e apta para análise"** para
  que o sistema aceite analisar lotes daquele produto. Dá para importar os
  dados a partir de documentos exemplo (OP, RC, etiquetas) em vez de digitar
  tudo.
- **Tempos de estágio** — configura, por equipamento e estágio, o tempo
  médio esperado, a tolerância (%) e uma margem em minutos; liga/desliga a
  checagem por estágio. Mostra a mediana observada no histórico como
  referência para calibrar.
- **Template FORM-GQ-0047** — arquivo XLSX usado para gerar o formulário
  preenchido após a análise.

---

## 7. Configurações

- **Pasta de destino do pacote** — onde o ZIP baixado é salvo na rede.
- **Usuários** — convidar pessoas (por e-mail) e definir nível de permissão.
- **Operadores** — cadastro de nome, código e Slack ID (usado nas menções
  automáticas de NC).
- **Planilha do PCP** — origem da lista de OPs pendentes.
- **Pasta de rede das NFs** — caminho(s) onde ficam os PDFs de nota fiscal,
  com suporte a `{ANO}`/`{ANO-1}` no caminho.

---

## 8. Dúvidas comuns

**"A página não carrega"** — confira se o serviço (`conversor-pdf-local`)
está no ar na máquina onde ele está rodando (`pm2 list`).

**"Diz que a Ficha Mestre não está apta"** — normal para produto ainda não
revisado; use o botão "Abrir a Ficha Mestre" que aparece no próprio aviso.

**"Baixei o pacote e não salvou na pasta certa"** — confira em
Configurações → Pasta de destino do pacote.

**Dúvida técnica ou sobre a stack** — falar com Maria Luiza (Garantia da
Qualidade).
