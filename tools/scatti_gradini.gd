extends SceneTree

## Attrezzo di lavorazione: fotografa i posti dei gradini dalla camera vera del
## giocatore, alle misure del telefono, prima e dopo la tappa 10 (blocco A).
##
## Dal telefono, il 04/10/2026: *«alcuni gradini o mini gradini si vedevano poco e mi
## bloccavo, dovevo saltare per andare avanti»*. I posti sono quelli trovati dalla
## capsula fatta camminare sulle nove rampe (`tools/prova_gradini.gd`).
##   godot --path . --resolution 854x390 -s tools/scatti_gradini.gd [-- <suffisso>]

const CARTELLA := "res://scatti"

## Dove sta il giocatore, verso dove guarda (giro in gradi) e quanto inclina la testa.
const POSTI := [
	# Sulla scala nord-est, dentro il catino, a due metri dall'asse per stare fuori dal
	# pilone: davanti c'era il gradino di 80 cm del bordo del catino.
	{"nome": "G1-scala_dal_catino", "dove": Vector3(6.85, -1.1, -9.67), "giro": -45.0, "pendenza": -4.0},
	# In cima alla scala, verso la terrazza nord-est: l'angolo della terrazza le passava
	# sopra, e lì restava un altro gradino.
	{"nome": "G2-scala_verso_la_terrazza", "dove": Vector3(19.4, 2.8, -19.4), "giro": -45.0, "pendenza": -6.0},
	# La rampa dell'ocra, a due terzi, verso la piattaforma: in cima 31 cm.
	{"nome": "G3-ocra_verso_la_piattaforma", "dove": Vector3(-9.5, 2.2, -22.5), "giro": 0.0, "pendenza": -6.0},
	# A terra, davanti al fianco della rampa sud-est, a mezzo metro dal piede: 27 cm.
	{"nome": "G4-fianco_della_rampa_sud_est", "dove": Vector3(22.8, 0.1, 15.0), "giro": -90.0, "pendenza": -12.0},
	# Dall'ala mattone verso la scala dove passa sotto lo zero: il bordo del pavimento.
	{"nome": "G5-la_scala_vista_dall_ala", "dove": Vector3(13.5, 0.1, -9.0), "giro": 69.4, "pendenza": -16.0},
]


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var suffisso: String = argomenti[0] if argomenti.size() > 0 else "dopo"
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await _riposa(40)
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = 0.65
	var giocatore: Giocatore = arena.call("giocatore")
	for posto in POSTI:
		giocatore.global_position = posto["dove"]
		giocatore.velocity = Vector3.ZERO
		giocatore.punta(float(posto["giro"]), float(posto["pendenza"]))
		await _riposa(20)
		print("  %s: giocatore a %s" % [posto["nome"], giocatore.global_position])
		await _scatta("%s-%s.png" % [posto["nome"], suffisso])
	print("fatto.")
	quit()


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var immagine := root.get_texture().get_image()
	immagine.save_png(CARTELLA + "/" + nome)
