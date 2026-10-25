extends SceneTree

## Attrezzo di lavorazione: le tre inquadrature delle prove della tappa 11, blocco C2
## (Fable, `ricerca-grezza/stato-2026-10-11/fable-c2.md`), uguali per ogni variante, così
## gli scatti si confrontano uno accanto all'altro:
##   1. dalla partenza dell'angolo nord-ovest, a terra, verso il catino: lo scatto «muro a
##      un passo» della diagnosi, che deve smettere di esserlo;
##   2. dalla piattaforma dell'ocra (+3,5) verso sud-ovest: il campo, la torre, il bersaglio
##      bonus, un avversario a 20-30 metri;
##   3. alle spalle, un avversario a dodici metri, nell'istante in cui il colpo va a segno.
## Più un quarto, di lavorazione: il primo piano del corpo di chi gioca.
## Gli avversari sono fermi (il loro corpo continua a respirare), messi sui punti di
## rinascita che la camera vede: niente è scelto a mano, quindi niente cambia da una
## variante all'altra se non l'arena.
##   godot --path . --resolution 854x390 -s tools/scatti_prove.gd -- <variante>
## Gli scatti escono come `P<variante>-<n>.png`.

const CARTELLA := "res://scatti"


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var variante := int(argomenti[0]) if argomenti.size() > 0 else Aspetto.scelta()
	var di_prima := Aspetto.scelta()
	Aspetto.scegli(variante)
	DirAccess.make_dir_recursive_absolute(CARTELLA)
	Arena.modo_partita = true
	var arena: Arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = 0.65
	var scadenza := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < scadenza and not (bool(arena.get("_sfida"))
			and bool(arena.call("_si_puo_segnare"))):
		await process_frame
	var giocatore := arena.giocatore()
	var avversari: Array = arena.avversari()
	for chi: Avversario in avversari:
		_ferma(chi)
	# Oltre il «VIA» scritto in mezzo allo schermo.
	await _riposa(110)
	var spazio := arena.get_world_3d().direct_space_state
	var pianta := arena.pianta()

	# 1. Dalla partenza nord-ovest verso il catino.
	var partenza: Dictionary = pianta["partenze"][0]
	var da := Vector3(float(partenza["dove"][0]), float(partenza["quota"]), float(partenza["dove"][1]))
	await _inquadra(arena, giocatore, avversari, spazio, da, Vector3(0, -2, 0), -4.0, 2, 10.0, 35.0)
	await _scatta("P%d-1.png" % variante)

	# 2. Dalla piattaforma dell'ocra verso sud-ovest.
	await _inquadra(arena, giocatore, avversari, spazio, Vector3(-11.5, 3.5, -31.5),
			Vector3(-40.0, 0.0, 0.0), -8.0, 2, 18.0, 32.0)
	await _scatta("P%d-2.png" % variante)

	# 3. Il colpo a segno, da dodici metri.
	var coppia := _coppia(arena, spazio)
	if coppia.is_empty():
		print("nessuna coppia a dodici metri")
	else:
		_metti(giocatore, coppia[0], coppia[1], 0.0)
		var bersaglio: Avversario = avversari[0]
		_metti_avversario(bersaglio, coppia[1], coppia[0])
		for k in range(1, avversari.size()):
			(avversari[k] as Node3D).global_position = Vector3(0, -80, 0)
		await _riposa(12)
		await _mira(giocatore, (coppia[1] as Vector3) + Vector3(0, 1.1, 0))
		var preso := [false]
		bersaglio.centrato.connect(func(_p: int, _m: int) -> void: preso[0] = true, CONNECT_ONE_SHOT)
		giocatore.spara()
		var fine := Time.get_ticks_msec() + 3000
		while not preso[0] and Time.get_ticks_msec() < fine:
			await process_frame
		await _riposa(5)
		await _scatta("P%d-3.png" % variante)
		print("colpo %s" % ("a segno" if preso[0] else "mancato"))

	# 4. Il primo piano di chi gioca, di tre quarti davanti, nel catino che è largo.
	for chi: Avversario in avversari:
		(chi as Node3D).global_position = Vector3(0, -80, 0)
	_metti(giocatore, Vector3(0, -2, 8.0), Vector3(0, -2, 20.0), 0.0)
	await _riposa(10)
	var camera := Camera3D.new()
	root.add_child(camera)
	var corpo := giocatore.corpo()
	var centro := corpo.global_position + Vector3(0, 1.0, 0)
	var avanti := -corpo.global_transform.basis.z
	camera.global_position = centro + avanti.rotated(Vector3.UP, 0.6) * 3.2 + Vector3(0, 0.4, 0)
	camera.look_at(centro, Vector3.UP)
	camera.fov = 50.0
	camera.make_current()
	await _riposa(4)
	await _scatta("P%d-4.png" % variante)

	print("fatto: variante %d (%s)" % [variante, Aspetto.nome()])
	Aspetto.scegli(di_prima)
	quit()


## Chi gioca in `da`, che guarda verso `verso`; e fino a `quanti` avversari sui punti di
## rinascita che la camera vede, fra `vicino` e `lontano` metri, girati verso di lui.
func _inquadra(arena: Arena, giocatore: Giocatore, avversari: Array,
		spazio: PhysicsDirectSpaceState3D, da: Vector3, verso: Vector3, pendenza: float,
		quanti: int, vicino: float, lontano: float) -> void:
	_metti(giocatore, da, verso, pendenza)
	var avanti := Vector3(verso.x - da.x, 0.0, verso.z - da.z).normalized()
	var sfera := SphereShape3D.new()
	sfera.radius = 0.6
	var domanda := PhysicsShapeQueryParameters3D.new()
	domanda.shape = sfera
	domanda.collision_mask = Strati.SOLIDO
	var messi := 0
	# Su un ventaglio davanti alla camera, dal centro verso i lati: il primo pavimento
	# libero e in vista a ogni passo, distanziati di almeno sei metri.
	var presi: Array[Vector3] = []
	for distanza in [vicino, (vicino + lontano) * 0.5, lontano, vicino + 4.0, lontano - 4.0]:
		for lato in [0.0, 12.0, -12.0, 20.0, -20.0]:
			if messi >= quanti:
				break
			var a: Vector3 = da + avanti.rotated(Vector3.UP, deg_to_rad(float(lato))) * float(distanza)
			var giu := PhysicsRayQueryParameters3D.create(a + Vector3(0, 12.0, 0), a + Vector3(0, -4.0, 0),
					Strati.SOLIDO)
			var terra := spazio.intersect_ray(giu)
			if terra.is_empty():
				continue
			var piedi: Vector3 = terra["position"]
			# Un pavimento, non la cima di un muro o di un cassone.
			if not [-2.0, 0.0, 3.5, 7.0].any(func(q: float) -> bool: return absf(piedi.y - q) < 0.1):
				continue
			domanda.transform = Transform3D(Basis(), piedi + Vector3(0, 1.0, 0))
			if not spazio.intersect_shape(domanda, 1).is_empty():
				continue
			var vista := PhysicsRayQueryParameters3D.create(da + Vector3(0, 2.0, 0),
					piedi + Vector3(0, 1.2, 0), Strati.SOLIDO)
			if not spazio.intersect_ray(vista).is_empty():
				continue
			if presi.any(func(p: Vector3) -> bool: return p.distance_to(piedi) < 6.0):
				continue
			presi.append(piedi)
			_metti_avversario(avversari[messi], piedi, da)
			messi += 1
	for k in range(messi, avversari.size()):
		(avversari[k] as Node3D).global_position = Vector3(0, -80, 0)
	await _riposa(14)
	# Fermi, gli avversari non aggiornano da soli contorno e nome.
	for chi: Avversario in avversari:
		chi.call("_aggiorna_i_contorni")
	await _riposa(2)


## Da un punto di rinascita alla quota zero, un posto a dodici metri con il pavimento
## sotto, libero per un corpo e in vista all'altezza del petto: il primo che si trova,
## nell'ordine della lista e girando a passi di 22,5 gradi.
func _coppia(arena: Arena, spazio: PhysicsDirectSpaceState3D) -> Array:
	var sfera := SphereShape3D.new()
	sfera.radius = 0.6
	for r: Dictionary in arena.get("_rinascite"):
		var da: Vector3 = r["dove"] - Vector3(0, 0.4, 0)
		if absf(da.y) > 0.05:
			continue
		for k in 16:
			var a := da + Vector3(12.0, 0.0, 0.0).rotated(Vector3.UP, TAU * float(k) / 16.0)
			var giu := PhysicsRayQueryParameters3D.create(a + Vector3(0, 1.0, 0), a + Vector3(0, -0.5, 0),
					Strati.SOLIDO)
			var terra := spazio.intersect_ray(giu)
			if terra.is_empty() or absf((terra["position"] as Vector3).y) > 0.1:
				continue
			var domanda := PhysicsShapeQueryParameters3D.new()
			domanda.shape = sfera
			domanda.collision_mask = Strati.SOLIDO
			domanda.transform = Transform3D(Basis(), a + Vector3(0, 1.0, 0))
			if not spazio.intersect_shape(domanda, 1).is_empty():
				continue
			var vista := PhysicsRayQueryParameters3D.create(da + Vector3(0, 1.4, 0),
					a + Vector3(0, 1.4, 0), Strati.SOLIDO)
			if not spazio.intersect_ray(vista).is_empty():
				continue
			# Dietro chi spara, dove sta la camera, non ci dev'essere un muro.
			var dietro := da - (a - da).normalized() * 4.2 + Vector3(0, 2.2, 0)
			domanda.transform = Transform3D(Basis(), dietro)
			domanda.shape = sfera
			var spalla := PhysicsRayQueryParameters3D.create(da + Vector3(0, 1.6, 0), dietro, Strati.SOLIDO)
			if spazio.intersect_shape(domanda, 1).is_empty() and spazio.intersect_ray(spalla).is_empty():
				return [da, a]
	return []


func _metti(giocatore: Giocatore, dove: Vector3, verso: Vector3, pendenza: float) -> void:
	giocatore.global_position = dove
	giocatore.velocity = Vector3.ZERO
	var d := verso - dove
	giocatore.punta(rad_to_deg(atan2(-d.x, -d.z)), pendenza)


## Il mirino sul punto: la camera sta sopra la spalla, quindi la direzione si corregge
## guardando dove punta davvero la camera, in tre giri.
func _mira(giocatore: Giocatore, dove: Vector3) -> void:
	var occhi := giocatore.global_position + Vector3(0, Giocatore.ALTEZZA_OCCHI, 0)
	var d := dove - occhi
	var giro := rad_to_deg(atan2(-d.x, -d.z))
	var pendenza := rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length()))
	for k in 3:
		giocatore.punta(giro, pendenza)
		await _riposa(3)
		var camera := giocatore.camera().global_transform
		var ora := -camera.basis.z
		var voluto := (dove - camera.origin).normalized()
		giro += rad_to_deg(atan2(-voluto.x, -voluto.z) - atan2(-ora.x, -ora.z))
		pendenza += rad_to_deg(asin(clampf(voluto.y, -1.0, 1.0)) - asin(clampf(ora.y, -1.0, 1.0)))
	giocatore.punta(giro, pendenza)
	await _riposa(3)


## Un avversario fermo: niente cervello, ma il corpo continua a respirare e la collisione
## resta, così un dardo lo prende.
func _ferma(chi: Avversario) -> void:
	chi.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	chi.process_mode = Node.PROCESS_MODE_DISABLED
	var corpo := chi.find_child("Corpo", true, false) as Corpo
	if corpo != null:
		corpo.process_mode = Node.PROCESS_MODE_ALWAYS
		corpo.aggiorna(Vector3.ZERO, true, 0.0, 1.0)


## `piedi`: dove poggia. I punti di rinascita stanno 40 centimetri sopra il pavimento.
func _metti_avversario(chi: Avversario, piedi: Vector3, guarda: Vector3) -> void:
	chi.global_position = piedi
	var d := guarda - piedi
	chi.rotation.y = atan2(-d.x, -d.z)


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(CARTELLA + "/" + nome)
	await _senza_interfaccia(nome)


## Lo stesso istante con l'interfaccia spenta (tappa 11, C3a): il fondo su cui si disegnano
## le direzioni dell'interfaccia. Solo con `pulito` dopo la variante.
func _senza_interfaccia(nome: String) -> void:
	if not OS.get_cmdline_user_args().has("pulito"):
		return
	var strati := root.find_children("*", "CanvasLayer", true, false)
	for strato: CanvasLayer in strati:
		strato.visible = false
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(CARTELLA + "/" + nome.get_basename() + "-pulito.png")
	for strato: CanvasLayer in strati:
		strato.visible = true
