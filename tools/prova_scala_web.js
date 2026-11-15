// Attrezzo di lavorazione (tappa 14, blocco B, 15/11/2026): **la prova di `?scala=` e di
// `tela=` in un browser vero**, prima di chiederla al telefono.
//
// Per ogni scala apre la pagina come la apre un iPhone in orizzontale (stesso nome di
// browser, tocchi, 854 × 390 punti), tocca GIOCA e guarda due cose:
// - **cosa disegna davvero la scheda**: le misure passate a `gl.viewport`. Con la scena
//   al 65 % di una tela larga 1708, fra quelle misure dev'esserci 1110 × 507;
// - **cosa dice la riga della sonda**: i campi `scala`, `tela`, `schermo` e `dpr`.
// La scala che la scheda disegna è il controllo; la riga della sonda è quello che poi
// si leggerà dal telefono, e devono dire la stessa cosa.
//
// **Le righe della sonda si intercettano e non partono mai**: qui non c'è un modo per
// spedirle al Server 2 (in `banco_web.js` c'è `PW_SPEDISCI`; qui no, apposta).
//
// Uso, con `build/web` servita in locale (python -m http.server 8765 --bind 127.0.0.1):
//   node tools/prova_scala_web.js [porta] [scale] [densità] [cartella degli scatti]
//   node tools/prova_scala_web.js 8765 0.65,0.8,1.0 2 scatti
// Senza scala nell'indirizzo (`-`) si prova che vale ancora quella di sempre.
//
// Playwright non sta in questo repository: lo prende dalla cartella di NOXBOX.
const { chromium } = require('C:/Users/Utente/Desktop/claude/nextbot/node_modules/playwright');

const PORTA = process.argv[2] || '8765';
const SCALE = (process.argv[3] || '0.65,0.8,1.0').split(',');
const DENSITA = Number(process.argv[4] || 2);
const CARTELLA = process.argv[5] || '.';
const SECONDI = Number(process.env.PW_SECONDI || 24);
const IPHONE = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 '
  + '(KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1';

// Dentro la pagina: le misure di `gl.viewport` (con quante volte e in che fotogramma si
// sono viste la prima e l'ultima volta) e quante cose si disegnano a fotogramma.
const DENTRO = `(() => {
  const S = window.__pw = { misure: {}, fotogrammi: 0, disegni: 0, ultimi: 0 };
  const raf = window.requestAnimationFrame.bind(window);
  window.requestAnimationFrame = (cb) => raf((ts) => { S.fotogrammi += 1; S.ultimi = S.disegni; S.disegni = 0; cb(ts); });
  for (const tipo of [window.WebGL2RenderingContext, window.WebGLRenderingContext]) {
    if (!tipo) continue;
    const vista = tipo.prototype.viewport;
    tipo.prototype.viewport = function (x, y, l, a) {
      const k = l + 'x' + a;
      const m = S.misure[k] || (S.misure[k] = { volte: 0, primo: S.fotogrammi, ultimo: 0 });
      m.volte += 1; m.ultimo = S.fotogrammi;
      return vista.call(this, x, y, l, a);
    };
    for (const nome of ['drawElements', 'drawArrays', 'drawElementsInstanced', 'drawArraysInstanced']) {
      const disegna = tipo.prototype[nome];
      if (!disegna) continue;
      tipo.prototype[nome] = function () { S.disegni += 1; return disegna.apply(this, arguments); };
    }
  }
})();`;

(async () => {
  // Fuori dallo schermo, come `misura_web.js`: la finestra non copre il lavoro di nessuno.
  const browser = await chromium.launch({ headless: false,
    args: ['--ignore-gpu-blocklist', '--window-position=-3200,0'] });
  let rossi = 0;
  for (const scala of SCALE) {
    const chiesta = scala === '-' ? null : Number(scala);
    const contesto = await browser.newContext({ viewport: { width: 854, height: 390 },
      deviceScaleFactor: DENSITA, userAgent: IPHONE, hasTouch: true, isMobile: true });
    const pagina = await contesto.newPage();
    const righe = [];
    // Mai al Server 2: ogni richiesta verso la sonda finisce qui.
    await contesto.route(/sonda\.92-4-172-126/, (r) => {
      righe.push(decodeURIComponent(r.request().url().split('?')[1] || ''));
      r.fulfill({ status: 204, body: '' });
    });
    await pagina.addInitScript(DENTRO);
    const indirizzo = `http://127.0.0.1:${PORTA}/index.html?aspetto=5` + (chiesta === null ? '' : `&scala=${scala}`);
    const t0 = Date.now();
    await pagina.goto(indirizzo);
    // L'ingresso è pronto quando la scena si disegna da tre secondi di fila.
    let da = 0;
    while (Date.now() - t0 < 240000) {
      await pagina.waitForTimeout(500);
      const disegni = await pagina.evaluate(() => window.__pw.ultimi);
      if (disegni < 10) da = 0; else if (da === 0) da = Date.now(); else if (Date.now() - da > 3000) break;
    }
    await pagina.touchscreen.tap(Number(process.env.PW_X || 140), Number(process.env.PW_Y || 225));
    const tGioca = Date.now();
    // GIOCA entra appena l'arena è pronta dietro l'ingresso, e nel browser del PC ci vuole
    // (compila gli shader a due fotogrammi al secondo): la partita è cominciata quando arriva
    // la prima riga della sonda dall'arena, dieci secondi dopo il fischio.
    // Intanto uno scatto al secondo, tenendo gli ultimi: quello buono è di otto secondi e
    // mezzo prima della riga, cioè a metà del conto alla rovescia. Lì chi gioca sta ancora
    // alla partenza e nessuno gli ha sparato: è la stessa inquadratura a ogni scala.
    const scatti = [];
    while (Date.now() - tGioca < 480000 && !righe.some((r) => /scena=arena/.test(r))) {
      // Mentre l'arena si prepara la pagina sta ferma anche per secondi: uno scatto che
      // non arriva si salta, non ferma la prova.
      const immagine = await pagina.screenshot({ timeout: 5000 }).catch(() => null);
      if (immagine) scatti.push({ quando: Date.now(), immagine });
      if (scatti.length > 16) scatti.shift();
      await pagina.waitForTimeout(900);
    }
    const tPartita = Date.now();
    const prima = Math.max(0, (await pagina.evaluate(() => window.__pw.fotogrammi)) - 240);
    const buono = scatti.reduce((a, b) => (Math.abs(b.quando - (tPartita - 8500)) < Math.abs(a.quando - (tPartita - 8500)) ? b : a), scatti[0]);
    if (buono) require('fs').writeFileSync(`${CARTELLA}/scala-${scala === '-' ? 'senza' : scala.replace('.', '')}.png`, buono.immagine);
    await pagina.waitForTimeout(SECONDI * 1000);
    const dati = await pagina.evaluate(() => window.__pw);
    await contesto.close();

    // La tela vera, e la misura a cui la scheda deve disegnare la scena.
    const tela = [854 * DENSITA, 390 * DENSITA];
    const attesa = chiesta === null ? 0.65 : chiesta;
    const scena = `${Math.round(tela[0] * attesa)}x${Math.round(tela[1] * attesa)}`;
    const partita = Object.entries(dati.misure).filter(([, m]) => m.ultimo > prima)
      .sort((a, b) => b[1].volte - a[1].volte);
    const vista = partita.some(([k]) => {
      const [l, a] = k.split('x').map(Number);
      const [vl, va] = scena.split('x').map(Number);
      return Math.abs(l - vl) <= 1 && Math.abs(a - va) <= 1;
    });
    const arena = righe.filter((r) => /scena=arena/.test(r));
    const campo = (r, nome) => (r.match(new RegExp('(?:^|&)' + nome + '=([^&]*)')) || [])[1];
    const prima_riga = arena[0] || '';
    const giusta = prima_riga !== '' && Math.abs(Number(campo(prima_riga, 'scala')) - attesa) < 0.006
      && campo(prima_riga, 'tela') === `${tela[0]}x${tela[1]}`;
    if (!vista || !giusta) rossi += 1;
    console.log(`\n[scala ${scala}] ${indirizzo}  (ingresso in ${((tGioca - t0) / 1000).toFixed(0)} s, prima riga dall'arena dopo altri ${((tPartita - tGioca) / 1000).toFixed(0)} s, densità ${DENSITA})`);
    console.log(`  ${vista ? 'ok  ' : 'NO  '} la scheda disegna la scena a ${scena} (tela ${tela.join('x')} × ${attesa})`);
    console.log('       misure di gl.viewport in partita: '
      + partita.slice(0, 8).map(([k, m]) => `${k} (${m.volte} volte, fotogrammi ${m.primo}-${m.ultimo})`).join(' · '));
    console.log(`  ${giusta ? 'ok  ' : 'NO  '} la prima riga della sonda dice scala=${campo(prima_riga, 'scala')} tela=${campo(prima_riga, 'tela')}`
      + ` schermo=${campo(prima_riga, 'schermo')} dpr=${campo(prima_riga, 'dpr')}`);
    for (const r of arena) {
      console.log(`       t=${campo(r, 't')} fps=${campo(r, 'fps')} scala=${campo(r, 'scala')} tela=${campo(r, 'tela')}`
        + ` lavoro=${campo(r, 'lavoro')} chiamate=${campo(r, 'chiamate')} aspetto=${campo(r, 'aspetto')} modo=${campo(r, 'modo')} fine=${campo(r, 'fine') || ''}`);
    }
    if (arena.length === 0) console.log('       nessuna riga della sonda: ' + righe.length + ' richieste intercettate');
  }
  await browser.close();
  console.log(rossi === 0 ? '\nSCALA WEB: tutto verde.' : `\nSCALA WEB: ${rossi} scale NON tornano.`);
  process.exit(rossi === 0 ? 0 : 1);
})();
