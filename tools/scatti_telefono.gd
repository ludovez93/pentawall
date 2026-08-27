extends SceneTree

## Attrezzo di lavorazione: fotografa l'arena **alle proporzioni del telefono**.
##
## Sul PC la finestra è 1280 × 720; l'iPhone di Ludovico, in orizzontale e a
## schermo intero, dà a Godot un canvas di **854 × 390** — quasi la metà in
## altezza. Un'interfaccia che sta comoda sul PC lì può finire in mezzo al
## pollice, ed è successo con la classifica della tappa 6: sei righe arrivavano
## a trecento punti su trecentonovanta.
##
## Va lanciato con la finestra alla misura giusta, o non misura niente:
##   godot --path . --resolution 854x390 -s tools/scatti_telefono.gd

const CARTELLA := "res://scatti"

var _arena: Node
var _giocatore: Giocatore


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	_arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(_arena)
	await _riposa(40)
	_giocatore = _arena.call("giocatore")
	print("finestra: ", DisplayServer.window_get_size())

	_arena.call("avvia_sfida")
	var scadenza := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < scadenza:
		await process_frame
		if (_arena.call("avversari") as Array).size() >= 5:
			break
	await _riposa(300)
	_metti(Vector3(0.0, 7.6, 20.0), 0.0, -8.0)
	await _riposa(20)
	await _scatta("43-partita-sul-telefono.png")

	print("fatto.")
	quit()


func _metti(dove: Vector3, giro_gradi: float, pendenza_gradi: float) -> void:
	_giocatore.global_position = dove
	_giocatore.velocity = Vector3.ZERO
	_giocatore.punta(giro_gradi, pendenza_gradi)


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var immagine := root.get_texture().get_image()
	immagine.save_png(CARTELLA + "/" + nome)
	print("  ", nome, "  ", immagine.get_width(), "x", immagine.get_height())
