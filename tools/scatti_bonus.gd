extends SceneTree

## Attrezzo di lavorazione: fotografa i bersagli bonus (tappa 11, blocco F) dalla camera
## vera del giocatore, alle misure e con la resa del telefono. Per ognuno: il giocatore
## davanti, sul pavimento, che lo guarda; uno scatto acceso, e uno appena preso (gira,
## poi grigio). Si guardano prima di pubblicare, non dopo.
##   godot --path . --resolution 854x390 -s tools/scatti_bonus.gd -- <variante>
## Gli scatti escono come `B<variante>-<n>-<valore>-<acceso|spento>.png`.

const CARTELLA := "res://scatti"
## A che distanza e di quanto di lato ci si mette davanti al bersaglio: si prova il primo
## posto che lo vede.
const DISTANZE := [12.0, 9.0, 16.0, 6.0, 20.0]
const DI_LATO := [0.0, 25.0, -25.0, 45.0, -45.0, 60.0, -60.0]


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var variante := int(argomenti[0]) if argomenti.size() > 0 else Aspetto.scelta()
	var di_prima := Aspetto.scelta()
	Aspetto.scegli(variante)
	DirAccess.make_dir_recursive_absolute(CARTELLA)
	Arena.modo_partita = true
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = 0.65
	# Dopo il via: prima un colpo non conta, e lo scatto «spento» sarebbe ancora acceso.
	var scadenza := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < scadenza and not (bool(arena.get("_sfida"))
			and bool(arena.call("_si_puo_segnare"))):
		await process_frame
	await _riposa(20)
	var giocatore: Giocatore = arena.call("giocatore")
	for chi in arena.call("avversari"):
		(chi as Node3D).process_mode = Node.PROCESS_MODE_DISABLED
		(chi as Node3D).global_position = Vector3(0, -80, 0)
	var spazio := (arena as Node3D).get_world_3d().direct_space_state
	var bonus: Array = arena.call("bersagli_bonus")
	for i in bonus.size():
		var b := bonus[i] as BersaglioBonus
		var posto := _davanti(spazio, b)
		if posto == Vector3.INF:
			print("nessun posto davanti a %d" % b.valore)
			continue
		giocatore.global_position = posto
		giocatore.velocity = Vector3.ZERO
		var occhi := posto + Vector3(0, 1.62, 0)
		var verso := b.centro() - occhi
		var giro := rad_to_deg(atan2(-verso.x, -verso.z))
		var pendenza := rad_to_deg(atan2(verso.y, Vector2(verso.x, verso.z).length()))
		giocatore.punta(giro, pendenza)
		await _riposa(14)
		await _scatta("B%d-%d-%d-acceso.png" % [variante, i, b.valore])
		b.incassa(0, giocatore)
		await _riposa(int(BersaglioBonus.GIRA * 60.0) + 10)
		await _scatta("B%d-%d-%d-spento.png" % [variante, i, b.valore])
		b.riparti()
	print("fatto: variante %d (%s)" % [variante, Aspetto.nome()])
	Aspetto.scegli(di_prima)
	quit()


## Un punto di pavimento davanti al disco da cui lo si vede: si scende dalla verticale
## fino al primo pavimento, e si controlla la linea dagli occhi.
func _davanti(spazio: PhysicsDirectSpaceState3D, b: BersaglioBonus) -> Vector3:
	for angolo in DI_LATO:
		var posto := _davanti_a(spazio, b, b.global_transform.basis.z.rotated(Vector3.UP,
				deg_to_rad(float(angolo))))
		if posto != Vector3.INF:
			return posto
	return Vector3.INF


func _davanti_a(spazio: PhysicsDirectSpaceState3D, b: BersaglioBonus, normale: Vector3) -> Vector3:
	for d in DISTANZE:
		var sopra := b.centro() + normale * float(d)
		var giu := PhysicsRayQueryParameters3D.create(Vector3(sopra.x, b.centro().y + 0.5, sopra.z),
				Vector3(sopra.x, -3.0, sopra.z), Strati.SOLIDO)
		var terra := spazio.intersect_ray(giu)
		if terra.is_empty():
			continue
		var piedi: Vector3 = terra["position"] + Vector3(0, 0.05, 0)
		var occhi := piedi + Vector3(0, 1.62, 0)
		var linea := PhysicsRayQueryParameters3D.create(occhi,
				b.centro() + normale * 0.3, Strati.SOLIDO)
		if spazio.intersect_ray(linea).is_empty():
			return piedi
	return Vector3.INF


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var immagine := root.get_texture().get_image()
	immagine.save_png(CARTELLA + "/" + nome)
