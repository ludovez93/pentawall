extends SceneTree

## Attrezzo di lavorazione: stampa l'albero di una scena importata (nodi e
## classi), le ossa dei suoi scheletri e le animazioni dei suoi animatori.
## Serve a guardare dentro un modello prima di scrivergli intorno del codice:
##
##   godot --path . --headless -s tools/ispeziona.gd -- res://assets/models/x.glb


func _initialize() -> void:
	for percorso in OS.get_cmdline_user_args():
		print("=== ", percorso)
		var scena: PackedScene = load(String(percorso))
		if scena == null:
			print("  non si carica")
			continue
		var radice := scena.instantiate()
		_stampa(radice, 0)
		radice.free()
	quit()


func _stampa(nodo: Node, livello: int) -> void:
	var riga := "  ".repeat(livello) + nodo.name + " (" + nodo.get_class() + ")"
	if nodo is Skeleton3D:
		var ossa := []
		for i in (nodo as Skeleton3D).get_bone_count():
			ossa.append((nodo as Skeleton3D).get_bone_name(i))
		riga += " ossa=%d %s" % [ossa.size(), str(ossa.slice(0, 8))]
	if nodo is AnimationPlayer:
		var animatore := nodo as AnimationPlayer
		riga += " radice=" + str(animatore.root_node) + " animazioni=" + str(animatore.get_animation_list())
		var lista := animatore.get_animation_list()
		if lista.size() > 0:
			var anim := animatore.get_animation(lista[0])
			var tracce := []
			for t in mini(anim.get_track_count(), 3):
				tracce.append(str(anim.track_get_path(t)))
			riga += " tracce=" + str(tracce)
	if nodo is MeshInstance3D:
		var m := nodo as MeshInstance3D
		riga += " scheletro=" + str(m.skeleton) + " superfici=%d" % (m.mesh.get_surface_count() if m.mesh else 0)
	print(riga)
	for figlio in nodo.get_children():
		_stampa(figlio, livello + 1)
