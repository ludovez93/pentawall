extends SceneTree

## Attrezzo di lavorazione: fotografa i soffitti dalle partenze, alle misure del
## telefono e con la resa a tre quarti, per riprodurre «alcuni tetti non si
## vedono, cammino nel vuoto» (dal telefono, 12/09/2026).
##   godot --path . --resolution 854x390 -s tools/scatti_tetti.gd [-- chiaro] [-- solo]
## `chiaro`: i soffitti con una tinta più chiara, per separare «troppo scuro» da
## «non illuminato». `solo`: soltanto le partenze mattone e tribuna.

const CARTELLA := "res://scatti"
const TINTA_SOFFITTO := Color(0.36, 0.34, 0.60)

var _arena: Node
var _giocatore: Giocatore
var _chiaro := false
var _solo := false
var _suffisso := ""


func _initialize() -> void:
	var argomenti := OS.get_cmdline_user_args()
	_chiaro = argomenti.has("chiaro")
	_solo = argomenti.has("solo")
	if _chiaro:
		_suffisso = "-chiaro"
	_lavora()


func _lavora() -> void:
	_arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(_arena)
	await _riposa(40)
	_giocatore = _arena.call("giocatore")
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = 0.75
	if _chiaro:
		_schiarisci_i_soffitti()
	var pianta: Dictionary = _arena.call("pianta")
	for i in pianta["partenze"].size():
		var p: Dictionary = pianta["partenze"][i]
		if _solo and not (i == 2 or i == 4):
			continue
		_arena.call("_mettiti_alla_partenza", i)
		# Guardando avanti e un po' in su: è dove stanno i soffitti.
		_giocatore.punta(float(p["giro"]), 14.0)
		await _riposa(12)
		await _scatta("T%d-%s-su%s.png" % [i, _nome(p), _suffisso])
		_giocatore.punta(float(p["giro"]) + 90.0, 18.0)
		await _riposa(12)
		await _scatta("T%d-%s-sinistra%s.png" % [i, _nome(p), _suffisso])
	print("fatto.")
	quit()


func _nome(p: Dictionary) -> String:
	return String(p["nome"]).replace(" ", "_").replace(",", "")


## I soffitti sono i muri con la tinta del soffitto: si riconoscono dal materiale.
func _schiarisci_i_soffitti() -> void:
	var quanti := 0
	for nodo in _arena.find_children("*", "MeshInstance3D", true, false):
		var pezzo := nodo as MeshInstance3D
		var materiale := pezzo.material_override as StandardMaterial3D
		if materiale == null:
			continue
		if materiale.albedo_color.is_equal_approx(TINTA_SOFFITTO):
			materiale.albedo_color = Color(0.55, 0.52, 0.80)
			quanti += 1
	print("  soffitti schiariti: ", quanti)


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var immagine := root.get_texture().get_image()
	immagine.save_png(CARTELLA + "/" + nome)
	print("  ", nome)
