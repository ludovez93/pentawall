extends SceneTree

## Attrezzo di lavorazione: **le pose dei corpi veri**, da vicino e una accanto
## all'altra (tappa 8, blocco D).
##
## Un palco vuoto, sei corpi, e a ognuno si dà una velocità finta: fermo, corsa in
## avanti, corsa di lato, all'indietro, in volo, e uno che spara a raffica. Così si
## giudica l'animazione da sola, senza l'intelligenza degli avversari che decide
## per conto suo dove andare. Due scatti a un quarto di secondo l'uno dall'altro:
## un passo fermo non dice se il passo è giusto.
##
##   godot --path . --resolution 854x390 -s tools/scatti_pose.gd

const CARTELLA := "res://scatti"

## Chi fa cosa: velocità nel riferimento del corpo (x a destra, z indietro).
const PROVE := [
	{"chi": "TU", "velocita": Vector3.ZERO, "a_terra": true, "nome": "fermo"},
	{"chi": "BRACE", "velocita": Vector3(0, 0, -7.62), "a_terra": true, "nome": "avanti"},
	{"chi": "QUARZO", "velocita": Vector3(7.62, 0, 0), "a_terra": true, "nome": "di lato"},
	{"chi": "LAMPO", "velocita": Vector3(0, 0, 7.62), "a_terra": true, "nome": "indietro"},
	{"chi": "NEBBIA", "velocita": Vector3(0, 0, -5.0), "a_terra": false, "nome": "in volo"},
	{"chi": "TORO", "velocita": Vector3.ZERO, "a_terra": true, "nome": "spara"},
]

var _corpi: Array[Corpo] = []


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var palco := Node3D.new()
	root.add_child(palco)
	_scena(palco)
	for i in PROVE.size():
		var corpo := Corpo.crea(String(PROVE[i]["chi"]))
		palco.add_child(corpo)
		corpo.position = Vector3(-6.25 + 2.5 * i, 0.0, 0.0)
		# Girati verso la camera: le facce si giudicano di faccia.
		corpo.rotation.y = PI
		_corpi.append(corpo)
		var targa := Label3D.new()
		targa.text = String(PROVE[i]["nome"]).to_upper()
		targa.font_size = 64
		targa.pixel_size = 0.004
		targa.position = corpo.position + Vector3(0, 2.25, 0)
		targa.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		palco.add_child(targa)

	var camera := Camera3D.new()
	camera.fov = 52.0
	palco.add_child(camera)
	camera.look_at_from_position(Vector3(1.5, 1.9, 7.2), Vector3(0.0, 0.95, 0.0))
	camera.current = true

	var tempo := 0.0
	var prossimo_sparo := 0.0
	var scatti := [0.9, 1.15]
	var fatti := 0
	while fatti < scatti.size():
		var delta := 1.0 / 60.0
		await process_frame
		tempo += delta
		for i in _corpi.size():
			var p: Dictionary = PROVE[i]
			var corpo := _corpi[i]
			var v: Vector3 = corpo.global_transform.basis * (p["velocita"] as Vector3)
			corpo.aggiorna(v, bool(p["a_terra"]), 0.0, delta)
		if tempo >= prossimo_sparo:
			prossimo_sparo = tempo + Giocatore.CADENZA
			_corpi[5].spara()
		if tempo >= float(scatti[fatti]):
			await _scatta("85-pose-%d.png" % (fatti + 1))
			fatti += 1
	print("fatto.")
	quit()


func _scena(palco: Node3D) -> void:
	var mondo := WorldEnvironment.new()
	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color(0.05, 0.05, 0.10)
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color(0.46, 0.42, 0.66)
	ambiente.ambient_light_energy = 0.85
	ambiente.tonemap_mode = Environment.TONE_MAPPER_ACES
	mondo.environment = ambiente
	palco.add_child(mondo)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-50, 30, 0)
	sole.light_energy = 1.1
	palco.add_child(sole)
	var pavimento := MeshInstance3D.new()
	var piano := PlaneMesh.new()
	piano.size = Vector2(30, 14)
	pavimento.mesh = piano
	var tinta := StandardMaterial3D.new()
	tinta.albedo_color = Color(0.24, 0.13, 0.36)
	pavimento.material_override = tinta
	palco.add_child(pavimento)


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var immagine := root.get_texture().get_image()
	immagine.save_png(CARTELLA + "/" + nome)
	print("  ", nome)
