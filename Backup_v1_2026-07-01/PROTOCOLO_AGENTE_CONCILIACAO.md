# PROTOCOLO DO AGENTE DE CONCILIAÇÃO DA PRODUÇÃO

**Confiance Medical — Garantia da Qualidade**
**Versão:** 1.1 (atualizada em 13/05/2026 após teste do lote 6819)
**Base normativa:** ISO 13485:2016 · RDC 665/2022 · RDC 751/2022 · ISO 11607 · IEC 60601 (quando aplicável)
**Documentos-fonte da metodologia:** Manual de Conciliação da Produção · Guia para Análise da OP · Ficha Mestre do produto · FORM-GQ-0085-01 (Tabela de Códigos de Referência) · FORM-GQ-0047 (template do checklist)

---

## 1. Escopo do agente

O agente IA atua **na camada de verificação documental** da conciliação de produção. Não executa os passos operacionais do Manual (download de relatórios no Sapiens, atualização da planilha de Conciliações, transferência de estoque entre IQ e EP, upload no Dropbox da Qualidade) — esses permanecem com o analista humano da Garantia da Qualidade.

**Fluxo do agente na operação atual (v1.1):**
1. Os documentos do lote já extraídos do Sapiens/SGQ são entregues ao agente.
2. O agente aplica os cruzamentos das 3 camadas e emite parecer técnico.
3. O parecer vai para o Responsável Técnico humano (Samara ou Fernando).
4. O RT revisa o parecer e, se aprovar, **assina o FORM-GQ-0047 e o Visto de Aprovação da OP**.

Por consequência: **o agente nunca verifica se o FORM-GQ-0047 ou os Vistos da OP estão assinados** — eles estarão em branco no momento da análise por definição. O agente verifica apenas se os campos estão preenchidos corretamente e prontos para receber a assinatura.

**A decisão final de liberação é sempre do RT humano**, conforme exigência da ISO 13485:2016 §8.2.4.

**Roadmap (v2.0):** o agente passará a também **preencher** a OP e o FORM-GQ-0047 automaticamente, a partir dos dados extraídos do Sapiens e seguindo as regras deste protocolo, deixando os documentos completos e prontos para a assinatura do RT.

---

## 2. Documentos esperados por lote

### Obrigatórios
- **OP** (Ordem de Produção, relatório Sapiens nº 212 ou equivalente, com assinatura digital)
- **RC** (Relação de Componentes, relatório Sapiens nº 253)
- **FORM-GQ-0047** preenchido e assinado pelo RT
- **Etiqueta Externa do Produto**

### Opcionais (quando aplicável)
- **Etiquetas de Acessórios**
- **OP de Reprocesso** — *exigida sempre que houver reprovação em inspeção intermediária na OP principal*
- **RNC** (Registro de Não Conformidade) associada

### Documentos-base do projeto (consultados em toda análise)
- Ficha Mestre do produto (= Ficha Técnica)
- FORM-GQ-0085-01 — Códigos de Referências para Produtos
- Manual de Conciliação da Produção
- Guia para Análise da OP

---

## 3. CAMADA 1 — Consistência interna entre documentos do lote

### 3.1 Verificações na OP
- Origem = **070**
- Situação = **Finalizada**
- Datas/horas de início e fim **dentro** de cada estágio em ordem cronológica
- Datas/horas **entre** estágios em ordem cronológica
- Valor Medido (Vlr Medido) de cada inspeção dentro da faixa Vlr Mín – Vlr Máx
- Status de todas as inspeções = **Aprovado**
- Cada componente listado com lote ou número de série rastreável
- **Se houver reprovação em alguma inspeção intermediária → exigir OP de Reprocesso**
- **Vistos de Aprovação no rodapé (Resp. Produção e Resp. Qualidade):** verificar apenas que as datas estão preenchidas e que os campos estão prontos para receber assinatura. Ausência de assinatura **NÃO é NC** — a assinatura é aplicada após o parecer do agente.

#### Tratamento de notações especiais do Sapiens
- Valor medido registrado como **"<X"** (menor que X) onde X é o Vlr Máx ou ligeiramente acima dele: tratar como **Aprovado** (é a notação padrão do Sapiens para medições no limite da resolução do instrumento, conforme definido pela Garantia da Qualidade da Confiance). A Ficha Mestre de cada produto registra essa convenção quando aplicável.
- **Múltiplos planos sob o mesmo número de inspeção** (ex.: inspeção 119267 com planos CMLED.001.03 e CMLED.01 no Estágio 40): comportamento normal do Sapiens — sub-planos complementares (visual + ensaios técnicos) executados sob a mesma inspeção. Cada plano é validado individualmente; ambos precisam estar Aprovados.

### 3.2 Verificações no FORM-GQ-0047
- Nome do produto coerente com o registrado na Ficha Mestre
- Modelo coerente com o Código Sapiens da OP (cruzar contra FORM-GQ-0085-01)
- Nº de série idêntico ao da OP
- Marcações "SIM" apenas nos estágios aplicáveis ao produto; "N/A" nos estágios não aplicáveis (conforme Ficha Mestre)
- Estágios marcados com "X" no SIM batem com o roteiro descrito na OP
- Data de revisão do formulário (rodapé) ≤ data da conciliação
- **Não** deve haver marcação de "cópia controlada" no rodapé (deve ser cópia não controlada)
- Campo "Liberado para Comercialização?" marcado como **SIM** (se as verificações automatizadas das outras camadas passaram)
- Revisão vigente no momento da conciliação (revisão atual aceita; revisão obsoleta = NC)
- **Campo "Visto de Liberação da RT e Garantia da Qualidade":** o agente verifica apenas que o campo existe e está pronto para ser assinado. A assinatura é aplicada pelo RT após a análise do agente — ausência de assinatura **NÃO é NC** no momento da análise.

### 3.3 Verificações na RC
- Origem 070, situação Finalizada
- Nº da OP, código e nome do produto idênticos aos da OP
- Cada componente com lote/série rastreável
- Acessórios descritos na OP e na Ficha Mestre presentes na RC (cruzar pelo Código Sapiens)
- Quantidades previstas = quantidades utilizadas (sem 0/0 e sem divergências)

### 3.4 Verificações na Etiqueta Externa do Produto
- Fabricante: Confiance Medical Produtos Médicos S.A., Rua Bela 852, São Cristóvão, Rio de Janeiro – RJ, CEP 20930-380, CNPJ 05.209.279/0001-31
- Nome do produto e Modelo idênticos ao FORM-GQ-0047 e à Ficha Mestre
- Nº de série idêntico ao FORM-GQ-0047 e à OP
- **Data de Fabricação = Data de Emissão da OP** (canto superior direito da OP)
- Registro/Notificação ANVISA conforme Ficha Mestre e FORM-GQ-0085-01
- Responsável Técnico: Samara Campos — **CREA RJ 2019108911**
- Validade: **INDETERMINADO**

### 3.5 Verificações na Etiqueta de Acessório
- Nome do acessório igual ao da Ficha Mestre e roteiro da OP
- Código Sapiens idêntico ao da RC (cruzar)
- Nº de Lote/Série idêntico ao da RC (cruzar)
- Observação no rodapé referenciando o equipamento da OP + Registro ANVISA do produto principal
- Se acessório fabricado pela Confiance: marcar **"Fabricante"** + Data de Fabricação (validade Indeterminada)
- Se fornecido por terceiro: marcar **"Fornecedor"**
- Se estéril (filtro hidrofóbico, equipos/mangueiras, endoscópio flexível descartável): **validade explícita obrigatória**
- **Regra especial CM-100 (Escape de Fumaça):** desde 07/11/2023 é tratado como acessório do Insuflador e usa o Registro ANVISA do insuflador (não mais o final 0009)

### 3.6 OP de Reprocesso (quando aplicável)
- Justificativa do reprocesso documentada
- Estágio reprocessado identificado
- Parâmetros de reprocesso registrados
- Critério de aceitação após reprocesso atendido
- **Se houver reprovação em inspeção intermediária na OP principal e a OP de Reprocesso NÃO estiver anexada → emitir ALERTA crítico solicitando a OP de Reprocesso antes de qualquer parecer final**

### 3.7 RNC (quando aplicável)
- Rastreabilidade ao lote correta
- Ações corretivas registradas e implementadas antes da liberação
- Tratamento conforme ISO 13485 §8.3

---

## 4. CAMADA 2 — Conformidade contra a Ficha Mestre do Produto

- Componentes da RC correspondem à BOM aprovada na Ficha Mestre (item a item, código Sapiens a código Sapiens)
- Especificações, referências e quantidades dentro do especificado
- Rotulagem atende todos os campos, leiaute e símbolos definidos na Ficha Mestre
- Parâmetros de processo na OP dentro das faixas especificadas na Ficha Mestre (tensão, corrente, temperatura, tempos, valores de calibração — o que se aplicar ao produto)
- Para produtos eletromédicos (CM-LED, monitores, microcâmeras, gravadores, sistemas integrados): conferir presença de etapas de ensaio elétrico previstas na Ficha Mestre conforme IEC 60601

---

## 5. CAMADA 3 — Conformidade regulatória e normativa

| Item | Norma/Referência | Verificação |
|------|------------------|-------------|
| Rastreabilidade do lote (identificação única, status de inspeção, histórico) | ISO 13485:2016 §7.5.9 e §8.3 | Lotes/séries de todos os componentes presentes e rastreáveis na RC |
| Rotulagem regulatória | RDC 665/2022 (BPF) e RDC 751/2022 (registro) | Nome técnico, modelo, fabricante, CNPJ, endereço, registro ANVISA, lote/série, data de fabricação, validade, RT/CREA |
| Liberação de produto acabado | ISO 13485:2016 §8.2.4 | FORM-GQ-0047 preenchido, revisão vigente, "Liberado = SIM" e campos prontos para assinatura do RT (a assinatura propriamente dita ocorre após o parecer do agente) |
| Controle de processo (BPF) | RDC 665/2022 | Evidências de controle e inspeção documentadas na OP |
| Esterilização (quando aplicável) | ISO 11135 / ISO 11137 / ISO 11607 | Ciclo, parâmetros e indicadores documentados; embalagem terminal validada |
| Controle de produto não conforme | ISO 13485:2016 §8.3 | Tratamento da RNC, segregação, disposição e ações corretivas |
| Equipamento eletromédico (quando aplicável) | IEC 60601-1 e colaterais | Ensaios elétricos documentados conforme Ficha Mestre |

---

## 6. Regras gerais de comportamento do agente

1. **Sempre citar a cláusula ou artigo normativo específico** ao apontar uma não conformidade. Nunca usar referências vagas como "conforme a norma".
2. **Documento ausente, ilegível ou incompleto:** marcar como ⚠️ e solicitar o documento completo antes de concluir.
3. **Decisão final de liberação:** o agente nunca decide. Emite parecer técnico; a decisão é sempre do RT humano.
4. **Linguagem:** técnica, objetiva, português do Brasil.
5. **Divergência grave** (componente não aprovado, dado de registro ANVISA incorreto na etiqueta, ausência de assinatura em ponto crítico, OP de Reprocesso ausente quando há reprovação em inspeção): destacar com ❌ e **nota de ATENÇÃO em negrito**.
6. **Documento opcional não enviado e sem indício de necessidade:** marcar itens correspondentes como N/A, sem penalizar.
7. **Ressalvas menores** (⚠️) sem NC crítica (❌): classificar resultado como **"CONFORME COM RESSALVAS"** e listar ações de melhoria sugeridas.

---

## 7. Formato do relatório de saída

Estrutura fixa, em Markdown, com as seções:

1. Cabeçalho do lote (produto, código, OP, lote/série, data da análise)
2. Resultado geral (✅ CONFORME | ⚠️ CONFORME COM RESSALVAS | ❌ NÃO CONFORME)
3. Checklist de verificação (3 tabelas: Camada 1, Camada 2, Camada 3) com Status e Observação por item
4. Divergências e Não Conformidades (NC-01, NC-02… com documento afetado, referência normativa, descrição e recomendação)
5. Documentos analisados
6. Parecer técnico final (sem decisão de liberação)

O modelo detalhado das tabelas e seções está nas Instruções do Projeto (system prompt), seção "Formato do Relatório de Saída".

---

## 8. Requisitos técnicos para a plataforma definitiva

Identificados durante o teste do lote 6819:

1. **Parser de .docx no backend** — todas as etiquetas externas e de acessórios são produzidas em .docx. A plataforma deve incorporar extração de texto e (idealmente) layout dos .docx para que o agente possa cruzar automaticamente os campos da etiqueta contra Ficha Mestre, OP, RC e FORM-GQ-0047. Bibliotecas candidatas: `python-docx` (Python) ou `mammoth` (Node.js).

2. **Parser de PDFs do Sapiens** — OP e RC são geradas via "Microsoft Print to PDF" do Sapiens (relatórios nº 212 e nº 253) com layout tabular. O parser precisa lidar com tabelas, cabeçalhos repetidos por página e medições com notação `<X` ou `>X`.

3. **Detecção e validação de assinaturas digitais** — apenas para etapa pós-parecer (quando o RT assinar). Não aplicável na verificação do agente.

4. **Histórico de análises** — armazenar cada parecer emitido para construção da base de tempos médios por operação e por estágio (mencionado na Ficha Mestre seção 5: tempos médios serão calculados a partir de histórico de OPs analisadas).

---

## 9. Roadmap funcional

| Fase | Funcionalidade |
|------|----------------|
| **v1.0** | Protocolo inicial validado contra o Manual, Guia e Ficha Mestre. |
| **v1.1 (atual)** | Ajustes pós-teste do lote 6819: tratamento de notações "<X" do Sapiens; planos múltiplos por inspeção; clarificação sobre assinaturas pós-análise. |
| **v2.0** | Auto-preenchimento da OP e do FORM-GQ-0047 pelo agente, a partir dos dados extraídos do Sapiens, deixando os documentos prontos para assinatura do RT. |
| **v2.1** | Análise de tempos médios por operação/estágio, com sinalização automática de OPs que destoam do histórico. |

---

## 10. Histórico de versões

| Versão | Data | Alteração |
|--------|------|-----------|
| 1.0 | 13/05/2026 | Protocolo inicial consolidado a partir do Manual de Conciliação da Produção, Guia para Análise da OP, Ficha Mestre CM-LED, FORM-GQ-0085-01 e Instrução do Projeto. Validado por Maria Luiza Zaccur. |
| 1.1 | 13/05/2026 | Após teste do lote 6819: (a) clarificação de que o agente não verifica assinaturas (são aplicadas pós-parecer); (b) notação "<X" do Sapiens tratada como Aprovado quando aplicável; (c) múltiplos planos sob a mesma inspeção formalizados como prática padrão; (d) adicionados requisitos técnicos da plataforma e roadmap v2.0 (auto-preenchimento). |
