extends SceneTree

## Collaudo della PALLA (tappa 11, blocco D2).
##
## Le regole vengono dal 1999 (`RICERCA-ORIGINALE.md` § 2): le palle si raccolgono passandoci
## sopra e se ne portano più d'una; in porta si lanciano, non si portano; lanciata addosso a
## un altro gliela consegni; chi è colpito le perde tutte; la dorata compare quando qualcuno
## ha segnato tutte e sei, e chi le ha segnate e segna la dorata chiude la partita. Ognuna con
## la sua controprova (`LEARNED.md` § 19). Poi il lancio: la strada disegnata è quella vera.
## E un avversario che porta una palla davanti alla porta la mette dentro.
##
## Uso:  godot --headless --path . -s tools/prova_palla.gd

const PARTITE := 3
const ACCELERA := 4.0
const TETTO := 240.0

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

	_porte_e_cannoni()
	await _la_partita_comincia()
	await _si_raccolgono()
	await _in_porta()
	await _colpito_le_perde()
	await _lanciata_addosso()
	await _il_lancio_e_la_sua_strada()
	await _la_dorata()
	await _le_palle_perse()
	await _l_avversario_segna()
	await _poi_lo_scontro_di_sempre()
	await _partite_accelerate()
	_arena.queue_free()
	await process_frame
	await _la_home()
	Modalita.scegli(di_prima)
	_chiudi()


func _la_rete_c_e() -> void:
	var mappa := _arena.get_world_3d().navigation_map
	var scadenza := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < scadenza and NavigationServer3D.map_get_iteration_id(mappa) == 0:
		await physics_frame
	for i in 3:
		await process_frame
		await physics_frame
	NavigationServer3D.map_force_update(mappa)


# ------------------------------------------------------------------ il campo

func _porte_e_cannoni() -> void:
	var palle := _arena.palle()
	var mappa := _arena.get_world_3d().navigation_map
	_conta("due porte e otto cannoni", palle.porte().size() == 2 and palle.cannoni().size() == 8,
			"%d porte, %d cannoni" % [palle.porte().size(), palle.cannoni().size()])
	_conta("sette palle: sei colorate e la dorata, coi valori del 1999 divisi per dieci",
			palle.palle().size() == 7 and palle.palle()[0].valore == 75 and palle.palle()[5].valore == 200
			and palle.dorata().valore == 500)
	var fuori := ""
	for i in palle.porte().size():
		var davanti := palle.davanti_alla_porta(i, 6.0)
		if NavigationServer3D.map_get_closest_point(mappa, davanti).distance_to(davanti) > 1.5:
			fuori += " porta %d" % i
	for c in palle.cannoni():
		if NavigationServer3D.map_get_closest_point(mappa, c).distance_to(c) > 1.0:
			fuori += " cannone %s" % c
	_conta("davanti a ogni porta e a ogni cannone ci si arriva a piedi", fuori == "", fuori)
	# Nella variante dell'aspetto in uso: la corsia davanti alla bocca libera (otto metri,
	# larga quanto la porta) e intorno a ogni cannone un metro e mezzo di posto. Gli oggetti
	# delle varianti la misura delle porte non li conosceva.
	var spazio := _arena.get_world_3d().direct_space_state
	var ingombri := ""
	for i in palle.porte().size():
		var porta: Dictionary = palle.porte()[i]
		var verso: Vector3 = porta["verso"]
		var scatola := BoxShape3D.new()
		scatola.size = Vector3(Palle.LARGA - 0.4, Palle.ALTA - 0.6, 8.0)
		var domanda := PhysicsShapeQueryParameters3D.new()
		domanda.shape = scatola
		domanda.collision_mask = Strati.SOLIDO
		domanda.transform = Transform3D(Basis.looking_at(-verso, Vector3.UP),
				(porta["bocca"] as Vector3) + verso * 4.2 + Vector3(0, Palle.ALTA * 0.5, 0))
		var urti := spazio.intersect_shape(domanda, 4)
		if not urti.is_empty():
			ingombri += " porta %d (%s)" % [i, (urti[0]["collider"] as Node).name]
	for c in palle.cannoni():
		var cilindro := CylinderShape3D.new()
		cilindro.radius = 1.5
		cilindro.height = 2.2
		var domanda := PhysicsShapeQueryParameters3D.new()
		domanda.shape = cilindro
		domanda.collision_mask = Strati.SOLIDO
		domanda.transform = Transform3D(Basis.IDENTITY, c + Vector3(0, 1.4, 0))
		var urti := spazio.intersect_shape(domanda, 4)
		if not urti.is_empty():
			ingombri += " cannone %s (%s)" % [c, (urti[0]["collider"] as Node).name]
	_conta("nell'aspetto %s le corsie delle porte e i cannoni sono liberi" % Aspetto.nome(),
			ingombri == "", ingombri)
	_conta("fuori dalla PALLA porte e palle non si vedono", not palle.visible)


func _la_partita_comincia() -> void:
	var palle := _arena.palle()
	_arena.imposta_modalita(Modalita.PALLA)
	_arena.avvia_sfida()
	await _entrano_tutti(5)
	await _il_via()
	_conta("nella PALLA si vedono", palle.visible)
	var in_campo := 0
	for palla in palle.palle():
		if palla.in_campo():
			in_campo += 1
	_conta("le sei colorate sono in campo, la dorata no", in_campo == 6 and not palle.dorata().in_campo(),
			"%d in campo, dorata %s" % [in_campo, palle.dorata().in_campo()])
	_conta("le sfere sono tutte e sei, come nello scontro",
			(_arena.get_node("potenziamenti") as Potenziamenti).quante_disponibili() == 6)
	# Fermi tutti: da qui le palle le prende solo la prova.
	for bot in _arena.avversari():
		bot.process_mode = Node.PROCESS_MODE_DISABLED


func _si_raccolgono() -> void:
	var palle := _arena.palle()
	var tu := _arena.giocatore()
	var blu := palle.palle()[0]
	var verde := palle.palle()[1]
	# Nell'ala tribuna, lontano dai cannoni: una palla che ne esce non deve cadere qui.
	await _porta(tu, Vector3(-34.0, 0.0, -9.0))
	await _ferma(blu, Vector3(-31.0, 0.4, -9.0))
	await _ferma(verde, Vector3(-27.0, 0.4, -9.0))
	_conta("controprova: da lontano non si prende", blu.portata_da == null)
	await _porta(tu, Vector3(-31.0, 0.0, -9.0))
	await _porta(tu, Vector3(-27.0, 0.0, -9.0))
	var mie := palle.portate_da(tu)
	_conta("passandoci sopra si raccolgono, e se ne portano due", mie.size() >= 2
			and mie.has(blu) and mie.has(verde), "%d portate" % mie.size())
	await process_frame
	_conta("e girano intorno a chi le porta", blu.global_position.distance_to(tu.global_position) < 2.5)
	_conta("compare il pulsante LANCIA, nel colore della prima", tu.comandi.lancia_visibile()
			and tu.comandi.colore_del_lancio().is_equal_approx(blu.colore))


func _in_porta() -> void:
	var palle := _arena.palle()
	var tu := _arena.giocatore()
	var blu := palle.palle()[0]
	# Portata dentro la porta non vale: in porta si lancia.
	var prima := int(_arena.punteggi()[0])
	await _porta(tu, palle.porte()[0]["bocca"] - (palle.porte()[0]["verso"] as Vector3) * 0.8)
	_conta("portata in porta non vale", int(_arena.punteggi()[0]) == prima and blu.portata_da == tu)
	# Lanciata dentro sì: la si mette in volo sopra la bocca, autore il giocatore.
	await _porta(tu, palle.davanti_alla_porta(0, 6.0))
	palle.lancia(tu, blu, Vector3.ZERO)
	blu.global_position = palle.centro_della_porta(0)
	blu.linear_velocity = Vector3.ZERO
	await _attendi(func() -> bool: return not blu.in_campo(), 2000)
	await process_frame
	_conta("lanciata in porta dà il suo valore (75)", int(_arena.punteggi()[0]) - prima == 75,
			"%d punti" % (int(_arena.punteggi()[0]) - prima))
	_conta("e conta fra le segnate", _arena.segnate_da(tu).has(0))
	await _attendi(func() -> bool: return blu.in_campo(), 4000)
	_conta("e torna in campo da un cannone", blu.in_campo() and _vicino_a_un_cannone(blu.global_position),
			str(blu.global_position))
	# Coi PUNTI DOPPI il doppio.
	var verde := palle.palle()[1]
	(_arena.get_node("potenziamenti") as Potenziamenti)._effetti[tu.get_instance_id()] = {"doppio": 10.0}
	prima = int(_arena.punteggi()[0])
	palle.lancia(tu, verde, Vector3.ZERO)
	verde.global_position = palle.centro_della_porta(1)
	verde.linear_velocity = Vector3.ZERO
	await _attendi(func() -> bool: return not verde.in_campo(), 2000)
	await process_frame
	_conta("coi PUNTI DOPPI vale il doppio (200)", int(_arena.punteggi()[0]) - prima == 200,
			"%d punti" % (int(_arena.punteggi()[0]) - prima))
	(_arena.get_node("potenziamenti") as Potenziamenti)._effetti.erase(tu.get_instance_id())
	# Una palla che entra senza che nessuno l'abbia lanciata non vale niente.
	var gialla := palle.palle()[2]
	prima = int(_arena.punteggi()[0])
	await _ferma(gialla, palle.centro_della_porta(0))
	await _attendi(func() -> bool: return not gialla.in_campo(), 2000)
	await process_frame
	_conta("controprova: entrata da sola non vale niente", int(_arena.punteggi()[0]) == prima
			and _punti_di_tutti() == prima)


func _colpito_le_perde() -> void:
	var palle := _arena.palle()
	var tu := _arena.giocatore()
	var bot := _arena.avversari()[0]
	var rossa := palle.palle()[4]
	var viola := palle.palle()[5]
	await _attendi(func() -> bool: return rossa.libera(), 3000)
	await _porta(tu, Vector3(0, 0, -24))
	await _ferma(rossa, tu.global_position + Vector3(0, 0.4, 0))
	await _ferma(viola, tu.global_position + Vector3(0, 0.4, 0))
	await _attendi(func() -> bool: return palle.portate_da(tu).size() >= 2, 2000)
	var dove := tu.global_position
	await _non_immune(tu)
	tu.incassa(0, bot)
	await process_frame
	await process_frame
	_conta("colpito, perde tutte le palle che porta", palle.portate_da(tu).is_empty())
	_conta("che cadono dove stava", rossa.libera() and rossa.global_position.distance_to(dove) < 4.0
			and viola.libera() and viola.global_position.distance_to(dove) < 4.0,
			"a %.1f e %.1f m" % [rossa.global_position.distance_to(dove), viola.global_position.distance_to(dove)])
	_conta("e il colpo vale i suoi punti, come nello scontro", _punti_di(bot) == 25, "%d" % _punti_di(bot))


func _lanciata_addosso() -> void:
	var palle := _arena.palle()
	var tu := _arena.giocatore()
	var bot := _arena.avversari()[1]
	bot.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	var arancio := palle.palle()[3]
	await _attendi(func() -> bool: return arancio.libera(), 3000)
	await _porta(tu, Vector3(-6, 0, -24))
	await _ferma(arancio, tu.global_position + Vector3(0, 0.4, 0))
	await _attendi(func() -> bool: return arancio.portata_da == tu, 2000)
	bot.global_position = Vector3(2, 0.4, -24)
	await physics_frame
	var verso := (bot.global_position + Vector3(0, 1.0, 0)) - palle.da_dove_si_lancia(tu, Vector3(1, 0, 0))
	palle.lancia(tu, arancio, verso.normalized() * 12.0)
	await _attendi(func() -> bool: return arancio.portata_da != null, 2000)
	_conta("lanciata addosso a un altro, gliela consegni", arancio.portata_da == bot,
			"la porta %s" % (arancio.portata_da.name if arancio.portata_da != null else "nessuno"))
	_conta("controprova: appena lanciata non torna a chi l'ha lanciata",
			not arancio.si_prende(tu, palle._orologio) or arancio.portata_da == bot)
	palle.lascia_tutte(bot)
	# Via dal campo: fermo lì, prenderebbe al volo le palle delle prove dopo.
	bot.global_position = Vector3(0, -60, 0)


func _il_lancio_e_la_sua_strada() -> void:
	var palle := _arena.palle()
	var tu := _arena.giocatore()
	var blu := palle.palle()[0]
	await _attendi(func() -> bool: return blu.libera(), 4000)
	# Nell'ala ocra, girati verso est lungo l'ala, la mira un poco in su: davanti ci sono
	# venti metri di campo libero (verso il catino c'è la sua faccia nord, alta 14 m).
	await _porta(tu, Vector3(-12.0, 0, -24))
	tu.punta(-90.0, 10.0)
	await _ferma(blu, tu.global_position + Vector3(0, 0.4, 0))
	await _attendi(func() -> bool: return blu.portata_da == tu, 2000)
	var velocita := Palle.velocita_del_lancio(-tu.camera().global_transform.basis.z)
	var strada := palle.traiettoria(palle.da_dove_si_lancia(tu, velocita), velocita)
	var previsto := strada[strada.size() - 1]
	_arena.call("_lancia_la_tua")
	var primo_urto := Vector3.INF
	var scadenza := Time.get_ticks_msec() + 4000
	var prima := blu.global_position
	var velocita_prima := blu.linear_velocity
	while Time.get_ticks_msec() < scadenza:
		await physics_frame
		# Il primo urto: la velocità cambia verso di colpo (la caduta la piega piano).
		var adesso := blu.linear_velocity
		if blu.portata_da != null:
			break
		if adesso.length() > 0.5 and velocita_prima.length() > 0.5 				and adesso.normalized().dot(velocita_prima.normalized()) < 0.9:
			primo_urto = prima
			break
		velocita_prima = adesso
		prima = blu.global_position
	var scarto := primo_urto.distance_to(previsto) if primo_urto != Vector3.INF else INF
	_conta("la palla batte dove l'arco disegnato dice (entro un metro)", scarto < 1.0,
			"previsto %s, vero %s" % [previsto, primo_urto])
	# Quanto lontano arriva in piano, senza niente in mezzo: la stessa caduta e lo stesso
	# freno, fino a tornare all'altezza dei piedi. Non dipende dagli oggetti della variante.
	var p := palle.da_dove_si_lancia(tu, velocita)
	var v := velocita
	var piedi := tu.global_position.y
	var via := p
	while p.y > piedi or v.y > 0.0:
		v.y -= Palla.GRAVITA * Palle.PASSO_TRAIETTORIA
		v *= 1.0 - Palla.FRENO_IN_VOLO * Palle.PASSO_TRAIETTORIA
		p += v * Palle.PASSO_TRAIETTORIA
	var lontano := Vector2(p.x - via.x, p.z - via.z).length()
	_conta("il lancio arriva lontano almeno dieci metri in piano", lontano > 10.0, "%.1f m" % lontano)


func _la_dorata() -> void:
	var palle := _arena.palle()
	var tu := _arena.giocatore()
	var bot := _arena.avversari()[2]
	# Controprova: tre colori a testa, nessuno le ha tutte e sei.
	_arena._righe_di(tu)["segnate"] = [0, 1, 2]
	_arena._righe_di(bot)["segnate"] = [3, 4, 5]
	await _gol(bot, palle.palle()[3])
	_conta("con tre e tre la dorata non c'è", not palle.dorata().in_campo())
	# Il giocatore ne ha cinque e segna la sesta: arriva la dorata.
	_arena._righe_di(tu)["segnate"] = [0, 1, 2, 3, 4]
	await _gol(tu, palle.palle()[5])
	await process_frame
	_conta("chi segna la sesta fa entrare la dorata", palle.dorata().in_campo())
	# Segnata da chi non ha le sei: punti sì, fine no.
	var prima := _punti_di(bot)
	await _gol(bot, palle.dorata())
	_conta("la dorata segnata da chi non ha le sei vale 500 ma non chiude", _punti_di(bot) - prima == 500
			and not bool(_arena.get("_finita")), "%d punti" % (_punti_di(bot) - prima))
	await _attendi(func() -> bool: return palle.dorata().in_campo(), 4000)
	_conta("e torna in campo", palle.dorata().in_campo())
	await _gol(tu, palle.dorata())
	_conta("segnata da chi ha le sei chiude la partita", bool(_arena.get("_finita")))
	_conta("e sale il podio", tu.comandi._podio != null and tu.comandi._podio.visible)
	_arena.rigioca()
	await _entrano_tutti(5)
	await _il_via()
	for b in _arena.avversari():
		b.process_mode = Node.PROCESS_MODE_DISABLED
	_conta("RIGIOCA: si riparte da zero palle segnate e la dorata fuori",
			_arena.segnate_da(tu).is_empty() and not palle.dorata().in_campo())


func _le_palle_perse() -> void:
	var palle := _arena.palle()
	var blu := palle.palle()[0]
	await _attendi(func() -> bool: return blu.libera(), 4000)
	blu.global_position = Vector3(0, -20, 0)
	blu.linear_velocity = Vector3.ZERO
	palle._controllo = 0.01
	await _attendi(func() -> bool: return blu.global_position.y > -5.0, 3000)
	_conta("una palla persa torna da un cannone", blu.libera() and _vicino_a_un_cannone(blu.global_position),
			str(blu.global_position))


func _l_avversario_segna() -> void:
	var palle := _arena.palle()
	var tu := _arena.giocatore()
	tu.process_mode = Node.PROCESS_MODE_DISABLED
	tu.global_position = Vector3(0, -40, 0)
	var bot := _arena.avversari()[3]
	var gialla := palle.palle()[2]
	await _attendi(func() -> bool: return gialla.libera(), 4000)
	bot.global_position = palle.davanti_alla_porta(1, 9.0) + Vector3(0, 0.4, 0)
	await _ferma(gialla, bot.global_position)
	bot.process_mode = Node.PROCESS_MODE_INHERIT
	await _attendi(func() -> bool: return gialla.portata_da == bot, 2000)
	var prima := _punti_di(bot)
	await _attendi(func() -> bool: return _punti_di(bot) > prima, 15000)
	_conta("un avversario con una palla davanti alla porta la mette dentro", _punti_di(bot) - prima == 125,
			"%d punti" % (_punti_di(bot) - prima))
	bot.process_mode = Node.PROCESS_MODE_DISABLED
	tu.process_mode = Node.PROCESS_MODE_INHERIT
	_arena.chiudi_sfida()
	await process_frame
	_conta("chiusa la PALLA porte e palle spariscono", not palle.visible)


func _poi_lo_scontro_di_sempre() -> void:
	_arena.imposta_modalita(Modalita.SCONTRO)
	_arena.avvia_sfida()
	await _entrano_tutti(5)
	await _il_via()
	var in_campo := 0
	for palla in _arena.palle().palle():
		if palla.in_campo():
			in_campo += 1
	_conta("dopo la PALLA lo scontro è quello di sempre: niente palle, tre minuti",
			not _arena.palle().visible and in_campo == 0
			and _arena.tempo_rimasto() > Arena.DURATA_PARTITA - 3.0)
	_arena.chiudi_sfida()
	await process_frame


## Partite fra soli avversari, accelerate come P0: finiscono, e qualcuno segna.
func _partite_accelerate() -> void:
	Engine.physics_ticks_per_second = int(round(60.0 * ACCELERA))
	Engine.max_physics_steps_per_frame = 16
	Engine.time_scale = ACCELERA
	_arena.imposta_modalita(Modalita.PALLA)
	_arena.imposta_durata(TETTO)
	var tu := _arena.giocatore()
	var finite := 0
	var gol := 0
	for g in PARTITE:
		_arena.avvia_sfida()
		tu.process_mode = Node.PROCESS_MODE_DISABLED
		tu.global_position = Vector3(0, -40, 0)
		var scadenza := Time.get_ticks_msec() + int((TETTO / ACCELERA + 20.0) * 1000.0)
		while Time.get_ticks_msec() < scadenza and not bool(_arena.get("_finita")):
			await process_frame
		if bool(_arena.get("_finita")):
			finite += 1
		for riga in _arena.get("_concorrenti"):
			gol += int(riga.get("gol", 0))
		_arena.chiudi_sfida()
		tu.process_mode = Node.PROCESS_MODE_INHERIT
		await process_frame
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	Engine.max_physics_steps_per_frame = 8
	_conta("le partite accelerate fra soli avversari finiscono", finite == PARTITE, "%d su %d" % [finite, PARTITE])
	_conta("e gli avversari segnano (almeno quattro gol a partita)", gol >= 4 * PARTITE, "%d gol" % gol)


func _la_home() -> void:
	Modalita.scegli(Modalita.SCONTRO)
	var ingresso: Node = load("res://scenes/ingresso.tscn").instantiate()
	root.add_child(ingresso)
	current_scene = ingresso
	await process_frame
	var pulsanti: Array = ingresso.get("_modalita")
	var nomi: Array[String] = []
	for p in pulsanti:
		nomi.append((p as Button).text)
	_conta("sulla Home la riga dice SCONTRO, GARA e PALLA", nomi == ["SCONTRO", "GARA", "PALLA"], str(nomi))
	(pulsanti[2] as Button).pressed.emit()
	var scadenza := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < scadenza and ingresso.get("_arena_pronta") == null:
		await process_frame
	ingresso.call("_comincia")
	await process_frame
	var arena := current_scene
	_conta("toccata PALLA, GIOCA entra nella PALLA", arena is Arena and (arena as Arena).modalita() == Modalita.PALLA
			and (arena as Arena).palle().visible)
	if arena is Arena:
		(arena as Arena).chiudi_sfida()
		arena.queue_free()
	await process_frame


# ------------------------------------------------------------------ attrezzi

func _gol(chi: Node3D, palla: Palla) -> void:
	var palle := _arena.palle()
	await _attendi(func() -> bool: return palla.libera() or palla.portata_da == chi, 4000)
	if palla.portata_da != chi:
		palla.prendi(chi)
	palle.lancia(chi, palla, Vector3.ZERO)
	palla.global_position = palle.centro_della_porta(0)
	palla.linear_velocity = Vector3.ZERO
	await _attendi(func() -> bool: return not palla.in_campo(), 2000)
	await process_frame


func _punti_di(corpo: Node3D) -> int:
	for riga in _arena.get("_concorrenti"):
		if riga["corpo"] == corpo:
			return int(riga["punti"])
	return -1


func _punti_di_tutti() -> int:
	var tutti := 0
	for riga in _arena.get("_concorrenti"):
		tutti += int(riga["punti"])
	return tutti


func _vicino_a_un_cannone(dove: Vector3) -> bool:
	for c in _arena.palle().cannoni():
		if Vector2(dove.x - c.x, dove.z - c.z).length() < 7.0:
			return true
	return false


## Una palla ferma in un posto, libera.
func _ferma(palla: Palla, dove: Vector3) -> void:
	palla.in_campo_da(dove, Vector3.ZERO, null, -10.0)
	await physics_frame


func _porta(corpo: Node3D, piedi: Vector3) -> void:
	corpo.global_position = piedi + Vector3(0, 0.4, 0)
	if corpo is CharacterBody3D:
		(corpo as CharacterBody3D).velocity = Vector3.ZERO
	for i in 3:
		await physics_frame
		await process_frame


func _attendi(condizione: Callable, ms: int) -> void:
	var scadenza := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < scadenza and not bool(condizione.call()):
		await physics_frame


func _non_immune(corpo: Node3D) -> void:
	await _attendi(func() -> bool: return not bool(corpo.call("immune")), 4000)


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
	print("\nPALLA: %d prove, %d errori" % [_prove, _errori])
	quit(1 if _errori > 0 else 0)
