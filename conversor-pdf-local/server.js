/* ============================================================================
 * Conversor PDF Local — Confiance Medical
 * Plataforma de Conciliacao da Producao
 * ----------------------------------------------------------------------------
 *   POST /converter-pdf   (xlsx/docx/pdf/html -> PDF)
 *   POST /salvar-pacote    (grava o pacote na pasta do servidor)
 *      Headers: X-Dest-Path, X-Filename, X-Extract ('true' = descompacta o ZIP
 *               na pasta em vez de salvar o .zip)
 *   GET  /health
 * ==========================================================================*/

// Carrega variaveis de um arquivo .env na pasta do servico (ex.: SUPABASE_URL,
// SUPABASE_SERVICE_ROLE_KEY). Assim nao dependem do 'set' e sobrevivem a reinicios.
try { require('dotenv').config(); } catch (e) { /* dotenv opcional */ }

const express = require('express');
const cors = require('cors');
const os = require('os');
const fs = require('fs');
const path = require('path');
const { execFile } = require('child_process');
const { promisify } = require('util');

// ---------------------------------------------------------------------------
// Windows: esconde as "janelinhas" de console (prompt piscando) dos processos
// filhos disparados durante a montagem do pacote — Ghostscript (gswin64c) e
// LibreOffice (soffice), chamados internamente pelas libs. Injeta
// windowsHide:true quando a chamada não especificou. Sem efeito fora do Windows.
if (process.platform === 'win32') {
  const cp = require('child_process');
  const patchar = (fn) => {
    const orig = cp[fn];
    if (typeof orig !== 'function') return;
    cp[fn] = function (...args) {
      let idxOpts = -1;
      for (let i = 0; i < args.length; i++) {
        const a = args[i];
        if (a && typeof a === 'object' && !Array.isArray(a) && typeof a !== 'function') { idxOpts = i; break; }
      }
      if (idxOpts >= 0) {
        if (args[idxOpts].windowsHide === undefined) args[idxOpts].windowsHide = true;
      } else {
        const opts = { windowsHide: true };
        if (typeof args[args.length - 1] === 'function') args.splice(args.length - 1, 0, opts);
        else args.push(opts);
      }
      return orig.apply(this, args);
    };
  };
  ['spawn', 'exec', 'execFile', 'spawnSync', 'execSync', 'execFileSync'].forEach(patchar);
}

const libre = require('libreoffice-convert');
const AdmZip = require('adm-zip');
const { createClient } = require('@supabase/supabase-js');

// Parser CSV simples (lida com aspas e vírgulas dentro de campo). Retorna array de linhas,
// cada linha um array de células.
function parseCSV(txt) {
  const linhas = [];
  let campo = '', linha = [], emAspas = false;
  const s = String(txt || '').replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (emAspas) {
      if (c === '"') { if (s[i + 1] === '"') { campo += '"'; i++; } else emAspas = false; }
      else campo += c;
    } else if (c === '"') emAspas = true;
    else if (c === ',') { linha.push(campo); campo = ''; }
    else if (c === '\n') { linha.push(campo); linhas.push(linha); linha = []; campo = ''; }
    else campo += c;
  }
  if (campo.length || linha.length) { linha.push(campo); linhas.push(linha); }
  return linhas;
}

// Supabase Admin (service_role) — SÓ no servidor. Usado para convidar usuários.
const SUPABASE_URL = process.env.SUPABASE_URL || '';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
let _supaAdmin = null;
function supaAdmin() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error('Configure SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY nas variaveis de ambiente do servico.');
  }
  if (!_supaAdmin) _supaAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { autoRefreshToken: false, persistSession: false } });
  return _supaAdmin;
}

const libreConvert = promisify(libre.convert);
const execFileP = promisify(execFile);

const PORT = process.env.PORT || 3001;
const GHOSTSCRIPT_BIN = process.env.GHOSTSCRIPT_BIN || (process.platform === 'win32' ? 'gswin64c' : 'gs');
if (process.env.SOFFICE_BIN) process.env.LIBRE_OFFICE_EXE = process.env.SOFFICE_BIN;

const OFFICE = new Set(['xlsx', 'xls', 'docx', 'doc', 'pptx', 'ppt', 'odt', 'ods']);

const app = express();
app.use(cors());
app.use(express.raw({ type: '*/*', limit: '80mb' }));

// Serve a plataforma por HTTP (necessario para o Supabase aceitar o redirect do
// convite — file:// e bloqueado). Defina PLATAFORMA_HTML no .env com o caminho do
// plataforma.html. Acesse em http://SERVIDOR:3001/
const PLATAFORMA_HTML = process.env.PLATAFORMA_HTML || '';
app.get(['/', '/plataforma.html'], (req, res) => {
  if (!PLATAFORMA_HTML) return res.status(404).send('Defina PLATAFORMA_HTML no .env com o caminho do plataforma.html.');
  res.sendFile(PLATAFORMA_HTML, (err) => {
    if (err) { console.error('[ERRO servir plataforma]', err.message); if (!res.headersSent) res.status(500).send('Nao foi possivel ler o plataforma.html em: ' + PLATAFORMA_HTML); }
  });
});

app.get('/health', (req, res) => {
  res.json({ ok: true, servico: 'conversor-pdf-local', versao: '1.4.0' });
});

// ---- Conversao para PDF ---------------------------------------------------
app.post('/converter-pdf', async (req, res) => {
  const t0 = Date.now();
  const fmt = String(req.get('X-Source-Format') || 'xlsx').toLowerCase().replace(/[^a-z0-9]+/g, '');
  const filename = req.get('X-Filename') || `arquivo.${fmt}`;
  const input = req.body;
  if (!input || !input.length) return res.status(400).json({ error: 'Arquivo vazio.' });
  try {
    let pdf;
    if (OFFICE.has(fmt)) {
      pdf = await libreConvert(input, '.pdf', undefined);
    } else if (fmt === 'pdf') {
      pdf = await otimizarPdf(input);
    } else if (fmt === 'html' || fmt === 'htm') {
      // X-Pdf-Landscape: 1 → A4 paisagem (relatório de qualidade com tabelas largas).
      pdf = await htmlParaPdf(input.toString('utf8'), { landscape: req.get('X-Pdf-Landscape') === '1' });
    } else {
      return res.status(400).json({ error: `Formato nao suportado: ${fmt}` });
    }
    const outName = filename.replace(/\.[^.]+$/, '') + '.pdf';
    res.set({
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename="${outName}"`,
      'X-Source-Format': fmt,
    });
    console.log(`[OK] ${fmt} -> pdf (${filename}) ${pdf.length} bytes em ${Date.now() - t0}ms`);
    return res.send(pdf);
  } catch (err) {
    console.error(`[ERRO] ${fmt} (${filename}):`, err.message);
    return res.status(500).json({ error: err.message || String(err) });
  }
});

// ---- Salvar pacote na pasta do servidor -----------------------------------
app.post('/salvar-pacote', (req, res) => {
  const destPath = req.get('X-Dest-Path');
  const filename = req.get('X-Filename');
  const extrair = String(req.get('X-Extract') || '').toLowerCase() === 'true';
  const bytes = req.body;
  if (!destPath) return res.status(400).json({ error: 'X-Dest-Path (pasta destino) ausente.' });
  if (!filename) return res.status(400).json({ error: 'X-Filename ausente.' });
  if (!bytes || !bytes.length) return res.status(400).json({ error: 'Arquivo vazio.' });
  try {
    fs.mkdirSync(destPath, { recursive: true });
    if (extrair) {
      // Descompacta o ZIP direto na pasta — vem como pasta normal (não compactada).
      // Extração MANUAL (writeFileSync) para evitar o chmod do extractAllTo, que
      // falha em pastas de rede (UNC) com ENOENT.
      const zip = new AdmZip(Buffer.from(bytes));
      for (const entry of zip.getEntries()) {
        const rel = String(entry.entryName).replace(/\\/g, '/');
        if (rel.split('/').some((seg) => seg === '..')) continue; // seguranca (path traversal)
        const target = path.join(destPath, rel);
        if (entry.isDirectory) { fs.mkdirSync(target, { recursive: true }); continue; }
        fs.mkdirSync(path.dirname(target), { recursive: true });
        fs.writeFileSync(target, entry.getData());
      }
      const raiz = filename.replace(/\.zip$/i, '');
      const destino = path.join(destPath, raiz);
      console.log(`[EXTRAÍDO] ${destino} (do zip ${bytes.length} bytes)`);
      return res.json({ ok: true, caminho: destino, extraido: true });
    }
    const safeName = path.basename(String(filename)).replace(/[<>:"/\\|?*\x00-\x1f]/g, '_');
    const full = path.join(destPath, safeName);
    fs.writeFileSync(full, bytes);
    console.log(`[SALVO] ${full} (${bytes.length} bytes)`);
    return res.json({ ok: true, caminho: full });
  } catch (err) {
    console.error('[ERRO salvar-pacote]', err.message);
    return res.status(500).json({ error: err.message || String(err) });
  }
});

// ---- Convidar usuario (envia e-mail de convite via Supabase Admin) ---------
//   Body JSON: { email, cargo, permissoes, convidado_por, redirectTo }
//   Cria/convida o usuario no Supabase Auth, grava o perfil (cargo+permissoes)
//   e registra o convite. A service_role key fica SOMENTE aqui no servidor.
app.post('/convidar-usuario', async (req, res) => {
  let body;
  try { body = JSON.parse(Buffer.from(req.body).toString('utf8')); } catch (e) { return res.status(400).json({ error: 'JSON invalido.' }); }
  const { email, cargo, permissoes, convidado_por, redirectTo } = body || {};
  if (!email) return res.status(400).json({ error: 'email ausente.' });
  try {
    const admin = supaAdmin();
    const { data, error } = await admin.auth.admin.inviteUserByEmail(email, {
      redirectTo: redirectTo || undefined,
      data: { cargo: cargo || null },
    });
    if (error) throw error;
    const uid = data && data.user && data.user.id;
    if (uid) {
      await admin.from('perfis').upsert(
        { id: uid, email, cargo: cargo || null, permissoes: permissoes || {}, ativo: true, convidado_por: convidado_por || null },
        { onConflict: 'id' }
      );
    }
    await admin.from('convites').insert({ email, cargo: cargo || null, permissoes: permissoes || {}, convidado_por: convidado_por || null, status: 'pendente' });
    console.log(`[CONVITE] ${email} (${cargo}) por ${convidado_por}`);
    return res.json({ ok: true, user_id: uid || null });
  } catch (err) {
    console.error('[ERRO convidar-usuario]', err.message);
    return res.status(500).json({ error: err.message || String(err) });
  }
});

// ---- Alerta no Slack (Incoming Webhook) -----------------------------------
//   Body JSON: { texto, canal? }  → posta a mensagem no canal escolhido.
//   canal: 'pcp' (canal pcp_gq) | 'almoxarifado' (canal almoxarifado_gq).
//   Cada canal tem seu proprio Incoming Webhook. Defina no .env do servico:
//     SLACK_WEBHOOK_PCP=...            (canal pcp_gq)
//     SLACK_WEBHOOK_ALMOXARIFADO=...   (canal almoxarifado_gq)
//   SLACK_WEBHOOK_URL continua sendo o fallback geral (usado se o especifico
//   nao estiver configurado, para nao quebrar durante a transicao).
const SLACK_WEBHOOK_URL = process.env.SLACK_WEBHOOK_URL || '';
const SLACK_WEBHOOK_PCP = process.env.SLACK_WEBHOOK_PCP || '';
const SLACK_WEBHOOK_ALMOXARIFADO = process.env.SLACK_WEBHOOK_ALMOXARIFADO || '';
function webhookDoCanal(canal) {
  const c = String(canal || '').toLowerCase();
  if (c === 'pcp') return SLACK_WEBHOOK_PCP || SLACK_WEBHOOK_URL;
  if (c === 'almoxarifado' || c === 'almox') return SLACK_WEBHOOK_ALMOXARIFADO || SLACK_WEBHOOK_URL;
  return SLACK_WEBHOOK_URL; // sem canal informado → geral
}
// Observação: a menção de pessoas (quando a Qualidade escolhe quem marcar em
// cada envio) é montada na PLATAFORMA, dentro do próprio texto (formato Slack
// `<@ID-DO-MEMBRO>`), a partir do cadastro de Contatos do Slack em
// Configurações. Este endpoint só repassa `texto` como veio — nenhuma lógica
// de menção fica fixa aqui no servidor.
app.post('/notificar-slack', async (req, res) => {
  let body;
  try { body = JSON.parse(Buffer.from(req.body).toString('utf8')); } catch (e) { return res.status(400).json({ error: 'JSON invalido.' }); }
  const texto = body && body.texto;
  const canal = body && body.canal;
  if (!texto) return res.status(400).json({ error: 'texto ausente.' });
  const webhook = webhookDoCanal(canal);
  if (!webhook) return res.status(500).json({ error: 'Webhook do Slack nao configurado no .env do servico (canal: ' + (canal || 'geral') + '). Defina SLACK_WEBHOOK_PCP / SLACK_WEBHOOK_ALMOXARIFADO ou SLACK_WEBHOOK_URL.' });
  try {
    const r = await fetch(webhook, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ text: texto }) });
    if (!r.ok) return res.status(502).json({ error: 'Slack respondeu ' + r.status + ': ' + (await r.text()) });
    console.log('[SLACK] alerta enviado (canal: ' + (canal || 'geral') + ')');
    return res.json({ ok: true });
  } catch (err) {
    // "fetch failed" esconde o motivo real — que fica em err.cause. Expõe a causa
    // (ex.: ENOTFOUND/ETIMEDOUT/certificate) para facilitar o diagnóstico de rede.
    const causa = err && err.cause ? (err.cause.code || err.cause.message || String(err.cause)) : '';
    console.error('[ERRO notificar-slack]', err.message, causa ? '| causa: ' + causa : '');
    return res.status(500).json({ error: (err.message || String(err)) + (causa ? ' (' + causa + ')' : '') });
  }
});

// ---- Status do PCP (CSV publicado do Google Sheets) -----------------------
//   Body JSON: { csvUrl, colOP, colOK }
//   Baixa o CSV publicado da planilha do PCP (dupla checagem) e devolve as OPs
//   que estao com "ok" na coluna indicada. Feito no servidor (sem CORS).
app.post('/pcp-status', async (req, res) => {
  let body;
  try { body = JSON.parse(Buffer.from(req.body).toString('utf8')); } catch (e) { return res.status(400).json({ error: 'JSON invalido.' }); }
  const { csvUrl, colOP, colOK } = body || {};
  if (!csvUrl || !/^https?:\/\//i.test(String(csvUrl))) return res.status(400).json({ error: 'csvUrl ausente/invalida (URL do CSV publicado da planilha do PCP).' });
  const nomeColOP = String(colOP || 'OP').trim().toLowerCase();
  const nomeColOK = String(colOK || 'OK?').trim().toLowerCase();
  const OKS = new Set(['ok', 'sim', 's', 'x', '✓', 'true', 'v']);
  const norm = (v) => String(v == null ? '' : v).trim();
  const normHeader = (v) => norm(v).toLowerCase().replace(/\s+/g, ' ');
  try {
    const r = await fetch(String(csvUrl), { redirect: 'follow' });
    if (!r.ok) return res.status(502).json({ error: 'Não foi possível baixar o CSV (HTTP ' + r.status + '). Confirme que a planilha está publicada como CSV.' });
    const rows = parseCSV(await r.text());
    if (!rows.length) return res.json({ ok: true, oks: [], total: 0, aviso: 'CSV vazio.' });
    // acha a linha de cabecalho (a que contem as duas colunas)
    let headerIdx = -1, idxOP = -1, idxOK = -1;
    for (let i = 0; i < Math.min(rows.length, 15); i++) {
      const h = rows[i].map(normHeader);
      const cOP = h.findIndex((c) => c === nomeColOP || c.includes(nomeColOP));
      const cOK = h.findIndex((c) => c === nomeColOK || c.includes(nomeColOK));
      if (cOP >= 0 && cOK >= 0) { headerIdx = i; idxOP = cOP; idxOK = cOK; break; }
    }
    if (headerIdx < 0) return res.status(422).json({ error: `Não achei as colunas "${colOP}" e "${colOK}" no cabeçalho do CSV.` });
    const oks = [];
    for (let i = headerIdx + 1; i < rows.length; i++) {
      const row = rows[i];
      const op = norm(row[idxOP]).replace(/\D/g, '');
      const okVal = norm(row[idxOK]).toLowerCase();
      if (op && OKS.has(okVal)) oks.push(op);
    }
    console.log(`[PCP] ${oks.length} OP(s) com OK (CSV do PCP)`);
    return res.json({ ok: true, oks: [...new Set(oks)], total: oks.length, atualizadoEm: new Date().toISOString() });
  } catch (err) {
    console.error('[ERRO pcp-status]', err.message);
    return res.status(500).json({ error: err.message || String(err) });
  }
});

/* ===========================================================================
   VARREDURA DAS NFs DE VENDA (rastreabilidade serie -> nota fiscal)
   ---------------------------------------------------------------------------
   Antes da plataforma, as pastas eram renomeadas com o numero da NF de venda
   para dar rastreabilidade do numero de serie. Este bloco recupera isso:
   varre a pasta de rede onde ficam as NFs, le o texto de cada DANFE, extrai
   numero da nota / data / cliente / natureza / CFOPs e TODOS os numeros de
   serie de equipamento, e grava em public.nfs_venda.

   O casamento com a analise e pelo numero_serie. Os numeros de serie sao
   reconhecidos pelo padrao do sistema (PREFIXO-AAAAM-N), usando os prefixos
   cadastrados em produtos.codigo_referencia — por isso codigos de acessorio
   (C15789, A6033 etc.) sao ignorados naturalmente.

   Roda de tres formas:
     - POST /varrer-nfs           (botao "Varrer agora" na plataforma)
     - agendamento interno mensal (dia/hora vindos de config_app)
   =========================================================================== */

// CFOPs de venda de producao / mercadoria propria. Remessa, comodato,
// demonstracao, conserto e devolucao ficam de fora de proposito.
// Decisao de 24/08/2026 (Maria Luiza): vale QUALQUER nota de SAIDA, nao apenas
// venda. Demonstracao, comodato, consignacao e emprestimo tambem tiram o
// equipamento da fabrica, e a Qualidade quer o rastro da serie de todo jeito.
// O tipo de movimento (venda x outra saida) fica gravado para nao se perder a
// distincao entre equipamento vendido e apenas emprestado.
//   CFOP iniciado em 5/6/7 = SAIDA · iniciado em 1/2/3 = ENTRADA (nao interessa)
//   5101/6101 venda de producao · 5107/6107 venda a nao contribuinte
//   5109/6109 venda p/ Zona Franca · 5116/6116/5117/6117 venda com entrega futura
//   5102/6102 revenda · 5908/6908 remessa em comodato · 5912/6912 demonstracao
const CFOP_VENDA = new Set(['5101', '6101', '5107', '6107', '5109', '6109', '5116', '6116', '5117', '6117', '5102', '6102', '5103', '6103', '5104', '6104', '5105', '6105', '5106', '6106', '7101', '7102']);
const ehCfopSaida = (c) => /^[567]/.test(String(c || ''));
const CNPJ_CONFIANCE = '05.209.279/0001-31';

async function extrairTextoPdf(buf) {
  const { PDFParse } = require('pdf-parse');
  const p = new PDFParse({ data: new Uint8Array(buf) });
  try {
    const r = await p.getText();
    return String((r && r.text) || '');
  } finally {
    try { await p.destroy(); } catch (e) {}
  }
}

// Extrai os campos da NF a partir do texto do DANFE. Escrito para tolerar
// variacao de layout: procura cada campo dentro de uma JANELA de texto depois
// do rotulo, em vez de exigir que esteja na mesma linha.
function parseNfVenda(texto, prefixos) {
  const t = String(texto || '').replace(/\r/g, '');
  const r = { cfops: [], series: [] };
  const jan = (re, tam) => {
    const m = t.match(re);
    if (!m) return '';
    return t.slice(m.index + m[0].length, m.index + m[0].length + (tam || 200));
  };

  let m = t.match(/N[ÚU]MERO\s*\n?\s*(\d{1,9})/i);
  if (m) r.numero_nf = m[1];
  m = t.match(/S[ÉE]RIE\s*\n?\s*(\d{1,3})\b/i);
  if (m) r.serie_nf = m[1];

  // Chave de acesso: 44 digitos (normalmente em 11 grupos de 4)
  m = t.match(/((?:\d{4}[\s.]?){11})/);
  if (m && m[1].replace(/\D/g, '').length === 44) r.chave_acesso = m[1].replace(/\D/g, '');

  m = jan(/DATA\s+EMISS[ÃA]O/i, 60).match(/(\d{2})\/(\d{2})\/(\d{4})/);
  if (m) r.data_emissao = `${m[3]}-${m[2]}-${m[1]}`;

  const jNat = jan(/NATUREZA DA OPERA[ÇC][ÃA]O/i, 200);
  m = jNat.match(/\n?\s*([A-Za-zÀ-ÿ][^\n]{4,80})/);
  if (m) r.natureza = m[1].replace(/\s*\d{8,}.*$/, '').trim();

  // Destinatario: nome e CNPJ na janela apos "NOME / RAZAO SOCIAL"
  const jDest = jan(/NOME \/ RAZ[ÃA]O SOCIAL/i, 300);
  m = jDest.match(/\n?\s*([A-Z0-9][^\n]{4,120})/);
  if (m) r.cliente_nome = m[1].replace(/(\d{2}\.\d{3}\.\d{3}\/\d{4}-\d{2})/, '').replace(/\d{2}\/\d{2}\/\d{4}/, '').trim();
  for (const mm of jDest.matchAll(/(\d{2}\.\d{3}\.\d{3}\/\d{4}-\d{2})/g)) {
    if (mm[1] !== CNPJ_CONFIANCE) { r.cliente_cnpj = mm[1]; break; }
  }

  m = jan(/VALOR TOTAL DA NOTA/i, 120).match(/R?\$?\s?([\d.]+,\d{2})/);
  if (m) r.valor_total = Number(m[1].replace(/\./g, '').replace(',', '.'));

  // CFOPs das linhas de item (o CFOP vem imediatamente antes da unidade).
  // Captura qualquer familia (1xxx a 7xxx), nao so venda — precisamos saber se
  // a nota e de saida (5/6/7) ou de entrada (1/2/3).
  const cfops = new Set();
  for (const mm of t.matchAll(/\b([123567]\d{3})\s*\n?\s*(?:UN|PC|PÇ|CX|UND|KG|MT|LT|CJ)\b/gi)) cfops.add(mm[1]);
  if (!cfops.size) {
    const jc = jan(/CFOP/i, 400);
    for (const mm of jc.matchAll(/\b([123567]\d{3})\b/g)) cfops.add(mm[1]);
  }
  r.cfops = [...cfops];

  // Numeros de serie no padrao do sistema: PREFIXO-AAAAM-N
  const pref = [...new Set((prefixos || []).filter(Boolean))]
    .sort((a, b) => b.length - a.length)
    .map((p) => String(p).replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
  if (pref.length) {
    // Separadores toleram QUEBRA DE LINHA. Na coluna de descricao do DANFE a
    // serie pode partir no meio, ex.: "CM-CINEMED32F - CM32FC-\n20267-1".
    // Com apenas um caractere de separacao ([-\s]?) essas series eram perdidas
    // — foi o caso da NF 28434, que trazia CM32FC-20267-1 e -2 quebrados.
    const reSerie = new RegExp(`\\b(${pref.join('|')})[-\\s]{0,3}(\\d{5})[-\\s]{0,3}(\\d{1,3})\\b`, 'gi');
    const vistos = new Map();
    for (const mm of t.matchAll(reSerie)) {
      const s = `${mm[1].toUpperCase()}-${mm[2]}-${mm[3]}`;
      if (vistos.has(s)) continue;
      // Janela de texto ANTES da serie: e onde ficam o codigo Sapiens e o modelo
      const janela = t.slice(Math.max(0, mm.index - 400), mm.index + 20);
      const cod = [...janela.matchAll(/\b([A-Z]{3}\d{4})\b/g)].pop();
      const mod = [...janela.matchAll(/\b(CM-[A-Z0-9]+(?:-[A-Z0-9]+)?)\b/g)].pop();
      vistos.set(s, {
        numero_serie: s,
        codigo_produto: cod ? cod[1] : null,
        modelo: mod ? mod[1] : null,
      });
    }
    r.series = [...vistos.values()];
  }

  // Nota de SAIDA? (o equipamento deixou a fabrica, seja por venda ou nao)
  const temSaida = r.cfops.some(ehCfopSaida);
  const temEntrada = r.cfops.some((c) => /^[123]/.test(c));
  const NAT_SAIDA = /venda|remessa|comodato|demonstra|consigna|empr[ée]stimo|transfer[êe]ncia|bonifica|doa[çc][ãa]o|exporta|locac|loca[çc][ãa]o|amostra|brinde|feira|congresso|conserto|industrializa/i;
  r.ehSaida = temSaida || (!temEntrada && NAT_SAIDA.test(r.natureza || ''));

  // Venda propriamente dita (para nao perder a distincao na tela)
  const ehVenda = r.cfops.some((c) => CFOP_VENDA.has(c)) || /\bvenda\b/i.test(r.natureza || '');
  r.tipo_movimento = ehVenda ? 'venda' : 'outra_saida';

  // Mantido por compatibilidade com o resto do codigo
  r.ehVenda = ehVenda;
  return r;
}

function listarPdfsRecursivo(dir, acc, profundidade) {
  acc = acc || [];
  if ((profundidade || 0) > 6) return acc;
  let entradas = [];
  try { entradas = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) { return acc; }
  for (const e of entradas) {
    const full = path.join(dir, e.name);
    if (e.isDirectory()) { listarPdfsRecursivo(full, acc, (profundidade || 0) + 1); continue; }
    if (!/\.pdf$/i.test(e.name)) continue;
    let st = null;
    try { st = fs.statSync(full); } catch (err) { continue; }
    acc.push({ nome: e.name, caminho: full, mtime: st.mtime.toISOString() });
  }
  return acc;
}

// Estado da varredura em andamento. A leitura de milhares de PDFs leva minutos,
// entao ela roda em BACKGROUND: o POST responde na hora e a plataforma acompanha
// o progresso por /varrer-nfs/status. Assim o navegador nao fica preso e um
// restart do servico nao deixa requisicao orfa segurando a porta.
// Quantas linhas acumular antes de gravar no banco. Blocos pequenos deixam a
// varredura resistente a interrupcao e mantem o uso de memoria estavel.
const LOTE_GRAVACAO = 100;

const varreduraStatus = {
  rodando: false, origem: null, iniciado_em: null, concluido_em: null,
  arquivos_na_pasta: 0, arquivos_ja_lidos: 0, a_processar: 0, processados: 0,
  nfs_venda: 0, series_encontradas: 0, erro: null, resumo: null,
};

async function lerConfig(chaves) {
  const admin = supaAdmin();
  const { data, error } = await admin.from('config_app').select('chave, valor').in('chave', chaves);
  if (error) throw error;
  const out = {};
  for (const r of data || []) out[r.chave] = r.valor || '';
  return out;
}

async function gravarConfig(chave, valor) {
  const admin = supaAdmin();
  await admin.from('config_app')
    .upsert({ chave, valor: String(valor == null ? '' : valor), updated_at: new Date().toISOString(), updated_by: 'varredura_nfs' }, { onConflict: 'chave' });
}

// Executa a varredura completa. `opts.incremental` processa somente arquivos
// modificados depois da ultima varredura; `opts.pasta` sobrepoe a pasta da config.
async function varrerNfsVenda(opts) {
  const o = opts || {};
  const admin = supaAdmin();
  const cfg = await lerConfig(['nf_pasta_rede', 'nf_ultima_varredura', 'nf_ano_minimo']);
  const bruto = String(o.pasta || cfg.nf_pasta_rede || '').trim();
  if (!bruto) throw new Error('Pasta das NFs de venda nao configurada (Configuracoes -> NFs de venda).');

  // Aceita VARIAS pastas separadas por ";" e os curingas {ANO} e {ANO-1}, para
  // a configuracao nao precisar ser trocada na virada do ano (a pasta da rede e
  // organizada por ano \ filial \ natureza \ mes).
  // O ano minimo evita varrer anos anteriores ao inicio da plataforma: como
  // todo equipamento analisado foi fabricado a partir de 2026, notas de 2025
  // para tras nao tem serie que casaria com nenhuma analise. Na virada do ano
  // o {ANO-1} volta a valer sozinho (2026 >= 2026), sem mexer na configuracao.
  const anoAtual = new Date().getFullYear();
  const anoMinimo = parseInt(cfg.nf_ano_minimo || '2026', 10) || 2026;
  const pastas = [];
  for (const p of bruto.split(';').map((x) => x.trim()).filter(Boolean)) {
    const temAnoAnterior = /\{ANO-1\}/i.test(p);
    if (temAnoAnterior && anoAtual - 1 < anoMinimo) continue; // pula o ano anterior ao minimo
    if (/\{ANO\}/i.test(p) && !temAnoAnterior && anoAtual < anoMinimo) continue;
    pastas.push(p.replace(/\{ANO-1\}/gi, String(anoAtual - 1)).replace(/\{ANO\}/gi, String(anoAtual)));
  }
  if (!pastas.length) throw new Error('Nenhuma pasta a varrer depois de aplicar o ano minimo (' + anoMinimo + ').');
  const pastasOk = pastas.filter((p) => fs.existsSync(p));
  if (!pastasOk.length) throw new Error('Nenhuma das pastas configuradas foi encontrada / acessivel: ' + pastas.join(' | '));
  const pasta = pastasOk.join(' | ');

  // Prefixos de serie do catalogo (produtos.codigo_referencia)
  const { data: prods, error: errProd } = await admin.from('produtos').select('codigo_referencia').eq('ativo', true);
  if (errProd) throw errProd;
  const prefixos = [...new Set((prods || []).map((p) => String(p.codigo_referencia || '').trim()).filter(Boolean))];
  if (!prefixos.length) throw new Error('Nenhum prefixo de serie no catalogo (produtos.codigo_referencia vazio).');

  const todos = [];
  for (const p of pastasOk) listarPdfsRecursivo(p, todos, 0);

  // ------------------------------------------------------------------------
  // Nao reler o que ja foi lido. O controle e por (caminho + data de
  // modificacao do arquivo), nao por data da varredura: um PDF acrescentado
  // hoje mas com mtime antigo (copiado de outro lugar) tambem e processado, e
  // um arquivo alterado depois de lido volta a ser processado.
  // A tabela nfs_venda_falhas serve tambem como registro dos arquivos que
  // foram lidos e nao geraram vinculo (nota fora de venda, venda so de
  // acessorio) — sem isso eles seriam relidos em toda varredura.
  // `o.forcar` ignora esse controle e reprocessa tudo (usar depois de melhorar
  // o parser, por exemplo).
  // ------------------------------------------------------------------------
  // A chave usa o mtime em MILISSEGUNDOS, nao a string. O Postgres guarda
  // timestamptz e devolve em outro formato que o ISO gerado aqui
  // ("...123Z" x "...123+00:00"), entao comparar texto nunca casava e todo
  // arquivo parecia novo em cada varredura.
  const chaveArquivo = (caminho, mtime) => {
    const t = mtime ? new Date(mtime).getTime() : NaN;
    return `${caminho}|${isNaN(t) ? '' : t}`;
  };

  const jaLidos = new Set();
  if (!o.forcar) {
    for (const tab of ['nfs_venda', 'nfs_venda_falhas']) {
      let de = 0;
      while (true) {
        // ORDER BY explicito: sem ele a paginacao do PostgREST pode repetir ou
        // pular linhas entre as paginas.
        const { data, error } = await admin.from(tab)
          .select('arquivo_path, arquivo_mtime')
          .not('arquivo_path', 'is', null)
          .order('arquivo_path', { ascending: true })
          .range(de, de + 999);
        if (error || !data || !data.length) break;
        for (const r of data) if (r.arquivo_path) jaLidos.add(chaveArquivo(r.arquivo_path, r.arquivo_mtime));
        if (data.length < 1000) break;
        de += 1000;
      }
    }
  }
  // Mais recentes primeiro: se a varredura for interrompida, o que ja foi
  // gravado e a parte que mais importa (notas novas).
  const arquivos = todos
    .filter((a) => !jaLidos.has(chaveArquivo(a.caminho, a.mtime)))
    .sort((x, y) => String(y.mtime).localeCompare(String(x.mtime)));

  const resumo = {
    pasta, iniciado_em: new Date().toISOString(),
    arquivos_na_pasta: todos.length, arquivos_ja_lidos: todos.length - arquivos.length, arquivos_processados: 0,
    nfs_venda: 0, series_encontradas: 0, series_novas: 0,
    ignoradas_nao_venda: 0, sem_texto: 0, sem_serie: 0, erros: 0,
    ano_minimo: anoMinimo, pastas_varridas: pastasOk,
  };

  varreduraStatus.arquivos_na_pasta = todos.length;
  varreduraStatus.arquivos_ja_lidos = resumo.arquivos_ja_lidos;
  varreduraStatus.a_processar = arquivos.length;
  varreduraStatus.processados = 0;

  let linhas = [];
  let falhas = [];
  // Arquivos que geraram vinculo neste bloco: se estavam registrados como
  // "sem vinculo" numa varredura anterior (regra antiga, leitura pior), a
  // linha antiga precisa sair para nao ficar contando como pendencia.
  let pathsComSucesso = [];

  // Descarrega no banco o que estiver acumulado (uma "transacao logica" por
  // bloco). Marca tem_analise consultando as analises pelas series do bloco.
  const gravarLote = async () => {
    if (linhas.length) {
      // Dedup DENTRO do bloco pela chave de conflito. A mesma nota pode estar
      // salva em mais de um arquivo na rede (copia em outra pasta/filial), e o
      // Postgres recusa o upsert quando o mesmo comando tenta atualizar a mesma
      // linha duas vezes ("ON CONFLICT DO UPDATE command cannot affect row a
      // second time"). Fica a ultima ocorrencia.
      const porChave = new Map();
      for (const l of linhas) porChave.set(`${l.numero_nf}|${l.serie_nf}|${l.numero_serie}`, l);
      linhas = [...porChave.values()];

      const series = [...new Set(linhas.map((l) => l.numero_serie))];
      const comAnalise = new Set();
      for (let i = 0; i < series.length; i += 200) {
        const { data } = await admin.from('analises').select('numero_serie').in('numero_serie', series.slice(i, i + 200));
        for (const a of data || []) if (a.numero_serie) comAnalise.add(a.numero_serie);
      }
      for (const l of linhas) l.tem_analise = comAnalise.has(l.numero_serie);
      for (let i = 0; i < linhas.length; i += 200) {
        const { error } = await admin.from('nfs_venda')
          .upsert(linhas.slice(i, i + 200), { onConflict: 'numero_nf,serie_nf,numero_serie', ignoreDuplicates: false });
        if (error) throw error;
      }
      resumo.series_novas += linhas.length;
      linhas = [];
    }
    if (falhas.length) {
      // Mesma precaucao: uma linha por arquivo_path dentro do bloco.
      const porPath = new Map();
      for (const f of falhas) porPath.set(f.arquivo_path, f);
      falhas = [...porPath.values()];
      for (let i = 0; i < falhas.length; i += 200) {
        const { error } = await admin.from('nfs_venda_falhas').upsert(falhas.slice(i, i + 200), { onConflict: 'arquivo_path' });
        if (error) throw error;
      }
      falhas = [];
    }
    if (pathsComSucesso.length) {
      for (let i = 0; i < pathsComSucesso.length; i += 100) {
        await admin.from('nfs_venda_falhas').delete().in('arquivo_path', pathsComSucesso.slice(i, i + 100));
      }
      pathsComSucesso = [];
    }
    // Resumo parcial para a tela mostrar progresso mesmo entre recarregamentos
    try { await gravarConfig('nf_ultimo_resumo', JSON.stringify({ ...resumo, parcial: true })); } catch (e) {}
  };

  for (const arq of arquivos) {
    resumo.arquivos_processados++;
    varreduraStatus.processados = resumo.arquivos_processados;
    varreduraStatus.nfs_venda = resumo.nfs_venda;
    varreduraStatus.series_encontradas = resumo.series_encontradas;
    let texto = '';
    try {
      texto = await extrairTextoPdf(fs.readFileSync(arq.caminho));
    } catch (err) {
      resumo.erros++;
      falhas.push({ arquivo_nome: arq.nome, arquivo_path: arq.caminho, arquivo_mtime: arq.mtime, motivo: 'erro_leitura', detalhe: String(err.message || err).slice(0, 500) });
      continue;
    }
    if (texto.replace(/\s+/g, '').length < 200) {
      resumo.sem_texto++;
      falhas.push({ arquivo_nome: arq.nome, arquivo_path: arq.caminho, arquivo_mtime: arq.mtime, motivo: 'sem_texto', detalhe: 'PDF sem texto extraivel (provavelmente escaneado) — precisa de conferencia manual.' });
      continue;
    }
    const nf = parseNfVenda(texto, prefixos);
    // Notas de ENTRADA (devolucao recebida, retorno de demonstracao, compra) e
    // saidas sem numero de serie de equipamento (acessorio/peca) sao situacoes
    // NORMAIS. Ficam registradas apenas para nao serem relidas na proxima
    // varredura; a tela nao as mostra como pendencia.
    if (!nf.ehSaida) {
      resumo.ignoradas_nao_venda++;
      falhas.push({ arquivo_nome: arq.nome, arquivo_path: arq.caminho, arquivo_mtime: arq.mtime, motivo: 'nao_saida', detalhe: (nf.natureza || 'natureza nao identificada') + ' | CFOPs: ' + (nf.cfops.join(', ') || '—') });
      continue;
    }
    if (!nf.numero_nf || !nf.series.length) {
      resumo.sem_serie++;
      falhas.push({ arquivo_nome: arq.nome, arquivo_path: arq.caminho, arquivo_mtime: arq.mtime, motivo: 'sem_serie', detalhe: 'NF ' + (nf.numero_nf || '?') + ' — saida sem numero de serie de equipamento (acessorio/peca).' });
      continue;
    }
    resumo.nfs_venda++;
    if (nf.tipo_movimento !== 'venda') resumo.outras_saidas = (resumo.outras_saidas || 0) + 1;
    pathsComSucesso.push(arq.caminho);
    for (const s of nf.series) {
      resumo.series_encontradas++;
      linhas.push({
        // serie_nf entra como '' (nunca null) porque faz parte da chave unica
        numero_nf: nf.numero_nf, serie_nf: nf.serie_nf || '', chave_acesso: nf.chave_acesso || null,
        data_emissao: nf.data_emissao || null, natureza: nf.natureza || null, cfops: nf.cfops.join(',') || null,
        cliente_nome: nf.cliente_nome || null, cliente_cnpj: nf.cliente_cnpj || null,
        valor_total: nf.valor_total != null ? nf.valor_total : null,
        numero_serie: s.numero_serie, codigo_produto: s.codigo_produto, modelo: s.modelo,
        tipo_movimento: nf.tipo_movimento || 'venda',
        arquivo_nome: arq.nome, arquivo_path: arq.caminho, arquivo_mtime: arq.mtime,
        detectada_por: o.origem || 'varredura_automatica',
      });
    }
    // Grava em blocos: assim uma interrupcao (restart do servico, queda de
    // rede) NAO perde o que ja foi lido, e a proxima varredura continua de onde
    // parou por causa do controle de arquivos ja lidos. Antes o sistema so
    // gravava no final — foi o que fez a primeira varredura perder tudo.
    if (linhas.length >= LOTE_GRAVACAO || falhas.length >= LOTE_GRAVACAO) await gravarLote();
  }
  await gravarLote(); // resto do ultimo bloco

  // OPs analisadas que continuam sem NF de venda vinculada
  try {
    const { data: an } = await admin.from('analises').select('numero_serie');
    const { data: nv } = await admin.from('nfs_venda').select('numero_serie');
    const comNf = new Set((nv || []).map((x) => x.numero_serie));
    const semNf = new Set((an || []).map((x) => x.numero_serie).filter((s) => s && !comNf.has(s)));
    resumo.analises_sem_nf = semNf.size;
  } catch (e) { /* informativo */ }

  resumo.concluido_em = new Date().toISOString();
  await gravarConfig('nf_ultima_varredura', resumo.concluido_em);
  await gravarConfig('nf_ultimo_resumo', JSON.stringify(resumo));
  console.log('[NFs] varredura concluida:', JSON.stringify(resumo));
  return resumo;
}

// Dispara a varredura em BACKGROUND e responde na hora.
//   Body JSON (opcional): { pasta, forcar, origem }
function dispararVarredura(opts) {
  const o = opts || {};
  if (varreduraStatus.rodando) return false;
  varreduraStatus.rodando = true;
  varreduraStatus.origem = o.origem || 'manual';
  varreduraStatus.iniciado_em = new Date().toISOString();
  varreduraStatus.concluido_em = null;
  varreduraStatus.erro = null;
  varreduraStatus.resumo = null;
  varreduraStatus.arquivos_na_pasta = 0;
  varreduraStatus.arquivos_ja_lidos = 0;
  varreduraStatus.a_processar = 0;
  varreduraStatus.processados = 0;
  varreduraStatus.nfs_venda = 0;
  varreduraStatus.series_encontradas = 0;
  varrerNfsVenda(o)
    .then((resumo) => { varreduraStatus.resumo = resumo; })
    .catch((err) => {
      varreduraStatus.erro = err && err.message ? err.message : String(err);
      console.error('[ERRO varrer-nfs]', varreduraStatus.erro);
    })
    .finally(() => {
      varreduraStatus.rodando = false;
      varreduraStatus.concluido_em = new Date().toISOString();
    });
  return true;
}

app.post('/varrer-nfs', async (req, res) => {
  let body = {};
  try { if (req.body && req.body.length) body = JSON.parse(Buffer.from(req.body).toString('utf8')); } catch (e) {}
  if (varreduraStatus.rodando) {
    return res.status(409).json({ error: 'Ja existe uma varredura em andamento.', status: varreduraStatus });
  }
  dispararVarredura({ pasta: body.pasta, forcar: body.forcar === true, origem: body.origem || 'manual' });
  return res.json({ ok: true, iniciada: true, status: varreduraStatus });
});

// Progresso da varredura (a plataforma consulta de poucos em poucos segundos).
app.get('/varrer-nfs/status', (req, res) => {
  res.json({ ok: true, status: varreduraStatus });
});

// ---- Agendamento mensal (sem dependencia externa) -------------------------
//   Confere de hora em hora se chegou o dia/hora configurados (config_app:
//   nf_dia_mes e nf_hora, default dia 1o as 06h) e se ainda nao rodou hoje.
//   Roda dentro do proprio servico, no servidor — nao depende de ninguem
//   estar com a plataforma aberta.
let _ultimaVarreduraDia = '';
async function checarAgendamentoNfs() {
  try {
    const cfg = await lerConfig(['nf_pasta_rede', 'nf_dia_mes', 'nf_hora', 'nf_ultima_varredura']);
    if (!String(cfg.nf_pasta_rede || '').trim()) return;
    const diaAlvo = parseInt(cfg.nf_dia_mes || '1', 10) || 1;
    const horaAlvo = parseInt(cfg.nf_hora || '6', 10) || 6;
    const agora = new Date();
    if (agora.getDate() !== diaAlvo || agora.getHours() < horaAlvo) return;
    const hoje = agora.toISOString().slice(0, 10);
    if (_ultimaVarreduraDia === hoje) return;
    if (cfg.nf_ultima_varredura && String(cfg.nf_ultima_varredura).slice(0, 10) === hoje) { _ultimaVarreduraDia = hoje; return; }
    _ultimaVarreduraDia = hoje;
    console.log('[NFs] varredura mensal automatica iniciando...');
    dispararVarredura({ origem: 'varredura_mensal' });
  } catch (err) {
    console.error('[ERRO agendamento NFs]', err.message);
  }
}
setInterval(() => { checarAgendamentoNfs(); }, 60 * 60 * 1000);
setTimeout(() => { checarAgendamentoNfs(); }, 60 * 1000);

// ============================================================================
// RELATÓRIOS DE QUALIDADE MENSAIS AUTOMÁTICOS (10/10/2026)
// O cálculo e o layout NÃO são duplicados aqui: o serviço lê o bloco
// "@@MOTOR_RELATORIO" do próprio plataforma.html (o mesmo código que gera o
// relatório no navegador) e executa. Assim o PDF automático é idêntico ao
// gerado pela tela. Para cada modelo marcado como "automático", gera o PDF do
// mês anterior e grava em <pasta>/<ano>/.
// ============================================================================
function carregarMotorRelatorio() {
  if (!PLATAFORMA_HTML) throw new Error('Defina PLATAFORMA_HTML no .env (caminho do plataforma.html).');
  const src = fs.readFileSync(PLATAFORMA_HTML, 'utf8');
  const ini = src.indexOf('@@MOTOR_RELATORIO_INICIO');
  const fim = src.indexOf('/* @@MOTOR_RELATORIO_FIM');
  if (ini < 0 || fim < 0) throw new Error('Bloco do motor de relatório não encontrado no plataforma.html (atualize com git pull).');
  const codigo = src.slice(src.indexOf('*/', ini) + 2, fim);
  // eslint-disable-next-line no-new-func
  return new Function(codigo + '\nreturn { calcularBaseQualidade, gerarRelatorioQualidade, mesclarModelosRelatorio };')();
}

async function buscarTodasLinhas(tabela, colunas, ordemCampo) {
  const admin = supaAdmin();
  const PAG = 1000; let de = 0; const out = [];
  for (;;) {
    let q = admin.from(tabela).select(colunas);
    if (ordemCampo) q = q.order(ordemCampo, { ascending: true });
    const { data, error } = await q.range(de, de + PAG - 1);
    if (error) throw error;
    out.push(...(data || []));
    if (!data || data.length < PAG) break;
    de += PAG;
  }
  return out;
}

const mesAnteriorYM = (d = new Date()) => { const x = new Date(d.getFullYear(), d.getMonth() - 1, 1); return `${x.getFullYear()}-${String(x.getMonth() + 1).padStart(2, '0')}`; };
const relatorioStatus = { rodando: false, iniciado_em: null, resultado: null, erro: null };

async function gerarRelatoriosMensais({ mes, origem }) {
  const motor = carregarMotorRelatorio();
  const cfg = await lerConfig(['relatorio_auto_pasta', 'relatorio_modelos', 'meta_aprovacao']);
  const pasta = String(cfg.relatorio_auto_pasta || '').trim();
  if (!pasta) throw new Error('Pasta dos relatórios automáticos não configurada (Configurações → Relatórios automáticos).');
  let salvos = []; try { salvos = JSON.parse(cfg.relatorio_modelos || '[]'); } catch (e) { salvos = []; }
  const modelos = motor.mesclarModelosRelatorio(salvos).filter((m) => m.automatico);
  if (!modelos.length) throw new Error('Nenhum modelo marcado como "gerar automaticamente".');
  const alvo = /^\d{4}-\d{2}$/.test(String(mes || '')) ? mes : mesAnteriorYM();
  const admin = supaAdmin();
  const analises = await buscarTodasLinhas('analises', 'id, status, modelo, numero_op, numero_serie, created_at, parecer_completo, analise_origem_id, origem_analise, doc_substituido, motivo_reanalise, tipo_reanalise', 'created_at');
  const { data: produtos } = await admin.from('produtos').select('id, modelo, codigo_sapiens, equipamento');
  let temposAtivos = [];
  try { const { data } = await admin.from('tempos_estagio').select('equipamento, estagio_numero, ativo').eq('ativo', true); temposAtivos = data || []; } catch (e) { /* tabela opcional */ }
  const base = motor.calcularBaseQualidade({ analises, produtos: produtos || [], temposAtivos });
  const dir = path.join(pasta, alvo.slice(0, 4));
  fs.mkdirSync(dir, { recursive: true });
  const meta = parseFloat(String(cfg.meta_aprovacao || '').replace(',', '.')) || 90;
  const arquivos = [];
  for (const m of modelos) {
    const r = motor.gerarRelatorioQualidade(base, { ...m, de: alvo, ate: alvo, titulo: m.nome }, { meta, podeVerOperador: true, autor: 'Geração automática mensal', agora: new Date() });
    const pdf = await htmlParaPdf(r.html, { landscape: r.paisagem });
    const arq = path.join(dir, `${r.nomeArq}.pdf`);
    fs.writeFileSync(arq, pdf);
    arquivos.push(arq);
    console.log(`[RELATORIO] ${m.nome} -> ${arq}`);
  }
  const resultado = { mes: alvo, em: new Date().toISOString(), origem: origem || 'manual', arquivos };
  await gravarConfig('relatorio_auto_ultimo', JSON.stringify(resultado));
  return resultado;
}

async function dispararRelatorios(opts) {
  if (relatorioStatus.rodando) return false;
  Object.assign(relatorioStatus, { rodando: true, iniciado_em: new Date().toISOString(), resultado: null, erro: null });
  try { relatorioStatus.resultado = await gerarRelatoriosMensais(opts || {}); }
  catch (err) { relatorioStatus.erro = err.message || String(err); console.error('[ERRO relatorios mensais]', relatorioStatus.erro); }
  finally { relatorioStatus.rodando = false; }
  return true;
}

app.post('/relatorios-mensais/gerar', async (req, res) => {
  let body = {};
  try { body = JSON.parse(Buffer.isBuffer(req.body) ? req.body.toString('utf8') || '{}' : JSON.stringify(req.body || {})); } catch (e) { body = {}; }
  if (relatorioStatus.rodando) return res.status(409).json({ error: 'Já existe uma geração em andamento.', status: relatorioStatus });
  await dispararRelatorios({ mes: body.mes, origem: 'manual' });
  if (relatorioStatus.erro) return res.status(500).json({ error: relatorioStatus.erro });
  return res.json({ ok: true, ...relatorioStatus.resultado });
});
app.get('/relatorios-mensais/status', (req, res) => res.json(relatorioStatus));

// Agenda: dia/hora configuráveis (padrão dia 1, 07h — depois da varredura de NFs).
async function checarAgendamentoRelatorios() {
  try {
    const cfg = await lerConfig(['relatorio_auto_pasta', 'relatorio_auto_dia', 'relatorio_auto_hora', 'relatorio_auto_ultimo']);
    if (!String(cfg.relatorio_auto_pasta || '').trim()) return;
    const dia = parseInt(cfg.relatorio_auto_dia || '1', 10) || 1;
    const hora = parseInt(cfg.relatorio_auto_hora || '7', 10);
    const agora = new Date();
    if (agora.getDate() < dia || agora.getHours() < (isNaN(hora) ? 7 : hora)) return;
    const alvo = mesAnteriorYM(agora);
    let ultimo = null; try { ultimo = JSON.parse(cfg.relatorio_auto_ultimo || 'null'); } catch (e) { ultimo = null; }
    if (ultimo && ultimo.mes === alvo) return; // já gerado para este mês
    console.log(`[RELATORIO] geração automática do mês ${alvo} iniciando...`);
    await dispararRelatorios({ mes: alvo, origem: 'automatica' });
  } catch (err) {
    console.error('[ERRO agendamento relatorios]', err.message);
  }
}
setInterval(() => { checarAgendamentoRelatorios(); }, 60 * 60 * 1000);
setTimeout(() => { checarAgendamentoRelatorios(); }, 2 * 60 * 1000);

// ---- Ghostscript: regenera o PDF SEM restricoes (assinavel no Adobe) ------
async function otimizarPdf(inputBytes) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cpdf-'));
  const inPath = path.join(dir, 'in.pdf');
  const outPath = path.join(dir, 'out.pdf');
  try {
    fs.writeFileSync(inPath, inputBytes);
    await execFileP(GHOSTSCRIPT_BIN, [
      '-sDEVICE=pdfwrite',
      '-dPDFSETTINGS=/prepress',
      '-dCompatibilityLevel=1.6',
      '-dNOPAUSE', '-dBATCH', '-dQUIET',
      '-dPreserveAnnots=true',
      `-sOutputFile=${outPath}`,
      inPath,
    ], { maxBuffer: 1024 * 1024 * 64, windowsHide: true });
    return fs.readFileSync(outPath);
  } finally {
    try { fs.rmSync(dir, { recursive: true, force: true }); } catch (e) {}
  }
}

// ---- Chromium headless: HTML -> PDF ---------------------------------------
let _browser = null;
async function getBrowser() {
  if (_browser && _browser.isConnected()) return _browser;
  const puppeteer = require('puppeteer');
  _browser = await puppeteer.launch({ headless: 'new', args: ['--no-sandbox', '--disable-setuid-sandbox'] });
  return _browser;
}
async function htmlParaPdf(html, opts = {}) {
  const browser = await getBrowser();
  const page = await browser.newPage();
  try {
    await page.setContent(html, { waitUntil: 'networkidle0' });
    return await page.pdf({ format: 'A4', landscape: !!opts.landscape, printBackground: true, margin: { top: '24px', bottom: '24px', left: '18px', right: '18px' } });
  } finally {
    await page.close();
  }
}

app.listen(PORT, () => {
  console.log(`Conversor PDF local ouvindo em http://0.0.0.0:${PORT}`);
  console.log(`  Endpoints: POST /converter-pdf | POST /salvar-pacote | POST /convidar-usuario | POST /notificar-slack | POST /pcp-status | POST /varrer-nfs | GET /varrer-nfs/status | POST /relatorios-mensais/gerar | GET /relatorios-mensais/status`);
});
