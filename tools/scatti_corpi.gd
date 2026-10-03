extends SceneTree

## Attrezzo di lavorazione: fotografa **i sei corpi veri** dentro l'arena, alle
## misure del telefono (tappa 8, blocco D).
##
## Quattro scatti: i cinque avversari fermi in fila davanti a te (chi è chi, a che
## distanza si legge), uno che ti corre addosso, uno che corre di lato mirandoti
## (il busto sulla mira e le gambe sulla corsa), e te visto da vicino.
##
## Vuole la finestra: senza schermo il fotogramma non c'è e resta appeso.
##   godot --path . --resolution 854x390 -s tools/scatti_corpi.gd

const CARTELLA := "res://scatti"


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	Arena.modo_partita = false
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await _riposa(30)
	var giocatore: Giocatore = arena.call("giocatore")
	arena.call("avvia_sfida")
	var scadenza := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < scadenza and float(arena.call("conto_alla_rovescia")) > 0.0:
		await process_frame
	await _riposa(10)
	# La partita si ferma qui: nessuno sceglie più chi attaccare, nessuno fa punti e
	# nessuno ricompare — gli scatti vogliono i corpi dove li si mette.
	arena.set("_finita", true)
	for bot in arena.call("avversari"):
		(bot as Avversario).bersaglio = null

	# Il giocatore nel catino (quota −2), a sud del box centrale, che guarda verso
	# nord: davanti ha dieci metri di moquette libera prima del box.
	var centro := Vector3(0.0, -1.6, 9.5)
	giocatore.global_position = centro
	giocatore.velocity = Vector3.ZERO
	giocatore.punta(0.0, -6.0)
	var avversari: Array = arena.call("avversari")
	for i in avversari.size():
		var bot := avversari[i] as Avversario
		bot.bersaglio = null
		bot.caccia = false
		bot.global_position = centro + Vector3(-5.0 + 2.5 * i, 0.0, -5.0 - 0.6 * absf(i - 2.0))
		bot.velocity = Vector3.ZERO
		bot.rotation.y = 0.0
	await _riposa(40)
	for bot in avversari:
		var b := bot as Avversario
		print("  %s y=%.2f a_terra=%s aria=%.2f" % [b.personaggio, b.global_position.y,
				b.is_on_floor(), float(b.get("_corpo").get("_in_aria"))])
	await _scatta("80-corpi-in-fila.png")

	# Uno che ti corre addosso: la caccia spenta vuol dire «sa dove sei».
	var corridore := avversari[2] as Avversario
	corridore.global_position = centro + Vector3(8.0, 0.0, -8.0)
	corridore.bersaglio = giocatore
	await _aspetta(0.55)
	await _scatta("81-corpo-che-corre.png")
	corridore.bersaglio = null

	# Di lato: lo si spinge a mano verso destra mentre guarda te. È il caso del
	# busto che mira mentre le gambe corrono.
	var laterale := avversari[0] as Avversario
	laterale.global_position = centro + Vector3(-6.0, 0.0, -5.5)
	laterale.bersaglio = giocatore
	var tempo := 0.0
	while tempo < 0.6:
		laterale.velocity = Vector3(7.0, laterale.velocity.y, 0.0)
		await physics_frame
		tempo += 1.0 / Engine.physics_ticks_per_second
	await _scatta("82-corpo-di-lato.png")
	laterale.bersaglio = null

	# Da vicino: un avversario a tre metri e mezzo, fermo, in prima persona.
	for i in avversari.size():
		(avversari[i] as Avversario).global_position = centro + Vector3(-30.0 + i, 0.0, 30.0)
	var vicino := avversari[1] as Avversario
	vicino.global_position = centro + Vector3(0.6, 0.0, -3.6)
	vicino.rotation.y = 0.0
	giocatore.cambia_camera()
	await _riposa(30)
	await _scatta("83-corpo-da-vicino.png")
	giocatore.cambia_camera()

	# Te, da vicino, visto di fianco: la camera si avvicina girando attorno.
	giocatore.punta(70.0, -2.0)
	await _riposa(30)
	await _scatta("84-tu-di-fianco.png")

	print("fatto.")
	quit()


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame


func _aspetta(secondi: float) -> void:
	var fine := Time.get_ticks_msec() + int(secondi * 1000.0)
	while Time.get_ticks_msec() < fine:
		await process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var immagine := root.get_texture().get_image()
	immagine.save_png(CARTELLA + "/" + nome)
	print("  ", nome, "  ", immagine.get_width(), "x", immagine.get_height())
