extends SceneTree

## Attrezzo di lavorazione: quanto pesa ogni variante dell'aspetto per la scheda video,
## contata invece che stimata (tappa 10, blocco D). Per ogni variante costruisce l'arena
## e scrive: quanto ci ha messo a nascere, quanti pezzi si disegnano (una chiamata di
## disegno l'uno, a scena intera), quanti triangoli e vertici, quanti materiali diversi.
## Il telefono si misura dal telefono: questo dice solo se una variante ne pesa il
## doppio di un'altra prima di chiederglielo.
##   godot --headless --path . -s tools/misura_varianti.gd -- 0 4


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var di_prima := Aspetto.scelta()
	var varianti: Array[int] = []
	for argomento in OS.get_cmdline_user_args():
		varianti.append(int(argomento))
	if varianti.is_empty():
		varianti = [Aspetto.OGGI, Aspetto.GIOCATTOLO]
	for variante in varianti:
		Aspetto.scegli(variante)
		var prima := Time.get_ticks_usec()
		var arena: Node3D = load("res://scenes/arena.tscn").instantiate()
		root.add_child(arena)
		var nascita := (Time.get_ticks_usec() - prima) / 1000.0
		for i in 3:
			await process_frame
		_conta(arena, variante, nascita)
		arena.queue_free()
		await process_frame
	Aspetto.scegli(di_prima)
	quit()


func _conta(arena: Node3D, variante: int, nascita: float) -> void:
	var pezzi := 0
	var triangoli := 0
	var vertici := 0
	var materiali := {}
	var scritte := 0
	var per_nome := {}
	for nodo in arena.find_children("*", "GeometryInstance3D", true, false):
		var pezzo := nodo as GeometryInstance3D
		if not pezzo.is_visible_in_tree():
			continue
		pezzi += 1
		if pezzo is Label3D:
			scritte += 1
			continue
		var mesh: Mesh = null
		var copie := 1
		if pezzo is MeshInstance3D:
			mesh = (pezzo as MeshInstance3D).mesh
		elif pezzo is MultiMeshInstance3D and (pezzo as MultiMeshInstance3D).multimesh != null:
			mesh = (pezzo as MultiMeshInstance3D).multimesh.mesh
			copie = (pezzo as MultiMeshInstance3D).multimesh.instance_count
		if pezzo.material_override != null:
			materiali[pezzo.material_override] = true
		if mesh == null:
			continue
		var suoi := 0
		for s in mesh.get_surface_count():
			var dati := mesh.surface_get_arrays(s)
			var punti: PackedVector3Array = dati[Mesh.ARRAY_VERTEX]
			var indici = dati[Mesh.ARRAY_INDEX]
			vertici += punti.size() * copie
			suoi += ((indici as PackedInt32Array).size() if indici != null else punti.size()) / 3 * copie
		triangoli += suoi
		# Per gruppo di pezzi: il nome senza i numeri che Godot aggiunge ai doppioni.
		var nome := String(pezzo.name).rstrip("0123456789").trim_suffix("@").trim_prefix("@")
		if pezzo.get_parent() != arena:
			nome = String(pezzo.get_parent().name).rstrip("0123456789") + "/" + pezzo.get_class()
		per_nome[nome] = int(per_nome.get(nome, 0)) + suoi
	print("%-12s nasce in %6.0f ms · %4d pezzi (di cui %d scritte) · %7d triangoli · %7d vertici · %3d materiali"
			% [Aspetto.NOMI[variante], nascita, pezzi, scritte, triangoli, vertici, materiali.size()])
	var nomi := per_nome.keys()
	nomi.sort_custom(func(a, b) -> bool: return int(per_nome[a]) > int(per_nome[b]))
	for nome in nomi.slice(0, 12):
		print("      %-40s %7d triangoli" % [nome, per_nome[nome]])
