extends SceneTree

## Attrezzo di lavorazione: fotografa **le schermate del blocco C** alle misure
## del telefono — l'ingresso, il fischio d'inizio, la partita e il podio.
##
## Serve perché l'interfaccia si guarda dove sta il pollice, non sul PC: l'iPhone
## in orizzontale dà a Godot un canvas di 854 × 390, e quello che sul monitor
## respira, là finisce addosso a un dito (`LEARNED.md` § 36).
##
## Vuole la finestra: senza schermo il fotogramma non c'è e resta appeso.
##   godot --path . --resolution 854x390 -s tools/scatti_partita.gd

const CARTELLA := "res://scatti"


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	print("finestra: ", DisplayServer.window_get_size())

	# 1. L'ingresso, come lo trova chi apre il link.
	Arena.modo_partita = false
	var ingresso: Node = load("res://scenes/ingresso.tscn").instantiate()
	root.add_child(ingresso)
	await _riposa(40)
	await _scatta("60-ingresso.png")

	# 2. Lo stesso, col banco di prova aperto dai cinque tocchi sulla versione.
	for i in 5:
		ingresso.call("_tocco")
	await _riposa(10)
	await _scatta("61-ingresso-banco.png")
	ingresso.queue_free()
	await _riposa(5)

	# 3. La partita che parte: il fischio d'inizio, con i corpi che entrano.
	Arena.modo_partita = true
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await _riposa(60)
	var giocatore: Giocatore = arena.call("giocatore")
	giocatore.punta(0.0, -4.0)
	await _riposa(20)
	await _scatta("62-fischio-inizio.png")

	# 4. La partita in corso: cronometro, posizione, punti, classifica. Con
	# qualche punto in giro, o la classifica sarebbe sei righe di zeri.
	var scadenza := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < scadenza and float(arena.call("conto_alla_rovescia")) > 0.0:
		await process_frame
	var avversari: Array = arena.call("avversari")
	for i in avversari.size():
		for colpo in i:
			(avversari[i] as Avversario).call("incassa", 0, giocatore)
			await _riposa(55)
	await _riposa(20)
	await _scatta("63-partita.png")

	# 5. Il podio: la fine della partita, e RIGIOCA a un tocco.
	arena.call("imposta_durata", 2.0)
	arena.call("avvia_sfida")
	scadenza = Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < scadenza and float(arena.call("tempo_rimasto")) > 0.0:
		await process_frame
		if float(arena.call("conto_alla_rovescia")) <= 0.0 \
				and int((arena.call("punteggi") as Array)[0]) == 0:
			var vittime: Array = arena.call("avversari")
			if not vittime.is_empty():
				(vittime[0] as Avversario).call("incassa", 2, giocatore)
	await _riposa(30)
	await _scatta("64-podio.png")

	print("fatto.")
	quit()


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var immagine := root.get_texture().get_image()
	immagine.save_png(CARTELLA + "/" + nome)
	print("  ", nome, "  ", immagine.get_width(), "x", immagine.get_height())
