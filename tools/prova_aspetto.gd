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
		if variante == Aspetto.GONFIABILE:
			_copre_le_scatole(arena, "GONFIABILE")
			_niente_facce_doppie(arena, "GONFIABILE")
		if variante == Aspetto.PISTA:
			# Le gomme sono tonde su una scatola: fra due gomme la gomma sta fino a mezzo
			# metro dietro la faccia del muro. Il resto della pista copre come i moduli.
			_copre_le_scatole(arena, "PISTA", 0.5)
			_niente_facce_doppie(arena, "PISTA")
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
	if variante != Aspetto.GIOCATTOLO and variante != Aspetto.GONFIABILE and variante != Aspetto.PISTA:
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
			_conta("GIOCATTOLO, controprova dell'arena aperta: a 6 metri il perimetro c'è ancora",
					_solido_in(arena, Vector3(0.0, 6.0, -40.4)), "")
		Aspetto.GONFIABILE:
			_guarda_l_arena_aperta(arena, nome, giocattolo, soffitti, lucernari, cielo, lampade,
					["terreno_e_pali", "vasca_di_palline", "oggetti_gonfiabili", "rampe", "fuori_0"])
		Aspetto.PISTA:
			_guarda_l_arena_aperta(arena, nome, giocattolo, soffitti, lucernari, cielo, lampade,
					["terreno_e_pali", "muri_della_pista", "muri_di_gomme", "tribune",
					"oggetti_della_pista", "rampe", "fuori_0"])


func _guarda_il_giocattolo(arena: Node3D, pezzi: Dictionary, soffitti: int, lucernari: int,
		cielo: bool, lampade: int, ombre: int) -> void:
	# A cielo aperto: niente soffitti né fasce, **nemmeno nella fisica** (un dardo non deve
	# fermarsi nel vuoto a otto metri), niente lucernari né lampade, il cielo.
	var tetto_fisico := 0
	var spazio := arena.get_world_3d().direct_space_state
	for dove in [Vector3(-29.1, 8.3, -29.1), Vector3(0, 12.3, 0), Vector3(29.1, 8.3, 0),
			Vector3(-29.1, 8.3, 0), Vector3(0, 12.3, 29.1), Vector3(-18.2, 10.0, 0)]:
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


## **Le prove dell'arena aperta** (tappa 11, blocco C2): niente tetto e il cielo, il
## perimetro a 4 metri, i pezzi della direzione e gli oggetti in campo, le sponde tutte, i
## corpi a cartone, la rete di cammino sua. E **dai piani alti non si cade fuori**: lungo
## ogni orlo di terrazza, passerella o ballatoio che tocca il perimetro, un raggio a 60
## centimetri sopra il pavimento verso fuori trova il parapetto. La controprova tira gli
## stessi raggi a 1,4 metri, sopra il parapetto: lì l'arena è aperta, e devono passare.
func _guarda_l_arena_aperta(arena: Node3D, nome: String, pezzi: Dictionary, soffitti: int,
		lucernari: int, cielo: bool, lampade: int, voluti: Array) -> void:
	var tetto_fisico := 0
	for dove in [Vector3(-29.1, 8.3, -29.1), Vector3(0, 12.3, 0), Vector3(29.1, 8.3, 0)]:
		tetto_fisico += 1 if _solido_in(arena, dove) else 0
	_conta("%s: niente tetto, nemmeno nella collisione, il cielo e nessuna lampada" % nome,
			soffitti == 0 and lucernari == 0 and tetto_fisico == 0 and cielo and lampade == 0,
			"%d soffitti, %d lucernari, %d punti solidi, cielo %s, %d lampade"
			% [soffitti, lucernari, tetto_fisico, cielo, lampade])
	_conta("%s: il perimetro è a 4 metri (a 3,5 c'è, a 6 no)" % nome,
			_solido_in(arena, Vector3(0.0, 3.5, -40.4)) and not _solido_in(arena, Vector3(0.0, 6.0, -40.4)), "")
	var mancano: Array[String] = []
	for voluto in voluti:
		if not pezzi.has(voluto):
			mancano.append(voluto)
	var oggetti := 0
	for figlio in arena.get_children():
		if figlio.is_in_group(Apertura.GRUPPO_OGGETTI):
			oggetti += 1
	# Venticinque e non più trenta: dal 23/10/2026 gli oggetti che ingombravano porte e
	# cannoni della PALLA si saltano (PISTA da 33 a 27, GONFIABILE da 42 a 32).
	_conta("%s: i pezzi della direzione, e almeno venticinque oggetti in campo" % nome,
			mancano.is_empty() and oggetti >= 25, "mancano %s, %d oggetti" % [mancano, oggetti])
	print("         %d oggetti in campo" % oggetti)
	var sponde := 0
	for figlio in arena.get_children():
		if figlio.is_in_group(Muratura.GRUPPO_SPONDE):
			sponde += 1
	var pianta: Dictionary = arena.call("pianta")
	_conta("%s: le sponde ci sono tutte" % nome, sponde == (pianta["sponde"] as Array).size(),
			"%d sponde su %d" % [sponde, (pianta["sponde"] as Array).size()])
	var corpo: Corpo = (arena.call("giocatore") as Giocatore).corpo()
	_conta("%s: i corpi sono a cartone" % nome, bool(corpo.get("_cartone")), "")
	_conta("%s: la rete di cammino è la sua" % nome,
			ResourceLoader.exists(Aspetto.rete(Arena.RETE)) and Aspetto.rete(Arena.RETE) != Arena.RETE,
			Aspetto.rete(Arena.RETE))
	var bassi := _raggi_dal_bordo(arena, pianta, 0.6)
	_conta("%s: dai piani alti non si cade fuori (raggi a 60 cm verso il perimetro)" % nome,
			int(bassi[0]) >= 40 and int(bassi[1]) == 0, "%d raggi, %d passano" % bassi)
	var alti := _raggi_dal_bordo(arena, pianta, 1.4)
	_conta("%s, controprova: sopra il parapetto l'arena è aperta (raggi a 1,4 m)" % nome,
			int(alti[1]) > int(alti[0]) / 2, "%d raggi, %d passano" % alti)


## Raggi ogni mezzo metro lungo gli orli dei piani alti che stanno sul perimetro, da
## mezzo metro dentro a un metro e mezzo fuori, `sopra` il pavimento. `[raggi, passano]`.
func _raggi_dal_bordo(arena: Node3D, pianta: Dictionary, sopra: float) -> Array:
	var spazio := arena.get_world_3d().direct_space_state
	var bordo := float(pianta["misura"]["larghezza"]) * 0.5
	var raggi := 0
	var passano := 0
	for zona: Dictionary in pianta["zone"]:
		var quota := float(zona["quota"])
		if quota <= 0.5:
			continue
		var punti: Array = zona["poligono"]
		for i in punti.size():
			var da := Vector2(float(punti[i][0]), float(punti[i][1]))
			var a := Vector2(float(punti[(i + 1) % punti.size()][0]), float(punti[(i + 1) % punti.size()][1]))
			for asse in 2:
				if absf(da[asse]) < bordo - 0.5 or absf(da[asse] - a[asse]) > 0.01:
					continue
				var fuori := Vector3.ZERO
				fuori[0 if asse == 0 else 2] = signf(da[asse])
				var passi := int(floor(da.distance_to(a) / 0.5))
				for k in range(1, passi):
					var p := da.lerp(a, float(k) / float(passi))
					var dentro := Vector3(p.x, quota + sopra, p.y) - fuori * 0.5
					var colpo := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(dentro,
							dentro + fuori * 2.0, Strati.SOLIDO))
					raggi += 1
					if colpo.is_empty():
						passano += 1
	return [raggi, passano]


func _solido_in(arena: Node3D, dove: Vector3) -> bool:
	var domanda := PhysicsPointQueryParameters3D.new()
	domanda.position = dove
	domanda.collision_mask = Strati.TIRO
	return not arena.get_world_3d().direct_space_state.intersect_point(domanda).is_empty()


## **Ogni modulo copre la sua scatola.** Contro ogni muro della pianta si tirano raggi da
## un metro fuori, su ogni faccia, in tre punti lungo il muro e a due altezze; dove la
## fisica colpisce proprio quel muro, il pezzo che si vede deve cominciare fra `DIETRO`
## dietro e `DAVANTI` davanti. La controprova sposta un settore di trenta centimetri: lo
## stesso controllo deve accorgersene.
func _copre_le_scatole(arena: Node3D, nome := "GIOCATTOLO", dietro := DIETRO) -> void:
	var visibili := []
	for figlio in arena.get_children():
		if figlio is MeshInstance3D and figlio.is_in_group(Giocattolo.GRUPPO) \
				and String(figlio.name).begins_with("muri"):
			visibili.append([figlio, (figlio as MeshInstance3D).mesh.generate_triangle_mesh()])
	var esito := _confronta(arena, visibili, dietro)
	_conta("%s: ogni modulo copre la sua scatola (vista e fisica entro -%d/+%d cm)"
			% [nome, int(dietro * 100), int(DAVANTI * 100)],
			int(esito[0]) >= 200 and int(esito[1]) == 0,
			"%d raggi, %d fuori misura, peggiore %.3f m (%s)" % esito)
	print("         %d raggi, peggiore %.3f m" % [int(esito[0]), float(esito[2])])
	# La controprova: un settore spostato in diagonale di trenta centimetri.
	var spostato: MeshInstance3D = visibili[0][0]
	spostato.position += Vector3(0.3, 0.0, 0.3)
	var storto := _confronta(arena, visibili, minf(dietro, 0.25))
	spostato.position -= Vector3(0.3, 0.0, 0.3)
	_conta("%s, controprova: un settore spostato di 30 cm non passa" % nome,
			int(storto[1]) > 0, "%d raggi, %d fuori misura" % [int(storto[0]), int(storto[1])])


## **Niente facce doppie.** Dal telefono, il 05/10/2026: *«le parti superiori di alcune
## forme lampeggiavano veloci»* — sulle cime dei moduli corpo, cappello e montanti
## finivano alla stessa quota. Si contano le coppie fra colori diversi con dentro un pezzo
## dell'arena-giocattolo, che si vedono (senza un solido subito davanti). La controprova
## mette un settore di muri accanto a una sua copia spostata di venti centimetri e tinta
## di rosso: le cime delle due stanno in pari, e il controllo deve accorgersene.
func _niente_facce_doppie(arena: Node3D, nome := "GIOCATTOLO") -> void:
	var esito: Dictionary = FacceDoppie.cerca(arena)
	_conta("%s: niente facce doppie fra colori diversi (stesso piano, stesso verso, si coprono)" % nome,
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
	_conta("%s, controprova: un settore e la sua copia spostata di 20 cm non passano" % nome,
			int(storto["da_correggere"]) > 0, "%d coppie" % int(storto["da_correggere"]))
	arena.remove_child(prova)
	prova.queue_free()


func _confronta(arena: Node3D, visibili: Array, dietro := DIETRO) -> Array:
	var spazio := arena.get_world_3d().direct_space_state
	var muri: Array = (arena.call("pianta") as Dictionary)["muri"]
	var raggi := 0
	var storti := 0
	var peggiore := 0.0
	var dove_peggiore := ""
	var dove_storti := {}
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
					if scarto < -dietro or scarto > DAVANTI:
						storti += 1
						dove_storti[String(m.get("nome", ""))] = true
					if absf(scarto) > peggiore:
						peggiore = absf(scarto)
						dove_peggiore = "%s, quota %.1f" % [String(m.get("nome", "")), su_muro.y]
	if dove_storti.size() > 0:
		dove_peggiore += "; fuori misura su: " + ", ".join(PackedStringArray(dove_storti.keys()))
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
