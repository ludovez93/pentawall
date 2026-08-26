extends SceneTree

## Attrezzo di lavorazione: cerca **gli scatti**, non i fotogrammi al secondo.
##
## Nasce da un difetto riportato dal telefono il 26/08/2026: *«se faccio fuoco
## tante volte mentre mi muovo c'è qualche scatto dell'immagine»*. Uno scatto non
## si vede nella media — un fotogramma da 200 millisecondi ogni due secondi
## lascia la media quasi ferma e si sente benissimo sotto il pollice. Quindi qui
## si guarda la **coda della distribuzione**: il peggiore, il novantacinquesimo,
## e quanti fotogrammi sfondano le soglie.
##
## Si misura sempre **in coppia** (LEARNED.md 20): con la raffica e senza, nella
## stessa sessione e sulla stessa scena.
##
## Uso:  godot --path . -s tools/misura_scatti.gd -- angolo
##       godot --path . -s tools/misura_scatti.gd -- angolo senza-fuoco
##       godot --path . -s tools/misura_scatti.gd
##       godot --path . -s tools/misura_scatti.gd -- senza-fuoco

const SECONDI := 12.0
const SOGLIA_LISCIO := 0.020   ## 20 ms: sopra, il movimento smette di essere liscio
const SOGLIA_SCATTO := 0.050   ## 50 ms: qui lo scatto si vede a occhio


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var argomenti := OS.get_cmdline_user_args()
	var quale := "poligono"
	for nome in ["angolo", "arena"]:
		if argomenti.has(nome):
			quale = nome
	var col_fuoco := not argomenti.has("senza-fuoco")

	var scena: Node = load("res://scenes/%s.tscn" % quale).instantiate()
	root.add_child(scena)
	for i in 60:
		await process_frame
	var giocatore: Giocatore = scena.call("giocatore")

	var tempi := []
	var colpi := 0
	var picco_al_colpo := 0
	# Non basta sapere **quanti** fotogrammi sono lenti: serve sapere cosa stava
	# succedendo dentro. Un'ipotesi convincente sugli scatti e' gia' stata
	# smentita una volta (gli anelli), e le ipotesi costano piu' della misura.
	var diario := []
	var dardi_prima := 0
	var ultimo := Time.get_ticks_usec()
	var fine := ultimo + int(SECONDI * 1000000.0)
	var da_quando_ha_sparato := 999

	while Time.get_ticks_usec() < fine:
		await process_frame
		var adesso := Time.get_ticks_usec()
		var passo := float(adesso - ultimo) / 1000000.0
		ultimo = adesso
		tempi.append(passo)
		# Ci si muove sempre: una scena ferma misura la scena più facile, non
		# quella vera — ed è **muovendosi** che il difetto è stato riportato.
		giocatore.gira(0.011, 0.0)
		giocatore.velocity.x = 4.0 * sin(float(tempi.size()) * 0.05)
		da_quando_ha_sparato += 1
		if col_fuoco and giocatore.spara():
			colpi += 1
			da_quando_ha_sparato = 0
		# Il fotogramma **subito dopo** un colpo è quello in cui nascono le nove
		# risorse nuove del dardo: se gli scatti stanno lì, si vede da qui.
		if da_quando_ha_sparato <= 1 and passo > SOGLIA_SCATTO:
			picco_al_colpo += 1
		var dardi := get_nodes_in_group(Proiettile.GRUPPO).size()
		if passo > SOGLIA_LISCIO:
			diario.append("  %6.1f ms — dardi in volo %d (erano %d), colpo %d fotogrammi fa" % [
				passo * 1000.0, dardi, dardi_prima, da_quando_ha_sparato])
		dardi_prima = dardi

	tempi.sort()
	var somma := 0.0
	for t in tempi:
		somma += t
	var media: float = somma / float(tempi.size())
	var mediana: float = tempi[tempi.size() / 2]
	var novantacinque: float = tempi[int(float(tempi.size()) * 0.95)]
	var peggiore: float = tempi[tempi.size() - 1]
	var sopra_liscio := 0
	var sopra_scatto := 0
	for t in tempi:
		if t > SOGLIA_LISCIO:
			sopra_liscio += 1
		if t > SOGLIA_SCATTO:
			sopra_scatto += 1

	print("scheda: ", RenderingServer.get_video_adapter_name())
	print("scena: %s   fuoco: %s   colpi sparati: %d" % [
		quale, "a raffica" if col_fuoco else "spento", colpi])
	print("fotogrammi: %d in %.1f s  (media %.1f al secondo)" % [
		tempi.size(), SECONDI, float(tempi.size()) / SECONDI])
	print("tempo per fotogramma — mediana %.1f ms, media %.1f ms, 95° %.1f ms, PEGGIORE %.1f ms" % [
		mediana * 1000.0, media * 1000.0, novantacinque * 1000.0, peggiore * 1000.0])
	print("sopra i 20 ms: %d fotogrammi (%.1f%%)   sopra i 50 ms: %d (%.1f%%)" % [
		sopra_liscio, 100.0 * float(sopra_liscio) / float(tempi.size()),
		sopra_scatto, 100.0 * float(sopra_scatto) / float(tempi.size())])
	print("scatti nel fotogramma del colpo o subito dopo: %d su %d colpi" % [picco_al_colpo, colpi])
	if not diario.is_empty():
		print("cosa succedeva nei fotogrammi lenti:")
		for riga in diario:
			print(riga)
	quit(0)
