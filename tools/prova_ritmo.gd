extends SceneTree

## **La prima partita si può vincere?** (tappa 7, blocco C)
##
## Il piano lo dice con un metro: *un giocatore che mette a segno un colpo ogni
## otto secondi deve finire nei primi tre*. Questo attrezzo fa girare una partita
## intera senza schermo, accredita al giocatore un colpo diretto ogni otto
## secondi e stampa la classifica finale.
##
## Non è un collaudo: è la **misura** che serve prima di girare una manopola. Se
## con quel ritmo non si finisce nei primi tre, si abbassa la cadenza del livello
## facile — non l'errore di mira: un avversario che sbaglia di più è un
## avversario scemo, uno che spara meno è un avversario tranquillo.
##
## Dura quanto la partita, perché senza schermo la fisica resta agganciata
## all'orologio (`LEARNED.md` § 17) e accelerarla misurerebbe un'altra cosa.
##
## Uso:  godot --headless --path . -s tools/prova_ritmo.gd

## Ogni quanto il giocatore mette a segno un colpo diretto.
const RITMO := 8.0

## Quanto dura la partita misurata.
const DURATA := 180.0

## Ogni quanto si stampa come sta andando.
const RAPPORTO := 30.0


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame

	arena.call("imposta_durata", DURATA)
	arena.call("avvia_sfida")
	print("partita da %.0f s, un colpo del giocatore ogni %.0f s, livello %s"
			% [DURATA, RITMO, String(Avversario.TARATURE[0]["nome"])])

	var giocatore: Node3D = arena.call("giocatore")
	var prossimo_colpo := RITMO
	var prossimo_rapporto := RAPPORTO
	var colpi := 0
	var scadenza := Time.get_ticks_msec() + int((DURATA + 20.0) * 1000.0)

	while Time.get_ticks_msec() < scadenza:
		await process_frame
		var passati: float = DURATA - float(arena.call("tempo_rimasto"))
		if float(arena.call("conto_alla_rovescia")) > 0.0:
			continue
		if passati >= prossimo_colpo:
			prossimo_colpo += RITMO
			if _un_colpo(arena, giocatore):
				colpi += 1
		if passati >= prossimo_rapporto:
			prossimo_rapporto += RAPPORTO
			_scrivi("%3.0f s" % passati, arena)
		if float(arena.call("tempo_rimasto")) <= 0.0:
			break

	print("")
	_scrivi("fine", arena)
	var righe: Array = arena.call("classifica")
	var mia: int = int(arena.call("posizione_mia"))
	print("\nil giocatore ha messo a segno %d colpi (%d punti) ed è arrivato %d° su %d"
			% [colpi, int((arena.call("punteggi") as Array)[0]), mia, righe.size()])
	print("nei primi tre: %s" % ("sì" if mia <= 3 else "NO"))
	quit(0)


## Un colpo diretto del giocatore su uno che è in campo: venticinque punti, gli
## stessi che farebbe col pollice. Chi è appena stato colpito è immune, e allora
## si prova con un altro — o il ritmo misurato non sarebbe quello dichiarato.
func _un_colpo(arena: Node, giocatore: Node3D) -> bool:
	var bersagli: Array = arena.call("avversari")
	bersagli.shuffle()
	for uno in bersagli:
		if bool((uno as Avversario).call("incassa", 0, giocatore)):
			return true
	return false


func _scrivi(quando: String, arena: Node) -> void:
	var pezzi: Array[String] = []
	for riga in arena.call("classifica"):
		pezzi.append("%s %d%s" % [String(riga["nome"]), int(riga["punti"]),
				" ←" if bool(riga["tu"]) else ""])
	print("  %s   %s" % [quando, "  ·  ".join(pezzi)])
