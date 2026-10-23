extends SceneTree

## **Dove mettere le sette bandiere della GARA** (tappa 11, blocco D1): misurato sulla rete di
## cammino, non a occhio, come le sfere e i bersagli bonus.
##
## Il percorso per zone è una scelta mia del 13/10/2026 (`PLAN.md`, tappa 11, blocco D): passa
## per tutte le quote e per le quattro ali. Partenza in griglia nell'ala ocra, poi tribuna,
## terrazza sud-ovest, ballatoio, terrazza sud-est, ala mattone, terrazza nord-est o passerella,
## e la bandiera d'oro nel catino. Dal 1999 vengono le sette bandiere in ordine e la partenza
## raggruppata (le sei mappe di gara: partenze entro 12-28 m, quasi alla stessa distanza dalla
## prima bandiera).
##
## Dentro ogni zona l'attrezzo prova tutti i punti del pavimento ogni `PASSO` metri con almeno
## `LIBERO` metri liberi intorno (muri all'altezza del corpo, orli, rampe: lì si rinasce, e
## possono arrivarci in sei), lontani dalle partenze e dalle sfere che restano in gara, e
## sulla rete di cammino. Fra tutte le combinazioni sceglie quella coi tratti più vicini a
## `TRATTO` metri **di cammino**, preferendo i posti più larghi.
##
## Poi rifà i conti nelle altre varianti dell'aspetto (la loro rete, i loro oggetti in campo):
## lunghezze dei tratti e posto libero intorno a ogni bandiera.
##
## Scrive `user://bandiere.json` (posti, tratti e strade, per l'immagine).
## Uso:  godot --headless --path . -s tools/misura_bandiere.gd

const PERCORSO := [
	{"nome": "partenza", "zone": ["ala ocra"]},
	{"nome": "1", "zone": ["ala tribuna"]},
	{"nome": "2", "zone": ["terrazza sud-ovest"]},
	{"nome": "3", "zone": ["ballatoio"]},
	{"nome": "4", "zone": ["terrazza sud-est"]},
	{"nome": "5", "zone": ["ala mattone"]},
	{"nome": "6", "zone": ["terrazza nord-est", "passerella nord"]},
	{"nome": "7", "zone": ["catino"]},
]
const PASSO := 1.0
## Il pavimento libero intorno a una bandiera, e intorno al centro della griglia di partenza
## (sei posti in due file da tre: `PASSO_GRIGLIA`).
const LIBERO := 2.5
const LIBERO_GRIGLIA := 3.0
## Nelle varianti, nessun oggetto solido entro tanto da una bandiera.
const INGOMBRO := 2.0
## La griglia è quella del gioco (`Bandiere.griglia_di_partenza`, a `Bandiere.PASSO_GRIGLIA`):
## a due metri i sei posti stanno tutti dentro i tre metri liberi intorno al centro (il più
## lontano a 2,24, più il corpo); a due metri e mezzo uno toccava un cassone.
## Il raggio del corpo (0,42) con un margine: un posto della griglia è libero se qui dentro
## non c'è niente di solido.
const CORPO_IN_GRIGLIA := 0.7
const DA_PARTENZE := 5.0
const DA_SFERE := 5.0
## In gara restano TURBO, FULMINE, FANTASMA e RADAR (`PLAN.md`, blocco D1).
const SFERE_IN_GARA := ["turbo", "fulmine", "fantasma", "radar"]
const TRATTO := 40.0
## Quanto pesa un posto stretto: un metro di spazio in meno vale come tre metri di tratto
## fuori misura, fino a cinque metri di spazio.
const PESO_SPAZIO := 9.0
const SPAZIO_PIENO := 5.0
const SCELTA := Aspetto.GIOCATTOLO
const VERIFICHE := [Aspetto.OGGI, Aspetto.GONFIABILE, Aspetto.PISTA]


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var di_prima := Aspetto.scelta()
	var esito := {}
	var arena := await _apri(SCELTA)
	var mappa := arena.get_world_3d().navigation_map
	var pianta: Dictionary = arena.pianta()
	var tappe: Array = []
	for t in PERCORSO:
		tappe.append(_candidati(arena, pianta, mappa, t))
	# Via i posti che un oggetto di qualche variante ingombra, o che la sua rete non tocca:
	# la scelta dell'aspetto è ancora aperta, e le bandiere devono stare bene in tutte.
	_scarta(arena, tappe)
	arena.queue_free()
	await process_frame
	for v in VERIFICHE:
		var altra := await _apri(v)
		_scarta(altra, tappe)
		altra.queue_free()
		await process_frame
	for t in PERCORSO.size():
		print("%-9s %s: %d posti possibili" % [PERCORSO[t]["nome"], ", ".join(PERCORSO[t]["zone"]),
				tappe[t].size()])
	arena = await _apri(SCELTA)
	mappa = arena.get_world_3d().navigation_map
	var inizio := Time.get_ticks_msec()
	var scelti := _scegli(tappe, mappa)
	print("strade misurate in %d ms" % (Time.get_ticks_msec() - inizio))
	var posti: Array[Vector3] = []
	for s in scelti:
		posti.append(s["dove"])
	esito["scelta"] = Aspetto.NOMI[SCELTA]
	esito["posti"] = []
	for i in scelti.size():
		var s: Dictionary = scelti[i]
		esito["posti"].append({"nome": PERCORSO[i]["nome"], "zona": s["zona"],
				"dove": [snappedf(s["dove"].x, 0.01), snappedf(s["dove"].y, 0.01), snappedf(s["dove"].z, 0.01)],
				"spazio": snappedf(s["spazio"], 0.1)})
	esito["varianti"] = {}
	esito["varianti"][Aspetto.NOMI[SCELTA]] = _rapporto(arena, mappa, posti, true)
	arena.queue_free()
	await process_frame
	await process_frame
	for v in VERIFICHE:
		var altra := await _apri(v)
		esito["varianti"][Aspetto.NOMI[v]] = _rapporto(altra, altra.get_world_3d().navigation_map, posti, false)
		altra.queue_free()
		await process_frame
		await process_frame
	Aspetto.scegli(di_prima)
	var file := FileAccess.open("user://bandiere.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(esito, "  "))
	file.close()
	print("scritto %s" % ProjectSettings.globalize_path("user://bandiere.json"))
	quit()


func _apri(variante: int) -> Arena:
	Aspetto.scegli(variante)
	var arena: Arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	# Il primo fotogramma: prima la scena non è ancora dentro il mondo, e il mondo non c'è.
	await process_frame
	var mappa := arena.get_world_3d().navigation_map
	var scadenza := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < scadenza and NavigationServer3D.map_get_iteration_id(mappa) == 0:
		await physics_frame
	for i in 3:
		await process_frame
		await physics_frame
	return arena


## I punti di pavimento di una tappa, con lo spazio libero intorno e il punto della rete sotto.
func _candidati(arena: Arena, pianta: Dictionary, mappa: RID, tappa: Dictionary) -> Array:
	var libero := LIBERO_GRIGLIA if tappa["nome"] == "partenza" else LIBERO
	var muri: Array = []
	for m in pianta["muri"]:
		muri.append([Vector2(float(m["centro"][0]), float(m["centro"][1])),
				Vector2(float(m["misura"][0]), float(m["misura"][1])) * 0.5,
				deg_to_rad(float(m.get("giro", 0.0))), float(m["quota"]),
				float(m["quota"]) + float(m["alto"])])
	var rampe: Array = []
	for r in pianta["rampe"]:
		rampe.append([Vector2(float(r["da"][0]), float(r["da"][1])),
				Vector2(float(r["a"][0]), float(r["a"][1])), float(r["larghezza"]) * 0.5,
				minf(float(r["quota_da"]), float(r["quota_a"])),
				maxf(float(r["quota_da"]), float(r["quota_a"]))])
	var lontani: Array[Vector3] = []
	for p in pianta["partenze"]:
		lontani.append(Vector3(float(p["dove"][0]), float(p["quota"]), float(p["dove"][1])))
	var sfere: Array[Vector3] = []
	for s in arena.sfere_della_pianta():
		if String(s["tipo"]) in SFERE_IN_GARA:
			sfere.append(s["dove"])
	var fuori := []
	var zone: Array = pianta["zone"]
	for z in zone.size():
		if not String(zone[z]["nome"]) in tappa["zone"]:
			continue
		var quota := float(zone[z]["quota"])
		var muri_qui := muri.filter(func(m: Array) -> bool:
				return m[3] < quota + Giocatore.ALTEZZA_CORPO + 0.2 and m[4] > quota + 0.05)
		var rampe_qui := rampe.filter(func(r: Array) -> bool:
				return r[4] > quota - 0.5 and r[3] < quota + Giocatore.ALTEZZA_CORPO + 0.5)
		for pezzo: PackedVector2Array in arena.pezzi_della_zona(z):
			var minimo := pezzo[0]
			var massimo := pezzo[0]
			for p in pezzo:
				minimo = minimo.min(p)
				massimo = massimo.max(p)
			var x := snappedf(minimo.x, PASSO) + PASSO * 0.5
			while x < massimo.x:
				var y := snappedf(minimo.y, PASSO) + PASSO * 0.5
				while y < massimo.y:
					var punto := Vector2(x, y)
					var spazio := _spazio(punto, pezzo, muri_qui, rampe_qui)
					var dove := Vector3(x, quota, y)
					if spazio >= libero and _lontano(dove, lontani, DA_PARTENZE) \
							and _lontano(dove, sfere, DA_SFERE):
						var su := NavigationServer3D.map_get_closest_point(mappa, dove)
						if Vector2(su.x - x, su.z - y).length() < 0.3 and absf(su.y - quota) < 0.8:
							fuori.append({"dove": dove, "rete": su, "spazio": spazio,
									"zona": String(zone[z]["nome"])})
					y += PASSO
				x += PASSO
	return fuori


## Lo spazio libero intorno a un punto del pavimento: fino all'orlo, al muro più vicino
## all'altezza del corpo, all'orlo di una rampa. La stessa geometria con cui l'arena sceglie
## i posti di rinascita (`Arena._buon_posto_per_rinascere`), letta come una distanza.
func _spazio(punto: Vector2, pezzo: PackedVector2Array, muri: Array, rampe: Array) -> float:
	if not Geometry2D.is_point_in_polygon(punto, pezzo):
		return -1.0
	var quanto := INF
	for i in pezzo.size():
		var orlo := Geometry2D.get_closest_point_to_segment(punto, pezzo[i], pezzo[(i + 1) % pezzo.size()])
		quanto = minf(quanto, punto.distance_to(orlo))
	for m: Array in muri:
		var locale: Vector2 = (punto - (m[0] as Vector2)).rotated(m[2])
		quanto = minf(quanto, (locale.abs() - (m[1] as Vector2)).max(Vector2.ZERO).length())
	for r: Array in rampe:
		var asse := Geometry2D.get_closest_point_to_segment(punto, r[0], r[1])
		quanto = minf(quanto, punto.distance_to(asse) - float(r[2]))
	return quanto


## Toglie da ogni tappa i posti che in questa variante hanno qualcosa nel raggio libero
## (all'altezza del corpo) o che la sua rete di cammino non tocca.
func _scarta(arena: Arena, tappe: Array) -> void:
	var mappa := arena.get_world_3d().navigation_map
	for t in tappe.size():
		var raggio := LIBERO_GRIGLIA if PERCORSO[t]["nome"] == "partenza" else INGOMBRO
		tappe[t] = tappe[t].filter(func(c: Dictionary) -> bool:
			var dove: Vector3 = c["dove"]
			var su := NavigationServer3D.map_get_closest_point(mappa, dove)
			if Vector2(su.x - dove.x, su.z - dove.z).length() >= 0.3 or absf(su.y - dove.y) >= 0.8:
				return false
			return _ingombri(arena, dove, raggio) == 0)


## Quante cose solide stanno in un cilindro intorno al posto, dai trenta centimetri sopra il
## pavimento fino sopra la testa: muri, cassoni, gli oggetti in campo delle varianti.
func _ingombri(arena: Arena, dove: Vector3, raggio: float) -> int:
	var forma := CylinderShape3D.new()
	forma.radius = raggio
	forma.height = 1.6
	var domanda := PhysicsShapeQueryParameters3D.new()
	domanda.shape = forma
	domanda.collision_mask = Strati.SOLIDO
	domanda.transform = Transform3D(Basis.IDENTITY, dove + Vector3(0, 1.1, 0))
	return arena.get_world_3d().direct_space_state.intersect_shape(domanda, 4).size()


func _lontano(dove: Vector3, da: Array[Vector3], quanto: float) -> bool:
	for p in da:
		if dove.distance_to(p) < quanto:
			return false
	return true


func _lunghezza(mappa: RID, da: Vector3, a: Vector3) -> float:
	var via := NavigationServer3D.map_get_path(mappa, da, a, true)
	if via.is_empty() or via[via.size() - 1].distance_to(a) > 1.0:
		return INF
	var quanto := 0.0
	for i in range(1, via.size()):
		quanto += via[i - 1].distance_to(via[i])
	return quanto


func _costo_posto(c: Dictionary) -> float:
	return PESO_SPAZIO * (SPAZIO_PIENO - minf(float(c["spazio"]), SPAZIO_PIENO))


## La combinazione migliore, tappa dopo tappa (si tiene, per ogni posto, la strada più
## economica che ci arriva): il costo è lo scarto dei tratti da `TRATTO`, al quadrato, più
## quello dei posti stretti.
func _scegli(tappe: Array, mappa: RID) -> Array:
	var costi: Array = []
	var da_dove: Array = []
	var primi := []
	for c in tappe[0]:
		primi.append(0.0)
	costi.append(primi)
	da_dove.append([])
	for t in range(1, tappe.size()):
		var qui := []
		var indietro := []
		# I posti di prima dal più economico: così la potatura qui sotto taglia presto.
		var ordine := range(tappe[t - 1].size())
		ordine.sort_custom(func(x: int, y: int) -> bool: return float(costi[t - 1][x]) < float(costi[t - 1][y]))
		var strade := 0
		for b in tappe[t]:
			var migliore := INF
			var chi := -1
			for i: int in ordine:
				var a: Dictionary = tappe[t - 1][i]
				if float(costi[t - 1][i]) >= migliore:
					break
				# Una strada non è mai più corta della linea d'aria: se già questa costa
				# troppo, non serve chiedere la strada alla rete.
				var aria := (a["rete"] as Vector3).distance_to(b["rete"])
				if float(costi[t - 1][i]) + pow(maxf(aria - TRATTO, 0.0), 2.0) >= migliore:
					continue
				strade += 1
				var lungo := _lunghezza(mappa, a["rete"], b["rete"])
				if lungo == INF:
					continue
				var costo := float(costi[t - 1][i]) + pow(lungo - TRATTO, 2.0)
				if costo < migliore:
					migliore = costo
					chi = i
			qui.append(migliore + _costo_posto(b))
			indietro.append(chi)
		costi.append(qui)
		da_dove.append(indietro)
		print("   tappa %s: %d strade chieste alla rete" % [PERCORSO[t]["nome"], strade])
	var ultimo := 0
	for j in costi[costi.size() - 1].size():
		if float(costi[costi.size() - 1][j]) < float(costi[costi.size() - 1][ultimo]):
			ultimo = j
	var scelti := []
	var j := ultimo
	for t in range(tappe.size() - 1, -1, -1):
		scelti.push_front(tappe[t][j])
		if t > 0:
			j = int(da_dove[t][j])
	return scelti


## Tratti di cammino e posto libero intorno a ogni bandiera, nella variante aperta.
func _rapporto(arena: Arena, mappa: RID, posti: Array[Vector3], con_strade: bool) -> Dictionary:
	var tratti := []
	var ingombri := []
	var strade := []
	var totale := 0.0
	for i in posti.size():
		ingombri.append(_ingombri(arena, posti[i], LIBERO_GRIGLIA if i == 0 else INGOMBRO))
		if i == 0:
			continue
		var da := NavigationServer3D.map_get_closest_point(mappa, posti[i - 1])
		var a := NavigationServer3D.map_get_closest_point(mappa, posti[i])
		var lungo := _lunghezza(mappa, da, a)
		tratti.append(snappedf(lungo, 0.1))
		totale += lungo
		if con_strade:
			var via := NavigationServer3D.map_get_path(mappa, da, a, true)
			var punti := []
			for p in via:
				punti.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)])
			strade.append(punti)
	# I sei posti della griglia, uno per uno: un corpo con un dito di margine.
	var griglia := []
	var stretti := []
	var verso := NavigationServer3D.map_get_closest_point(mappa, posti[1])
	for p in Bandiere.griglia_di_partenza(posti[0], verso):
		griglia.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)])
		stretti.append(_ingombri(arena, p, CORPO_IN_GRIGLIA))
	var nome := Aspetto.NOMI[Aspetto.scelta()]
	print("%-10s tratti %s  totale %.0f m, %.0f s di corsa a %.2f m/s; ingombri nel raggio libero: %s; nella griglia: %s" % [
		nome, " ".join(tratti.map(func(t: float) -> String: return "%.0f" % t)), totale,
		totale / Giocatore.VELOCITA, Giocatore.VELOCITA, str(ingombri), str(stretti)])
	var fuori := {"tratti": tratti, "totale": snappedf(totale, 0.1), "ingombri": ingombri,
			"griglia": griglia, "ingombri_griglia": stretti}
	if con_strade:
		fuori["strade"] = strade
	return fuori
