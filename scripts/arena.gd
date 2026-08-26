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

## Si vince a 500, come al poligono. Tu fai 25 con un colpo diretto e raddoppi a
## ogni muro; lui spara solo dritto, quindi vale sempre 25: giocando dritto siete
## pari, e si vince di sponda.
const TRAGUARDO := 500

## Quanto pesa, nella scelta di dove ricomparire, l'essere in vista dell'altro:
## sessanta metri su un'arena la cui diagonale ne misura novantatré. Non azzera la
## distanza, la sovrasta — una partenza in faccia all'avversario perde sempre
## contro una coperta, per lontana che sia.
const PENALITA_IN_VISTA := 60.0

## La tavolozza della palestra, la stessa dell'angolo della tappa 3: nessuna di
## queste tinte è il bianco-arancio del dardo, e nessuna è il ciano delle sponde.
const TINTE := {
	"moquette": Color(0.24, 0.13, 0.36),
	"ocra": Color(0.66, 0.47, 0.15),
	"mattone": Color(0.58, 0.19, 0.20),
	"tribuna": Color(0.19, 0.16, 0.38),
	"soffitto": Color(0.10, 0.10, 0.21),
}

const SPONDA := Color(0.09, 0.60, 0.64)
const NEON_SPONDA := Color(0.30, 0.99, 0.95)

const CANDIDATI := [
	{"nome": "bianco-arancio", "colore": Color(1.0, 0.62, 0.24)},
	{"nome": "ciano-bianco", "colore": Color(0.35, 0.9, 1.0)},
	{"nome": "magenta-bianco", "colore": Color(1.0, 0.36, 0.78)},
]

const SCORCIATOIE := {KEY_C: "colore", KEY_S: "sponde", KEY_A: "poligono", KEY_P: "partenza",
	KEY_B: "sfida", KEY_L: "livello"}

## Gli anelli del rimbalzo, riciclati: nascerne uno a ogni impatto è quello che
## faceva scattare l'immagine sparando a raffica (LEARNED.md § 25).
const ANELLI_IN_RISERVA := 12
const VITA_ANELLO := 0.36

var _pianta: Dictionary = {}
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
var _partenza := 0
var _anelli: Array[MeshInstance3D] = []
var _vita_anelli: Array[float] = []
var _prossimo_anello := 0

var _avversario: Avversario
var _sfida := false
var _finita := false
var _livello := 1
var _punti_tu := 0
var _punti_lui := 0


func _ready() -> void:
	_pianta = carica_pianta()
	_ambiente()
	_costruisci()
	_rete_di_cammino()
	_luci()
	_prepara_gli_anelli()

	_comandi = Comandi.new()
	add_child(_comandi)
	_comandi.colore_richiesto.connect(_cambia_colore)
	_comandi.camera_richiesta.connect(func() -> void: _giocatore.cambia_camera())
	_comandi.sfida_richiesta.connect(commuta_sfida)
	_comandi.livello_richiesto.connect(cambia_livello)
	_bottone_sponde = _comandi.pulsante_di_scena("SPONDE", Color(0.2, 0.75, 0.7), commuta_sponde)
	_comandi.pulsante_di_scena("PARTENZA", Color(0.85, 0.45, 0.35), passa_alla_partenza_seguente)
	_comandi.pulsante_di_scena("POLIGONO", Color(0.35, 0.4, 0.55), torna_al_poligono)

	_giocatore = Giocatore.new()
	add_child(_giocatore)
	_giocatore.comandi = _comandi
	_giocatore.incassato.connect(_su_giocatore_incassato)
	_mettiti_alla_partenza(0)

	# Il primo colpo di una partita costava un fotogramma intero: si scalda lo
	# shader del bagliore appena la scena si apre (LEARNED.md § 26 e 27).
	Proiettile.scalda(self, _giocatore.camera())

	get_tree().node_added.connect(_su_nodo_nuovo)
	_applica_regola()
	_aggiorna_righe()


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
	for zona in _pianta["zone"]:
		Muratura.piano(self, _contorno(zona["poligono"]), float(zona["quota"]),
				SPESSORE_PIANO, _tinta(zona["tinta"]))

	for r in _pianta["rampe"]:
		Muratura.rampa(self, _punto(r["da"]), _punto(r["a"]), float(r["larghezza"]),
				float(r["quota_da"]), float(r["quota_a"]), SPESSORE_RAMPA,
				_tinta("moquette"))

	for m in _pianta["muri"]:
		var misura := Vector3(float(m["misura"][0]), float(m["alto"]), float(m["misura"][1]))
		var centro := Vector3(float(m["centro"][0]),
				float(m["quota"]) + misura.y * 0.5, float(m["centro"][1]))
		Muratura.muro(self, centro, misura, _tinta(m["tinta"]),
				Vector3(0, float(m.get("giro", 0)), 0))

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
				misura, _tinta(c["tinta"]))

	# I lucernari: nell'originale sono la cosa che dice «palestra» in mezzo
	# secondo, e costano un rettangolo acceso l'uno.
	for l in _pianta["lucernari"]:
		Muratura.decoro(self, Vector3(float(l["dove"][0]), float(l["quota"]),
				float(l["dove"][1])),
				Vector3(float(l["misura"][0]), 0.12, float(l["misura"][1])),
				Color(0.72, 0.52, 0.98), 0.72)

	for i in _pianta["insegne"]:
		Muratura.insegna(self, String(i["testo"]),
				Vector3(float(i["dove"][0]), float(i["quota"]), float(i["dove"][1])),
				Vector3(0, float(i["giro"]), 0), float(i["misura"]),
				Color(0.60, 0.82, 1.0))


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
				Color(0.80, 0.74, 1.0), 4.6, alto + 14.0)

	# Le tre lampade di colore: sono quelle che danno un'aria a ogni zona, ed e'
	# cosi' che un'ala si riconosce da lontano prima di leggerne l'insegna.
	_lampada(Vector3(0, 5.0, -22), Color(0.98, 0.78, 0.42), 3.4, 26.0)
	_lampada(Vector3(26, 4.2, 0), Color(1.0, 0.52, 0.46), 3.2, 24.0)
	# Verde lime, non ambra: una lampada arancione tingerebbe le pareti del
	# colore del dardo, e quel colore e' riservato a lui solo.
	_lampada(Vector3(-24, 4.0, -24), Color(0.62, 1.0, 0.45), 2.8, 22.0)


func _lampada(dove: Vector3, colore: Color, forza: float, portata: float) -> void:
	var luce := OmniLight3D.new()
	luce.position = dove
	luce.light_color = colore
	luce.light_energy = forza
	luce.omni_range = portata
	luce.shadow_enabled = false
	add_child(luce)


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


func _process(delta: float) -> void:
	_aggiorna_righe()
	_respiro_degli_anelli(delta)
	if _sfida and not _finita:
		_controlla_il_traguardo()
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
		_tasti[tasto] = giu


# ------------------------------------------------------------------ la partita

## L'interruttore. Acceso: entra l'avversario, i bersagli si fanno da parte e i
## punteggi ripartono da zero. Spento: l'arena torna il posto in cui si gira per
## guardarla.
func commuta_sfida() -> void:
	if _sfida:
		chiudi_sfida()
	else:
		avvia_sfida()


func avvia_sfida() -> void:
	_sfida = true
	_finita = false
	_punti_tu = 0
	_punti_lui = 0
	for bersaglio in _bersagli:
		bersaglio.metti_in_pausa(true)

	_mettiti_alla_partenza(_partenza)
	if _avversario == null or not is_instance_valid(_avversario):
		_avversario = Avversario.crea(self, _dove_partenza(_partenza), _livello)
		_avversario.centrato.connect(_su_avversario_centrato)
		_avversario.ha_centrato.connect(_su_avversario_ha_centrato)
	_avversario.imposta_livello(_livello)
	_avversario.bersaglio = _giocatore
	_porta_alla_partenza(_avversario, _partenza_lontana_da(_giocatore, _partenza))

	_comandi.scrivi_sfida("CHIUDI")
	_comandi.annuncia("SFIDA · %s" % String(Avversario.TARATURE[_livello]["nome"]).to_upper())


func chiudi_sfida() -> void:
	_sfida = false
	_finita = false
	if _avversario != null and is_instance_valid(_avversario):
		_avversario.bersaglio = null
		_avversario.queue_free()
		_avversario = null
	for bersaglio in _bersagli:
		bersaglio.metti_in_pausa(false)
	_comandi.scrivi_sfida("SFIDA")
	_comandi.annuncia("ARENA")


## Il livello si cambia dentro la partita: i tre si confrontano col pollice nello
## stesso posto, non leggendo una tabella.
func cambia_livello() -> void:
	_livello = (_livello + 1) % Avversario.TARATURE.size()
	if _avversario != null and is_instance_valid(_avversario):
		_avversario.imposta_livello(_livello)
	_comandi.annuncia(String(Avversario.TARATURE[_livello]["nome"]).to_upper())


func in_sfida() -> bool:
	return _sfida


func avversario() -> Avversario:
	return _avversario


func punteggi() -> Array:
	return [_punti_tu, _punti_lui]


## Chi arriva prima a 500. Finita la partita l'avversario smette di giocare, e il
## pulsante ne comincia un'altra da zero.
func _controlla_il_traguardo() -> void:
	if _punti_tu < TRAGUARDO and _punti_lui < TRAGUARDO:
		return
	_finita = true
	if _avversario != null and is_instance_valid(_avversario):
		_avversario.bersaglio = null
	_comandi.scrivi_sfida("ANCORA")
	_comandi.annuncia("HAI VINTO" if _punti_tu >= TRAGUARDO else "HAI PERSO")


func _su_avversario_centrato(punti: int, muri: int) -> void:
	if _finita:
		return
	_punti_tu += punti
	if muri == 0:
		_comandi.annuncia("DIRETTO · %d" % punti)
	elif muri == 1:
		_comandi.annuncia("1 MURO · %d" % punti)
	else:
		_comandi.annuncia("%d MURI · %d" % [muri, punti])
	_ricompari_avversario.call_deferred()


func _su_avversario_ha_centrato(punti: int, _muri: int) -> void:
	if _finita:
		return
	_punti_lui += punti


func _su_giocatore_incassato(_punti: int, _muri: int) -> void:
	if not _sfida or _finita:
		return
	_comandi.annuncia("COLPITO")
	_ricompari_giocatore.call_deferred()


## **La ricomparsa.** Nel nostro gioco un colpo non toglie la vita — dà venticinque
## punti a chi lo tira, raddoppiati a ogni muro — ma **sposta**: chi è stato
## centrato ricompare da un'altra parte dell'arena.
##
## È una regola nostra, del 26/08/2026, e discende dal 1999 in un punto solo: là
## chi veniva eliminato riappariva subito e mai vicino a chi lo aveva preso
## (`RICERCA-ORIGINALE.md` § 2). Senza, in un posto da sessantasei metri la partita
## si deciderebbe nei primi trenta secondi dentro un angolo: chi trova per primo
## l'altro lo tiene sotto tiro fino a 500, e le altre cinque partenze non servono a
## niente. Con la ricomparsa la caccia ricomincia a ogni colpo, e l'arena serve
## tutta.
func _ricompari_giocatore() -> void:
	if not _sfida or _finita or _avversario == null or not is_instance_valid(_avversario):
		return
	_mettiti_alla_partenza(_partenza_lontana_da(_avversario, _partenza))


func _ricompari_avversario() -> void:
	if not _sfida or _finita or _avversario == null or not is_instance_valid(_avversario):
		return
	_porta_alla_partenza(_avversario, _partenza_lontana_da(_giocatore, -1))
	_avversario.ricomincia_il_cammino()


func _porta_alla_partenza(chi: CharacterBody3D, quale: int) -> void:
	chi.global_position = _dove_partenza(quale)
	chi.velocity = Vector3.ZERO


## Quale partenza sta più lontana da qualcuno — e soprattutto **fuori dalla sua
## vista**.
##
## È il criterio del 1999: fra i candidati il gioco penalizzava pesantemente quelli
## vicini o in linea di vista di un giocatore vivo (`RICERCA-ORIGINALE.md` § 2).
## Nascere davanti a chi ti ha appena preso è la cosa che rende irrespirabile
## un'arena, e con sei partenze non c'è nessun motivo per farlo.
func _partenza_lontana_da(chi: Node3D, evita: int) -> int:
	var quante := int(_pianta["partenze"].size())
	var migliore := 0
	var punteggio := -INF
	for i in quante:
		if i == evita and quante > 1:
			continue
		var dove := _dove_partenza(i)
		var quanto := dove.distance_to(chi.global_position)
		if _in_vista(dove, chi):
			quanto -= PENALITA_IN_VISTA
		if quanto > punteggio:
			punteggio = quanto
			migliore = i
	return migliore


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
		_comandi.scrivi_alto("TU %d — LUI %d   (a %d)" % [_punti_tu, _punti_lui, TRAGUARDO])
		_comandi.scrivi_basso("avversario %s · %s · %s · dardo %s · %d fps" % [
			Avversario.TARATURE[_livello]["nome"],
			String(_pianta["partenze"][_partenza]["nome"]), visuale,
			CANDIDATI[_candidato]["nome"], Engine.get_frames_per_second()])
		return
	_comandi.scrivi_alto("%d punti" % _punteggio)
	var migliore := "—" if _migliore == 0 else "%d con %d muri" % [_migliore, _migliore_muri]
	_comandi.scrivi_basso("%s · %s · miglior colpo: %s · %s · dardo %s · %d fps" % [
		"rimbalza solo sulle sponde" if _solo_sponde else "rimbalza tutto",
		String(_pianta["partenze"][_partenza]["nome"]), migliore, visuale,
		CANDIDATI[_candidato]["nome"], Engine.get_frames_per_second()])


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
	if muri == 0:
		_comandi.annuncia("DIRETTO · %d" % punti)
	elif muri == 1:
		_comandi.annuncia("1 MURO · %d" % punti)
	else:
		_comandi.annuncia("%d MURI · %d" % [muri, punti])


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
