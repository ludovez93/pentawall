class_name Ingresso
extends Control

## La schermata d'ingresso.
##
## Fino al 17/09/2026 il gioco si apriva nel **poligono**, che è un banco di prova;
## dal 17/09 su una schermata scura col nome e GIOCA. **Dal 03/10/2026 (tappa 8,
## blocco I) c'è il tuo personaggio**: in piedi su una pedana al neon, col blaster in
## mano, che respira mentre la camera gli gira attorno piano, con la musica
## d'ingresso. È il primo secondo del gioco, quello che decide se sembra vero.
##
## I banchi di prova non spariscono — servono a noi — ma stanno **dietro un
## gesto**: cinque tocchi sulla riga della versione, in basso a destra. È la
## stessa riga che dice quale pubblicazione sta servendo la pagina, e che si
## guarda quando un difetto «non si è chiuso» (`LEARNED.md` § 32).
##
## Il pulsante del dardo (19 o 24) se n'è andato da qui: dal 03/10/2026 si parte a
## 24, e la manopola resta nei banchi di prova.

const TOCCHI_PER_APRIRE := 5

## Quanto gira la camera attorno al personaggio: avanti e indietro, non un giro
## intero — il personaggio deve restare di tre quarti, armato verso chi guarda.
const GIRO_CAMERA := 0.42
const PERIODO_CAMERA := 14.0
const CENTRO := Vector3(0.0, 1.0, 0.0)

var _versione := "locale"
var _riga_versione: Button
var _tocchi := 0
var _banco: HBoxContainer
var _palco: Node3D
var _camera: Camera3D
var _corpo: Corpo
var _tempo := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scena()
	_velo()
	_titolo()
	_pulsanti()
	_leggi_la_versione()
	# Chi torna qui dal podio non deve ritrovarsi in partita al tocco seguente.
	Arena.modo_partita = false
	add_child(Suoni.new())
	Suoni.musica("musica_ingresso")


func _process(delta: float) -> void:
	_tempo += delta
	if _camera != null:
		var giro := sin(_tempo * TAU / PERIODO_CAMERA) * GIRO_CAMERA - 0.35
		var dove := Vector3(sin(giro) * 4.6, 1.5, cos(giro) * 4.6)
		# Si guarda un po' a sinistra del personaggio, così lui sta nella metà destra
		# dello schermo e la sinistra resta al nome e a GIOCA.
		var verso := (CENTRO - dove).normalized()
		var destra := verso.cross(Vector3.UP).normalized()
		_camera.look_at_from_position(dove, CENTRO - destra * 1.05)
	if _corpo != null:
		_corpo.aggiorna(Vector3.ZERO, true, 0.0, delta)


# ------------------------------------------------------------------ il palco

## Il palco: una pedana tonda al neon in una stanza buia, due luci di taglio nei
## colori dell'arena e il personaggio in mezzo. Sta dietro all'interfaccia, nella
## stessa finestra: è un mondo 3D come l'arena, solo più piccolo.
func _scena() -> void:
	_palco = Node3D.new()
	_palco.name = "palco"
	add_child(_palco)

	var mondo := WorldEnvironment.new()
	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color(0.03, 0.025, 0.07)
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color(0.42, 0.38, 0.62)
	ambiente.ambient_light_energy = 0.55
	ambiente.tonemap_mode = Environment.TONE_MAPPER_ACES
	ambiente.glow_enabled = true
	ambiente.glow_intensity = 0.9
	ambiente.glow_bloom = 0.1
	ambiente.glow_hdr_threshold = 1.0
	ambiente.fog_enabled = true
	ambiente.fog_light_color = Color(0.10, 0.07, 0.22)
	ambiente.fog_density = 0.035
	mondo.environment = ambiente
	_palco.add_child(mondo)

	var chiave := DirectionalLight3D.new()
	chiave.rotation_degrees = Vector3(-38.0, 28.0, 0.0)
	chiave.light_energy = 1.25
	chiave.light_color = Color(1.0, 0.95, 0.92)
	_palco.add_child(chiave)
	# Le due luci di taglio: ciano da una parte, viola dall'altra, come i neon.
	_luce(Vector3(-2.6, 2.4, -1.6), Color(0.35, 0.95, 1.0), 7.0)
	_luce(Vector3(2.4, 2.6, -1.8), Vestizione.NEON, 7.0)
	_luce(Vector3(0.0, 0.5, 1.8), Color(0.55, 0.45, 1.0), 1.8)

	# La pedana: un disco smussato scuro con l'anello al neon sul bordo.
	var pedana := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 1.25
	disco.bottom_radius = 1.32
	disco.height = 0.22
	disco.radial_segments = 48
	pedana.mesh = disco
	pedana.position = Vector3(0, -0.11, 0)
	var lamiera := Vestizione.materiale_di("soffitto").duplicate() as StandardMaterial3D
	lamiera.albedo_color = Color(0.16, 0.14, 0.26)
	lamiera.emission_energy_multiplier = 0.0
	pedana.material_override = lamiera
	_palco.add_child(pedana)
	for raggio in [1.27, 2.2, 3.4]:
		var anello := MeshInstance3D.new()
		var toro := TorusMesh.new()
		toro.inner_radius = raggio - (0.035 if raggio > 1.3 else 0.05)
		toro.outer_radius = raggio
		toro.rings = 72
		toro.ring_segments = 6
		anello.mesh = toro
		anello.scale = Vector3(1, 0.3, 1)
		anello.position = Vector3(0, 0.0 if raggio < 1.3 else -0.2, 0)
		anello.material_override = Muratura.acceso(Vestizione.NEON if raggio < 3.0
				else Color(0.30, 0.99, 0.95), 0.9 if raggio < 1.3 else 0.5)
		anello.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_palco.add_child(anello)
	# Il pavimento della stanza, quasi nero, perché la pedana si stacchi.
	var pavimento := MeshInstance3D.new()
	var piano := PlaneMesh.new()
	piano.size = Vector2(40, 40)
	pavimento.mesh = piano
	pavimento.position = Vector3(0, -0.21, 0)
	var scuro := StandardMaterial3D.new()
	scuro.albedo_color = Color(0.06, 0.05, 0.11)
	scuro.roughness = 0.35
	pavimento.material_override = scuro
	_palco.add_child(pavimento)
	# Sul fondo, le strisce al neon di una palestra lontana.
	for i in 4:
		var striscia := MeshInstance3D.new()
		var tubo := BoxMesh.new()
		tubo.size = Vector3(9.0, 0.06, 0.06)
		striscia.mesh = tubo
		striscia.position = Vector3(2.5, 0.5 + 1.2 * i, -7.5)
		striscia.material_override = Muratura.acceso(Vestizione.NEON if i % 2 == 0
				else Color(0.30, 0.99, 0.95), 0.75)
		_palco.add_child(striscia)

	_corpo = Corpo.crea("TU")
	_palco.add_child(_corpo)
	# Girato di tre quarti verso chi guarda: il blaster punta fuori dallo schermo.
	_corpo.rotation.y = PI - 0.45

	_camera = Camera3D.new()
	_camera.fov = 38.0
	_camera.current = true
	_palco.add_child(_camera)
	_camera.look_at_from_position(Vector3(-1.5, 1.55, 4.2), Vector3(0.0, 1.05, 0.0))


func _luce(dove: Vector3, colore: Color, forza: float) -> void:
	var luce := OmniLight3D.new()
	luce.position = dove
	luce.light_color = colore
	luce.light_energy = forza
	luce.omni_range = 7.0
	_palco.add_child(luce)


## Un velo scuro a sinistra, dove stanno il nome e GIOCA: il personaggio resta a
## destra, pulito, e le scritte si leggono anche sopra le luci.
func _velo() -> void:
	var velo := GradientTexture2D.new()
	velo.width = 256
	velo.height = 4
	velo.fill_from = Vector2(0.0, 0.5)
	velo.fill_to = Vector2(1.0, 0.5)
	var sfumatura := Gradient.new()
	sfumatura.set_color(0, Color(0.02, 0.02, 0.05, 0.88))
	sfumatura.set_color(1, Color(0.02, 0.02, 0.05, 0.0))
	sfumatura.add_point(0.42, Color(0.02, 0.02, 0.05, 0.55))
	velo.gradient = sfumatura
	var quadro := TextureRect.new()
	quadro.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	quadro.offset_right = 900
	quadro.texture = velo
	quadro.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	quadro.stretch_mode = TextureRect.STRETCH_SCALE
	quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(quadro)


# ------------------------------------------------------------------ l'interfaccia

func _titolo() -> void:
	var nome := Label.new()
	nome.text = "PENTAWALL"
	nome.set_anchors_preset(Control.PRESET_TOP_LEFT)
	nome.position = Vector2(84, 130)
	nome.add_theme_font_override("font", _titolo_spaziato())
	nome.add_theme_font_size_override("font_size", 104)
	nome.add_theme_color_override("font_color", Color(1, 1, 1, 0.98))
	nome.add_theme_color_override("font_outline_color", Color(0.62, 0.30, 1.0, 0.55))
	nome.add_theme_constant_override("outline_size", 12)
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nome)

	var filo := ColorRect.new()
	filo.color = Color(0.35, 0.95, 0.92, 0.85)
	filo.position = Vector2(90, 262)
	filo.size = Vector2(120, 4)
	filo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(filo)

	var sotto := Label.new()
	sotto.text = "IL DARDO RIMBALZA FINO A CINQUE MURI"
	sotto.position = Vector2(90, 280)
	sotto.add_theme_font_override("font", Comandi.carattere_testo())
	sotto.add_theme_font_size_override("font_size", 24)
	sotto.add_theme_color_override("font_color", Color(1, 1, 1, 0.66))
	sotto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sotto)


## Il carattere del titolo con le lettere staccate: a cento punti, attaccate,
## PENTAWALL è un blocco.
func _titolo_spaziato() -> Font:
	var variante := FontVariation.new()
	variante.base_font = Comandi.carattere_titolo()
	variante.spacing_glyph = 10
	return variante


func _pulsanti() -> void:
	var gioca := Button.new()
	gioca.text = "GIOCA"
	gioca.position = Vector2(90, 360)
	gioca.custom_minimum_size = Vector2(340, 112)
	gioca.add_theme_font_override("font", Comandi.carattere_titolo())
	gioca.add_theme_font_size_override("font_size", 46)
	gioca.add_theme_color_override("font_color", Color(0.04, 0.03, 0.08))
	gioca.add_theme_color_override("font_pressed_color", Color(0.04, 0.03, 0.08))
	gioca.add_theme_color_override("font_hover_color", Color(0.04, 0.03, 0.08))
	for stato in ["normal", "hover", "focus"]:
		gioca.add_theme_stylebox_override(stato, _pieno(Color(0.40, 1.0, 0.92), 0.0))
	gioca.add_theme_stylebox_override("pressed", _pieno(Color(0.30, 0.86, 0.80), 3.0))
	gioca.pressed.connect(_comincia)
	add_child(gioca)

	# Il banco di prova: c'è, ma spento, finché non lo si chiama col gesto.
	_banco = HBoxContainer.new()
	_banco.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_banco.offset_left = 90
	_banco.offset_top = -150
	_banco.offset_bottom = -82
	_banco.add_theme_constant_override("separation", 14)
	_banco.visible = false
	add_child(_banco)
	_banco.add_child(_pulsante("ARENA LIBERA", Vector2(210, 68), Color(0.35, 0.45, 0.7),
			func() -> void: _vai("res://scenes/arena.tscn")))
	_banco.add_child(_pulsante("POLIGONO", Vector2(180, 68), Color(0.35, 0.4, 0.55),
			func() -> void: _vai("res://scenes/poligono.tscn")))
	_banco.add_child(_pulsante("ANGOLO", Vector2(170, 68), Color(0.35, 0.4, 0.55),
			func() -> void: _vai("res://scenes/angolo.tscn")))

	_riga_versione = _pulsante("", Vector2(238, 52), Color(0, 0, 0), _tocco)
	_riga_versione.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_riga_versione.offset_left = -260
	_riga_versione.offset_right = -22
	_riga_versione.offset_top = -80
	_riga_versione.offset_bottom = -28
	_riga_versione.add_theme_font_size_override("font_size", 17)
	_riga_versione.add_theme_font_override("font", Comandi.carattere_testo())
	_riga_versione.add_theme_color_override("font_color", Color(1, 1, 1, 0.32))
	for stato in ["normal", "hover", "focus", "pressed"]:
		_riga_versione.add_theme_stylebox_override(stato, StyleBoxEmpty.new())
	add_child(_riga_versione)
	_scrivi_la_versione()


## Il fondo di GIOCA: pieno, acceso, con un'ombra morbida sotto invece del bordo a
## caramella — il pulsante del 2026 è un oggetto illuminato, non un rilievo.
func _pieno(colore: Color, schiacciato: float) -> StyleBoxFlat:
	var stile := StyleBoxFlat.new()
	stile.bg_color = colore
	stile.set_corner_radius_all(28)
	stile.shadow_color = Color(colore.r, colore.g, colore.b, 0.35)
	stile.shadow_size = int(18 - schiacciato * 4)
	stile.shadow_offset = Vector2(0, 6 - schiacciato)
	stile.content_margin_top = schiacciato
	return stile


func _pulsante(testo: String, misura: Vector2, colore: Color, azione: Callable) -> Button:
	var pulsante := Button.new()
	pulsante.text = testo
	pulsante.custom_minimum_size = misura
	pulsante.add_theme_font_size_override("font_size", 24)
	pulsante.add_theme_font_override("font", Comandi.carattere_titolo())
	pulsante.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	for stato in ["normal", "hover", "focus"]:
		pulsante.add_theme_stylebox_override(stato, _sfondo(colore, 0.55))
	pulsante.add_theme_stylebox_override("pressed", _sfondo(colore, 0.85))
	pulsante.pressed.connect(azione)
	return pulsante


func _sfondo(colore: Color, opacita: float) -> StyleBoxFlat:
	var stile := StyleBoxFlat.new()
	stile.bg_color = Color(colore.r, colore.g, colore.b, opacita)
	stile.set_corner_radius_all(22)
	return stile


func _comincia() -> void:
	Suoni.tocco()
	Arena.modo_partita = true
	_vai("res://scenes/arena.tscn")


func _vai(scena: String) -> void:
	get_tree().change_scene_to_file(scena)


## Il gesto nascosto: cinque tocchi sulla riga della versione.
func _tocco() -> void:
	_tocchi += 1
	if _tocchi < TOCCHI_PER_APRIRE:
		return
	_banco.visible = true
	_riga_versione.add_theme_color_override("font_color", Color(0.35, 0.95, 0.92, 0.7))


## Se il banco di prova è aperto. Serve al collaudo, che deve poter dire se il
## gesto funziona senza guardare lo schermo.
func banco_aperto() -> bool:
	return _banco != null and _banco.visible


## Il personaggio sul palco: serve al collaudo.
func personaggio() -> Corpo:
	return _corpo


## La versione la conosce solo la pagina: `versione.txt` lo scrive la lavorazione
## accanto al gioco. Sul PC non c'è, e la riga dice «locale».
func _leggi_la_versione() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		window.__pw_v = window.__pw_v || '?';
		fetch('versione.txt', {cache: 'no-cache'})
			.then(function (r) { return r.text(); })
			.then(function (t) { window.__pw_v = t.trim().slice(0, 7); })
			.catch(function () {});
	""")
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var letta: Variant = JavaScriptBridge.eval("String(window.__pw_v || '?')", true)
		if letta is String:
			_versione = String(letta)
		_scrivi_la_versione())


func _scrivi_la_versione() -> void:
	if _riga_versione != null:
		_riga_versione.text = "versione %s" % _versione
