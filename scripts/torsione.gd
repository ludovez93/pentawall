class_name Torsione
extends SkeletonModifier3D

## Il busto che mira mentre le gambe corrono (tappa 8, blocco D).
##
## Un concorrente guarda sempre dove spara, e si muove in tutte le direzioni:
## avanti, di lato, indietro. Le animazioni della libreria sanno correre solo in
## avanti. Allora le gambe si girano verso dove si cammina — è il corpo intero a
## ruotare — e qui la colonna gira al contrario della stessa quantità, divisa sulle
## sue tre vertebre: il bacino va dove si corre, il petto e il blaster restano sulla
## mira. È il modo in cui lo fanno gli sparatutto in terza persona.
##
## Si applica sopra l'animazione, a ogni fotogramma, e non la tocca: con `angolo`
## a zero non fa niente.

## Quanto ruotare il busto attorno alla verticale, in radianti (positivo = verso
## sinistra, come le rotazioni di Godot attorno a +Y).
var angolo := 0.0

const OSSA := ["spine_01", "spine_02", "spine_03"]
const QUOTE := [0.30, 0.34, 0.36]

var _indici: Array[int] = []


func _process_modification_with_delta(_delta: float) -> void:
	_torci()


## Per le versioni di Godot che chiamano ancora la funzione senza il tempo: una
## sola delle due viene chiamata, mai tutte e due.
func _process_modification() -> void:
	_torci()


func _torci() -> void:
	if absf(angolo) < 0.001:
		return
	var scheletro := get_skeleton()
	if scheletro == null:
		return
	if _indici.is_empty():
		for nome in OSSA:
			_indici.append(scheletro.find_bone(nome))
	# La verticale del mondo, vista dallo scheletro: il modello è girato e scalato
	# dentro il personaggio, e la colonna deve girare attorno al su vero.
	var su := (scheletro.global_transform.basis.orthonormalized().inverse() * Vector3.UP).normalized()
	for i in _indici.size():
		var osso := _indici[i]
		if osso < 0:
			continue
		var genitore := scheletro.get_bone_parent(osso)
		var base_genitore := Basis()
		if genitore >= 0:
			base_genitore = scheletro.get_bone_global_pose(genitore).basis.orthonormalized()
		# Ruotare nello spazio dello scheletro vuol dire ruotare attorno a quell'asse
		# riportato nello spazio del genitore: le rotazioni attorno allo stesso asse
		# si sommano senza disturbarsi, quindi l'ordine delle tre vertebre non conta.
		var asse := (base_genitore.inverse() * su).normalized()
		var giro := Quaternion(asse, angolo * float(QUOTE[i]))
		scheletro.set_bone_pose_rotation(osso, giro * scheletro.get_bone_pose_rotation(osso))
