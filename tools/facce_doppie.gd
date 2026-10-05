extends SceneTree

## **Le facce doppie**: due facce nello stesso piano, rivolte dalla stessa parte, che si
## coprono. La scheda le disegna tutte e due, e quale resta davanti lo decide
## l'arrotondamento di ogni punto: a ogni movimento della camera vince l'altra, e la
## superficie lampeggia. Dal telefono, il 05/10/2026: *«le parti superiori di alcune forme
## lampeggiavano veloci»* — sulle cime dei moduli corpo, cappello e montanti finivano alla
## stessa quota. Prima ancora i pavimenti dei passaggi diagonali (`LEARNED.md` § 49).
##
## Si raccolgono i triangoli di tutto quello che si vede nell'arena (i corpi no), si
## raggruppano per piano — stessa normale, distanza entro `Raccolta.SCARTO` — e dentro ogni
## piano si cercano le coppie che si sovrappongono davvero, non quelle che si toccano su un
## lato. Una coppia che ha un solido subito davanti non si vede e non conta: dove due muri
## si incrociano i loro pezzi si compenetrano e le facce stanno dentro, e il fondo di un
## pezzo appoggiato guarda il pavimento (si guarda in più punti della sovrapposizione, non
## solo nel mezzo, perché una faccia può stare dentro a metà). Il collaudo è in
## `prova_aspetto.gd`; qui si stampa l'elenco, per sapere dove guardare.
##
## Uso:  godot --headless --path . -s tools/facce_doppie.gd -- <variante>
##       (senza numero, la variante salvata)


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var di_prima := Aspetto.scelta()
	var argomenti := OS.get_cmdline_user_args()
	var variante := int(argomenti[0]) if not argomenti.is_empty() else di_prima
	Aspetto.scegli(variante)
	var arena: Node3D = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	for i in 3:
		await process_frame
	for i in 2:
		await physics_frame
	var inizio := Time.get_ticks_msec()
	var esito := cerca(arena)
	print("%s: %d triangoli, %d coppie di facce doppie che si vedono, %.3f m² (%d ms)" % [
			Aspetto.NOMI[variante], esito["triangoli"], esito["coppie"], esito["area"],
			Time.get_ticks_msec() - inizio])
	print("  di cui fra colori diversi con dentro un pezzo dell'arena-giocattolo: %d" % esito["da_correggere"])
	for g: Dictionary in esito["gruppi"]:
		print("  %8.4f m²  %4d  %s  /  %s   normale %s   scarto %.1f mm   per esempio a %s%s" % [
				g["area"], g["coppie"], g["a"], g["b"], g["normale"], float(g["scarto"]) * 1000.0,
				g["dove"], "   << DA CORREGGERE" if g["da_correggere"] else ""])
	Aspetto.scegli(di_prima)
	quit()


## Le facce doppie che si vedono sotto `radice`: quante coppie, quanta area, quante da
## correggere (fra due colori diversi, e almeno un pezzo è dell'arena-giocattolo), e i
## gruppi (stessi due pezzi, stessi due colori, stesso piano) dal più grande.
static func cerca(radice: Node3D) -> Dictionary:
	var raccolta := Raccolta.new()
	raccolta.spazio = radice.get_world_3d().direct_space_state
	_raccogli(radice, radice, raccolta)
	return raccolta.coppie()


static func _raccogli(nodo: Node, radice: Node, raccolta: Raccolta) -> void:
	if nodo is CharacterBody3D or nodo is GPUParticles3D or nodo is CPUParticles3D:
		return
	if nodo is Node3D and not (nodo as Node3D).visible:
		return
	var nostro := nodo.is_in_group(Giocattolo.GRUPPO)
	if nodo is MeshInstance3D and (nodo as MeshInstance3D).mesh != null:
		var pezzo := nodo as MeshInstance3D
		var chi := String(radice.get_path_to(pezzo))
		for s in pezzo.mesh.get_surface_count():
			raccolta.superficie(pezzo.mesh, s, pezzo.global_transform, pezzo.get_active_material(s),
					chi, Color.WHITE, nostro)
	elif nodo is MultiMeshInstance3D and (nodo as MultiMeshInstance3D).multimesh != null:
		var serie := nodo as MultiMeshInstance3D
		var mm := serie.multimesh
		if mm.mesh != null and mm.transform_format == MultiMesh.TRANSFORM_3D:
			var chi := String(radice.get_path_to(serie))
			var quante := mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
			for i in quante:
				var tinta := mm.get_instance_color(i) if mm.use_colors else Color.WHITE
				for s in mm.mesh.get_surface_count():
					var materiale := serie.material_override if serie.material_override != null \
							else mm.mesh.surface_get_material(s)
					raccolta.superficie(mm.mesh, s, serie.global_transform * mm.get_instance_transform(i),
							materiale, chi, tinta, nostro)
	for figlio in nodo.get_children():
		_raccogli(figlio, radice, raccolta)


## **La raccolta**: i triangoli nel mondo, ognuno con il suo piano (la normale della faccia
## davanti: Godot disegna il senso orario), il colore e chi lo porta; e la fisica, per
## sapere quali facce hanno un solido davanti.
class Raccolta:
	## Due facce più vicine di così la scheda non le separa da lontano: con la camera del
	## giocatore (da 0,05 a 220 m) e 24 bit di profondità, a 60 metri il passo è di 4 mm.
	const SCARTO := 0.005
	## Sotto quest'area una sovrapposizione è un filo lungo uno spigolo, non una faccia.
	const AREA_MINIMA := 0.0004
	## Una faccia non si vede se a tanto davanti a lei c'è un solido (muro, pavimento,
	## sponda): la camera non ci entra.
	const DAVANTI := 0.02

	var spazio: PhysicsDirectSpaceState3D
	var punti := PackedVector3Array()
	var distanze := PackedFloat32Array()
	var colori := PackedColorArray()
	var chi := PackedInt32Array()
	var nomi: Array[String] = []
	var nostri: Array[bool] = []
	var _nome_indice := {}
	## (normale arrotondata, fetta di distanza) → triangoli.
	var gruppi := {}

	func _coperta(p: Vector3, n: Vector3) -> bool:
		var domanda := PhysicsPointQueryParameters3D.new()
		domanda.position = p + n * DAVANTI
		domanda.collision_mask = Strati.SOLIDO
		return not spazio.intersect_point(domanda, 1).is_empty()

	func superficie(mesh: Mesh, s: int, posto: Transform3D, materiale: Material, nome: String,
			tinta: Color, nostro: bool) -> void:
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return
		var dati := mesh.surface_get_arrays(s)
		var vertici: PackedVector3Array = dati[Mesh.ARRAY_VERTEX]
		var indici := PackedInt32Array()
		if dati[Mesh.ARRAY_INDEX] != null:
			indici = dati[Mesh.ARRAY_INDEX]
		var colori_v := PackedColorArray()
		if dati[Mesh.ARRAY_COLOR] != null:
			colori_v = dati[Mesh.ARRAY_COLOR]
		var base := tinta
		if materiale is BaseMaterial3D:
			base *= (materiale as BaseMaterial3D).albedo_color
		var doppio := Raccolta.due_facce(materiale)
		if not _nome_indice.has(nome):
			_nome_indice[nome] = nomi.size()
			nomi.append(nome)
			nostri.append(nostro)
		var di_chi: int = _nome_indice[nome]
		var mondo := PackedVector3Array()
		mondo.resize(vertici.size())
		for i in vertici.size():
			mondo[i] = posto * vertici[i]
		var quanti := (indici.size() if not indici.is_empty() else vertici.size()) / 3
		for t in quanti:
			var i0 := indici[3 * t] if not indici.is_empty() else 3 * t
			var i1 := indici[3 * t + 1] if not indici.is_empty() else 3 * t + 1
			var i2 := indici[3 * t + 2] if not indici.is_empty() else 3 * t + 2
			var colore := base * colori_v[i0] if not colori_v.is_empty() else base
			_aggiungi(mondo[i0], mondo[i1], mondo[i2], colore, di_chi)
			if doppio:
				_aggiungi(mondo[i0], mondo[i2], mondo[i1], colore, di_chi)

	func _aggiungi(a: Vector3, b: Vector3, c: Vector3, colore: Color, di_chi: int) -> void:
		var croce := (c - a).cross(b - a)
		var doppia := croce.length()
		if doppia < 0.000001:
			return
		var n := croce / doppia
		var d := n.dot(a)
		var t := distanze.size()
		punti.push_back(a)
		punti.push_back(b)
		punti.push_back(c)
		distanze.push_back(d)
		colori.push_back(colore)
		chi.push_back(di_chi)
		var chiave := Vector4i(roundi(n.x * 200.0), roundi(n.y * 200.0), roundi(n.z * 200.0),
				floori(d / SCARTO))
		if not gruppi.has(chiave):
			gruppi[chiave] = []
		(gruppi[chiave] as Array).append(t)

	func coppie() -> Dictionary:
		var trovati := {}
		var quante := 0
		var da_correggere := 0
		var area_tutta := 0.0
		for chiave: Vector4i in gruppi:
			var qui: Array = gruppi[chiave]
			var sopra: Array = gruppi.get(Vector4i(chiave.x, chiave.y, chiave.z, chiave.w + 1), [])
			if qui.size() < 2 and sopra.is_empty():
				continue
			var n0 := Vector3(chiave.x, chiave.y, chiave.z).normalized()
			var u := n0.cross(Vector3.UP if absf(n0.y) < 0.9 else Vector3.RIGHT).normalized()
			var v := n0.cross(u)
			var voci := []
			for t: int in qui:
				voci.append(_voce(t, u, v, false))
			for t: int in sopra:
				voci.append(_voce(t, u, v, true))
			voci.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
			for i in voci.size():
				var p: Array = voci[i]
				for j in range(i + 1, voci.size()):
					var q: Array = voci[j]
					if q[0] > p[1]:
						break
					if p[5] and q[5]:
						continue
					if q[2] > p[3] or q[3] < p[2]:
						continue
					var tp: int = p[4]
					var tq: int = q[4]
					var scarto := absf(distanze[tp] - distanze[tq])
					if scarto > SCARTO:
						continue
					var area := 0.0
					var dentro := Geometry2D.intersect_polygons(p[6], q[6])
					for poligono: PackedVector2Array in dentro:
						area += Raccolta.area_di(poligono)
					if area < AREA_MINIMA:
						continue
					var dove := _dove_si_vede(dentro, u, v, n0, distanze[tp])
					if dove == Vector3.INF:
						continue
					quante += 1
					area_tutta += area
					var a := "%s %s" % [nomi[chi[tp]], colori[tp].to_html(false)]
					var b := "%s %s" % [nomi[chi[tq]], colori[tq].to_html(false)]
					if b < a:
						var scambio := a
						a = b
						b = scambio
					var correggere := not colori[tp].is_equal_approx(colori[tq]) \
							and (nostri[chi[tp]] or nostri[chi[tq]])
					if correggere:
						da_correggere += 1
					var nome_gruppo := "%s|%s|%s" % [a, b, chiave]
					if not trovati.has(nome_gruppo):
						trovati[nome_gruppo] = {"a": a, "b": b, "area": 0.0, "coppie": 0, "scarto": 0.0,
								"normale": "(%.2f, %.2f, %.2f)" % [n0.x, n0.y, n0.z],
								"dove": "(%.2f, %.2f, %.2f)" % [dove.x, dove.y, dove.z],
								"da_correggere": correggere}
					var g: Dictionary = trovati[nome_gruppo]
					g["area"] = float(g["area"]) + area
					g["coppie"] = int(g["coppie"]) + 1
					g["scarto"] = maxf(float(g["scarto"]), scarto)
		var elenco := trovati.values()
		elenco.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["area"] > y["area"])
		return {"triangoli": distanze.size(), "coppie": quante, "area": area_tutta,
				"da_correggere": da_correggere, "gruppi": elenco}

	## Un punto della sovrapposizione senza un solido davanti, o `Vector3.INF` se non ce
	## n'è: il mezzo di ogni pezzo e i suoi vertici, tirati di un centimetro verso il mezzo.
	func _dove_si_vede(dentro: Array, u: Vector3, v: Vector3, n: Vector3, d: float) -> Vector3:
		for poligono: PackedVector2Array in dentro:
			var mezzo := Vector2.ZERO
			for punto in poligono:
				mezzo += punto
			mezzo /= float(poligono.size())
			var prove: Array[Vector2] = [mezzo]
			for punto in poligono:
				prove.append(punto + (mezzo - punto).limit_length(0.01))
			for prova in prove:
				var p := u * prova.x + v * prova.y + n * d
				if not _coperta(p, n):
					return p
		return Vector3.INF

	## Un triangolo nel suo piano: l'ingombro, chi è, se viene dalla fetta di sopra, la forma.
	func _voce(t: int, u: Vector3, v: Vector3, di_sopra: bool) -> Array:
		var forma := PackedVector2Array()
		for k in 3:
			var p := punti[3 * t + k]
			forma.push_back(Vector2(p.dot(u), p.dot(v)))
		var x0 := minf(forma[0].x, minf(forma[1].x, forma[2].x))
		var x1 := maxf(forma[0].x, maxf(forma[1].x, forma[2].x))
		var y0 := minf(forma[0].y, minf(forma[1].y, forma[2].y))
		var y1 := maxf(forma[0].y, maxf(forma[1].y, forma[2].y))
		return [x0, x1, y0, y1, t, di_sopra, forma]

	static func due_facce(materiale: Material) -> bool:
		if materiale is BaseMaterial3D:
			return (materiale as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED
		if materiale is ShaderMaterial and (materiale as ShaderMaterial).shader != null:
			return (materiale as ShaderMaterial).shader.code.contains("cull_disabled")
		return false

	static func area_di(poligono: PackedVector2Array) -> float:
		var somma := 0.0
		for i in poligono.size():
			somma += poligono[i].cross(poligono[(i + 1) % poligono.size()])
		return absf(somma) * 0.5
