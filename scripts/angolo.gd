extends Node3D

## Un angolo di arena vero: la tappa 3.
##
## Non è un livello e non è un'arena: è **un angolo**, con i materiali definitivi,
## l'illuminazione definitiva e le insegne al neon. Serve a rispondere a due cose
## che la stanza grigia del poligono non può dire (`PLAN.md`, tappa 3):
##
##   1. la direzione visiva — «Nerf com'era, rifatto nel 2026» — regge su uno
##      schermo di telefono?
##   2. **si capisce a occhio quali superfici rimbalzano?**
##
## La seconda è una decisione di gioco travestita da decisione visiva. Nel
## poligono rimbalza tutto, e in una stanza di sei scatole va benissimo; in
## un'arena con la geometria ricca che chiede `DECISIONI.md` § B, una sporgenza
## qualunque restituirebbe un rimbalzo che nessuno può prevedere — e un rimbalzo
## imprevedibile non è la firma del gioco, è un caso fortunato. Perciò qui le
## **sponde sono dichiarate** e tutto il resto ferma il dardo.
##
## Il pulsante SPONDE commuta fra le due regole nella stessa stanza, perché le
## cose del pollice si scelgono col pollice e non leggendo una tabella: è lo
## stesso modo con cui si sceglie il colore del dardo e il livello dell'avversario.
##
## Il tema è la palestra al neon dell'arena di apertura del 1999 — moquette viola,
## pareti gialle e rosse, insegne, pubblico (`RICERCA-ORIGINALE.md` § 4) — con i
## volumi nostri: i corridoi stretti dell'originale non li teniamo, perché la
## camera in terza persona deve respirare (decisione 2).

const LARGHEZZA := 26.0
const PROFONDITA := 22.0
const ALTEZZA := 9.0
const SPESSORE := 0.6

## La tavolozza della palestra. Nessuna di queste tinte è il bianco-arancio del
## dardo a piena saturazione: è la regola che discende da `DECISIONI.md` § B.
const MOQUETTE := Color(0.24, 0.13, 0.36)
const OCRA := Color(0.66, 0.47, 0.15)
const MATTONE := Color(0.58, 0.19, 0.20)
const TRIBUNA := Color(0.19, 0.16, 0.38)
const SOFFITTO := Color(0.10, 0.10, 0.21)

## Il colore riservato alle sponde, come il bianco-arancio è riservato al dardo:
## sta all'opposto sulla ruota, e nell'originale compare sugli arredi e mai sulle
## superfici grandi.
##
## **Satura e accesa, non pallida e non scura.** Ci sono voluti tre giri.
## Pallida (azzurro chiaro illuminato) rendeva l'arena lattiginosa, che è l'esatto
## contrario del 1999. Scura con la cornice accesa si riconosceva di faccia e
## spariva di taglio — e di taglio è proprio l'angolo da cui si guarda una sponda
## quando la si sta per usare. Accesa e satura fa tutte e due le cose: resta un
## colore del mondo del 1999 e si vede da ottanta gradi.
const SPONDA := Color(0.09, 0.60, 0.64)
const NEON_SPONDA := Color(0.30, 0.99, 0.95)

const PARTENZA := Vector3(7.0, 0.4, 6.0)
const GIRO_PARTENZA := 49.0

## Gli stessi tre candidati del poligono: il colore del dardo si sceglie sulla
## scena vera, e adesso le scene vere sono due.
const CANDIDATI := [
	{"nome": "bianco-arancio", "colore": Color(1.0, 0.62, 0.24)},
	{"nome": "ciano-bianco", "colore": Color(0.35, 0.9, 1.0)},
	{"nome": "magenta-bianco", "colore": Color(1.0, 0.36, 0.78)},
]

## I tasti della lavorazione: sul PC si prova senza toccare i pulsanti.
const SCORCIATOIE := {KEY_C: "colore", KEY_S: "sponde", KEY_A: "poligono"}

const SEME := 20260826  ## il pubblico dev'essere sempre lo stesso, o gli scatti non si confrontano

## Gli anelli del rimbalzo si preparano all'avvio e si riciclano: nascerne uno a
## ogni impatto e' quello che faceva scattare l'immagine sparando a raffica.
const ANELLI_IN_RISERVA := 12
const VITA_ANELLO := 0.36

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
var _anelli: Array[MeshInstance3D] = []
var _vita_anelli: Array[float] = []
var _prossimo_anello := 0
var _nascosto: Bersaglio


func _ready() -> void:
	_ambiente()
	_guscio()
	_sponde()
	_arredo()
	_tribune()
	_luci()
	_insegne()
	_bersagli_dell_angolo()
	_prepara_gli_anelli()

	_comandi = Comandi.new()
	add_child(_comandi)
	_comandi.colore_richiesto.connect(_cambia_colore)
	_comandi.camera_richiesta.connect(func() -> void: _giocatore.cambia_camera())
	# Qui non c'è nessun avversario: SFIDA e LIVELLO sarebbero due pulsanti che
	# non fanno niente, e un pulsante che non fa niente è peggio di uno che manca.
	_comandi.spegni_il_duello()
	_bottone_sponde = _comandi.pulsante_di_scena("SPONDE", Color(0.2, 0.75, 0.7),
			commuta_sponde)
	_comandi.pulsante_di_scena("POLIGONO", Color(0.35, 0.4, 0.55), torna_al_poligono)

	_giocatore = Giocatore.new()
	add_child(_giocatore)
	_giocatore.global_position = PARTENZA
	_giocatore.comandi = _comandi
	_giocatore.punta(GIRO_PARTENZA, -4.0)

	# Il primo colpo di una partita costava un fotogramma intero: il motore
	# compila lo shader del dardo quando lo disegna, e lo disegnava per la prima
	# volta proprio li'. Adesso lo disegna adesso, grande meno di un pixel.
	Proiettile.scalda(self, _giocatore.camera())

	# Ogni dardo che nasce racconta i suoi rimbalzi: è così che la sponda si
	# accende dove è stata colpita. Il collegamento si fa alla nascita del nodo,
	# non inseguendo i dardi in volo a ogni fotogramma.
	get_tree().node_added.connect(_su_nodo_nuovo)

	_applica_regola()
	_aggiorna_righe()


## Servono agli attrezzi di lavorazione, che pilotano la scena per gli scatti.
func giocatore() -> Giocatore:
	return _giocatore


func nome_colore() -> String:
	return String(CANDIDATI[_candidato]["nome"])


func passa_al_colore_seguente() -> void:
	_cambia_colore()


## Quello dietro il divisorio: lo dice la scena, non si indovina dalle coordinate.
## Il collaudo che lo cercava per posizione ha pescato quello allo scoperto e ha
## dichiarato scoperto un angolo cieco che c'era.
func bersaglio_nascosto() -> Bersaglio:
	return _nascosto


## Vero se rimbalza solo dove c'è una sponda; falso se rimbalza tutto, com'è al
## poligono. È la domanda della tappa, e si commuta in gioco.
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
	for tasto in SCORCIATOIE:
		var giu := Input.is_physical_key_pressed(tasto)
		if giu and not bool(_tasti.get(tasto, false)):
			match String(SCORCIATOIE[tasto]):
				"colore": _cambia_colore()
				"sponde": commuta_sponde()
				"poligono": torna_al_poligono()
		_tasti[tasto] = giu


## La regola, applicata ai muri: gli stessi corpi, un altro strato. Nient'altro
## cambia — la geometria, la luce e i pannelli restano dove sono, e questo è il
## punto: con «rimbalza tutto» il linguaggio delle sponde continua a dire dove
## rimbalzare, e non serve più a niente. Si vede subito.
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
	_comandi.scrivi_alto("%d punti" % _punteggio)
	var migliore := "—" if _migliore == 0 else "%d con %d muri" % [_migliore, _migliore_muri]
	_comandi.scrivi_basso("%s · miglior colpo: %s · %s · dardo %s · %d fps" % [
		"rimbalza solo sulle sponde" if _solo_sponde else "rimbalza tutto",
		migliore, visuale, CANDIDATI[_candidato]["nome"], Engine.get_frames_per_second()])


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


## La riserva degli anelli, pronta all'avvio e riciclata per sempre.
##
## Prima ne nasceva uno nuovo a ogni rimbalzo — nodo, mesh e materiale da zero,
## piu' un'animazione — e sparando a raffica erano decine in pochi secondi:
## e' da li' che veniva lo scatto riportato dal telefono il 26/08/2026.
## Adesso non si alloca piu' niente mentre si gioca: dodici anelli girano a
## rotazione, e dodici bastano perche' ognuno dura poco piu' di un terzo di
## secondo e un dardo puo' fare al massimo cinque muri.
func _prepara_gli_anelli() -> void:
	var forma := TorusMesh.new()
	forma.inner_radius = 0.24
	forma.outer_radius = 0.34
	forma.rings = 20
	forma.ring_segments = 5
	for i in ANELLI_IN_RISERVA:
		var anello := MeshInstance3D.new()
		# La forma e' una sola, prestata a tutti: e' il materiale che deve essere
		# suo, perche' ognuno sbiadisce per conto proprio.
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


## Il terzo segnale, e l'unico che non si vede stando fermi: la sponda si accende
## dove il dardo l'ha presa. Serve a imparare la regola giocando invece che
## leggendola, e a far contare i cinque muri a occhio.
func _su_rimbalzo(punto: Vector3, normale: Vector3, _muri: int) -> void:
	var quale := _prossimo_anello
	_prossimo_anello = (_prossimo_anello + 1) % ANELLI_IN_RISERVA
	var anello := _anelli[quale]
	_vita_anelli[quale] = VITA_ANELLO
	anello.visible = true
	anello.scale = Vector3.ONE * 0.5
	anello.rotation = Vector3.ZERO
	anello.global_position = punto + normale * 0.05
	# Il toro nasce sdraiato sul piano orizzontale: va coricato sulla superficie.
	if absf(normale.dot(Vector3.UP)) < 0.999:
		anello.look_at_from_position(anello.global_position, anello.global_position + normale,
				Vector3.UP, true)
		anello.rotate_object_local(Vector3.RIGHT, PI * 0.5)


## L'anello si allarga e sbiadisce. A mano invece che con un'animazione del
## motore: un'animazione e' un oggetto in piu' che nasce a ogni rimbalzo, e il
## conto qui sono due righe.
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


## L'ambiente. La soglia del bagliore sta a 1.0: sopra ci va solo il dardo, e
## nessuna superficie dell'arena la tocca — è la regola che tiene insieme «mondo
## saturo» e «dardo sempre leggibile» (DECISIONI.md § B).
func _ambiente() -> void:
	var mondo := WorldEnvironment.new()
	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color(0.04, 0.04, 0.09)
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color(0.46, 0.42, 0.66)
	ambiente.ambient_light_energy = 0.55
	ambiente.tonemap_mode = Environment.TONE_MAPPER_ACES
	ambiente.glow_enabled = true
	ambiente.glow_intensity = 1.1
	ambiente.glow_bloom = 0.12
	ambiente.glow_hdr_threshold = 1.0
	ambiente.fog_enabled = false
	mondo.environment = ambiente
	add_child(mondo)


## Il guscio: pavimento, soffitto e le quattro pareti. Tutte opache — quello su
## cui si rimbalza arriva dopo, e si vede che arriva dopo.
func _guscio() -> void:
	var meta_x := LARGHEZZA * 0.5
	var meta_z := PROFONDITA * 0.5

	Muratura.muro(self, Vector3(0, -SPESSORE * 0.5, 0),
			Vector3(LARGHEZZA, SPESSORE, PROFONDITA), MOQUETTE)
	Muratura.muro(self, Vector3(0, ALTEZZA + SPESSORE * 0.5, 0),
			Vector3(LARGHEZZA, SPESSORE, PROFONDITA), SOFFITTO)

	# Le due pareti che fanno l'angolo: sono loro a portare le sponde.
	Muratura.muro(self, Vector3(0, ALTEZZA * 0.5, -meta_z - SPESSORE * 0.5),
			Vector3(LARGHEZZA, ALTEZZA, SPESSORE), OCRA)
	Muratura.muro(self, Vector3(-meta_x - SPESSORE * 0.5, ALTEZZA * 0.5, 0),
			Vector3(SPESSORE, ALTEZZA, PROFONDITA), MATTONE)

	# Le altre due chiudono verso il resto dell'arena: sono le tribune.
	Muratura.muro(self, Vector3(meta_x + SPESSORE * 0.5, ALTEZZA * 0.5, 0),
			Vector3(SPESSORE, ALTEZZA, PROFONDITA), TRIBUNA)
	Muratura.muro(self, Vector3(0, ALTEZZA * 0.5, meta_z + SPESSORE * 0.5),
			Vector3(LARGHEZZA, ALTEZZA, SPESSORE), TRIBUNA)

	# Il divisorio: è lui a creare l'angolo cieco, cioè il motivo per cui si
	# impara a tirare di sponda. Opaco: chi ci sbatte contro perde il dardo.
	Muratura.muro(self, Vector3(-4.0, 2.25, -3.0), Vector3(8.0, 4.5, 0.8), MATTONE)

	# Un pilastro, copertura mobile. Porta una sponda su una faccia sola: è il
	# caso che insegna che la sponda è il pannello, non l'oggetto.
	# Spostato di lato: dove stava prima tagliava a metà l'insegna PENTAWALL da
	# dove si comincia a giocare, cioè nell'unica inquadratura garantita.
	Muratura.muro(self, Vector3(8.2, 3.0, -5.0), Vector3(1.6, 6.0, 1.6), OCRA)

	# Il dislivello, con la rampa: sparare dall'alto cambia tutti gli angoli.
	Muratura.muro(self, Vector3(-9.5, 0.6, 7.0), Vector3(7.0, 1.2, 7.0), MATTONE)
	Muratura.muro(self, Vector3(-9.5, 0.55, 2.2), Vector3(7.0, 0.25, 3.6), MATTONE,
			Vector3(-12.0, 0, 0))


## Le sponde: dove si rimbalza, e le uniche. Grandi, piane e orientate apposta —
## sono il disegno del livello, non un materiale sparso a caso.
func _sponde() -> void:
	var meta_x := LARGHEZZA * 0.5
	var meta_z := PROFONDITA * 0.5
	var filo := Muratura.SPESSORE_SPONDA * 0.5

	# I due pannelli grandi della parete d'ocra, divisi dal passaggio centrale.
	Muratura.sponda(self, Vector3(-7.0, 3.6, -meta_z + filo), Vector2(6.2, 3.4),
			Vector3.ZERO, SPONDA, NEON_SPONDA)
	Muratura.sponda(self, Vector3(5.4, 3.6, -meta_z + filo), Vector2(5.6, 3.4),
			Vector3.ZERO, SPONDA, NEON_SPONDA)

	# Il pannello della parete di mattoni: è quello che porta il dardo dietro il
	# divisorio, e quindi è quello che fa il gioco.
	Muratura.sponda(self, Vector3(-meta_x + filo, 3.5, -1.5), Vector2(7.0, 3.4),
			Vector3(0, 90, 0), SPONDA, NEON_SPONDA)

	# Le sponde basse lungo il piede delle due pareti: sono quelle del tiro
	# radente, che è il tiro che si impara per primo.
	Muratura.sponda(self, Vector3(0, 0.62, -meta_z + filo), Vector2(25.0, 1.16),
			Vector3.ZERO, SPONDA, NEON_SPONDA)
	Muratura.sponda(self, Vector3(-meta_x + filo, 0.62, 0), Vector2(21.0, 1.16),
			Vector3(0, 90, 0), SPONDA, NEON_SPONDA)

	# La faccia buona del pilastro, verso il campo.
	Muratura.sponda(self, Vector3(8.2, 3.0, -4.2 + filo), Vector2(1.4, 4.4),
			Vector3.ZERO, SPONDA, NEON_SPONDA)

	# Una piastra a terra: il pavimento è moquette e non rimbalza, ma qui sì. È
	# il caso che rompe l'idea «rimbalzano le pareti» e la sostituisce con quella
	# giusta, «rimbalza dove è segnato».
	Muratura.sponda(self, Vector3(1.5, 0.02, -0.5), Vector2(3.4, 3.4),
			Vector3(-90, 0, 0), SPONDA, NEON_SPONDA)


## Zoccoli, segnatura a terra e lucernari. Decori puri: niente collisione, così
## nessun dardo rimbalza su una striscia dipinta — che in un gioco di rimbalzi
## sarebbe la bugia peggiore.
func _arredo() -> void:
	var segnatura := Color(0.78, 0.72, 0.95)

	Muratura.decoro(self, Vector3(0, 0.012, 0), Vector3(LARGHEZZA, 0.02, 0.16), segnatura, 0.30)
	Muratura.decoro(self, Vector3(0, 0.012, -7.0), Vector3(LARGHEZZA, 0.02, 0.1), segnatura, 0.22)
	Muratura.decoro(self, Vector3(-6.0, 0.012, 0), Vector3(0.1, 0.02, PROFONDITA), segnatura, 0.22)

	var cerchio := MeshInstance3D.new()
	var anello := TorusMesh.new()
	# Sottile e schiacciato: con la sezione grossa sembrava un tubo appoggiato
	# per terra invece di una riga dipinta.
	anello.inner_radius = 3.16
	anello.outer_radius = 3.24
	anello.rings = 40
	anello.ring_segments = 4
	cerchio.mesh = anello
	cerchio.position = Vector3(0, 0.012, 0)
	cerchio.material_override = Muratura.acceso(segnatura, 0.18)
	cerchio.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cerchio)

	# I lucernari del soffitto: nell'originale sono la cosa che dice «palestra»
	# in mezzo secondo, e costano quattro rettangoli.
	for posto in [Vector3(-7.0, 0, -5.0), Vector3(4.0, 0, -5.0),
			Vector3(-7.0, 0, 4.0), Vector3(4.0, 0, 4.0)]:
		Muratura.decoro(self, posto + Vector3(0, ALTEZZA - 0.06, 0),
				Vector3(4.4, 0.12, 3.0), Color(0.72, 0.52, 0.98), 0.72)


## Le tribune: il pubblico sta in alto, dietro un parapetto, e non ruba campo.
## Nell'originale c'è, e senza si perde metà del «gara ufficiale ospitata in un
## posto straordinario» che è l'anima del gioco (RICERCA-ORIGINALE.md § 4).
func _tribune() -> void:
	var meta_x := LARGHEZZA * 0.5
	var meta_z := PROFONDITA * 0.5
	var parapetto := Color(0.30, 0.24, 0.52)
	var tinte := [
		Color(0.85, 0.32, 0.30), Color(0.30, 0.62, 0.90), Color(0.92, 0.74, 0.28),
		Color(0.42, 0.80, 0.48), Color(0.78, 0.42, 0.86), Color(0.95, 0.55, 0.30),
	]
	var caso := RandomNumberGenerator.new()
	caso.seed = SEME

	Muratura.decoro(self, Vector3(meta_x - 0.22, 5.0, 0), Vector3(0.3, 0.34, PROFONDITA),
			parapetto, 0.35)
	Muratura.decoro(self, Vector3(0, 5.0, meta_z - 0.22), Vector3(LARGHEZZA, 0.34, 0.3),
			parapetto, 0.35)

	for fila in 2:
		var alto := 5.5 + fila * 0.6
		var arretra := 0.26 + fila * 0.3
		for i in 14:
			var lungo := -9.1 + i * 1.4 + (0.7 if fila == 1 else 0.0)
			Muratura.decoro(self, Vector3(meta_x - arretra, alto, lungo),
					Vector3(0.34, 0.5, 0.42), tinte[caso.randi() % tinte.size()], 0.16)
			Muratura.decoro(self, Vector3(lungo, alto, meta_z - arretra),
					Vector3(0.42, 0.5, 0.34), tinte[caso.randi() % tinte.size()], 0.16)


func _luci() -> void:
	var sole := DirectionalLight3D.new()
	# Le dodici cifre di Transform3D sono le RIGHE della matrice, non le colonne:
	# scambiarle mette la luce a illuminare il cielo (LEARNED.md 14).
	sole.rotation_degrees = Vector3(-54.0, -34.0, 0.0)
	sole.light_energy = 0.62
	sole.light_color = Color(0.86, 0.80, 1.0)
	sole.shadow_enabled = true
	add_child(sole)

	# Luce colorata addosso alle pareti: è l'anima del gioco del 1999, e non si
	# ottiene con le texture ma con le lampade.
	_lampada(Vector3(-6.0, 7.4, -4.0), Color(0.55, 0.72, 1.0), 5.0, 26.0)
	_lampada(Vector3(5.0, 7.4, -2.0), Color(0.85, 0.45, 1.0), 4.6, 26.0)
	# Verde lime, non ambra: una lampada arancione tingerebbe le pareti del colore
	# del dardo, e quel colore è riservato a lui solo.
	_lampada(Vector3(-9.0, 4.0, 7.0), Color(0.62, 1.0, 0.45), 3.2, 20.0)


func _lampada(dove: Vector3, colore: Color, forza: float, portata: float) -> void:
	var luce := OmniLight3D.new()
	luce.position = dove
	luce.light_color = colore
	luce.light_energy = forza
	luce.omni_range = portata
	luce.shadow_enabled = false
	add_child(luce)


func _insegne() -> void:
	var meta_x := LARGHEZZA * 0.5
	var meta_z := PROFONDITA * 0.5
	# Staccate dalla parete di qualche centimetro: appoggiate esattamente sopra,
	# le due superfici si contendono lo stesso piano e il testo esce a strisce.
	Muratura.insegna(self, "PENTAWALL", Vector3(0, 7.6, -meta_z + 0.12), Vector3.ZERO,
			2.0, Color(0.60, 0.82, 1.0))
	Muratura.insegna(self, "PUNTI", Vector3(-meta_x + 0.12, 7.4, -6.0), Vector3(0, 90, 0),
			1.3, Color(0.95, 0.86, 0.42))
	# Nessuna insegna dice «SPONDA». Ce n'era una, ed era la prova che il
	# linguaggio non reggeva da solo: un linguaggio visivo che funziona non ha
	# bisogno di sottotitoli, e uno che non funziona non lo salva un cartello.
	Muratura.insegna(self, "TURBO", Vector3(-meta_x + 0.12, 6.4, 5.5), Vector3(0, 90, 0),
			1.1, Color(0.98, 0.55, 0.35))


func _bersagli_dell_angolo() -> void:
	var azzurro := Color(0.26, 0.74, 1.0)
	var verde := Color(0.32, 0.92, 0.56)

	# Allo scoperto, in movimento: serve a tarare la mira diretta.
	_aggiungi(Vector3(1.0, 0, -8.0), Vector3(-1.0, 0, -8.0), 3.0, azzurro)

	# Dietro il divisorio: da dove si parte non si vede. Si prende mandando il
	# dardo sulla sponda della parete di mattoni — ed è tutto il gioco.
	_nascosto = _aggiungi(Vector3(-4.0, 0, -5.5), Vector3(-4.0, 0, -5.5), 0.0, verde)


func _aggiungi(da: Vector3, a: Vector3, velocita: float, colore: Color) -> Bersaglio:
	var bersaglio := Bersaglio.crea(self, da, a, velocita, colore)
	bersaglio.centrato.connect(_su_bersaglio_centrato)
	_bersagli.append(bersaglio)
	return bersaglio
