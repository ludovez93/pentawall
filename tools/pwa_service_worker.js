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
// **La copia si scrive intanto, non prima** (06/10/2026). Fino ad allora l'operaio
// scaricava tutto il file, lo scriveva in cache e solo dopo lo passava al gioco: a
// ogni pubblicazione la barra di caricamento si fermava al 35% (il motore c'era, il
// pacchetto da 74 MB no) per tutto lo scaricamento, e sul telefono, la sera del
// 05/10/2026, non è più ripartita. Adesso il file va al gioco mentre arriva, e la
// barra cammina con lui.
//
// Questo file non cambia da una pubblicazione all'altra, ed è voluto: un operaio
// di servizio che resta identico non ha versioni vecchie da smaltire. Quando
// cambia (l'ultima volta il 06/10/2026), la prima apertura lo installa mentre il
// vecchio serve ancora quella pagina, e dalla seconda lavora il nuovo.

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
				evento.waitUntil(aggiornaLaCopia(indirizzo, risposta.clone()));
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

// La copia di riserva, scritta mentre il gioco legge l'originale. Se il file non è
// cambiato la copia si lascia andare subito: tenuta lì, il browser ne terrebbe in
// memoria tutto il contenuto. Se la scrittura non riesce (memoria piena) non importa:
// il gioco ha già il suo file, e la riserva resta quella di prima.
async function aggiornaLaCopia(indirizzo, risposta) {
	try {
		const cache = await caches.open(CACHE);
		const vecchia = await cache.match(indirizzo);
		if (vecchia !== undefined && vecchia.headers.get('ETag') === risposta.headers.get('ETag')) {
			if (risposta.body) {
				await risposta.body.cancel();
			}
			return;
		}
		await cache.put(indirizzo, risposta);
	} catch (errore) {
		// Solo la riserva non si è aggiornata.
	}
}
