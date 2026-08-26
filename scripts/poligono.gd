extends Node3D

## Il poligono di tiro: la tappa 1.
##
## Non è un livello, è la risposta a una domanda sola (PLAN.md): **un rimbalzo a
## cinque muri, mirato con il pollice, è divertente?** Perciò qui c'è solo quello
## che serve a rispondere — una stanza, un'arma, il dardo, la linea di mira,
## bersagli che si muovono e due bersagli che si possono prendere **solo** di
## sponda, perché stanno dietro un angolo.
##
## La stanza è costruita da codice, da una tabella di blocchi: una scena scritta
## a mano può essere valida e inquadrare il vuoto (LEARNED.md 14), mentre questa
## si legge, si misura e domani genera le arene vere.
##
## Dalla tappa 2 la stanza ha due mestieri: **poligono** com'era, e **sfida** —
## il pulsante SFIDA fa entrare l'avversario e mette da parte i bersagli. È la
## stessa stanza perché la domanda della tappa 2 è un'altra: non «il rimbalzo si
## mira?», ma «un avversario che schiva rende l'anticipo una bravura?».

const LARGHEZZA := 30.0
const PROFONDITA := 20.0
const ALTEZZA := 7.0
const SPESSORE := 0.6

## I tre candidati per il colore riservato al proiettile. Si confermano qui, sulla
## scena vera con la luce vera, non su un campionario (DECISIONI.md § B).
## Nessuna superficie della stanza usa nessuno dei tre a piena saturazione.
const CANDIDATI := [
	{"nome": "bianco-arancio", "colore": Color(1.0, 0.62, 0.24)},
	{"nome": "ciano-bianco", "colore": Color(0.35, 0.9, 1.0)},
	{"nome": "magenta-bianco", "colore": Color(1.0, 0.36, 0.78)},
]

## Si vince a 500. Tu ne fai 25 con un colpo diretto e raddoppi a ogni muro; lui
## spara solo dritto, quindi vale sempre 25. Il conto dice da solo qual è il
## gioco: giocando dritto siete pari, e si vince di sponda.
const TRAGUARDO := 500
const PARTENZA_GIOCATORE := Vector3(-9.0, 0.2, 6.5)
const PARTENZA_AVVERSARIO := Vector3(10.0, 0.2, 2.0)

## I tasti della lavorazione: sul PC si prova senza toccare i pulsanti.
const SCORCIATOIE := {KEY_C: "colore", KEY_B: "sfida", KEY_L: "livello", KEY_A: "arena"}

var _giocatore: Giocatore
var _comandi: Comandi
var _bersagli: Array[Bersaglio] = []
var _punteggio := 0
var _migliore := 0
var _migliore_muri := 0
var _candidato := 0
var _tasti := {}

var _avversario: Avversario
var _sfida := false
var _finita := false
var _livello := 1
var _punti_tu := 0
var _punti_lui := 0


func _ready() -> void:
	_ambiente()
	_stanza()
	_luci()
	_insegne()
	_bersagli_del_poligono()
	_comandi = Comandi.new()
	add_child(_comandi)
	_comandi.colore_richiesto.connect(_cambia_colore)
	_comandi.camera_richiesta.connect(func() -> void: _giocatore.cambia_camera())
	_comandi.sfida_richiesta.connect(commuta_sfida)
	_comandi.livello_richiesto.connect(cambia_livello)
	# Dalla tappa 3 le stanze sono due: qui si collauda, di là si guarda.
	_comandi.pulsante_di_scena("ARENA", Color(0.35, 0.4, 0.55), vai_all_angolo)
	_giocatore = Giocatore.new()
	add_child(_giocatore)
	_giocatore.global_position = PARTENZA_GIOCATORE
	_giocatore.rotation.y = deg_to_rad(20.0)
	_giocatore.comandi = _comandi
	_giocatore.incassato.connect(_su_giocatore_incassato)
	_aggiorna_righe()


## Servono agli attrezzi di lavorazione, che pilotano la scena per gli scatti.
func giocatore() -> Giocatore:
	return _giocatore


func nome_colore() -> String:
	return String(CANDIDATI[_candidato]["nome"])


func passa_al_colore_seguente() -> void:
	_cambia_colore()


func _process(_delta: float) -> void:
	_aggiorna_righe()
	if _sfida and not _finita:
		_controlla_il_traguardo()
	for tasto in SCORCIATOIE:
		var giu := Input.is_physical_key_pressed(tasto)
		if giu and not bool(_tasti.get(tasto, false)):
			match String(SCORCIATOIE[tasto]):
				"colore": _cambia_colore()
				"sfida": commuta_sfida()
				"livello": cambia_livello()
				"arena": vai_all_angolo()
		_tasti[tasto] = giu


func _aggiorna_righe() -> void:
	if _comandi == null:
		return
	var visuale := "prima persona" if _giocatore != null and _giocatore.in_prima_persona() else "terza persona"
	if _sfida:
		_comandi.scrivi_alto("TU %d — LUI %d   (a %d)" % [_punti_tu, _punti_lui, TRAGUARDO])
		_comandi.scrivi_basso("avversario %s · %s · dardo %s · %d fps" % [
			Avversario.TARATURE[_livello]["nome"], visuale,
			CANDIDATI[_candidato]["nome"], Engine.get_frames_per_second()])
		return
	_comandi.scrivi_alto("%d punti" % _punteggio)
	var migliore := "—" if _migliore == 0 else "%d con %d muri" % [_migliore, _migliore_muri]
	_comandi.scrivi_basso("miglior colpo: %s · %s · dardo %s · %d fps" % [
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


## L'interruttore. Acceso: entra l'avversario, i bersagli si fanno da parte e i
## punteggi ripartono da zero. Spento: la stanza torna il poligono di prima.
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

	if _avversario == null or not is_instance_valid(_avversario):
		_avversario = Avversario.crea(self, PARTENZA_AVVERSARIO, _livello)
		_avversario.centrato.connect(_su_avversario_centrato)
		_avversario.ha_centrato.connect(_su_avversario_ha_centrato)
	_avversario.global_position = PARTENZA_AVVERSARIO
	_avversario.velocity = Vector3.ZERO
	_avversario.imposta_livello(_livello)
	_avversario.bersaglio = _giocatore
	_giocatore.global_position = PARTENZA_GIOCATORE
	_giocatore.punta(20.0, -3.0)

	_comandi.scrivi_sfida("CHIUDI")
	_comandi.annuncia("SFIDA · %s" % Avversario.TARATURE[_livello]["nome"].to_upper())


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
	_comandi.annuncia("POLIGONO")


## Il livello si cambia dentro la partita: i tre si confrontano col pollice nella
## stessa stanza, non leggendo una tabella.
func cambia_livello() -> void:
	_livello = (_livello + 1) % Avversario.TARATURE.size()
	if _avversario != null and is_instance_valid(_avversario):
		_avversario.imposta_livello(_livello)
	_comandi.annuncia(String(Avversario.TARATURE[_livello]["nome"]).to_upper())


## L'angolo di arena della tappa 3: si va e si torna con lo stesso pulsante, per
## poter confrontare col pollice la stanza dei collaudi e l'arena vera.
func vai_all_angolo() -> void:
	get_tree().change_scene_to_file("res://scenes/angolo.tscn")


func in_sfida() -> bool:
	return _sfida


func avversario() -> Avversario:
	return _avversario


func punteggi() -> Array:
	return [_punti_tu, _punti_lui]


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


func _su_avversario_ha_centrato(punti: int, _muri: int) -> void:
	if _finita:
		return
	_punti_lui += punti


func _su_giocatore_incassato(_punti: int, _muri: int) -> void:
	if _sfida and not _finita:
		_comandi.annuncia("COLPITO")


## Chi arriva prima a 500. Finita la partita l'avversario smette di giocare, e il
## pulsante SFIDA ne comincia un'altra da zero.
func _controlla_il_traguardo() -> void:
	if _punti_tu < TRAGUARDO and _punti_lui < TRAGUARDO:
		return
	_finita = true
	if _avversario != null and is_instance_valid(_avversario):
		_avversario.bersaglio = null
	_comandi.scrivi_sfida("ANCORA")
	_comandi.annuncia("HAI VINTO" if _punti_tu >= TRAGUARDO else "HAI PERSO")


## L'ambiente. La soglia del bagliore sta a 1.0: sopra ci va solo il proiettile,
## e nessuna superficie della stanza la tocca. È la regola che tiene insieme
## «mondo saturo» e «dardo sempre leggibile» (DECISIONI.md § B).
func _ambiente() -> void:
	var mondo := WorldEnvironment.new()
	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color(0.05, 0.06, 0.12)
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color(0.42, 0.5, 0.78)
	ambiente.ambient_light_energy = 0.62
	ambiente.tonemap_mode = Environment.TONE_MAPPER_ACES
	ambiente.glow_enabled = true
	ambiente.glow_intensity = 1.1
	ambiente.glow_bloom = 0.12
	ambiente.glow_hdr_threshold = 1.0
	ambiente.fog_enabled = false
	mondo.environment = ambiente
	add_child(mondo)


func _stanza() -> void:
	var blu := Color(0.14, 0.30, 0.78)
	var viola := Color(0.38, 0.17, 0.66)
	var acqua := Color(0.10, 0.44, 0.44)
	var pavimento := Color(0.15, 0.17, 0.36)
	var soffitto := Color(0.12, 0.14, 0.30)
	var meta_x := LARGHEZZA * 0.5
	var meta_z := PROFONDITA * 0.5

	_blocco(Vector3(0, -SPESSORE * 0.5, 0), Vector3(LARGHEZZA, SPESSORE, PROFONDITA), pavimento, 0.07)
	_blocco(Vector3(0, ALTEZZA + SPESSORE * 0.5, 0), Vector3(LARGHEZZA, SPESSORE, PROFONDITA), soffitto, 0.06)

	_blocco(Vector3(0, ALTEZZA * 0.5, -meta_z - SPESSORE * 0.5), Vector3(LARGHEZZA, ALTEZZA, SPESSORE), blu, 0.14)
	_blocco(Vector3(0, ALTEZZA * 0.5, meta_z + SPESSORE * 0.5), Vector3(LARGHEZZA, ALTEZZA, SPESSORE), viola, 0.14)
	_blocco(Vector3(-meta_x - SPESSORE * 0.5, ALTEZZA * 0.5, 0), Vector3(SPESSORE, ALTEZZA, PROFONDITA), viola, 0.14)
	_blocco(Vector3(meta_x + SPESSORE * 0.5, ALTEZZA * 0.5, 0), Vector3(SPESSORE, ALTEZZA, PROFONDITA), blu, 0.14)

	_arredo(meta_x, meta_z, acqua)

	# Il divisorio: è lui che crea l'angolo cieco, cioè il motivo per cui esiste
	# questa stanza. Due bersagli stanno dietro e non si vedono dalla partenza.
	_blocco(Vector3(2.0, 2.0, -6.0), Vector3(0.7, 4.0, 8.0), acqua, 0.22)

	# Due pilastri: copertura mobile e sponde per il tiro d'angolo.
	_blocco(Vector3(-6.0, 2.5, 2.0), Vector3(1.3, 5.0, 1.3), acqua, 0.2)
	_blocco(Vector3(7.5, 2.5, 4.5), Vector3(1.3, 5.0, 1.3), acqua, 0.2)

	# Piattaforma con rampa: serve a sparare dall'alto e a leggere il rimbalzo
	# sul pavimento, che è il muro che tutti dimenticano.
	_blocco(Vector3(-10.5, 0.6, -6.0), Vector3(7.0, 1.2, 5.0), blu, 0.12)
	var rampa := _blocco(Vector3(-10.5, 0.55, -2.6), Vector3(7.0, 0.25, 3.2), blu, 0.12)
	rampa.rotation.x = deg_to_rad(-12.0)


## Zoccoli, cornici al neon e segnatura a terra. Non è vernice: senza, una stanza
## di scatole tutte dello stesso blu non dice dove finisce il pavimento, e le
## distanze non si leggono. Sono decori puri — niente collisione, così nessun
## dardo rimbalza su una striscia dipinta.
func _arredo(meta_x: float, meta_z: float, acqua: Color) -> void:
	var neon := Color(0.35, 0.95, 0.85)
	var segnatura := Color(0.62, 0.80, 0.96)
	var alto := ALTEZZA - 0.4

	for parete in [
		{"pos": Vector3(0, 0, -meta_z + 0.06), "misura": Vector3(LARGHEZZA, 1.0, 0.12)},
		{"pos": Vector3(0, 0, meta_z - 0.06), "misura": Vector3(LARGHEZZA, 1.0, 0.12)},
		{"pos": Vector3(-meta_x + 0.06, 0, 0), "misura": Vector3(0.12, 1.0, PROFONDITA)},
		{"pos": Vector3(meta_x - 0.06, 0, 0), "misura": Vector3(0.12, 1.0, PROFONDITA)},
	]:
		var base: Vector3 = parete["pos"]
		var misura: Vector3 = parete["misura"]
		_decoro(base + Vector3(0, 0.5, 0), misura, acqua, 0.2)
		_decoro(base + Vector3(0, alto, 0), Vector3(misura.x, 0.22, misura.z), neon, 0.75)

	# La segnatura a terra: campo da gioco, e un metro per misurare le distanze.
	_decoro(Vector3(0, 0.012, 0), Vector3(LARGHEZZA, 0.02, 0.16), segnatura, 0.3)
	_decoro(Vector3(0, 0.012, -7.0), Vector3(LARGHEZZA, 0.02, 0.1), segnatura, 0.22)
	_decoro(Vector3(0, 0.012, 7.0), Vector3(LARGHEZZA, 0.02, 0.1), segnatura, 0.22)

	var cerchio := MeshInstance3D.new()
	var anello := TorusMesh.new()
	anello.inner_radius = 3.1
	anello.outer_radius = 3.25
	anello.rings = 32
	anello.ring_segments = 8
	cerchio.mesh = anello
	cerchio.position = Vector3(0, 0.012, 0)
	cerchio.material_override = _materiale_superficie(segnatura, 0.3)
	add_child(cerchio)


func _decoro(centro: Vector3, misura: Vector3, colore: Color, luce: float) -> void:
	var pezzo := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = misura
	pezzo.mesh = mesh
	pezzo.position = centro
	pezzo.material_override = _materiale_superficie(colore, luce)
	add_child(pezzo)


func _luci() -> void:
	var sole := DirectionalLight3D.new()
	# Le dodici cifre di Transform3D sono le RIGHE della matrice, non le colonne:
	# scambiarle mette la luce a illuminare il cielo (LEARNED.md 14).
	sole.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sole.light_energy = 0.9
	sole.light_color = Color(1.0, 0.95, 0.88)
	sole.shadow_enabled = true
	add_child(sole)

	# Luce colorata addosso alle pareti: è l'anima del gioco del 1999, e non si
	# ottiene con le texture ma con le lampade.
	_lampada(Vector3(-9.0, 5.4, -5.0), Color(0.35, 0.55, 1.0), 4.4, 22.0)
	_lampada(Vector3(9.0, 5.4, -4.0), Color(0.78, 0.35, 1.0), 4.2, 22.0)
	_lampada(Vector3(0.0, 5.6, 6.0), Color(0.3, 0.95, 0.8), 3.6, 20.0)
	# Verde lime, non ambra: una lampada arancione tingerebbe le pareti del colore
	# del dardo, e quel colore è riservato a lui solo.
	_lampada(Vector3(-11.0, 3.2, 8.0), Color(0.62, 1.0, 0.38), 2.6, 16.0)


func _lampada(dove: Vector3, colore: Color, forza: float, portata: float) -> void:
	var luce := OmniLight3D.new()
	luce.position = dove
	luce.light_color = colore
	luce.light_energy = forza
	luce.omni_range = portata
	luce.shadow_enabled = false
	add_child(luce)


## Le insegne al neon dentro l'arena: arredo di gara e segnaletica insieme.
## Restano sotto la soglia del bagliore, come tutto il resto del mondo.
func _insegne() -> void:
	# Le insegne stanno **staccate** dalla parete di qualche centimetro: appoggiate
	# esattamente sopra, le due superfici si contendono lo stesso piano e il testo
	# viene fuori a strisce.
	_insegna("PENTAWALL", Vector3(0, 5.2, -9.94), Vector3.ZERO, 1.9, Color(0.55, 0.8, 1.0))
	_insegna("5 MURI", Vector3(-14.94, 4.4, -1.0), Vector3(0, 90, 0), 1.4, Color(0.95, 0.85, 0.4))
	_insegna("PUNTI", Vector3(14.94, 4.4, 1.0), Vector3(0, -90, 0), 1.4, Color(0.6, 0.95, 0.75))
	_insegna("SPONDA", Vector3(2.41, 3.2, -6.0), Vector3(0, 90, 0), 0.85, Color(0.5, 0.95, 0.9))


func _insegna(testo: String, dove: Vector3, giro: Vector3, misura: float, colore: Color) -> void:
	var insegna := Label3D.new()
	insegna.text = testo
	insegna.font_size = 160
	insegna.pixel_size = misura * 0.006
	insegna.position = dove
	insegna.rotation_degrees = giro
	insegna.modulate = Color(colore.r * 0.92, colore.g * 0.92, colore.b * 0.92)
	insegna.outline_size = 26
	insegna.outline_modulate = Color(0.02, 0.02, 0.06, 0.85)
	insegna.shaded = false
	insegna.double_sided = false
	# Senza questo il testo viene fuori a strisce: la trasparenza normale, in
	# modalità Compatibility, lo disegna a puntini invece che pieno.
	insegna.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	add_child(insegna)


func _bersagli_del_poligono() -> void:
	var azzurro := Color(0.24, 0.72, 1.0)
	var verde := Color(0.3, 0.9, 0.55)

	# Allo scoperto: servono a tarare la mira diretta e l'anticipo.
	_aggiungi(Vector3(-4.0, 0, -7.5), Vector3(0.0, 0, -7.5), 3.2, azzurro)
	_aggiungi(Vector3(11.0, 0, 7.0), Vector3(11.0, 0, -0.5), 4.2, azzurro)
	_aggiungi(Vector3(-11.0, 1.2, -7.0), Vector3(-11.0, 1.2, -4.5), 2.4, azzurro)

	# Dietro l'angolo: da dove si parte non si vedono. Questi due sono il gioco.
	_aggiungi(Vector3(6.0, 0, -8.0), Vector3(6.0, 0, -8.0), 0.0, verde)
	_aggiungi(Vector3(9.0, 0, 6.0), Vector3(9.0, 0, 6.0), 0.0, verde)


func _aggiungi(da: Vector3, a: Vector3, velocita: float, colore: Color) -> void:
	var bersaglio := Bersaglio.crea(self, da, a, velocita, colore)
	bersaglio.centrato.connect(_su_bersaglio_centrato)
	_bersagli.append(bersaglio)


## Un blocco della stanza: la parte che si vede e la parte che ferma il dardo,
## sempre insieme, così non può succedere che rimbalzi su niente o attraversi
## una parete che c'è.
func _blocco(centro: Vector3, misura: Vector3, colore: Color, luce: float) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.collision_layer = Strati.MONDO
	corpo.collision_mask = 0
	corpo.position = centro
	add_child(corpo)

	var forma := CollisionShape3D.new()
	var scatola := BoxShape3D.new()
	scatola.size = misura
	forma.shape = scatola
	corpo.add_child(forma)

	var pezzo := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = misura
	pezzo.mesh = mesh
	pezzo.material_override = _materiale_superficie(colore, luce)
	corpo.add_child(pezzo)
	return corpo


## Una superficie del mondo: satura quanto si vuole, ma **mai sopra il bianco**.
## La soglia del bagliore è a 1.0 e sopra ci va solo il dardo: è così che il mondo
## resta acceso come nel 1999 e il proiettile resta leggibile lo stesso, senza
## spegnere niente (DECISIONI.md § B).
func _materiale_superficie(colore: Color, luce: float) -> StandardMaterial3D:
	var materiale := StandardMaterial3D.new()
	materiale.albedo_color = colore
	materiale.roughness = 0.62
	materiale.metallic = 0.05
	materiale.emission_enabled = true
	materiale.emission = colore
	materiale.emission_energy_multiplier = luce
	return materiale
