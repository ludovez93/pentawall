extends SceneTree

## Attrezzo di lavorazione: **quanto costa aprire una partita**, passo per passo.
##
## Dal telefono, il 03/10/2026: dopo GIOCA un fotogramma da 15,5 secondi. Nel
## browser del PC lo stesso fotogramma dura 22,6 s, e solo 12,5 sono shader: il
## resto è lavoro del gioco mentre l'arena nasce. Qui si ripete la costruzione
## dell'arena con un cronometro su ogni passo (la sottoclasse `ArenaCronometrata`
## chiama gli stessi metodi nello stesso ordine), poi si misurano i primi
## fotogrammi della partita.
##
##   godot --path . --resolution 854x390 -s tools/misura_apertura.gd

const ArenaCronometrata := preload("res://tools/misura_apertura_arena.gd")


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	Arena.modo_partita = true
	var t := Time.get_ticks_usec()
	var scena: PackedScene = load("res://scenes/arena.tscn")
	print("caricare la scena:            %7.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	t = Time.get_ticks_usec()
	var arena: Node = scena.instantiate()
	arena.set_script(ArenaCronometrata)
	print("istanziarla:                  %7.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	t = Time.get_ticks_usec()
	root.add_child(arena)
	print("aggiungerla (tutto _ready):   %7.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	var prima := Time.get_ticks_usec()
	for i in 12:
		await process_frame
		var adesso := Time.get_ticks_usec()
		print("  fotogramma %2d: %7.1f ms  (calcolo %5.1f ms, avversari %d)" % [i, (adesso - prima) / 1000.0,
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, (arena.call("avversari") as Array).size()])
		prima = adesso

	# Poi trenta secondi di partita: ogni fotogramma lento, con **chi è nato** dentro
	# quel fotogramma (LEARNED.md § 25: quello che nasce durante il gioco va contato).
	var nati := {}
	node_added.connect(func(n: Node) -> void:
		var chiave := n.get_class() + ("(" + String(n.name) + ")" if not String(n.name).begins_with("@") else "")
		nati[chiave] = int(nati.get(chiave, 0)) + 1)
	var inizio := Time.get_ticks_usec()
	prima = inizio
	print("
fotogrammi oltre i 30 ms nei primi 30 secondi di partita:")
	while Time.get_ticks_usec() - inizio < 30000000:
		nati.clear()
		await process_frame
		var adesso := Time.get_ticks_usec()
		var ms := (adesso - prima) / 1000.0
		prima = adesso
		if ms > 30.0:
			var chi := []
			for k in nati:
				chi.append("%s×%d" % [k, nati[k]])
			print("  a %5.1f s: %6.1f ms  punti %s  nati: %s" % [(adesso - inizio) / 1000000.0, ms,
					str(arena.call("punteggi")), ", ".join(chi).left(300)])
	quit()
