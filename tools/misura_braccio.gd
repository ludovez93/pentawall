extends SceneTree

## **E0, la camera alle ricomparse** (tappa 12, blocco E). L'ipotesi del piano: i
## fotogrammi col muro a mezzo schermo e il personaggio sparito subito dopo una ricomparsa
## vengono da posti con un muro alle spalle più vicino del braccio della camera (3,9 m).
##
## Per ognuno dei 24 posti di rinascita il giocatore ci viene messo col verso che il gioco
## gli darebbe ricomparendo nello scontro (`Arena._verso_alla_ricomparsa`, la stessa
## funzione di `Arena._ricompari`; prima di E1 erano due righe lì dentro: il verso della
## pianta nelle sei partenze, `_verso_libero` negli altri), e si legge quanto è lungo
## il braccio della camera (`SpringArm3D.get_hit_length`). Sotto i 2,2 m il personaggio si
## nasconde (`Giocatore._aggiorna_camera`).
##
## Con `scatti` (vuole la finestra) salva anche uno scatto per posto in
## `scatti/E0-<variante>/`, alla misura del telefono.
##   godot --headless --path . -s tools/misura_braccio.gd -- <variante>
##   godot --path . --resolution 1280x585 -s tools/misura_braccio.gd -- <variante> scatti

const SOGLIA := 2.2


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var di_prima := Aspetto.scelta()
	if argomenti.size() > 0 and argomenti[0].is_valid_int():
		Aspetto.scegli(int(argomenti[0]))
	var scatti := argomenti.has("scatti")
	var cartella := "res://scatti/E0-%d" % Aspetto.scelta()
	if scatti:
		DirAccess.make_dir_recursive_absolute(cartella)
		root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		root.scaling_3d_scale = 0.75
	print("E0: il braccio della camera alle ricomparse, in %s" % Aspetto.nome())
	Arena.modo_partita = true
	var arena: Arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	var scadenza := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < scadenza and not (bool(arena.get("_sfida"))
			and bool(arena.call("_si_puo_segnare"))):
		await process_frame
	Aspetto.scegli(di_prima)
	# Gli avversari fuori dai piedi e fuori dagli scatti.
	for uno in arena.avversari():
		(uno as Avversario).bersaglio = null
		uno.process_mode = Node.PROCESS_MODE_DISABLED
		uno.global_position = Vector3(0, -60, 0)
	var tu := arena.giocatore()
	var braccio: SpringArm3D = tu.get("_braccio")
	var posti: Array = arena.get("_rinascite")
	var sotto := 0
	for i in posti.size():
		var posto: Dictionary = posti[i]
		var dove: Vector3 = posto["dove"]
		tu.global_position = dove
		tu.velocity = Vector3.ZERO
		var giro: float = arena.call("_verso_alla_ricomparsa", posto)
		tu.punta(giro, Arena.PENDENZA_RICOMPARSA)
		for k in 12:
			await physics_frame
		await process_frame
		var lungo := braccio.get_hit_length()
		if lungo <= SOGLIA:
			sotto += 1
		print("  %2d  %-9s  (%6.1f; %5.1f; %6.1f)  verso %4.0f°  braccio %.2f m%s" % [i,
				"partenza" if i < 6 else "aggiunto", dove.x, dove.y, dove.z, giro, lungo,
				"  ← personaggio nascosto" if lungo <= SOGLIA else ""])
		if scatti:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/%02d.png" % [cartella, i])
	print("posti col braccio sotto %.1f m: %d su %d" % [SOGLIA, sotto, posti.size()])
	quit(0)
