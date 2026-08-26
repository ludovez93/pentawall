// L'operaio di servizio di PENTAWALL installato sulla schermata Home.
//
// Prende il posto di quello che scrive Godot in fase di esportazione, e cambia
// una cosa sola ma decisiva: **quello di Godot serve prima la copia in cache**,
// quindi una versione appena pubblicata arriva sul telefono soltanto al secondo
// avvio. Qui la regola è rovesciata: **prima la rete**.
//
// Ogni file viene chiesto al server con `cache: 'no-cache'`, che obbliga il
// browser a domandare «è cambiato?» invece di fidarsi dei dieci minuti di
// validità che manda GitHub Pages (`Cache-Control: max-age=600`). Se il file non
// è cambiato il server risponde «304 non modificato» e non si scarica niente:
// l'avvio resta veloce — conta, perché `index.wasm` pesa quasi 38 MB — ma la
// versione è sempre quella pubblicata per ultima.
//
// La copia in cache serve solo come rete di sicurezza: senza campo il gioco
// parte lo stesso, con l'ultima versione scaricata. Si riscrive soltanto quando
// il file è cambiato davvero, e lo si riconosce dall'`ETag`: senza quella
// guardia si riscriverebbero 38 MB sul telefono a ogni avvio.
//
// Questo file non cambia mai da una pubblicazione all'altra, ed è voluto: un
// operaio di servizio che resta identico non ha versioni vecchie da smaltire.

const CACHE = 'pentawall';

// Il nuovo operaio entra in servizio subito, senza aspettare che si chiudano le
// schede aperte, e prende in carico anche la pagina già a video.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (evento) => evento.waitUntil(self.clients.claim()));

self.addEventListener('fetch', (evento) => {
	const richiesta = evento.request;
	if (richiesta.method !== 'GET') {
		return;
	}
	// Solo roba nostra: quello che sta su altri domini passa senza essere toccato.
	if (new URL(richiesta.url).origin !== self.location.origin) {
		return;
	}

	evento.respondWith((async () => {
		const indirizzo = richiesta.url;
		try {
			const risposta = await fetch(indirizzo, { cache: 'no-cache', credentials: 'same-origin' });
			if (risposta && risposta.ok) {
				const cache = await caches.open(CACHE);
				const vecchia = await cache.match(indirizzo);
				const cambiata = vecchia === undefined
					|| vecchia.headers.get('ETag') !== risposta.headers.get('ETag');
				if (cambiata) {
					await cache.put(indirizzo, risposta.clone());
				}
			}
			return risposta;
		} catch (senzaRete) {
			const cache = await caches.open(CACHE);
			const copia = await cache.match(indirizzo);
			if (copia !== undefined) {
				return copia;
			}
			throw senzaRete;
		}
	})());
});
