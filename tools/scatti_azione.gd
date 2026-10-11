extends SceneTree

## Attrezzo di lavorazione: fotografa **la partita in corso** come la vede chi gioca,
## per il confronto con i giochi veri (tappa 11, blocco C1). Gli scatti delle varianti
## guardano l'arena con gli avversari fermi; qui la partita gira davvero, e a ogni
## scatto il giocatore si mette alle spalle di un avversario che sta tirando a un
## altro, e spara anche lui: corpi, dardi, numeri e annunci come in una partita.
##   godot --path . --resolution 854x390 -s tools/scatti_azione.gd -- <variante> [scatti]
## Gli scatti escono come `Z<variante>-<n>.png`.

const CARTELLA := "res://scatti"
const DIETRO := 6.0


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var variante := int(argomenti[0]) if argomenti.size() > 0 else Aspetto.scelta()
	var quanti := int(argomenti[1]) if argomenti.size() > 1 else 10
	var di_prima := Aspetto.scelta()
	Aspetto.scegli(variante)
	DirAccess.make_dir_recursive_absolute(CARTELLA)
	Arena.modo_partita = true
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = 0.65
	var scadenza := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < scadenza and float(arena.call("conto_alla_rovescia")) > 0.0:
		await process_frame
	await _riposa(240)
	var giocatore: Giocatore = arena.call("giocatore")
	var spazio := giocatore.get_world_3d().direct_space_state
	var fatti := 0
	var tentativi := 0
	while fatti < quanti and tentativi < quanti * 30:
		tentativi += 1
		await _riposa(20)
		var coppia := _coppia_in_lotta(arena.call("avversari"), spazio)
		if coppia.is_empty():
			continue
		var chi: Node3D = coppia[0]
		var contro: Node3D = coppia[1]
		var verso := contro.global_position - chi.global_position
		verso.y = 0.0
		verso = verso.normalized()
		var dove := chi.global_position - verso * DIETRO + Vector3(1.2, 0.0, 0.0).rotated(Vector3.UP, atan2(-verso.x, -verso.z))
		if not _libero(spazio, dove + Vector3.UP * 0.9, giocatore):
			continue
		giocatore.global_position = dove
		giocatore.velocity = Vector3.ZERO
		var mira := contro.global_position + Vector3.UP * 1.0 - (dove + Vector3.UP * 1.6)
		var giro := rad_to_deg(atan2(-mira.x, -mira.z))
		var pendenza := rad_to_deg(atan2(mira.y, Vector2(mira.x, mira.z).length()))
		giocatore.punta(giro, pendenza - 2.0)
		await _riposa(6)
		giocatore.spara()
		await _riposa(9)
		await _scatta("Z%d-%d.png" % [variante, fatti])
		fatti += 1
		await _riposa(90)
	print("fatto: %d scatti, variante %d (%s)" % [fatti, variante, Aspetto.nome()])
	Aspetto.scegli(di_prima)
	quit()


## Un avversario che ha un bersaglio fra 7 e 22 metri, in vista: è una lotta che
## si può guardare da dietro le sue spalle.
func _coppia_in_lotta(avversari: Array, spazio: PhysicsDirectSpaceState3D) -> Array:
	for chi in avversari:
		var bersaglio: Node3D = (chi as Avversario).bersaglio
		if bersaglio == null or not is_instance_valid(bersaglio):
			continue
		var distanza := (chi as Node3D).global_position.distance_to(bersaglio.global_position)
		if distanza < 7.0 or distanza > 22.0:
			continue
		var raggio := PhysicsRayQueryParameters3D.create(
				(chi as Node3D).global_position + Vector3.UP * 1.4,
				bersaglio.global_position + Vector3.UP * 1.4)
		raggio.exclude = [(chi as CollisionObject3D).get_rid()]
		var tocco := spazio.intersect_ray(raggio)
		if tocco.is_empty() or tocco["collider"] == bersaglio:
			return [chi, bersaglio]
	return []


func _libero(spazio: PhysicsDirectSpaceState3D, punto: Vector3, giocatore: Giocatore) -> bool:
	var sfera := SphereShape3D.new()
	sfera.radius = 0.6
	var domanda := PhysicsShapeQueryParameters3D.new()
	domanda.shape = sfera
	domanda.transform = Transform3D(Basis(), punto)
	domanda.exclude = [giocatore.get_rid()]
	if not spazio.intersect_shape(domanda, 1).is_empty():
		return false
	# Ci deve essere un pavimento sotto, non il vuoto di un orlo.
	var giu := PhysicsRayQueryParameters3D.create(punto, punto + Vector3.DOWN * 2.0)
	giu.exclude = [giocatore.get_rid()]
	return not spazio.intersect_ray(giu).is_empty()


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var immagine := root.get_texture().get_image()
	immagine.save_png(CARTELLA + "/" + nome)
