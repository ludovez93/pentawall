extends SceneTree

## Attrezzo di lavorazione: **l'immagine del blocco A della tappa 14** — una schermata
## vera dello scontro nel PARCO GONFIABILE, da mettere accanto alla pubblicità di
## riferimento. La partita gira davvero; dopo qualche secondo chi gioca si mette nel
## posto scelto, con tre avversari davanti e la tribuna dietro di loro, e tira al più
## centrale: lo scatto parte quando la stella del colpo è aperta.
##   godot --path . --resolution 854x390 --fixed-fps 30 -s tools/scatti_blocco_a.gd -- [scala] [prova]
## `scala` è la scala della scena (0.65 quella del telefono di oggi, 1.0 piena). Con
## `prova` fotografa solo le inquadrature candidate, senza comporre.
## Gli scatti escono in `scatti/` come `A14-<scala>.png` (e `A14-prova-<n>.png`).

const CARTELLA := "res://scatti"

## Le inquadrature: dove sta chi gioca, verso dove guarda (gradi, 0 = nord, 90 = ovest),
## e gli avversari in metri davanti (primo numero) e a destra (secondo) di chi gioca.
## Il primo avversario è quello a cui si tira. La prima inquadratura è quella dello scatto;
## le altre servono con `prova`, per sceglierla guardando.
const INQUADRATURE := [
	{"posto": Vector3(-18.5, 0.0, -11.0), "giro": 53.0,
			"avversari": [Vector2(6.0, -3.4), Vector2(7.5, -6.2), Vector2(3.4, 4.6), Vector2(12.0, 3.0)]},
	{"posto": Vector3(-18.5, 0.0, -11.0), "giro": 60.0,
			"avversari": [Vector2(8.0, 1.6), Vector2(6.0, -3.4), Vector2(11.5, 5.0)]},
	{"posto": Vector3(-20.0, 0.0, -8.0), "giro": 55.0,
			"avversari": [Vector2(8.0, 1.2), Vector2(6.5, -3.6), Vector2(11.0, 4.5)]},
	{"posto": Vector3(-19.0, 0.0, -6.0), "giro": 62.0,
			"avversari": [Vector2(8.0, 1.5), Vector2(6.0, -3.5), Vector2(12.0, 4.5)]},
	{"posto": Vector3(-21.0, 0.0, -12.0), "giro": 45.0,
			"avversari": [Vector2(7.5, 1.4), Vector2(6.0, -3.4), Vector2(10.5, 4.5)]},
	{"posto": Vector3(-18.5, 0.0, -11.0), "giro": 68.0,
			"avversari": [Vector2(8.0, 1.6), Vector2(6.0, -3.4), Vector2(11.5, 5.0)]},
]
## La pendenza della visuale di chi corre: il personaggio si vede intero.
const PENDENZA := -11.0
## Secondi di partita prima di comporre: la classifica e il tabellone hanno dei punti.
const PARTITA := 14.0

var _messi: Array[Node3D] = []
var _posti: Array[Vector3] = []


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var scala := float(argomenti[0]) if argomenti.size() > 0 else 0.65
	var prova := argomenti.size() > 1 and argomenti[1] == "prova"
	var di_prima := Aspetto.scelta()
	Aspetto.scegli(Aspetto.GONFIABILE)
	DirAccess.make_dir_recursive_absolute(CARTELLA)
	Arena.modo_partita = true
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = scala
	# L'arena nasce a passi: prima che ci sia chi gioca il conto alla rovescia è già zero.
	var scadenza := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < scadenza and arena.call("giocatore") == null:
		await process_frame
	await _riposa(20)
	while Time.get_ticks_msec() < scadenza and float(arena.call("conto_alla_rovescia")) > 0.0:
		await process_frame
	var giocatore: Giocatore = arena.call("giocatore")
	await _riposa(int(PARTITA * 30.0))
	if prova:
		for i in INQUADRATURE.size():
			_disponi(arena, giocatore, INQUADRATURE[i])
			await _fermi(12)
			giocatore.set("_immunita", 0.0)
			await _fermi(2)
			await _scatta("A14-prova-%d.png" % i)
	else:
		var fatto := false
		for tentativo in 4:
			if await _componi(arena, giocatore, INQUADRATURE[0]):
				await _scatta("A14-%s.png" % str(scala).replace(".", ""))
				fatto = true
				break
			await _riposa(45)
		print("blocco A: %s, scala %.2f" % ["scatto fatto" if fatto else "NESSUN COLPO A SEGNO", scala])
	Aspetto.scegli(di_prima)
	quit()


## Mette chi gioca e gli avversari al loro posto nell'inquadratura.
func _disponi(arena: Node, giocatore: Giocatore, quadro: Dictionary) -> void:
	var posto: Vector3 = quadro["posto"]
	var giro := float(quadro["giro"])
	var avanti := Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(giro))
	var destra := Vector3(1, 0, 0).rotated(Vector3.UP, deg_to_rad(giro))
	giocatore.global_position = posto
	giocatore.velocity = Vector3.ZERO
	giocatore.punta(giro, PENDENZA)
	# Mentre ci si dispone chi gioca non si può colpire: un colpo preso lo farebbe
	# ricomparire dall'altra parte dell'arena. La protezione si toglie prima dello scatto,
	# perché chi è protetto lampeggia.
	giocatore.proteggi(30.0)
	var avversari: Array = arena.call("avversari")
	var dove: Array = quadro["avversari"]
	_messi.clear()
	_posti.clear()
	for i in avversari.size():
		var bot := avversari[i] as Node3D
		if i < dove.size():
			_messi.append(bot)
			_posti.append(posto + avanti * (dove[i] as Vector2).x + destra * (dove[i] as Vector2).y)
		else:
			# Gli altri lontano, dall'altra parte dell'arena: fuori dall'inquadratura.
			bot.global_position = Vector3(30.0, 0.0, 20.0 + 3.0 * float(i))


## Lascia passare dei fotogrammi tenendo gli avversari dell'inquadratura al loro posto:
## la partita gira, e in mezzo secondo se ne andrebbero ognuno per la sua strada.
func _fermi(fotogrammi: int) -> void:
	for f in fotogrammi:
		for i in _messi.size():
			if is_instance_valid(_messi[i]):
				_messi[i].global_position = _posti[i]
				(_messi[i] as CharacterBody3D).velocity = Vector3.ZERO
		await process_frame


## Dispone tutti, tira al primo avversario e aspetta che il colpo vada a segno: lo scatto
## vale solo se i punti di chi gioca sono saliti (una stella può essere di un altro duello).
func _componi(arena: Node, giocatore: Giocatore, quadro: Dictionary) -> bool:
	_disponi(arena, giocatore, quadro)
	await _fermi(6)
	for colpo in 8:
		var prima := _punti_miei(arena)
		var mira := _posti[0] + Vector3.UP * 1.0 - (giocatore.global_position + Vector3.UP * 1.6)
		# La camera sta sopra la spalla destra, non dietro la testa: perché il mirino cada
		# sull'avversario ci si gira a sinistra di quell'angolo, e a ogni colpo mancato si
		# prova un grado e mezzo più in là, da una parte e dall'altra.
		var lontano := Vector2(mira.x, mira.z).length()
		var spalla := rad_to_deg(atan2(Giocatore.SPALLA_TERZA, lontano + Giocatore.BRACCIO_TERZA))
		var scarto := 1.5 * float((colpo + 1) / 2) * (1.0 if colpo % 2 == 0 else -1.0)
		giocatore.punta(rad_to_deg(atan2(-mira.x, -mira.z)) + spalla + scarto,
				rad_to_deg(atan2(mira.y, lontano)) - 2.0)
		await _fermi(2)
		giocatore.spara()
		for i in 16:
			await _fermi(1)
			# Solo il colpo diretto, 25 punti: un colpo di sponda che prende un altro non è
			# lo scatto che si vuole (il rimbalzo non è il soggetto, `DECISIONI.md` § 20).
			if _punti_miei(arena) == prima + 25:
				# Chi è stato colpito ricompare altrove: non lo si tiene più fermo. Il
				# pollice torna giù: la visuale di chi corre, col personaggio intero.
				_messi.remove_at(0)
				_posti.remove_at(0)
				giocatore.punta(float(quadro["giro"]), PENDENZA)
				giocatore.set("_immunita", 0.0)
				await _fermi(3)
				return true
	return false


func _punti_miei(arena: Node) -> int:
	for riga in arena.call("classifica"):
		if bool(riga["tu"]):
			return int(riga["punti"])
	return 0


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var immagine := root.get_texture().get_image()
	immagine.save_png(CARTELLA + "/" + nome)
