extends SceneTree

## Collaudo del poligono: la prova che la tappa 1 fa quello che promette.
##
## Non controlla la matematica (quella la controlla `prova_balistica.gd`):
## controlla il **giro completo**, cioè che da un punto in cui un bersaglio è
## invisibile si possa colpirlo di sponda, e che il colpo diventi punteggio.
## È il criterio di «fatto» del PLAN.md, tolto il pollice: quello si prova solo
## sul telefono.
##
## Uso:  godot --path . -s tools/prova_poligono.gd

var _errori := 0
var _prove := 0
var _punti := 0
var _muri_del_colpo := -1


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var poligono: Node = load("res://scenes/poligono.tscn").instantiate()
	root.add_child(poligono)
	await process_frame
	await process_frame
	var giocatore: Giocatore = poligono.call("giocatore")

	var nascosti := []
	for figlio in poligono.get_children():
		if figlio is Bersaglio:
			figlio.centrato.connect(_segna)
			nascosti.append(figlio)
	_conta("il poligono ha dei bersagli", nascosti.size() >= 5, str(nascosti.size()))

	# Il posto da cui si comincia a giocare.
	var partenza := Vector3(-9.0, 0.6, 6.5)
	giocatore.global_position = partenza
	giocatore.punta(20.0, -3.0)
	for i in 6:
		await process_frame

	# 1. Da lì, il bersaglio dietro il divisorio non si vede. Se si vedesse,
	#    l'angolo cieco non sarebbe cieco e la stanza non servirebbe a niente.
	var dietro := _piu_a_nord_est(nascosti)
	var occhi := giocatore.camera().global_position
	var spazio := root.get_world_3d().direct_space_state
	var domanda := PhysicsRayQueryParameters3D.create(occhi,
			dietro.global_position + Vector3(0, 0.9, 0), Strati.TIRO, [giocatore.get_rid()])
	var esito := spazio.intersect_ray(domanda)
	_conta("il bersaglio dietro l'angolo è coperto",
			not esito.is_empty() and esito["collider"] != dietro,
			"visto: %s" % [esito.get("collider")])

	# 2. Esiste una mira, da fermi lì, che lo prende di sponda. Si cerca come lo
	#    cercherebbe un giocatore: girandosi e guardando la linea.
	var mira := _cerca_la_sponda(giocatore, dietro)
	if not _conta("esiste un colpo di sponda che lo prende",
			mira != Vector2.INF, "nessuna direzione lo raggiunge"):
		_chiudi()
		return
	print("       mira trovata: giro %.1f°, pendenza %.1f°" % [mira.x, mira.y])

	# 3. Il colpo parte, vola e arriva: il punteggio deve muoversi da solo.
	giocatore.punta(mira.x, mira.y)
	await process_frame
	var previsti: int = Balistica.muri_usati(giocatore.previsione())
	_conta("il colpo sparerà almeno un rimbalzo", previsti >= 1, str(previsti))
	giocatore.spara()
	# Non si contano i fotogrammi: senza schermo il motore ne macina migliaia al
	# secondo, ognuno con un delta minuscolo, e il dardo resterebbe fermo a mezzo
	# metro dalla canna. Si aspetta che il dardo finisca la sua corsa.
	var dardo: Proiettile = null
	for figlio in poligono.get_children():
		if figlio is Proiettile:
			dardo = figlio
	if dardo != null:
		dardo.rimbalzato.connect(func(punto: Vector3, _n: Vector3, muri: int) -> void:
			print("       muro %d in %s" % [muri, punto]))
		dardo.spento.connect(func(punto: Vector3, muri: int) -> void:
			print("       dardo finito in %s dopo %d muri" % [punto, muri]))
	var giri := 0
	while giri < 200000 and _punti == 0 and is_instance_valid(dardo):
		giri += 1
		await process_frame
	_conta("il dardo ha colpito il bersaglio e ha fatto punti", _punti > 0, str(_punti))
	_conta("il punteggio è quello del rimbalzo, non del colpo diretto",
			_muri_del_colpo >= 1, "muri %d" % _muri_del_colpo)
	# 25 punti raddoppiati a ogni muro.
	var atteso := 25 * int(pow(2, maxi(_muri_del_colpo, 0)))
	_conta("i punti tornano col numero di muri", _punti == atteso,
			"%d invece di %d" % [_punti, atteso])

	_chiudi()


## Cerca una mira che, partendo da dove sta il giocatore, faccia arrivare il
## dardo sul bersaglio dopo almeno un muro. Prova un ventaglio di direzioni e usa
## la previsione del gioco, non un conto a parte: se la previsione mentisse, il
## collaudo mentirebbe con lei.
func _cerca_la_sponda(giocatore: Giocatore, bersaglio: Bersaglio) -> Vector2:
	var giro := -180.0
	while giro < 180.0:
		var pendenza := -12.0
		while pendenza <= 12.0:
			giocatore.punta(giro, pendenza)
			var tratti := giocatore.previsione()
			if not tratti.is_empty():
				var ultimo = tratti[tratti.size() - 1]
				if ultimo.bersaglio and ultimo.corpo == bersaglio and Balistica.muri_usati(tratti) >= 1:
					return Vector2(giro, pendenza)
			pendenza += 2.0
		giro += 1.0
	return Vector2.INF


func _piu_a_nord_est(bersagli: Array) -> Bersaglio:
	var scelto: Bersaglio = bersagli[0]
	for bersaglio in bersagli:
		var punto: Vector3 = bersaglio.global_position
		if punto.x > 3.0 and punto.z < -4.0:
			scelto = bersaglio
	return scelto


func _segna(punti: int, muri: int) -> void:
	_punti = punti
	_muri_del_colpo = muri


func _conta(nome: String, esito: bool, dettaglio: String = "") -> bool:
	_prove += 1
	if esito:
		print("  OK   ", nome)
	else:
		_errori += 1
		print("  NO   ", nome, "  →  ", dettaglio)
	return esito


func _chiudi() -> void:
	print("")
	if _errori == 0:
		print("POLIGONO: %d prove, tutte passate." % _prove)
		quit(0)
	else:
		print("POLIGONO: %d prove, %d FALLITE." % [_prove, _errori])
		quit(1)
