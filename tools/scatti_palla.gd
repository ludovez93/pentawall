extends SceneTree

## Attrezzo di lavorazione: **la PALLA fotografata alle misure del telefono** (tappa 11,
## blocco D2). Si entra dalla strada vera — la Home, PALLA, GIOCA — e poi si mette il
## giocatore dove serve: al via, davanti a una porta, con due palle addosso (il pulsante
## LANCIA, l'arco e i pallini), un attimo dopo il lancio e sul podio.
##
## Vuole la finestra: senza schermo il fotogramma non c'è e resta appeso.
##   godot --path . --resolution 854x390 -s tools/scatti_palla.gd [-- <variante>]

const CARTELLA := "res://scatti"


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var aspetto_di_prima := Aspetto.scelta()
	var modalita_di_prima := Modalita.scelta()
	if argomenti.size() > 0:
		Aspetto.scegli(int(argomenti[0]))
	var prefisso := "P%d" % Aspetto.scelta()
	Modalita.scegli(Modalita.SCONTRO)
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = 0.75
	var ingresso: Node = load("res://scenes/ingresso.tscn").instantiate()
	root.add_child(ingresso)
	current_scene = ingresso
	await _riposa(6)
	var pulsanti: Array = ingresso.get("_modalita")
	(pulsanti[Modalita.PALLA] as Button).pressed.emit()
	var scadenza := Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < scadenza and ingresso.get("_arena_pronta") == null:
		await process_frame
	await _riposa(4)
	await _scatta(prefisso + "-1-home.png")

	ingresso.call("_comincia")
	await _riposa(4)
	var arena := current_scene as Arena
	scadenza = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < scadenza and arena.conto_alla_rovescia() > 0.0:
		await process_frame
	await _riposa(30)
	await _scatta(prefisso + "-2-via.png")

	for bot in arena.avversari():
		bot.process_mode = Node.PROCESS_MODE_DISABLED
	var palle := arena.palle()
	var tu := arena.giocatore()

	# Davanti alla porta della tribuna, a nove metri, guardandola.
	var davanti := palle.davanti_alla_porta(1, 9.0)
	await _metti(tu, davanti, Bandiere.giro_verso(davanti, palle.centro_della_porta(1)), -2.0)
	await _scatta(prefisso + "-3-porta.png")

	# Con due palle addosso, mirando la porta: il pulsante LANCIA, l'arco, i pallini.
	var blu := palle.palle()[0]
	var rossa := palle.palle()[4]
	blu.prendi(tu)
	rossa.prendi(tu)
	(arena.get("_concorrenti")[0]["segnate"] as Array).append(2)
	await _metti(tu, davanti, Bandiere.giro_verso(davanti, palle.centro_della_porta(1)), 6.0)
	await _riposa(20)
	await _scatta(prefisso + "-4-porto-due-palle.png")

	# Il lancio, un attimo dopo.
	arena.call("_lancia_la_tua")
	await _riposa(14)
	await _scatta(prefisso + "-5-lancio.png")
	await _riposa(60)
	await _scatta(prefisso + "-6-dopo-il-lancio.png")

	# Il podio: le sei già segnate, e la dorata in porta.
	var riga: Dictionary = arena.get("_concorrenti")[0]
	riga["segnate"] = [0, 1, 2, 3, 4, 5]
	var dorata := palle.dorata()
	dorata.prendi(tu)
	palle.lancia(tu, dorata, Vector3.ZERO)
	dorata.global_position = palle.centro_della_porta(1)
	dorata.linear_velocity = Vector3.ZERO
	await _riposa(50)
	await _scatta(prefisso + "-7-podio.png")

	Aspetto.scegli(aspetto_di_prima)
	Modalita.scegli(modalita_di_prima)
	print("fatto.")
	quit()


func _metti(corpo: Node3D, piedi: Vector3, giro: float, pendenza: float) -> void:
	corpo.global_position = piedi + Vector3(0, 0.4, 0)
	(corpo as CharacterBody3D).velocity = Vector3.ZERO
	if corpo is Giocatore:
		(corpo as Giocatore).punta(giro, pendenza)
	await _riposa(12)


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var immagine := root.get_texture().get_image()
	immagine.save_png(CARTELLA + "/" + nome)
	print("  ", nome)
	await _senza_interfaccia(nome)


## Lo stesso istante con l'interfaccia spenta (tappa 11, C3a): il fondo su cui si disegnano
## le direzioni dell'interfaccia. Solo con `pulito` dopo la variante.
func _senza_interfaccia(nome: String) -> void:
	if not OS.get_cmdline_user_args().has("pulito"):
		return
	var strati := root.find_children("*", "CanvasLayer", true, false)
	for strato: CanvasLayer in strati:
		strato.visible = false
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(CARTELLA + "/" + nome.get_basename() + "-pulito.png")
	for strato: CanvasLayer in strati:
		strato.visible = true
