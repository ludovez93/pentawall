class_name Arena
extends Node3D

## L'arena intera: la tappa 5.
##
## Non è più un angolo. È la palestra completa — 66 × 66 metri, quattro quote,
## traversata in dodici secondi — dentro cui si gioca una partita vera.
##
## **La pianta non sta in questo file.** Sta in `arene/palestra.json`, che è la
## sorgente unica: da lì si disegna la planimetria (`planimetrie/pianta_nostra.py`,
## nello stesso stile delle 39 mappe del 1999) e da lì si costruisce la scena. Un
## disegno che nasce dallo stesso file dell'arena non può raccontarne una diversa,
## ed è per questo che si può ragionare sulla carta prima di costruire — che è
## quello che ha permesso a Fable di bocciare la prima stesura senza che fosse
## costata una riga di codice.
##
## Le quattro quote hanno un nome, e sono il modo in cui ci si orienta senza
## mappa: **catino −2, campo 0, terrazze +3,5, ballatoio +7**.

const PIANTA := "res://arene/palestra.json"

## La rete di cammino, **cotta in anticipo** da `tools/cuoci_percorsi.gd` e salvata
## accanto alla pianta. Non si cuoce all'apertura: la pagina web gira senza thread,
## e lì la cottura sarebbe mezzo secondo di gioco fermo appena aperto il link.
const RETE := "res://arene/palestra_cammino.res"

const SPESSORE_PIANO := 0.6
const SPESSORE_RAMPA := 0.45

## I soffitti e le fasce, i lucernari e le loro lampade: le varianti dell'aspetto
## (tappa 10) li ritrovano per nome, invece di riconoscerli dal colore.
const GRUPPO_SOFFITTI := &"soffitti"
const GRUPPO_LUCERNARI := &"lucernari"

## I muri della pianta e le rampe (tappa 10, blocco D): l'arena-giocattolo costruisce i
## suoi moduli sopra le loro scatole, e li ritrova qui. Ogni muro porta il suo posto
## nell'elenco della pianta (`muro`), ogni pavimento quello della sua zona (`zona`).
const GRUPPO_PARETI := &"pareti"
const GRUPPO_RAMPE := &"rampe"

## **Si gioca a tempo, tre minuti** (decisione 19, dal blocco C). Il duello del
## poligono resta a 500 punti; qui no, e per due motivi misurati: a 500 la partita
## finiva in cinquanta secondi, e sapere quanto manca vale più di sapere quanto
## serve — è `MIGLIORIE.md` § 3, che lo diceva dal 25/08/2026.
const DURATA_PARTITA := 180.0

## Il fischio d'inizio: 3 · 2 · 1 · VIA. Prima del via nessuno ha un bersaglio e
## nessun colpo fa punti — la partita comincia per tutti nello stesso istante.
const CONTO_INIZIALE := 3.0

## Gli annunci dell'ultimo pezzo di partita, in secondi che mancano.
const AVVISI_TEMPO := [{"quando": 60.0, "cosa": "ULTIMO MINUTO"},
	{"quando": 30.0, "cosa": "30 SECONDI"}]

## Quanto si aspetta fra due annunci di posizione: senza, in mischia sarebbe una
## mitragliata di «TI HANNO SUPERATO».
const ATTESA_ANNUNCIO := 3.0

## **Come si è entrati.** Dal pulsante GIOCA dell'ingresso si arriva con questa
## accesa: partita che parte da sola, interfaccia di gioco, niente pulsanti di
## prova. Dal banco di prova («ARENA LIBERA») si arriva con questa spenta, e
## l'arena è quella di sempre.
static var modo_partita := false

## **L'arena che si prepara dietro l'ingresso** (tappa 9, 03/10/2026). Accesa da
## chi la costruisce in una vetrina invisibile: si fa solo il mondo — muri, pubblico,
## luci, il giocatore — un passo per fotogramma, e poi si aspetta. Interfaccia,
## suoni, sonda e partita arrivano con `entra_in_campo`, quando l'ingresso la porta
## sullo schermo. Spenta (i collaudi, il banco di prova) l'arena nasce tutta subito.
static var in_preparazione := false

## **Il banco della scheda video** (`BancoScheda`, 04/10/2026): acceso dall'ingresso
## quando l'indirizzo dice `?scheda`. La partita parte come sempre, poi il banco ferma
## tutti e misura; la risoluzione resta quella di partenza, perché ogni voce si
## confronta con la stessa.
static var banco_scheda := false
## Le voci del banco, se l'indirizzo le sceglie (`?scheda=base,pieno`); vuoto, tutte.
static var voci_banco: Array = []

## Il mondo è pronto e l'arena aspetta di entrare in campo.
signal preparata

## **I cinque avversari.** Il numero non è nostro: la partita di carriera del 1999
## girava con cinque bot più il giocatore (`RICERCA-ORIGINALE.md` § 2), ed è anche
## il motivo per cui questa pianta ha sei partenze. Uno per partenza, nessuno
## avanza.
##
## I nomi servono alla classifica: cinque avversari senza nome sono cinque
## capsule, e in classifica sarebbero cinque righe uguali.
const NOMI := ["BRACE", "QUARZO", "LAMPO", "NEBBIA", "TORO"]

## Quante righe di classifica si vedono mentre si gioca, oltre alla tua.
const PODIO := 3

## Ogni quanto un avversario si guarda intorno e sceglie di nuovo chi attaccare.
## Non tutti insieme: **uno per volta, a turno**, così i raggi di vista sono
## cinque ogni sei decimi di secondo invece di venticinque tutti nello stesso
## fotogramma. È il primo dei quattro rimedi del piano, e costa così poco che si
## spende subito.
const RISCELTA := 0.6

## Quanti dei più vicini si controllano davvero con un raggio. Guardarli tutti
## costerebbe cinque volte tanto per cambiare idea quasi mai: chi è il quarto più
## vicino, in un'arena da sessantasei metri, è lontano comunque.
const CANDIDATI_VISTA := 3

## Quanto tiene il bersaglio che si ha già. Senza questo margine un avversario
## cambierebbe preda a ogni riscelta — due nemici quasi alla stessa distanza se lo
## rimpallerebbero — e da fuori si vedrebbe uno che gira su se stesso.
const AFFEZIONE := 1.4

## **Dove si rinasce** (tappa 11, blocco A). Dal telefono, il 05/10/2026: *«quando
## muori non devi rinascere vicino ad altri avversari, ti uccidono subito»*. Si
## sceglieva fra le sei partenze guardando solo chi aveva sparato; adesso vale la
## regola del 1999 (`RICERCA-ORIGINALE.md` § 2): pesano i posti vicini o in vista di
## **qualunque** concorrente in campo. I posti sono le partenze più i punti presi
## dai pavimenti della pianta (`_prepara_le_rinascite`): in tutto `RINASCITE`, cercati
## ogni `PASSO_RINASCITE` metri.
const RINASCITE := 24
const PASSO_RINASCITE := 4.0
## Un punto di rinascita sta ad almeno tanto da ogni muro alla sua altezza, e almeno
## tanto dentro il suo pavimento e lontano dalle rampe: mai a filo di un cassone o
## sull'orlo di una terrazza.
const MARGINE_MURI := 1.2
const MARGINE_BORDO := 1.0

## Oltre questa distanza dal concorrente più vicino un posto vale l'altro: senza un
## tetto si rinascerebbe sempre nello stesso angolo, il più lontano di tutti.
const LONTANO_ABBASTANZA := 25.0

## E la rinascita deve **spostare**: almeno tanti metri da dove si è stati presi.
## Con le sole sei partenze, lontane fra loro, bastava escludere quella in cui si
## stava (collaudo dell'arena, 27/08/2026); fra ventiquattro posti un punto a due
## passi vincerebbe, e chi viene centrato ricompare da un'altra parte dell'arena.
const SCARTO_MINIMO := 15.0

## Quanto pesa ogni concorrente che vede il posto: più del tetto della distanza, così
## un posto in vista perde sempre contro uno coperto, per vicino che sia.
const PENALITA_IN_VISTA := 100.0

## *Nostro*: per tanti secondi chi è appena rinato non si può colpire, e lampeggia
## come dopo un colpo (`Giocatore.proteggi`, `Avversario.proteggi`).
const PROTEZIONE := 2.0

## La tavolozza della palestra, la stessa dell'angolo della tappa 3: nessuna di
## queste tinte è il bianco-arancio del dardo, e nessuna è il ciano delle sponde.
const TINTE := {
	"moquette": Color(0.24, 0.13, 0.36),
	"ocra": Color(0.66, 0.47, 0.15),
	"mattone": Color(0.58, 0.19, 0.20),
	"tribuna": Color(0.19, 0.16, 0.38),
	# Era (0.10, 0.10, 0.21): con la luce d'ambiente veniva nero, uguale al fondo
	# dietro l'arena, e dal telefono «alcuni tetti non si vedono» (12/09/2026).
	# Misurato con due scatti: schiarita si vede, con più luci restava nera.
	"soffitto": Color(0.36, 0.34, 0.60),
}

const SPONDA := Color(0.09, 0.60, 0.64)
const NEON_SPONDA := Color(0.30, 0.99, 0.95)

const CANDIDATI := [
	{"nome": "bianco-arancio", "colore": Color(1.0, 0.62, 0.24)},
	{"nome": "ciano-bianco", "colore": Color(0.35, 0.9, 1.0)},
	{"nome": "magenta-bianco", "colore": Color(1.0, 0.36, 0.78)},
]

const SCORCIATOIE := {KEY_C: "colore", KEY_S: "sponde", KEY_A: "poligono", KEY_P: "partenza",
	KEY_B: "sfida", KEY_L: "livello", KEY_R: "dardo"}

## Gli anelli del rimbalzo, riciclati: nascerne uno a ogni impatto è quello che
## faceva scattare l'immagine sparando a raffica (LEARNED.md § 25).
const ANELLI_IN_RISERVA := 12
const VITA_ANELLO := 0.36

var _pianta: Dictionary = {}
## I pezzi di ogni zona dopo il ritaglio delle rampe che le passano sotto, nello
## stesso ordine della pianta (`_ritaglia_le_rampe`).
var _pezzi: Array = []
## I posti in cui si rinasce: `{"dove", "giro"}`, con `giro` NAN dove il verso si
## sceglie al momento (`_prepara_le_rinascite`).
var _rinascite: Array[Dictionary] = []
var _giocatore: Giocatore
var _comandi: Comandi
var _bersagli: Array[Bersaglio] = []
var _punteggio := 0
var _migliore := 0
var _migliore_muri := 0
var _candidato := 0
var _tasti := {}
var _solo_sponde := true
var _bottone_sponde: Button
var _bottone_dardo: Button
var _partenza := 0
var _anelli: Array[MeshInstance3D] = []
var _vita_anelli: Array[float] = []
var _prossimo_anello := 0

## Chi è in campo: `{"nome": String, "corpo": Node3D, "punti": int}`. Il giocatore
## è una riga come le altre — è la differenza fra una partita a sei e un duello
## con quattro comparse.
var _concorrenti: Array[Dictionary] = []
var _sfida := false
var _finita := false
## Il livello di partenza è **il facile**: la prima partita si deve poter vincere.
var _livello := 0
var _modo_partita := false
var _in_preparazione := false
var _durata := DURATA_PARTITA
var _tempo := 0.0
var _conto := 0.0
var _posizione_annunciata := 0
var _attesa_annuncio := 0.0
var _avvisi_dati := 0
var _prossima_riscelta := 0.0
var _turno_riscelta := 0
## Chi deve ancora nascere: `{"riga", "partenza"}`, un corpo per fotogramma. In
## classifica ci sono già tutti dal fischio d'inizio — è il **corpo** ad arrivare
## un attimo dopo, non il concorrente.
var _in_arrivo: Array[Dictionary] = []
## La sonda dei fotogrammi: in partita manda i numeri del telefono al Server 2.
var _sonda: Sonda
## Il tabellone sopra il catino, e ogni quanto si riscrive (quattro volte al secondo
## basta per un cronometro che cambia una volta al secondo).
var _tabellone: Node3D
var _prossimo_tabellone := 0.0
## Le palle colorate (tappa 8, blocco H).
var _potenziamenti: Potenziamenti
## Le sagome del tuo RADAR sono accese (tappa 11, blocco B).
var _radar_acceso := false


func _ready() -> void:
	_in_preparazione = in_preparazione
	# **Il mondo**, in passi. Preparata dietro l'ingresso, fra un passo e l'altro
	# l'arena lascia passare un fotogramma: sul telefono l'arena intera costava un
	# fotogramma solo da secondi, e così il palco continua a muoversi.
	_pianta = carica_pianta()
	_ambiente()
	_costruisci()
	await _respiro()
	_prepara_le_rinascite()
	await _respiro()
	# Le superfici vere al posto delle tinte piatte (tappa 8, blocco E): moquette,
	# intonaco, mattoni e lamiera PBR, ognuna con il colore della sua tinta. Fino al
	# 03/10/2026 vestivano solo l'angolo dell'attrezzo degli scatti.
	Vestizione.vesti(self)
	await _respiro()
	_tabellone = Vestizione.arreda_arena(self, _pianta)
	await _respiro()
	_pubblico()
	# L'aspetto (tappa 10): la variante scelta veste prima della luce per vertice, così
	# i pezzi che aggiunge la calcolano sui vertici come tutti gli altri. L'arena-giocattolo
	# lo fa a passi, un fotogramma l'uno quando si prepara dietro l'ingresso.
	await Aspetto.veste(self)
	_luce_per_vertice()
	await _respiro()
	_rete_di_cammino()
	_luci()
	Aspetto.illumina(self)
	_prepara_gli_anelli()
	add_child(Scintille.new())
	_potenziamenti = Potenziamenti.new()
	_potenziamenti.name = "potenziamenti"
	add_child(_potenziamenti)
	_potenziamenti.concorrenti = _corpi_in_campo
	_potenziamenti.prepara(POTENZIAMENTI)
	_potenziamenti.preso.connect(_su_potenziamento_preso)
	_potenziamenti.finito.connect(_su_potenziamento_finito)
	await _respiro()
	_giocatore = Giocatore.new()
	add_child(_giocatore)
	# Si collega una volta sola, non a ogni partita: `preso_da` porta **chi** ha
	# sparato, ed è l'unico posto da cui passano i punti di chiunque.
	_giocatore.preso_da.connect(_su_colpo_valido.bind(_giocatore))
	_mettiti_alla_partenza(0)

	if _in_preparazione:
		preparata.emit()
		return
	entra_in_campo()


## **La luce per vertice** (tappa 9, terza parte, 04/10/2026). Sul telefono, dopo i primi
## 15-35 secondi, un fotogramma costava 45-54 ms, e le lampade ne valevano 26: Godot
## calcola su ogni pixel le otto lampade migliori di ogni pezzo, e con 23 lampade da 10-26
## metri di portata ogni pezzo ne ha quasi sempre otto. Qui i pezzi dell'arena le
## calcolano sui vertici e le sfumano: nel banco del telefono, da 46 a 11 ms. Si perdono
## i riflessi bianchi delle lampade sulle lamiere di tribune e soffitti (scelta di
## Ludovico, 04/10/2026: tornano finti nella tappa 10). Corpi, pubblico e quello che
## nasce dopo (anelli, palle colorate, dardi) restano per pixel: sono piccoli sullo
## schermo. Si cambia il materiale stesso: quelli di `Vestizione` li condividono tutti i
## pezzi, e il palco dell'ingresso ne usa una copia sua. Va fatto prima della vetrina,
## che così scalda gli shader nella variante della partita.
func _luce_per_vertice() -> void:
	for nodo in find_children("*", "MeshInstance3D", true, false):
		var materiale := (nodo as MeshInstance3D).material_override as BaseMaterial3D
		if materiale != null and materiale.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL:
			materiale.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX


## Un fotogramma di respiro fra due passi della costruzione, solo quando l'arena si
## prepara dietro l'ingresso.
func _respiro() -> void:
	if _in_preparazione:
		await get_tree().process_frame


## **L'arena entra in campo**: la resa del telefono, la sonda, i suoni,
## l'interfaccia, la camera — e la partita, se si è arrivati da GIOCA. Quando
## l'arena si è preparata dietro l'ingresso, la chiama l'ingresso dopo averla
## portata sullo schermo: niente di questo ha senso dentro una vetrina invisibile
## (la sonda misurerebbe l'ingresso, i suoni ruberebbero la musica al palco,
## l'interfaccia si disporrebbe su una finestra di 128 punti).
func entra_in_campo() -> void:
	_in_preparazione = false
	Resa.regola(get_viewport())
	if not banco_scheda:
		add_child(Resa.new())
	_sonda = Sonda.new()
	_sonda.arena = self
	add_child(_sonda)
	add_child(Suoni.new())

	_comandi = Comandi.new()
	add_child(_comandi)
	_comandi.colore_richiesto.connect(_cambia_colore)
	_comandi.camera_richiesta.connect(func() -> void: _giocatore.cambia_camera())
	_comandi.sfida_richiesta.connect(commuta_sfida)
	_comandi.livello_richiesto.connect(cambia_livello)
	_bottone_sponde = _comandi.pulsante_di_scena("SPONDE", Color(0.2, 0.75, 0.7), commuta_sponde)
	_comandi.pulsante_di_scena("PARTENZA", Color(0.85, 0.45, 0.35), passa_alla_partenza_seguente)
	_comandi.pulsante_di_scena("POLIGONO", Color(0.35, 0.4, 0.55), torna_al_poligono)
	# La manopola del «lento» che si gira giocando: il dardo a 19 o a 24 m/s
	# (tappa 7, blocco B). Decide il pollice, non il PC.
	_bottone_dardo = _comandi.pulsante_di_scena("DARDO 19", Color(0.8, 0.55, 0.25), commuta_dardo)
	_scrivi_il_dardo()

	_giocatore.comandi = _comandi
	# Dalla vetrina la camera corrente era un'altra: qui torna quella di chi gioca.
	_giocatore.camera().make_current()

	# Il primo colpo di una partita costava un fotogramma intero: si scalda lo
	# shader del bagliore appena la scena si apre (LEARNED.md § 26 e 27).
	Proiettile.scalda(self, _giocatore.camera())
	# E le cose nuove della tappa 8: particelle e lampo dello sparo.
	if Scintille.attivo != null:
		Scintille.attivo.scalda(_giocatore.camera())
	_giocatore.corpo().scalda(_giocatore.camera())

	_comandi.rigioca_richiesta.connect(rigioca)
	_comandi.uscita_richiesta.connect(torna_all_ingresso)

	get_tree().node_added.connect(_su_nodo_nuovo)
	_applica_regola()
	_aggiorna_righe()

	# Da GIOCA si entra in partita, non in un'arena da guardare.
	_modo_partita = modo_partita
	if _modo_partita:
		avvia_sfida()
		if banco_scheda:
			var banco := BancoScheda.new()
			banco.arena = self
			banco.sonda = _sonda
			if not voci_banco.is_empty():
				banco.voci = voci_banco
			add_child(banco)


## La pianta si legge da un file di testo, non da un file del motore: si apre con
## un editor qualunque, si confronta con la planimetria e si corregge a mano.
static func carica_pianta(percorso := PIANTA) -> Dictionary:
	var testo := FileAccess.get_file_as_string(percorso)
	assert(testo != "", "pianta non trovata: %s" % percorso)
	var letto: Variant = JSON.parse_string(testo)
	assert(letto is Dictionary, "pianta illeggibile: %s" % percorso)
	return letto as Dictionary


# ------------------------------------------------------------------ costruzione

func _costruisci() -> void:
	var zone: Array = _pianta["zone"]
	_pezzi.clear()
	for zona in zone:
		_pezzi.append(_ritaglia_le_rampe(_contorno(zona["poligono"]), float(zona["quota"])))
	for i in zone.size():
		var contorno := _contorno(zone[i]["poligono"])
		var solidi: Array[PackedVector2Array] = []
		if _pezzi[i].size() != 1 or _pezzi[i][0] != contorno:
			solidi.assign(_pezzi[i])
		Muratura.piano(self, contorno, float(zone[i]["quota"]),
				SPESSORE_PIANO, _tinta(zone[i]["tinta"]), _parti_scoperte(i), solidi) \
				.set_meta(&"zona", i)

	_cordoli()

	for r in _pianta["rampe"]:
		Muratura.rampa(self, _punto(r["da"]), _punto(r["a"]), float(r["larghezza"]),
				float(r["quota_da"]), float(r["quota_a"]), SPESSORE_RAMPA,
				_tinta("moquette")).add_to_group(GRUPPO_RAMPE)

	var muri: Array = _pianta["muri"]
	for i in muri.size():
		var m: Dictionary = muri[i]
		var misura := Vector3(float(m["misura"][0]), float(m["alto"]), float(m["misura"][1]))
		var centro := Vector3(float(m["centro"][0]),
				float(m["quota"]) + misura.y * 0.5, float(m["centro"][1]))
		var nome := String(m.get("nome", ""))
		# **La regola delle forme** (12/09/2026, tappa 8 blocco E): nessuno spigolo
		# vivo. Colonne, piloni e pilastri diventano tondi; tutto il resto si smussa,
		# di più le cose basse che si guardano da vicino (cassoni, casse, blocchi),
		# di meno i muri alti. Lo decide il nome nella pianta, non la misura.
		var corpo: StaticBody3D
		if _e_tondo(nome) and absf(misura.x - misura.z) < 0.01:
			corpo = Muratura.pilone(self, centro, misura.x * 0.5, misura.y, _tinta(m["tinta"]))
		else:
			corpo = Muratura.muro(self, centro, misura, _tinta(m["tinta"]),
					Vector3(0, float(m.get("giro", 0)), 0), _smusso_di(nome, misura))
		corpo.add_to_group(GRUPPO_PARETI)
		corpo.set_meta(&"muro", i)

	for s in _pianta["sponde"]:
		var faccia := Vector2(float(s["faccia"][0]), float(s["faccia"][1]))
		var dove := Vector3(float(s["centro"][0]), float(s["quota"]), float(s["centro"][1]))
		Muratura.sponda(self, dove, faccia, _giro_sponda(s), SPONDA, NEON_SPONDA)

	for b in _pianta["bersagli"]:
		var dove := Vector3(float(b["dove"][0]), float(b["quota"]), float(b["dove"][1]))
		_aggiungi_bersaglio(dove, Color(0.32, 0.92, 0.56) if b["solo_di_sponda"]
				else Color(0.26, 0.74, 1.0))

	# Il soffitto: senza, l'arena e' a cielo aperto e la palestra del 1999 non lo
	# era. E' anche il secondo modo in cui si capisce dove si e': alto sul cuore,
	# alto sul ballatoio, piu' basso sulle ali.
	for c in _pianta["soffitti"]:
		var spessore := 0.6
		var misura := Vector3(float(c["misura"][0]), spessore, float(c["misura"][1]))
		Muratura.muro(self, Vector3(float(c["centro"][0]),
				float(c["quota"]) + spessore * 0.5, float(c["centro"][1])),
				misura, _tinta(c["tinta"])).add_to_group(GRUPPO_SOFFITTI)

	# Le fasce: dove il soffitto sale da 8 a 12 metri — dalle ali al cuore e al
	# lato sud — fra i due soffitti restava un gradino aperto di quattro metri, e
	# da un'ala si guardava dentro il vuoto sopra l'altra («alcuni tetti non si
	# vedono», dal telefono, 12/09/2026). Sono muri come gli altri, solo in alto.
	for f in _pianta.get("fasce", []):
		var misura := Vector3(float(f["misura"][0]), float(f["alto"]), float(f["misura"][1]))
		Muratura.muro(self, Vector3(float(f["centro"][0]),
				float(f["quota"]) + misura.y * 0.5, float(f["centro"][1])),
				misura, _tinta(f["tinta"])).add_to_group(GRUPPO_SOFFITTI)

	# I lucernari: nell'originale sono la cosa che dice «palestra» in mezzo
	# secondo, e costano un rettangolo acceso l'uno.
	for l in _pianta["lucernari"]:
		Muratura.decoro(self, Vector3(float(l["dove"][0]), float(l["quota"]),
				float(l["dove"][1])),
				Vector3(float(l["misura"][0]), 0.12, float(l["misura"][1])),
				Color(0.72, 0.52, 0.98), 0.72).add_to_group(GRUPPO_LUCERNARI)

	# Le insegne della pianta le costruisce l'arredo (`Vestizione.arreda_arena`):
	# dal 03/10/2026 sono oggetti — pannello, cornice al neon, scritta — e non più
	# scritte sospese davanti al muro.


## **Dove un pavimento si vede.** Nella pianta i quattro passaggi diagonali passano
## sopra le ali e gli angoli **alla stessa quota**: due pavimenti nello stesso piano,
## e la scheda video li disegnava tutti e due — moquette e parquet, e a ogni passo
## vinceva l'altro. Dal telefono, il 04/10/2026: *«qualche zona del pavimento
## lampeggia quando ci passo»*. Non si era mai visto perché fino alla tappa 8 i
## pavimenti erano invisibili dall'alto (`LEARNED.md` § 42).
##
## Una zona si disegna solo dove nessuna zona scritta **dopo** di lei sta alla stessa
## quota: chi viene dopo vince, come nella planimetria. È solo l'aspetto: la
## collisione resta il contorno intero, e con lei la rete di cammino.
func _parti_scoperte(indice: int) -> Array[PackedVector2Array]:
	var zone: Array = _pianta["zone"]
	var quota := float(zone[indice]["quota"])
	var parti: Array[PackedVector2Array] = []
	parti.assign(_pezzi[indice])
	for j in range(indice + 1, zone.size()):
		if absf(float(zone[j]["quota"]) - quota) > 0.01:
			continue
		var sopra := _contorno(zone[j]["poligono"])
		var restano: Array[PackedVector2Array] = []
		for parte in parti:
			var pezzi := Geometry2D.clip_polygons(parte, sopra)
			# Una zona tutta dentro un'altra lascerebbe un buco, e un pavimento col buco
			# non si triangola così: si tiene intera e lo dice. Il collaudo dei
			# pavimenti (`prova_vivo`) la troverebbe doppia.
			if _ha_un_buco(pezzi):
				push_warning("pavimento con un buco, non ritagliato: %s" % zone[indice]["nome"])
				restano.append(parte)
				continue
			restano.append_array(pezzi)
		parti = restano
	return parti


## **Un pavimento non copre una rampa che gli passa sotto** (tappa 10, blocco A).
## Dove la rampa sta fra i piedi e la testa di chi la sale — sotto la quota del
## pavimento, ma non tanto da passarci sotto in piedi — il pavimento si ritaglia,
## anche nella collisione, e la rampa ci arriva a filo. Dalla tappa 5 non lo faceva:
## la scala nord-est usciva dal catino contro un gradino di 80 cm (la zona della
## scala e gli spigoli delle due ali le passavano sopra) e finiva contro l'angolo
## della terrazza, e la rampa dell'ocra finiva mezzo metro dentro la piattaforma
## (31 cm). Misurato con una capsula come il giocatore, 04/10/2026.
func _ritaglia_le_rampe(contorno: PackedVector2Array, quota: float) -> Array[PackedVector2Array]:
	var pezzi: Array[PackedVector2Array] = [contorno]
	for r in _pianta["rampe"]:
		var taglio := _rampa_sotto(r, quota)
		if taglio.is_empty():
			continue
		var restano: Array[PackedVector2Array] = []
		for pezzo in pezzi:
			var esito := Geometry2D.clip_polygons(pezzo, taglio)
			if _ha_un_buco(esito):
				push_warning("pavimento bucato da una rampa, non ritagliato: %s" % r["nome"])
				restano.append(pezzo)
				continue
			restano.append_array(esito)
		pezzi = restano
	return pezzi


## I pezzi di una zona dopo il ritaglio delle rampe: servono a chi collauda i
## pavimenti, che altrimenti scambierebbe per un buco il posto di una rampa.
func pezzi_della_zona(indice: int) -> Array:
	return _pezzi[indice]


## L'impronta del pezzo di rampa che sta fra i piedi e la testa di chi starebbe su
## un pavimento a questa quota: vuota se la rampa non ci passa.
func _rampa_sotto(r: Dictionary, quota: float) -> PackedVector2Array:
	var q_da := float(r["quota_da"])
	var q_a := float(r["quota_a"])
	if is_equal_approx(q_da, q_a):
		return PackedVector2Array()
	var basso := quota - SPESSORE_PIANO - Giocatore.ALTEZZA_CORPO
	var t1 := clampf((basso - q_da) / (q_a - q_da), 0.0, 1.0)
	var t2 := clampf((quota - q_da) / (q_a - q_da), 0.0, 1.0)
	if absf(t2 - t1) < 0.001:
		return PackedVector2Array()
	var da := _punto(r["da"])
	var a := _punto(r["a"])
	var lato := (a - da).normalized().orthogonal() * float(r["larghezza"]) * 0.5
	var p1 := da.lerp(a, minf(t1, t2))
	var p2 := da.lerp(a, maxf(t1, t2))
	return PackedVector2Array([p1 - lato, p2 - lato, p2 + lato, p1 + lato])


## Un ritaglio ha un buco quando un pezzo sta dentro un altro.
static func _ha_un_buco(pezzi: Array[PackedVector2Array]) -> bool:
	for a in pezzi:
		for b in pezzi:
			if a != b and Geometry2D.is_point_in_polygon(a[0], b):
				return true
	return false


## Tondi: colonne, piloni, pilastri. Tutto il resto è una scatola, smussata.
static func _e_tondo(nome: String) -> bool:
	return nome.contains("colonna") or nome.contains("pilone") or nome.contains("pilastro")


## Di quanto si smussano gli spigoli di un muro, in metri.
static func _smusso_di(nome: String, misura: Vector3) -> float:
	var sottile := minf(misura.x, misura.z)
	if nome.contains("cassone") or nome.contains("cassa") or nome.contains("blocco") 			or nome.contains("box"):
		return 0.3
	if nome.contains("perimetro") or nome.contains("faccia"):
		return 0.18
	return clampf(sottile * 0.3, 0.06, 0.16)


## Il cordolo: una riga chiara sul **bordo che dà sul vuoto** di ogni piano alto.
##
## Serve a rispondere a una cosa arrivata dal telefono il 26/08/2026, e sono le
## parole di Ludovico: *«qui sono salito su qualcosa ma sembro sospeso nel vuoto»*.
## Non era un difetto di collisione — sotto i piedi il pavimento c'era. Era che
## **non si vedeva**: il piano della passerella è ocra come la parete che le sta
## dietro, stessa tinta e stessa grana, e in terza persona la camera lo guarda
## quasi a filo. Un piano visto di taglio, senza un bordo che lo stacchi, non è un
## piano: è una fascia di colore.
##
## Il poligono e l'angolo ce l'avevano già (zoccoli e segnatura a terra), e per lo
## stesso motivo: *senza, una stanza di scatole tutte dello stesso colore non dice
## dove finisce il pavimento*. L'arena intera se n'era dimenticata.
##
## Il cordolo va **solo dove serve**: sui lati oltre i quali non c'è pavimento alla
## stessa quota. Fra due zone che si toccano sarebbe una riga in mezzo al niente.
func _cordoli() -> void:
	var tinta := Muratura.CORDOLO
	var zone: Array = _pianta["zone"]
	for z in zone.size():
		var quota := float(zone[z]["quota"])
		if quota <= 0.0:
			continue
		for contorno: PackedVector2Array in _pezzi[z]:
			_cordoli_di(contorno, quota, tinta)


func _cordoli_di(contorno: PackedVector2Array, quota: float, tinta: Color) -> void:
	for i in contorno.size():
		var da := contorno[i]
		var a := contorno[(i + 1) % contorno.size()]
		var lungo := da.distance_to(a)
		if lungo < 0.6:
			continue
		var mezzo := (da + a) * 0.5
		var verso := (a - da).normalized()
		var fuori := Vector2(verso.y, -verso.x)
		# Il fuori si prova, non si deduce dal verso del contorno: un pezzo ritagliato
		# da una rampa può uscire girato al contrario, e allora ogni bordo sembrerebbe
		# una giuntura con sé stesso.
		if Geometry2D.is_point_in_polygon(mezzo + fuori * 0.01, contorno):
			fuori = -fuori
		# Un lato su cui arriva una rampa non è un bordo: è l'ingresso. Una riga lì
		# è una riga da scavalcare (visto sugli scatti della rampa dell'ocra,
		# 12/09/2026).
		if _rampa_arriva(mezzo, quota):
			continue
		# Un tratto che confina con un altro piano alla stessa quota non è un bordo:
		# è una giuntura, e segnarla vorrebbe dire disegnare una riga in mezzo al
		# pavimento. Il lato si guarda a passi di mezzo metro, non dal suo punto di
		# mezzo: dopo il ritaglio della scala, il lato ovest della terrazza nord-est
		# dà sul vuoto per cinque metri e tocca la passerella per gli altri cinque, e
		# il punto di mezzo cadeva proprio sul confine (04/10/2026).
		var passi := maxi(1, roundi(lungo / 0.5))
		var inizio := -1
		for k in passi + 1:
			var bordo := k < passi and not _piano_alla_quota(
					da.lerp(a, (k + 0.5) / passi) + fuori * 0.8, quota)
			if bordo and inizio < 0:
				inizio = k
			elif not bordo and inizio >= 0:
				_cordolo(da.lerp(a, float(inizio) / passi), da.lerp(a, float(k) / passi),
						quota, tinta)
				inizio = -1


func _cordolo(da: Vector2, a: Vector2, quota: float, tinta: Color) -> void:
	var lungo := da.distance_to(a)
	if lungo < 0.6:
		return
	var mezzo := (da + a) * 0.5
	var verso := (a - da).normalized()
	Muratura.decoro(self, Vector3(mezzo.x, quota + 0.03, mezzo.y),
			Vector3(lungo, 0.06, 0.18), tinta, 0.55,
			Vector3(0, rad_to_deg(atan2(-verso.y, verso.x)), 0))


## Una rampa parte o arriva a quella quota, vicino a quel punto?
func _rampa_arriva(dove: Vector2, quota: float) -> bool:
	for r in _pianta["rampe"]:
		var mezza := float(r["larghezza"]) * 0.5 + 0.5
		for capo in [[r["da"], r["quota_da"]], [r["a"], r["quota_a"]]]:
			if absf(float(capo[1]) - quota) < 0.2 and _punto(capo[0]).distance_to(dove) < mezza:
				return true
	return false


## C'è un pavimento a quella quota, in quel punto della pianta? Si guarda la
## pianta, non la scena: qui la scena non è ancora costruita. E la pianta già
## ritagliata dalle rampe: dove passa una rampa, a quella quota non c'è pavimento.
func _piano_alla_quota(dove: Vector2, quota: float) -> bool:
	var zone: Array = _pianta["zone"]
	for z in zone.size():
		if absf(float(zone[z]["quota"]) - quota) > 0.2:
			continue
		for pezzo: PackedVector2Array in _pezzi[z]:
			if Geometry2D.is_point_in_polygon(dove, pezzo):
				return true
	return false


## La rete di cammino: si carica, non si cuoce.
##
## È il pezzo che permette all'avversario di **camminare** invece di girarti
## intorno: in una stanza sola bastava tenersi a distanza, qui con rampe, scala e
## ballatoio senza un percorso ci si incastra in un angolo — e un avversario
## incastrato rende impossibile giudicare se perdere contro di lui sembra giusto.
##
## Se il file non c'è, l'arena si apre lo stesso e il bot torna a fare quello che
## faceva prima: una rete che manca non deve togliere il gioco.
func _rete_di_cammino() -> void:
	if not ResourceLoader.exists(RETE):
		push_warning("la rete di cammino non c'è: %s — si gioca senza percorsi" % RETE)
		return
	var regione := NavigationRegion3D.new()
	regione.navigation_mesh = load(RETE)
	add_child(regione)


## Una sponda è un piano orientato: in piedi guarda avanti, sdraiata guarda in su
## (pavimento) o in giù (soffitto). Sdraiata si **dichiara**, non si deduce da un
## angolo di rotazione — dedurla è il modo per ritrovarsi un pavimento in verticale.
func _giro_sponda(s: Dictionary) -> Vector3:
	match String(s.get("sdraiata", "")):
		"pavimento": return Vector3(-90, 0, 0)
		"soffitto": return Vector3(90, 0, 0)
		_: return Vector3(0, float(s.get("giro", 0)), 0)


func _contorno(punti: Array) -> PackedVector2Array:
	var fuori := PackedVector2Array()
	for p in punti:
		fuori.append(Vector2(float(p[0]), float(p[1])))
	return fuori


func _punto(p: Array) -> Vector2:
	return Vector2(float(p[0]), float(p[1]))


func _tinta(nome: Variant) -> Color:
	return TINTE.get(String(nome), TINTE["moquette"])


func _aggiungi_bersaglio(dove: Vector3, colore: Color) -> Bersaglio:
	var bersaglio := Bersaglio.crea(self, dove, dove, 0.0, colore)
	bersaglio.centrato.connect(_su_bersaglio_centrato)
	_bersagli.append(bersaglio)
	return bersaglio


# ------------------------------------------------------------------ luce

## **Il pubblico.** Le gradinate erano due blocchi vuoti, ed erano la cosa che più
## faceva sembrare l'arena un cantiere: un posto dove si gioca una partita ha
## qualcuno che guarda.
##
## Un disegno solo, ripetuto: `MultiMesh` è **una passata sola** per la scheda
## video, quante che siano le figure — ottanta capsule messe una per una sarebbero
## ottanta passate, e su un telefono si sentirebbero. Nessuna collisione, nessuna
## animazione: il pubblico riempie, non gioca.
##
## Dove stanno lo dice **la pianta**, non questo file: si prendono i muri che si
## chiamano «gradinata» e ci si siede sopra. Sposta la gradinata nel `.json` e il
## pubblico la segue.
func _pubblico() -> void:
	# Il cordolo sul bordo che dà sul campo. Senza, la folla sembra sospesa sul
	# niente: la gradinata è un blocco scuro e il suo piano non si legge — è la
	# lezione della passerella nord (`LEARNED.md` § 31), applicata a un piano su cui
	# non si cammina ma si guarda.
	for muro in _pianta["muri"]:
		if not String(muro.get("nome", "")).contains("gradinata"):
			continue
		var centro := _punto(muro["centro"])
		var misura := _punto(muro["misura"])
		var piano := float(muro["quota"]) + float(muro["alto"])
		Muratura.decoro(self, Vector3(centro.x + misura.x * 0.5, piano + 0.03, centro.y),
				Vector3(misura.y, 0.06, 0.18), Color(0.78, 0.72, 0.95), 0.55,
				Vector3(0, 90, 0))
	# Le persone (tappa 8, blocco E): dal 03/10/2026 non più capsule ma gente vera,
	# sedute o che esultano, sui loro gradini (`Pubblico`).
	Pubblico.costruisci(self, _pianta)


## Quante figure ci sono. Serve al collaudo: una tribuna vuota si vede solo
## guardandola, e un errore nella pianta la svuoterebbe in silenzio.
func quanto_pubblico() -> int:
	return Pubblico.quante(get_node_or_null("pubblico"))


func _ambiente() -> void:
	var mondo := WorldEnvironment.new()
	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color(0.04, 0.04, 0.09)
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color(0.46, 0.42, 0.66)
	ambiente.ambient_light_energy = 0.85
	ambiente.tonemap_mode = Environment.TONE_MAPPER_ACES
	ambiente.glow_enabled = true
	ambiente.glow_intensity = 1.1
	ambiente.glow_bloom = 0.12
	# Sopra questa soglia ci va **solo il dardo**: è la regola che tiene insieme
	# «arena satura» e «dardo sempre leggibile».
	ambiente.glow_hdr_threshold = 1.0
	mondo.environment = ambiente
	add_child(mondo)


## La luce di un posto coperto: **la fa il soffitto**.
##
## Col tetto chiuso il sole non entra piu' — nell'angolo entrava, perche' era un
## angolo. Quindi la luce viene da dove viene in una palestra vera: dai lucernari.
## Una lampada per lucernario, nessuna con le ombre (il primo dei quattro rimedi
## di prestazione del piano), piu' una direzionale debole senza ombre che tiene
## il volume: senza, le facce orientate diversamente prendono tutte la stessa
## luce e l'arena diventa un disegno piatto.
func _luci() -> void:
	var riempimento := DirectionalLight3D.new()
	riempimento.rotation_degrees = Vector3(-58.0, -34.0, 0.0)
	riempimento.light_energy = 0.55
	riempimento.light_color = Color(0.86, 0.80, 1.0)
	riempimento.shadow_enabled = false
	add_child(riempimento)

	for l in _pianta["lucernari"]:
		var alto := float(l["quota"])
		# Sotto il lucernario, non dentro: una lampada annegata nel soffitto
		# illumina il soffitto.
		_lampada(Vector3(float(l["dove"][0]), alto - 1.2, float(l["dove"][1])),
				Color(0.80, 0.74, 1.0), 4.6, alto + 14.0).add_to_group(GRUPPO_LUCERNARI)

	# Le tre lampade di colore: sono quelle che danno un'aria a ogni zona, ed e'
	# cosi' che un'ala si riconosce da lontano prima di leggerne l'insegna.
	_lampada(Vector3(0, 5.0, -22), Color(0.98, 0.78, 0.42), 3.4, 26.0)
	_lampada(Vector3(26, 4.2, 0), Color(1.0, 0.52, 0.46), 3.2, 24.0)
	# Viola, il colore del neon: non ambra (una lampada arancione tingerebbe le
	# pareti del colore del dardo) e non piu' lime, che dalla tappa 4 e' il colore
	# riservato al contorno degli avversari (decisione 15).
	_lampada(Vector3(-24, 4.0, -24), Vestizione.NEON, 2.6, 22.0)


func _lampada(dove: Vector3, colore: Color, forza: float, portata: float) -> OmniLight3D:
	var luce := OmniLight3D.new()
	luce.position = dove
	luce.light_color = colore
	luce.light_energy = forza
	luce.omni_range = portata
	luce.shadow_enabled = false
	add_child(luce)
	return luce


# ------------------------------------------------------------------ comandi

## Le sei partenze, girate col pollice: servono a giocare e servono a controllare
## che nessuna guardi in faccia un'altra.
func passa_alla_partenza_seguente() -> void:
	_mettiti_alla_partenza((_partenza + 1) % int(_pianta["partenze"].size()))
	_comandi.annuncia(String(_pianta["partenze"][_partenza]["nome"]).to_upper())


func _mettiti_alla_partenza(quale: int) -> void:
	_partenza = quale
	var p: Dictionary = _pianta["partenze"][quale]
	_giocatore.global_position = _dove_partenza(quale)
	_giocatore.velocity = Vector3.ZERO
	_giocatore.punta(float(p["giro"]), -4.0)


## Dove si nasce: il piede della partenza, quaranta centimetri sopra il pavimento
## dichiarato, così nessuno compare mezzo dentro la moquette.
func _dove_partenza(quale: int) -> Vector3:
	var p: Dictionary = _pianta["partenze"][quale]
	return Vector3(float(p["dove"][0]), float(p["quota"]) + 0.4, float(p["dove"][1]))


func partenza() -> int:
	return _partenza


func pianta() -> Dictionary:
	return _pianta


func giocatore() -> Giocatore:
	return _giocatore


func nome_colore() -> String:
	return String(CANDIDATI[_candidato]["nome"])


func passa_al_colore_seguente() -> void:
	_cambia_colore()


func solo_sponde() -> bool:
	return _solo_sponde


func commuta_sponde() -> void:
	_solo_sponde = not _solo_sponde
	_applica_regola()
	_comandi.annuncia("SOLO LE SPONDE" if _solo_sponde else "RIMBALZA TUTTO")


func torna_al_poligono() -> void:
	get_tree().change_scene_to_file("res://scenes/poligono.tscn")


## Il dardo a 19 o a 24 m/s, per tutti: anche gli avversari sparano e schivano
## con la velocità del momento, così il confronto è alla pari.
func commuta_dardo() -> void:
	if is_equal_approx(Proiettile.velocita, Proiettile.VELOCITA_BASE):
		Proiettile.velocita = Proiettile.VELOCITA_VELOCE
	else:
		Proiettile.velocita = Proiettile.VELOCITA_BASE
	_scrivi_il_dardo()
	_comandi.annuncia("DARDO %d m/s" % int(round(Proiettile.velocita)))


func velocita_del_dardo() -> float:
	return Proiettile.velocita


func _scrivi_il_dardo() -> void:
	if _bottone_dardo != null:
		_bottone_dardo.text = "DARDO %d" % int(round(Proiettile.velocita))


func _process(delta: float) -> void:
	_aggiorna_righe()
	_respiro_degli_anelli(delta)
	_prossimo_tabellone -= delta
	if _prossimo_tabellone <= 0.0:
		_prossimo_tabellone = 0.25
		_scrivi_il_tabellone()
	if _sfida and not _finita:
		# I corpi entrano anche durante il conto alla rovescia: i tre secondi del
		# fischio d'inizio servono anche a questo.
		if not _in_arrivo.is_empty():
			_fai_entrare_il_prossimo()
		elif _conto > 0.0:
			_scorre_il_conto(delta)
		else:
			_scegli_i_bersagli(delta)
			_scorre_il_tempo(delta)
			_guarda_la_classifica(delta)
	if _modo_partita and _sfida:
		_comandi.modalita_partita(tempo_scritto(), maxi(posizione_mia(), 1), punteggi()[0])
	_segui_i_potenziamenti()
	for tasto in SCORCIATOIE:
		var giu := Input.is_physical_key_pressed(tasto)
		if giu and not bool(_tasti.get(tasto, false)):
			match String(SCORCIATOIE[tasto]):
				"colore": _cambia_colore()
				"sponde": commuta_sponde()
				"poligono": torna_al_poligono()
				"partenza": passa_alla_partenza_seguente()
				"sfida": commuta_sfida()
				"livello": cambia_livello()
				"dardo": commuta_dardo()
		_tasti[tasto] = giu


## **Dove stanno le palle colorate**: sei, una per tipo (tappa 11, blocco B). Ognuna
## dove passano più strade nella sua ala — misurato coi 276 percorsi della rete di
## cammino fra tutti i punti di rinascita — a più di 6 m da partenze e rinascite, mai su
## una rampa (`ricerca-grezza/stato-2026-10-05/sfere-sei.png`, approvata da Ludovico il
## 05/10/2026). Ballatoio e terrazza nord-est sono i posti della tappa 8; chi va dove è
## scelta mia: i punti doppi nel posto più scomodo, il radar in alto, il fulmine al
## centro dove sono tutti, il turbo nel corridoio lungo.
const POTENZIAMENTI := [
	{"tipo": "doppio", "dove": Vector3(6.0, 7.0, 21.5)},
	{"tipo": "radar", "dove": Vector3(27.0, 3.5, -27.0)},
	{"tipo": "fulmine", "dove": Vector3(9.0, -2.0, 0.0)},
	{"tipo": "turbo", "dove": Vector3(23.0, 0.0, 11.0)},
	{"tipo": "fantasma", "dove": Vector3(-21.0, 0.0, 4.0)},
	{"tipo": "ladro", "dove": Vector3(-3.0, 0.0, -21.0)},
]

## Quando un avversario prende una palla si annuncia solo se ti tocca da vicino: i
## punti doppi e il ladro pesano sui tuoi punti, il fulmine ti rallenta. Fantasma e
## radar restano zitti: sono armi di nascosto.
const ANNUNCI_ALTRUI := {"doppio": "%s HA I PUNTI DOPPI", "fulmine": "%s HA IL FULMINE",
	"ladro": "%s HA IL LADRO"}


## Chi può raccogliere una palla colorata: tutti i corpi in campo durante la partita.
func _corpi_in_campo() -> Array:
	var fuori := []
	if not _sfida or _finita or _conto > 0.0:
		return fuori
	for riga in _concorrenti:
		var corpo: Node3D = riga["corpo"]
		if corpo != null and is_instance_valid(corpo):
			fuori.append(corpo)
	return fuori


func _su_potenziamento_preso(chi: Node3D, tipo: String) -> void:
	var dati: Dictionary = Potenziamenti.TIPI[tipo]
	if tipo == "fantasma":
		# Chi ti stava puntando ti perde adesso, non alla prossima riscelta.
		for bot in avversari():
			if bot.bersaglio == chi:
				bot.punta_a(_chi_attaccare(bot))
	if chi == _giocatore:
		_comandi.annuncia(String(dati["nome"]) + "!")
		Suoni.potenziamento(true)
	else:
		Suoni.potenziamento(false)
		var riga := _riga_di(chi)
		if riga >= 0 and ANNUNCI_ALTRUI.has(tipo):
			_comandi.annuncia(String(ANNUNCI_ALTRUI[tipo]) % String(_concorrenti[riga]["nome"]))


func _su_potenziamento_finito(chi: Node3D, _tipo: String) -> void:
	if chi == _giocatore:
		Suoni.potenziamento_finito()


## Quello che dei tuoi potenziamenti vale per te: i punti doppi nell'etichetta del colpo
## e, col RADAR, le sagome di tutti gli avversari attraverso i muri. Si guarda a ogni
## fotogramma cosa hai, invece di accendere e spegnere: così a partita chiusa o rifatta
## a metà non resta acceso niente (fino al 05/10/2026 i punti doppi restavano, se si
## chiudeva la partita prima che scadessero).
func _segui_i_potenziamenti() -> void:
	if _potenziamenti == null or _giocatore == null or _comandi == null:
		return
	_giocatore.moltiplicatore_punti = 2 if _potenziamenti.ha(_giocatore, "doppio") else 1
	var radar := _sfida and not _finita and _potenziamenti.ha(_giocatore, "radar")
	if radar != _radar_acceso:
		_radar_acceso = radar
		for bot in avversari():
			if bot.corpo() != null:
				bot.corpo().radar(radar, Potenziamenti.TIPI["radar"]["colore"])
	# Le pillole sotto il cronometro: tutti quelli che hai, con quanto ti resta.
	var voci: Array = []
	for tipo in Potenziamenti.TIPI:
		var resto := _potenziamenti.resto(_giocatore, tipo)
		if resto > 0.0:
			var dati: Dictionary = Potenziamenti.TIPI[tipo]
			voci.append({"testo": "%s · %d" % [String(dati["nome"]), int(ceil(resto))],
					"colore": dati["colore"]})
	_comandi.potenziamenti(voci)


## Il tabellone sopra il catino: durante la partita il tempo e chi comanda, a
## partita finita chi ha vinto, fuori dalla partita il nome del gioco.
func _scrivi_il_tabellone() -> void:
	if _tabellone == null:
		return
	if not _sfida:
		Vestizione.aggiorna_tabellone(_tabellone, "PENTAWALL", "5 MURI")
		return
	var righe := classifica()
	var capo := "" if righe.is_empty() else "1° %s · %d" % [String(righe[0]["nome"]),
			int(righe[0]["punti"])]
	if _finita:
		Vestizione.aggiorna_tabellone(_tabellone, "FINE",
				"" if righe.is_empty() else "VINCE %s" % String(righe[0]["nome"]))
	else:
		Vestizione.aggiorna_tabellone(_tabellone, tempo_scritto(), capo)


# ------------------------------------------------------------- il cronometro

## **Il fischio d'inizio.** Tre numeri e un via, uno al secondo, con il bip. Chi
## gioca può girarsi e guardare dov'è finito, ma nessuno spara sul serio: prima
## del via i colpi non fanno punti e gli avversari non hanno un bersaglio.
func _scorre_il_conto(delta: float) -> void:
	var prima := int(ceil(_conto))
	_conto -= delta
	var adesso := int(ceil(_conto))
	if adesso != prima and adesso > 0:
		_comandi.fischio("%d" % adesso)
		Suoni.conto(adesso)
	if _conto <= 0.0:
		_conto = 0.0
		_via()


func _via() -> void:
	_comandi.fischio("VIA")
	Suoni.via()
	_prossima_riscelta = RISCELTA
	_turno_riscelta = 0
	for bot in avversari():
		bot.punta_a(_chi_attaccare(bot))


## Il tempo che scende. Finito, finisce la partita: è l'unico modo in cui una
## partita dell'arena può finire, dalla decisione 19.
func _scorre_il_tempo(delta: float) -> void:
	_tempo = maxf(_tempo - delta, 0.0)
	if _avvisi_dati < AVVISI_TEMPO.size() 			and _tempo <= float(AVVISI_TEMPO[_avvisi_dati]["quando"]):
		_comandi.annuncia(String(AVVISI_TEMPO[_avvisi_dati]["cosa"]))
		# L'ultimo minuto si sente: l'annunciatore, e la musica che cambia passo.
		if _avvisi_dati == 0:
			Suoni.ultimo_minuto()
		_avvisi_dati += 1
	if _tempo <= 0.0:
		_finisci_la_partita()


## Il cronometro come si legge: minuti e secondi. Durante il conto alla rovescia
## segna la durata piena — la partita non è ancora cominciata.
func tempo_scritto() -> String:
	var quanto := int(ceil(_durata if _conto > 0.0 else _tempo))
	return "%d:%02d" % [quanto / 60, quanto % 60]


func tempo_rimasto() -> float:
	return _tempo


func conto_alla_rovescia() -> float:
	return _conto


## Quanto dura una partita. I collaudi la abbassano: aspettare tre minuti veri
## per sapere se il cronometro chiude non dimostra niente di più.
func imposta_durata(secondi: float) -> void:
	_durata = maxf(secondi, 1.0)


## «SEI PRIMO» e «TI HANNO SUPERATO»: gli annunci che tengono dentro. Uno ogni
## tre secondi al massimo, o in mischia diventano una mitragliata.
func _guarda_la_classifica(delta: float) -> void:
	_attesa_annuncio = maxf(_attesa_annuncio - delta, 0.0)
	var adesso := posizione_mia()
	if adesso <= 0 or adesso == _posizione_annunciata or _attesa_annuncio > 0.0:
		return
	if _posizione_annunciata > 0:
		if adesso == 1:
			_comandi.annuncia("SEI PRIMO")
		elif adesso > _posizione_annunciata:
			_comandi.annuncia("TI HANNO SUPERATO")
	_posizione_annunciata = adesso
	_attesa_annuncio = ATTESA_ANNUNCIO


# ------------------------------------------------------------------ la partita

## L'interruttore. Acceso: entrano i cinque avversari, i bersagli si fanno da
## parte e i punteggi ripartono da zero. Spento: l'arena torna il posto in cui si
## gira per guardarla.
func commuta_sfida() -> void:
	if _sfida:
		chiudi_sfida()
	else:
		avvia_sfida()


## **La partita a sei.** Uno per partenza: tu dove sei, i cinque avversari sulle
## altre cinque. Nessuno avanza e nessuno nasce addosso a un altro — è la ragione
## per cui la pianta ne ha sei, e viene dal 1999 (`RICERCA-ORIGINALE.md` § 2).
##
## Tutti contro tutti, non a squadre: le squadre nell'originale esistevano solo
## nei menù di rete, e la carriera non le usava mai. Qui vuol dire che **anche i
## colpi fra avversari valgono punti**, e senza quello gli altri quattro sarebbero
## arredamento intorno al duello di sempre.
func avvia_sfida() -> void:
	_sfida = true
	_finita = false
	_tempo = _durata
	_conto = CONTO_INIZIALE
	_avvisi_dati = 0
	_posizione_annunciata = 0
	_attesa_annuncio = 0.0
	_comandi.spegni_il_podio()
	# I posti dove si va a cercare chi non si trova: le sei partenze.
	var ronda: Array[Vector3] = []
	for i in int(_pianta["partenze"].size()):
		ronda.append(_dove_partenza(i))
	Avversario.punti_di_ronda = ronda
	for bersaglio in _bersagli:
		bersaglio.metti_in_pausa(true)

	_svuota_il_campo()
	_mettiti_alla_partenza(_partenza)
	_potenziamenti.riparti()
	_concorrenti.append({"nome": "TU", "corpo": _giocatore, "punti": 0})

	# **Entrano uno per fotogramma.** Costruire un corpo — mesh, materiali, i due
	# gusci del contorno — costa tredici millesimi di secondo, e cinque tutti
	# insieme facevano un fotogramma da sessantatré: un inciampo netto proprio nel
	# momento in cui si preme SFIDA (misurato il 27/08/2026). Distribuiti, nessun
	# fotogramma supera i venti, e in un decimo di secondo ci sono tutti.
	var quante := int(_pianta["partenze"].size())
	var quanti := mini(NOMI.size(), quante - 1)
	_in_arrivo.clear()
	for i in quanti:
		_concorrenti.append({"nome": String(NOMI[i]), "corpo": null, "punti": 0})
		_in_arrivo.append({"riga": _concorrenti.size() - 1,
				"partenza": (_partenza + 1 + i) % quante})
	# Nemmeno il primo nasce adesso: il fotogramma in cui si preme il pulsante ha
	# già da fare — i bersagli che si fanno da parte, il giocatore che va alla
	# partenza, la classifica che si accende — e sommarci un corpo lo portava a
	# quarantacinque millesimi. Il primo entra al fotogramma dopo, e la partita
	# comincia lo stesso: nessuno spara nei primi otto centesimi di secondo.

	_prossima_riscelta = RISCELTA
	_turno_riscelta = 0
	_comandi.fischio("%d" % int(ceil(_conto)))
	Suoni.conto(int(ceil(_conto)))
	# La partita ha la sua musica e il suo pubblico: si accendono col fischio.
	Suoni.musica("musica_partita")
	Suoni.folla(true)
	_sonda.parti()
	_aggiorna_la_classifica()
	_comandi.scrivi_sfida("CHIUDI")
	if not _modo_partita:
		_comandi.annuncia("PARTITA · %s"
				% String(Avversario.TARATURE[_livello]["nome"]).to_upper())


## Uno solo per fotogramma, finché la coda non è vuota. Il bersaglio se lo
## sceglie appena entrato: chi arriva per ultimo trova gli altri già in campo, e
## chi era già dentro lo aggiusta al suo turno di riscelta.
func _fai_entrare_il_prossimo() -> void:
	if _in_arrivo.is_empty():
		return
	var chi: Dictionary = _in_arrivo.pop_front()
	# Il nome è anche la faccia: ogni concorrente ha il suo corpo (`Corpo.PERSONAGGI`).
	var bot := Avversario.crea(self, _dove_partenza(int(chi["partenza"])), _livello,
			String(_concorrenti[int(chi["riga"])]["nome"]))
	# **Cerca, non sa** (blocco C): nella partita a sei l'avversario ti vede, ti
	# ricorda o ti cerca. Nel poligono e nell'angolo resta lo sparring partner
	# che ti sta addosso, che è quello che serve là.
	bot.caccia = true
	bot.preso_da.connect(_su_colpo_valido.bind(bot))
	_concorrenti[int(chi["riga"])]["corpo"] = bot
	# Prima del via non attacca nessuno: entra, si guarda intorno e aspetta.
	if _conto <= 0.0:
		bot.punta_a(_chi_attaccare(bot))
	_aggiorna_la_classifica()


func chiudi_sfida() -> void:
	_sonda.fermati("chiusa")
	Suoni.ferma_la_musica()
	Suoni.folla(false)
	_sfida = false
	_finita = false
	_in_arrivo.clear()
	_svuota_il_campo()
	for bersaglio in _bersagli:
		bersaglio.metti_in_pausa(false)
	_comandi.spegni_la_classifica()
	_comandi.spegni_il_podio()
	_comandi.scrivi_sfida("SFIDA")
	_comandi.annuncia("ARENA")


## Manda via chi è in campo. Il bersaglio si toglie **prima** di liberare il
## corpo: un avversario che se ne va mentre gli altri lo stanno inseguendo
## lascerebbe in giro riferimenti a un nodo che non c'è più.
func _svuota_il_campo() -> void:
	for riga in _concorrenti:
		var corpo: Node3D = riga["corpo"]
		if corpo is Avversario and is_instance_valid(corpo):
			(corpo as Avversario).bersaglio = null
			corpo.queue_free()
	_concorrenti.clear()


## Il livello si cambia dentro la partita: i tre si confrontano col pollice nello
## stesso posto, non leggendo una tabella. Vale per tutti e cinque insieme —
## avversari di livelli diversi nella stessa partita non direbbero niente su
## nessuno dei tre.
func cambia_livello() -> void:
	_livello = (_livello + 1) % Avversario.TARATURE.size()
	for bot in avversari():
		bot.imposta_livello(_livello)
	_comandi.annuncia(String(Avversario.TARATURE[_livello]["nome"]).to_upper())


func in_sfida() -> bool:
	return _sfida


## Il primo degli avversari. Resta per chi ne guarda **uno** — i collaudi della
## tappa 2 e gli attrezzi degli scatti, che di corpi ne vogliono uno solo.
func avversario() -> Avversario:
	for bot in avversari():
		return bot
	return null


## Tutti gli avversari vivi, in ordine di entrata.
func avversari() -> Array[Avversario]:
	var elenco: Array[Avversario] = []
	for riga in _concorrenti:
		var corpo: Node3D = riga["corpo"]
		if corpo is Avversario and is_instance_valid(corpo):
			elenco.append(corpo as Avversario)
	return elenco


## I tuoi punti e quelli del migliore fra gli avversari. Serve a chi vuole sapere
## come sta andando senza leggere tutta la classifica.
func punteggi() -> Array:
	var miei := 0
	var loro := 0
	for riga in _concorrenti:
		var punti := int(riga["punti"])
		if riga["corpo"] == _giocatore:
			miei = punti
		else:
			loro = maxi(loro, punti)
	return [miei, loro]


## La classifica: `{"nome", "punti", "tu"}`, dal primo all'ultimo. A pari punti
## resta avanti chi è entrato prima, che è l'ordine delle partenze: senza una
## seconda chiave l'ordinamento potrebbe cambiare da solo fra un fotogramma e
## l'altro, e la classifica ballerebbe senza motivo.
func classifica() -> Array:
	var righe: Array = []
	for i in _concorrenti.size():
		var riga: Dictionary = _concorrenti[i]
		righe.append({
			"nome": String(riga["nome"]),
			"punti": int(riga["punti"]),
			"tu": riga["corpo"] == _giocatore,
			"ordine": i,
		})
	righe.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["punti"]) != int(b["punti"]):
			return int(a["punti"]) > int(b["punti"])
		return int(a["ordine"]) < int(b["ordine"]))
	for i in righe.size():
		righe[i]["posizione"] = i + 1
	return righe


## Quella che si vede in partita: **le prime tre e la tua**. Tutte e sei stanno
## in centonovanta punti d'altezza, e sul telefono in orizzontale lo schermo ne ha
## trecentonovanta: la classifica arriverebbe in mezzo al pollice sinistro.
## A partita finita si mostrano tutte — l'ordine d'arrivo è la cosa per cui si è
## giocato, e il pollice a quel punto non serve più.
func classifica_da_mostrare() -> Array:
	var righe := classifica()
	if _finita or righe.size() <= PODIO + 1:
		return righe
	var corte := righe.slice(0, PODIO)
	for riga in righe:
		if bool(riga["tu"]) and int(riga["posizione"]) > PODIO:
			corte.append(riga)
	return corte


## In che posizione stai. È il numero che in partita si guarda per primo.
func posizione_mia() -> int:
	var righe := classifica()
	for i in righe.size():
		if bool(righe[i]["tu"]):
			return i + 1
	return 0


func _aggiorna_la_classifica() -> void:
	if _comandi != null:
		_comandi.classifica(classifica_da_mostrare())


# ------------------------------------------------------------- chi attacca chi

## **A turno, uno per volta.** Ogni avversario si guarda intorno ogni sei decimi
## di secondo, ma non tutti nello stesso fotogramma: il turno gira, e in un
## fotogramma si paga un giro di raggi solo, non cinque.
func _scegli_i_bersagli(delta: float) -> void:
	if not _in_arrivo.is_empty():
		_fai_entrare_il_prossimo()
		return
	var quanti := _concorrenti.size() - 1
	if quanti <= 0:
		return
	_prossima_riscelta -= delta
	if _prossima_riscelta > 0.0:
		return
	_prossima_riscelta = RISCELTA / float(quanti)
	_turno_riscelta = (_turno_riscelta + 1) % quanti
	var corpo: Node3D = _concorrenti[_turno_riscelta + 1]["corpo"]
	if corpo is Avversario and is_instance_valid(corpo):
		var bot := corpo as Avversario
		bot.punta_a(_chi_attaccare(bot))


## Chi attaccare: **il più vicino che si vede**, e in mancanza di meglio il più
## vicino e basta — perché la rete di cammino sa portarcelo, e un avversario senza
## nessuno da cercare resterebbe fermo.
##
## Si controllano col raggio solo i tre più vicini: il quarto, in un'arena da
## sessantasei metri, è dall'altra parte comunque.
##
## I potenziamenti (tappa 11, blocco B): **il FANTASMA non lo sceglie nessuno**, e chi
## ha **il RADAR** sa dove sono tutti — prende il più vicino, che lo veda o no.
func _chi_attaccare(bot: Avversario) -> Node3D:
	var altri: Array = []
	for riga in _concorrenti:
		var corpo: Node3D = riga["corpo"]
		if corpo == null or corpo == bot or not is_instance_valid(corpo):
			continue
		if _potenziamenti.ha(corpo, "fantasma"):
			continue
		altri.append({"corpo": corpo,
				"quanto": bot.global_position.distance_to(corpo.global_position)})
	if altri.is_empty():
		return null
	altri.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["quanto"]) < float(b["quanto"]))
	if _potenziamenti.ha(bot, "radar"):
		return altri[0]["corpo"] as Node3D

	var scelto: Node3D = null
	var quanto_scelto := 0.0
	for i in mini(CANDIDATI_VISTA, altri.size()):
		var corpo: Node3D = altri[i]["corpo"]
		if _si_vedono(bot, corpo):
			scelto = corpo
			quanto_scelto = float(altri[i]["quanto"])
			break
	if scelto == null:
		return altri[0]["corpo"] as Node3D

	# Chi ce l'ha già davanti se lo tiene, se non è molto più lontano di quello
	# nuovo: cambiare preda per mezzo metro vuol dire non attaccarne mai nessuno.
	var attuale := bot.bersaglio
	if attuale != null and is_instance_valid(attuale) and attuale != scelto \
			and not _potenziamenti.ha(attuale, "fantasma"):
		var quanto := bot.global_position.distance_to(attuale.global_position)
		if quanto <= quanto_scelto * AFFEZIONE and _si_vedono(bot, attuale):
			return attuale
	return scelto


## Due corpi si vedono? Lo stesso raggio con cui l'avversario decide se ha la
## linea libera per sparare: i combattenti stanno su un altro strato, quindi non
## si fanno ombra a vicenda.
func _si_vedono(uno: Node3D, altro: Node3D) -> bool:
	var da := uno.global_position + Vector3(0, Avversario.ALTEZZA_PETTO, 0)
	var a := altro.global_position + Vector3(0, Avversario.ALTEZZA_PETTO, 0)
	var domanda := PhysicsRayQueryParameters3D.create(da, a, Strati.SOLIDO)
	return get_world_3d().direct_space_state.intersect_ray(domanda).is_empty()


# ------------------------------------------------------------------------ i punti

## **Scaduto il tempo.** Il campo si ferma, la classifica si apre tutta e sopra
## arriva il podio con RIGIOCA: è il momento per cui esiste la tappa 7, perché è
## lì che si vede se una partita ne chiama un'altra.
func _finisci_la_partita() -> void:
	if _finita:
		return
	_finita = true
	_tempo = 0.0
	_sonda.fermati("traguardo")
	_potenziamenti.riparti()
	for bot in avversari():
		bot.bersaglio = null
	_aggiorna_la_classifica()
	_comandi.scrivi_sfida("ANCORA")
	var righe := classifica()
	var mia := posizione_mia()
	if mia == 1:
		_comandi.annuncia("HAI VINTO")
	else:
		_comandi.annuncia("VINCE %s" % String(righe[0]["nome"]))
	_comandi.podio(righe, maxi(mia, 1))
	Suoni.fine_partita(mia == 1)
	Suoni.folla(false)


## Un'altra partita, a un tocco: stesso posto, punti e tempo da zero. È la
## domanda della tappa fatta col pollice invece che a parole.
func rigioca() -> void:
	_comandi.spegni_il_podio()
	avvia_sfida()


## Si esce dalla partita e si torna all'ingresso, da dove si può rientrare.
func torna_all_ingresso() -> void:
	modo_partita = false
	get_tree().change_scene_to_file("res://scenes/ingresso.tscn")


## **L'unico posto da cui passano i punti.** Ogni corpo che si può colpire dice
## chi l'ha preso e quanto vale; qui si accredita a chi ha sparato, si annuncia se
## la cosa ti riguarda, e si fa ricomparire chi ha incassato.
##
## Nel duello bastava sapere che qualcuno era stato colpito, perché chi sparava
## era per forza l'altro. In sei no: senza il nome di chi ha sparato, un colpo fra
## avversari finirebbe nel tuo punteggio.
func _su_colpo_valido(chi_spara: Object, punti: int, muri: int, chi_incassa: Node3D) -> void:
	# Prima del via i colpi non contano: si entra in campo tutti insieme.
	if not _sfida or _finita or _conto > 0.0:
		return
	var autore := _riga_di(chi_spara)
	# I punti doppi di chi spara (tappa 8, blocco H).
	if _potenziamenti != null and _potenziamenti.ha(chi_spara, "doppio"):
		punti *= 2
	# Il LADRO di chi spara (tappa 11, blocco B): chi incassa perde i punti che il colpo
	# dà a chi spara, mai sotto zero.
	var rubati := 0
	var vittima := _riga_di(chi_incassa)
	if autore >= 0 and vittima >= 0 and _potenziamenti.ha(chi_spara, "ladro"):
		rubati = mini(punti, int(_concorrenti[vittima]["punti"]))
		_concorrenti[vittima]["punti"] = int(_concorrenti[vittima]["punti"]) - rubati
	if autore >= 0:
		_concorrenti[autore]["punti"] = int(_concorrenti[autore]["punti"]) + punti
		if chi_spara == _giocatore:
			# In partita il colpo si vede già dove succede — l'etichetta che sale
			# dal punto d'impatto, blocco B — e l'annuncio grande al centro serve
			# alla gara: «SEI PRIMO», l'ultimo minuto.
			if not _modo_partita:
				_comandi.annuncia(Comandi.annuncio_del_colpo(punti, muri))
		elif chi_incassa == _giocatore and rubati > 0:
			_comandi.annuncia("%s TI HA RUBATO %d" % [String(_concorrenti[autore]["nome"]), rubati])
		elif chi_incassa == _giocatore:
			_comandi.annuncia("COLPITO DA %s" % String(_concorrenti[autore]["nome"]))
		else:
			# Un colpo fra due avversari: si sente da dove succede, sordo. È il
			# rumore di una partita che va avanti anche dove non guardi.
			Suoni.colpo_nel_mondo(chi_incassa.global_position)
	elif chi_incassa == _giocatore:
		_comandi.annuncia("COLPITO")
	_aggiorna_la_classifica()
	_ricompari.call_deferred(chi_incassa, chi_spara)


## In che riga della partita sta un corpo. Sei righe: cercarle una per una costa
## meno che tenere in piedi un secondo elenco da mantenere allineato.
func _riga_di(corpo: Object) -> int:
	# Senza questa riga, un colpo senza padrone troverebbe la prima riga con il
	# corpo ancora da nascere e gli accrediterebbe i punti.
	if corpo == null:
		return -1
	for i in _concorrenti.size():
		if _concorrenti[i]["corpo"] == corpo:
			return i
	return -1


## **La ricomparsa.** Nel nostro gioco un colpo non toglie la vita — dà venticinque
## punti a chi lo tira, cinquanta se di sponda — ma **sposta**: chi è stato
## centrato ricompare da un'altra parte dell'arena.
##
## È una regola nostra, del 26/08/2026, e discende dal 1999 in un punto solo: là
## chi veniva eliminato riappariva subito e mai vicino a chi lo aveva preso
## (`RICERCA-ORIGINALE.md` § 2). Senza, in un posto da sessantasei metri la partita
## si deciderebbe nei primi trenta secondi dentro un angolo: chi trova per primo
## l'altro lo tiene sotto tiro fino a 500, e le altre cinque partenze non servono a
## niente. Con la ricomparsa la caccia ricomincia a ogni colpo, e l'arena serve
## tutta.
func _ricompari(chi: Node3D, _da: Object) -> void:
	if not _sfida or _finita or chi == null or not is_instance_valid(chi):
		return
	var posto := _dove_ricomparire(chi)
	var dove: Vector3 = posto["dove"]
	# Chi sparisce lascia uno sbuffo, e dove riappare sale una colonna di luce nel
	# suo colore (tappa 8, blocco G): senza, chi ricompare dall'altra parte
	# dell'arena compare e basta, e non si capisce che cosa è successo.
	Scintille.spento(chi.global_position + Vector3(0, 1.0, 0), Vector3.UP)
	var riga := _riga_di(chi)
	var colore := Corpo.colore_di(String(_concorrenti[riga]["nome"]) if riga >= 0 else "TU")
	if chi == _giocatore:
		_giocatore.global_position = dove
		_giocatore.velocity = Vector3.ZERO
		var giro: float = posto["giro"]
		_giocatore.punta(_verso_libero(dove) if is_nan(giro) else giro, -4.0)
		Suoni.ricomparsa()
	elif chi is Avversario:
		(chi as Avversario).global_position = dove
		(chi as Avversario).velocity = Vector3.ZERO
		(chi as Avversario).ricomincia_il_cammino()
	if chi.has_method("proteggi"):
		chi.call("proteggi", PROTEZIONE)
	Scintille.ricomparsa(dove - Vector3(0, 0.4, 0), colore)


## Dove ricomparire: lontano da **tutti** e fuori dalla vista di **tutti**, non solo
## di chi ti ha appena preso. Il criterio è quello del 1999: fra i candidati il gioco
## penalizzava pesantemente quelli vicini o in linea di vista di un giocatore vivo
## (`RICERCA-ORIGINALE.md` § 2). Si guardano i posti dal più lontano dal concorrente
## più vicino (col tetto `LONTANO_ABBASTANZA` e due metri di caso, per non rinascere
## sempre nello stesso angolo), e il primo che nessuno vede è quello giusto: dopo di
## lui nessuno può batterlo. Se tutti sono in vista di qualcuno, vince quello visto
## da meno concorrenti.
func _dove_ricomparire(chi_torna: Node3D) -> Dictionary:
	var altri: Array[Node3D] = []
	for riga in _concorrenti:
		var altro: Node3D = riga["corpo"]
		if altro != null and altro != chi_torna and is_instance_valid(altro):
			altri.append(altro)
	var posti := []
	for r in _rinascite:
		var dove: Vector3 = r["dove"]
		if dove.distance_to(chi_torna.global_position) < SCARTO_MINIMO:
			continue
		var vicino := LONTANO_ABBASTANZA
		for altro in altri:
			vicino = minf(vicino, dove.distance_to(altro.global_position))
		posti.append([vicino + randf() * 2.0, r])
	posti.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var migliore: Dictionary = _rinascite[0]
	var punteggio := -INF
	for posto in posti:
		var r: Dictionary = posto[1]
		var visti := 0
		for altro in altri:
			if _in_vista(r["dove"], altro):
				visti += 1
		var quanto: float = float(posto[0]) - PENALITA_IN_VISTA * float(visti)
		if quanto > punteggio:
			punteggio = quanto
			migliore = r
		if visti == 0:
			break
	return migliore


## **I posti in cui si rinasce**: le sei partenze, più i punti dei pavimenti lontani
## dai muri, dagli orli e dalle rampe, presi uno alla volta come il più lontano da
## quelli già presi — così coprono tutte le quote e tutte le ali. Si legge la pianta,
## non la scena (che qui non è ancora finita): una pianta che cambia cambia i posti da
## sola.
func _prepara_le_rinascite() -> void:
	_rinascite.clear()
	var partenze: Array = _pianta["partenze"]
	for i in partenze.size():
		_rinascite.append({"dove": _dove_partenza(i), "giro": float(partenze[i]["giro"])})
	# Muri e rampe letti una volta sola, e per ogni pavimento solo quelli alla sua
	# altezza: sul PC la prima stesura costava 50-68 ms in un fotogramma.
	var muri: Array = []
	for m in _pianta["muri"]:
		muri.append([Vector2(float(m["centro"][0]), float(m["centro"][1])),
				Vector2(float(m["misura"][0]), float(m["misura"][1])) * 0.5,
				deg_to_rad(float(m.get("giro", 0.0))), float(m["quota"]),
				float(m["quota"]) + float(m["alto"])])
	var rampe: Array = []
	for r in _pianta["rampe"]:
		rampe.append([_punto(r["da"]), _punto(r["a"]), float(r["larghezza"]) * 0.5,
				minf(float(r["quota_da"]), float(r["quota_a"])),
				maxf(float(r["quota_da"]), float(r["quota_a"]))])
	var candidati: Array[Vector3] = []
	var zone: Array = _pianta["zone"]
	for z in zone.size():
		var quota := float(zone[z]["quota"])
		# Conta un muro che sta all'altezza del corpo (quelli che reggono il pavimento
		# finiscono sotto i piedi), e una rampa che passa da quella quota.
		var muri_qui := muri.filter(func(m: Array) -> bool:
				return m[3] < quota + Giocatore.ALTEZZA_CORPO + 0.2 and m[4] > quota + 0.05)
		var rampe_qui := rampe.filter(func(r: Array) -> bool:
				return r[4] > quota - 0.5 and r[3] < quota + Giocatore.ALTEZZA_CORPO + 0.5)
		for pezzo: PackedVector2Array in _pezzi[z]:
			var minimo := pezzo[0]
			var massimo := pezzo[0]
			for p in pezzo:
				minimo = minimo.min(p)
				massimo = massimo.max(p)
			var x := minimo.x + PASSO_RINASCITE * 0.5
			while x < massimo.x:
				var y := minimo.y + PASSO_RINASCITE * 0.5
				while y < massimo.y:
					if _buon_posto_per_rinascere(Vector2(x, y), pezzo, muri_qui, rampe_qui):
						candidati.append(Vector3(x, quota + 0.4, y))
					y += PASSO_RINASCITE
				x += PASSO_RINASCITE
	var lontananza: Array[float] = []
	for c in candidati:
		var vicino := INF
		for r in _rinascite:
			vicino = minf(vicino, c.distance_to(r["dove"]))
		lontananza.append(vicino)
	while _rinascite.size() < RINASCITE and not candidati.is_empty():
		var migliore := 0
		for i in candidati.size():
			if lontananza[i] > lontananza[migliore]:
				migliore = i
		var preso := candidati[migliore]
		_rinascite.append({"dove": preso, "giro": NAN})
		candidati.remove_at(migliore)
		lontananza.remove_at(migliore)
		for i in candidati.size():
			lontananza[i] = minf(lontananza[i], candidati[i].distance_to(preso))


## `muri`: `[centro, mezze misure, giro, quota, cima]`; `rampe`: `[da, a, mezza
## larghezza, quota bassa, quota alta]` — già scelti per la quota del pavimento.
func _buon_posto_per_rinascere(punto: Vector2, pezzo: PackedVector2Array, muri: Array,
		rampe: Array) -> bool:
	if not Geometry2D.is_point_in_polygon(punto, pezzo):
		return false
	for i in pezzo.size():
		var orlo := Geometry2D.get_closest_point_to_segment(punto, pezzo[i], pezzo[(i + 1) % pezzo.size()])
		if punto.distance_to(orlo) < MARGINE_BORDO:
			return false
	for m: Array in muri:
		var locale: Vector2 = (punto - (m[0] as Vector2)).rotated(m[2])
		if (locale.abs() - (m[1] as Vector2)).max(Vector2.ZERO).length() < MARGINE_MURI:
			return false
	for r: Array in rampe:
		var asse := Geometry2D.get_closest_point_to_segment(punto, r[0], r[1])
		if punto.distance_to(asse) < float(r[2]) + MARGINE_BORDO:
			return false
	return true


## Verso dove guarda chi rinasce in un punto senza un verso suo: dove si vede più
## lontano, fra otto direzioni, all'altezza degli occhi.
func _verso_libero(dove: Vector3) -> float:
	var occhi := dove + Vector3(0, Giocatore.ALTEZZA_OCCHI - 0.4, 0)
	var spazio := get_world_3d().direct_space_state
	var migliore := Vector3.FORWARD
	var piu_lontano := -1.0
	for k in 8:
		var verso := Vector3.FORWARD.rotated(Vector3.UP, TAU * float(k) / 8.0)
		var colpo := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(occhi,
				occhi + verso * 40.0, Strati.SOLIDO))
		var quanto := 40.0 if colpo.is_empty() else occhi.distance_to(colpo["position"])
		if quanto > piu_lontano:
			piu_lontano = quanto
			migliore = verso
	return rad_to_deg(atan2(-migliore.x, -migliore.z))


## Da quel punto si vede quel corpo? Lo stesso raggio con cui l'avversario decide
## se ha la linea libera per sparare, e per lo stesso motivo.
func _in_vista(da: Vector3, chi: Node3D) -> bool:
	var occhi := da + Vector3(0, Giocatore.ALTEZZA_OCCHI - 0.4, 0)
	var petto := chi.global_position + Vector3(0, Avversario.ALTEZZA_PETTO, 0)
	var domanda := PhysicsRayQueryParameters3D.create(occhi, petto, Strati.SOLIDO)
	return get_world_3d().direct_space_state.intersect_ray(domanda).is_empty()


func _applica_regola() -> void:
	var strato := Strati.OSTACOLO if _solo_sponde else Strati.MONDO
	for muro in get_tree().get_nodes_in_group(Muratura.GRUPPO_MURI):
		if muro is CollisionObject3D:
			(muro as CollisionObject3D).collision_layer = strato
	if _bottone_sponde != null:
		_bottone_sponde.text = "SPONDE" if _solo_sponde else "TUTTO"


func _aggiorna_righe() -> void:
	if _comandi == null:
		return
	var visuale := "prima persona" if _giocatore != null and _giocatore.in_prima_persona() else "terza persona"
	if _sfida:
		# La riga alta non ripete la classifica, che sta due dita sotto: dice
		# **quanto manca**, che dalla decisione 19 è un tempo e non dei punti.
		if _finita:
			_comandi.scrivi_alto("FINITA · sei %d° su %d" %
					[posizione_mia(), _concorrenti.size()])
		else:
			_comandi.scrivi_alto("%d° · %s" % [posizione_mia(), tempo_scritto()])
		_comandi.scrivi_basso("%d avversari · %s · %s · %s · dardo %s %d m/s · %d fps" % [
			_concorrenti.size() - 1,
			Avversario.TARATURE[_livello]["nome"],
			String(_pianta["partenze"][_partenza]["nome"]), visuale,
			CANDIDATI[_candidato]["nome"], int(round(Proiettile.velocita)),
			Engine.get_frames_per_second()])
		return
	_comandi.scrivi_alto("%d punti" % _punteggio)
	var migliore := "—" if _migliore == 0 else "%d con %d muri" % [_migliore, _migliore_muri]
	_comandi.scrivi_basso("%s · %s · miglior colpo: %s · %s · dardo %s %d m/s · %d fps" % [
		"rimbalza solo sulle sponde" if _solo_sponde else "rimbalza tutto",
		String(_pianta["partenze"][_partenza]["nome"]), migliore, visuale,
		CANDIDATI[_candidato]["nome"], int(round(Proiettile.velocita)),
		Engine.get_frames_per_second()])


func _cambia_colore() -> void:
	_candidato = (_candidato + 1) % CANDIDATI.size()
	Proiettile.colore_riservato = CANDIDATI[_candidato]["colore"]
	if _giocatore != null:
		_giocatore.aggiorna_colore()
	_comandi.annuncia(String(CANDIDATI[_candidato]["nome"]).to_upper())


func _su_bersaglio_centrato(punti: int, muri: int) -> void:
	_punteggio += punti
	if punti > _migliore:
		_migliore = punti
		_migliore_muri = muri
	_comandi.annuncia(Comandi.annuncio_del_colpo(punti, muri))


func _su_nodo_nuovo(nodo: Node) -> void:
	if nodo is Proiettile:
		(nodo as Proiettile).rimbalzato.connect(_su_rimbalzo)


# ------------------------------------------------------------------ gli anelli

func _prepara_gli_anelli() -> void:
	var forma := TorusMesh.new()
	forma.inner_radius = 0.24
	forma.outer_radius = 0.34
	forma.rings = 20
	forma.ring_segments = 5
	for i in ANELLI_IN_RISERVA:
		var anello := MeshInstance3D.new()
		anello.mesh = forma
		var materiale := StandardMaterial3D.new()
		materiale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		materiale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		materiale.albedo_color = Color(NEON_SPONDA.r, NEON_SPONDA.g, NEON_SPONDA.b, 0.0)
		materiale.disable_receive_shadows = true
		anello.material_override = materiale
		anello.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		anello.visible = false
		add_child(anello)
		_anelli.append(anello)
		_vita_anelli.append(0.0)


func _su_rimbalzo(punto: Vector3, normale: Vector3, _muri: int) -> void:
	var quale := _prossimo_anello
	_prossimo_anello = (_prossimo_anello + 1) % ANELLI_IN_RISERVA
	var anello := _anelli[quale]
	_vita_anelli[quale] = VITA_ANELLO
	anello.visible = true
	anello.scale = Vector3.ONE * 0.5
	anello.rotation = Vector3.ZERO
	anello.global_position = punto + normale * 0.05
	if absf(normale.dot(Vector3.UP)) < 0.999:
		anello.look_at_from_position(anello.global_position, anello.global_position + normale,
				Vector3.UP, true)
		anello.rotate_object_local(Vector3.RIGHT, PI * 0.5)


func _respiro_degli_anelli(delta: float) -> void:
	for i in _anelli.size():
		if _vita_anelli[i] <= 0.0:
			continue
		_vita_anelli[i] -= delta
		var anello := _anelli[i]
		if _vita_anelli[i] <= 0.0:
			anello.visible = false
			continue
		var quanto := 1.0 - _vita_anelli[i] / VITA_ANELLO
		anello.scale = Vector3.ONE * (0.5 + quanto * 2.9)
		var materiale: StandardMaterial3D = anello.material_override
		materiale.albedo_color.a = 0.95 * (1.0 - quanto)
