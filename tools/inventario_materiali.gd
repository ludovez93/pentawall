extends SceneTree

## Attrezzo di lavorazione: **l'inventario dei materiali** di una partita, raggruppati
## per shader.
##
## Sul telefono ogni shader diverso costa cinque compilazioni (Godot compila quattro
## varianti di serie più quella che serve: `shader_gles3.h`, 4.7.2), e nel browser
## una compilazione si misura in decimi di secondo. Due materiali che differiscono
## solo nei numeri (colore, scala, intensità) condividono lo shader; basta un
## interruttore diverso — una texture in più, la trasparenza, il doppio lato — e
## lo shader è un altro. Qui si raggruppano i materiali per la loro **chiave**:
## tutti gli interruttori, gli elenchi e la presenza di ogni texture.
##
##   godot --path . --resolution 854x390 -s tools/inventario_materiali.gd

var _arena: Node
var _gruppi := {}


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	Arena.modo_partita = true
	_arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(_arena)
	var scadenza := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < scadenza and float(_arena.call("conto_alla_rovescia")) > 0.0:
		await process_frame
	for i in 30:
		await process_frame

	for nodo in _arena.find_children("*", "GeometryInstance3D", true, false):
		var g := nodo as GeometryInstance3D
		var chi := _nome(g)
		if g is Label3D:
			_aggiungi("Label3D " + _chiave_label(g as Label3D), chi)
			continue
		if g is GPUParticles3D:
			var p := g as GPUParticles3D
			_aggiungi_materiale(p.process_material, chi + " [processo]")
			for i in p.draw_passes:
				var m := p.get_draw_pass_mesh(i)
				if m != null:
					for s in m.get_surface_count():
						_aggiungi_materiale(m.surface_get_material(s), chi + " [passata]")
			_aggiungi_materiale(g.material_override, chi)
			continue
		if g.material_override != null:
			_aggiungi_materiale(g.material_override, chi)
		elif g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
			var mi := g as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				_aggiungi_materiale(mi.get_active_material(s), chi)
		elif g is MultiMeshInstance3D:
			var mm := (g as MultiMeshInstance3D).multimesh
			if mm != null and mm.mesh != null:
				for s in mm.mesh.get_surface_count():
					_aggiungi_materiale(mm.mesh.surface_get_material(s), chi + " [multimesh]")
		if g.material_overlay != null:
			_aggiungi_materiale(g.material_overlay, chi + " [sopra]")

	var chiavi := _gruppi.keys()
	chiavi.sort_custom(func(a: String, b: String) -> bool:
		return (_gruppi[a] as Array).size() > (_gruppi[b] as Array).size())
	print("\nshader diversi: %d" % chiavi.size())
	for k in chiavi:
		var chi: Array = _gruppi[k]
		var esempi := {}
		for c in chi:
			esempi[c] = true
		print("\n%3d × %s\n      %s" % [chi.size(), k.left(400), ", ".join(esempi.keys().slice(0, 8))])
	quit()


func _aggiungi_materiale(m: Material, chi: String) -> void:
	if m == null:
		return
	_aggiungi(_chiave(m), chi)
	if m.next_pass != null:
		_aggiungi_materiale(m.next_pass, chi + " [passo dopo]")


func _aggiungi(chiave: String, chi: String) -> void:
	if not _gruppi.has(chiave):
		_gruppi[chiave] = []
	(_gruppi[chiave] as Array).append(chi)


## La chiave di uno shader: per un `ShaderMaterial` è il suo file; per un materiale
## standard sono tutti gli interruttori e gli elenchi, più quali texture ci sono.
## I numeri e i colori restano fuori: diventano parametri, non shader diversi.
func _chiave(m: Material) -> String:
	if m is ShaderMaterial:
		var sh := (m as ShaderMaterial).shader
		return "Shader " + (sh.resource_path if sh != null and sh.resource_path != "" else str(sh))
	var parti := [m.get_class()]
	for proprieta in m.get_property_list():
		var nome: String = proprieta["name"]
		if nome.begins_with("resource_") or nome == "script" or nome == "next_pass" \
				or nome == "render_priority":
			continue
		var tipo: int = proprieta["type"]
		var valore: Variant = m.get(nome)
		if tipo == TYPE_BOOL and valore:
			parti.append(nome)
		elif tipo == TYPE_INT and int(valore) != 0:
			parti.append("%s=%d" % [nome, int(valore)])
		elif tipo == TYPE_OBJECT and valore is Texture:
			parti.append(nome + "+")
	return " ".join(parti)


func _chiave_label(l: Label3D) -> String:
	return "billboard=%d shaded=%s doppio=%s senza_profondita=%s taglia_fissa=%s alfa=%d filtro=%d" % [
		l.billboard, l.shaded, l.double_sided, l.no_depth_test, l.fixed_size, l.alpha_cut, l.texture_filter]


func _nome(n: Node) -> String:
	var percorso := String(_arena.get_path_to(n))
	var pezzi := percorso.split("/")
	var utili := []
	for p in pezzi:
		if not p.begins_with("@"):
			utili.append(p)
	return "/".join(utili) if not utili.is_empty() else n.get_class()
