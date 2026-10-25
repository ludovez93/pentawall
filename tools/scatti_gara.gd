extends SceneTree

## Attrezzo di lavorazione: **la GARA fotografata alle misure del telefono** (tappa 11,
## blocco D1). Si entra dalla strada vera — la Home, GARA, GIOCA — e poi si mette il
## giocatore dove serve: in griglia al via, davanti alla prima bandiera, con la bandiera
## alle spalle (la freccia), a metà gara e sul podio.
##
## Vuole la finestra: senza schermo il fotogramma non c'è e resta appeso.
##   godot --path . --resolution 854x390 -s tools/scatti_gara.gd [-- <variante>]

const CARTELLA := "res://scatti"


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var aspetto_di_prima := Aspetto.scelta()
	var modalita_di_prima := Modalita.scelta()
	if argomenti.size() > 0:
		Aspetto.scegli(int(argomenti[0]))
	var prefisso := "G%d" % Aspetto.scelta()
	Modalita.scegli(Modalita.SCONTRO)
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = 0.75
	var ingresso: Node = load("res://scenes/ingresso.tscn").instantiate()
	root.add_child(ingresso)
	current_scene = ingresso
	await _riposa(6)
	var pulsanti: Array = ingresso.get("_modalita")
	(pulsanti[Modalita.GARA] as Button).pressed.emit()
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
	await _riposa(20)
	await _scatta(prefisso + "-2-via.png")

	# Fermi tutti, così gli scatti dicono quello che si vuole far vedere.
	for bot in arena.avversari():
		bot.process_mode = Node.PROCESS_MODE_DISABLED
	var b := arena.bandiere()
	var tu := arena.giocatore()

	# Davanti alla prima bandiera, a sette metri, dalla strada che arriva.
	var verso := (b.partenza() - b.dove(0))
	verso.y = 0.0
	verso = verso.normalized()
	await _metti(tu, b.dove(0) + verso * 7.0, Bandiere.giro_verso(b.dove(0) + verso * 7.0, b.dove(0)), -6.0)
	await _scatta(prefisso + "-3-bandiera.png")

	# Con la bandiera alle spalle: la freccia sul bordo.
	await _metti(tu, b.dove(0) + verso * 7.0, Bandiere.giro_verso(b.dove(0), b.dove(0) + verso * 7.0), -4.0)
	await _scatta(prefisso + "-4-freccia.png")

	# A metà gara: toccate la prima e la seconda, verso la terza. Due avversari avanti.
	tu.process_mode = Node.PROCESS_MODE_INHERIT
	for i in 2:
		await _metti(tu, b.dove(i), 0.0, 0.0)
	var righe: Array = arena.get("_concorrenti")
	righe[1]["bandiere"] = 3
	righe[2]["bandiere"] = 2
	righe[2]["quando"] = 0.5
	var dopo := b.posto_di_ripartenza(1, arena.get_world_3d().direct_space_state)
	await _metti(tu, (dopo["dove"] as Vector3) - Vector3(0, 0.4, 0), float(dopo["giro"]), -4.0)
	await _riposa(30)
	await _scatta(prefisso + "-5-meta-gara.png")

	# Il podio: tu sulla settima con sei bandiere.
	righe[0]["bandiere"] = 6
	await _metti(tu, b.dove(6), 0.0, -4.0)
	await _riposa(40)
	await _scatta(prefisso + "-6-podio.png")

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
