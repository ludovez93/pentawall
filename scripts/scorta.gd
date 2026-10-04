class_name Scorta
extends RefCounted

## **La scorta degli shader** (tappa 9, 03/10/2026).
##
## Sul telefono uno shader nuovo costa cinque compilazioni: Godot compila quattro
## varianti di serie appena lo usa la prima volta, più quella che serve davvero
## (`ShaderGLES3::_initialize_version`, 4.7.2), e nel browser ognuna si misura in
## decimi di secondo. Uno shader resta compilato **finché vive un materiale che lo
## usa**: i materiali standard con gli stessi interruttori ne condividono uno, e
## quando l'ultimo se ne va lo shader se ne va con lui. Cambiando scena succedeva a
## tutti — e l'ingresso ricompilava, entrando in partita, quello che aveva appena
## compilato.
##
## Qui se ne tiene **uno per shader**, per tutta la durata del gioco: costano
## qualche riferimento, e risparmiano secondi a ogni partita.

static var _tenuti := {}


## Tiene da parte un materiale per ogni shader che compare sotto `radice`.
static func tieni(radice: Node) -> void:
	for nodo in radice.find_children("*", "GeometryInstance3D", true, false):
		var g := nodo as GeometryInstance3D
		_tieni(g.material_override)
		_tieni(g.material_overlay)
		var mesh: Mesh = null
		if g is MeshInstance3D:
			mesh = (g as MeshInstance3D).mesh
			if mesh != null:
				for s in mesh.get_surface_count():
					_tieni((g as MeshInstance3D).get_active_material(s))
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
			mesh = (g as MultiMeshInstance3D).multimesh.mesh
		elif g is CPUParticles3D:
			mesh = (g as CPUParticles3D).mesh
		if mesh != null and not (g is MeshInstance3D):
			for s in mesh.get_surface_count():
				_tieni(mesh.surface_get_material(s))


## Quanti shader sono tenuti da parte: serve al collaudo.
static func quanti() -> int:
	return _tenuti.size()


static func _tieni(materiale: Material) -> void:
	var m := materiale
	while m != null:
		var chiave := chiave_di(m)
		if not _tenuti.has(chiave):
			_tenuti[chiave] = m
		m = m.next_pass


## La chiave dello shader di un materiale. Per uno `ShaderMaterial` è il suo shader;
## per un materiale standard sono tutti gli interruttori e gli elenchi, più quali
## texture ci sono — i numeri e i colori diventano parametri, e non cambiano shader.
static func chiave_di(m: Material) -> String:
	if m is ShaderMaterial:
		var shader := (m as ShaderMaterial).shader
		return "shader %d" % (shader.get_instance_id() if shader != null else 0)
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
