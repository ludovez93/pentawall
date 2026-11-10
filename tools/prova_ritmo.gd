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
## Dalla tappa 12 (blocco 0) il ritmo è un argomento — il ritmo visto davvero col pilota
## e nello screenshot di Ludovico è da due a quattro volte più lento di otto secondi — e
## per ogni concorrente si stampa **quanti dei suoi punti vengono dai bersagli bonus**, e
## quando è stato preso ogni disco: nello scontro il distacco lo facevano i dischi.
##
## Dura quanto la partita, perché senza schermo la fisica resta agganciata
## all'orologio (`LEARNED.md` § 17) e accelerarla misurerebbe un'altra cosa.
##
## Uso:  godot --headless --path . -s tools/prova_ritmo.gd [-- <secondi fra due colpi>]
##       (di serie 8; la tappa 12 misura 8, 16 e 24)

## Ogni quanto il giocatore mette a segno un colpo diretto, se non si dice altro.
const RITMO := 8.0

## Quanto dura la partita misurata.
const DURATA := 180.0

## Ogni quanto si stampa come sta andando.
const RAPPORTO := 30.0

## Punti presi dai dischi, per nome.
var _dai_dischi := {}


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var ritmo := float(argomenti[0]) if argomenti.size() > 0 and argomenti[0].is_valid_float() else RITMO
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame

	arena.call("imposta_durata", DURATA)
	arena.call("avvia_sfida")
	print("partita da %.0f s in %s, un colpo del giocatore ogni %.0f s, livello %s"
			% [DURATA, Aspetto.nome(), ritmo, String(Avversario.TARATURE[0]["nome"])])
	for bonus: BersaglioBonus in arena.call("bersagli_bonus"):
		bonus.preso.connect(_su_disco.bind(arena, bonus))

	var giocatore: Node3D = arena.call("giocatore")
	var prossimo_colpo := ritmo
	var prossimo_rapporto := RAPPORTO
	var colpi := 0
	var scadenza := Time.get_ticks_msec() + int((DURATA + 20.0) * 1000.0)

	while Time.get_ticks_msec() < scadenza:
		await process_frame
		var passati: float = DURATA - float(arena.call("tempo_rimasto"))
		if float(arena.call("conto_alla_rovescia")) > 0.0:
			continue
		if passati >= prossimo_colpo:
			prossimo_colpo += ritmo
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
	var dischi := 0
	for nome in _dai_dischi:
		dischi += int(_dai_dischi[nome])
	print("punti dai dischi: %d in tutto, %s" % [dischi, str(_dai_dischi) if dischi > 0 else "nessuno"])
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


## Un disco preso: chi, quanto, quando. Doppio se chi l'ha preso ha i PUNTI DOPPI, come
## lo conta l'arena (`Arena._su_bonus_preso`).
func _su_disco(chi: Object, punti: int, arena: Node, bonus: BersaglioBonus) -> void:
	var potenziamenti: Potenziamenti = arena.get("_potenziamenti")
	if potenziamenti != null and potenziamenti.ha(chi, "doppio"):
		punti *= 2
	var nome := _nome(chi, arena)
	_dai_dischi[nome] = int(_dai_dischi.get(nome, 0)) + punti
	print("  disco da %d preso da %s a %.1f s (+%d)" % [bonus.valore, nome,
			DURATA - float(arena.call("tempo_rimasto")), punti])


func _nome(chi: Object, arena: Node) -> String:
	if chi is Avversario:
		return (chi as Avversario).personaggio
	return "TU" if chi == arena.call("giocatore") else "?"


func _scrivi(quando: String, arena: Node) -> void:
	var pezzi: Array[String] = []
	for riga in arena.call("classifica"):
		var dischi := int(_dai_dischi.get(String(riga["nome"]), 0))
		pezzi.append("%s %d%s%s" % [String(riga["nome"]), int(riga["punti"]),
				" (dischi %d)" % dischi if dischi > 0 else "", " ←" if bool(riga["tu"]) else ""])
	print("  %s   %s" % [quando, "  ·  ".join(pezzi)])
