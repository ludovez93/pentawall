extends SceneTree

func _initialize() -> void:
	_lavora()

func _lavora() -> void:
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	for i in 40:
		await process_frame
	var g: Giocatore = arena.call("giocatore")
	g.global_position = Vector3(1.8, -1.6, 10.6)
	g.punta(8.0, -6.0)
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://scatti/_potenziamento.png")
	print("persone: ", arena.call("quanto_pubblico"))
	quit()
