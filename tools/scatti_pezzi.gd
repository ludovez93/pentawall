extends SceneTree

## Attrezzo di lavorazione: **i tre pezzi di prova da vicino** (tappa 11, blocco C3b,
## passo 1). Il gonfiabile si riconosce da tre cose — le cuciture fra un rocchio e
## l'altro, la sfumatura che scurisce verso le pieghe, il punto di luce sul colmo — e
## quelle tre cose non si giudicano in un fotogramma di gioco: si guardano a due metri.
##
## I pezzi sono presi dalla pianta, non messi a mano, così da una variante all'altra
## l'inquadratura è la stessa: una colonna, uno scivolo (la prima rampa del catino) e la
## vasca di palline sul fondo del catino. La camera cerca da sé un posto da cui il pezzo
## si veda: in mezzo all'arena c'è sempre qualcosa davanti, e un punto scritto a mano
## vale solo per una variante. L'interfaccia è sempre spenta.
##
## Vuole la finestra: senza schermo il fotogramma non c'è e resta appeso.
##   godot --path . --resolution 1280x720 -s tools/scatti_pezzi.gd [-- <variante>]
## Gli scatti escono come `Z<variante>-<pezzo>.png`.

const CARTELLA := "res://scatti"

var _camera: Camera3D
var _spazio: PhysicsDirectSpaceState3D


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
	root.scaling_3d_scale = 1.0
	var scadenza := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < scadenza and not bool(arena.get("_sfida")):
		await process_frame
	await _riposa(40)
	for strato: CanvasLayer in root.find_children("*", "CanvasLayer", true, false):
		strato.visible = false
	# Chi gioca e gli avversari stanno in mezzo ai pezzi: si tolgono dalla vista.
	(arena.giocatore() as Node3D).global_position = Vector3(0, -80, 0)
	for chi in arena.avversari():
		(chi as Node3D).global_position = Vector3(0, -80, 0)
	await _riposa(6)

	_spazio = arena.get_world_3d().direct_space_state
	_camera = Camera3D.new()
	_camera.fov = 48.0
	root.add_child(_camera)
	_camera.make_current()

	var pianta := arena.pianta()
	var prefisso := "Z%d-" % variante

	# 1. Una colonna intera: da lontano quanto è alta, così le cuciture si contano.
	var colonna := _colonna(pianta)
	if colonna.is_empty():
		print("nessuna colonna nella pianta")
	else:
		var piede: Vector3 = colonna["piede"]
		var alto: float = minf(float(colonna["alto"]), 7.0)
		await _guarda(piede + Vector3(0, alto * 0.5, 0), maxf(5.0, alto * 1.1), 0.18)
		await _scatta(prefisso + "1-colonna.png")

	# 2. Lo scivolo del catino, di tre quarti dall'alto: si vede il piano della salita.
	var rampe: Array = pianta["rampe"]
	if rampe.is_empty():
		print("nessuna rampa nella pianta")
	else:
		var r: Dictionary = rampe[0]
		var da := Vector3(float(r["da"][0]), float(r["quota_da"]), float(r["da"][1]))
		var a := Vector3(float(r["a"][0]), float(r["quota_a"]), float(r["a"][1]))
		# Dalla cima, guardando in giu lungo la salita: il pilone in asse al piede della
		# rampa resta in fondo, e il piano dello scivolo riempie lo scatto.
		var lungo := Vector3(a.x - da.x, 0.0, a.z - da.z).normalized()
		await _posa(a + lungo * 2.4 + Vector3(0, 3.0, 0), da.lerp(a, 0.45) + Vector3(0, 0.2, 0))
		await _scatta(prefisso + "2-scivolo.png")

	# 3. La vasca di palline: in un angolo del fondo del catino, dove sono più fitte.
	await _guarda(Vector3(-1.5, -1.9, -12.0), 3.0, 0.10)
	await _scatta(prefisso + "3-vasca.png")

	print("fatto: variante %d (%s)" % [variante, Aspetto.nome()])
	Aspetto.scegli(di_prima)
	quit()


## La colonna più vicina al centro dell'arena, presa dalla pianta: il piede e l'altezza.
## Un pilone è un muro quadrato col nome che lo dice.
func _colonna(pianta: Dictionary) -> Dictionary:
	var scelto := {}
	var quanto := 1e9
	for m: Dictionary in pianta["muri"]:
		var nome := String(m.get("nome", ""))
		if not (nome.contains("pilone") or nome.contains("colonna") or nome.contains("pilastro")):
			continue
		var misura := Vector2(float(m["misura"][0]), float(m["misura"][1]))
		if absf(misura.x - misura.y) > 0.4:
			continue
		var dove := Vector2(float(m["centro"][0]), float(m["centro"][1]))
		if dove.length() < quanto:
			quanto = dove.length()
			scelto = {
				"piede": Vector3(dove.x, float(m.get("quota", 0.0)), dove.y),
				"alto": float(m.get("alto", 4.0)),
			}
	return scelto


## La camera a `quanto` metri da `punto`, inclinata di `su`, nel primo verso da cui il
## punto si vede davvero: si gira attorno a passi di trenta gradi e si tira un raggio.
## Se nessun verso è libero si tiene il primo, perché uno scatto storto dice più di
## nessuno scatto.
func _guarda(punto: Vector3, quanto: float, su: float) -> void:
	var scelto := Vector3(1.0, su, 0.75).normalized()
	for k in 12:
		var verso := Vector3(1.0, su, 0.75).normalized().rotated(Vector3.UP, TAU * float(k) / 12.0)
		var dove := punto + verso * quanto
		var raggio := PhysicsRayQueryParameters3D.create(punto, dove, Strati.SOLIDO)
		if _spazio.intersect_ray(raggio).is_empty():
			scelto = verso
			break
	await _posa(punto + scelto * quanto, punto)


## La camera in `dove`, che guarda `punto`.
func _posa(dove: Vector3, punto: Vector3) -> void:
	_camera.global_position = dove
	_camera.look_at(punto, Vector3.UP)
	await _riposa(4)


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(CARTELLA + "/" + nome)
	print("  ", nome)
