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
## ogni muro; loro sparano solo dritto, quindi valgono sempre 25: giocando dritto
## siete pari, e si vince di sponda.
const TRAGUARDO := 500

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

## La ricomparsa: quanto conta trovare qualcun altro già lì. Le sei partenze sono
## tutte assegnate a inizio partita, quindi «libera» non esiste: esiste **meno
## occupata**.
const RAGGIO_LIBERO := 6.0
const PENALITA_OCCUPATA := 30.0

## E la ricomparsa deve **spostare**: la partenza in cui si sta già non è
## candidata. Senza, chi viene colpito appena nato resta esattamente dov'è — la
## sua partenza è lontana da chi ha sparato e non è occupata da nessun altro,
## quindi vince il confronto e la ricomparsa non si vede (trovato dal collaudo
## dell'arena, 27/08/2026).
const SCARTO_MINIMO := 3.0

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

## **Il pubblico sulle gradinate.** Tre file per gradinata, una più alta
## dell'altra: le gradinate sono blocchi lisci, e sono i posti sfalsati a
## raccontare il gradino. Le tinte sono quelle sature del gioco, che da
## venticinque metri sono l'unica cosa che si legge di una figura alta un metro.
const FILE_PUBBLICO := 4
const PASSO_FILA := 1.15     ## quanto dista una fila dall'altra, verso il campo
const GRADINO := 0.4         ## quanto sale ogni fila
const PASSO_POSTO := 0.7     ## quanto è largo un posto
const ALTEZZA_SEDUTO := 0.5  ## mezzo busto sopra il piano: seduti, non in piedi
const POSTI_VUOTI := 0.12    ## una tribuna piena al centesimo non è una tribuna
const TINTE_PUBBLICO := [
	Color(0.98, 0.78, 0.22), Color(0.30, 0.85, 0.95), Color(0.95, 0.35, 0.62),
	Color(0.55, 0.90, 0.40), Color(0.92, 0.92, 0.88), Color(0.99, 0.55, 0.25),
]

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

## Chi è in campo: `{"nome": String, "corpo": Node3D, "punti": int}`. Il giocatore
## è una riga come le altre — è la differenza fra una partita a sei e un duello
## con quattro comparse.
var _concorrenti: Array[Dictionary] = []
var _sfida := false
var _finita := false
var _livello := 1
var _prossima_riscelta := 0.0
var _turno_riscelta := 0
## Chi deve ancora entrare in campo: `{"nome", "partenza"}`, uno per fotogramma.
var _in_arrivo: Array[Dictionary] = []


func _ready() -> void:
	_pianta = carica_pianta()
	_ambiente()
	_costruisci()
	_pubblico()
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
	# Si collega una volta sola, non a ogni partita: `preso_da` porta **chi** ha
	# sparato, ed è l'unico posto da cui passano i punti di chiunque.
	_giocatore.preso_da.connect(_su_colpo_valido.bind(_giocatore))
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

	_cordoli()

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
	var tinta := Color(0.78, 0.72, 0.95)
	for zona in _pianta["zone"]:
		var quota := float(zona["quota"])
		if quota <= 0.0:
			continue
		var contorno := _contorno(zona["poligono"])
		for i in contorno.size():
			var da := contorno[i]
			var a := contorno[(i + 1) % contorno.size()]
			var lungo := da.distance_to(a)
			if lungo < 0.6:
				continue
			var mezzo := (da + a) * 0.5
			var verso := (a - da).normalized()
			var fuori := Vector2(verso.y, -verso.x)
			# Un lato che confina con un altro piano alla stessa quota non è un
			# bordo: è una giuntura, e segnarla vorrebbe dire disegnare una riga
			# in mezzo al pavimento.
			if _piano_alla_quota(mezzo + fuori * 0.8, quota):
				continue
			Muratura.decoro(self, Vector3(mezzo.x, quota + 0.03, mezzo.y),
					Vector3(lungo, 0.06, 0.18), tinta, 0.55,
					Vector3(0, rad_to_deg(atan2(-verso.y, verso.x)), 0))


## C'è un pavimento a quella quota, in quel punto della pianta? Si guarda la
## pianta, non la scena: qui la scena non è ancora costruita.
func _piano_alla_quota(dove: Vector2, quota: float) -> bool:
	for zona in _pianta["zone"]:
		if absf(float(zona["quota"]) - quota) > 0.2:
			continue
		if Geometry2D.is_point_in_polygon(dove, _contorno(zona["poligono"])):
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
	var posti: Array[Transform3D] = []
	var tinte: Array[Color] = []
	# Seme fisso: la tribuna dev'essere la stessa a ogni apertura, o due scatti
	# dello stesso posto non si possono confrontare.
	var caso := RandomNumberGenerator.new()
	caso.seed = 20260827

	for muro in _pianta["muri"]:
		var nome := String(muro.get("nome", ""))
		if not nome.contains("gradinata"):
			continue
		var centro := _punto(muro["centro"])
		var misura := _punto(muro["misura"])
		var piano := float(muro["quota"]) + float(muro["alto"])
		# Il cordolo sul bordo che dà sul campo. Senza, la folla sembra sospesa
		# sul niente: la gradinata è un blocco scuro e il suo piano non si legge
		# — è la lezione della passerella nord (`LEARNED.md` § 31), applicata a
		# un piano su cui non si cammina ma si guarda.
		Muratura.decoro(self, Vector3(centro.x + misura.x * 0.5, piano + 0.03, centro.y),
				Vector3(misura.y, 0.06, 0.18), Color(0.78, 0.72, 0.95), 0.55,
				Vector3(0, 90, 0))
		# Le file guardano l'arena, che sta a est: corrono lungo la profondità
		# della gradinata e si susseguono verso ovest, ognuna un gradino più su.
		for fila in FILE_PUBBLICO:
			var x := centro.x - misura.x * 0.5 + PASSO_FILA * (float(fila) + 0.6)
			var alto := piano + GRADINO * float(fila)
			var quanti := int(misura.y / PASSO_POSTO)
			for posto in quanti:
				if caso.randf() < POSTI_VUOTI:
					continue
				var z := centro.y - misura.y * 0.5 + PASSO_POSTO * (float(posto) + 0.5)
				var dove := Vector3(x + caso.randf_range(-0.1, 0.1), alto + ALTEZZA_SEDUTO,
						z + caso.randf_range(-0.08, 0.08))
				var giro := Transform3D(Basis(Vector3.UP, caso.randf_range(-0.4, 0.4)), dove)
				posti.append(giro)
				tinte.append(TINTE_PUBBLICO[caso.randi() % TINTE_PUBBLICO.size()])

	if posti.is_empty():
		return

	# **Busti e teste, due passate in tutto.** Una capsula da sola, a venticinque
	# metri, non è una persona: è un birillo — guardato in uno scatto il
	# 27/08/2026, ed è la testa a fare la differenza. Fonderle in una mesh sola
	# avrebbe risparmiato una passata su centoquaranta figure: non vale il codice
	# che costa.
	var busto := CapsuleMesh.new()
	busto.radius = 0.26
	busto.height = 1.0
	busto.radial_segments = 6
	busto.rings = 2
	_folla("pubblico", busto, posti, tinte, Vector3.ZERO, 1.0)

	var testa := SphereMesh.new()
	testa.radius = 0.2
	testa.height = 0.4
	testa.radial_segments = 6
	testa.rings = 4
	# La testa è la stessa tinta, ma scura: senza, una fila di teste chiare
	# sembra una fila di lampadine.
	_folla("pubblico_teste", testa, posti, tinte, Vector3(0, 0.66, 0), 0.42)


## Una folla: la stessa figura ripetuta, una passata sola per la scheda video.
## `scuro` moltiplica la tinta, `alzata` sposta la figura rispetto al posto.
func _folla(nome: String, figura: Mesh, posti: Array[Transform3D], tinte: Array[Color],
		alzata: Vector3, scuro: float) -> void:
	var pelle := StandardMaterial3D.new()
	pelle.vertex_color_use_as_albedo = true
	pelle.roughness = 0.85
	pelle.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var folla := MultiMesh.new()
	folla.transform_format = MultiMesh.TRANSFORM_3D
	folla.use_colors = true
	folla.mesh = figura
	folla.instance_count = posti.size()
	for i in posti.size():
		folla.set_instance_transform(i, posti[i].translated(alzata))
		folla.set_instance_color(i, tinte[i] * scuro)

	var nodo := MultiMeshInstance3D.new()
	nodo.name = nome
	nodo.multimesh = folla
	nodo.material_override = pelle
	nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(nodo)


## Quante figure ci sono. Serve al collaudo: una tribuna vuota si vede solo
## guardandola, e un errore nella pianta la svuoterebbe in silenzio.
func quanto_pubblico() -> int:
	var nodo := get_node_or_null("pubblico") as MultiMeshInstance3D
	if nodo == null or nodo.multimesh == null:
		return 0
	return nodo.multimesh.instance_count


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
		_scegli_i_bersagli(delta)
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
	for bersaglio in _bersagli:
		bersaglio.metti_in_pausa(true)

	_svuota_il_campo()
	_mettiti_alla_partenza(_partenza)
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
		_in_arrivo.append({"nome": String(NOMI[i]), "partenza": (_partenza + 1 + i) % quante})
	_fai_entrare_il_prossimo()

	_prossima_riscelta = RISCELTA
	_turno_riscelta = 0
	_aggiorna_la_classifica()
	_comandi.scrivi_sfida("CHIUDI")
	_comandi.annuncia("PARTITA · %s" % String(Avversario.TARATURE[_livello]["nome"]).to_upper())


## Uno solo per fotogramma, finché la coda non è vuota. Il bersaglio se lo
## sceglie appena entrato: chi arriva per ultimo trova gli altri già in campo, e
## chi era già dentro lo aggiusta al suo turno di riscelta.
func _fai_entrare_il_prossimo() -> void:
	if _in_arrivo.is_empty():
		return
	var chi: Dictionary = _in_arrivo.pop_front()
	var bot := Avversario.crea(self, _dove_partenza(int(chi["partenza"])), _livello)
	bot.preso_da.connect(_su_colpo_valido.bind(bot))
	_concorrenti.append({"nome": String(chi["nome"]), "corpo": bot, "punti": 0})
	bot.punta_a(_chi_attaccare(bot))
	_aggiorna_la_classifica()


func chiudi_sfida() -> void:
	_sfida = false
	_finita = false
	_in_arrivo.clear()
	_svuota_il_campo()
	for bersaglio in _bersagli:
		bersaglio.metti_in_pausa(false)
	_comandi.spegni_la_classifica()
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
func _chi_attaccare(bot: Avversario) -> Node3D:
	var altri: Array = []
	for riga in _concorrenti:
		var corpo: Node3D = riga["corpo"]
		if corpo == null or corpo == bot or not is_instance_valid(corpo):
			continue
		altri.append({"corpo": corpo,
				"quanto": bot.global_position.distance_to(corpo.global_position)})
	if altri.is_empty():
		return null
	altri.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["quanto"]) < float(b["quanto"]))

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
	if attuale != null and is_instance_valid(attuale) and attuale != scelto:
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

## Chi arriva per primo a 500. Finita la partita nessuno gioca più, e il pulsante
## ne comincia un'altra da zero.
func _controlla_il_traguardo() -> void:
	var vincitore := -1
	for i in _concorrenti.size():
		if int(_concorrenti[i]["punti"]) < TRAGUARDO:
			continue
		if vincitore < 0 or int(_concorrenti[i]["punti"]) > int(_concorrenti[vincitore]["punti"]):
			vincitore = i
	if vincitore < 0:
		return

	_finita = true
	for bot in avversari():
		bot.bersaglio = null
	_aggiorna_la_classifica()
	_comandi.scrivi_sfida("ANCORA")
	if _concorrenti[vincitore]["corpo"] == _giocatore:
		_comandi.annuncia("HAI VINTO")
	else:
		_comandi.annuncia("VINCE %s · SEI %d°" %
				[String(_concorrenti[vincitore]["nome"]), posizione_mia()])


## **L'unico posto da cui passano i punti.** Ogni corpo che si può colpire dice
## chi l'ha preso e quanto vale; qui si accredita a chi ha sparato, si annuncia se
## la cosa ti riguarda, e si fa ricomparire chi ha incassato.
##
## Nel duello bastava sapere che qualcuno era stato colpito, perché chi sparava
## era per forza l'altro. In sei no: senza il nome di chi ha sparato, un colpo fra
## avversari finirebbe nel tuo punteggio.
func _su_colpo_valido(chi_spara: Object, punti: int, muri: int, chi_incassa: Node3D) -> void:
	if not _sfida or _finita:
		return
	var autore := _riga_di(chi_spara)
	if autore >= 0:
		_concorrenti[autore]["punti"] = int(_concorrenti[autore]["punti"]) + punti
		if chi_spara == _giocatore:
			_annuncia_il_colpo(punti, muri)
		elif chi_incassa == _giocatore:
			_comandi.annuncia("COLPITO DA %s" % String(_concorrenti[autore]["nome"]))
	elif chi_incassa == _giocatore:
		_comandi.annuncia("COLPITO")
	_aggiorna_la_classifica()
	_ricompari.call_deferred(chi_incassa, chi_spara)


## In che riga della partita sta un corpo. Sei righe: cercarle una per una costa
## meno che tenere in piedi un secondo elenco da mantenere allineato.
func _riga_di(corpo: Object) -> int:
	for i in _concorrenti.size():
		if _concorrenti[i]["corpo"] == corpo:
			return i
	return -1


func _annuncia_il_colpo(punti: int, muri: int) -> void:
	if muri == 0:
		_comandi.annuncia("DIRETTO · %d" % punti)
	elif muri == 1:
		_comandi.annuncia("1 MURO · %d" % punti)
	else:
		_comandi.annuncia("%d MURI · %d" % [muri, punti])


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
func _ricompari(chi: Node3D, da: Object) -> void:
	if not _sfida or _finita or chi == null or not is_instance_valid(chi):
		return
	var lontano_da := chi
	if da is Node3D and is_instance_valid(da as Node3D):
		lontano_da = da as Node3D
	var dove := _dove_ricomparire(lontano_da, chi)
	if chi == _giocatore:
		_mettiti_alla_partenza(dove)
	elif chi is Avversario:
		_porta_alla_partenza(chi as CharacterBody3D, dove)
		(chi as Avversario).ricomincia_il_cammino()


func _porta_alla_partenza(chi: CharacterBody3D, quale: int) -> void:
	chi.global_position = _dove_partenza(quale)
	chi.velocity = Vector3.ZERO


## Dove ricomparire: lontano da chi ti ha appena preso, **fuori dalla sua vista**,
## e possibilmente non in braccio a un terzo.
##
## Il criterio è quello del 1999: fra i candidati il gioco penalizzava pesantemente
## quelli vicini o in linea di vista di un giocatore vivo (`RICERCA-ORIGINALE.md`
## § 2). Nascere davanti a chi ti ha appena preso è la cosa che rende irrespirabile
## un'arena.
##
## In sei c'è una penalità in più che nel duello non serviva: a inizio partita le
## sei partenze sono **tutte** assegnate, quindi non ne esiste una libera — esiste
## la meno occupata, e quella basta, perché dopo tre secondi nessuno è più dove è
## nato.
func _dove_ricomparire(lontano_da: Node3D, chi_torna: Node3D) -> int:
	var quante := int(_pianta["partenze"].size())
	var migliore := 0
	var punteggio := -INF
	for i in quante:
		var dove := _dove_partenza(i)
		if dove.distance_to(chi_torna.global_position) < SCARTO_MINIMO:
			continue
		var quanto := dove.distance_to(lontano_da.global_position)
		if _in_vista(dove, lontano_da):
			quanto -= PENALITA_IN_VISTA
		for riga in _concorrenti:
			var altro: Node3D = riga["corpo"]
			if altro == chi_torna or altro == null or not is_instance_valid(altro):
				continue
			if dove.distance_to(altro.global_position) < RAGGIO_LIBERO:
				quanto -= PENALITA_OCCUPATA
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
		# La riga alta non ripete la classifica, che sta due dita sotto: dice
		# **quanto manca**, che è l'unica cosa che la classifica non mostra.
		var miei := int(punteggi()[0])
		if _finita:
			_comandi.scrivi_alto("FINITA · sei %d° su %d" %
					[posizione_mia(), _concorrenti.size()])
		else:
			_comandi.scrivi_alto("%d° · ti mancano %d punti" %
					[posizione_mia(), maxi(TRAGUARDO - miei, 0)])
		_comandi.scrivi_basso("%d avversari · %s · %s · %s · dardo %s · %d fps" % [
			_concorrenti.size() - 1,
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
