extends SceneTree

## Attrezzo di lavorazione: fotografa i piani alti **visti da sotto**, con un
## avversario sopra, alle misure del telefono e con la resa a tre quarti.
##
## Riproduce quello che è arrivato dal telefono il 03/10/2026: *«vedo la gente
## camminare sui soffitti da sotto»*. Dal portico si guarda in su il ballatoio, e
## dalla parte bassa dell'ala ocra la passerella nord.
##   godot --path . --resolution 854x390 -s tools/scatti_da_sotto.gd [-- <suffisso>]

const CARTELLA := "res://scatti"

## Dove si mette il giocatore, dove guarda e chi sta sopra di lui.
const POSTI := [
	{"nome": "portico", "dove": Vector3(0, 0, 17), "giro": 180.0, "su": 32.0,
			"sopra": Vector3(1.5, 7.0, 21.0)},
	{"nome": "passerella", "dove": Vector3(6, 0, -25), "giro": 0.0, "su": 26.0,
			"sopra": Vector3(8.0, 3.5, -30.5)},
]


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var suffisso: String = argomenti[0] if argomenti.size() > 0 else "dopo"
	Arena.modo_partita = true
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = 0.75
	var scadenza := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < scadenza and float(arena.call("conto_alla_rovescia")) > 0.0:
		await process_frame
	await _riposa(20)

	var giocatore: Giocatore = arena.call("giocatore")
	var avversari: Array = arena.call("avversari")
	for posto in POSTI:
		giocatore.global_position = posto["dove"]
		giocatore.velocity = Vector3.ZERO
		giocatore.punta(posto["giro"], posto["su"])
		var chi := avversari[0] as Avversario
		chi.global_position = posto["sopra"]
		chi.velocity = Vector3.ZERO
		await _riposa(8)
		await _scatta("S-%s-%s.png" % [posto["nome"], suffisso])
	print("fatto.")
	quit()


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var immagine := root.get_texture().get_image()
	immagine.save_png(CARTELLA + "/" + nome)
	print("  ", nome)
