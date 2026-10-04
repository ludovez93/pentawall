// Attrezzo di lavorazione (tappa 9, 03/10/2026): **misura la pagina web del gioco in
// un browser vero**, che è dove il telefono soffriva e il PC no.
//
// Per ogni fotogramma: quanto dura il giro di Godot, quanti programmi shader si
// compilano, quante texture e quanti suoni si caricano, quante chiamate di disegno.
// Per ogni programma: a quale shader appartiene (impronta del corpo) e quale
// variante è (le #define in testa). Le righe della sonda si intercettano e si
// stampano, senza mandarle al Server 2.
//
// Uso, dalla cartella dove servi `build/web` (python -m http.server 8765):
//   node tools/misura_web.js <porta|indirizzo> <etichetta> [secondi_di_regime]
// Con PW_X e PW_Y si cambia dove si tocca GIOCA (di serie 140, 225 a 854 × 390).
//
// Playwright non sta in questo repository: lo prende dalla cartella di NOXBOX.
const { chromium } = require('C:/Users/Utente/Desktop/claude/nextbot/node_modules/playwright');
const fs = require('fs');

const DOVE = process.argv[2] || '8765';
const ETICHETTA = process.argv[3] || 'misura';
const REGIME = Number(process.argv[4] || 12);
const URL = DOVE.startsWith('http') ? DOVE : `http://127.0.0.1:${DOVE}/index.html`;

const SONDA_INIT = `(() => {
  const S = window.__pw = { fotogrammi: [], programmi: [] };
  const ora = () => performance.now();
  const nuovo = () => ({ link: 0, linkMs: 0, tex: 0, texMs: 0, disegni: 0, audio: 0, audioS: 0, audioMs: 0 });
  let f = nuovo();
  const raf = window.requestAnimationFrame.bind(window);
  window.requestAnimationFrame = function (cb) {
    return raf(function (ts) {
      f = nuovo();
      const t0 = ora();
      try { cb(ts); } finally {
        f.inizio = t0; f.ms = ora() - t0;
        if (S.fotogrammi.length < 60000) S.fotogrammi.push(f);
      }
    });
  };
  const fonti = new WeakMap();
  const tipi = new WeakMap();
  const attaccati = new WeakMap();
  function fnv(s) { let h = 0x811c9dc5; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0; } return h.toString(16); }
  for (const P of [window.WebGL2RenderingContext && WebGL2RenderingContext.prototype]) {
    if (!P) continue;
    const cs = P.createShader;
    P.createShader = function (tipo) { const sh = cs.call(this, tipo); tipi.set(sh, tipo); return sh; };
    const ss = P.shaderSource;
    P.shaderSource = function (sh, src) { fonti.set(sh, src); return ss.call(this, sh, src); };
    const as = P.attachShader;
    P.attachShader = function (pr, sh) { const l = attaccati.get(pr) || []; l.push(sh); attaccati.set(pr, l); return as.call(this, pr, sh); };
    const lp = P.linkProgram;
    const gl = window.WebGL2RenderingContext;
    P.linkProgram = function (pr) {
      const t0 = ora();
      lp.call(this, pr);
      // Chiedere lo stato obbliga il browser a finire subito: è lì che sta il costo.
      const ok = this.getProgramParameter(pr, this.LINK_STATUS);
      const ms = ora() - t0;
      f.link++; f.linkMs += ms;
      let frammento = '';
      for (const sh of (attaccati.get(pr) || [])) if (tipi.get(sh) === this.FRAGMENT_SHADER) frammento = fonti.get(sh) || '';
      const righe = frammento.split('\\n');
      const define = righe.filter((r) => /^#define [A-Z_0-9]+\\s*$/.test(r.trim()) || /^#define (USE|MODE|DISABLE|LIGHT|BASE|RENDER|APPLY|ADDITIVE|SHADOW)/.test(r.trim())).map((r) => r.trim().slice(8));
      const corpo = righe.filter((r) => !/^#define /.test(r.trim())).join('\\n');
      S.programmi.push({ quando: S.fotogrammi.length, ms, ok, impronta: fnv(corpo), lunghezza: corpo.length, define, inizio: corpo.slice(0, 0) });
    };
    const avvolgi = (nome, n, m) => { const v = P[nome]; if (!v) return; P[nome] = function () { const t0 = ora(); try { return v.apply(this, arguments); } finally { if (n) f[n]++; if (m) f[m] += ora() - t0; } }; };
    for (const t of ['texImage2D', 'texSubImage2D', 'compressedTexImage2D', 'compressedTexSubImage2D', 'texImage3D', 'texSubImage3D', 'compressedTexImage3D']) avvolgi(t, 'tex', 'texMs');
    for (const d of ['drawElements', 'drawArrays', 'drawElementsInstanced', 'drawArraysInstanced', 'drawRangeElements']) avvolgi(d, 'disegni', null);
  }
  for (const C of [window.AudioContext, window.webkitAudioContext, window.OfflineAudioContext]) {
    if (!C || !C.prototype.createBuffer) continue;
    const cb = C.prototype.createBuffer;
    C.prototype.createBuffer = function (canali, lunghezza, frequenza) {
      const t0 = ora(); try { return cb.apply(this, arguments); } finally { f.audio++; f.audioS += lunghezza / frequenza; f.audioMs += ora() - t0; }
    };
  }
  if (window.AudioBuffer) {
    const cc = AudioBuffer.prototype.copyToChannel;
    AudioBuffer.prototype.copyToChannel = function () { const t0 = ora(); try { return cc.apply(this, arguments); } finally { f.audioMs += ora() - t0; } };
  }
})();`;

(async () => {
  // Di serie il browser usa ANGLE su Direct3D: compila lento (sulla scheda di questo PC
  // anche un secondo a programma) ma disegna giusto. Con PW_ANGLE=gl compila dieci volte
  // più in fretta e i conteggi restano veri, ma l'immagine della partita esce blu: va
  // bene per contare, non per guardare (visto il 04/10/2026).
  // La finestra si apre fuori dallo schermo: sul PC di Ludovico una partita tutta blu
  // sembra un gioco rotto (04/10/2026). Gli scatti escono lo stesso.
  const argomenti = ['--ignore-gpu-blocklist', '--window-position=-3200,0'];
  if (process.env.PW_ANGLE) argomenti.push('--use-angle=' + process.env.PW_ANGLE);
  const browser = await chromium.launch({ headless: false, args: argomenti });
  const pagina = await browser.newPage({ viewport: { width: 854, height: 390 } });
  const sonda = [];
  await pagina.route(/sonda\.92-4-172-126/, (r) => { sonda.push(decodeURIComponent(r.request().url().split('?')[1] || '')); r.fulfill({ status: 204, body: '' }); });
  const consolle = [];
  pagina.on('console', (m) => { const t = m.text(); if (!/glBlitFramebuffer/.test(t)) consolle.push(t); });
  await pagina.addInitScript(SONDA_INIT);
  const t0 = Date.now();
  await pagina.goto(URL);
  const fermo = async (secondi, limite) => {
    // Aspetta finché per `secondi` non si compila più niente.
    const inizio = Date.now();
    let ultimo = -1, da = Date.now();
    while (Date.now() - inizio < limite * 1000) {
      await pagina.waitForTimeout(500);
      // Pronta vuol dire che la scena 3D si disegna davvero: sulla pagina pubblicata
      // i primi secondi sono lo scaricamento, con fotogrammi vuoti e niente da compilare.
      const n = await pagina.evaluate(() => { const f = window.__pw.fotogrammi; const u = f.slice(-30);
        return window.__pw.programmi.length + ':' + f.length + ':' + Math.max(0, ...u.map((x) => x.disegni)); });
      const [p, fr, disegni] = n.split(':').map(Number);
      if (p !== ultimo || fr < 100 || disegni < 10) { ultimo = p; da = Date.now(); }
      else if (Date.now() - da > secondi * 1000) return;
    }
  };
  await fermo(6, 300);
  const pronta = (Date.now() - t0) / 1000;
  const segno = await pagina.evaluate(() => ({ f: window.__pw.fotogrammi.length, p: window.__pw.programmi.length }));
  await pagina.screenshot({ path: `${ETICHETTA}-ingresso.png` });
  await pagina.mouse.click(Number(process.env.PW_X || 140), Number(process.env.PW_Y || 225));
  const tClic = Date.now();
  await fermo(8, 400);
  const assestata = (Date.now() - tClic) / 1000;
  const segnoRegime = await pagina.evaluate(() => window.__pw.fotogrammi.length);
  await pagina.waitForTimeout(REGIME * 1000);
  await pagina.screenshot({ path: `${ETICHETTA}-partita.png` });
  const dati = await pagina.evaluate(() => window.__pw);
  await browser.close();

  const F = dati.fotogrammi, P = dati.programmi;
  const somma = (a, k) => a.reduce((s, x) => s + x[k], 0);
  const ingresso = F.slice(0, segno.f), partita = F.slice(segno.f, segnoRegime), regime = F.slice(segnoRegime);
  const pIngresso = P.filter((p) => p.quando <= segno.f), pPartita = P.filter((p) => p.quando > segno.f);
  console.log(`[${ETICHETTA}] pagina pronta e ferma in ${pronta.toFixed(1)} s; dopo GIOCA ferma in ${assestata.toFixed(1)} s`);
  console.log(`ingresso: ${pIngresso.length} programmi (${somma(pIngresso, 'ms').toFixed(0)} ms), ${somma(ingresso, 'tex')} texture (${somma(ingresso, 'texMs').toFixed(0)} ms)`);
  console.log(`audio: ingresso ${somma(ingresso, 'audio')} buffer (${somma(ingresso, 'audioS').toFixed(0)} s), dopo GIOCA ${somma(partita, 'audio') + somma(regime, 'audio')} buffer (${(somma(partita, 'audioS') + somma(regime, 'audioS')).toFixed(0)} s)`);
  console.log(`dopo GIOCA: ${pPartita.length} programmi (${somma(pPartita, 'ms').toFixed(0)} ms), ${somma(partita, 'tex')} texture (${somma(partita, 'texMs').toFixed(0)} ms)`);
  const peggiori = partita.map((x, i) => ({ ...x, i })).sort((a, b) => b.ms - a.ms).slice(0, 5);
  for (const p of peggiori) console.log(`  fotogramma a ${((p.inizio - partita[0].inizio) / 1000).toFixed(1)} s: ${p.ms.toFixed(0)} ms — programmi ${p.link} (${p.linkMs.toFixed(0)} ms), texture ${p.tex} (${p.texMs.toFixed(0)} ms), disegni ${p.disegni}, audio ${p.audio} buffer (${p.audioS.toFixed(0)} s di suono)`);
  const d = regime.map((x) => x.ms).sort((a, b) => a - b);
  const durata = (regime[regime.length - 1].inizio - regime[0].inizio) / 1000;
  console.log(`regime (${durata.toFixed(0)} s): ${(regime.length / durata).toFixed(1)} fotogrammi/s, giro mediano ${d[Math.floor(d.length / 2)].toFixed(1)} ms, 95° ${d[Math.floor(d.length * 0.95)].toFixed(1)} ms, disegni medi ${(somma(regime, 'disegni') / regime.length).toFixed(0)}`);
  // Programmi per shader: quanti corpi diversi, e quante varianti ciascuno.
  const perCorpo = {};
  for (const p of P) (perCorpo[p.impronta] = perCorpo[p.impronta] || []).push(p);
  const corpi = Object.entries(perCorpo).sort((a, b) => b[1].length - a[1].length);
  console.log(`programmi in tutto: ${P.length}, shader distinti: ${corpi.length}`);
  for (const [imp, l] of corpi.slice(0, 40)) {
    const varianti = l.map((p) => p.define.filter((x) => !/^(GLES|WEBGL)/.test(x)).join(' ')).join(' | ');
    console.log(`  ${imp} ×${l.length} (${(l[0].lunghezza / 1000).toFixed(0)}k, ${somma(l, 'ms').toFixed(0)} ms): ${varianti.slice(0, 300)}`);
  }
  console.log('sonda:'); for (const s of sonda) console.log('  ' + s);
  const errori = consolle.filter((t) => /error|ERROR|Errore|WARNING/.test(t)).slice(0, 12);
  if (errori.length) { console.log('console:'); for (const e of errori) console.log('  ' + e.slice(0, 200)); }
  fs.writeFileSync(`${ETICHETTA}-dati.json`, JSON.stringify({ segno, segnoRegime, P }));
})();
