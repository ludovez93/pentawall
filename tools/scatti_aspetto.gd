extends SceneTree

## Attrezzo di lavorazione: fotografa una variante dell'aspetto (tappa 10, blocco C)
## sempre dalle stesse inquadrature, con l'interfaccia della partita, alle misure del
## telefono e con la resa del telefono. Le direzioni si scelgono su questi scatti, non
## su un campionario: stessa arena, stessi posti, cambia solo l'aspetto.
##   godot --path . --resolution 854x390 -s tools/scatti_aspetto.gd -- <variante>
## Gli scatti escono come `A<variante>-<n>-<posto>.png`.

const CARTELLA := "res://scatti"

## I posti degli scatti dell'arena (`scatti_arena.gd`) più la partenza, con la camera
## vera del giocatore: dove sta, verso dove guarda, quanto inclina la testa.
const POSTI := [
	{"nome": "partenza", "dove": Vector3(-29.0, 0.6, -29.0), "giro": 225.0, "pendenza": -4.0},
	{"nome": "dal_catino", "dove": Vector3(0.0, -1.4, 8.0), "giro": 0.0, "pendenza": 6.0},
	{"nome": "dal_ballatoio", "dove": Vector3(0.0, 7.6, 20.0), "giro": 0.0, "pendenza": -10.0},
	{"nome": "corridoio_del_mattone", "dove": Vector3(29.0, 0.6, 11.0), "giro": 355.0, "pendenza": -1.0},
	{"nome": "ala_ocra", "dove": Vector3(9.0, 0.6, -20.0), "giro": 200.0, "pendenza": -4.0},
	{"nome": "dalla_terrazza", "dove": Vector3(27.0, 4.1, -27.0), "giro": 135.0, "pendenza": -8.0},
	{"nome": "tribuna", "dove": Vector3(-16.0, 0.6, 6.0), "giro": 105.0, "pendenza": 4.0},
]


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var variante := int(argomenti[0]) if argomenti.size() > 0 else Aspetto.scelta()
	# La scelta di chi lavora su questo PC si rimette com'era alla fine: i collaudi
	# costruiscono l'arena nella variante salvata, e devono trovare quella di oggi.
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
	await _riposa(20)
	var giocatore: Giocatore = arena.call("giocatore")
	# Gli avversari restano in campo ma fermi lontano: si guarda l'arena, e due o tre
	# corpi in vista si mettono davanti alla camera quando serve (la partita a sei è
	# già negli scatti della partita).
	for chi in arena.call("avversari"):
		(chi as Node3D).process_mode = Node.PROCESS_MODE_DISABLED
	for i in POSTI.size():
		var posto: Dictionary = POSTI[i]
		giocatore.global_position = posto["dove"]
		giocatore.velocity = Vector3.ZERO
		giocatore.punta(float(posto["giro"]), float(posto["pendenza"]))
		await _riposa(14)
		await _scatta("A%d-%d-%s.png" % [variante, i, posto["nome"]])
	print("fatto: variante %d (%s)" % [variante, Aspetto.nome()])
	Aspetto.scegli(di_prima)
	quit()


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var immagine := root.get_texture().get_image()
	immagine.save_png(CARTELLA + "/" + nome)
