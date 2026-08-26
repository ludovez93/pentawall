extends SceneTree

## Attrezzo di lavorazione: apre il poligono e misura quanto ci mette a disegnare
## un fotogramma, senza sincronismo verticale (che altrimenti tiene tutto a 60 e
## nasconde il margine vero). Riporta media, migliore e peggiore.

func _initialize() -> void:
	_lavora()

func _lavora() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# Dalla tappa 3 le scene sono due: con `-- angolo` si misura l'arena vera.
	# Una misura senza il suo paragone non dice niente (LEARNED.md 20), e il
	# paragone di questa e' il poligono sulla stessa macchina.
	var quale := "poligono"
	for scena in ["angolo", "arena"]:
		if OS.get_cmdline_user_args().has(scena):
			quale = scena
	var poligono: Node = load("res://scenes/%s.tscn" % quale).instantiate()
	root.add_child(poligono)
	var giocatore = null
	for i in 40:
		await process_frame
	giocatore = poligono.call("giocatore")
	# Con la sfida accesa: il caso peggiore e' quello vero, non la stanza vuota.
	# L'avversario ricalcola la traiettoria di ogni dardo in volo venti volte al
	# secondo, ed e' esattamente il conto che va misurato.
	# Con `-- senza-sfida` si misura la stanza da sola: e' il termine di paragone,
	# e un numero senza paragone non dice niente.
	var con_sfida := not OS.get_cmdline_user_args().has("senza-sfida") 			and poligono.has_method("avvia_sfida")
	if con_sfida:
		poligono.call("avvia_sfida")
		for i in 20:
			await process_frame

	var misure := []
	var disegno := []
	var fisica := []
	var dardi := []
	var scatti := 0
	# I fotogrammi al secondo veri: il tempo che si passa nel codice non dice
	# quanto ci mette la scheda video a disegnare, ed e' li' che stava il crollo.
	var partenza := Time.get_ticks_usec()
	var contati := 0
	for giro in 400:
		await process_frame
		# Ci si guarda intorno mentre si misura: una scena ferma misura la scena
		# piu' facile, non quella vera.
		giocatore.gira(0.012, 0.0)
		if giro % 40 == 0:
			giocatore.spara()
			scatti += 1
		if giro > 60:
			contati += 1
			misure.append(Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
			disegno.append(Performance.get_monitor(Performance.TIME_PROCESS))
			fisica.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
			dardi.append(root.get_tree().get_nodes_in_group(Proiettile.GRUPPO).size())

	misure.sort()
	var somma := 0.0
	for m in misure:
		somma += m
	var media: float = somma / float(misure.size())
	var peggiore: float = misure[misure.size() - 1]
	var mediano: float = misure[misure.size() / 2]
	var durata := float(Time.get_ticks_usec() - partenza) / 1000000.0
	print("scheda: ", RenderingServer.get_video_adapter_name())
	print("scena: ", quale)
	print("sfida: ", "accesa" if con_sfida else "spenta")
	print("fotogrammi misurati: ", misure.size(), " con ", scatti, " colpi sparati")
	print("logica di gioco per fotogramma — media %.2f ms, mediana %.2f ms, peggiore %.2f ms" % [media * 1000.0, mediano * 1000.0, peggiore * 1000.0])
	print("  di cui disegno %.2f ms, fisica %.2f ms (mediane)" % [
		_mediana(disegno) * 1000.0, _mediana(fisica) * 1000.0])
	print("dardi in volo: mediana %d, massimo %d" % [_mediana(dardi), dardi.max()])
	print("fotogrammi al secondo nell'ultimo tratto: ", Engine.get_frames_per_second())
	print("fotogrammi al secondo sull'intero giro: %.1f  (%d fotogrammi in %.1f s)" % [
		float(contati) / maxf(durata, 0.001), contati, durata])
	quit(0)


func _mediana(valori: Array) -> float:
	var copia := valori.duplicate()
	copia.sort()
	return float(copia[copia.size() / 2])
