extends SceneTree

## Collaudo dell'avversario: la prova che la tappa 2 fa quello che promette.
##
## Le tre capacità devono essere **sempre accese** — anticipa, schiva, e schiva
## anche i rimbalzi — e la differenza fra facile e duro deve stare solo
## nell'esecuzione (MIGLIORIE.md § 1). Qui si verifica esattamente questo, più il
## fatto che il bot non attraversi i muri e che una partita si giochi davvero.
##
## Uso:  godot --path . -s tools/prova_avversario.gd
##
## Sui tempi: il corpo dell'avversario vive nel passo fisico, che scorre col
## tempo dell'orologio, mentre il dardo vive nel disegno, che senza schermo ne
## macina migliaia al secondo (LEARNED.md 17). Perciò qui non si contano mai i
## fotogrammi: si aspettano **secondi veri**, o un esito.

const PARTENZA := Vector3(-9.0, 0.6, 6.5)

## Dove si mette l'avversario per le prove di tiro, e da che parte gli si spara.
## Il corridoio davanti a lui dev'essere **libero e dentro la stanza**: sparando
## da un punto oltre la parete il dardo muore nel muro, e «il colpo l'ha mancato»
## diventa vero per il motivo sbagliato.
const POSTO_PROVA := Vector3(0.0, 0.2, -6.0)
const DA_DOVE := Vector3(0, 0, 1)

var _errori := 0
var _prove := 0
var _poligono: Node
var _giocatore: Giocatore


func _initialize() -> void:
	# Seme fisso: la schivata sceglie il lato con un tiro di dado, e un collaudo
	# che cambia esito a ogni giro non serve a niente.
	seed(20260826)
	_lavora()


func _lavora() -> void:
	_poligono = load("res://scenes/poligono.tscn").instantiate()
	root.add_child(_poligono)
	await _riposa(0.2)
	_giocatore = _poligono.call("giocatore")
	_giocatore.global_position = PARTENZA

	await _prova_anticipo()
	await _prova_schivata_diretta()
	await _prova_schivata_di_rimbalzo()
	await _prova_livelli()
	await _prova_partita()

	_chiudi()


## 1. Anticipa: mira **davanti** al bersaglio, di quanto basta al tempo di volo.
## Se questa parte è spenta, il gioco insegna che l'anticipo non serve — che è
## l'errore che è costato la fama all'originale.
func _prova_anticipo() -> void:
	print("\n— anticipo —")
	var bot := Avversario.crea(_poligono, Vector3(-2.0, 0.2, 8.0), 2)
	var mobile := Bersaglio.crea(_poligono, Vector3(-9.0, 0, -1.0), Vector3(7.0, 0, -1.0), 4.0)
	bot.bersaglio = mobile
	await _riposa(1.0)

	var centro := mobile.global_position + Vector3(0, Avversario.ALTEZZA_PETTO, 0)
	var mira := bot.punto_di_mira()
	var scarto := (mira - centro)
	scarto.y = 0.0
	var volo := bot.global_position.distance_to(centro) / Proiettile.VELOCITA
	var atteso := 4.0 * volo
	_conta("mira davanti al bersaglio, non addosso", scarto.length() > 0.6 * atteso,
			"scarto %.2f m, atteso ~%.2f m" % [scarto.length(), atteso])
	_conta("l'anticipo non è esagerato", scarto.length() < 1.8 * atteso,
			"scarto %.2f m, atteso ~%.2f m" % [scarto.length(), atteso])

	# E la prova che conta: con un bersaglio che si muove, lo prende. Mirando dove
	# sta adesso lo mancherebbe di due metri buoni.
	var preso := [false]
	mobile.centrato.connect(func(_p: int, _m: int) -> void: preso[0] = true)
	await _aspetta_che(func() -> bool: return preso[0], 8.0)
	_conta("con l'anticipo centra un bersaglio in movimento", preso[0])

	bot.queue_free()
	mobile.queue_free()
	await _riposa(0.2)


## 2. Schiva un colpo diretto — e la controprova: se il colpo arriva prima del suo
## tempo di reazione, lo incassa. Senza la controprova, «il dardo non l'ha preso»
## potrebbe voler dire soltanto che avevo mirato male.
func _prova_schivata_diretta() -> void:
	print("\n— schivata, colpo diretto —")
	var bot := Avversario.crea(_poligono, POSTO_PROVA, 2)
	await _riposa(0.3)

	var esito := await _sparagli(bot, 10.0)
	_conta("il colpo di prova ha via libera", bool(esito["via_libera"]))
	_conta("si è spostato per schivare", float(esito["spostamento"]) > 0.5,
			"%.2f m" % float(esito["spostamento"]))
	_conta("il colpo diretto lo manca", not bool(esito["colpito"]))

	# Controprova: da due metri il dardo arriva in un decimo di secondo, meno del
	# tempo di reazione anche al livello duro. Deve prenderlo — senza questa, «il
	# colpo l'ha mancato» potrebbe voler dire soltanto che avevo mirato male.
	await _rimettilo_a_posto(bot)
	var vicino := await _sparagli(bot, 2.0)
	_conta("da due metri non fa in tempo: lo prende", bool(vicino["colpito"]))

	bot.queue_free()
	await _riposa(0.2)


## 3. Il pezzo che il 1999 non poteva avere: schiva anche quello che gli arriva
## **di sponda, da dietro l'angolo**. Se fallisce questa, il rimbalzo resta una
## bravura buona solo contro i sassi.
func _prova_schivata_di_rimbalzo() -> void:
	print("\n— schivata, colpo di sponda —")
	var posto := Vector3(6.0, 0.2, -8.0)
	var bot := Avversario.crea(_poligono, posto, 2)
	await _riposa(0.3)

	_giocatore.global_position = PARTENZA
	var occhi := _giocatore.camera().global_position
	var spazio := root.get_world_3d().direct_space_state
	var esclusi: Array[RID] = [_giocatore.get_rid()]
	var domanda := PhysicsRayQueryParameters3D.create(occhi,
			bot.global_position + Vector3(0, Avversario.ALTEZZA_PETTO, 0), Strati.TIRO, esclusi)
	var vista := spazio.intersect_ray(domanda)
	_conta("da dove si parte, l'avversario è coperto",
			not vista.is_empty() and vista["collider"] != bot, "visto: %s" % [vista.get("collider")])

	var mira := _cerca_la_sponda(bot)
	if not _conta("esiste un colpo di sponda che lo raggiunge", mira != Vector2.INF):
		bot.queue_free()
		return
	print("       mira trovata: giro %.1f°, pendenza %.1f°" % [mira.x, mira.y])

	var prima := bot.global_position
	var addosso := [false]
	_giocatore.punta(mira.x, mira.y)
	await _riposa(0.05)
	_giocatore.spara()
	var dardo := _ultimo_dardo()
	var id := 0
	var id_bot := bot.get_instance_id()
	if dardo != null:
		id = dardo.get_instance_id()
		dardo.colpito.connect(func(corpo: Object, _p: Vector3, _n: Vector3, _m: int) -> void:
			if corpo != null and corpo.get_instance_id() == id_bot:
				addosso[0] = true)
	var schivato := [false]
	await _aspetta_che(func() -> bool:
		if bot.in_schivata():
			schivato[0] = true
		return schivato[0] or not is_instance_id_valid(id), 4.0)

	_conta("schiva un colpo che gli arriva dietro l'angolo", schivato[0])
	await _aspetta_che(func() -> bool: return not is_instance_id_valid(id), 3.0)
	_conta("e quel colpo lo manca", not addosso[0],
			"spostato di %.2f m" % prima.distance_to(bot.global_position))

	bot.queue_free()
	await _riposa(0.2)


## 4. Facile e duro sanno fare le stesse cose: cambia solo quando reagiscono.
## La prova è che al livello facile lo si colpisce, al livello duro no — a parità
## di colpo, sparato dallo stesso posto.
func _prova_livelli() -> void:
	print("\n— facile contro duro —")
	var colpi := 5
	var presi := []
	for livello in [0, 2]:
		var bot := Avversario.crea(_poligono, POSTO_PROVA, livello)
		await _riposa(0.3)
		var conto := 0
		for giro in colpi:
			await _rimettilo_a_posto(bot)
			# Otto metri: il dardo arriva in quattro decimi di secondo. Chi
			# reagisce in dodici centesimi si sposta in tempo, chi ne impiega
			# quarantacinque no — ed è tutta lì la differenza fra i due livelli.
			var esito := await _sparagli(bot, 8.0)
			if not bool(esito["via_libera"]):
				_conta("il colpo di prova ha via libera", false, "livello %d" % livello)
			if bool(esito["colpito"]):
				conto += 1
		presi.append(conto)
		print("       %s: colpito %d volte su %d" % [bot.nome_livello(), conto, colpi])
		bot.queue_free()
		await _riposa(0.2)

	_conta("al livello facile si fa colpire", int(presi[0]) >= colpi - 1,
			"%d su %d" % [int(presi[0]), colpi])
	_conta("al livello duro schiva quegli stessi colpi", int(presi[1]) == 0,
			"%d su %d" % [int(presi[1]), colpi])


## 5. La partita: il giro completo, com'è quando si gioca. Il bot deve inseguire,
## sparare e fare punti — e deve restare dentro la stanza.
func _prova_partita() -> void:
	print("\n— la partita —")
	_poligono.call("avvia_sfida")
	await _riposa(0.2)
	var bot: Avversario = _poligono.call("avversario")
	if not _conta("la sfida mette in campo un avversario", bot != null):
		return
	for figlio in _poligono.get_children():
		if figlio is Bersaglio:
			_conta("i bersagli si fanno da parte", figlio.collision_layer == 0,
					"strato %d" % figlio.collision_layer)
			break

	var punti_prima: Array = _poligono.call("punteggi")
	await _aspetta_che(func() -> bool:
		var adesso: Array = _poligono.call("punteggi")
		return int(adesso[1]) > 0 and bot.global_position.distance_to(_giocatore.global_position) < 20.0,
		12.0)

	var punti: Array = _poligono.call("punteggi")
	_conta("l'avversario insegue e colpisce chi sta fermo", int(punti[1]) > int(punti_prima[1]),
			"punti suoi: %d" % int(punti[1]))
	var dove := bot.global_position
	var dentro := absf(dove.x) < 15.0 and absf(dove.z) < 10.0 and dove.y > -0.5 and dove.y < 8.0
	_conta("non attraversa i muri e non esce dalla stanza", dentro, str(dove))

	_poligono.call("chiudi_sfida")
	await _riposa(0.2)
	var tornati := true
	for figlio in _poligono.get_children():
		if figlio is Bersaglio and figlio.collision_layer == 0:
			tornati = false
	_conta("chiusa la sfida, il poligono torna quello di prima", tornati)


## Lo rimette al suo posto e aspetta che sia **fermo davvero**: un avversario
## ancora lanciato nella schivata di prima si porta via il colpo seguente, e la
## prova misurerebbe l'inerzia invece della reazione. Si aspetta la quiete, non
## un tempo (LEARNED.md 17).
func _rimettilo_a_posto(bot: Avversario) -> void:
	bot.global_position = POSTO_PROVA
	bot.velocity = Vector3.ZERO
	await _aspetta_che(func() -> bool:
		return not bot.in_schivata() and bot.velocity.length() < 0.4 and bot.is_on_floor(), 3.0)
	await _riposa(0.1)


## Gli spara addosso un dardo da una certa distanza, mirando al petto, e dice se
## l'ha preso e di quanto si è spostato. Il colpo lo tira il collaudo, non
## l'avversario: così l'esito non dipende dall'errore di mira di nessuno.
func _sparagli(bot: Avversario, distanza: float) -> Dictionary:
	var centro := bot.global_position + Vector3(0, Avversario.ALTEZZA_PETTO, 0)
	var da := centro + DA_DOVE.normalized() * distanza
	var prima := bot.global_position

	# Prima di sparare si controlla di avere davvero il bersaglio davanti: un
	# colpo che parte dentro un muro «manca» sempre, e sembrerebbe una schivata.
	var domanda := PhysicsRayQueryParameters3D.create(da, centro, Strati.TIRO)
	var vista := root.get_world_3d().direct_space_state.intersect_ray(domanda)
	var libera: bool = not vista.is_empty() and vista["collider"] == bot

	var dardo := Proiettile.lancia(_poligono, da, (centro - da).normalized())
	var id := dardo.get_instance_id()
	# Dentro le funzioni al volo si porta l'identificativo, mai l'oggetto: un
	# dardo può sopravvivere a chi lo stava osservando, e una funzione che si
	# porta dietro un morto fa errore appena viene chiamata.
	var id_bot := bot.get_instance_id()
	var addosso := [false]
	dardo.colpito.connect(func(corpo: Object, _p: Vector3, _n: Vector3, _m: int) -> void:
		if corpo != null and corpo.get_instance_id() == id_bot:
			addosso[0] = true)
	# Si aspetta l'esito del dardo, non un numero di fotogrammi: il tetto è solo
	# una rete di sicurezza. E si guarda l'identificativo, non l'oggetto: una
	# funzione che si porta dietro un dardo morto fa errore appena lo tocca.
	await _aspetta_che(func() -> bool: return not is_instance_id_valid(id), 4.0)
	return {
		"colpito": addosso[0],
		"spostamento": prima.distance_to(bot.global_position),
		"via_libera": libera,
	}


## Cerca una mira che, dal punto di partenza, faccia arrivare il dardo addosso
## all'avversario dopo almeno un muro. Usa la previsione del gioco, non un conto
## a parte: se la previsione mentisse, mentirebbe anche il collaudo.
func _cerca_la_sponda(bot: Avversario) -> Vector2:
	var giro := -180.0
	while giro < 180.0:
		var pendenza := -10.0
		while pendenza <= 10.0:
			_giocatore.punta(giro, pendenza)
			var tratti := _giocatore.previsione()
			if not tratti.is_empty():
				var ultimo = tratti[tratti.size() - 1]
				if ultimo.bersaglio and ultimo.corpo == bot and Balistica.muri_usati(tratti) >= 1:
					return Vector2(giro, pendenza)
			pendenza += 2.0
		giro += 1.0
	return Vector2.INF


func _ultimo_dardo() -> Proiettile:
	var dardi := root.get_tree().get_nodes_in_group(Proiettile.GRUPPO)
	if dardi.is_empty():
		return null
	return dardi[dardi.size() - 1] as Proiettile


## Aspetta secondi veri, non fotogrammi.
func _riposa(secondi: float) -> void:
	var fine := Time.get_ticks_msec() + int(secondi * 1000.0)
	while Time.get_ticks_msec() < fine:
		await process_frame


## Aspetta che una cosa succeda, con un tetto di sicurezza in secondi.
func _aspetta_che(condizione: Callable, tetto: float) -> bool:
	var fine := Time.get_ticks_msec() + int(tetto * 1000.0)
	while Time.get_ticks_msec() < fine:
		if condizione.call():
			return true
		await process_frame
	return false


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
		print("AVVERSARIO: %d prove, tutte passate." % _prove)
		quit(0)
	else:
		print("AVVERSARIO: %d prove, %d FALLITE." % [_prove, _errori])
		quit(1)
