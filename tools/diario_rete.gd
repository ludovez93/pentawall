extends SceneTree

## Attrezzo di diagnosi: disegna la rete di cammino vista dall'alto, **un carattere
## per isola**. Non fa parte del gioco.
##
## Una rete cotta è una cosa che non si vede: o si guarda, o si tira a indovinare
## (LEARNED.md § 15). Sapere che è spezzata non basta — serve sapere **dove**, o si
## aggiusta un taglio per volta rifacendo il giro ogni volta.
##
##   `.` niente rete: muro, vuoto, o pavimento troppo stretto per un corpo
##   una lettera: il pezzo di rete a cui quel posto appartiene. Stessa lettera,
##   stesso pezzo — e fra lettere diverse non si passa a piedi.
##
## Uso:  godot --path . -s tools/diario_rete.gd

const PASSO := 2.0
const META := 33.0
const VICINO := 1.4
const ARRIVO := 2.6
const LETTERE := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

var _arena: Node


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	_arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(_arena)
	# La mappa di navigazione si sincronizza nel giro della fisica, e prima di
	# allora risponde come se non ci fosse niente: chiedere subito vuol dire
	# misurare il vuoto.
	for i in 8:
		await process_frame
	for i in 4:
		await physics_frame
	var mappa: RID = _arena.get_world_3d().navigation_map
	NavigationServer3D.map_force_update(mappa)

	for quota in [0.4, 3.9, 7.4, -1.6]:
		_disegna(mappa, quota)

	quit()


func _disegna(mappa: RID, quota: float) -> void:
	# Prima si raccolgono i posti dove c'è rete, poi si guarda chi parla con chi.
	var posti: Array[Vector3] = []
	var caselle: Array = []
	var righe := 0
	var z := -META
	while z <= META:
		var riga: Array[int] = []
		var x := -META
		while x <= META:
			var punto := Vector3(x, quota, z)
			var sopra := NavigationServer3D.map_get_closest_point(mappa, punto)
			if sopra.distance_to(punto) > VICINO:
				riga.append(-1)
			else:
				riga.append(posti.size())
				posti.append(sopra)
			x += PASSO
		caselle.append(riga)
		righe += 1
		z += PASSO

	var isola := []
	isola.resize(posti.size())
	isola.fill(-1)
	var quante := 0
	var grandezze: Array[int] = []
	for i in posti.size():
		if isola[i] != -1:
			continue
		isola[i] = quante
		var grande := 1
		for j in range(i + 1, posti.size()):
			if isola[j] != -1:
				continue
			var strada := NavigationServer3D.map_get_path(mappa, posti[i], posti[j], true)
			if not strada.is_empty() and strada[-1].distance_to(posti[j]) <= ARRIVO:
				isola[j] = quante
				grande += 1
		grandezze.append(grande)
		quante += 1

	print("=== quota %.1f: %d posti in %d pezzi ===" % [quota, posti.size(), quante])
	for riga in caselle:
		var testo := ""
		for casella in riga:
			testo += "." if casella == -1 else _lettera(isola[casella])
		print(testo)
	for i in quante:
		if grandezze[i] >= 3:
			print("   %s: %d posti" % [_lettera(i), grandezze[i]])
	print("")


func _lettera(quale: int) -> String:
	return LETTERE[quale] if quale < LETTERE.length() else "?"
