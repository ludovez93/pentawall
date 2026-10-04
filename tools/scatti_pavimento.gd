extends SceneTree

## Attrezzo di lavorazione: fotografa il pavimento **mentre il giocatore cammina**,
## alle misure del telefono e con la resa sotto l'uno, dove i passaggi diagonali
## incontrano le ali.
##
## Riproduce quello che è arrivato dal telefono il 04/10/2026: *«qualche zona del
## pavimento lampeggia quando ci passo»*. Otto fotogrammi di fila, il giocatore che
## avanza di quindici centimetri a fotogramma: un pavimento che lampeggia cambia da
## uno scatto all'altro anche dove la camera si è spostata di niente.
##   godot --path . --resolution 854x390 -s tools/scatti_pavimento.gd [-- <suffisso>]

const CARTELLA := "res://scatti"

## Da dove guarda la camera, verso dove, e di quanto avanza a ogni fotogramma. Una
## camera libera, all'altezza di chi guarda dall'alto di un cassone: quella del
## giocatore, a terra, finisce contro i muri dei passaggi.
const POSTI := [
	# Dentro la galleria nord-ovest, dalla parte del catino: il pavimento è moquette,
	# e sotto ci passano l'ala ocra, l'angolo nord-ovest e l'ala tribuna.
	{"nome": "galleria", "da": Vector3(-10.0, 2.4, -10.0), "verso": Vector3(-15.0, 0.0, -16.5),
			"passo": Vector3(-0.1, 0.0, -0.1)},
	# Dentro il passaggio largo sud-est: sotto ci passano il portico e l'ala mattone.
	{"nome": "passaggio", "da": Vector3(10.0, 2.4, 10.0), "verso": Vector3(16.5, 0.0, 15.0),
			"passo": Vector3(0.1, 0.0, 0.1)},
	# Il catino dall'alto, da sud: il cerchio, le linee e il nome dipinto.
	{"nome": "catino", "da": Vector3(0.0, 1.5, 11.5), "verso": Vector3(0.0, -2.0, 6.0),
			"passo": Vector3(0.0, 0.0, 0.1)},
]
const FOTOGRAMMI := 8


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var suffisso: String = argomenti[0] if argomenti.size() > 0 else "prima"
	Arena.modo_partita = true
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = 0.65
	var scadenza := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < scadenza and float(arena.call("conto_alla_rovescia")) > 0.0:
		await process_frame
	await _riposa(20)

	var giocatore: Giocatore = arena.call("giocatore")
	# Gli avversari via dall'inquadratura: qui si guarda il pavimento.
	for chi in arena.call("avversari"):
		(chi as Node3D).global_position = Vector3(30, 0.5, 30)
		(chi as Node3D).process_mode = Node.PROCESS_MODE_DISABLED
	giocatore.global_position = Vector3(30, 0.5, -30)
	var camera := Camera3D.new()
	camera.fov = Giocatore.CAMPO_TERZA
	camera.near = 0.05
	camera.far = 220.0
	root.add_child(camera)
	camera.make_current()
	for posto in POSTI:
		for f in FOTOGRAMMI:
			var scarto := (posto["passo"] as Vector3) * f
			camera.global_position = (posto["da"] as Vector3) + scarto
			camera.look_at((posto["verso"] as Vector3) + scarto)
			await _riposa(3)
			await _scatta("P-%s-%d-%s.png" % [posto["nome"], f, suffisso])
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
