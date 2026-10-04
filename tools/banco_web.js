// Attrezzo di lavorazione (04/10/2026): **fa girare il banco della scheda video**
// (`scripts/banco_scheda.gd`) in un browser vero, come farà il telefono aprendo
// `…/pentawall/?scheda`, e stampa le righe della sonda senza mandarle al Server 2.
//
// Uso, dalla cartella dove servi `build/web` (python -m http.server 8765):
//   node tools/banco_web.js <porta|indirizzo> [etichetta]
// Con PW_VOCI=risoluzione,lampade si fanno solo quelle voci, in quell'ordine; con
// PW_CALDO=10 il riscaldamento dura dieci secondi invece di novanta.
// Con PW_SPEDISCI=1 le righe vanno davvero al Server 2 (di serie si intercettano).
// Con PW_ANGLE=gl il browser usa OpenGL invece di Direct3D: compila più in fretta, ma
// sulla scheda di questo PC l'immagine esce blu (LEARNED.md § 48).
//
// Playwright non sta in questo repository: lo prende dalla cartella di NOXBOX.
const { chromium } = require('C:/Users/Utente/Desktop/claude/nextbot/node_modules/playwright');

const DOVE = process.argv[2] || '8765';
const ETICHETTA = process.argv[3] || 'banco';
const BASE = DOVE.startsWith('http') ? DOVE : `http://127.0.0.1:${DOVE}/index.html`;
const VOCI = process.env.PW_VOCI || '';
const URL = BASE + (BASE.includes('?') ? '&' : '?') + 'scheda' + (VOCI ? '=' + VOCI : '')
  + (process.env.PW_CALDO ? '&caldo=' + process.env.PW_CALDO : '');

(async () => {
  // Fuori dallo schermo, come in `misura_web.js`: gli scatti escono lo stesso.
  const argomenti = ['--ignore-gpu-blocklist', '--window-position=-3200,0'];
  if (process.env.PW_ANGLE) argomenti.push('--use-angle=' + process.env.PW_ANGLE);
  const browser = await chromium.launch({ headless: false, args: argomenti });
  const pagina = await browser.newPage({ viewport: { width: 854, height: 390 } });
  const righe = [];
  // Con PW_SPEDISCI=1 le righe arrivano anche al Server 2: è la prova che il banco
  // pubblicato spedisce davvero, prima di chiederlo al telefono (04/10/2026).
  await pagina.route(/sonda\.92-4-172-126/, (r) => {
    righe.push(decodeURIComponent(r.request().url().split('?')[1] || ''));
    if (process.env.PW_SPEDISCI) r.continue();
    else r.fulfill({ status: 204, body: '' });
  });
  const consolle = [];
  pagina.on('console', (m) => { const t = m.text(); if (!/glBlitFramebuffer/.test(t)) consolle.push(t); });
  const t0 = Date.now();
  await pagina.goto(URL);
  // L'ultima riga del banco lo dice (`ultima=1`).
  while (Date.now() - t0 < 900000) {
    await pagina.waitForTimeout(2000);
    if (righe.some((r) => /scena=banco/.test(r) && /&ultima=1/.test(r))) break;
  }
  await pagina.screenshot({ path: `${ETICHETTA}-fine.png` });
  await browser.close();
  console.log(`[${ETICHETTA}] ${((Date.now() - t0) / 1000).toFixed(0)} s`);
  // Ogni voce si confronta con la «base» misurata subito prima.
  let base = null;
  for (const r of righe) {
    if (!/scena=banco/.test(r)) { console.log('  ' + r); continue; }
    const v = Object.fromEntries(r.split('&').map((x) => x.split('=')));
    const delta = (v.voce !== 'base' && v.voce !== 'caldo' && base !== null) ? `  risparmio ${(base - Number(v.costo)).toFixed(1)} ms` : '';
    if (v.voce === 'base') base = Number(v.costo);
    console.log(`  ${v.n.padStart(2)} ${v.voce.padEnd(12)} fps ${v.fps.padStart(5)}  costo ${v.costo.padStart(5)} ms (lavoro ${v.lavoro}, max ${v.costo_max}, ${v.pesati} pesati)  chiamate ${v.chiamate}  scala ${v.scala}  msaa ${v.msaa}${delta}`);
  }
  const errori = consolle.filter((t) => /error|ERROR|Errore|WARNING/.test(t)).slice(0, 12);
  if (errori.length) { console.log('console:'); for (const e of errori) console.log('  ' + e.slice(0, 200)); }
})();
