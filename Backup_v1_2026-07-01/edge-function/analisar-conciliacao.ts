// ============================================================================
// Supabase Edge Function: analisar-conciliacao
// Recebe os textos extraídos dos documentos do lote, chama o Gemini Flash com
// o Protocolo v1.1 da Confiance Medical, salva o resultado e devolve o parecer.
//
// DEPLOY: cole este arquivo INTEIRO no editor de Edge Functions do Supabase
// Studio (Edge Functions → Create new function → nome "analisar-conciliacao")
// e clique em Deploy.
//
// SECRETS necessárias (Supabase → Settings → Edge Functions → Secrets):
//   GEMINI_API_KEY = (sua key do Google AI Studio)
// As secrets SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY já são injetadas
// automaticamente pelo Supabase em toda Edge Function.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Modelo Gemini gratuito - usando a variante experimental do 2.0-flash, que costuma
// ter free tier ativo mesmo em projetos onde a versão estável vem com cota 0.
// Alternativas se este modelo der erro:
//   gemini-1.5-flash              → fallback se -exp não estiver disponível
//   gemini-1.5-flash-8b           → menor, mais leve
//   gemini-1.5-flash-002          → versão fixada do 1.5-flash
//   gemini-2.0-flash              → estável (em alguns projetos vem com cota 0)
const GEMINI_MODEL = "gemini-2.0-flash-exp";

// ============================================================================
// SYSTEM PROMPT — Protocolo v1.1 da Confiance Medical (resumido)
// ============================================================================
const SYSTEM_PROMPT = `Você é um especialista sênior em Garantia da Qualidade e Assuntos Regulatórios de Dispositivos Médicos, atuando como agente verificador independente do processo de conciliação de produção da Confiance Medical. Trabalha em português do Brasil.

# Base normativa
- ISO 13485:2016 — Sistema de gestão da qualidade para dispositivos médicos
- RDC 665/2022 (ANVISA) — Boas Práticas de Fabricação
- RDC 751/2022 (ANVISA) — Registro de dispositivos médicos
- ISO 11607 — Embalagens para dispositivos médicos esterilizados
- IEC 60601 — Equipamentos eletromédicos (quando aplicável)

# Metodologia obrigatória — 3 camadas em ordem

## CAMADA 1 — Consistência interna entre documentos do lote
- OP: Origem 070, situação Finalizada, cronologia consistente, inspeções Aprovadas, componentes com lote/série
- FORM-GQ-0047: nome/modelo/série coerentes com OP e Ficha Mestre, revisão vigente, "Liberado=SIM" marcado, marcações de estágio batendo com Ficha Mestre + roteiro da OP
- RC: origem 070, finalizada, componentes da BOM presentes, quantidades prevista=utilizada, lote/série rastreável
- Etiqueta Externa: fabricante/endereço/CNPJ/modelo/série/registro ANVISA/data fabricação=data emissão OP/validade=INDETERMINADO/CREA RT
- Etiquetas Acessórios: nome bate ficha, código Sapiens=RC, lote/série=RC, observação referencia produto principal+ANVISA, indica Fabricante (Confiance) ou Fornecedor

## CAMADA 2 — Conformidade contra a Ficha Mestre do produto
- BOM da RC = BOM da Ficha (item a item, código Sapiens a código Sapiens)
- Especificações dentro do espec
- Rotulagem atende todos os campos da seção 3 da Ficha
- Parâmetros de processo da OP dentro das faixas da Ficha

## CAMADA 3 — Conformidade regulatória
- Rastreabilidade (ISO 13485 §7.5.9 e §8.3)
- Rotulagem (RDC 665/2022, RDC 751/2022)
- Checklist liberação (ISO 13485 §8.2.4)
- BPF (RDC 665/2022)
- Para eletromédicos (CM-LED, monitores, microcâmeras, gravadores, sistemas integrados): verificar IEC 60601 nos ensaios elétricos da OP

# Regras especiais da Confiance (protocolo v1.1)

1. **Vistos de Aprovação em branco são ESPERADOS** — assinaturas são aplicadas APÓS o seu parecer. Não marcar como NC.
2. **Notação "<X" em medições (ex.: "<0,1 Ohm") é padrão do Sapiens** — tratar como Aprovado, é o limite de resolução do instrumento.
3. **Múltiplos planos sob mesma inspeção** (ex.: 119267 com CMLED.001.03 e CMLED.01) é prática padrão — Aprovado.
4. **OP de Reprocesso** é exigida APENAS se houver reprovação em inspeção intermediária da OP principal. Se OP é tipo Normal e todas inspeções Aprovadas, marcar item como N/A. Se houver reprovação e a OP de Reprocesso não foi enviada, emitir ALERTA crítico.
5. **CM-100 (Escape de Fumaça)**: desde 07/11/2023 é acessório do Insuflador, usa o Registro ANVISA do insuflador, não o final 0009.

# Diretrizes de comportamento

- SEMPRE cite cláusula/artigo específico em NCs e ressalvas. NUNCA use referências vagas.
- NUNCA decida liberação do lote. Você emite parecer técnico; decisão é do RT humano (Samara Campos ou Fernando) conforme ISO 13485 §8.2.4.
- Documento ausente ou ilegível → marcar como ⚠️ e solicitar.
- Apenas ressalvas menores (sem NC crítica) → "ressalva". NC crítica (componente não aprovado, dado ANVISA errado, OP Reprocesso ausente quando há reprovação, etc.) → "nao_conforme".
- Resultado geral: "conforme" se tudo ✅; "ressalva" se há ⚠️ mas nenhuma ❌; "nao_conforme" se há qualquer ❌.

# Saída

Responda APENAS com um JSON válido seguindo EXATAMENTE este schema (sem markdown, sem código de bloco, apenas o objeto JSON puro):

{
  "produto": {
    "nome": "string — nome comercial (ex.: Fonte de Luz LED)",
    "modelo": "string — modelo (ex.: CM-LED)",
    "codigo_sapiens": "string — código Sapiens do produto",
    "numero_op": "string — número da OP",
    "numero_serie": "string — nº de série/lote",
    "registro_anvisa": "string — registro ou notificação ANVISA"
  },
  "resultado_geral": "conforme" | "ressalva" | "nao_conforme",
  "parecer_resumo": "string — parágrafo de 2-4 linhas resumindo o parecer",
  "documentos_analisados": ["lista dos documentos efetivamente analisados"],
  "camadas": {
    "camada_1": [
      { "item": "string", "status": "conforme" | "ressalva" | "nao_conforme" | "na", "observacao": "string" }
    ],
    "camada_2": [
      { "item": "string", "status": "conforme" | "ressalva" | "nao_conforme" | "na", "observacao": "string" }
    ],
    "camada_3": [
      { "item": "string", "norma": "string — ex.: ISO 13485 §7.5.9", "status": "conforme" | "ressalva" | "nao_conforme" | "na", "observacao": "string" }
    ]
  },
  "apontamentos": [
    {
      "codigo": "string — NC-01, R-01, etc.",
      "severidade": "ressalva" | "nao_conforme",
      "camada": 1 | 2 | 3,
      "documento_afetado": "string",
      "referencia_normativa": "string — cláusula/artigo específico",
      "descricao": "string",
      "recomendacao": "string"
    }
  ],
  "recomendacoes_melhoria": ["lista de sugestões de melhoria não impeditivas"]
}

Se não houver apontamentos, retorne apontamentos: []. Se não houver recomendações, recomendacoes_melhoria: [].`;

// ============================================================================
// HANDLER
// ============================================================================
serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Use POST" }, 405);
  }

  try {
    // ----- Autenticação do usuário (usa ANON_KEY para validar o JWT)
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return jsonResponse({ error: "Authorization header faltando" }, 401);

    const supabaseAuth = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await supabaseAuth.auth.getUser();
    if (userError || !userData?.user) {
      return jsonResponse({ error: "Sessão inválida", details: userError?.message }, 401);
    }

    // Cliente com service role para escrever na base (bypassa RLS)
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // ----- Parse do body
    const body = await req.json();
    const documentos = body?.documentos as {
      op: string;
      rc: string;
      form_gq_0047: string;
      etiqueta_externa: string;
      etiqueta_acessorio?: string[];
      op_reprocesso?: string;
      rnc?: string;
    };

    if (!documentos?.op || !documentos?.rc || !documentos?.form_gq_0047 || !documentos?.etiqueta_externa) {
      return jsonResponse({ error: "Documentos obrigatórios faltando (op, rc, form_gq_0047, etiqueta_externa)." }, 400);
    }

    // ----- Buscar todas as fichas mestres ativas (servem como base de conhecimento)
    const { data: fichasData } = await supabase
      .from("fichas_mestres")
      .select(`
        id, versao, nome_comercial, convencao_nro_serie, exemplo_nro_serie,
        razao_social, cnpj, endereco_fabrica, responsavel_tecnico, crea_rt, responsavel_legal,
        etiqueta_externa_campos, regras_negocio, observacoes,
        produto:produtos(modelo, equipamento, codigo_referencia, registro_anvisa, codigo_sapiens, derivacao),
        acessorios:acessorios_aplicaveis(ordem, descricao, codigo_sapiens, obrigatorio, is_fabricante_confiance, esteril, observacao),
        roteiro:roteiro_form_gq_0047(ordem, item_checklist, marcacao_esperada, justificativa),
        inspecoes:inspecoes_criterios(estagio_codigo, estagio_nome, criterio_aceitacao),
        bom:componentes_bom(codigo_sapiens, descricao, tipo_controle, prefixo_serie, quantidade, critico, observacao)
      `)
      .eq("ativa", true);

    // ----- Construir mensagem do usuário com os documentos e a base
    const fichasJson = JSON.stringify(fichasData ?? [], null, 2);

    const userMessage = `# DOCUMENTOS DO LOTE A ANALISAR

## 1. Ordem de Produção (OP)
\`\`\`
${documentos.op}
\`\`\`

## 2. Relação de Componentes (RC)
\`\`\`
${documentos.rc}
\`\`\`

## 3. FORM-GQ-0047 preenchido
\`\`\`
${documentos.form_gq_0047}
\`\`\`

## 4. Etiqueta Externa do Produto
\`\`\`
${documentos.etiqueta_externa}
\`\`\`
${documentos.etiqueta_acessorio?.length ? `\n## 5. Etiquetas de Acessórios (${documentos.etiqueta_acessorio.length})\n${documentos.etiqueta_acessorio.map((t, i) => `### Acessório ${i + 1}\n\`\`\`\n${t}\n\`\`\``).join("\n\n")}` : ""}
${documentos.op_reprocesso ? `\n## 6. OP de Reprocesso\n\`\`\`\n${documentos.op_reprocesso}\n\`\`\`` : ""}
${documentos.rnc ? `\n## 7. RNC associada\n\`\`\`\n${documentos.rnc}\n\`\`\`` : ""}

# BASE DE CONHECIMENTO — FICHAS MESTRES CADASTRADAS

A seguir, todas as fichas mestres ativas no sistema. Identifique a aplicável pelo Código Sapiens / Modelo / Prefixo de Nº de Série presente na OP e use-a para os cruzamentos da Camada 2:

\`\`\`json
${fichasJson}
\`\`\`

---

Execute a análise seguindo o protocolo v1.1. Retorne APENAS o JSON estruturado conforme especificado, sem texto antes ou depois, sem blocos de código markdown.`;

    // ----- Chamada ao Gemini
    const startTs = Date.now();
    const geminiResp = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          system_instruction: { parts: [{ text: SYSTEM_PROMPT }] },
          contents: [{ role: "user", parts: [{ text: userMessage }] }],
          generationConfig: {
            responseMimeType: "application/json",
            temperature: 0.2,
            maxOutputTokens: 8192,
          },
          safetySettings: [
            { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE" },
            { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE" },
            { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE" },
            { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE" },
          ],
        }),
      },
    );

    const tempoExecucao = Date.now() - startTs;

    if (!geminiResp.ok) {
      const errText = await geminiResp.text();
      return jsonResponse({ error: `Gemini API erro: ${errText}` }, 502);
    }

    const geminiData = await geminiResp.json();
    const rawText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!rawText) return jsonResponse({ error: "Resposta vazia do Gemini", details: geminiData }, 502);

    let parecer: any;
    try {
      // Limpa possíveis markdown fences que o Gemini às vezes adiciona
      const cleaned = rawText.replace(/^```json\s*/i, "").replace(/```\s*$/i, "").trim();
      parecer = JSON.parse(cleaned);
    } catch (e) {
      return jsonResponse({ error: "Resposta do Gemini não é JSON válido", raw: rawText }, 502);
    }

    // ----- Tenta associar produto/ficha pelo modelo retornado
    let produtoId: string | null = null;
    let fichaId: string | null = null;
    if (parecer?.produto?.modelo) {
      const { data: prod } = await supabase
        .from("produtos")
        .select("id, ficha:fichas_mestres(id)")
        .eq("modelo", parecer.produto.modelo)
        .maybeSingle();
      if (prod) {
        produtoId = prod.id;
        const ficha = Array.isArray(prod.ficha) ? prod.ficha[0] : prod.ficha;
        fichaId = ficha?.id ?? null;
      }
    }

    // ----- Salvar análise no banco
    const { data: analise, error: insertError } = await supabase
      .from("analises")
      .insert({
        produto_id: produtoId,
        ficha_id: fichaId,
        numero_op: parecer?.produto?.numero_op ?? null,
        numero_serie: parecer?.produto?.numero_serie ?? null,
        nome_produto: parecer?.produto?.nome ?? null,
        modelo: parecer?.produto?.modelo ?? null,
        registro_anvisa: parecer?.produto?.registro_anvisa ?? null,
        status: parecer?.resultado_geral ?? "em_andamento",
        parecer_resumo: parecer?.parecer_resumo ?? null,
        parecer_completo: parecer,
        finalizada_em: new Date().toISOString(),
        tempo_execucao_ms: tempoExecucao,
        created_by: userData.user.id,
      })
      .select()
      .single();

    if (insertError) {
      return jsonResponse({ error: `Erro ao salvar análise: ${insertError.message}`, parecer }, 500);
    }

    // ----- Salvar apontamentos
    if (Array.isArray(parecer?.apontamentos) && parecer.apontamentos.length > 0) {
      const apontamentos = parecer.apontamentos.map((ap: any, idx: number) => ({
        analise_id: analise.id,
        ordem: idx + 1,
        codigo: ap.codigo ?? null,
        severidade: ap.severidade ?? "ressalva",
        camada: ap.camada ?? 1,
        documento_afetado: ap.documento_afetado ?? null,
        referencia_normativa: ap.referencia_normativa ?? null,
        descricao: ap.descricao ?? "",
        recomendacao: ap.recomendacao ?? null,
      }));
      await supabase.from("apontamentos").insert(apontamentos);
    }

    return jsonResponse({ success: true, analise_id: analise.id, parecer });
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
