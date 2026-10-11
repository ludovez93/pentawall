extends SceneTree

## Attrezzo di lavorazione (tappa 11, blocco C2): con l'arena aperta, chi rinasce trova
## ancora un posto fuori dalla vista di tutti? Fable lo lasciava aperto («va verificato in
## partita contando quante rinascite trovano un punto fuori vista: oggi il dato non c'è»).
## Sei corpi messi a caso sui posti di rinascita (sempre gli stessi tiri), uno rinasce, e si
## conta quante volte il posto scelto dalla regola del gioco è in vista di qualcuno: vuol
## dire che un posto libero non c'era. Senza finestra.
##   godot --headless --path . -s tools/misura_rinascite.gd -- <variante> [prove]

func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var variante := int(argomenti[0]) if argomenti.size() > 0 else Aspetto.scelta()
	var prove := int(argomenti[1]) if argomenti.size() > 1 else 300
	var di_prima := Aspetto.scelta()
	Aspetto.scegli(variante)
	Arena.modo_partita = true
	var arena: Arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	var scadenza := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < scadenza and not (bool(arena.get("_sfida"))
			and bool(arena.call("_si_puo_segnare"))):
		await process_frame
	Aspetto.scegli(di_prima)
	var corpi: Array[Node3D] = [arena.giocatore()]
	for uno in arena.avversari():
		(uno as Avversario).bersaglio = null
		corpi.append(uno as Node3D)
	for corpo in corpi:
		corpo.process_mode = Node.PROCESS_MODE_DISABLED
	await physics_frame
	await physics_frame
	var posti: Array = arena.get("_rinascite")
	var caso := RandomNumberGenerator.new()
	caso.seed = 2026
	var in_vista := 0
	var visti_in_media := 0.0
	var posti_visti := 0
	for t in prove:
		for corpo in corpi:
			var p: Dictionary = posti[caso.randi_range(0, posti.size() - 1)]
			corpo.global_position = (p["dove"] as Vector3) - Vector3(0, 0.4, 0) \
					+ Vector3(caso.randf_range(-1.0, 1.0), 0.0, caso.randf_range(-1.0, 1.0))
		await physics_frame
		var chi := corpi[caso.randi_range(0, corpi.size() - 1)]
		var scelto: Dictionary = arena.call("_dove_ricomparire", chi)
		var visti := 0
		for altro in corpi:
			if altro != chi and bool(arena.call("_in_vista", scelto["dove"], altro)):
				visti += 1
		if visti > 0:
			in_vista += 1
			visti_in_media += visti
		# La controprova: quanti dei posti sono in vista di qualcuno. Se il conto della vista
		# fosse rotto sarebbe zero dappertutto, e lo zero di sopra non vorrebbe dire niente.
		for p: Dictionary in posti:
			for altro in corpi:
				if altro != chi and bool(arena.call("_in_vista", p["dove"], altro)):
					posti_visti += 1
					break
	print("variante %d (%s): %d posti di rinascita; in %d rinascite su %d nessun posto era fuori vista (%.0f%%)%s" % [
		variante, Aspetto.NOMI[variante], posti.size(), in_vista, prove,
		100.0 * float(in_vista) / float(prove),
		"" if in_vista == 0 else ", e lì ti vedevano in media %.1f avversari" % (visti_in_media / float(in_vista))])
	print("   controprova: in media %.1f posti su %d erano in vista di qualcuno" % [
		float(posti_visti) / float(prove), posti.size()])
	quit()
