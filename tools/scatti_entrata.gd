extends SceneTree

## Attrezzo di lavorazione: **la strada vera dall'ingresso alla partita** (tappa 9),
## alle misure del telefono. L'ingresso mentre prepara l'arena, l'ingresso pronto,
## il fischio subito dopo GIOCA e la partita in corso: l'arena arriva da una vetrina
## invisibile, e l'interfaccia deve disporsi sulla finestra vera.
##
## Vuole la finestra: senza schermo il fotogramma non c'è e resta appeso.
##   godot --path . --resolution 854x390 -s tools/scatti_entrata.gd

const CARTELLA := "res://scatti"


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = 0.75
	var ingresso: Node = load("res://scenes/ingresso.tscn").instantiate()
	root.add_child(ingresso)
	current_scene = ingresso
	await _riposa(8)
	await _scatta("70-ingresso-prepara.png")
	var scadenza := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < scadenza and ingresso.get("_arena_pronta") == null:
		await process_frame
	await _riposa(4)
	await _scatta("71-ingresso-pronto.png")
	ingresso.call("_comincia")
	await _riposa(20)
	await _scatta("72-fischio-dopo-gioca.png")
	var arena := current_scene
	scadenza = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < scadenza and float(arena.call("conto_alla_rovescia")) > 0.0:
		await process_frame
	await _riposa(150)
	await _scatta("73-partita-dopo-gioca.png")
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
