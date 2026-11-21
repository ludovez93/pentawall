extends SceneTree

## Attrezzo di diagnosi: **dove si cade nel vuoto**. Non fa parte del gioco.
##
## Nato il 21/11/2026, dal telefono: *«l'ultima partita mi ha fatto cadere nel vuoto
## ancora una volta»*. L'arena non ha una rete sotto: chi esce dal pavimento cade per
## sempre. Qui si cercano i posti da cui succede.
##
## Una griglia di colonne ogni dieci centimetri raccoglie i piani su cui si sta in piedi
## (come `scansione_gradini.gd`). Per ogni piano si guardano le quattro colonne vicine:
## se alla stessa altezza c'è aria e, scendendo dritti da lì, non si incontra niente,
## quella colonna è un **bordo sul vuoto**. I bordi vicini si raccolgono in buchi.
##
## Uso:  godot --headless --path . -s tools/scansione_buchi.gd -- <variante>
##       (senza numero, la variante salvata; quella di prima si rimette alla fine)

const PASSO := 0.1
## Spostata di qualche centimetro dai numeri tondi: una colonna esattamente sul filo fra
## il pavimento e la faccia di un muro (x = 40,00) passa di taglio fra i due e non tocca
## niente, ma lì il corpo non passa.
const MEZZA := 40.363
const TESTA := 1.75
## Quanto sotto il piano di partenza deve esserci ancora qualcosa: oltre, è vuoto.
const FONDO := -30.0

var _spazio: PhysicsDirectSpaceState3D


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var di_prima := Aspetto.scelta()
	var argomenti := OS.get_cmdline_user_args()
	var variante := int(argomenti[0]) if not argomenti.is_empty() else di_prima
	Aspetto.scegli(variante)
	var arena: Node3D = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	for i in 6:
		await process_frame
		await physics_frame
	_spazio = arena.get_world_3d().direct_space_state
	var inizio := Time.get_ticks_msec()

	var n := int(round(MEZZA * 2.0 / PASSO)) + 1
	var colonne := []
	colonne.resize(n * n)
	for i in n:
		for j in n:
			colonne[i * n + j] = _piani(-MEZZA + i * PASSO, -MEZZA + j * PASSO)

	# I bordi sul vuoto: chiave "i,j" -> {quota del piano da cui ci si arriva, chi}.
	var bordi := {}
	for i in n:
		for j in n:
			for piano in colonne[i * n + j]:
				var h: float = piano[0]
				for v in [[i + 1, j], [i - 1, j], [i, j + 1], [i, j - 1]]:
					if v[0] < 0 or v[1] < 0 or v[0] >= n or v[1] >= n:
						continue
					var chiave := "%d,%d" % [v[0], v[1]]
					if bordi.has(chiave):
						continue
					var x: float = -MEZZA + int(v[0]) * PASSO
					var z: float = -MEZZA + int(v[1]) * PASSO
					if _cade(x, h, z):
						bordi[chiave] = {"i": v[0], "j": v[1], "quota": h, "chi": piano[1]}

	# I buchi: bordi che si toccano (anche in diagonale).
	var visti := {}
	var buchi := []
	for chiave in bordi:
		if visti.has(chiave):
			continue
		var coda: Array = [chiave]
		visti[chiave] = true
		var b := {"n": 0, "da": Vector2(INF, INF), "a": Vector2(-INF, -INF),
				"quota_min": INF, "quota_max": -INF, "chi": {}}
		while not coda.is_empty():
			var k: String = coda.pop_back()
			var c: Dictionary = bordi[k]
			var p := Vector2(-MEZZA + int(c["i"]) * PASSO, -MEZZA + int(c["j"]) * PASSO)
			b["n"] = int(b["n"]) + 1
			b["da"] = (b["da"] as Vector2).min(p)
			b["a"] = (b["a"] as Vector2).max(p)
			b["quota_min"] = minf(b["quota_min"], c["quota"])
			b["quota_max"] = maxf(b["quota_max"], c["quota"])
			var chi: Object = c["chi"]
			if chi is Node:
				b["chi"][String((chi as Node).name)] = true
			for di in [-1, 0, 1]:
				for dj in [-1, 0, 1]:
					var k2 := "%d,%d" % [int(c["i"]) + di, int(c["j"]) + dj]
					if bordi.has(k2) and not visti.has(k2):
						visti[k2] = true
						coda.append(k2)
		buchi.append(b)
	buchi.sort_custom(func(p, q): return int(p["n"]) > int(q["n"]))

	print("%s: %d colonne di bordo sul vuoto, %d buchi (%d ms)" % [
			Aspetto.NOMI[variante], bordi.size(), buchi.size(), Time.get_ticks_msec() - inizio])
	for b in buchi:
		var da: Vector2 = b["da"]
		var a: Vector2 = b["a"]
		print("  %5d colonne   x %6.2f..%6.2f   z %6.2f..%6.2f   (%.1f × %.1f m)   da quota %.2f..%.2f   accanto a %s" % [
				b["n"], da.x, a.x, da.y, a.y, a.x - da.x + PASSO, a.y - da.y + PASSO,
				b["quota_min"], b["quota_max"], ", ".join((b["chi"] as Dictionary).keys())])
	Aspetto.scegli(di_prima)
	quit()


## I piani di una colonna su cui si sta in piedi: [quota, chi].
func _piani(x: float, z: float) -> Array:
	var fuori := []
	var da := 30.0
	for k in 16:
		var giu := PhysicsRayQueryParameters3D.create(Vector3(x, da, z), Vector3(x, -6.0, z),
				Strati.SOLIDO)
		giu.hit_back_faces = false
		var colpo := _spazio.intersect_ray(giu)
		if colpo.is_empty():
			break
		var y: float = (colpo["position"] as Vector3).y
		var normale: Vector3 = colpo["normal"]
		if normale.y > 0.7 and y < 12.0 and y > -2.6:
			var su := PhysicsRayQueryParameters3D.create(Vector3(x, y + 0.05, z),
					Vector3(x, y + TESTA, z), Strati.SOLIDO)
			if _spazio.intersect_ray(su).is_empty() and _aria(Vector3(x, y + 0.05, z)):
				fuori.append([y, colpo["collider"]])
		da = y - 0.02
	return fuori


## Da (x, h + 0.3, z), che deve essere aria, si cade dritti senza trovare niente?
func _cade(x: float, h: float, z: float) -> bool:
	var su := Vector3(x, h + 0.3, z)
	if not _aria(su):
		return false
	var giu := PhysicsRayQueryParameters3D.create(su, Vector3(x, FONDO, z), Strati.SOLIDO)
	giu.hit_back_faces = false
	return _spazio.intersect_ray(giu).is_empty()


func _aria(punto: Vector3) -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = punto
	q.collision_mask = Strati.SOLIDO
	return _spazio.intersect_point(q, 1).is_empty()
