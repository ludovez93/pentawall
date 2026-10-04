extends SceneTree

## Collaudo delle varianti dell'aspetto (tappa 10, blocco C).
##
## Le varianti si provano dal telefono, una dopo l'altra, col pulsante del banco di
## prova: se una si rompe in silenzio — un gruppo rinominato, un pezzo che non nasce —
## il confronto si fa contro una variante a metà e nessuno se ne accorge. Qui si
## costruisce l'arena in ognuna e si guarda che ci sia quello che la distingue. La
## variante di oggi deve restare quella di prima.
##
## Uso:  godot --headless --path . -s tools/prova_aspetto.gd

var _errori := 0
var _prove := 0


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var di_prima := Aspetto.scelta()
	for variante in Aspetto.NOMI.size():
		Aspetto.scegli(variante)
		var arena: Node3D = load("res://scenes/arena.tscn").instantiate()
		root.add_child(arena)
		for i in 3:
			await process_frame
		_guarda(arena, variante)
		arena.queue_free()
		await process_frame
	Aspetto.scegli(di_prima)
	print("\n%d prove, %d errori" % [_prove, _errori])
	quit(1 if _errori > 0 else 0)


func _guarda(arena: Node3D, variante: int) -> void:
	var nome := Aspetto.NOMI[variante]
	var soffitti := 0
	var lucernari := 0
	var serie := 0
	var cielo := false
	var nebbia := false
	var torri := 0
	for figlio in arena.get_children():
		if figlio.is_in_group(Arena.GRUPPO_SOFFITTI):
			soffitti += 1
		if figlio is MeshInstance3D and figlio.is_in_group(Arena.GRUPPO_LUCERNARI):
			lucernari += 1
		if figlio is MultiMeshInstance3D:
			serie += 1
		if figlio is WorldEnvironment:
			var ambiente := (figlio as WorldEnvironment).environment
			cielo = ambiente.background_mode == Environment.BG_SKY
			nebbia = ambiente.fog_enabled
		if figlio is OmniLight3D and (figlio as OmniLight3D).omni_range >= 60.0:
			torri += 1
	_conta("%s: soffitti e lucernari si ritrovano per gruppo" % nome, soffitti >= 5 and lucernari >= 20,
			"%d soffitti, %d lucernari" % [soffitti, lucernari])
	var ombre := 0
	var giocatore: Node = arena.call("giocatore")
	for figlio in giocatore.get_children():
		if figlio is MeshInstance3D and (figlio as MeshInstance3D).mesh is QuadMesh:
			ombre += 1
	match variante:
		Aspetto.OGGI:
			_conta("OGGI è l'arena di prima: niente cielo, niente nebbia, niente pezzi in serie, niente ombra",
					not cielo and not nebbia and serie == 0 and ombre == 0,
					"cielo %s, nebbia %s, %d in serie, %d ombre" % [cielo, nebbia, serie, ombre])
		Aspetto.PALAZZETTO:
			_conta("PALAZZETTO: capriate e materassini (almeno sei serie), nebbia, ombra",
					serie >= 6 and nebbia and ombre == 1, "%d in serie, %d ombre" % [serie, ombre])
		Aspetto.ORA_BLU:
			_conta("ORA BLU: il cielo, quattro torri faro, nebbia, ombra",
					cielo and torri == 4 and nebbia and ombre == 1,
					"cielo %s, %d torri, %d ombre" % [cielo, torri, ombre])
		Aspetto.SALA_LASER:
			_conta("SALA LASER: condotti e strisce in serie, nebbia, ombra",
					serie >= 3 and nebbia and ombre == 1, "%d in serie, %d ombre" % [serie, ombre])


func _conta(cosa: String, esito: bool, dettaglio := "") -> void:
	_prove += 1
	if esito:
		print("  ok   ", cosa)
	else:
		_errori += 1
		print("  NO   ", cosa, ("   (%s)" % dettaglio) if dettaglio != "" else "")
