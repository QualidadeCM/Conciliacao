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
const libre = require('libreoffice-convert');
const AdmZip = require('adm-zip');
const { createClient } = require('@supabase/supabase-js');

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
  res.json({ ok: true, servico: 'conversor-pdf-local', versao: '1.3.0' });
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
      pdf = await htmlParaPdf(input.toString('utf8'));
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
//   Body JSON: { texto }  → posta a mensagem no canal configurado.
//   Defina SLACK_WEBHOOK_URL no .env (https://hooks.slack.com/services/...).
const SLACK_WEBHOOK_URL = process.env.SLACK_WEBHOOK_URL || '';
app.post('/notificar-slack', async (req, res) => {
  let body;
  try { body = JSON.parse(Buffer.from(req.body).toString('utf8')); } catch (e) { return res.status(400).json({ error: 'JSON invalido.' }); }
  const texto = body && body.texto;
  if (!texto) return res.status(400).json({ error: 'texto ausente.' });
  if (!SLACK_WEBHOOK_URL) return res.status(500).json({ error: 'SLACK_WEBHOOK_URL nao configurado no .env do servico.' });
  try {
    const r = await fetch(SLACK_WEBHOOK_URL, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ text: texto }) });
    if (!r.ok) return res.status(502).json({ error: 'Slack respondeu ' + r.status + ': ' + (await r.text()) });
    console.log('[SLACK] alerta enviado');
    return res.json({ ok: true });
  } catch (err) {
    console.error('[ERRO notificar-slack]', err.message);
    return res.status(500).json({ error: err.message || String(err) });
  }
});

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
    ], { maxBuffer: 1024 * 1024 * 64 });
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
async function htmlParaPdf(html) {
  const browser = await getBrowser();
  const page = await browser.newPage();
  try {
    await page.setContent(html, { waitUntil: 'networkidle0' });
    return await page.pdf({ format: 'A4', printBackground: true, margin: { top: '24px', bottom: '24px', left: '18px', right: '18px' } });
  } finally {
    await page.close();
  }
}

app.listen(PORT, () => {
  console.log(`Conversor PDF local ouvindo em http://0.0.0.0:${PORT}`);
  console.log(`  Ghostscript: ${GHOSTSCRIPT_BIN}`);
  console.log(`  Endpoints: POST /converter-pdf | POST /salvar-pacote | GET /health`);
});
