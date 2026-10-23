extends SceneTree

## **Dove mettere le due porte e gli otto cannoni della PALLA** (tappa 11, blocco D2):
## misurato sulla pianta e sulla rete di cammino, non a occhio, come le sfere, i bersagli
## bonus e le bandiere.
##
## **Le porte** stanno a terra (quota 0) con la schiena contro un muro alto, la bocca verso
## il campo. Un posto vale se: davanti c'è una corsia libera per tirare (`CORSIA` metri),
## la porta ci sta intera, è lontana da partenze e rinascite (non si nasce in porta) e da
## sfere e bersagli bonus. Fra quelli buoni conta **da quanta parte del pavimento si vede la
## bocca**: una porta che nessuno vede non chiama nessuno. Le due porte si scelgono in due
## ali diverse e lontane, la coppia con la vista peggiore più alta.
##
## **I cannoni** sono due per ala (ocra, mattone, portico, tribuna): punti del pavimento con
## spazio intorno (la palla esce in aria e ricade lì vicino), sulla rete, lontani dalle porte
## e da partenze, rinascite e sfere. Fra quelli buoni contano **le strade che ci passano**:
## i percorsi della rete fra tutti i punti di rinascita, come per le sfere. I due di un'ala
## stanno ad almeno `FRA_CANNONI` metri.
##
## Scrive `user://porte_posti.json` (porte, cannoni, e i punti di pavimento per l'immagine).
## Uso:  godot --headless --path . -s tools/misura_porte.gd

const LARGA := 4.0
const FONDA := 1.6
const ALTA := 2.5
const CORSIA := 10.0
const PASSO_MURO := 1.0
const PASSO_PAVIMENTO := 3.0
const OCCHI := 1.62
const PORTATA := 45.0
const DI_FACCIA := 0.25
const DA_RINASCITE := 8.0
const DA_SFERE := 6.0
const DA_BONUS := 5.0
const FRA_PORTE := 55.0
## Il coseno massimo fra le direzioni delle due porte viste dal centro: sotto −0,5, cioè a
## più di 120 gradi l'una dall'altra.
const OPPOSTE := -0.5
const ALI := ["ala ocra", "ala mattone", "portico", "ala tribuna"]
const CANNONI_PER_ALA := 2
const LIBERO_CANNONE := 2.6
const DA_PORTE := 12.0
const FRA_CANNONI := 9.0
const STRADA := 2.5


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var arena: Arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var mappa := arena.get_world_3d().navigation_map
	var scadenza := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < scadenza and NavigationServer3D.map_get_iteration_id(mappa) == 0:
		await physics_frame
	for i in 3:
		await process_frame
		await physics_frame
	NavigationServer3D.map_force_update(mappa)
	var pianta := arena.pianta()
	var spazio := arena.get_world_3d().direct_space_state

	var rinascite: Array[Vector3] = []
	for r in arena.get("_rinascite"):
		rinascite.append(r["dove"] - Vector3(0, 0.4, 0))
	var sfere: Array[Vector3] = []
	for s in arena.sfere_della_pianta():
		sfere.append(s["dove"])
	var bonus: Array[Vector3] = []
	for b in pianta.get("bonus", []):
		bonus.append(Vector3(float(b["dove"][0]), float(b["quota"]), float(b["dove"][1])))
	var pavimento := _pavimento(arena, pianta, spazio)
	print("punti di pavimento: %d" % pavimento.size())

	# ---- le porte
	var porte := _posti_per_porte(pianta, spazio)
	var buone := []
	for p in porte:
		var bocca: Vector3 = p["bocca"]
		if _piu_vicino(bocca, rinascite) < DA_RINASCITE or _piu_vicino(bocca, sfere) < DA_SFERE \
				or _piu_vicino(bocca, bonus) < DA_BONUS:
			continue
		var visti := 0
		var centro := bocca + Vector3(0, ALTA * 0.5, 0)
		for q in pavimento:
			var occhio := q + Vector3(0, OCCHI, 0)
			var verso := centro - occhio
			var lungo := verso.length()
			if lungo > PORTATA or lungo < 3.0:
				continue
			if (p["normale"] as Vector3).dot(-verso / lungo) < DI_FACCIA:
				continue
			var domanda := PhysicsRayQueryParameters3D.create(occhio, centro - verso / lungo * 0.4, Strati.SOLIDO)
			if spazio.intersect_ray(domanda).is_empty():
				visti += 1
		p["vista"] = 100.0 * visti / float(pavimento.size())
		p["zona"] = _zona(pianta, bocca + (p["normale"] as Vector3) * 3.0)
		buone.append(p)
	print("posti per le porte: %d, buoni: %d" % [porte.size(), buone.size()])
	buone.sort_custom(func(a, b): return float(a["vista"]) > float(b["vista"]))
	for p in buone:
		print("   %5.1f%%  %-14s bocca %s verso %s  muro «%s»" % [p["vista"], p["zona"], _testo(p["bocca"]),
				_testo(p["normale"]), p["muro"]])
	var coppia := []
	var migliore := -1.0
	for i in buone.size():
		for j in range(i + 1, buone.size()):
			var a: Dictionary = buone[i]
			var b: Dictionary = buone[j]
			if a["zona"] == b["zona"] or (a["bocca"] as Vector3).distance_to(b["bocca"]) < FRA_PORTE:
				continue
			# Da lati opposti dell'arena: due porte nella stessa metà lascerebbero l'altra metà
			# senza niente da fare (la prima misura le metteva tutte e due a sud).
			var pa := Vector2((a["bocca"] as Vector3).x, (a["bocca"] as Vector3).z).normalized()
			var pb := Vector2((b["bocca"] as Vector3).x, (b["bocca"] as Vector3).z).normalized()
			if pa.dot(pb) > OPPOSTE:
				continue
			var peggiore := minf(float(a["vista"]), float(b["vista"]))
			if peggiore > migliore:
				migliore = peggiore
				coppia = [a, b]
	if coppia.is_empty():
		print("NESSUNA COPPIA DI PORTE")
		quit(1)
		return
	print("le porte: %s (%.1f%%) e %s (%.1f%%), a %.0f m" % [coppia[0]["zona"], coppia[0]["vista"],
			coppia[1]["zona"], coppia[1]["vista"], (coppia[0]["bocca"] as Vector3).distance_to(coppia[1]["bocca"])])

	# ---- i cannoni
	var strade: Array = []
	for i in rinascite.size():
		for j in range(i + 1, rinascite.size()):
			var da := NavigationServer3D.map_get_closest_point(mappa, rinascite[i])
			var a := NavigationServer3D.map_get_closest_point(mappa, rinascite[j])
			strade.append(NavigationServer3D.map_get_path(mappa, da, a, true))
	var cannoni := []
	for ala in ALI:
		var candidati := []
		for q in pavimento:
			if _zona(pianta, q + Vector3(0, 0.1, 0)) != ala:
				continue
			if not _libero(spazio, q, LIBERO_CANNONE):
				continue
			if NavigationServer3D.map_get_closest_point(mappa, q).distance_to(q) > 0.6:
				continue
			if _piu_vicino(q, rinascite) < 4.0 or _piu_vicino(q, sfere) < 4.0:
				continue
			var lontano := true
			for p in coppia:
				if (p["bocca"] as Vector3).distance_to(q) < DA_PORTE:
					lontano = false
			if not lontano:
				continue
			var passano := 0
			for via in strade:
				if _passa_vicino(via, q):
					passano += 1
			candidati.append({"dove": q, "strade": passano})
		candidati.sort_custom(func(a, b): return int(a["strade"]) > int(b["strade"]))
		var presi := []
		for c in candidati:
			var vicino := false
			for p in presi:
				if (p["dove"] as Vector3).distance_to(c["dove"]) < FRA_CANNONI:
					vicino = true
			if not vicino:
				presi.append(c)
			if presi.size() >= CANNONI_PER_ALA:
				break
		print("== %s: %d posti buoni" % [ala, candidati.size()])
		for p in presi:
			print("   cannone %s, ci passano %d strade su %d" % [_testo(p["dove"]), p["strade"], strade.size()])
			cannoni.append({"zona": ala, "dove": p["dove"], "strade": p["strade"]})

	var esito := {"porte": [], "cannoni": [], "pavimento": []}
	for p in coppia:
		esito["porte"].append({"zona": p["zona"], "muro": p["muro"], "vista": snappedf(p["vista"], 0.1),
				"bocca": _lista(p["bocca"]), "normale": [p["normale"].x, p["normale"].z]})
	for c in cannoni:
		esito["cannoni"].append({"zona": c["zona"], "dove": _lista(c["dove"]), "strade": c["strade"]})
	var file := FileAccess.open("user://porte_posti.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(esito, "  "))
	file.close()
	print("scritto %s" % ProjectSettings.globalize_path("user://porte_posti.json"))
	quit()


## I posti possibili per una porta: le facce dei muri dritti alti almeno quanto la porta,
## con la base a quota 0, ogni `PASSO_MURO` metri; la porta ci sta intera e davanti c'è la
## corsia libera.
func _posti_per_porte(pianta: Dictionary, spazio: PhysicsDirectSpaceState3D) -> Array:
	var fuori := []
	var mezza := float(pianta["misura"]["larghezza"]) * 0.5
	for m in pianta["muri"]:
		if float(m.get("giro", 0)) != 0.0 or float(m["quota"]) != 0.0 or float(m["alto"]) < ALTA:
			continue
		var c := Vector2(float(m["centro"][0]), float(m["centro"][1]))
		var mis := Vector2(float(m["misura"][0]), float(m["misura"][1]))
		for faccia in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var lungo_x: bool = faccia.y != 0.0
			var lunghezza := mis.x if lungo_x else mis.y
			if lunghezza < LARGA + 1.0:
				continue
			var piano := c + Vector2(faccia.x * mis.x, faccia.y * mis.y) * 0.5
			var t := -lunghezza * 0.5 + LARGA * 0.5 + 0.5
			while t <= lunghezza * 0.5 - LARGA * 0.5 - 0.5:
				var p2 := piano + (Vector2(t, 0) if lungo_x else Vector2(0, t))
				var normale := Vector3(faccia.x, 0, faccia.y)
				var schiena := Vector3(p2.x, 0.0, p2.y)
				var bocca := schiena + normale * FONDA
				if absf(bocca.x) < mezza and absf(bocca.z) < mezza \
						and _ci_sta(spazio, schiena + normale * (FONDA * 0.5 + 0.05), normale, Vector3(LARGA + 0.4, ALTA, FONDA - 0.1)) \
						and _ci_sta(spazio, bocca + normale * (CORSIA * 0.5 + 0.1), normale, Vector3(LARGA, ALTA - 0.4, CORSIA)):
					fuori.append({"bocca": bocca, "normale": normale, "muro": String(m["nome"])})
				t += PASSO_MURO
	return fuori


## Una scatola libera da muri, centrata in `centro` e girata col davanti verso `normale`
## (`misura`: larghezza, altezza, profondità). Sta sollevata di 30 cm: i gradini bassi non
## contano.
func _ci_sta(spazio: PhysicsDirectSpaceState3D, centro: Vector3, normale: Vector3, misura: Vector3) -> bool:
	var scatola := BoxShape3D.new()
	scatola.size = misura
	var base := Basis.looking_at(-normale, Vector3.UP)
	var domanda := PhysicsShapeQueryParameters3D.new()
	domanda.shape = scatola
	domanda.collision_mask = Strati.SOLIDO
	domanda.transform = Transform3D(base, centro + Vector3(0, misura.y * 0.5 + 0.3, 0))
	return spazio.intersect_shape(domanda, 1).is_empty()


func _libero(spazio: PhysicsDirectSpaceState3D, piedi: Vector3, raggio: float) -> bool:
	var cilindro := CylinderShape3D.new()
	cilindro.radius = raggio
	cilindro.height = 2.5
	var domanda := PhysicsShapeQueryParameters3D.new()
	domanda.shape = cilindro
	domanda.collision_mask = Strati.SOLIDO
	domanda.transform = Transform3D(Basis.IDENTITY, piedi + Vector3(0, 1.55, 0))
	return spazio.intersect_shape(domanda, 1).is_empty()


func _passa_vicino(via: PackedVector3Array, punto: Vector3) -> bool:
	for i in range(1, via.size()):
		var vicino := Geometry3D.get_closest_point_to_segment(punto, via[i - 1], via[i])
		if vicino.distance_to(punto) < STRADA:
			return true
	return false


## Il pavimento: ogni zona ritagliata dalle rampe, a passo fisso, senza i punti dentro un muro.
func _pavimento(arena: Arena, pianta: Dictionary, spazio: PhysicsDirectSpaceState3D) -> Array[Vector3]:
	var punti: Array[Vector3] = []
	var sfera := SphereShape3D.new()
	sfera.radius = 0.45
	var domanda := PhysicsShapeQueryParameters3D.new()
	domanda.shape = sfera
	domanda.collision_mask = Strati.SOLIDO
	var zone: Array = pianta["zone"]
	for i in zone.size():
		var quota := float(zone[i]["quota"])
		for pezzo in arena.pezzi_della_zona(i):
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


func _zona(pianta: Dictionary, dove: Vector3) -> String:
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


func _piu_vicino(dove: Vector3, posti: Array[Vector3]) -> float:
	var minimo := INF
	for p in posti:
		minimo = minf(minimo, p.distance_to(dove))
	return minimo


func _lista(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


func _testo(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]
