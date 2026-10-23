extends SceneTree

## Collaudo della GARA (tappa 11, blocco D1).
##
## Le regole vengono dal 1999 (`RICERCA-ORIGINALE.md` § 2): sette bandiere in ordine, fuori
## ordine non conta, chi viene colpito riparte dall'ultima toccata, vince il primo alla
## settima e la partita finisce lì. Qui si controllano una per una, ognuna con la sua
## controprova (`LEARNED.md` § 19): un «non conta» vale solo accanto a un «questa sì».
## Poi la Home che sceglie la modalità, e dieci gare accelerate fra soli avversari che
## devono arrivare tutte in fondo.
##
## Uso:  godot --headless --path . -s tools/prova_gara.gd

## Quanto può mancare all'arrivo perché un percorso della rete valga «ci si arriva»: la rete
## verso un posto irraggiungibile risponde con la strada fino al punto più vicino.
const ARRIVO := 2.5
## Le dieci gare dell'ultimo controllo, accelerate come G0 (`tools/misura_gara.gd`).
const GARE := 10
const ACCELERA := 4.0
const TETTO := 300.0

var _errori := 0
var _prove := 0
var _arena: Arena


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var di_prima := Modalita.scelta()
	_arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(_arena)
	await process_frame
	await process_frame
	await _la_rete_c_e()

	_il_percorso()
	await _la_gara_comincia()
	await _fuori_ordine_non_conta()
	await _i_colpi_fermano()
	_la_classifica_conta_le_bandiere()
	await _l_avversario_corre()
	await _la_settima_vince()
	await _rigioca_e_chiudi()
	await _la_freccia()
	await _poi_lo_scontro_di_sempre()
	await _dieci_gare()
	_arena.queue_free()
	await process_frame
	await _la_home_sceglie()
	Modalita.scegli(di_prima)
	_chiudi()


## La mappa di navigazione risponde «vuoto» finché non è sincronizzata.
func _la_rete_c_e() -> void:
	var mappa := _arena.get_world_3d().navigation_map
	var scadenza := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < scadenza and NavigationServer3D.map_get_iteration_id(mappa) == 0:
		await physics_frame
	for i in 3:
		await process_frame
		await physics_frame
	NavigationServer3D.map_force_update(mappa)


# ------------------------------------------------------------------ il percorso

func _il_percorso() -> void:
	var b := _arena.bandiere()
	var pianta := _arena.pianta()
	_conta("il percorso ha sette bandiere", b.quante() == 7, "%d" % b.quante())
	var mappa := _arena.get_world_3d().navigation_map
	var tratti: Array[String] = []
	var lontane := ""
	var corti := ""
	var prima := b.partenza()
	for i in b.quante():
		var da := NavigationServer3D.map_get_closest_point(mappa, prima)
		var a := NavigationServer3D.map_get_closest_point(mappa, b.dove(i))
		var via := NavigationServer3D.map_get_path(mappa, da, a, true)
		if via.is_empty() or via[via.size() - 1].distance_to(b.dove(i)) > ARRIVO:
			lontane += " %d" % (i + 1)
		var lungo := 0.0
		for j in range(1, via.size()):
			lungo += via[j - 1].distance_to(via[j])
		tratti.append("%.0f" % lungo)
		if lungo < 25.0 or lungo > 80.0:
			corti += " %d (%.0f m)" % [i + 1, lungo]
		prima = b.dove(i)
	_conta("ogni bandiera si raggiunge dalla rete partendo dalla precedente", lontane == "",
			"irraggiungibili:%s" % lontane)
	_conta("i tratti stanno fra 25 e 80 metri di cammino", corti == "", corti)
	print("         tratti: %s m" % " · ".join(tratti))

	# Mai su una partenza, e lontano dalle sfere che restano in gara.
	var addosso := ""
	for i in b.quante():
		for p in pianta["partenze"]:
			var partenza := Vector3(float(p["dove"][0]), float(p["quota"]), float(p["dove"][1]))
			if partenza.distance_to(b.dove(i)) < 5.0:
				addosso += " %d su «%s»" % [i + 1, p["nome"]]
		for s in pianta["sfere"]:
			if Arena.FUORI_GARA.has(String(s["tipo"])):
				continue
			var sfera := Vector3(float(s["dove"][0]), float(s["quota"]), float(s["dove"][1]))
			if sfera.distance_to(b.dove(i)) < 5.0:
				addosso += " %d sulla sfera %s" % [i + 1, s["tipo"]]
	_conta("nessuna bandiera a meno di 5 m da una partenza o da una sfera in gara", addosso == "",
			addosso)

	# La griglia: sei posti, e in ognuno ci sta un corpo.
	var griglia := b.griglia()
	var stretti := 0
	for posto in griglia:
		if not b._c_e_posto(posto, _arena.get_world_3d().direct_space_state):
			stretti += 1
	_conta("la griglia ha sei posti, e in ognuno ci sta un corpo", griglia.size() == 6 and stretti == 0,
			"%d posti, %d stretti" % [griglia.size(), stretti])
	# La controprova del controllo: un posto dentro un muro deve risultare stretto.
	var muro: Dictionary = pianta["muri"][0]
	var dentro := Vector3(float(muro["centro"][0]), float(muro["quota"]), float(muro["centro"][1]))
	_conta("controprova: un posto dentro un muro risulta stretto",
			not b._c_e_posto(dentro, _arena.get_world_3d().direct_space_state))


# ------------------------------------------------------------------ la gara

func _la_gara_comincia() -> void:
	var b := _arena.bandiere()
	_conta("fuori dalla gara le bandiere non si vedono", not b.visible)
	_arena.imposta_modalita(Modalita.GARA)
	_arena.avvia_sfida()
	await _entrano_tutti(5)
	_conta("in gara si vedono", b.visible)
	_conta("e il limite è quello della gara", is_equal_approx(_arena.tempo_rimasto(), Arena.DURATA_GARA),
			"%.0f s" % _arena.tempo_rimasto())

	# Tutti in griglia, raggruppati: nessuno a più di tre metri e mezzo dal centro.
	var centro := b.partenza()
	var lontani := 0
	for corpo in _corpi():
		if Vector2(corpo.global_position.x - centro.x, corpo.global_position.z - centro.z).length() > 3.5:
			lontani += 1
	_conta("si parte tutti dalla griglia", lontani == 0, "%d fuori griglia" % lontani)

	var potenziamenti: Potenziamenti = _arena.get_node("potenziamenti")
	var spente := ""
	for sfera in potenziamenti._sfere:
		var tipo := String(sfera["tipo"])
		var accesa := (sfera["nodo"] as Node3D).visible
		if accesa == Arena.FUORI_GARA.has(tipo):
			spente += " %s %s" % [tipo, "accesa" if accesa else "spenta"]
	_conta("PUNTI DOPPI e LADRO non ci sono, le altre quattro sì",
			spente == "" and potenziamenti.quante_disponibili() == 4, spente)
	var fuori := 0
	for bonus in _arena.bersagli_bonus():
		if not bonus.visible and bonus.collision_layer == 0:
			fuori += 1
	_conta("i bersagli bonus si fanno da parte", fuori == _arena.bersagli_bonus().size(),
			"%d su %d" % [fuori, _arena.bersagli_bonus().size()])
	_conta("al posto dei punti, la bandiera da toccare",
			_arena._bandiera_scritta() == "BANDIERA 1 DI 7", _arena._bandiera_scritta())

	await _il_via()
	# Fermi tutti: da qui le bandiere le tocca solo la prova (LEARNED.md § 19).
	for bot in _arena.avversari():
		bot.process_mode = Node.PROCESS_MODE_DISABLED
	_conta("al via ognuno ha la sua prima bandiera",
			_arena.avversari()[0].traguardo.distance_to(b.dove(0)) < 0.01)
	# La partenza protetta: in griglia a due metri, al VIA nessuno si può colpire (la
	# controprova, tre secondi dopo, è il primo colpo di `_i_colpi_fermano`).
	var tu := _arena.giocatore()
	_conta("al via nessuno si può colpire", not tu.incassa(0, _arena.avversari()[0])
			and _arena.avversari()[1].immune())


func _fuori_ordine_non_conta() -> void:
	var b := _arena.bandiere()
	var tu := _arena.giocatore()
	await _porta(tu, b.dove(2))
	_conta("toccata fuori ordine, la terza non conta", _arena.bandiere_di(tu) == 0,
			"%d bandiere" % _arena.bandiere_di(tu))
	var avviso: Label = tu.comandi._avviso
	_conta("e un avviso dice quale serve", avviso.text == "PRIMA LA BANDIERA 1", avviso.text)
	await _porta(tu, b.dove(0))
	_conta("controprova: la prima conta", _arena.bandiere_di(tu) == 1, "%d" % _arena.bandiere_di(tu))
	_conta("e la colonna di luce passa alla seconda",
			Vector2(b._colonna.position.x, b._colonna.position.z).distance_to(
				Vector2(b.dove(1).x, b.dove(1).z)) < 0.01)
	await _porta(tu, b.dove(1))
	_conta("poi la seconda", _arena.bandiere_di(tu) == 2, "%d" % _arena.bandiere_di(tu))


func _i_colpi_fermano() -> void:
	var b := _arena.bandiere()
	var tu := _arena.giocatore()
	var bot := _arena.avversari()[0]
	await _non_immune(tu)
	_conta("controprova: passati i tre secondi della partenza, sì", not tu.immune())
	var lontano := tu.global_position + Vector3(9.0, 0.0, 0.0)
	tu.global_position = lontano
	await physics_frame
	var colpito := tu.incassa(0, bot)
	await process_frame
	await process_frame
	var punti: Array = _arena.punteggi()
	_conta("in gara un colpo non fa punti", colpito and int(punti[0]) == 0 and int(punti[1]) == 0,
			str(punti))
	var piano := Vector2(tu.global_position.x - b.dove(1).x, tu.global_position.z - b.dove(1).z).length()
	_conta("chi è colpito riparte dall'ultima bandiera che ha toccato (la seconda)",
			piano <= Bandiere.RIPARTENZA + 0.6 and absf(tu.global_position.y - b.dove(1).y) < 1.0,
			"a %.1f m dalla seconda" % piano)
	_conta("e lo sa", (tu.comandi._avviso as Label).text == "COLPITO DA %s" % bot.personaggio,
			(tu.comandi._avviso as Label).text)

	# La controprova: un avversario che non ne ha toccata nessuna torna al suo posto in griglia.
	var altro := _arena.avversari()[1]
	var riga: Dictionary = _arena._concorrenti[_arena._riga_di(altro)]
	altro.global_position = b.dove(4) + Vector3(0, 0.4, 0)
	await physics_frame
	# Fermo, la protezione della partenza non gli scorre: la si toglie a mano.
	altro.set("_immunita", 0.0)
	altro.incassa(0, tu)
	await process_frame
	await process_frame
	var posto: Vector3 = b.griglia()[int(riga["posto"])]
	_conta("controprova: senza bandiere si torna al proprio posto in griglia",
			Vector2(altro.global_position.x - posto.x, altro.global_position.z - posto.z).length() < 0.5,
			"a %.1f m" % altro.global_position.distance_to(posto))
	_conta("e il colpo del giocatore non gli fa punti", int(_arena.punteggi()[0]) == 0)

	var comandi: Comandi = tu.comandi
	var camera := tu.camera()
	comandi.punti_dal_mondo(camera.global_position - camera.global_transform.basis.z * 6.0, 25, 0)
	var etichetta: Label = comandi._etichette_volanti[(comandi._prossima_etichetta + comandi._etichette_volanti.size() - 1) % comandi._etichette_volanti.size()]["etichetta"]
	_conta("il colpo a segno dice FERMATO, non i punti", etichetta.text == Comandi.TESTO_FERMATO,
			etichetta.text)


func _la_classifica_conta_le_bandiere() -> void:
	var righe := _arena.classifica()
	_conta("in testa chi ha più bandiere", bool(righe[0]["tu"]) and righe[0]["testo"] == "2/7",
			str(righe[0]))
	# A pari bandiere passa chi l'ha toccata prima: BRACE ne fa due adesso, dopo di te.
	var bot := _arena.avversari()[0]
	var r := _arena._riga_di(bot)
	_arena._concorrenti[r]["bandiere"] = 2
	_arena._concorrenti[r]["quando"] = _arena.orologio() + 1.0
	righe = _arena.classifica()
	_conta("a pari bandiere passa chi l'ha toccata prima", bool(righe[0]["tu"])
			and String(righe[1]["nome"]) == bot.personaggio, "%s, %s" % [righe[0]["nome"], righe[1]["nome"]])
	# La controprova: una bandiera in più batte il tempo.
	_arena._concorrenti[r]["bandiere"] = 3
	righe = _arena.classifica()
	_conta("controprova: una bandiera in più batte chi è arrivato prima",
			String(righe[0]["nome"]) == bot.personaggio and _arena.posizione_mia() == 2,
			"%s primo, tu %d°" % [righe[0]["nome"], _arena.posizione_mia()])
	_arena._concorrenti[r]["bandiere"] = 0
	_arena._concorrenti[r]["quando"] = 0.0


func _l_avversario_corre() -> void:
	var b := _arena.bandiere()
	var bot := _arena.avversari()[2]
	var tu := _arena.giocatore()
	# Il giocatore fermo e fuori vista, così il corridore non si ferma a nessun duello.
	tu.process_mode = Node.PROCESS_MODE_DISABLED
	tu.global_position = Vector3(0, -40, 0)
	_arena._dai_il_traguardo(_arena._riga_di(bot))
	bot.process_mode = Node.PROCESS_MODE_INHERIT
	var partito := bot.global_position
	var inizio := Time.get_ticks_msec()
	while Time.get_ticks_msec() - inizio < 25000 and _arena.bandiere_di(bot) < 1:
		await physics_frame
	_conta("un avversario corre fino alla sua bandiera sulla rete", _arena.bandiere_di(bot) >= 1,
			"in %.1f s, da %.0f m" % [(Time.get_ticks_msec() - inizio) / 1000.0, partito.distance_to(b.dove(0))])
	_conta("e poi punta la seconda", bot.traguardo.distance_to(b.dove(1)) < 0.01)
	bot.process_mode = Node.PROCESS_MODE_DISABLED
	tu.process_mode = Node.PROCESS_MODE_INHERIT


func _la_settima_vince() -> void:
	var b := _arena.bandiere()
	var tu := _arena.giocatore()
	# Prima la controprova: un avversario con tre bandiere sulla settima non chiude niente.
	var bot := _arena.avversari()[3]
	var r := _arena._riga_di(bot)
	_arena._concorrenti[r]["bandiere"] = 3
	await _porta(bot, b.dove(6))
	_conta("sulla settima fuori ordine non si vince", not bool(_arena.get("_finita"))
			and _arena.bandiere_di(bot) == 3)
	bot.global_position = b.griglia()[0] + Vector3(0, 0.4, 0)
	_arena._concorrenti[r]["bandiere"] = 0
	# Tu, con sei bandiere, sulla settima.
	_arena._concorrenti[_arena._riga_di(tu)]["bandiere"] = 6
	await _porta(tu, b.dove(6))
	var righe := _arena.classifica()
	_conta("chi tocca la settima vince, e la partita finisce lì", bool(_arena.get("_finita"))
			and bool(righe[0]["tu"]) and righe[0]["testo"] == "7/7", str(righe[0]))
	_conta("e sale il podio", tu.comandi._podio != null and tu.comandi._podio.visible)
	var fermi := 0
	for uno in _arena.avversari():
		if not uno.in_gara():
			fermi += 1
	_conta("e nessuno corre più", fermi == _arena.avversari().size(), "%d fermi" % fermi)
	_conta("la colonna di luce si spegne", not b._colonna.visible)


func _rigioca_e_chiudi() -> void:
	var b := _arena.bandiere()
	_arena.rigioca()
	await _entrano_tutti(5)
	var tutte_zero := true
	for corpo in _corpi():
		if _arena.bandiere_di(corpo) != 0:
			tutte_zero = false
	_conta("RIGIOCA riparte da zero bandiere, in gara", tutte_zero and _arena.in_gara()
			and not bool(_arena.get("_finita")))
	_conta("con la colonna sulla prima", b._colonna.visible and Vector2(b._colonna.position.x,
			b._colonna.position.z).distance_to(Vector2(b.dove(0).x, b.dove(0).z)) < 0.01)
	_arena.chiudi_sfida()
	await process_frame
	var potenziamenti: Potenziamenti = _arena.get_node("potenziamenti")
	var bonus_accesi := 0
	for bonus in _arena.bersagli_bonus():
		if bonus.visible and bonus.collision_layer != 0 and bonus.acceso():
			bonus_accesi += 1
	_conta("chiusa la gara l'arena torna com'era: bandiere spente, sei sfere, bersagli bonus accesi",
			not b.visible and potenziamenti.quante_disponibili() == 6
			and bonus_accesi == _arena.bersagli_bonus().size(),
			"bandiere %s, sfere %d, bonus %d" % [b.visible, potenziamenti.quante_disponibili(), bonus_accesi])


## La freccia sul bordo: c'è quando la bandiera è alle spalle, non c'è quando la guardi.
func _la_freccia() -> void:
	var b := _arena.bandiere()
	var tu := _arena.giocatore()
	_arena.imposta_modalita(Modalita.GARA)
	_arena.avvia_sfida()
	await _entrano_tutti(5)
	await _il_via()
	for bot in _arena.avversari():
		bot.process_mode = Node.PROCESS_MODE_DISABLED
	var comandi: Comandi = tu.comandi
	tu.punta(Bandiere.giro_verso(b.dove(0), tu.global_position), 0.0)
	await process_frame
	await process_frame
	var dove := comandi.dove_la_freccia()
	var tela := comandi._disegno.size
	_conta("con la bandiera alle spalle, la freccia sta sul bordo dello schermo", dove != Vector2.INF
			and (dove.x <= Comandi.MARGINE_FRECCIA + 1.0 or dove.x >= tela.x - Comandi.MARGINE_FRECCIA - 1.0
			or dove.y <= Comandi.MARGINE_FRECCIA + 1.0 or dove.y >= tela.y - Comandi.MARGINE_FRECCIA - 1.0),
			"%s su %s" % [dove, tela])
	_conta("e in basso, perché è dietro", dove != Vector2.INF and dove.y > tela.y * 0.5, str(dove))
	# Dalla griglia, girati verso la prima: è nello schermo ma dietro il muro.
	tu.punta(Bandiere.giro_verso(tu.global_position, b.dove(0)), -4.0)
	await process_frame
	await process_frame
	_conta("girati verso la bandiera coperta: niente freccia, il segnalino sopra di lei",
			comandi.dove_la_freccia() == Vector2.INF and comandi.dove_il_segnalino() != Vector2.INF,
			"freccia %s, segnalino %s" % [comandi.dove_la_freccia(), comandi.dove_il_segnalino()])
	# In vista, a sette metri: né freccia né segnalino, c'è la colonna.
	var verso := b.partenza() - b.dove(0)
	verso.y = 0.0
	var davanti := b.dove(0) + verso.normalized() * 7.0
	tu.global_position = davanti + Vector3(0, 0.4, 0)
	tu.punta(Bandiere.giro_verso(davanti, b.dove(0)), -4.0)
	for i in 4:
		await physics_frame
		await process_frame
	_conta("controprova: in vista, né freccia né segnalino", comandi.dove_la_freccia() == Vector2.INF
			and comandi.dove_il_segnalino() == Vector2.INF,
			"freccia %s, segnalino %s" % [comandi.dove_la_freccia(), comandi.dove_il_segnalino()])
	_arena.chiudi_sfida()
	await process_frame
	_conta("fuori dalla gara la freccia è spenta", comandi.dove_la_freccia() == Vector2.INF)


func _poi_lo_scontro_di_sempre() -> void:
	_arena.imposta_modalita(Modalita.SCONTRO)
	_arena.avvia_sfida()
	await _entrano_tutti(5)
	await _il_via()
	var righe := _arena.classifica()
	_conta("dopo una gara lo scontro è quello di sempre: niente bandiere, punti in classifica, tre minuti",
			not _arena.bandiere().visible and not _arena.in_gara() and not righe[0].has("testo")
			and _arena.tempo_rimasto() > Arena.DURATA_PARTITA - 3.0,
			"bandiere %s, gara %s, riga %s, %.0f s" % [_arena.bandiere().visible, _arena.in_gara(),
			str(righe[0]), _arena.tempo_rimasto()])
	var bot := _arena.avversari()[0]
	for uno in _arena.avversari():
		uno.process_mode = Node.PROCESS_MODE_DISABLED
	var tu := _arena.giocatore()
	bot.incassa(0, tu)
	await process_frame
	_conta("e un colpo vale 25 punti", int(_arena.punteggi()[0]) == 25, str(_arena.punteggi()))
	_conta("e l'etichetta dice i punti", not tu.comandi.senza_punti)
	_arena.chiudi_sfida()
	await process_frame


## Dieci gare fra soli avversari, accelerate come G0: tutte devono arrivare in fondo.
func _dieci_gare() -> void:
	Engine.physics_ticks_per_second = int(round(60.0 * ACCELERA))
	Engine.max_physics_steps_per_frame = 16
	Engine.time_scale = ACCELERA
	_arena.imposta_modalita(Modalita.GARA)
	_arena.imposta_durata(TETTO)
	var tu := _arena.giocatore()
	var chiuse := 0
	var durate: Array[String] = []
	for g in GARE:
		_arena.avvia_sfida()
		tu.process_mode = Node.PROCESS_MODE_DISABLED
		tu.global_position = Vector3(0, -40, 0)
		var scadenza := Time.get_ticks_msec() + int((TETTO / ACCELERA + 20.0) * 1000.0)
		while Time.get_ticks_msec() < scadenza and not bool(_arena.get("_finita")):
			await process_frame
		var primo: Dictionary = _arena.classifica()[0]
		if int(primo["bandiere"]) >= _arena.bandiere().quante():
			chiuse += 1
		durate.append("%.0f" % _arena.orologio())
		_arena.chiudi_sfida()
		tu.process_mode = Node.PROCESS_MODE_INHERIT
		await process_frame
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	Engine.max_physics_steps_per_frame = 8
	_conta("dieci gare accelerate fra soli avversari arrivano tutte in fondo", chiuse == GARE,
			"%d su %d" % [chiuse, GARE])
	print("         durate: %s s" % " · ".join(durate))


# ------------------------------------------------------------------ la home

func _la_home_sceglie() -> void:
	Modalita.scegli(Modalita.SCONTRO)
	var ingresso: Node = load("res://scenes/ingresso.tscn").instantiate()
	root.add_child(ingresso)
	current_scene = ingresso
	await process_frame
	var pulsanti: Array = ingresso.get("_modalita")
	var nomi: Array[String] = []
	for p in pulsanti:
		nomi.append((p as Button).text)
	_conta("sulla Home la riga delle modalità dice SCONTRO e GARA", nomi == ["SCONTRO", "GARA"], str(nomi))
	var gioca: Button = ingresso.get("_gioca")
	var riga := (pulsanti[0] as Control).get_parent() as Control
	_conta("e sta sopra GIOCA", riga.position.y + 52.0 <= gioca.position.y, "%.0f, %.0f" % [riga.position.y, gioca.position.y])
	(pulsanti[1] as Button).pressed.emit()
	_conta("toccata GARA, la scelta è la gara e resta salvata", Modalita.scelta() == Modalita.GARA
			and _salvata() == Modalita.GARA)
	var scadenza := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < scadenza and ingresso.get("_arena_pronta") == null:
		await process_frame
	ingresso.call("_comincia")
	await process_frame
	var arena := current_scene
	_conta("e GIOCA entra in gara", arena is Arena and (arena as Arena).in_gara(),
			arena.get_class() if arena != null else "niente")
	if arena is Arena:
		(arena as Arena).chiudi_sfida()
		arena.queue_free()
	await process_frame


func _salvata() -> int:
	var cfg := ConfigFile.new()
	return int(cfg.get_value("modalita", "scelta", -1)) if cfg.load(Modalita.FILE) == OK else -1


# ------------------------------------------------------------------ attrezzi

func _corpi() -> Array[Node3D]:
	var corpi: Array[Node3D] = [_arena.giocatore()]
	for bot in _arena.avversari():
		corpi.append(bot)
	return corpi


## Porta un corpo su un posto e aspetta che l'arena lo veda.
func _porta(corpo: Node3D, dove: Vector3) -> void:
	corpo.global_position = dove + Vector3(0, 0.4, 0)
	if corpo is CharacterBody3D:
		(corpo as CharacterBody3D).velocity = Vector3.ZERO
	for i in 3:
		await physics_frame
		await process_frame


func _non_immune(corpo: Node3D) -> void:
	var scadenza := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < scadenza and bool(corpo.call("immune")):
		await physics_frame


func _il_via() -> void:
	var scadenza := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < scadenza:
		await process_frame
		if _arena.conto_alla_rovescia() <= 0.0:
			return


func _entrano_tutti(quanti: int) -> void:
	var scadenza := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < scadenza:
		await process_frame
		if _arena.avversari().size() >= quanti:
			return


func _conta(cosa: String, esito: bool, dettaglio := "") -> void:
	_prove += 1
	if esito:
		print("  ok   ", cosa)
	else:
		_errori += 1
		print("  NO   ", cosa, ("   (%s)" % dettaglio) if dettaglio != "" else "")


func _chiudi() -> void:
	print("\nGARA: %d prove, %d errori" % [_prove, _errori])
	quit(1 if _errori > 0 else 0)
