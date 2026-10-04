extends SceneTree

## Attrezzo di diagnosi: dove il pavimento sale di colpo. Non fa parte del gioco.
##
## Una griglia di raggi dall'alto, ogni dieci centimetri, raccoglie i piani su cui si
## sta in piedi (pendenza sotto i 45° e un corpo di spazio sopra la testa). Fra due
## colonne vicine, un piano che sale di colpo fra 8 cm e 1 m è un gradino. Si contano
## solo quelli che partono da un pavimento o da una rampa: il tetto di un cassone non
## è un posto da cui si cammina.
##
## È nato il 04/10/2026, quando dal telefono è arrivato *«alcuni gradini o mini
## gradini si vedevano poco e mi bloccavo»*: ha trovato i fianchi delle rampe e la
## scala nord-est (`LEARNED.md` § 58). Dice due cose: i gradini che il corpo sale da
## solo (fino a `Gradino.ALTEZZA`) e quelli che fermano, cioè i muri bassi — che sono
## i primi da guardare quando uno dice «mi sono bloccato».
##
## Uso:  godot --headless --path . -s tools/scansione_gradini.gd

const PASSO := 0.1
const MEZZA := 33.5
## Sotto questa differenza due colonne vicine sono lo stesso piano, anche in salita:
## la rampa più ripida, 35°, sale di 7 cm ogni 10.
const CONTINUO := 0.08
const MASSIMO := 1.0
const TESTA := 1.75

var _spazio: PhysicsDirectSpaceState3D


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var arena: Node3D = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	for i in 4:
		await process_frame
		await physics_frame
	_spazio = arena.get_world_3d().direct_space_state

	var n := int(round(MEZZA * 2.0 / PASSO)) + 1
	var colonne := []
	colonne.resize(n * n)
	for i in n:
		for j in n:
			colonne[i * n + j] = _piani(-MEZZA + i * PASSO, -MEZZA + j * PASSO)

	var gruppi := {}
	for i in n:
		for j in n:
			for vicino in [[i + 1, j], [i, j + 1], [i - 1, j], [i, j - 1]]:
				if vicino[0] < 0 or vicino[1] < 0 or vicino[0] >= n or vicino[1] >= n:
					continue
				_confronta(colonne[i * n + j], colonne[vicino[0] * n + vicino[1]],
						Vector2(-MEZZA + vicino[0] * PASSO, -MEZZA + vicino[1] * PASSO), gruppi)

	var salgono := []
	var fermano := []
	for g in gruppi.values():
		if int(g["n"]) < 3:
			continue
		(fermano if float(g["massimo"]) > Gradino.ALTEZZA else salgono).append(g)
	print("\ngradini fino a %d cm, che il corpo sale da solo: %d" % [
			roundi(Gradino.ALTEZZA * 100), salgono.size()])
	_stampa(salgono)
	print("\ngradini da %d cm a 1 m, che fermano: %d" % [roundi(Gradino.ALTEZZA * 100), fermano.size()])
	_stampa(fermano)
	quit()


## I piani di una colonna, dall'alto in giù: [quota, chi, si parte da qui].
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
		if normale.y > 0.7 and y < 7.6 and y > -2.6:
			var su := PhysicsRayQueryParameters3D.create(Vector3(x, y + 0.05, z),
					Vector3(x, y + TESTA, z), Strati.SOLIDO)
			if _spazio.intersect_ray(su).is_empty():
				var chi: Object = colpo["collider"]
				var pavimento: bool = normale.y < 0.999 or (chi is Node \
						and (chi as Node).is_in_group(Muratura.GRUPPO_PAVIMENTI))
				fuori.append([y, chi, pavimento])
		da = y - 0.02
	return fuori


func _confronta(a: Array, b: Array, dove: Vector2, gruppi: Dictionary) -> void:
	for piano in a:
		if not piano[2]:
			continue
		var y: float = piano[0]
		var continuo := false
		var sale := INF
		var chi: Object = null
		for altro in b:
			var d: float = altro[0] - y
			if absf(d) <= CONTINUO:
				continuo = true
				break
			if d > CONTINUO and d <= MASSIMO and d < sale:
				sale = d
				chi = altro[1]
		if continuo or chi == null:
			continue
		var chiave := "%d|%.1f" % [chi.get_instance_id(), y]
		if not gruppi.has(chiave):
			gruppi[chiave] = {"chi": chi, "quota": y, "minimo": sale, "massimo": sale, "n": 0,
					"da": dove, "a": dove}
		var g: Dictionary = gruppi[chiave]
		g["n"] = int(g["n"]) + 1
		g["minimo"] = minf(g["minimo"], sale)
		g["massimo"] = maxf(g["massimo"], sale)
		g["da"] = (g["da"] as Vector2).min(dove)
		g["a"] = (g["a"] as Vector2).max(dove)


func _stampa(lista: Array) -> void:
	lista.sort_custom(func(p, q): return int(p["n"]) > int(q["n"]))
	for g in lista:
		var chi: Node3D = g["chi"]
		var forma := ""
		for figlio in chi.get_children():
			if figlio is CollisionShape3D and (figlio as CollisionShape3D).shape != null:
				var s := (figlio as CollisionShape3D).shape
				forma = s.get_class().replace("Shape3D", "")
				if s is BoxShape3D:
					var m: Vector3 = (s as BoxShape3D).size
					forma += " %.1f × %.1f × %.1f" % [m.x, m.y, m.z]
				break
		print("   da quota %5.2f sale %2d-%2d cm   x %5.1f..%5.1f   z %5.1f..%5.1f   contro %s a %s" % [
				g["quota"], roundi(g["minimo"] * 100), roundi(g["massimo"] * 100),
				g["da"].x, g["a"].x, g["da"].y, g["a"].y, forma,
				str(chi.global_position.snapped(Vector3.ONE * 0.1))])
