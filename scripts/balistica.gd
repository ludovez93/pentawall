class_name Balistica
extends RefCounted

## Il risolutore di mira e la riflessione. È il codice più riusato del progetto:
## la stessa funzione, chiamata da quattro posti diversi, dà
##   1. la linea che vedi mentre miri          → linea_mira.gd
##   2. la traiettoria del proiettile vero     → proiettile.gd
##   3. l'allarme al bot che sta per essere colpito   → avversario.gd
##   4. la mira del bot                                → avversario.gd
## Se è sbagliata qui, è sbagliato tutto il gioco (PLAN.md, rischio numero 2).
## I casi limite sono verificati da `tools/prova_balistica.gd`.

## Cinque muri. È un pilastro, non un parametro di bilanciamento: il gioco si
## chiama PENTAWALL e questo numero è il suo nome (DECISIONI.md, 10 e D).
const MURI_MASSIMI := 5

## Stacco dalla superficie appena colpita, per non ricolpire quella.
const SCOSTAMENTO := 0.02

## Quanto lontano si guarda quando si mira: più della diagonale di un'arena (~95 m).
const PORTATA_MIRA := 140.0


## Un pezzo di traiettoria: da dove parte, dove finisce, e cosa c'è alla fine.
class Tratto:
	var da := Vector3.ZERO
	var a := Vector3.ZERO
	var normale := Vector3.ZERO  ## normale di ciò che è stato colpito (zero se finisce nel vuoto)
	var corpo: Object = null     ## cosa è stato colpito (null se finisce nel vuoto)
	var muro := false            ## alla fine c'è una superficie che riflette
	var bersaglio := false       ## alla fine c'è qualcosa da colpire: il proiettile si ferma
	var esaurito := false        ## il proiettile muore qui: ha finito i muri a disposizione

	func lunghezza() -> float:
		return da.distance_to(a)


## La funzione. Tira un raggio, e a ogni muro lo specchia sulla normale, fino a
## `muri_massimi` volte. Restituisce l'elenco dei tratti, in ordine.
##
## `portata` è la distanza totale ancora percorribile: la linea di mira ne passa
## tanta, il proiettile solo quella di un fotogramma.
static func traiettoria(spazio: PhysicsDirectSpaceState3D, origine: Vector3, direzione: Vector3,
		portata: float = PORTATA_MIRA, muri_massimi: int = MURI_MASSIMI,
		esclusi: Array[RID] = [], maschera: int = Strati.TIRO) -> Array:
	var tratti: Array = []
	if spazio == null or portata <= 0.0 or direzione.length_squared() < 0.000001:
		return tratti

	var punto := origine
	var verso := direzione.normalized()
	var resto := portata
	var muri := 0
	# Tetto di giri: se il proiettile finisse incastrato in uno spigolo, ogni giro
	# consumerebbe una distanza quasi nulla e il ciclo non finirebbe mai.
	var giri := 0
	var tetto := muri_massimi + 3

	while resto > 0.001 and giri < tetto:
		giri += 1
		var domanda := PhysicsRayQueryParameters3D.create(punto, punto + verso * resto, maschera, esclusi)
		domanda.collide_with_areas = false
		domanda.collide_with_bodies = true
		var esito := spazio.intersect_ray(domanda)

		var tratto := Tratto.new()
		tratto.da = punto

		if esito.is_empty():
			# Niente sulla strada: il tratto finisce nel vuoto e la corsa è finita.
			tratto.a = punto + verso * resto
			tratti.append(tratto)
			return tratti

		tratto.a = esito["position"]
		tratto.normale = esito["normal"]
		tratto.corpo = esito["collider"]

		var strato := 0
		if tratto.corpo is CollisionObject3D:
			strato = (tratto.corpo as CollisionObject3D).collision_layer
		tratto.bersaglio = (strato & Strati.ASSORBE) != 0

		if tratto.bersaglio:
			tratti.append(tratto)
			return tratti

		tratto.muro = true
		if muri >= muri_massimi:
			# Sesto muro: il proiettile muore qui, non rimbalza.
			tratto.esaurito = true
			tratti.append(tratto)
			return tratti

		tratti.append(tratto)
		muri += 1
		resto -= tratto.lunghezza()
		# La riflessione vera e propria: `bounce` è d - 2·(d·n)·n, cioè lo specchio
		# sulla normale. Nessuna perdita di energia, come il Sidewinder del 1999.
		verso = verso.bounce(tratto.normale).normalized()
		punto = tratto.a + tratto.normale * SCOSTAMENTO

	return tratti


## Quanti muri ha consumato una traiettoria.
static func muri_usati(tratti: Array) -> int:
	var conto := 0
	for tratto in tratti:
		if tratto.muro and not tratto.esaurito:
			conto += 1
	return conto


## Quanto vicino passa una traiettoria a un punto, e dopo quanta strada.
##
## È il secondo mestiere della riflessione, ed è quello che rende coerente il
## gioco: la stessa traiettoria che al giocatore serve per mirare, all'avversario
## serve per sapere che è in pericolo — anche quando il colpo gli arriva dietro
## l'angolo dopo tre sponde (MIGLIORIE.md § 1). Un raggio non basta, perché un
## corpo è largo: si misura la distanza dal segmento, non l'urto.
##
## Restituisce [distanza minima, strada percorsa fino a quel punto].
static func avvicinamento(tratti: Array, punto: Vector3) -> Array:
	var minima := INF
	var strada_al_minimo := 0.0
	var strada := 0.0
	for tratto in tratti:
		var vicino := Geometry3D.get_closest_point_to_segment(punto, tratto.da, tratto.a)
		var distanza := vicino.distance_to(punto)
		if distanza < minima:
			minima = distanza
			strada_al_minimo = strada + tratto.da.distance_to(vicino)
		strada += tratto.lunghezza()
	return [minima, strada_al_minimo]


## Dove finisce, in tutto, una traiettoria.
static func punto_finale(tratti: Array) -> Vector3:
	if tratti.is_empty():
		return Vector3.ZERO
	return tratti[tratti.size() - 1].a


## Il punto che il giocatore sta inquadrando: un raggio dal centro della camera.
## Se non c'è niente davanti, si prende un punto lontano sulla stessa linea — così
## la mira ha sempre una risposta e il proiettile non ha mai una direzione nulla.
static func punto_mirato(spazio: PhysicsDirectSpaceState3D, camera: Camera3D,
		portata: float = PORTATA_MIRA, esclusi: Array[RID] = []) -> Vector3:
	var origine := camera.global_position
	var verso := -camera.global_transform.basis.z
	var lontano := origine + verso * portata
	if spazio == null:
		return lontano
	var domanda := PhysicsRayQueryParameters3D.create(origine, lontano, Strati.TIRO, esclusi)
	var esito := spazio.intersect_ray(domanda)
	if esito.is_empty():
		return lontano
	return esito["position"]


## Da dove parte davvero il colpo: dalla canna, verso il punto inquadrato.
##
## È il nodo di tutto il sistema, ed è il motivo per cui una riga sola serve la
## terza e la prima persona (DECISIONI.md, 1): la canna è cosmesi, la mira è la
## camera. Se sparasse lungo l'asse della canna, in terza persona il colpo
## andrebbe di lato.
static func direzione_del_colpo(canna: Vector3, punto_mirato_: Vector3, avanti: Vector3) -> Vector3:
	var verso := punto_mirato_ - canna
	# Il punto inquadrato può cadere dietro la canna (mirando a un muro attaccato
	# alla faccia): in quel caso si spara avanti, non all'indietro.
	if verso.length_squared() < 0.04 or verso.normalized().dot(avanti) < 0.0:
		return avanti.normalized()
	return verso.normalized()
