extends SceneTree

## Attrezzo di lavorazione, non fa parte del gioco.
## Apre una scena, aspetta qualche fotogramma e salva uno scatto in PNG,
## cosi' le verifiche visive si fanno guardando l'immagine invece che a parole.
##
## Uso:  Godot --path . -s tools/scatto.gd -- res://scenes/test_cube.tscn scatto.png

func _initialize() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var percorso_scena := argomenti[0] if argomenti.size() > 0 else "res://scenes/test_cube.tscn"
	var nome_file := argomenti[1] if argomenti.size() > 1 else "scatto.png"
	var scena: Node = load(percorso_scena).instantiate()
	root.add_child(scena)
	_scatta(nome_file)


func _scatta(nome_file: String) -> void:
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var immagine := root.get_texture().get_image()
	immagine.save_png("res://" + nome_file)
	print("scatto salvato: ", nome_file, " ", immagine.get_width(), "x", immagine.get_height())
	quit()
