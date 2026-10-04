extends SceneTree

## Attrezzo di lavorazione: fa girare il banco della scheda video (`BancoScheda`)
## sul PC, nella finestra di Godot, e stampa le sue righe. Nel browser il banco si
## apre con `?scheda`; qui si accende a mano.
##   godot --path . --resolution 854x390 -s tools/prova_banco_scheda.gd


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	Arena.modo_partita = true
	Arena.banco_scheda = true
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	var banco: BancoScheda = null
	var scadenza := Time.get_ticks_msec() + 15000
	while banco == null and Time.get_ticks_msec() < scadenza:
		await process_frame
		for figlio in arena.get_children():
			if figlio is BancoScheda:
				banco = figlio
	if banco == null:
		print("il banco non è partito")
		quit(1)
		return
	scadenza = Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < scadenza and not String(banco.get("_scritta").text).begins_with("FATTO"):
		await process_frame
	print("fine: ", banco.get("_scritta").text)
	quit()
