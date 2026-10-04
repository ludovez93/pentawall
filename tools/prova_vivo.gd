extends SceneTree

## Collaudo della **tappa 8: il gioco vivo** — corpi veri, forme, suoni,
## particelle, palle colorate.
##
## Le cose di questa tappa si giudicano guardandole e ascoltandole, e quello lo fa
## chi gioca. Qui si controlla quello che una persona non può vedere a occhio e che,
## rompendosi, rovinerebbe tutto in silenzio:
## - che ogni concorrente abbia il suo corpo, con l'albero delle animazioni acceso e
##   il blaster che punta dove guarda;
## - che la corsa usi davvero le animazioni giuste (avanti, indietro, di lato col
##   busto sulla mira);
## - che **i pavimenti si vedano dall'alto e da sotto**: fino al 03/10/2026 erano
##   invisibili dall'alto, e appena raddrizzati lo sono diventati da sotto — e
##   nessun collaudo poteva accorgersene;
## - che le scatole smussate guardino tutte fuori;
## - che sopra ogni punto dell'arena ci sia **un solo pavimento** (dal 04/10/2026: due
##   nello stesso piano lampeggiano) e che **la camera non esca dall'arena** quando ci
##   si addossa ai muri (dal 04/10/2026: la spalla finiva dentro il muro);
## - che i suoni si carichino e la musica cambi;
## - che un colpo faccia schizzare le particelle;
## - che le palle colorate si prendano, facciano quello che dicono e ricompaiano.
##
## Uso:  godot --headless --path . -s tools/prova_vivo.gd

var _errori := 0
var _prove := 0


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	await _i_corpi()
	_le_forme()
	await _l_arena()
	await _la_resa()
	print("\nVIVO: %d prove, %s" % [_prove, "tutte passate." if _errori == 0 else "%d ERRORI." % _errori])
	quit(1 if _errori > 0 else 0)


# ------------------------------------------------------------------ i corpi

func _i_corpi() -> void:
	var palco := Node3D.new()
	root.add_child(palco)
	for chi in Corpo.PERSONAGGI:
		var corpo := Corpo.crea(String(chi))
		palco.add_child(corpo)
		var albero := corpo.get("_albero") as AnimationTree
		_conta("%s ha il suo corpo e l'albero delle animazioni acceso" % chi,
				albero != null and albero.active and corpo.get("_scheletro") != null)
		var blaster := corpo.get("_blaster") as Node3D
		# Qualche fotogramma: la mano prende la posa di mira quando l'albero delle
		# animazioni ha girato almeno una volta.
		for i in 4:
			await process_frame
			corpo.aggiorna(Vector3.ZERO, true, 0.0, 1.0 / 60.0)
		var canna := (blaster.global_transform.basis.z).normalized()
		var avanti := -corpo.global_transform.basis.z
		_conta("%s: il blaster punta dove guarda il corpo" % chi, canna.dot(avanti) > 0.95,
				"allineamento %.2f" % canna.dot(avanti))
		corpo.queue_free()

	# La corsa: a piena velocità in avanti si mescola lo scatto e il passo accelera;
	# all'indietro il passo va al contrario; di lato le gambe girano e il busto no.
	var corpo := Corpo.crea("TU")
	palco.add_child(corpo)
	await process_frame
	for i in 30:
		corpo.aggiorna(corpo.global_transform.basis * Vector3(0, 0, -7.62), true, 0.0, 1.0 / 60.0)
	var albero := corpo.get("_albero") as AnimationTree
	_conta("in avanti a 7,62 m/s si corre allo scatto",
			is_equal_approx(float(albero.get("parameters/corsa/blend_position")), Corpo.VELOCITA_SCATTO))
	_conta("e il passo accelera per non pattinare",
			float(albero.get("parameters/passo/scale")) > 1.1,
			"%.2f" % float(albero.get("parameters/passo/scale")))
	for i in 30:
		corpo.aggiorna(corpo.global_transform.basis * Vector3(0, 0, 7.62), true, 0.0, 1.0 / 60.0)
	_conta("all'indietro il passo va al contrario",
			float(albero.get("parameters/passo/scale")) < -1.0,
			"%.2f" % float(albero.get("parameters/passo/scale")))
	for i in 60:
		corpo.aggiorna(corpo.global_transform.basis * Vector3(7.62, 0, 0), true, 0.0, 1.0 / 60.0)
	var gambe := float(corpo.get("_angolo_gambe"))
	var torsione := corpo.get("_torsione") as Torsione
	_conta("di lato le gambe girano verso la corsa", absf(rad_to_deg(gambe)) > 60.0,
			"%.0f°" % rad_to_deg(gambe))
	_conta("e il busto gira al contrario: resta sulla mira",
			is_equal_approx(torsione.angolo, -gambe), "%.2f contro %.2f" % [torsione.angolo, gambe])
	for i in 20:
		corpo.aggiorna(Vector3.ZERO, false, 0.0, 1.0 / 60.0)
	_conta("senza terra sotto i piedi si mescola il salto",
			float(albero.get("parameters/aria/blend_amount")) > 0.9)
	palco.queue_free()
	await process_frame


# ------------------------------------------------------------------ le forme

## **Il verso dei triangoli.** Godot disegna una faccia solo se i suoi vertici, visti
## da fuori, girano in senso orario: il prodotto dei lati punta **lontano** da chi
## guarda. Un pavimento al contrario dall'alto non si vede — ed è successo per un
## mese, dalla tappa 5 al 03/10/2026.
##
## **E da sotto.** Raddrizzata la faccia di sopra, lo stesso giorno i piani alti
## sono spariti visti da sotto: la faccia di sotto non c'era, e a fare da soffitto
## era stata fino ad allora quella di sopra girata al contrario. Per questo non
## basta il verso: ogni faccia deve **coprire tutto il contorno**, sopra e sotto.
func _le_forme() -> void:
	for prova in [
		{"nome": "rettangolo", "punti": [Vector2(-3, -2), Vector2(3, -2), Vector2(3, 2), Vector2(-3, 2)]},
		{"nome": "rettangolo al contrario", "punti": [Vector2(-3, 2), Vector2(3, 2), Vector2(3, -2), Vector2(-3, -2)]},
		{"nome": "a elle (concavo)", "punti": [Vector2(0, 0), Vector2(0, 4), Vector2(5, 4), Vector2(5, 2), Vector2(2, 2), Vector2(2, 0)]},
	]:
		var contorno := PackedVector2Array(prova["punti"])
		var mesh := Muratura._prisma(contorno, 0.0, -0.6)
		var dati := mesh.surface_get_arrays(0)
		var vertici: PackedVector3Array = dati[Mesh.ARRAY_VERTEX]
		var normali: PackedVector3Array = dati[Mesh.ARRAY_NORMAL]
		var sopra_ok := true
		var sotto_ok := true
		var fianchi_ok := true
		var piatte := true
		var area_sopra := 0.0
		var area_sotto := 0.0
		for t in range(0, vertici.size(), 3):
			var a := vertici[t]
			var b := vertici[t + 1]
			var c := vertici[t + 2]
			var croce := (b - a).cross(c - a)
			var orizzontale := absf(a.y - b.y) < 0.0001 and absf(a.y - c.y) < 0.0001
			if orizzontale:
				# Sopra si guarda dall'alto, sotto dal basso: chi guarda sta dalla
				# parte di `verso`, e il prodotto dei lati deve puntare lontano da lui.
				var sopra := a.y > -0.3
				var verso := Vector3.UP if sopra else Vector3.DOWN
				if croce.dot(verso) >= 0.0:
					if sopra:
						sopra_ok = false
					else:
						sotto_ok = false
				if sopra:
					area_sopra += croce.length() * 0.5
				else:
					area_sotto += croce.length() * 0.5
				# La luce di un piano è piatta: le normali dritte, non piegate verso
				# i fianchi.
				for k in 3:
					if normali[t + k].dot(verso) < 0.999:
						piatte = false
			else:
				# Un fianco: deve guardare fuori dal poligono.
				var meta := (a + b + c) / 3.0
				var fuori := Vector3(croce.x, 0.0, croce.z).normalized() * -1.0
				var passo := Vector2(meta.x + fuori.x * 0.02, meta.z + fuori.z * 0.02)
				if Geometry2D.is_point_in_polygon(passo, contorno):
					fianchi_ok = false
		var area := _area(contorno)
		_conta("pavimento %s: la faccia di sopra si vede dall'alto e lo copre tutto" % prova["nome"],
				sopra_ok and is_equal_approx(area_sopra, area), "%.2f m² su %.2f" % [area_sopra, area])
		_conta("pavimento %s: la faccia di sotto si vede da sotto e lo copre tutto" % prova["nome"],
				sotto_ok and is_equal_approx(area_sotto, area), "%.2f m² su %.2f" % [area_sotto, area])
		_conta("pavimento %s: i fianchi guardano fuori" % prova["nome"], fianchi_ok)
		_conta("pavimento %s: sopra e sotto la luce è piatta" % prova["nome"], piatte)

	var scatola := Muratura.scatola_smussata(Vector3(4.0, 2.2, 3.0), 0.3)
	var vertici: PackedVector3Array = scatola.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var dentro := 0
	for t in range(0, vertici.size(), 3):
		var croce := (vertici[t + 1] - vertici[t]).cross(vertici[t + 2] - vertici[t])
		var meta := (vertici[t] + vertici[t + 1] + vertici[t + 2]) / 3.0
		if croce.length_squared() > 0.0000001 and croce.dot(meta) > 0.0:
			dentro += 1
	_conta("la scatola smussata guarda tutta fuori", dentro == 0, "%d triangoli girati" % dentro)
	var scatola_aabb := scatola.get_aabb()
	_conta("e ha le misure della scatola che sostituisce",
			scatola_aabb.size.is_equal_approx(Vector3(4.0, 2.2, 3.0)), str(scatola_aabb.size))


# ------------------------------------------------------------------ l'arena

func _l_arena() -> void:
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	for i in 3:
		await process_frame

	# Le superfici: i pavimenti hanno parquet o moquette, non la grana di prova.
	var vestiti := 0
	var pavimenti := 0
	for corpo in arena.get_tree().get_nodes_in_group(Muratura.GRUPPO_PAVIMENTI):
		for figlio in corpo.get_children():
			if figlio is MeshInstance3D:
				pavimenti += 1
				var m := (figlio as MeshInstance3D).material_override as StandardMaterial3D
				if m != null and m.albedo_texture != null and m.albedo_texture != Muratura.grana():
					vestiti += 1
	_conta("tutti i pavimenti sono vestiti", pavimenti > 0 and vestiti == pavimenti,
			"%d su %d" % [vestiti, pavimenti])

	# La luce per vertice (04/10/2026): pavimenti e muri la calcolano sui vertici, i corpi
	# su ogni pixel. Sul telefono le lampade calcolate su ogni pixel valevano 26 ms su 48.
	var pezzi := 0
	var per_vertice := 0
	for gruppo in [Muratura.GRUPPO_PAVIMENTI, Muratura.GRUPPO_MURI]:
		for corpo in arena.get_tree().get_nodes_in_group(gruppo):
			for figlio in corpo.get_children():
				if not (figlio is MeshInstance3D):
					continue
				var m := (figlio as MeshInstance3D).material_override as BaseMaterial3D
				if m == null:
					continue
				pezzi += 1
				if m.shading_mode == BaseMaterial3D.SHADING_MODE_PER_VERTEX:
					per_vertice += 1
	_conta("pavimenti e muri calcolano la luce sui vertici", pezzi > 0 and per_vertice == pezzi,
			"%d su %d" % [per_vertice, pezzi])
	var del_corpo := 0
	for nodo in (arena.call("giocatore") as Giocatore).corpo().find_children("*", "MeshInstance3D", true, false):
		var m := (nodo as MeshInstance3D).material_override as BaseMaterial3D
		if m != null and m.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL:
			del_corpo += 1
	_conta("e il corpo del giocatore resta su ogni pixel (controprova)", del_corpo > 0,
			"%d pezzi" % del_corpo)
	_conta("un muro appena fatto nasce su ogni pixel: è l'arena a cambiarlo (controprova)",
			Muratura.opaco(Color.WHITE).shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL)

	# Le forme: colonne, piloni e pilastri sono tondi anche per i colpi.
	var tondi := 0
	for corpo in arena.get_tree().get_nodes_in_group(Muratura.GRUPPO_MURI):
		for figlio in corpo.get_children():
			if figlio is CollisionShape3D and (figlio as CollisionShape3D).shape is CylinderShape3D:
				tondi += 1
	_conta("colonne, piloni e pilastri sono tondi", tondi == 10, "%d tondi" % tondi)

	# Il pubblico: persone, sui loro gradini.
	_conta("il pubblico è gente, almeno cento persone", int(arena.call("quanto_pubblico")) >= 100,
			str(arena.call("quanto_pubblico")))

	_i_pavimenti(arena)
	await _la_camera(arena)

	# Le scritte ritagliate a soglia si vedono o non si vedono: una trasparenza sotto la
	# soglia le ritaglia tutte. Il nome dipinto nel catino, a 0,42, dalla tappa 8 non si
	# vedeva più, e nessuno se n'era accorto (04/10/2026).
	var ritagliate := 0
	var sparite := []
	for nodo in arena.find_children("*", "Label3D", true, false):
		var scritta := nodo as Label3D
		if scritta.alpha_cut != Label3D.ALPHA_CUT_DISCARD:
			continue
		ritagliate += 1
		if scritta.modulate.a < scritta.alpha_scissor_threshold:
			sparite.append(scritta.text)
	_conta("nessuna scritta ritagliata a soglia è più trasparente della soglia",
			ritagliate > 0 and sparite.is_empty(), "%d scritte, sparite: %s" % [ritagliate, sparite])

	# I suoni: tutti si caricano, e la musica della partita parte col fischio.
	var mancano := []
	for nome in Suoni.NOMI:
		if Suoni.attivo._flussi.get(nome) == null:
			mancano.append(nome)
	_conta("tutti i suoni si caricano", mancano.is_empty(), str(mancano))

	arena.call("avvia_sfida")
	_conta("col fischio parte la musica della partita", Suoni.brano() == "musica_partita", Suoni.brano())
	await _il_via(arena)

	var giocatore: Giocatore = arena.call("giocatore")
	var bots: Array = arena.call("avversari")
	_conta("i cinque avversari hanno ognuno il suo corpo", bots.size() == 5
			and bots.all(func(b: Avversario) -> bool: return b.get("_corpo") != null))
	var nomi := {}
	for b in bots:
		nomi[(b as Avversario).personaggio] = true
	_conta("e sono cinque persone diverse", nomi.size() == 5, str(nomi.keys()))
	await _i_corpi_costano_poco(giocatore, bots)

	# Il tabellone dice il tempo.
	await _aspetta(0.4)
	var tabellone := arena.get_node_or_null("tabellone")
	var riga: Label3D = null
	if tabellone != null:
		for lato in tabellone.get_children():
			if lato.get_node_or_null("riga_0") != null:
				riga = lato.get_node("riga_0") as Label3D
				break
	_conta("il tabellone sopra il catino dice il tempo",
			riga != null and riga.text == String(arena.call("tempo_scritto")),
			riga.text if riga != null else "manca")

	# **Le palle colorate.** Si va sopra a una e la si prende.
	# Gli avversari, intanto, fermi e sotto l'arena: una palla la prende chiunque ci
	# passi, e il 03/10/2026 nella lavorazione uno di loro ci arrivava prima del
	# giocatore — il collaudo falliva su un gioco sano, per due pubblicazioni di fila.
	for b in bots:
		(b as Node3D).process_mode = Node.PROCESS_MODE_DISABLED
		(b as Node3D).global_position = Vector3(0.0, -50.0, 0.0)
	var potenziamenti := arena.get_node("potenziamenti") as Potenziamenti
	# E le palle rimesse tutte in campo: nei secondi prima, qualcuno può averne presa una.
	potenziamenti.riparti()
	_conta("ci sono tre palle colorate, tutte disponibili", potenziamenti.quante_disponibili() == 3,
			str(potenziamenti.quante_disponibili()))
	potenziamenti.imposta_ricomparsa(0.6)
	var posti: Array = potenziamenti.posti()
	var turbo: Dictionary = posti.filter(func(p: Dictionary) -> bool: return p["tipo"] == "turbo")[0]
	var doppio: Dictionary = posti.filter(func(p: Dictionary) -> bool: return p["tipo"] == "doppio")[0]
	giocatore.global_position = (turbo["dove"] as Vector3) + Vector3(0, 0.3, 0)
	giocatore.velocity = Vector3.ZERO
	await _aspetta(0.25)
	_conta("passandoci sopra si prende il turbo", potenziamenti.ha(giocatore, "turbo"))
	_conta("e il turbo spinge", is_equal_approx(giocatore.spinta, Potenziamenti.SPINTA_TURBO),
			"%.2f" % giocatore.spinta)
	_conta("la palla presa sparisce", potenziamenti.quante_disponibili() == 2)
	# Ci si sposta, o appena ricompare la si riprende subito.
	giocatore.global_position = (turbo["dove"] as Vector3) + Vector3(4.0, 0.3, 0.0)
	await _aspetta(0.9)
	var turbo_c_e := false
	for p in Potenziamenti.disponibili:
		if p.distance_to(turbo["dove"]) < 0.1:
			turbo_c_e = true
	_conta("e ricompare", turbo_c_e)

	# La premessa, prima della prova (LEARNED.md § 19): la palla c'è.
	var doppio_c_e := false
	for p in Potenziamenti.disponibili:
		if p.distance_to(doppio["dove"]) < 0.1:
			doppio_c_e = true
	_conta("la palla dei punti doppi è lì, libera", doppio_c_e)
	giocatore.global_position = (doppio["dove"] as Vector3) + Vector3(0, 0.3, 0)
	giocatore.velocity = Vector3.ZERO
	await _aspetta(0.25)
	_conta("si prendono i punti doppi", potenziamenti.ha(giocatore, "doppio"))
	# Un colpo diretto del giocatore vale cinquanta invece di venticinque.
	var prima := int((arena.call("punteggi") as Array)[0])
	var bersaglio := bots[0] as Avversario
	bersaglio.set("_immunita", 0.0)
	bersaglio.incassa(0, giocatore)
	await process_frame
	var dopo := int((arena.call("punteggi") as Array)[0])
	_conta("con i punti doppi un colpo diretto vale 50", dopo - prima == 50, "%d punti" % (dopo - prima))

	# Le particelle: un dardo che prende un corpo schizza gommapiuma.
	var scintille: Scintille = Scintille.attivo
	var prima_colpo := scintille.accese("colpo")
	Scintille.colpo(giocatore.global_position + Vector3(0, 1, -2), Vector3.UP, Color.WHITE)
	_conta("un colpo fa schizzare le particelle", scintille.accese("colpo") > prima_colpo)

	arena.queue_free()
	await process_frame


## **I corpi costano poco** (04/10/2026). In Compatibility ogni corpo animato si
## deforma a ogni passo d'animazione, pezzo per pezzo, e il contorno era fatto di due
## **copie** del corpo che si deformavano per conto loro. Adesso il contorno sono due
## passate in più degli stessi pezzi, e chi è lontano o alle spalle si anima più di
## rado. Qui: nessun pezzo deformato è la copia di un altro; il contorno si accende da
## vicino e si spegne da lontano; il ritmo segue distanza e inquadratura.
func _i_corpi_costano_poco(giocatore: Giocatore, bots: Array) -> void:
	var copie := 0
	for b in bots:
		var visti := {}
		for nodo in ((b as Node).get("_corpo") as Node).find_children("*", "MeshInstance3D", true, false):
			var pezzo := nodo as MeshInstance3D
			if not (pezzo.mesh is ArrayMesh):
				continue
			var mesh := pezzo.mesh as ArrayMesh
			if mesh.get_surface_count() == 0 or not (mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_BONES):
				continue
			if visti.has(mesh):
				copie += 1
			visti[mesh] = true
	_conta("nessun pezzo deformato è la copia di un altro", copie == 0, "%d copie" % copie)

	var camera := giocatore.camera()
	var bot := bots[0] as Avversario
	var corpo := bot.get("_corpo") as Corpo
	bot.set_physics_process(false)
	var avanti := -camera.global_transform.basis.z
	avanti.y = 0.0
	avanti = avanti.normalized()
	var esiti := []
	var sbagliati := 0
	for prova in [{"metri": 6.0, "contorno": true, "ogni": 1},
			{"metri": 18.0, "contorno": false, "ogni": 2},
			{"metri": 32.0, "contorno": false, "ogni": 3},
			{"metri": -6.0, "contorno": true, "ogni": Corpo.OGNI_FUORI}]:
		bot.global_position = camera.global_position + avanti * float(prova["metri"]) 				- Vector3(0.0, Corpo.ALTEZZA_CORPO * 0.5, 0.0)
		for i in 3:
			await process_frame
		var ogni: int = corpo._ogni()
		var acceso := corpo.contorni_accesi()
		var giusto: bool = ogni == int(prova["ogni"]) and acceso == bool(prova["contorno"])
		esiti.append("%+.0f m: uno su %d, contorno %s%s" % [prova["metri"], ogni,
				"acceso" if acceso else "spento", "" if giusto else " ←"])
		if not giusto:
			sbagliati += 1
	bot.set_physics_process(true)
	_conta("contorno e ritmo seguono distanza e inquadratura", sbagliati == 0, " · ".join(esiti))


## **Un pavimento solo sopra ogni punto.** Dal telefono, il 04/10/2026: *«qualche zona
## del pavimento lampeggia quando ci passo»*. I passaggi diagonali stavano sopra le ali
## e gli angoli alla stessa quota, e la scheda video disegnava due pavimenti nello
## stesso piano: a ogni passo vinceva l'altro. Si campiona la pianta ogni metro, a ogni
## quota: sopra ogni punto di una zona ci deve essere **una** faccia di sopra. Due
## lampeggiano, zero sono un buco.
func _i_pavimenti(arena: Node) -> void:
	var zone: Array = (arena.call("pianta") as Dictionary)["zone"]
	# La premessa (LEARNED.md § 19): la pianta ha davvero zone che si sovrappongono,
	# altrimenti la prova passerebbe senza aver provato niente.
	var coppie := 0
	for i in zone.size():
		for j in range(i + 1, zone.size()):
			if absf(float(zone[i]["quota"]) - float(zone[j]["quota"])) > 0.01:
				continue
			for pezzo in Geometry2D.intersect_polygons(_poligono(zone[i]), _poligono(zone[j])):
				if _area(pezzo) > 0.01:
					coppie += 1
					break
	_conta("la pianta ha zone sovrapposte alla stessa quota (la premessa)", coppie >= 4,
			"%d coppie" % coppie)

	# Le facce di sopra dei pavimenti costruiti, per quota: triangoli orizzontali che si
	# vedono dall'alto (il prodotto dei lati punta in giù, lontano da chi guarda).
	var facce := {}
	for corpo in arena.get_tree().get_nodes_in_group(Muratura.GRUPPO_PAVIMENTI):
		for figlio in corpo.get_children():
			if not (figlio is MeshInstance3D):
				continue
			var pezzo := figlio as MeshInstance3D
			var vertici: PackedVector3Array = pezzo.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for t in range(0, vertici.size(), 3):
				var a := pezzo.global_transform * vertici[t]
				var b := pezzo.global_transform * vertici[t + 1]
				var c := pezzo.global_transform * vertici[t + 2]
				if absf(a.y - b.y) > 0.001 or absf(a.y - c.y) > 0.001:
					continue
				if (b - a).cross(c - a).y >= 0.0:
					continue
				var quota := snappedf(a.y, 0.01)
				if not facce.has(quota):
					facce[quota] = []
				(facce[quota] as Array).append([Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)])

	# Un metro di passo, spostato di un quarto e di sei decimi: così nessun punto cade
	# su un bordo, né dritto né in diagonale.
	var doppi := 0
	var buchi := 0
	var punti := 0
	for indice in zone.size():
		var quota := snappedf(float(zone[indice]["quota"]), 0.01)
		# La pianta già ritagliata dalle rampe (tappa 10): dove una rampa passa sotto
		# un pavimento, lì il pavimento non c'è apposta.
		var pezzi: Array = arena.call("pezzi_della_zona", indice)
		var triangoli: Array = facce.get(quota, [])
		var x := -33.0 + 0.25
		while x < 33.0:
			var z := -33.0 + 0.6
			while z < 33.0:
				var p := Vector2(x, z)
				if pezzi.any(func(pezzo: PackedVector2Array) -> bool:
						return Geometry2D.is_point_in_polygon(p, pezzo)):
					punti += 1
					var sopra := 0
					for tri in triangoli:
						if Geometry2D.point_is_inside_triangle(p, tri[0], tri[1], tri[2]):
							sopra += 1
					if sopra == 0:
						buchi += 1
					elif sopra > 1:
						doppi += 1
				z += 1.0
			x += 1.0
	_conta("sopra ogni punto della pianta un pavimento solo, mai due nello stesso piano",
			doppi == 0, "%d punti con due pavimenti, su %d" % [doppi, punti])
	_conta("e nessun buco dove la pianta ha un pavimento", buchi == 0,
			"%d punti scoperti, su %d" % [buchi, punti])


## **La camera non esce dall'arena.** Dal telefono, il 04/10/2026: *«se sono attaccato
## ai bordi dell'arena e giro la visuale vedo il nero fuori dell'arena»*. La spalla della
## camera sta 85 cm a destra della testa: col muro a destra finiva dentro il muro, e il
## braccio — che cerca gli ostacoli partendo da lì — ignorava proprio quello. Il
## giocatore contro i quattro muri e nei quattro angoli, girato su otto direzioni: la
## camera abbastanza lontana dalle facce interne (±33 m) perché il piano vicino non ci
## entri, e raggiungibile dalla testa passando dalla spalla senza attraversare niente.
func _la_camera(arena: Node) -> void:
	# Gli angoli del piano vicino stanno a 11 cm dal centro della camera, sul telefono.
	const VICINO := 0.12
	var giocatore: Giocatore = arena.call("giocatore")
	var testa := giocatore.get("_testa") as Node3D
	var braccio := giocatore.get("_braccio") as Node3D
	var spazio := giocatore.get_world_3d().direct_space_state
	var prove := 0
	var spostati := 0
	var nel_muro := 0
	var fuori := 0
	var attraversa := 0
	# Contro i muri, dove ci si può stare davvero: a ovest e a sud, lungo il muro, corre
	# una sponda bassa a mezzo metro dalla parete, e un punto messo lì nasce dentro la
	# sponda (la fisica lo spinge nell'intercapedine, dove nessuno può stare).
	for dove in [Vector3(32.5, 0.4, 2.0), Vector3(-32.0, 0.4, 1.0), Vector3(2.0, 0.4, -32.5),
			Vector3(-3.0, 0.4, 32.1), Vector3(32.5, 0.4, -32.5), Vector3(-32.5, 0.4, -32.5),
			Vector3(32.5, 0.4, 32.5), Vector3(-32.5, 0.4, 32.5)]:
		for giro in range(0, 360, 45):
			giocatore.global_position = dove
			giocatore.velocity = Vector3.ZERO
			giocatore.punta(float(giro), -6.0)
			# Il braccio si allunga nella fisica, la spalla si cerca nel disegno.
			for i in 3:
				await physics_frame
				await process_frame
			prove += 1
			# Le premesse (LEARNED.md § 19): il giocatore sta dove l'ho messo, e senza
			# rimedio la spalla sarebbe finita oltre il muro.
			var scarto: Vector3 = giocatore.global_position - (dove as Vector3)
			if Vector2(scarto.x, scarto.z).length() > 0.1:
				spostati += 1
			var spalla := testa.global_transform * Vector3(Giocatore.SPALLA_TERZA, 0.22, 0.0)
			if absf(spalla.x) > 33.0 or absf(spalla.z) > 33.0:
				nel_muro += 1
			var c := giocatore.camera().global_position
			if absf(c.x) > 33.0 - VICINO or absf(c.z) > 33.0 - VICINO:
				fuori += 1
			for tratto in [[testa.global_position, braccio.global_position],
					[braccio.global_position, c]]:
				var domanda := PhysicsRayQueryParameters3D.create(tratto[0], tratto[1],
						Strati.SOLIDO, [giocatore.get_rid()])
				if not spazio.intersect_ray(domanda).is_empty():
					attraversa += 1
	_conta("il giocatore sta dove la prova lo mette (la premessa)", spostati == 0,
			"%d volte spostato su %d" % [spostati, prove])
	_conta("la prova mette davvero la spalla oltre il muro (la premessa)", nel_muro >= 8,
			"%d volte su %d" % [nel_muro, prove])
	_conta("addossati ai muri, la camera resta dentro e il piano vicino non tocca il muro",
			fuori == 0, "%d volte troppo vicina su %d" % [fuori, prove])
	_conta("e dalla testa alla spalla alla camera non si attraversa niente", attraversa == 0,
			"%d tratti su %d" % [attraversa, prove * 2])


func _poligono(zona: Dictionary) -> PackedVector2Array:
	var fuori := PackedVector2Array()
	for p in zona["poligono"]:
		fuori.append(Vector2(float(p[0]), float(p[1])))
	return fuori


# ------------------------------------------------------------------ la resa

## **La risoluzione che si adatta** (tappa 9). Sul telefono non la si può provare
## da qui; la decisione sì. Dal 04/10/2026 (terza parte) si scende **guardando il
## lavoro**: se il gioco lavora meno di metà del fotogramma il limite è la scheda video
## e si scende; se lavora quasi tutto, non si tocca niente. E non si confrontano più
## due momenti di gioco (`LEARNED.md` § 53): si scende e basta, non si risale.
func _la_resa() -> void:
	var di_prima := root.scaling_3d_scale
	# Quanti gradini ci sono dalla partenza alla metà: i conti seguono le costanti, così
	# cambiare la scala di partenza non rompe la prova.
	var gradini := int(ceil((Resa.SCALA_TELEFONO - Resa.SCALA_MINIMA) / Resa.GRADINO - 0.001))

	# Il telefono del 04/10: 30 fotogrammi, e il gioco ne lavora 8 ms su 33.
	var resa := Resa.new()
	root.add_child(resa)
	root.scaling_3d_scale = Resa.SCALA_TELEFONO
	resa._decidi(30.0, 8.0)
	_conta("aspettando la scheda video la scena scende di un gradino",
			is_equal_approx(root.scaling_3d_scale, Resa.SCALA_TELEFONO - Resa.GRADINO),
			"%.2f" % root.scaling_3d_scale)
	for i in gradini + 2:
		resa._decidi(30.0, 8.0)
	_conta("e continua fino a metà, non oltre, anche se resta sotto la soglia", resa.ferma()
			and is_equal_approx(root.scaling_3d_scale, Resa.SCALA_MINIMA), "%.2f" % root.scaling_3d_scale)
	resa.queue_free()

	# Gli stessi 30 fotogrammi, ma il gioco ne lavora 30 ms: il limite è il calcolo, e
	# una scena sfocata non servirebbe. La controprova è la prova sopra: stessi
	# fotogrammi, lavoro corto, e si scende.
	resa = Resa.new()
	root.add_child(resa)
	root.scaling_3d_scale = Resa.SCALA_TELEFONO
	for i in gradini + 2:
		resa._decidi(30.0, 30.0)
	_conta("se il limite è il calcolo non si tocca niente", not resa.ferma()
			and is_equal_approx(root.scaling_3d_scale, Resa.SCALA_TELEFONO), "%.2f" % root.scaling_3d_scale)
	resa.queue_free()

	# Sceso un gradino, la scena si fa leggera: non si risale, perché tornerà pesante
	# appena ci si gira.
	resa = Resa.new()
	root.add_child(resa)
	root.scaling_3d_scale = Resa.SCALA_TELEFONO
	resa._decidi(30.0, 8.0)
	resa._decidi(60.0, 8.0)
	_conta("sopra la soglia si resta dove si è arrivati",
			is_equal_approx(root.scaling_3d_scale, Resa.SCALA_TELEFONO - Resa.GRADINO),
			"%.2f" % root.scaling_3d_scale)
	resa.queue_free()

	# La riga della partita del 04/10 mattina: un fotogramma da 17,4 secondi con la
	# pagina probabilmente ferma. Una finestra così non dice niente della scena.
	resa = Resa.new()
	root.add_child(resa)
	root.scaling_3d_scale = Resa.SCALA_TELEFONO
	resa._decidi(1.9, 2.0, 17416.0)
	_conta("una finestra con la pagina ferma non si giudica",
			is_equal_approx(root.scaling_3d_scale, Resa.SCALA_TELEFONO), "%.2f" % root.scaling_3d_scale)
	resa._decidi(1.9, 2.0)
	_conta("e senza il fotogramma lungo la stessa finestra farebbe scendere (controprova)",
			is_equal_approx(root.scaling_3d_scale, Resa.SCALA_TELEFONO - Resa.GRADINO),
			"%.2f" % root.scaling_3d_scale)
	resa.queue_free()

	resa = Resa.new()
	root.add_child(resa)
	root.scaling_3d_scale = Resa.SCALA_TELEFONO
	resa._decidi(59.0, 3.0)
	_conta("a 59 fotogrammi non si tocca niente",
			is_equal_approx(root.scaling_3d_scale, Resa.SCALA_TELEFONO) and not resa.ferma())
	resa.queue_free()
	_conta("e non si parte mai sopra la scala del 04/10 mattina",
			Resa.SCALA_TELEFONO <= 0.65 + 0.001, "%.2f" % Resa.SCALA_TELEFONO)
	root.scaling_3d_scale = di_prima
	await process_frame


## L'area di un contorno, con la formula dei lacci.
func _area(contorno: PackedVector2Array) -> float:
	var doppia := 0.0
	for i in contorno.size():
		var p := contorno[i]
		var q := contorno[(i + 1) % contorno.size()]
		doppia += p.x * q.y - q.x * p.y
	return absf(doppia) * 0.5


func _il_via(arena: Node) -> void:
	var scadenza := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < scadenza and float(arena.call("conto_alla_rovescia")) > 0.0:
		await process_frame
	await _aspetta(0.3)


func _aspetta(secondi: float) -> void:
	var fine := Time.get_ticks_msec() + int(secondi * 1000.0)
	while Time.get_ticks_msec() < fine:
		await physics_frame


func _conta(cosa: String, esito: bool, dettaglio := "") -> void:
	_prove += 1
	if esito:
		print("  ok   ", cosa)
	else:
		_errori += 1
		print("  NO   ", cosa, ("   (%s)" % dettaglio) if dettaglio != "" else "")
