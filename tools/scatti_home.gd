extends SceneTree

## Attrezzo di lavorazione: **la Home accanto alla partita** (problema 8 di `PROBLEMI.md`,
## tappa 13 blocco C), alle misure del telefono. Tre scatti della Home in tre punti del giro
## della camera, poi GIOCA e uno scatto della partita: le due cose devono sembrare lo stesso
## gioco. La variante si sceglie per il giro e poi si rimette quella di prima.
##
## Vuole la finestra:
##   godot --path . --resolution 1280x585 -s tools/scatti_home.gd -- <variante>

const CARTELLA := "res://scatti"


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var variante := int(argomenti[0]) if argomenti.size() > 0 else Aspetto.GIOCATTOLO
	var di_prima := Aspetto.scelta()
	Aspetto.scegli(variante)
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = 0.75
	var ingresso: Node = load("res://scenes/ingresso.tscn").instantiate()
	root.add_child(ingresso)
	current_scene = ingresso
	var scadenza := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < scadenza and ingresso.get("_arena_pronta") == null:
		await process_frame
	# Il giro della camera dura 14 secondi: l'inizio, un estremo e l'altro.
	for tempo in [0.0, 3.5, 10.5]:
		ingresso.set("_tempo", tempo)
		await _riposa(3)
		await _scatta("home-%d-%04.1f.png" % [variante, tempo])
	ingresso.call("_comincia")
	await _riposa(20)
	var arena := current_scene
	scadenza = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < scadenza and arena.has_method("conto_alla_rovescia") \
			and float(arena.call("conto_alla_rovescia")) > 0.0:
		await process_frame
	await _riposa(60)
	await _scatta("home-%d-partita.png" % variante)
	Aspetto.scegli(di_prima)
	print("fatto.")
	quit()


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(CARTELLA + "/" + nome)
	print("scatto: ", nome)
