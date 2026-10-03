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
## - che **i pavimenti si vedano dall'alto**: fino al 03/10/2026 erano invisibili, e
##   nessun collaudo poteva accorgersene;
## - che le scatole smussate guardino tutte fuori;
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
func _le_forme() -> void:
	for prova in [
		{"nome": "rettangolo", "punti": [Vector2(-3, -2), Vector2(3, -2), Vector2(3, 2), Vector2(-3, 2)]},
		{"nome": "rettangolo al contrario", "punti": [Vector2(-3, 2), Vector2(3, 2), Vector2(3, -2), Vector2(-3, -2)]},
		{"nome": "a elle (concavo)", "punti": [Vector2(0, 0), Vector2(0, 4), Vector2(5, 4), Vector2(5, 2), Vector2(2, 2), Vector2(2, 0)]},
	]:
		var contorno := PackedVector2Array(prova["punti"])
		var mesh := Muratura._prisma(contorno, 0.0, -0.6)
		var vertici: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var sopra_ok := true
		var fianchi_ok := true
		var centro := Vector2.ZERO
		for p in contorno:
			centro += p
		centro /= float(contorno.size())
		for t in range(0, vertici.size(), 3):
			var a := vertici[t]
			var b := vertici[t + 1]
			var c := vertici[t + 2]
			var croce := (b - a).cross(c - a)
			var orizzontale := absf(a.y - b.y) < 0.0001 and absf(a.y - c.y) < 0.0001
			if orizzontale:
				if croce.dot(Vector3.UP) >= 0.0:
					sopra_ok = false
			else:
				# Un fianco: deve guardare fuori dal poligono.
				var meta := (a + b + c) / 3.0
				var fuori := Vector3(croce.x, 0.0, croce.z).normalized() * -1.0
				var passo := Vector2(meta.x + fuori.x * 0.02, meta.z + fuori.z * 0.02)
				if Geometry2D.is_point_in_polygon(passo, contorno):
					fianchi_ok = false
		_conta("pavimento %s: la faccia di sopra si vede dall'alto" % prova["nome"], sopra_ok)
		_conta("pavimento %s: i fianchi guardano fuori" % prova["nome"], fianchi_ok)

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
	var potenziamenti := arena.get_node("potenziamenti") as Potenziamenti
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
