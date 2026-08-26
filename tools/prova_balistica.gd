extends SceneTree

## Collaudo della balistica. Attrezzo di lavorazione, non entra nel gioco.
##
## `Balistica` è il codice più riusato del progetto: se sbaglia, sbaglia tutto
## (PLAN.md, rischio 2). Qui si controlla con dei numeri, non a occhio — e
## soprattutto si controlla la cosa che nessuno scatto può mostrare: che il
## dardo, che avanza a passettini di un fotogramma, finisca **dove la linea di
## mira aveva promesso**, che la calcola tutta in un colpo solo.
##
## Uso:  godot --headless --path . -s tools/prova_balistica.gd

const MEZZA_LARGHEZZA := 10.0
const ALTEZZA := 8.0

var _errori := 0
var _prove := 0


func _initialize() -> void:
	_costruisci_stanza()
	_esegui()


func _esegui() -> void:
	# Un paio di fotogrammi di fisica: prima i corpi non esistono per i raggi.
	await physics_frame
	await physics_frame
	var spazio := root.get_world_3d().direct_space_state

	_muro_frontale(spazio)
	_angolo_di_riflessione(spazio)
	_cinque_muri(spazio)
	_il_bersaglio_ferma(spazio)
	_energia_conservata(spazio)
	_il_dardo_segue_la_linea(spazio)

	print("")
	if _errori == 0:
		print("BALISTICA: %d prove, tutte passate." % _prove)
		quit(0)
	else:
		print("BALISTICA: %d prove, %d FALLITE." % [_prove, _errori])
		quit(1)


## Un muro davanti: si colpisce dove ci si aspetta e si torna indietro.
func _muro_frontale(spazio: PhysicsDirectSpaceState3D) -> void:
	var tratti := Balistica.traiettoria(spazio, Vector3(0, 4, 0), Vector3(0, 0, 1), 25.0)
	_conta("muro frontale: due tratti", tratti.size() == 2, str(tratti.size()))
	if tratti.size() < 2:
		return
	_vicino("muro frontale: punto d'urto", tratti[0].a, Vector3(0, 4, MEZZA_LARGHEZZA), 0.02)
	_vicino("muro frontale: normale", tratti[0].normale, Vector3(0, 0, -1), 0.01)
	_conta("muro frontale: un muro usato", Balistica.muri_usati(tratti) == 1,
			str(Balistica.muri_usati(tratti)))
	var indietro: Vector3 = tratti[1].a - tratti[1].da
	_conta("muro frontale: torna indietro", indietro.normalized().z < -0.99, str(indietro.normalized()))


## L'angolo di uscita è uguale a quello di entrata: è tutta la meccanica del gioco.
func _angolo_di_riflessione(spazio: PhysicsDirectSpaceState3D) -> void:
	var verso := Vector3(1, 0, 0.5).normalized()
	var tratti := Balistica.traiettoria(spazio, Vector3(0, 4, 0), verso, 40.0)
	if not _conta("angolo: almeno due tratti", tratti.size() >= 2, str(tratti.size())):
		return
	_vicino("angolo: urto sulla parete di destra", tratti[0].a, Vector3(MEZZA_LARGHEZZA, 4, 5.0), 0.05)
	var uscita: Vector3 = (tratti[1].a - tratti[1].da).normalized()
	var atteso := Vector3(-verso.x, verso.y, verso.z)
	_vicino("angolo: incidenza uguale a riflessione", uscita, atteso, 0.01)


## Cinque muri e non sei. È il nome del gioco.
func _cinque_muri(spazio: PhysicsDirectSpaceState3D) -> void:
	var tratti := Balistica.traiettoria(spazio, Vector3(0, 4, 0), Vector3(0, 0, 1), 400.0)
	_conta("cinque muri: ne usa esattamente cinque", Balistica.muri_usati(tratti) == 5,
			str(Balistica.muri_usati(tratti)))
	var ultimo = tratti[tratti.size() - 1]
	_conta("cinque muri: al sesto si spegne", ultimo.esaurito, str(ultimo.esaurito))
	_conta("cinque muri: sei tratti in tutto", tratti.size() == 6, str(tratti.size()))


## Un bersaglio assorbe: non rimbalza e chiude la traiettoria.
func _il_bersaglio_ferma(spazio: PhysicsDirectSpaceState3D) -> void:
	var tratti := Balistica.traiettoria(spazio, Vector3(-6, 1.0, 0), Vector3(1, 0, 0), 60.0)
	if not _conta("bersaglio: qualcosa è stato colpito", tratti.size() >= 1, str(tratti.size())):
		return
	_conta("bersaglio: il primo tratto lo trova", tratti[0].bersaglio, str(tratti[0].bersaglio))
	_conta("bersaglio: la traiettoria finisce lì", tratti.size() == 1, str(tratti.size()))
	_conta("bersaglio: nessun muro consumato", Balistica.muri_usati(tratti) == 0,
			str(Balistica.muri_usati(tratti)))


## Nessuna perdita di energia: la strada percorsa è tutta quella data, rimbalzi
## compresi. È la regola del Sidewinder del 1999, ed è quella che tiene la
## traiettoria pulita invece che molle.
func _energia_conservata(spazio: PhysicsDirectSpaceState3D) -> void:
	# La portata dev'essere una che il dardo riesce davvero a percorrere: se
	# esaurisce i cinque muri per strada muore prima, e allora la somma è più
	# corta per il motivo giusto. Cinquanta metri in questa stanza fanno tre
	# rimbalzi, e restano due muri di margine.
	var portata := 50.0
	var tratti := Balistica.traiettoria(spazio, Vector3(0, 4, 0), Vector3(0.3, 0, 1).normalized(), portata)
	var somma := 0.0
	for tratto in tratti:
		somma += tratto.lunghezza()
	var ultimo = tratti[tratti.size() - 1]
	_conta("energia: il dardo è ancora vivo", not ultimo.esaurito, str(ultimo.esaurito))
	_conta("energia: rimbalza almeno due volte", Balistica.muri_usati(tratti) >= 2,
			str(Balistica.muri_usati(tratti)))
	_conta("energia: strada percorsa uguale alla portata", absf(somma - portata) < 0.2,
			"%.3f invece di %.1f" % [somma, portata])


## La prova che conta davvero: il dardo avanza a passettini di un fotogramma, la
## linea di mira calcola tutto in un colpo solo. Devono finire nello stesso punto,
## altrimenti il gioco promette una cosa e ne fa un'altra.
func _il_dardo_segue_la_linea(spazio: PhysicsDirectSpaceState3D) -> void:
	var origine := Vector3(-3, 3.2, -4)
	var verso := Vector3(0.62, 0.18, 0.76).normalized()
	var strada := 90.0

	var linea := Balistica.traiettoria(spazio, origine, verso, strada)
	var arrivo_linea := Balistica.punto_finale(linea)
	var muri_linea := Balistica.muri_usati(linea)

	# La stessa strada, ma un fotogramma alla volta a 60 al secondo: 19 m/s
	# vogliono dire poco più di trenta centimetri per volta.
	var punto := origine
	var direzione := verso
	var muri := 0
	var passo := Proiettile.VELOCITA / 60.0
	var percorsa := 0.0
	var spento := false
	while percorsa < strada and not spento:
		var pezzo := minf(passo, strada - percorsa)
		var tratti := Balistica.traiettoria(spazio, punto, direzione, pezzo,
				Balistica.MURI_MASSIMI - muri)
		percorsa += pezzo
		if tratti.is_empty():
			punto += direzione * pezzo
			continue
		for tratto in tratti:
			punto = tratto.a
			if tratto.bersaglio or tratto.esaurito:
				spento = true
				break
			if tratto.muro:
				muri += 1
				direzione = direzione.bounce(tratto.normale).normalized()

	_conta("dardo e linea: stesso numero di muri", muri == muri_linea,
			"dardo %d, linea %d" % [muri, muri_linea])
	# Mezzo metro di tolleranza su novanta di corsa e cinque rimbalzi: gli
	# scostamenti dalla parete si accumulano, ma l'errore non deve crescere.
	_vicino("dardo e linea: stesso punto d'arrivo", punto, arrivo_linea, 0.5)


func _costruisci_stanza() -> void:
	_scatola(Vector3(0, -0.5, 0), Vector3(2.0 * MEZZA_LARGHEZZA, 1.0, 2.0 * MEZZA_LARGHEZZA), Strati.MONDO)
	_scatola(Vector3(0, ALTEZZA + 0.5, 0), Vector3(2.0 * MEZZA_LARGHEZZA, 1.0, 2.0 * MEZZA_LARGHEZZA), Strati.MONDO)
	_scatola(Vector3(0, ALTEZZA * 0.5, -MEZZA_LARGHEZZA - 0.5), Vector3(2.0 * MEZZA_LARGHEZZA, ALTEZZA, 1.0), Strati.MONDO)
	_scatola(Vector3(0, ALTEZZA * 0.5, MEZZA_LARGHEZZA + 0.5), Vector3(2.0 * MEZZA_LARGHEZZA, ALTEZZA, 1.0), Strati.MONDO)
	_scatola(Vector3(-MEZZA_LARGHEZZA - 0.5, ALTEZZA * 0.5, 0), Vector3(1.0, ALTEZZA, 2.0 * MEZZA_LARGHEZZA), Strati.MONDO)
	_scatola(Vector3(MEZZA_LARGHEZZA + 0.5, ALTEZZA * 0.5, 0), Vector3(1.0, ALTEZZA, 2.0 * MEZZA_LARGHEZZA), Strati.MONDO)
	# Un bersaglio piantato a destra, ad altezza d'uomo.
	_scatola(Vector3(-2.0, 1.0, 0), Vector3(0.8, 1.8, 0.8), Strati.BERSAGLIO)


func _scatola(centro: Vector3, misura: Vector3, strato: int) -> void:
	var corpo := StaticBody3D.new()
	corpo.collision_layer = strato
	corpo.collision_mask = 0
	corpo.position = centro
	var forma := CollisionShape3D.new()
	var scatola := BoxShape3D.new()
	scatola.size = misura
	forma.shape = scatola
	corpo.add_child(forma)
	root.add_child(corpo)


func _conta(nome: String, esito: bool, dettaglio: String = "") -> bool:
	_prove += 1
	if esito:
		print("  OK   ", nome)
	else:
		_errori += 1
		print("  NO   ", nome, "  →  ", dettaglio)
	return esito


func _vicino(nome: String, avuto: Vector3, atteso: Vector3, tolleranza: float) -> void:
	var scarto := avuto.distance_to(atteso)
	_conta(nome, scarto <= tolleranza, "scarto %.4f — avuto %s, atteso %s" % [scarto, avuto, atteso])
