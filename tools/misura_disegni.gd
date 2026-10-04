extends SceneTree

## Attrezzo di lavorazione: **chi fa i disegni** in una partita.
##
## Dal telefono, il 03/10/2026, la tappa 8 è scesa da 60 a 30 fotogrammi al
## secondo, e nel browser una partita fa circa 1.260 chiamate di disegno a
## fotogramma: su un telefono ognuna costa, e la scheda video aspetta. Qui si
## spegne un pezzo dell'arena alla volta e si legge quanto scendono disegni e
## oggetti: la voce grossa si vede subito, senza ipotesi.
##
## Vuole la finestra (il conto lo fa chi disegna):
##   godot --path . --resolution 854x390 -s tools/misura_disegni.gd

var _arena: Node


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	Arena.modo_partita = true
	_arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(_arena)
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = 0.75
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var scadenza := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < scadenza and float(_arena.call("conto_alla_rovescia")) > 0.0:
		await process_frame
	await _riposa(30)
	# Inquadrature fisse, con una camera nostra: dal posto del giocatore come
	# esce dal fischio, dal fondo del catino e dal ballatoio, che vede quasi tutto.
	var occhio := Camera3D.new()
	_arena.add_child(occhio)
	var posti := [
		["dal ballatoio, verso il catino", Vector3(0, 8.6, 30), Vector3(0, 0, 0)],
		["dal catino, verso nord", Vector3(0, -0.4, 6), Vector3(0, 0, -30)],
		["dal catino, verso est", Vector3(-6, -0.4, 0), Vector3(30, 0, 0)],
		["dall'angolo nord-ovest", Vector3(-29, 1.6, -29), Vector3(0, 0, 0)],
	]
	# Prima di tutto la camera vera, come esce dal fischio: 3D e interfaccia.
	await _riposa(4)
	var vp := root.get_viewport_rid()
	print("
camera del giocatore al via: %d disegni 3D, %d dell'interfaccia" % [_conta()[0],
			RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS,
					RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)])
	print("")
	for posto in posti:
		occhio.global_position = posto[1]
		occhio.look_at(posto[2])
		occhio.current = true
		await _riposa(4)
		print("%-34s %5d disegni %5d oggetti %7d triangoli" % ([posto[0]] + _conta()))

	occhio.global_position = posti[0][1]
	occhio.look_at(posti[0][2])
	await _riposa(4)
	var tutto := _conta()
	var voci := []
	for figlio in _arena.get_children():
		if not (figlio is Node3D) or not (figlio as Node3D).visible or figlio == occhio:
			continue
		var visuali := figlio.find_children("*", "VisualInstance3D", true, false).size()
		if figlio is VisualInstance3D:
			visuali += 1
		if visuali == 0:
			continue
		(figlio as Node3D).visible = false
		await _riposa(3)
		var senza := _conta()
		(figlio as Node3D).visible = true
		await _riposa(2)
		voci.append([String(figlio.name).left(34), visuali, tutto[0] - senza[0], tutto[1] - senza[1]])

	for gruppo in [Muratura.GRUPPO_MURI, Muratura.GRUPPO_PAVIMENTI]:
		var nodi := _arena.get_tree().get_nodes_in_group(gruppo)
		for n in nodi:
			(n as Node3D).visible = false
		await _riposa(3)
		var senza := _conta()
		for n in nodi:
			(n as Node3D).visible = true
		await _riposa(2)
		voci.append(["(gruppo) " + String(gruppo), nodi.size(), tutto[0] - senza[0], tutto[1] - senza[1]])

	var scritte := _arena.find_children("*", "Label3D", true, false)
	for t in scritte:
		(t as Node3D).visible = false
	await _riposa(3)
	var senza_scritte := _conta()
	for t in scritte:
		(t as Node3D).visible = true
	voci.append(["(tutte le Label3D)", scritte.size(), tutto[0] - senza_scritte[0], tutto[1] - senza_scritte[1]])

	voci.sort_custom(func(a: Array, b: Array) -> bool: return a[2] > b[2])
	print("
dal ballatoio, %d disegni in tutto. Spegnendo una voce alla volta:" % tutto[0])
	print("%-34s %8s %9s %9s" % ["voce", "nodi", "-disegni", "-oggetti"])
	for v in voci:
		if v[2] > 2:
			print("%-34s %8d %9d %9d" % v)
	quit()


func _conta() -> Array:
	var vp := root.get_viewport_rid()
	var visibile := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE
	return [RenderingServer.viewport_get_render_info(vp, visibile, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
			RenderingServer.viewport_get_render_info(vp, visibile, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
			RenderingServer.viewport_get_render_info(vp, visibile, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)]


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame
