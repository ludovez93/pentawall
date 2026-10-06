extends SceneTree

## **Dove mettere i bersagli bonus** (tappa 11, blocco F): per ogni posto possibile sui
## muri, da quanta parte del pavimento si vede. Un bersaglio che nessuno vede non
## esiste; uno che si vede da tutta l'arena non chiede niente. Si sceglie con un
## numero, come le sfere: non a occhio.
##
## I posti possibili: le facce dei muri dritti, ogni `PASSO_MURO` metri, a più altezze,
## con almeno un metro libero davanti, mai addosso a una sponda (il ciano resta l'unica
## cosa che rimbalza). I punti da cui si guarda: il pavimento di tutte le quote, ogni
## `PASSO_PAVIMENTO` metri, all'altezza degli occhi. Un punto vede il bersaglio se il
## raggio arriva libero e il disco gli sta davanti (un disco si guarda di faccia).
##
## Stampa i migliori per ala e scrive tutto in `user://bonus_posti.json`.
##
## Uso:  godot --headless --path . -s tools/misura_bonus.gd

const PASSO_PAVIMENTO := 3.0
const PASSO_MURO := 3.0
## Quanto sopra la base del muro: dal petto in su, fino a sotto la cima.
const ALTEZZE := [2.2, 4.0, 6.0, 8.0, 10.0]
const OCCHI := 1.62
const PORTATA := 40.0
## Quanto sporge il disco dalla faccia del muro.
const DAVANTI := 0.12
## Di faccia: il coseno minimo fra la normale del disco e la direzione di chi guarda.
const DI_FACCIA := 0.3


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var arena: Node3D = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	for i in 3:
		await process_frame
		await physics_frame
	var pianta: Dictionary = arena.call("pianta")
	var spazio := arena.get_world_3d().direct_space_state

	var punti := _pavimento(arena, pianta, spazio)
	var vietati: Array[Vector3] = []
	for r in arena.get("_rinascite"):
		vietati.append(r["dove"])
	var sfere: Array[Vector3] = []
	for s in arena.call("sfere_della_pianta"):
		sfere.append(s["dove"])
	var candidati := _candidati(pianta, spazio)
	print("punti di pavimento: %d, posti sui muri: %d" % [punti.size(), candidati.size()])

	var inizio := Time.get_ticks_msec()
	for c in candidati:
		var dove: Vector3 = c["dove"]
		var normale: Vector3 = c["normale"]
		var visti := 0
		for p in punti:
			var occhio := p + Vector3(0, OCCHI, 0)
			var verso := dove - occhio
			var lungo := verso.length()
			if lungo > PORTATA or lungo < 2.0:
				continue
			if normale.dot(-verso / lungo) < DI_FACCIA:
				continue
			var domanda := PhysicsRayQueryParameters3D.create(occhio,
					dove - verso / lungo * 0.3, Strati.SOLIDO)
			if spazio.intersect_ray(domanda).is_empty():
				visti += 1
		c["visti"] = visti
		c["quota_vista"] = 100.0 * visti / float(punti.size())
		c["da_rinascite"] = _piu_vicino(dove, vietati)
		c["da_sfere"] = _piu_vicino(dove, sfere)
		c["zona"] = _zona_davanti(pianta, dove + normale * 2.0)
	print("raggi in %d ms" % (Time.get_ticks_msec() - inizio))

	candidati.sort_custom(func(a, b): return a["visti"] > b["visti"])
	var per_zona := {}
	for c in candidati:
		var z := String(c["zona"])
		if not per_zona.has(z):
			per_zona[z] = []
		if (per_zona[z] as Array).size() < 5 and c["da_rinascite"] >= 8.0 and c["da_sfere"] >= 6.0:
			per_zona[z].append(c)
	for z in per_zona:
		print("== %s" % z)
		for c in per_zona[z]:
			print("   %5.1f%%  %s  normale %s  muro «%s»  da rinascite %.0f m, da sfere %.0f m" % [
				c["quota_vista"], _testo(c["dove"]), _testo(c["normale"]), c["muro"],
				c["da_rinascite"], c["da_sfere"]])

	var uscita := []
	for c in candidati:
		uscita.append({"dove": [c["dove"].x, c["dove"].y, c["dove"].z],
				"normale": [c["normale"].x, c["normale"].z], "muro": c["muro"],
				"zona": c["zona"], "vista": c["quota_vista"],
				"da_rinascite": c["da_rinascite"], "da_sfere": c["da_sfere"]})
	var file := FileAccess.open("user://bonus_posti.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(uscita))
	file.close()
	print("scritto %s" % ProjectSettings.globalize_path("user://bonus_posti.json"))
	quit()


## Il pavimento da cui si guarda: ogni zona già ritagliata dalle rampe, a passo fisso,
## scartando i punti dentro un cassone o un muro.
func _pavimento(arena: Node3D, pianta: Dictionary, spazio: PhysicsDirectSpaceState3D) -> Array[Vector3]:
	var punti: Array[Vector3] = []
	var sfera := SphereShape3D.new()
	sfera.radius = 0.45
	var domanda := PhysicsShapeQueryParameters3D.new()
	domanda.shape = sfera
	domanda.collision_mask = Strati.SOLIDO
	var zone: Array = pianta["zone"]
	for i in zone.size():
		var quota := float(zone[i]["quota"])
		var pezzi: Array = arena.call("pezzi_della_zona", i)
		for pezzo in pezzi:
			var scatola := Rect2(pezzo[0], Vector2.ZERO)
			for v in pezzo:
				scatola = scatola.expand(v)
			var x := scatola.position.x + 0.37
			while x < scatola.end.x:
				var z := scatola.position.y + 0.41
				while z < scatola.end.y:
					if Geometry2D.is_point_in_polygon(Vector2(x, z), pezzo):
						domanda.transform = Transform3D(Basis.IDENTITY, Vector3(x, quota + 0.95, z))
						if spazio.intersect_shape(domanda, 1).is_empty():
							punti.append(Vector3(x, quota, z))
					z += PASSO_PAVIMENTO
				x += PASSO_PAVIMENTO
	return punti


## I posti possibili sulle facce dei muri dritti.
func _candidati(pianta: Dictionary, spazio: PhysicsDirectSpaceState3D) -> Array:
	var fuori := []
	var sfera := SphereShape3D.new()
	sfera.radius = 0.5
	var libero := PhysicsShapeQueryParameters3D.new()
	libero.shape = sfera
	libero.collision_mask = Strati.SOLIDO
	var mezza := float(pianta["misura"]["larghezza"]) * 0.5
	for m in pianta["muri"]:
		if float(m.get("giro", 0)) != 0.0:
			continue
		var c := Vector2(float(m["centro"][0]), float(m["centro"][1]))
		var mis := Vector2(float(m["misura"][0]), float(m["misura"][1]))
		var base := float(m["quota"])
		var cima := base + float(m["alto"])
		for faccia in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var lungo_x: bool = faccia.y != 0.0
			var lunghezza := mis.x if lungo_x else mis.y
			if lunghezza < 2.0:
				continue
			var piano := c + Vector2(faccia.x * mis.x, faccia.y * mis.y) * 0.5
			var t := -lunghezza * 0.5 + 1.0
			while t <= lunghezza * 0.5 - 1.0:
				var p2 := piano + (Vector2(t, 0) if lungo_x else Vector2(0, t))
				for h in ALTEZZE:
					var y := base + float(h)
					if y > cima - 0.8:
						continue
					var normale := Vector3(faccia.x, 0, faccia.y)
					var dove := Vector3(p2.x, y, p2.y) + normale * DAVANTI
					if absf(dove.x) > mezza or absf(dove.z) > mezza:
						continue
					libero.transform = Transform3D(Basis.IDENTITY, dove + normale * 0.65)
					if not spazio.intersect_shape(libero, 1).is_empty():
						continue
					if _sopra_una_sponda(pianta, dove):
						continue
					fuori.append({"dove": dove, "normale": normale, "muro": String(m["nome"])})
				t += PASSO_MURO
	return fuori


func _sopra_una_sponda(pianta: Dictionary, dove: Vector3) -> bool:
	for s in pianta["sponde"]:
		if s.has("sdraiata"):
			continue
		var c := Vector3(float(s["centro"][0]), float(s["quota"]), float(s["centro"][1]))
		var w := float(s["faccia"][0]) * 0.5 + 0.8
		var h := float(s["faccia"][1]) * 0.5 + 0.8
		var d := dove - c
		if absf(d.y) > h or Vector2(d.x, d.z).length() > w + 0.6:
			continue
		return true
	return false


func _piu_vicino(dove: Vector3, posti: Array[Vector3]) -> float:
	var minimo := INF
	for p in posti:
		minimo = minf(minimo, Vector2(p.x - dove.x, p.z - dove.z).length())
	return minimo


func _zona_davanti(pianta: Dictionary, dove: Vector3) -> String:
	var migliore := "fuori"
	var quota_migliore := -INF
	for z in pianta["zone"]:
		var poligono := PackedVector2Array()
		for v in z["poligono"]:
			poligono.append(Vector2(float(v[0]), float(v[1])))
		var q := float(z["quota"])
		if q <= dove.y and q > quota_migliore and Geometry2D.is_point_in_polygon(Vector2(dove.x, dove.z), poligono):
			migliore = String(z["nome"])
			quota_migliore = q
	return migliore


func _testo(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
