extends SceneTree

## **P0, la misura della PALLA** (tappa 11, blocco D2), prima di fissare i numeri.
##
## Il piano chiede: quanto ci vuole perché qualcuno chiuda le sette (le sei colorate e poi
## la dorata), e quanti punti fanno le palle e quanti i colpi. Da qui il limite di sicurezza
## (allo scadere vince chi ha più punti) e la conferma dei valori.
##
## Come G0 (`tools/misura_gara.gd`): partite fra i soli cinque avversari, il giocatore fermo
## sotto il pavimento, la fisica a `ACCELERA` × 60 passi e il tempo di gioco altrettanto,
## così ogni passo dura un sessantesimo di secondo come sul telefono.
##
## Uso:  godot --headless --path . -s tools/misura_palla.gd [-- <partite> <accelerazione> <livello> <tetto>]
##       (di serie 6 partite, ×4, livello 0 = facile, tetto 900 s)

const PARTITE := 6
const ACCELERA := 4.0
const TETTO := 900.0
const RAPPORTO := 60.0


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var partite := int(argomenti[0]) if argomenti.size() > 0 else PARTITE
	var accelera := float(argomenti[1]) if argomenti.size() > 1 else ACCELERA
	var livello := int(argomenti[2]) if argomenti.size() > 2 else 0
	var tetto := float(argomenti[3]) if argomenti.size() > 3 else TETTO
	Engine.physics_ticks_per_second = int(round(60.0 * accelera))
	Engine.max_physics_steps_per_frame = 16
	Engine.time_scale = accelera

	var arena: Arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	arena.imposta_modalita(Modalita.PALLA)
	arena.imposta_durata(tetto)
	arena.set("_livello", livello)
	var giocatore := arena.giocatore()
	print("P0: %d partite fra cinque avversari, livello %s, ×%.0f, tetto %.0f s" % [partite,
			Avversario.TARATURE[livello]["nome"], accelera, tetto])

	var chiuse := 0
	var durate: Array[float] = []
	var palle_tot := 0
	var colpi_tot := 0
	for g in partite:
		arena.avvia_sfida()
		giocatore.process_mode = Node.PROCESS_MODE_DISABLED
		giocatore.global_position = Vector3(0, -40, 0)
		var inizio := Time.get_ticks_msec()
		var scadenza := inizio + int((tetto / accelera + 30.0) * 1000.0)
		var prossimo := RAPPORTO
		while Time.get_ticks_msec() < scadenza and not bool(arena.get("_finita")):
			await process_frame
			var passati := arena.durata_giocata()
			if passati >= prossimo:
				prossimo += RAPPORTO
				print("     %4.0f s  %s" % [passati, _stato(arena)])
		var durata := arena.durata_giocata()
		var chiusa := arena.chiusa_dalla_dorata()
		if chiusa:
			chiuse += 1
			durate.append(durata)
		var gol := 0
		var punti_palle := 0
		for riga in arena.get("_concorrenti"):
			gol += int(riga.get("gol", 0))
			punti_palle += int(riga.get("punti_palle", 0))
		var punti_colpi := 0
		for riga in arena.get("_concorrenti"):
			punti_colpi += int(riga["punti"]) - int(riga.get("punti_palle", 0))
		palle_tot += punti_palle
		colpi_tot += punti_colpi
		print("  partita %d: %5.0f s %s · %d gol · punti dalle palle %d, dai colpi e dai bersagli %d · %s  (%.0f s veri)" % [
				g + 1, durata, "CHIUSA DALLA DORATA" if chiusa else "a tempo", gol, punti_palle, punti_colpi,
				_stato(arena), (Time.get_ticks_msec() - inizio) / 1000.0])
		arena.chiudi_sfida()
		giocatore.process_mode = Node.PROCESS_MODE_INHERIT
		await process_frame

	print("")
	print("chiuse dalla dorata: %d su %d" % [chiuse, partite])
	if not durate.is_empty():
		durate.sort()
		print("durata delle chiuse: più corta %.0f s, mediana %.0f s, più lunga %.0f s" % [durate[0],
				durate[durate.size() / 2], durate[-1]])
	print("punti in tutto: dalle palle %d, dai colpi e dai bersagli %d" % [palle_tot, colpi_tot])
	quit(0)


func _stato(arena: Arena) -> String:
	var pezzi: Array[String] = []
	for riga in arena.classifica():
		for r in arena.get("_concorrenti"):
			if String(r["nome"]) == String(riga["nome"]):
				pezzi.append("%s %d (%d/6)" % [riga["nome"], int(riga["punti"]), (r["segnate"] as Array).size()])
	return "  ".join(pezzi)
