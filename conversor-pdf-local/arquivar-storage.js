// ============================================================================
// Arquivar o Storage do Supabase no servidor e liberar espaço (plano gratuito: 1 GB)
//
// Roda NO SERVIDOR, na pasta conversor-pdf-local (usa o mesmo .env do serviço:
// SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY). Nada é apagado do Supabase sem
// antes existir cópia idêntica (mesmo tamanho) na pasta de arquivo do servidor.
//
// Passo 1 — copiar tudo para o servidor (não apaga nada; pode repetir, pula o que já copiou):
//     node arquivar-storage.js --arquivar --pasta "D:\ArquivoPlataforma\pacotes-analise"
//
// Passo 2 — simular a liberação (mostra o que seria apagado; não apaga):
//     node arquivar-storage.js --liberar --pasta "D:\ArquivoPlataforma\pacotes-analise"
//
// Passo 3 — liberar de verdade:
//     node arquivar-storage.js --liberar --executar --pasta "D:\ArquivoPlataforma\pacotes-analise"
//
// O que a liberação remove do Supabase (sempre já copiado para o servidor):
//   • arquivos de análises que não existem mais (órfãos);
//   • documentos originais e ZIPs de análises SUBSTITUÍDAS por reanálise;
//   • ZIPs das análises vigentes (o pacote é regenerado pelo botão "Baixar pacote",
//     pois os documentos originais continuam no Supabase).
// Os documentos ORIGINAIS das análises vigentes ficam no Supabase (a reanálise usa).
// ============================================================================
try { require('dotenv').config(); } catch (e) { /* dotenv opcional */ }
const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

const BUCKET = 'pacotes-analise';
const args = process.argv.slice(2);
const tem = (f) => args.includes(f);
const valor = (f) => { const i = args.indexOf(f); return i >= 0 ? args[i + 1] : null; };

const MODO = tem('--arquivar') ? 'arquivar' : tem('--liberar') ? 'liberar' : null;
const EXECUTAR = tem('--executar');
const PASTA = valor('--pasta') || process.env.ARQUIVO_STORAGE_PASTA || '';

if (!MODO) { console.error('Use --arquivar ou --liberar (veja o cabeçalho do arquivo).'); process.exit(1); }
if (!PASTA) { console.error('Informe a pasta de arquivo: --pasta "D:\\ArquivoPlataforma\\pacotes-analise"'); process.exit(1); }
if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) { console.error('SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY não encontrados no .env.'); process.exit(1); }

const admin = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, { auth: { autoRefreshToken: false, persistSession: false } });
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const mb = (b) => (b / 1024 / 1024).toFixed(1) + ' MB';

// Lista recursivamente todos os arquivos do bucket: [{ caminho, tamanho }]
async function listarPasta(prefixo, out) {
  let offset = 0;
  for (;;) {
    const { data, error } = await admin.storage.from(BUCKET).list(prefixo, { limit: 1000, offset, sortBy: { column: 'name', order: 'asc' } });
    if (error) throw error;
    for (const it of data || []) {
      const caminho = prefixo ? `${prefixo}/${it.name}` : it.name;
      if (it.id == null) await listarPasta(caminho, out);            // "pasta"
      else out.push({ caminho, tamanho: Number(it.metadata?.size ?? 0) });
    }
    if (!data || data.length < 1000) break;
    offset += 1000;
  }
}

async function buscarTodas(tabela, colunas) {
  const out = []; let de = 0;
  for (;;) {
    const { data, error } = await admin.from(tabela).select(colunas).order('id').range(de, de + 999);
    if (error) throw error;
    out.push(...(data || []));
    if (!data || data.length < 1000) break;
    de += 1000;
  }
  return out;
}

const localDe = (caminho) => path.join(PASTA, ...caminho.split('/'));
const copiado = (a) => { try { return fs.statSync(localDe(a.caminho)).size === a.tamanho && a.tamanho > 0; } catch (e) { return false; } };

async function emLotes(lista, n, fn) {
  let i = 0;
  const trabalhadores = Array.from({ length: n }, async () => { while (i < lista.length) { const k = i++; await fn(lista[k], k); } });
  await Promise.all(trabalhadores);
}

(async () => {
  console.log('Listando arquivos do bucket (pode levar alguns minutos)...');
  const arquivos = []; await listarPasta('', arquivos);
  console.log(`${arquivos.length} arquivos, ${mb(arquivos.reduce((s, a) => s + a.tamanho, 0))}.`);

  if (MODO === 'arquivar') {
    fs.mkdirSync(PASTA, { recursive: true });
    const pend = arquivos.filter((a) => !copiado(a));
    console.log(`${arquivos.length - pend.length} já copiados; ${pend.length} a copiar.`);
    let feitos = 0, falhas = 0;
    await emLotes(pend, 4, async (a) => {
      try {
        const { data, error } = await admin.storage.from(BUCKET).download(a.caminho);
        if (error) throw error;
        const buf = Buffer.from(await data.arrayBuffer());
        fs.mkdirSync(path.dirname(localDe(a.caminho)), { recursive: true });
        fs.writeFileSync(localDe(a.caminho), buf);
        if (a.tamanho && buf.length !== a.tamanho) throw new Error(`tamanho diferente (${buf.length} × ${a.tamanho})`);
      } catch (e) { falhas++; console.error('FALHOU', a.caminho, e.message || e); }
      if (++feitos % 200 === 0) console.log(`  ${feitos}/${pend.length}`);
    });
    const faltam = arquivos.filter((a) => !copiado(a)).length;
    console.log(faltam === 0 ? 'Tudo copiado e conferido. Pode seguir para --liberar.' : `Atenção: ${faltam} arquivo(s) sem cópia conferida (${falhas} falha(s)). Rode de novo.`);
    return;
  }

  // ---- liberar ----
  const analises = await buscarTodas('analises', 'id, analise_origem_id, pacote_zip_path');
  const existe = new Set(analises.map((a) => a.id));
  const substituidas = new Set(analises.filter((a) => a.analise_origem_id).map((a) => a.analise_origem_id));

  const grupos = { orfas: [], substituidas: [], zipVigente: [] };
  for (const a of arquivos) {
    const id = a.caminho.split('/')[0];
    if (!UUID.test(id)) continue;                                       // fora do padrão: nunca mexe
    const ehOriginal = a.caminho.includes('/originais/');
    if (!existe.has(id)) grupos.orfas.push(a);
    else if (substituidas.has(id)) grupos.substituidas.push(a);
    else if (!ehOriginal && a.caminho.toLowerCase().endsWith('.zip')) grupos.zipVigente.push(a);
  }
  const semCopia = [];
  for (const [nome, lista] of Object.entries(grupos)) {
    const ok = lista.filter(copiado); const sem = lista.filter((a) => !copiado(a));
    semCopia.push(...sem);
    console.log(`${nome}: ${lista.length} arquivos (${mb(lista.reduce((s, a) => s + a.tamanho, 0))}) — ${ok.length} com cópia conferida, ${sem.length} SEM cópia (não serão apagados).`);
    grupos[nome] = ok;
  }
  const total = Object.values(grupos).flat();
  console.log(`\nTotal a liberar: ${total.length} arquivos, ${mb(total.reduce((s, a) => s + a.tamanho, 0))}.`);
  if (semCopia.length) console.log('Rode --arquivar de novo para copiar os que faltam.');
  if (!EXECUTAR) { console.log('\nSIMULAÇÃO — nada foi apagado. Para apagar: acrescente --executar.'); return; }

  const caminhos = total.map((a) => a.caminho);
  for (let i = 0; i < caminhos.length; i += 100) {
    const { error } = await admin.storage.from(BUCKET).remove(caminhos.slice(i, i + 100));
    if (error) throw error;
    console.log(`  apagados ${Math.min(i + 100, caminhos.length)}/${caminhos.length}`);
  }
  // Os ZIPs apagados deixam de existir: limpa a referência para o Histórico regenerar
  // o pacote ("Baixar pacote") em vez de tentar baixar um arquivo que não existe mais.
  const zipsApagados = new Set(caminhos.filter((c) => c.toLowerCase().endsWith('.zip') && !c.includes('/originais/')));
  const ids = analises.filter((a) => a.pacote_zip_path && zipsApagados.has(a.pacote_zip_path)).map((a) => a.id);
  for (let i = 0; i < ids.length; i += 100) {
    const { error } = await admin.from('analises').update({ pacote_zip_path: null, pacote_zip_filename: null, pacote_zip_size: null, pacote_zip_uploaded_at: null }).in('id', ids.slice(i, i + 100));
    if (error) throw error;
  }
  console.log(`Concluído. ${ids.length} análise(s) com pacote ZIP a regenerar sob demanda.`);
})().catch((e) => { console.error('ERRO:', e.message || e); process.exit(1); });
