// ============================================================================
// Supabase Edge Function: converter-para-pdf
// Confiance Medical · Plataforma de Conciliação da Produção
// ----------------------------------------------------------------------------
// Recebe um arquivo XLSX ou DOCX, chama o CloudConvert para converter em PDF
// e devolve o PDF binário. O PDF é gerado SEM criptografia e SEM restrições,
// compatível com assinatura digital pelo Adobe Acrobat (ICP-Brasil, etc).
//
// DEPLOY:
//   1. Vá no Supabase Studio → Edge Functions → Create new function
//   2. Function name (exatamente): converter-para-pdf
//   3. Cole TODO este arquivo no editor
//   4. Clique em Deploy function
//
// SECRETS necessárias (Settings → Edge Functions → Manage secrets):
//   CLOUDCONVERT_API_KEY = (sua API key v2 do CloudConvert)
//
// Como o cliente chama:
//   POST {SUPABASE_URL}/functions/v1/converter-para-pdf
//   Headers:
//     Authorization: Bearer {access_token_do_usuario_logado}
//     Content-Type: application/octet-stream
//     X-Source-Format: xlsx    (ou docx)
//     X-Filename: FORM-GQ-0047_6819_LEDT-20261-6.xlsx
//   Body: bytes brutos do arquivo
//
//   Retorno (sucesso):
//     200 OK · Content-Type: application/pdf · body = bytes do PDF
//   Retorno (erro):
//     4xx/5xx · Content-Type: application/json · body = { error: "...detalhes..." }
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CLOUDCONVERT_API_KEY = Deno.env.get("CLOUDCONVERT_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-source-format, x-filename",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonError(message: string, status = 500) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return jsonError("Use POST", 405);

  try {
    // ----- Autenticação: exige usuário logado na plataforma
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return jsonError("Authorization header faltando", 401);
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await supabase.auth.getUser();
    if (userErr || !userData?.user) {
      return jsonError("Sessão inválida: " + (userErr?.message || "sem usuário"), 401);
    }

    // ----- Parse de headers e body
    const sourceFormat = (req.headers.get("x-source-format") || "xlsx")
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "");
    const filename = req.headers.get("x-filename") || `arquivo.${sourceFormat}`;
    const fileBytes = new Uint8Array(await req.arrayBuffer());

    if (fileBytes.length === 0) return jsonError("Arquivo vazio.", 400);
    if (!["xlsx", "xls", "docx", "doc", "pptx", "ppt", "pdf", "html", "htm"].includes(sourceFormat)) {
      return jsonError(`Formato não suportado: ${sourceFormat}`, 400);
    }

    // ----- 1. Criar job no CloudConvert (3 tasks: import → convert → export)
    //
    // Estratégia por tipo de entrada:
    //  - Office (xlsx/docx/etc.): convert com engine libreoffice → PDF.
    //  - PDF de entrada: operação `optimize` com profile `web` — re-escreve o
    //    PDF (via qpdf/ghostscript) regenerando a estrutura SEM as restrições/
    //    proteções que o Sapiens embute. Mantém visual original e habilita
    //    assinatura/edição no Adobe Acrobat.
    //  - HTML: convert com engine chrome (Chromium headless) — renderiza CSS
    //    moderno (cores, fontes, layout). Usado para o relatório de Resumo da
    //    Análise gerado pela plataforma.
    const cvAuth = { Authorization: `Bearer ${CLOUDCONVERT_API_KEY}` };
    const isPdfInput = sourceFormat === "pdf";
    const isHtmlInput = sourceFormat === "html" || sourceFormat === "htm";
    let conversionTask: Record<string, unknown>;
    if (isPdfInput) {
      conversionTask = {
        operation: "optimize",
        input: "import-file",
        input_format: "pdf",
        output_format: "pdf",
        profile: "web",
      };
    } else if (isHtmlInput) {
      conversionTask = {
        operation: "convert",
        input: "import-file",
        input_format: "html",
        output_format: "pdf",
        engine: "chrome",
        // Configurações para o relatório do Resumo da Análise — A4 portrait
        page_orientation: "portrait",
        page_size: "A4",
        margin_top: 24,
        margin_bottom: 24,
        margin_left: 18,
        margin_right: 18,
        print_background: true,
      };
    } else {
      conversionTask = {
        operation: "convert",
        input: "import-file",
        input_format: sourceFormat,
        output_format: "pdf",
        engine: "libreoffice",
      };
    }

    const jobResp = await fetch("https://api.cloudconvert.com/v2/jobs", {
      method: "POST",
      headers: { ...cvAuth, "Content-Type": "application/json" },
      body: JSON.stringify({
        tasks: {
          "import-file": { operation: "import/upload" },
          "convert-file": conversionTask,
          "export-file": { operation: "export/url", input: "convert-file" },
        },
        tag: `confiance-conciliacao-${userData.user.id}`,
      }),
    });
    if (!jobResp.ok) {
      return jsonError(`CloudConvert /jobs erro: ${await jobResp.text()}`, 502);
    }
    const job = await jobResp.json();

    // ----- 2. Upload do arquivo para a URL pré-assinada que o CloudConvert devolveu
    const importTask = job.data.tasks.find((t: any) => t.name === "import-file");
    if (!importTask?.result?.form) {
      return jsonError("CloudConvert não retornou URL de upload.", 502);
    }
    const { url: uploadUrl, parameters: uploadParams } = importTask.result.form;

    const uploadFD = new FormData();
    for (const [k, v] of Object.entries(uploadParams)) {
      uploadFD.append(k, v as string);
    }
    const mimeBySrc: Record<string, string> = {
      xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      xls: "application/vnd.ms-excel",
      docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      doc: "application/msword",
      pptx: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
      ppt: "application/vnd.ms-powerpoint",
      pdf: "application/pdf",
      html: "text/html",
      htm: "text/html",
    };
    uploadFD.append(
      "file",
      new Blob([fileBytes], { type: mimeBySrc[sourceFormat] || "application/octet-stream" }),
      filename,
    );

    const uploadResp = await fetch(uploadUrl, { method: "POST", body: uploadFD });
    if (!uploadResp.ok) {
      return jsonError(`Upload p/ CloudConvert falhou: ${await uploadResp.text()}`, 502);
    }

    // ----- 3. Polling do status do job (CloudConvert é assíncrono)
    const jobId = job.data.id;
    let exportUrl: string | null = null;
    const startedAt = Date.now();
    const TIMEOUT_MS = 90_000; // 90s — converter Office costuma levar 5-30s

    while (Date.now() - startedAt < TIMEOUT_MS) {
      await new Promise((r) => setTimeout(r, 1500));
      const statusResp = await fetch(
        `https://api.cloudconvert.com/v2/jobs/${jobId}`,
        { headers: cvAuth },
      );
      if (!statusResp.ok) continue;
      const statusJson = await statusResp.json();
      const status = statusJson.data.status;
      if (status === "finished") {
        const exportTask = statusJson.data.tasks.find(
          (t: any) => t.name === "export-file",
        );
        const files = exportTask?.result?.files || [];
        if (files.length > 0) {
          exportUrl = files[0].url;
          break;
        }
      } else if (status === "error") {
        const errTask = statusJson.data.tasks.find((t: any) => t.status === "error");
        return jsonError(
          `CloudConvert erro na conversão: ${errTask?.message || "desconhecido"}`,
          502,
        );
      }
    }

    if (!exportUrl) return jsonError("Conversão expirou (timeout 90s).", 504);

    // ----- 4. Download do PDF convertido e devolve ao cliente
    const pdfResp = await fetch(exportUrl);
    if (!pdfResp.ok) {
      return jsonError(`Falha ao baixar PDF do CloudConvert: ${pdfResp.status}`, 502);
    }
    const pdfBytes = await pdfResp.arrayBuffer();

    // Nome do PDF de saída = nome original com extensão trocada
    const outName = filename.replace(/\.[^.]+$/, "") + ".pdf";

    return new Response(pdfBytes, {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/pdf",
        "Content-Disposition": `attachment; filename="${outName}"`,
        // Cabeçalho para auditoria — útil se for inspecionar manualmente
        "X-Source-Format": sourceFormat,
        "X-Source-Filename": filename,
      },
    });
  } catch (err) {
    return jsonError(`Erro inesperado: ${(err as Error).message}`, 500);
  }
});
