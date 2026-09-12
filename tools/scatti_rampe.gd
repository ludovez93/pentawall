extends SceneTree

## Attrezzo di lavorazione: fotografa la rampa dell'ocra e la piattaforma, alle
## misure del telefono e con la resa a tre quarti, per riprodurre «sono salito su
## una rampa e sono nel vuoto» (dal telefono, 12/09/2026).
##   godot --path . --resolution 854x390 -s tools/scatti_rampe.gd

const CARTELLA := "res://scatti"

## Dove mettere il giocatore, dove guardare: `{nome, dove, giro, pendenza}`.
## La rampa «ocra, sale in piattaforma» va da (-9,5, -24,5) a 3,5 a (-9,5, -19,6)
## a 0: a metà sta a (-9,5, -22) a quota 1,75.
const POSTI := [
	{"nome": "R1-meta_rampa-verso_la_piattaforma", "dove": Vector3(-9.5, 2.0, -22.0), "giro": 0.0, "pendenza": -6.0},
	{"nome": "R2-meta_rampa-verso_il_campo", "dove": Vector3(-9.5, 2.0, -22.0), "giro": 180.0, "pendenza": -10.0},
	{"nome": "R3-meta_rampa-di_lato_a_est", "dove": Vector3(-9.5, 2.0, -22.0), "giro": -90.0, "pendenza": -14.0},
	{"nome": "R4-in_cima-verso_il_campo", "dove": Vector3(-9.5, 3.9, -25.0), "giro": 180.0, "pendenza": -12.0},
	{"nome": "R5-da_terra-la_rampa_di_fianco", "dove": Vector3(-2.0, 0.4, -20.0), "giro": 60.0, "pendenza": 6.0},
	{"nome": "R6-sulla_piattaforma-verso_ovest", "dove": Vector3(-8.0, 3.9, -28.0), "giro": 90.0, "pendenza": -8.0},
]

var _arena: Node
var _giocatore: Giocatore


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	_arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(_arena)
	await _riposa(40)
	_giocatore = _arena.call("giocatore")
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = 0.75
	for posto in POSTI:
		_giocatore.global_position = posto["dove"]
		_giocatore.velocity = Vector3.ZERO
		_giocatore.punta(float(posto["giro"]), float(posto["pendenza"]))
		await _riposa(12)
		print("  %s: giocatore a %s" % [posto["nome"], _giocatore.global_position])
		await _scatta(String(posto["nome"]) + ".png")
	print("fatto.")
	quit()


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var immagine := root.get_texture().get_image()
	immagine.save_png(CARTELLA + "/" + nome)
