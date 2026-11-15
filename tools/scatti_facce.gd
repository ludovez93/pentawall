extends SceneTree

## Attrezzo di lavorazione: **le sei facce** della striscia che sta sotto la parola grande
## (tappa 14, blocco F). Fotografa la testa di ognuno dei sei corpi a cartone, uno alla
## volta, su fondo trasparente, e le salva in `assets/ui/faccia_<nome>.png` (256 × 256).
## Sono fotografie dei nostri personaggi: si rifanno solo se cambia un corpo (`Corpo.FACCE`).
##
## Vuole la finestra: senza schermo il fotogramma non c'è.
##   godot --path . --resolution 480x270 -s tools/scatti_facce.gd
## Poi `godot --headless --path . --import`, perché il gioco le possa leggere.

const CARTELLA := "res://assets/ui"
## Si fotografa al doppio e si riduce: i bordi restano puliti.
const LATO := 256
const FOTO := 512
## Quanto è largo il quadro rispetto alla testa (dal collo alla cima: la testa a cartone è
## più larga che alta, e sopra ci sono berretto e capelli), di quanto si gira il
## personaggio (di tre quarti) e da quanto in alto lo si guarda.
const AGIO := 1.7
const TRE_QUARTI := 22.0
const DALL_ALTO := 6.0
const CAMPO := 18.0


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	await process_frame
	var di_prima := Aspetto.scelta()
	Aspetto.scegli(Aspetto.GONFIABILE)
	DirAccess.make_dir_recursive_absolute(CARTELLA)

	var studio := SubViewport.new()
	studio.size = Vector2i(FOTO, FOTO)
	studio.own_world_3d = true
	studio.transparent_bg = true
	studio.msaa_3d = Viewport.MSAA_4X
	studio.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(studio)

	# La luce: un sole di tre quarti davanti e in alto, e un chiarore tutt'intorno perché
	# le ombre non siano buchi. Niente cielo: il fondo resta trasparente.
	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_CLEAR_COLOR
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color(1.0, 1.0, 1.0)
	ambiente.ambient_light_energy = 0.62
	var mondo := WorldEnvironment.new()
	mondo.environment = ambiente
	studio.add_child(mondo)
	var sole := DirectionalLight3D.new()
	sole.light_energy = 1.15
	sole.shadow_enabled = false
	studio.add_child(sole)
	sole.look_at_from_position(Vector3(-1.4, 2.4, -3.0), Vector3(0.0, 1.3, 0.0))
	var camera := Camera3D.new()
	camera.fov = CAMPO
	camera.near = 0.05
	studio.add_child(camera)
	camera.make_current()

	for nome: String in Corpo.PERSONAGGI:
		var corpo := Corpo.crea(nome)
		studio.add_child(corpo)
		# Il braccio del blaster in giù, e il blaster via: nel ritratto c'è la faccia.
		var blaster := corpo.get("_blaster") as Node3D
		if blaster != null:
			blaster.visible = false
		corpo.rotation.y = deg_to_rad(-TRE_QUARTI)
		for i in 8:
			corpo.aggiorna(Vector3.ZERO, true, deg_to_rad(-55.0), 1.0 / 30.0)
			await process_frame
		# La testa: dall'osso del collo alla cima del corpo.
		var scheletro := corpo.get("_scheletro") as Skeleton3D
		var osso := scheletro.find_bone("head")
		var collo := (scheletro.global_transform * scheletro.get_bone_global_pose(osso)).origin
		var cima := Corpo.ALTEZZA_CORPO
		var alta := (cima - collo.y) * AGIO
		# Il centro un poco sopra la metà: entrano berretto e crocchia, e sotto un filo di spalle.
		var centro := Vector3(collo.x, (collo.y + cima) * 0.5 + 0.05, collo.z)
		var lontano := alta * 0.5 / tan(deg_to_rad(CAMPO * 0.5))
		var verso := Vector3(0.0, sin(deg_to_rad(DALL_ALTO)), -cos(deg_to_rad(DALL_ALTO)))
		camera.look_at_from_position(centro + verso * lontano, centro)
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var foto := studio.get_texture().get_image()
		foto.convert(Image.FORMAT_RGBA8)
		foto.resize(LATO, LATO, Image.INTERPOLATE_LANCZOS)
		var percorso := "%s/faccia_%s.png" % [CARTELLA, nome.to_lower()]
		foto.save_png(percorso)
		print("  %s  (collo a %.2f m, testa alta %.2f m)" % [percorso, collo.y, cima - collo.y])
		corpo.queue_free()
		await process_frame

	Aspetto.scegli(di_prima)
	print("fatto.")
	quit()
