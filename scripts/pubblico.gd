class_name Pubblico
extends RefCounted

## **Il pubblico sulle tribune** (tappa 8, blocco E).
##
## Fino al 03/10/2026 erano capsule colorate con una sfera per testa: da lontano
## birilli, da vicino niente. Adesso sono persone — le «Background Posed Humans» di
## Quaternius, CC0, sedute o che esultano — con la maglietta nei colori dei
## concorrenti, carnagioni e capelli diversi, e chi esulta che salta sul posto.
## Sono tante e costano poco: **una passata per pezzo di persona** (pelle,
## maglietta, pantaloni, scarpe, capelli) per ogni posa, quante che siano le
## figure — `MultiMesh`, come prima. Niente collisioni: il pubblico riempie, non
## gioca.
##
## E sotto le file ci sono **i gradini**: la gradinata della pianta è un blocco
## liscio, e prima le file di capsule galleggiavano una più alta dell'altra sopra un
## piano. Le file adesso salgono **da davanti verso dietro** (prima era il
## contrario: la fila più alta stava davanti al campo e nascondeva le altre).

const CARTELLA := "res://assets/models/quaternius/pubblico/"
const SHADER := "res://assets/materials/pubblico.gdshader"

## Le quattro pose, con i capelli che le vanno bene. `tifo` è quanto saltano.
const POSE := [
	{"file": "Female_Sitting", "capelli": ["Female_Hairstyle_1", "Female_Hairstyle_2"], "tifo": 0.15},
	{"file": "Female_Sitting_Cheering", "capelli": ["Female_Hairstyle_1", "Female_Hairstyle_2"], "tifo": 1.0},
	{"file": "Male_Sitting", "capelli": ["Male_Hairstyle_1", "Male_Hairstyle_2"], "tifo": 0.15},
	{"file": "Male_Sitting_Cheering", "capelli": ["Male_Hairstyle_1", "Male_Hairstyle_2"], "tifo": 1.0},
]

## Le persone nei file sono alte 3,7 unità in piedi: a 0,45 un adulto fa 1,67 m.
const SCALA := 0.45

## Le magliette: i colori dei sei concorrenti, più il viola dell'arena e l'oro. Mai
## l'arancio del dardo né il ciano delle sponde, nemmeno sulle tribune.
const MAGLIE := [Color(0.13, 0.36, 0.95), Color(0.84, 0.12, 0.20), Color(0.98, 0.80, 0.12),
	Color(0.90, 0.30, 0.64), Color(0.92, 0.92, 0.95), Color(0.15, 0.15, 0.18),
	Color(0.62, 0.34, 0.95), Color(0.95, 0.72, 0.30)]

## Le parti delle persone, per nome del materiale nel file.
const PARTI := {"Skin": 0, "Shirt": 1, "Pants": 2, "Shoes": 3}

const FILE := 4
const PASSO_FILA := 1.15
const GRADINO := 0.4
const PASSO_POSTO := 0.62
const POSTI_VUOTI := 0.10


## Costruisce il pubblico su tutte le gradinate della pianta. Torna il nodo che lo
## contiene: i suoi figli sono le folle, una per posa e una per pettinatura.
static func costruisci(arena: Node3D, pianta: Dictionary) -> Node3D:
	var radice := Node3D.new()
	radice.name = "pubblico"
	arena.add_child(radice)
	# Seme fisso: la tribuna è la stessa a ogni apertura, o due scatti dello stesso
	# posto non si possono confrontare.
	var caso := RandomNumberGenerator.new()
	caso.seed = 20261003

	var forme: Array[Dictionary] = []
	for posa in POSE:
		forme.append(_forma(posa))

	# Chi siede dove: per ogni posa le sue persone, per ogni pettinatura i suoi capelli.
	var persone: Array = []
	for i in POSE.size():
		persone.append([])
	var capelli := {}

	for muro in pianta["muri"]:
		var nome := String(muro.get("nome", ""))
		if not nome.contains("gradinata"):
			continue
		var centro := Vector2(float(muro["centro"][0]), float(muro["centro"][1]))
		var misura := Vector2(float(muro["misura"][0]), float(muro["misura"][1]))
		var piano := float(muro["quota"]) + float(muro["alto"])
		var davanti := centro.x + misura.x * 0.5
		_gradini(radice, centro, misura, piano)
		for fila in FILE:
			var x := davanti - PASSO_FILA * (float(fila) + 0.55)
			var alto := piano + GRADINO * float(fila)
			var quanti := int(misura.y / PASSO_POSTO)
			for posto in quanti:
				if caso.randf() < POSTI_VUOTI:
					continue
				var z := centro.y - misura.y * 0.5 + PASSO_POSTO * (float(posto) + 0.5)
				var quale := caso.randi() % POSE.size()
				var forma: Dictionary = forme[quale]
				# I piedi sul gradino di sotto, il sedere sul bordo del proprio.
				var dove := Vector3(x + caso.randf_range(-0.06, 0.06), alto - GRADINO,
						z + caso.randf_range(-0.06, 0.06))
				# Guardano l'arena, che sta a est: −Z del modello va verso +X.
				var giro := Basis(Vector3.UP, -PI * 0.5 + caso.randf_range(-0.35, 0.35))
				var posto_mondo := Transform3D(giro.scaled(Vector3.ONE * SCALA), dove)
				var dati := Color(caso.randf(), caso.randf(), caso.randf(),
						float(POSE[quale]["tifo"]) * caso.randf_range(0.5, 1.0))
				var maglia: Color = MAGLIE[caso.randi() % MAGLIE.size()]
				(persone[quale] as Array).append({"posto": posto_mondo * (forma["corpo_xform"] as Transform3D),
						"maglia": maglia, "dati": dati})
				var taglio: String = POSE[quale]["capelli"][caso.randi() % 2]
				if not capelli.has(taglio):
					capelli[taglio] = []
				var testa: Vector3 = forma["testa"]
				(capelli[taglio] as Array).append({
					"posto": posto_mondo * Transform3D(Basis(), testa) * (_xform_capelli(taglio)),
					"maglia": maglia, "dati": dati})

	for i in POSE.size():
		var forma: Dictionary = forme[i]
		_folla(radice, "posa_%d" % i, forma["mesh"], persone[i], forma["su"], false)
	for taglio in capelli:
		_folla(radice, "capelli_" + String(taglio), _mesh_capelli(taglio), capelli[taglio],
				_su_capelli(taglio), true)
	return radice


## Quante persone ci sono: serve al collaudo, perché una tribuna vuota si vede solo
## guardandola e un errore nella pianta la svuoterebbe in silenzio.
static func quante(radice: Node) -> int:
	if radice == null:
		return 0
	var conta := 0
	for figlio in radice.get_children():
		if figlio is MultiMeshInstance3D and String(figlio.name).begins_with("posa_"):
			conta += (figlio as MultiMeshInstance3D).multimesh.instance_count
	return conta


# ------------------------------------------------------------------ dentro

static var _cache := {}


## La forma di una posa: la mesh, la sua trasformazione nel file, dove sta la testa
## (per appoggiarci i capelli) e la verticale del mondo misurata nel modello.
static func _forma(posa: Dictionary) -> Dictionary:
	var file := String(posa["file"])
	if _cache.has(file):
		return _cache[file]
	var scena: Node = (load(CARTELLA + file + ".fbx") as PackedScene).instantiate()
	var pezzo := scena.find_child("*", true, false) as MeshInstance3D
	for nodo in scena.get_children():
		if nodo is MeshInstance3D:
			pezzo = nodo
	var xform := (pezzo as Node3D).transform
	var mesh := (pezzo.mesh as ArrayMesh).duplicate() as ArrayMesh
	for s in mesh.get_surface_count():
		var materiale := mesh.surface_get_material(s)
		var nome := materiale.resource_name if materiale != null else ""
		mesh.surface_set_material(s, _pelle(int(PARTI.get(nome, 0)), xform))
	var forma := {"mesh": mesh, "corpo_xform": xform, "testa": _testa(pezzo.mesh, xform),
			"su": _su(xform)}
	scena.free()
	_cache[file] = forma
	return forma


## Un metro di su nel mondo, misurato nello spazio del modello: la scala del file
## (cento), quella della tribuna (0,45) e il verso (il file sta in piedi sull'asse Z).
static func _su(xform: Transform3D) -> Vector3:
	return (xform.basis.inverse() * Vector3.UP) / SCALA


static func _pelle(parte: int, xform: Transform3D) -> ShaderMaterial:
	var materiale := ShaderMaterial.new()
	materiale.shader = load(SHADER)
	materiale.set_shader_parameter("parte", parte)
	materiale.set_shader_parameter("su_modello", _su(xform))
	return materiale


## **Dove sta la testa** di una posa, nello spazio della scena del file. La pelle è
## fatta di pezzi staccati — la testa col collo, le braccia, a volte le gambe — e la
## testa è il pezzo che sta sopra la maglietta e più vicino all'asse del corpo:
## nelle pose che esultano le mani stanno più in alto della testa, quindi «il punto
## più alto» darebbe le mani.
static func _testa(mesh: Mesh, xform: Transform3D) -> Vector3:
	var pelle_s := -1
	var maglia_s := -1
	for s in mesh.get_surface_count():
		var nome := mesh.surface_get_material(s).resource_name if mesh.surface_get_material(s) else ""
		if nome == "Skin":
			pelle_s = s
		elif nome == "Shirt":
			maglia_s = s
	if pelle_s < 0 or maglia_s < 0:
		return Vector3.ZERO
	var maglia: PackedVector3Array = mesh.surface_get_arrays(maglia_s)[Mesh.ARRAY_VERTEX]
	var asse := Vector3.ZERO
	var colletto := -INF
	for v in maglia:
		var p := xform * v
		asse += p
		colletto = maxf(colletto, p.y)
	asse /= float(maglia.size())

	var arrays := mesh.surface_get_arrays(pelle_s)
	var vertici: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indici: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	# Pezzi connessi, unendo anche i vertici doppi delle cuciture (stessa posizione).
	var padre := PackedInt32Array()
	padre.resize(vertici.size())
	for i in vertici.size():
		padre[i] = i
	var per_posizione := {}
	for i in vertici.size():
		var chiave := Vector3i(roundi(vertici[i].x * 100000.0), roundi(vertici[i].y * 100000.0),
				roundi(vertici[i].z * 100000.0))
		if per_posizione.has(chiave):
			_unisci(padre, i, int(per_posizione[chiave]))
		else:
			per_posizione[chiave] = i
	for t in range(0, indici.size(), 3):
		_unisci(padre, indici[t], indici[t + 1])
		_unisci(padre, indici[t], indici[t + 2])
	var pezzi := {}
	for i in vertici.size():
		var r := _radice(padre, i)
		if not pezzi.has(r):
			pezzi[r] = {"somma": Vector3.ZERO, "quanti": 0}
		var p := xform * vertici[i]
		pezzi[r]["somma"] = (pezzi[r]["somma"] as Vector3) + p
		pezzi[r]["quanti"] = int(pezzi[r]["quanti"]) + 1
	var migliore := Vector3.ZERO
	var distanza := INF
	for r in pezzi:
		var centro: Vector3 = (pezzi[r]["somma"] as Vector3) / float(pezzi[r]["quanti"])
		if centro.y < colletto:
			continue
		var d := Vector2(centro.x - asse.x, centro.z - asse.z).length()
		if d < distanza:
			distanza = d
			migliore = centro
	return migliore


static func _unisci(padre: PackedInt32Array, a: int, b: int) -> void:
	var ra := _radice(padre, a)
	var rb := _radice(padre, b)
	if ra != rb:
		padre[ra] = rb


static func _radice(padre: PackedInt32Array, i: int) -> int:
	while padre[i] != i:
		padre[i] = padre[padre[i]]
		i = padre[i]
	return i


static func _xform_capelli(taglio: String) -> Transform3D:
	_carica_capelli(taglio)
	return _cache["capelli_" + taglio]["xform"]


static func _mesh_capelli(taglio: String) -> Mesh:
	_carica_capelli(taglio)
	return _cache["capelli_" + taglio]["mesh"]


static func _su_capelli(taglio: String) -> Vector3:
	_carica_capelli(taglio)
	return _su(_cache["capelli_" + taglio]["xform"])


## I capelli: nel file stanno attorno all'origine, e il loro centro va sul centro
## della testa — un filo più su, perché coprono la nuca e la cima, non il viso.
static func _carica_capelli(taglio: String) -> void:
	if _cache.has("capelli_" + taglio):
		return
	var scena: Node = (load(CARTELLA + taglio + ".fbx") as PackedScene).instantiate()
	var pezzo: MeshInstance3D = null
	for nodo in scena.get_children():
		if nodo is MeshInstance3D:
			pezzo = nodo
	var xform := pezzo.transform
	var centro := (xform * pezzo.mesh.get_aabb()).get_center()
	xform.origin -= centro - Vector3(0, 0.06, 0.02)
	var mesh := (pezzo.mesh as ArrayMesh).duplicate() as ArrayMesh
	for s in mesh.get_surface_count():
		mesh.surface_set_material(s, _pelle(4, xform))
	_cache["capelli_" + taglio] = {"mesh": mesh, "xform": xform}
	scena.free()


static func _folla(radice: Node3D, nome: String, forma: Mesh, persone: Array, su: Vector3,
		capelli: bool) -> void:
	if persone.is_empty():
		return
	var folla := MultiMesh.new()
	folla.transform_format = MultiMesh.TRANSFORM_3D
	folla.use_colors = true
	folla.use_custom_data = true
	folla.mesh = forma
	folla.instance_count = persone.size()
	for i in persone.size():
		var p: Dictionary = persone[i]
		folla.set_instance_transform(i, p["posto"])
		folla.set_instance_color(i, p["maglia"])
		folla.set_instance_custom_data(i, p["dati"])
	var nodo := MultiMeshInstance3D.new()
	nodo.name = nome
	nodo.multimesh = folla
	nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	radice.add_child(nodo)


## I gradini sotto le file: blocchi smussati, scuri, dal piano della gradinata alla
## quota di ogni fila. Solo per gli occhi — sopra la gradinata non ci sale nessuno.
static func _gradini(radice: Node3D, centro: Vector2, misura: Vector2, piano: float) -> void:
	var davanti := centro.x + misura.x * 0.5
	var pelle := Muratura.tinta_unita(Color(0.20, 0.17, 0.36), 0.8)
	for fila in range(1, FILE):
		var alto := GRADINO * float(fila)
		var profondo := misura.x - PASSO_FILA * float(fila)
		if profondo <= 0.2:
			continue
		var gradino := MeshInstance3D.new()
		gradino.mesh = Muratura.scatola_smussata(Vector3(profondo, alto, misura.y), 0.06)
		gradino.position = Vector3(davanti - PASSO_FILA * float(fila) - profondo * 0.5,
				piano + alto * 0.5, centro.y)
		gradino.material_override = pelle
		gradino.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		radice.add_child(gradino)
