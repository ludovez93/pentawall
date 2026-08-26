extends SceneTree

## Collaudo dell'angolo di arena: la prova che la regola nuova della tappa 3 fa
## quello che promette.
##
## La regola è una sola e vale la tappa: **si rimbalza sulle sponde, non su
## tutto**. Qui si controlla che sia vera nei due versi — che un muro qualunque
## fermi il dardo, e che lo stesso identico colpo, commutata la regola, rimbalzi.
## Senza la seconda metà, la prima passerebbe anche se il dardo morisse per un
## motivo qualsiasi: una prova che verifica un'assenza va con la sua controprova
## (LEARNED.md 19).
##
## Uso:  godot --path . -s tools/prova_angolo.gd

var _errori := 0
var _prove := 0

var _angolo: Node
var _giocatore: Giocatore


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	_angolo = load("res://scenes/angolo.tscn").instantiate()
	root.add_child(_angolo)
	await process_frame
	await process_frame
	_giocatore = _angolo.call("giocatore")

	_prova_che_ci_sia_tutto()
	_prova_la_regola()
	_prova_le_sponde()
	await _prova_langolo_cieco()
	await _prova_che_non_si_esca()

	_chiudi()


## 1. Le due specie di superficie esistono davvero, e sono separate. Se un giorno
##    qualcuno costruisse un'arena di soli muri, il gioco resterebbe senza
##    rimbalzi e nessun'altra prova se ne accorgerebbe.
func _prova_che_ci_sia_tutto() -> void:
	var muri := get_nodes_in_group(Muratura.GRUPPO_MURI)
	var sponde := get_nodes_in_group(Muratura.GRUPPO_SPONDE)
	_conta("l'angolo ha dei muri", muri.size() >= 6, str(muri.size()))
	_conta("l'angolo ha delle sponde", sponde.size() >= 4, str(sponde.size()))
	_conta("nessuna superficie è muro e sponda insieme",
			_nessuna_in_comune(muri, sponde), "qualcuna sta in tutti e due i gruppi")

	var solo := bool(_angolo.call("solo_sponde"))
	_conta("si comincia con la regola nuova", solo, "si comincia da «rimbalza tutto»")
	for sponda in sponde:
		if (sponda as CollisionObject3D).collision_layer != Strati.MONDO:
			_conta("le sponde stanno sullo strato che riflette", false,
					"una sponda sta sullo strato %d" % (sponda as CollisionObject3D).collision_layer)
			return
	_conta("le sponde stanno sullo strato che riflette", true)


## 2 e 3. Lo stesso identico colpo, contro lo stesso identico muro, nelle due
##    regole. È il cuore del collaudo: la prima metà dice che il muro ferma, la
##    seconda che il muro *potrebbe* rimbalzare — cioè che la prima non è passata
##    perché il dardo si era perso per strada.
func _prova_la_regola() -> void:
	var da := Vector3(2.0, 1.6, 2.0)
	var verso := (Vector3(-4.0, 1.6, -2.6) - da).normalized()

	_imposta_regola(true)
	var stretta := _tratti(da, verso)
	var colpito_muro: bool = not stretta.is_empty() and stretta[stretta.size() - 1].corpo != null \
			and (stretta[stretta.size() - 1].corpo as Node).is_in_group(Muratura.GRUPPO_MURI)
	_conta("con le sponde sole, il colpo arriva sul muro", colpito_muro,
			"ha trovato %s" % [stretta[stretta.size() - 1].corpo if not stretta.is_empty() else null])
	_conta("e lì muore: zero rimbalzi", Balistica.muri_usati(stretta) == 0,
			"%d muri" % Balistica.muri_usati(stretta))

	_imposta_regola(false)
	var larga := _tratti(da, verso)
	_conta("lo stesso colpo, con «rimbalza tutto», rimbalza",
			Balistica.muri_usati(larga) >= 1, "%d muri" % Balistica.muri_usati(larga))
	# La controprova serve a poco se le due traiettorie non partivano uguali.
	var stesso_punto: bool = not stretta.is_empty() and not larga.is_empty() \
			and stretta[0].a.distance_to(larga[0].a) < 0.01
	_conta("i due colpi hanno preso lo stesso muro nello stesso punto", stesso_punto,
			"punti diversi")
	_imposta_regola(true)


## 4. Una sponda riflette, e riflette in tutte e due le regole: commutare la
##    regola non deve mai spegnere un rimbalzo che c'era.
func _prova_le_sponde() -> void:
	var da := Vector3(2.0, 2.5, 3.0)
	var verso := (Vector3(-12.8, 2.5, -1.0) - da).normalized()
	for regola in [true, false]:
		_imposta_regola(regola)
		var tratti := _tratti(da, verso)
		var su_sponda: bool = not tratti.is_empty() and tratti[0].corpo != null \
				and (tratti[0].corpo as Node).is_in_group(Muratura.GRUPPO_SPONDE)
		var nome := "solo le sponde" if regola else "rimbalza tutto"
		_conta("con «%s» il colpo trova una sponda" % nome, su_sponda,
				"ha trovato %s" % [tratti[0].corpo if not tratti.is_empty() else null])
		_conta("e la sponda lo rimbalza", Balistica.muri_usati(tratti) >= 1,
				"%d muri" % Balistica.muri_usati(tratti))
	_imposta_regola(true)


## 5. Il giro completo, come al poligono: dal posto in cui si comincia, il
##    bersaglio verde non si vede, e c'è una mira che lo prende di sponda.
##    Se questa fallisce, l'angolo è bello e non è un campo da gioco.
func _prova_langolo_cieco() -> void:
	var dietro := _bersaglio_nascosto()
	if dietro == null:
		_conta("c'è un bersaglio dietro il divisorio", false, "non l'ho trovato")
		return
	_conta("c'è un bersaglio dietro il divisorio", true)

	_giocatore.global_position = Vector3(7.0, 0.6, 6.0)
	_giocatore.punta(49.0, -4.0)
	for i in 6:
		await process_frame

	var occhi := _giocatore.camera().global_position
	var domanda := PhysicsRayQueryParameters3D.create(occhi,
			dietro.global_position + Vector3(0, 0.9, 0), Strati.TIRO, [_giocatore.get_rid()])
	var esito := root.get_world_3d().direct_space_state.intersect_ray(domanda)
	_conta("da dove si parte, il bersaglio è coperto",
			not esito.is_empty() and esito["collider"] != dietro,
			"visto: %s" % [esito.get("collider")])

	var mira := _cerca_la_sponda(dietro)
	if _conta("esiste un colpo di sponda che lo prende", mira != Vector2.INF,
			"nessuna direzione lo raggiunge"):
		print("       mira trovata: giro %.1f°, pendenza %.1f°" % [mira.x, mira.y])


## 6. Chi gioca resta dentro: la moquette regge il peso anche se non rimbalza.
##    È il controllo che si porta dietro la scelta degli strati — un muro che
##    ferma il dardo deve continuare a fermare anche i piedi.
func _prova_che_non_si_esca() -> void:
	_giocatore.global_position = Vector3(0.0, 2.0, 0.0)
	_giocatore.velocity = Vector3.ZERO
	await _aspetta(0.8)
	var dove := _giocatore.global_position
	_conta("chi gioca non sprofonda nel pavimento", dove.y > -0.2 and dove.y < 2.2,
			"y = %.2f" % dove.y)

	# Contro la parete, spinto forte: non deve passare dall'altra parte.
	_giocatore.global_position = Vector3(-11.0, 1.0, 0.0)
	await _aspetta(0.2)
	for i in 40:
		_giocatore.velocity = Vector3(-40.0, 0.0, 0.0)
		await process_frame
	await _aspetta(0.3)
	_conta("e non attraversa il muro", _giocatore.global_position.x > -13.0,
			"x = %.2f" % _giocatore.global_position.x)


func _imposta_regola(solo_sponde: bool) -> void:
	if bool(_angolo.call("solo_sponde")) != solo_sponde:
		_angolo.call("commuta_sponde")


func _tratti(da: Vector3, verso: Vector3) -> Array:
	return Balistica.traiettoria(root.get_world_3d().direct_space_state, da, verso)


func _bersaglio_nascosto() -> Bersaglio:
	return _angolo.call("bersaglio_nascosto")


## Cerca una mira che, da dove sta il giocatore, porti il dardo sul bersaglio
## dopo almeno un muro. Usa la previsione del gioco, non un conto a parte: se la
## previsione mentisse, il collaudo mentirebbe con lei.
func _cerca_la_sponda(bersaglio: Bersaglio) -> Vector2:
	var giro := -180.0
	while giro < 180.0:
		var pendenza := -14.0
		while pendenza <= 14.0:
			_giocatore.punta(giro, pendenza)
			var tratti := _giocatore.previsione()
			if not tratti.is_empty():
				var ultimo = tratti[tratti.size() - 1]
				if ultimo.bersaglio and ultimo.corpo == bersaglio \
						and Balistica.muri_usati(tratti) >= 1:
					return Vector2(giro, pendenza)
			pendenza += 2.0
		giro += 1.0
	return Vector2.INF


func _nessuna_in_comune(prima: Array, seconda: Array) -> bool:
	for uno in prima:
		if seconda.has(uno):
			return false
	return true


## Secondi veri, non fotogrammi: senza schermo il motore ne macina migliaia al
## secondo, e la fisica resta invece agganciata all'orologio (LEARNED.md 17).
func _aspetta(secondi: float) -> void:
	var fine := Time.get_ticks_msec() + int(secondi * 1000.0)
	while Time.get_ticks_msec() < fine:
		await process_frame


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
		print("ANGOLO: %d prove, tutte passate." % _prove)
		quit(0)
	else:
		print("ANGOLO: %d prove, %d FALLITE." % [_prove, _errori])
		quit(1)
