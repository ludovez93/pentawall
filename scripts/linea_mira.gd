class_name LineaMira
extends Node3D

## La linea che si vede mentre si mira: dove batte il colpo e dove ripartirà.
##
## È la contromossa al rischio numero uno del progetto (PLAN.md): mirare un
## rimbalzo con il pollice è difficile finché non si vede il rimbalzo. Con la
## linea non si mira all'avversario, **si mira alla parete**.
##
## Non calcola niente per conto suo: riceve i tratti di `Balistica.traiettoria`,
## gli stessi che percorrerà il proiettile vero. Se linea e dardo divergessero,
## il gioco mentirebbe.

## Quanti tratti si mostrano: quello diretto più il primo rimbalzo. Gli altri
## quattro muri restano da immaginare — è lì che sta la bravura.
const TRATTI_MOSTRATI := 2

const SPESSORE := 0.035

var _segmenti: Array[MeshInstance3D] = []
var _marcatore: MeshInstance3D
var _colore := Color(1.0, 0.62, 0.24)


func _ready() -> void:
	set_as_top_level(true)
	for i in TRATTI_MOSTRATI:
		var segmento := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(SPESSORE, SPESSORE, 1.0)
		segmento.mesh = mesh
		segmento.material_override = _materiale(0.55 if i == 0 else 0.85)
		segmento.visible = false
		segmento.set_as_top_level(true)
		add_child(segmento)
		_segmenti.append(segmento)

	_marcatore = MeshInstance3D.new()
	var mesh_marcatore := QuadMesh.new()
	# Piccolo: deve segnare il punto d'urto, non coprire il mirino.
	mesh_marcatore.size = Vector2(0.24, 0.24)
	_marcatore.mesh = mesh_marcatore
	var materiale := _materiale(0.9)
	materiale.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_marcatore.material_override = materiale
	_marcatore.visible = false
	_marcatore.set_as_top_level(true)
	add_child(_marcatore)


## Il colore segue quello riservato al proiettile, ma smorzato e trasparente:
## la linea è una promessa, il dardo è la cosa vera.
func imposta_colore(colore: Color) -> void:
	_colore = colore
	for i in _segmenti.size():
		var materiale: StandardMaterial3D = _segmenti[i].material_override
		materiale.albedo_color = Color(colore.r, colore.g, colore.b, 0.55 if i == 0 else 0.85)
	if _marcatore != null:
		var materiale_marcatore: StandardMaterial3D = _marcatore.material_override
		materiale_marcatore.albedo_color = Color(colore.r, colore.g, colore.b, 0.9)


func aggiorna(tratti: Array) -> void:
	if tratti.is_empty():
		nascondi()
		return

	for i in _segmenti.size():
		var segmento := _segmenti[i]
		if i >= tratti.size():
			segmento.visible = false
			continue
		var tratto = tratti[i]
		var lunghezza: float = tratto.da.distance_to(tratto.a)
		if lunghezza < 0.08:
			segmento.visible = false
			continue
		segmento.visible = true
		segmento.global_position = (tratto.da + tratto.a) * 0.5
		_orienta(segmento, tratto.a)
		segmento.scale = Vector3(1.0, 1.0, lunghezza)

	# Il segno sul punto d'impatto: è quello che il pollice insegue.
	var primo = tratti[0]
	if primo.muro or primo.bersaglio:
		_marcatore.visible = true
		_marcatore.global_position = primo.a + primo.normale * 0.03
	else:
		_marcatore.visible = false


func nascondi() -> void:
	for segmento in _segmenti:
		segmento.visible = false
	if _marcatore != null:
		_marcatore.visible = false


## `look_at` va in errore se la direzione è parallela al vettore alto: succede
## ogni volta che si mira dritti in su o dritti in giù, cioè spesso.
func _orienta(nodo: Node3D, verso_punto: Vector3) -> void:
	var direzione := verso_punto - nodo.global_position
	if direzione.length_squared() < 0.000001:
		return
	var alto := Vector3.UP
	if absf(direzione.normalized().dot(Vector3.UP)) > 0.999:
		alto = Vector3.FORWARD
	nodo.look_at(verso_punto, alto, true)


func _materiale(opacita: float) -> StandardMaterial3D:
	var materiale := StandardMaterial3D.new()
	materiale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materiale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materiale.albedo_color = Color(_colore.r, _colore.g, _colore.b, opacita)
	materiale.disable_receive_shadows = true
	return materiale
