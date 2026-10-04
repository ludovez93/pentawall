extends SceneTree

## Collaudo della schermata d'ingresso (tappa 7, blocco C).
##
## È **la scena principale**: se si rompe, il gioco non si apre e non lo dice
## nessuno finché non si tocca il link dal telefono. I controlli sono pochi e
## grossi: che si apra, che ci sia GIOCA, che il gesto nascosto apra il banco di
## prova, che sul palco ci sia il personaggio e che suoni la musica.
##
## Uso:  godot --headless --path . -s tools/prova_ingresso.gd

var _errori := 0
var _prove := 0


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	_conta("la scena principale del progetto è l'ingresso",
			String(ProjectSettings.get_setting("application/run/main_scene"))
			== "res://scenes/ingresso.tscn",
			String(ProjectSettings.get_setting("application/run/main_scene")))

	var ingresso: Node = load("res://scenes/ingresso.tscn").instantiate()
	root.add_child(ingresso)
	await process_frame
	await process_frame

	var tasti := _pulsanti(ingresso)
	_conta("c'è un pulsante GIOCA", tasti.has("GIOCA"), str(tasti.keys()))
	_conta("e il gioco non parte in partita finché non lo si tocca",
			not Arena.modo_partita)

	# **Il gesto nascosto**: cinque tocchi sulla riga della versione. Prima non si
	# vede niente — i banchi di prova servono a noi, non a chi gioca.
	_conta("il banco di prova è chiuso", not bool(ingresso.call("banco_aperto")))
	for i in Ingresso.TOCCHI_PER_APRIRE - 1:
		ingresso.call("_tocco")
	_conta("quattro tocchi non bastano", not bool(ingresso.call("banco_aperto")))
	ingresso.call("_tocco")
	_conta("al quinto si apre", bool(ingresso.call("banco_aperto")))
	await process_frame
	tasti = _pulsanti(ingresso)
	for dove in ["ARENA LIBERA", "POLIGONO", "ANGOLO"]:
		_conta("e porta a «%s»" % dove, tasti.has(dove))

	# Il personaggio sul palco (tappa 8, blocco I): il tuo corpo vero, col blaster.
	var corpo: Variant = ingresso.call("personaggio")
	_conta("sul palco c'è il tuo personaggio", corpo is Corpo and (corpo as Corpo).chi == "TU")
	_conta("e c'è la musica d'ingresso", Suoni.brano() == "musica_ingresso", Suoni.brano())
	_conta("il dardo parte a 24 m/s", is_equal_approx(Proiettile.velocita, Proiettile.VELOCITA_VELOCE),
			"%.0f m/s" % Proiettile.velocita)

	await _l_arena_pronta(ingresso)
	await _gioca_prima_del_tempo()

	print("\nINGRESSO: %d prove, %s" %
			[_prove, "tutte passate." if _errori == 0 else "%d ERRORI." % _errori])
	quit(1 if _errori > 0 else 0)


## **L'arena che si prepara dietro l'ingresso** (tappa 9). Dal telefono, premuto
## GIOCA, un fotogramma durava 15,5 secondi; adesso l'arena deve essere già lì —
## costruita, scaldata, ferma — e GIOCA la porta sullo schermo e basta.
func _l_arena_pronta(ingresso: Node) -> void:
	var inizio := Time.get_ticks_msec()
	while Time.get_ticks_msec() - inizio < 60000 and ingresso.get("_arena_pronta") == null:
		await process_frame
	var pronta: Node = ingresso.get("_arena_pronta")
	_conta("l'arena si prepara dietro l'ingresso", pronta != null,
			"dopo %.1f s non è pronta" % ((Time.get_ticks_msec() - inizio) / 1000.0))
	if pronta == null:
		return
	print("       (pronta in %.1f s, senza schermo)" % ((Time.get_ticks_msec() - inizio) / 1000.0))
	_conta("ferma finché non si entra", pronta.process_mode == Node.PROCESS_MODE_DISABLED)
	_conta("la vetrina, finito il riscaldamento, non disegna più",
			(ingresso.get("_vetrina") as SubViewport).render_target_update_mode
			== SubViewport.UPDATE_DISABLED)
	# Il riscaldamento spegne tutto e riaccende un gruppo alla volta: alla fine
	# ogni cosa deve tornare com'era. Un muro rimasto spento sarebbe un buco.
	var spenti := 0
	for gruppo in [Muratura.GRUPPO_MURI, Muratura.GRUPPO_PAVIMENTI]:
		for corpo in pronta.get_tree().get_nodes_in_group(gruppo):
			if not pronta.is_ancestor_of(corpo):
				continue
			for figlio in corpo.get_children():
				if figlio is GeometryInstance3D and not (figlio as GeometryInstance3D).visible:
					spenti += 1
	_conta("dopo il riscaldamento muri e pavimenti sono tutti accesi", spenti == 0,
			"%d spenti" % spenti)
	var giocatore := pronta.call("giocatore") as Giocatore
	_conta("e anche il tuo corpo", giocatore.corpo().is_visible_in_tree())
	_conta("la scorta tiene in vita gli shader", Scorta.quanti() >= 10, str(Scorta.quanti()))

	ingresso.call("_comincia")
	await process_frame
	await process_frame
	_conta("premuto GIOCA, si entra nell'arena già pronta", current_scene == pronta,
			str(current_scene))
	_conta("che è sullo schermo, non più nella vetrina", pronta.get_parent() == root)
	_conta("e la partita parte col fischio", float(pronta.call("conto_alla_rovescia")) > 0.0)
	_conta("con la musica della partita", Suoni.brano() == "musica_partita", Suoni.brano())
	_conta("la camera è quella di chi gioca", root.get_camera_3d() == giocatore.camera())
	_conta("e l'ingresso se n'è andato", not is_instance_valid(ingresso))
	pronta.queue_free()
	await process_frame


## Premuto GIOCA **prima** che l'arena sia pronta: si aspetta, e si entra appena lo è.
func _gioca_prima_del_tempo() -> void:
	var ingresso: Node = load("res://scenes/ingresso.tscn").instantiate()
	root.add_child(ingresso)
	await process_frame
	ingresso.call("_comincia")
	await process_frame
	_conta("premuto GIOCA prima del tempo, si resta all'ingresso ad aspettare",
			is_instance_valid(ingresso) and not (current_scene is Arena))
	var inizio := Time.get_ticks_msec()
	while Time.get_ticks_msec() - inizio < 60000 and not (current_scene is Arena):
		await process_frame
	_conta("e si entra appena l'arena è pronta", current_scene is Arena)
	if current_scene is Arena:
		current_scene.queue_free()
	await process_frame


## I pulsanti della scena, per testo: è così che si chiamano da fuori senza
## dipendere da come sono impilati dentro.
func _pulsanti(nodo: Node) -> Dictionary:
	var trovati := {}
	for figlio in nodo.get_children():
		if figlio is Button:
			trovati[(figlio as Button).text] = figlio
		if figlio.get_child_count() > 0:
			trovati.merge(_pulsanti(figlio))
	return trovati


func _conta(cosa: String, esito: bool, dettaglio := "") -> void:
	_prove += 1
	if esito:
		print("  ok   ", cosa)
	else:
		_errori += 1
		print("  NO   ", cosa, ("   (%s)" % dettaglio) if dettaglio != "" else "")
