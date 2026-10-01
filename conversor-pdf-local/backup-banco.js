/* ============================================================================
   backup-banco.js — Backup completo das tabelas do Supabase para uma pasta.
   Criado em 28/08/2026 (Maria Luiza), para o backup antes das férias.

   Usa a MESMA chave service_role que o serviço já tem no .env, então não
   precisa instalar nada novo: as dependências (@supabase/supabase-js, dotenv,
   adm-zip) já estão na pasta conversor-pdf-local.

   Uso:
     node backup-banco.js "\\\\192.168.20.252\\qualidade\\...\\Backups Plataforma"

   Sem argumento, grava em .\backups dentro da própria pasta do serviço.

   O que gera na pasta de destino:
     backup-conciliacao-AAAA-MM-DD_HHMM.zip
       ├── _MANIFESTO.json      (data, contagem de linhas por tabela, erros)
       ├── analises.json
       ├── produtos.json
       └── ... uma linha por tabela

   Cada .json é um array com TODAS as linhas da tabela (paginado de 1000 em
   1000 — o PostgREST corta em 1000 por requisição).

   NÃO inclui os arquivos do Storage (bucket pacotes-analise), que são os ZIPs
   dos pacotes e pesam muito. Esses continuam no Supabase.
   ============================================================================ */

const fs = require('fs');
const path = require('path');
const os = require('os');

// .env: tenta a pasta atual e, se não achar, o caminho antigo do serviço.
require('dotenv').config();
if (!process.env.SUPABASE_URL) {
  for (const alt of ['C:/conversor-pdf-local/.env', 'C:/conciliacao/conversor-pdf-local/.env']) {
    if (fs.existsSync(alt)) { require('dotenv').config({ path: alt }); break; }
  }
}

const { createClient } = require('@supabase/supabase-js');
const AdmZip = require('adm-zip');

const URL = process.env.SUPABASE_URL;
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!URL || !KEY) {
  console.error('ERRO: SUPABASE_URL e/ou SUPABASE_SERVICE_ROLE_KEY não encontrados.');
  console.error('Rode este script dentro da pasta conversor-pdf-local (onde está o .env),');
  console.error('ou defina as variáveis antes de rodar.');
  process.exit(1);
}

// Todas as tabelas da plataforma (levantadas do código em 28/08/2026).
const TABELAS = [
  'analises',
  'apontamentos',
  'produtos',
  'fichas_mestres',
  'fichas_mestres_versoes',
  'acessorios_aplicaveis',
  'operadores',
  'operacoes_livres',
  'tempos_estagio',
  'nfs_venda',
  'nfs_venda_falhas',
  'envios_pacote',
  'melhorias_regulatorias',
  'worklist_ops',
  'solicitacoes',
  'perfis',
  'convites',
  'config_app',
  'logs_atividade',
];

const supabase = createClient(URL, KEY, { auth: { persistSession: false } });

async function baixarTabela(tabela) {
  const PAG = 1000;
  let de = 0;
  const out = [];
  for (;;) {
    const { data, error } = await supabase.from(tabela).select('*').range(de, de + PAG - 1);
    if (error) throw error;
    out.push(...(data || []));
    if (!data || data.length < PAG) break;
    de += PAG;
    process.stdout.write(`\r  ${tabela}: ${out.length} linhas…`);
  }
  return out;
}

(async () => {
  const destino = process.argv[2] || path.join(__dirname, 'backups');
  const agora = new Date();
  const p2 = (n) => String(n).padStart(2, '0');
  const stamp = `${agora.getFullYear()}-${p2(agora.getMonth() + 1)}-${p2(agora.getDate())}_${p2(agora.getHours())}${p2(agora.getMinutes())}`;
  const nomeZip = `backup-conciliacao-${stamp}.zip`;

  // Trabalha primeiro numa pasta temporária local (rede pode ser lenta/instável).
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'backup-conc-'));

  console.log(`Backup da base: ${URL}`);
  console.log(`Destino: ${destino}`);
  console.log('');

  const manifesto = { gerado_em: agora.toISOString(), supabase_url: URL, tabelas: {}, erros: {} };

  for (const t of TABELAS) {
    try {
      const linhas = await baixarTabela(t);
      fs.writeFileSync(path.join(tmp, `${t}.json`), JSON.stringify(linhas, null, 1), 'utf8');
      manifesto.tabelas[t] = linhas.length;
      console.log(`\r  OK  ${t}: ${linhas.length} linha(s)`.padEnd(60));
    } catch (e) {
      const msg = e?.message || String(e);
      manifesto.erros[t] = msg;
      console.log(`\r  --  ${t}: ${msg}`.padEnd(60));
    }
  }

  fs.writeFileSync(path.join(tmp, '_MANIFESTO.json'), JSON.stringify(manifesto, null, 2), 'utf8');

  // Compacta tudo num único arquivo.
  const zip = new AdmZip();
  for (const f of fs.readdirSync(tmp)) zip.addLocalFile(path.join(tmp, f));

  try {
    fs.mkdirSync(destino, { recursive: true });
  } catch (e) {
    console.error(`\nERRO: não foi possível criar/abrir a pasta de destino: ${destino}`);
    console.error(e?.message || e);
    process.exit(1);
  }

  const caminhoFinal = path.join(destino, nomeZip);
  try {
    zip.writeZip(caminhoFinal);
  } catch (e) {
    // Se a rede falhar, salva local para não perder o trabalho.
    const fallback = path.join(__dirname, nomeZip);
    zip.writeZip(fallback);
    console.error(`\nAVISO: falhou gravar na rede (${e?.message || e}).`);
    console.error(`Backup salvo localmente em: ${fallback}`);
    process.exit(1);
  }

  const tamanho = (fs.statSync(caminhoFinal).size / 1048576).toFixed(1);
  const totalLinhas = Object.values(manifesto.tabelas).reduce((s, n) => s + n, 0);
  const comErro = Object.keys(manifesto.erros);

  console.log('');
  console.log(`Backup concluído: ${caminhoFinal}`);
  console.log(`${Object.keys(manifesto.tabelas).length} tabela(s), ${totalLinhas} linha(s), ${tamanho} MB`);
  if (comErro.length) console.log(`Tabelas com erro (ver _MANIFESTO.json): ${comErro.join(', ')}`);

  try { fs.rmSync(tmp, { recursive: true, force: true }); } catch (e) {}
})();
