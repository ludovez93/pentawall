class_name ArcoLancio
extends Node3D

## **Dove cade la palla** (tappa 11, blocco D2). Mentre porti una palla si vede l'arco che
## farebbe lanciata adesso, e un anello dove batte: il lancio in arco col pollice è il
## rischio dichiarato del blocco, ed è per questo che si vede prima (`PLAN.md`).
##
## Come la linea di mira del dardo (`LineaMira`): non calcola niente da sé, riceve i punti
## di `Palle.traiettoria`, gli stessi della palla vera. Stesso materiale, senza luci e
## trasparente, nel colore della palla che parte.

const PEZZI := 24
const SPESSORE := 0.08

var _pezzi: Array[MeshInstance3D] = []
var _anello: MeshInstance3D
var _pelle: StandardMaterial3D


func _ready() -> void:
	set_as_top_level(true)
	_pelle = StandardMaterial3D.new()
	_pelle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pelle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pelle.disable_receive_shadows = true
	_pelle.albedo_color = Color(1, 1, 1, 0.7)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(SPESSORE, SPESSORE, 1.0)
	for i in PEZZI:
		var pezzo := MeshInstance3D.new()
		pezzo.mesh = mesh
		pezzo.material_override = _pelle
		pezzo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pezzo.visible = false
		pezzo.set_as_top_level(true)
		add_child(pezzo)
		_pezzi.append(pezzo)
	_anello = MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.45
	toro.outer_radius = 0.6
	toro.rings = 32
	toro.ring_segments = 6
	_anello.mesh = toro
	_anello.scale = Vector3(1, 0.25, 1)
	_anello.material_override = _pelle
	_anello.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_anello.visible = false
	_anello.set_as_top_level(true)
	add_child(_anello)


## Disegna l'arco per i punti dati (dal primo all'urto), nel colore dato.
func mostra(punti: PackedVector3Array, colore: Color) -> void:
	_pelle.albedo_color = Color(colore.r, colore.g, colore.b, 0.75)
	if punti.size() < 2:
		nascondi()
		return
	# I punti sono tanti (uno ogni trentesimo di secondo): se ne prende uno ogni tanto,
	# l'ultimo sempre.
	var salto := maxi(1, int(ceil(float(punti.size() - 1) / float(PEZZI))))
	var usati := PackedVector3Array()
	var i := 0
	while i < punti.size() - 1:
		usati.append(punti[i])
		i += salto
	usati.append(punti[punti.size() - 1])
	for k in _pezzi.size():
		var pezzo := _pezzi[k]
		if k >= usati.size() - 1:
			pezzo.visible = false
			continue
		var da := usati[k]
		var a := usati[k + 1]
		var lungo := da.distance_to(a)
		if lungo < 0.02:
			pezzo.visible = false
			continue
		pezzo.visible = true
		pezzo.global_position = (da + a) * 0.5
		var su := Vector3.UP if absf((a - da).normalized().dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
		pezzo.look_at(a, su, true)
		pezzo.scale = Vector3(1, 1, lungo)
	# L'ultimo punto è il centro della palla quando batte: l'anello va giù di un raggio,
	# dove la palla tocca.
	_anello.visible = true
	_anello.global_position = punti[punti.size() - 1] - Vector3(0, Palla.RAGGIO - 0.05, 0)


func nascondi() -> void:
	for pezzo in _pezzi:
		pezzo.visible = false
	if _anello != null:
		_anello.visible = false
