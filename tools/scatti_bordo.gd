extends SceneTree

## Attrezzo di lavorazione: il giocatore **addossato al muro perimetrale**, che gira
## la visuale su otto direzioni. Per ognuna stampa dove sta la camera e la fotografa
## alle misure del telefono.
##
## Riproduce quello che è arrivato dal telefono il 04/10/2026: *«se sono attaccato
## ai bordi dell'arena e giro la visuale vedo il nero fuori dell'arena»*. Le facce
## interne del perimetro stanno a ±33 metri: una camera oltre quel numero è fuori.
##   godot --path . --resolution 854x390 -s tools/scatti_bordo.gd [-- <suffisso>]

const CARTELLA := "res://scatti"
const POSTI := [
	{"nome": "est", "dove": Vector3(32.5, 0.0, 2.0)},
	{"nome": "angolo", "dove": Vector3(32.5, 0.0, -32.5)},
]


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var suffisso: String = argomenti[0] if argomenti.size() > 0 else "prima"
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = 0.65
	await _riposa(20)
	var giocatore: Giocatore = arena.call("giocatore")
	for posto in POSTI:
		for giro in range(0, 360, 45):
			giocatore.global_position = posto["dove"]
			giocatore.velocity = Vector3.ZERO
			giocatore.punta(float(giro), -6.0)
			for i in 4:
				await physics_frame
			await _riposa(3)
			var c := giocatore.camera().global_position
			var fuori := absf(c.x) > 33.0 or absf(c.z) > 33.0
			print("  %s %3d°: camera (%.2f, %.2f, %.2f)%s" % [posto["nome"], giro, c.x, c.y, c.z,
					"  FUORI" if fuori else ""])
			await _scatta("B-%s-%03d-%s.png" % [posto["nome"], giro, suffisso])
	print("fatto.")
	quit()


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var immagine := root.get_texture().get_image()
	immagine.save_png(CARTELLA + "/" + nome)
