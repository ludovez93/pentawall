class_name Bersaglio
extends StaticBody3D

## Un bersaglio del poligono: alto e grosso come un avversario, e colpibile da
## tutti i lati — un pannello piatto premierebbe solo il colpo frontale, che è
## l'opposto di quello che questo gioco vuole insegnare.
##
## Si muove fra due punti a velocità costante, con l'inversione secca: il moto
## uniforme si può anticipare, ed è l'anticipo la cosa da esercitare.

signal centrato(punti: int, muri: int)

const RAGGIO := 0.35
const ALTEZZA := 1.7
const RIPOSO := 2.0  ## secondi di assenza dopo un colpo

## 25 punti il colpo diretto, poi raddoppia a ogni muro: 25, 50, 100, 200, 400, 800.
## I 25 sono quelli dell'originale (RICERCA-ORIGINALE.md § 5); il raddoppio è
## nostro, e dice in una riga qual è il gioco che stiamo facendo.
const PUNTI_BASE := 25

var _da := Vector3.ZERO
var _a := Vector3.ZERO
var _velocita := 0.0
var _avanzamento := 0.0
var _verso := 1.0
var _spento := 0.0
var _in_pausa := false

var _aspetto: Node3D
var _materiale_anello: StandardMaterial3D
var _colore := Color(0.24, 0.72, 1.0)


static func crea(genitore: Node, da: Vector3, a: Vector3, velocita: float,
		colore: Color = Color(0.24, 0.72, 1.0)) -> Bersaglio:
	var bersaglio := Bersaglio.new()
	bersaglio._da = da
	bersaglio._a = a
	bersaglio._velocita = velocita
	bersaglio._colore = colore
	genitore.add_child(bersaglio)
	bersaglio.global_position = da
	return bersaglio


func _ready() -> void:
	collision_layer = Strati.BERSAGLIO
	collision_mask = 0
	_costruisci()


func _process(delta: float) -> void:
	if _in_pausa:
		return
	if _spento > 0.0:
		_spento -= delta
		if _spento <= 0.0:
			_riaccendi()
		return

	var distanza := _da.distance_to(_a)
	if distanza > 0.01 and _velocita > 0.0:
		_avanzamento += _verso * (_velocita / distanza) * delta
		if _avanzamento >= 1.0:
			_avanzamento = 1.0
			_verso = -1.0
		elif _avanzamento <= 0.0:
			_avanzamento = 0.0
			_verso = 1.0
		global_position = _da.lerp(_a, _avanzamento)


## Chiamata da chi ha sparato quando il dardo arriva. `muri` sono quelli
## consumati prima di arrivare qui: è tutto il punteggio del gioco.
##
## Firma uguale a quella dell'avversario, e risposta uguale — vero se il colpo
## è valso punti. Così chi spara non ha bisogno di sapere cosa ha colpito.
func incassa(muri: int, _da: Object = null) -> bool:
	if _spento > 0.0 or _in_pausa:
		return false
	var punti := PUNTI_BASE * int(pow(2, muri))
	centrato.emit(punti, muri)
	_spegni()
	return true


## Durante la sfida i bersagli si fanno da parte: con un avversario in campo
## sarebbero punti gratis e rumore in mezzo alla linea di tiro.
func metti_in_pausa(pausa: bool) -> void:
	_in_pausa = pausa
	_aspetto.visible = not pausa
	if pausa:
		collision_layer = 0
	else:
		_spento = 0.0
		collision_layer = Strati.BERSAGLIO


func _spegni() -> void:
	_spento = RIPOSO
	_aspetto.visible = false
	collision_layer = 0


func _riaccendi() -> void:
	_aspetto.visible = true
	collision_layer = Strati.BERSAGLIO


func _costruisci() -> void:
	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = RAGGIO
	cilindro.height = ALTEZZA
	forma.shape = cilindro
	forma.position = Vector3(0, ALTEZZA * 0.5, 0)
	add_child(forma)

	_aspetto = Node3D.new()
	add_child(_aspetto)

	# Tre anelli: il colpo alto vale già di più nell'originale, e qui si vede.
	var altezze := [0.28, 0.85, 1.42]
	var raggi := [RAGGIO, RAGGIO * 0.98, RAGGIO * 0.86]
	for i in altezze.size():
		var anello := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = raggi[i]
		mesh.bottom_radius = raggi[i]
		mesh.height = 0.5
		mesh.radial_segments = 16
		anello.mesh = mesh
		anello.position = Vector3(0, altezze[i], 0)
		var materiale := StandardMaterial3D.new()
		var chiaro := i % 2 == 1
		materiale.albedo_color = Color(0.86, 0.9, 0.95) if chiaro else _colore
		materiale.emission_enabled = true
		materiale.emission = materiale.albedo_color
		# Sotto la soglia del bagliore: nel mondo niente supera il bianco,
		# solo il proiettile lo fa (DECISIONI.md § B).
		materiale.emission_energy_multiplier = 0.35
		materiale.roughness = 0.5
		anello.material_override = materiale
		_aspetto.add_child(anello)

	# Il cappello: dice a colpo d'occhio se il bersaglio è in piedi.
	var cappello := MeshInstance3D.new()
	var mesh_cappello := SphereMesh.new()
	mesh_cappello.radius = RAGGIO * 0.7
	mesh_cappello.height = RAGGIO * 1.0
	cappello.mesh = mesh_cappello
	cappello.position = Vector3(0, ALTEZZA + 0.05, 0)
	_materiale_anello = StandardMaterial3D.new()
	_materiale_anello.albedo_color = _colore
	_materiale_anello.emission_enabled = true
	_materiale_anello.emission = _colore
	_materiale_anello.emission_energy_multiplier = 0.6
	cappello.material_override = _materiale_anello
	_aspetto.add_child(cappello)
