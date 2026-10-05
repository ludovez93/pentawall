extends SceneTree

## Collaudo delle varianti dell'aspetto (tappa 10, blocchi C e D).
##
## Le varianti si provano dal telefono, una dopo l'altra, col pulsante del banco di
## prova: se una si rompe in silenzio — un gruppo rinominato, un pezzo che non nasce —
## il confronto si fa contro una variante a metà e nessuno se ne accorge. Qui si
## costruisce l'arena in ognuna e si guarda che ci sia quello che la distingue. La
## variante di oggi deve restare quella di prima.
##
## Per l'arena-giocattolo c'è in più il criterio del blocco D: **ogni modulo copre la sua
## scatola**. Quello che si vede e quello che ferma il dardo devono coincidere entro
## pochi centimetri, o un dardo si ferma nel vuoto davanti a un muro, o ci entra dentro.
## E **niente facce doppie** (`tools/facce_doppie.gd`): due facce nello stesso piano, di
## colori diversi, lampeggiano.
##
## Uso:  godot --headless --path . -s tools/prova_aspetto.gd

const FacceDoppie := preload("res://tools/facce_doppie.gd")

## Di quanto il pezzo che si vede può stare davanti alla scatola (cuscini, montanti e
## cappelli sporgono di `Giocattolo.SPORGE`) e dietro (niente: un dardo che si ferma
## nel vuoto si vede).
const DAVANTI := 0.06
const DIETRO := 0.01

var _errori := 0
var _prove := 0
## Il posto libero da cui parte un raggio: dieci centimetri tutt'intorno.
var _palla := _sfera(0.1)


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var di_prima := Aspetto.scelta()
	for variante in Aspetto.NOMI.size():
		Aspetto.scegli(variante)
		var arena: Node3D = load("res://scenes/arena.tscn").instantiate()
		root.add_child(arena)
		for i in 3:
			await process_frame
		for i in 2:
			await physics_frame
		_guarda(arena, variante)
		if variante == Aspetto.GIOCATTOLO:
			_copre_le_scatole(arena)
			_niente_facce_doppie(arena)
		arena.queue_free()
		await process_frame
	Aspetto.scegli(di_prima)
	print("\n%d prove, %d errori" % [_prove, _errori])
	quit(1 if _errori > 0 else 0)


func _guarda(arena: Node3D, variante: int) -> void:
	var nome := Aspetto.NOMI[variante]
	var soffitti := 0
	var lucernari := 0
	var serie := 0
	var cielo := false
	var nebbia := false
	var torri := 0
	var lampade := 0
	var giocattolo := {}
	for figlio in arena.get_children():
		if figlio.is_in_group(Arena.GRUPPO_SOFFITTI):
			soffitti += 1
		if figlio is MeshInstance3D and figlio.is_in_group(Arena.GRUPPO_LUCERNARI):
			lucernari += 1
		if figlio is MultiMeshInstance3D:
			serie += 1
		if figlio is WorldEnvironment:
			var ambiente := (figlio as WorldEnvironment).environment
			cielo = ambiente.background_mode == Environment.BG_SKY
			nebbia = ambiente.fog_enabled
		if figlio is OmniLight3D:
			lampade += 1
			if (figlio as OmniLight3D).omni_range >= 60.0:
				torri += 1
		if figlio.is_in_group(Giocattolo.GRUPPO):
			giocattolo[String(figlio.name)] = figlio
	if variante != Aspetto.GIOCATTOLO:
		_conta("%s: soffitti e lucernari si ritrovano per gruppo" % nome,
				soffitti >= 5 and lucernari >= 20, "%d soffitti, %d lucernari" % [soffitti, lucernari])
	var ombre := 0
	var giocatore: Node = arena.call("giocatore")
	for figlio in giocatore.get_children():
		if figlio is MeshInstance3D and (figlio as MeshInstance3D).mesh is QuadMesh:
			ombre += 1
	match variante:
		Aspetto.OGGI:
			_conta("OGGI è l'arena di prima: niente cielo, niente nebbia, niente pezzi in serie, niente ombra",
					not cielo and not nebbia and serie == 0 and ombre == 0 and giocattolo.is_empty(),
					"cielo %s, nebbia %s, %d in serie, %d ombre, %d pezzi giocattolo"
					% [cielo, nebbia, serie, ombre, giocattolo.size()])
		Aspetto.PALAZZETTO:
			_conta("PALAZZETTO: capriate e materassini (almeno sei serie), nebbia, ombra",
					serie >= 6 and nebbia and ombre == 1, "%d in serie, %d ombre" % [serie, ombre])
		Aspetto.ORA_BLU:
			_conta("ORA BLU: il cielo, quattro torri faro, nebbia, ombra",
					cielo and torri == 4 and nebbia and ombre == 1,
					"cielo %s, %d torri, %d ombre" % [cielo, torri, ombre])
		Aspetto.SALA_LASER:
			_conta("SALA LASER: condotti e strisce in serie, nebbia, ombra",
					serie >= 3 and nebbia and ombre == 1, "%d in serie, %d ombre" % [serie, ombre])
		Aspetto.GIOCATTOLO:
			_guarda_il_giocattolo(arena, giocattolo, soffitti, lucernari, cielo, lampade, ombre)


func _guarda_il_giocattolo(arena: Node3D, pezzi: Dictionary, soffitti: int, lucernari: int,
		cielo: bool, lampade: int, ombre: int) -> void:
	# A cielo aperto: niente soffitti né fasce, **nemmeno nella fisica** (un dardo non deve
	# fermarsi nel vuoto a otto metri), niente lucernari né lampade, il cielo.
	var tetto_fisico := 0
	var spazio := arena.get_world_3d().direct_space_state
	for dove in [Vector3(-24, 8.3, -24), Vector3(0, 12.3, 0), Vector3(24, 8.3, 0), Vector3(-24, 8.3, 0),
			Vector3(0, 12.3, 24), Vector3(-15, 10.0, 0)]:
		var domanda := PhysicsPointQueryParameters3D.new()
		domanda.position = dove
		domanda.collision_mask = Strati.TIRO
		tetto_fisico += spazio.intersect_point(domanda).size()
	_conta("GIOCATTOLO: niente tetto (soffitti, fasce, lucernari), nemmeno nella collisione",
			soffitti == 0 and lucernari == 0 and tetto_fisico == 0,
			"%d soffitti, %d lucernari, %d punti del tetto ancora solidi" % [soffitti, lucernari, tetto_fisico])
	_conta("GIOCATTOLO: il cielo e il sole, nessuna lampada", cielo and lampade == 0,
			"cielo %s, %d lampade" % [cielo, lampade])
	var muri := 0
	for nome in pezzi:
		if String(nome).begins_with("muri"):
			muri += 1
	var mancano: Array[String] = []
	for nome in ["decalcomanie", "rampe", "paraurti", "pance", "fuori_0", "fuori_1", "fuori_2",
			"fuori_3", "dardi_a_terra", "palloni", "cavi"]:
		if not pezzi.has(nome):
			mancano.append(nome)
	_conta("GIOCATTOLO: i muri in settori (almeno nove), e tutti gli altri pezzi",
			muri >= 9 and mancano.is_empty(), "%d settori di muri, mancano %s" % [muri, mancano])
	var quadri := 0
	if pezzi.has("decalcomanie"):
		quadri = (pezzi["decalcomanie"] as MeshInstance3D).mesh.surface_get_array_len(0) / 4
	_conta("GIOCATTOLO: le decalcomanie (almeno venti grafiche)", quadri >= 20, "%d grafiche" % quadri)
	var sponde := 0
	for figlio in arena.get_children():
		if figlio.is_in_group(Muratura.GRUPPO_SPONDE):
			sponde += 1
	var pianta: Dictionary = arena.call("pianta")
	_conta("GIOCATTOLO: le sponde ci sono tutte, compresa quella sopra la buca",
			sponde == (pianta["sponde"] as Array).size(),
			"%d sponde su %d" % [sponde, (pianta["sponde"] as Array).size()])
	_conta("GIOCATTOLO: l'ombra sotto i corpi", ombre == 1, "%d ombre" % ombre)


## **Ogni modulo copre la sua scatola.** Contro ogni muro della pianta si tirano raggi da
## un metro fuori, su ogni faccia, in tre punti lungo il muro e a due altezze; dove la
## fisica colpisce proprio quel muro, il pezzo che si vede deve cominciare fra `DIETRO`
## dietro e `DAVANTI` davanti. La controprova sposta un settore di trenta centimetri: lo
## stesso controllo deve accorgersene.
func _copre_le_scatole(arena: Node3D) -> void:
	var visibili := []
	for figlio in arena.get_children():
		if figlio is MeshInstance3D and figlio.is_in_group(Giocattolo.GRUPPO) \
				and String(figlio.name).begins_with("muri"):
			visibili.append([figlio, (figlio as MeshInstance3D).mesh.generate_triangle_mesh()])
	var esito := _confronta(arena, visibili)
	_conta("GIOCATTOLO: ogni modulo copre la sua scatola (vista e fisica entro -%d/+%d cm)"
			% [int(DIETRO * 100), int(DAVANTI * 100)],
			int(esito[0]) >= 200 and int(esito[1]) == 0,
			"%d raggi, %d fuori misura, peggiore %.3f m (%s)" % esito)
	print("         %d raggi, peggiore %.3f m" % [int(esito[0]), float(esito[2])])
	# La controprova: un settore spostato in diagonale di trenta centimetri.
	var spostato: MeshInstance3D = visibili[0][0]
	spostato.position += Vector3(0.3, 0.0, 0.3)
	var storto := _confronta(arena, visibili)
	spostato.position -= Vector3(0.3, 0.0, 0.3)
	_conta("GIOCATTOLO, controprova: un settore spostato di 30 cm non passa",
			int(storto[1]) > 0, "%d raggi, %d fuori misura" % [int(storto[0]), int(storto[1])])


## **Niente facce doppie.** Dal telefono, il 05/10/2026: *«le parti superiori di alcune
## forme lampeggiavano veloci»* — sulle cime dei moduli corpo, cappello e montanti
## finivano alla stessa quota. Si contano le coppie fra colori diversi con dentro un pezzo
## dell'arena-giocattolo, che si vedono (senza un solido subito davanti). La controprova
## mette un settore di muri accanto a una sua copia spostata di venti centimetri e tinta
## di rosso: le cime delle due stanno in pari, e il controllo deve accorgersene.
func _niente_facce_doppie(arena: Node3D) -> void:
	var esito: Dictionary = FacceDoppie.cerca(arena)
	_conta("GIOCATTOLO: niente facce doppie fra colori diversi (stesso piano, stesso verso, si coprono)",
			int(esito["da_correggere"]) == 0, "%d coppie" % int(esito["da_correggere"]))
	print("         %d triangoli, %d coppie fra pezzi dello stesso colore o dell'arena di prima"
			% [int(esito["triangoli"]), int(esito["coppie"]) - int(esito["da_correggere"])])
	var settore: MeshInstance3D = null
	for figlio in arena.get_children():
		if figlio is MeshInstance3D and String(figlio.name).begins_with("muri"):
			settore = figlio
			break
	var prova := Node3D.new()
	arena.add_child(prova)
	for spostamento in [Vector3.ZERO, Vector3(0.2, 0.0, 0.2)]:
		var copia := MeshInstance3D.new()
		copia.mesh = settore.mesh
		copia.material_override = settore.material_override
		copia.position = settore.position + spostamento
		copia.add_to_group(Giocattolo.GRUPPO)
		prova.add_child(copia)
	var rosso := StandardMaterial3D.new()
	rosso.albedo_color = Color(1.0, 0.0, 0.0)
	rosso.vertex_color_use_as_albedo = true
	(prova.get_child(1) as MeshInstance3D).material_override = rosso
	var storto: Dictionary = FacceDoppie.cerca(prova)
	_conta("GIOCATTOLO, controprova: un settore e la sua copia spostata di 20 cm non passano",
			int(storto["da_correggere"]) > 0, "%d coppie" % int(storto["da_correggere"]))
	arena.remove_child(prova)
	prova.queue_free()


func _confronta(arena: Node3D, visibili: Array) -> Array:
	var spazio := arena.get_world_3d().direct_space_state
	var muri: Array = (arena.call("pianta") as Dictionary)["muri"]
	var raggi := 0
	var storti := 0
	var peggiore := 0.0
	var dove_peggiore := ""
	for corpo in arena.get_children():
		if not (corpo is StaticBody3D and corpo.is_in_group(Arena.GRUPPO_PARETI)):
			continue
		var m: Dictionary = muri[int(corpo.get_meta(&"muro"))]
		var misura := Vector3(float(m["misura"][0]), float(m["alto"]), float(m["misura"][1]))
		var quota := float(m["quota"])
		var facce: Array = []
		if Arena._e_tondo(String(m.get("nome", ""))) and absf(misura.x - misura.z) < 0.01:
			for a in [0.0, PI * 0.5, PI, PI * 1.5]:
				facce.append([Vector3(cos(a), 0.0, sin(a)), Vector3.ZERO, misura.x * 0.5])
		else:
			facce.append([Vector3.RIGHT, Vector3.BACK * misura.z, misura.x * 0.5])
			facce.append([Vector3.LEFT, Vector3.BACK * misura.z, misura.x * 0.5])
			facce.append([Vector3.BACK, Vector3.RIGHT * misura.x, misura.z * 0.5])
			facce.append([Vector3.FORWARD, Vector3.RIGHT * misura.x, misura.z * 0.5])
		for faccia in facce:
			for t in [-0.3, 0.0, 0.3]:
				for altezza in [minf(1.2, misura.y * 0.5), misura.y * 0.5]:
					var locale: Vector3 = faccia[0] * faccia[2] + faccia[1] * t \
							+ Vector3.UP * (altezza - misura.y * 0.5)
					var su_muro: Vector3 = (corpo as Node3D).transform * locale
					var fuori: Vector3 = ((corpo as Node3D).transform.basis * faccia[0]).normalized()
					var da := su_muro + fuori * 1.0
					var a := su_muro - fuori * 0.3
					# Chi parte dentro un altro muro, o a filo, non dice niente su questo: a
					# filo del perimetro il raggio partiva dentro il cuscino del perimetro, che
					# sporge di quattro centimetri come deve (05/10/2026).
					var intorno := PhysicsShapeQueryParameters3D.new()
					intorno.shape = _palla
					intorno.transform = Transform3D(Basis(), da)
					intorno.collision_mask = Strati.TIRO
					if not spazio.intersect_shape(intorno, 1).is_empty():
						continue
					var colpo := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(da, a, Strati.TIRO))
					if colpo.is_empty() or colpo["collider"] != corpo:
						continue
					var fisica := da.distance_to(colpo["position"])
					var vista := INF
					for v in visibili:
						var pezzo: MeshInstance3D = v[0]
						var dentro := pezzo.global_transform.affine_inverse()
						var tocco: Dictionary = (v[1] as TriangleMesh).intersect_segment(dentro * da,
								dentro * (da + (a - da) * 3.0))
						if not tocco.is_empty():
							vista = minf(vista, da.distance_to(pezzo.global_transform * (tocco["position"] as Vector3)))
					raggi += 1
					var scarto := fisica - vista
					if scarto < -DIETRO or scarto > DAVANTI:
						storti += 1
					if absf(scarto) > peggiore:
						peggiore = absf(scarto)
						dove_peggiore = "%s, quota %.1f" % [String(m.get("nome", "")), su_muro.y]
	return [raggi, storti, peggiore, dove_peggiore]


func _conta(cosa: String, esito: bool, dettaglio := "") -> void:
	_prove += 1
	if esito:
		print("  ok   ", cosa)
	else:
		_errori += 1
		print("  NO   ", cosa, ("   (%s)" % dettaglio) if dettaglio != "" else "")


static func _sfera(raggio: float) -> SphereShape3D:
	var palla := SphereShape3D.new()
	palla.radius = raggio
	return palla
