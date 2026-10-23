extends SceneTree

## **G0, la misura della GARA** (tappa 11, blocco D1), prima di fissare i numeri.
##
## Il piano chiede due cose: **quanto dura una gara** e **quante volte uno viene rimandato
## indietro**. Qui girano tante gare fra i soli cinque avversari — il giocatore è fermo
## sotto il pavimento, non tocca niente e nessuno lo vede — e per ognuna si stampano la
## durata, chi ha vinto, le bandiere di tutti e i colpi incassati.
##
## **Accelerate**: la fisica gira a `ACCELERA` × 60 passi al secondo e il tempo di gioco a
## `ACCELERA` volte quello vero, così ogni passo di fisica dura sempre un sessantesimo di
## secondo di gioco, come sul telefono. Cambia quanto si aspetta, non come si corre.
##
## Uso:  godot --headless --path . -s tools/misura_gara.gd [-- <gare> <accelerazione> <livello>]
##       (di serie 10 gare, ×4, livello 0 = facile)

const GARE := 10
const ACCELERA := 4.0
## Oltre questo tempo di gioco si smette di aspettare: una gara che non chiude è un esito.
const TETTO := 600.0


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var gare := int(argomenti[0]) if argomenti.size() > 0 else GARE
	var accelera := float(argomenti[1]) if argomenti.size() > 1 else ACCELERA
	var livello := int(argomenti[2]) if argomenti.size() > 2 else 0
	Engine.physics_ticks_per_second = int(round(60.0 * accelera))
	Engine.max_physics_steps_per_frame = 16
	Engine.time_scale = accelera

	var arena: Arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	arena.imposta_modalita(Modalita.GARA)
	arena.imposta_durata(TETTO)
	arena.set("_livello", livello)
	var giocatore := arena.giocatore()
	print("G0: %d gare fra cinque avversari, livello %s, ×%.0f" % [gare, Avversario.TARATURE[livello]["nome"], accelera])

	var durate: Array[float] = []
	var colpi_tutti: Array[int] = []
	var chiuse := 0
	var vinte := {}
	for g in gare:
		arena.avvia_sfida()
		giocatore.process_mode = Node.PROCESS_MODE_DISABLED
		giocatore.global_position = Vector3(0, -40, 0)
		var inizio := Time.get_ticks_msec()
		var scadenza := inizio + int((TETTO / accelera + 30.0) * 1000.0)
		while Time.get_ticks_msec() < scadenza and not bool(arena.get("_finita")):
			await process_frame
		var durata := arena.orologio()
		var righe := arena.classifica()
		var primo: Dictionary = righe[0]
		var finita := int(primo["bandiere"]) >= arena.bandiere().quante()
		if finita:
			chiuse += 1
			durate.append(durata)
			vinte[primo["nome"]] = int(vinte.get(primo["nome"], 0)) + 1
		var pezzi: Array[String] = []
		for bot in arena.avversari():
			var colpi := arena.colpi_incassati(bot)
			colpi_tutti.append(colpi)
			pezzi.append("%s %d/7 %d colpi" % [bot.personaggio, arena.bandiere_di(bot), colpi])
		print("  gara %2d: %5.1f s %s, vince %-7s | %s  (%.0f s veri)" % [g + 1, durata,
				"" if finita else "(NON CHIUSA)", String(primo["nome"]), "  ·  ".join(pezzi),
				(Time.get_ticks_msec() - inizio) / 1000.0])
		arena.chiudi_sfida()
		giocatore.process_mode = Node.PROCESS_MODE_INHERIT
		await process_frame

	durate.sort()
	var somma := 0.0
	for d in durate:
		somma += d
	var colpi_somma := 0
	for c in colpi_tutti:
		colpi_somma += c
	print("")
	print("chiuse %d su %d" % [chiuse, gare])
	if not durate.is_empty():
		print("durata: più corta %.0f s, mediana %.0f s, media %.0f s, più lunga %.0f s" % [durate[0],
				durate[durate.size() / 2], somma / durate.size(), durate[-1]])
	print("colpi incassati per avversario a gara: media %.1f, il più colpito %d" % [
			float(colpi_somma) / maxf(colpi_tutti.size(), 1), colpi_tutti.max() if not colpi_tutti.is_empty() else 0])
	print("vittorie: %s" % str(vinte))
	quit(0)
