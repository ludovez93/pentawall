extends Node3D

## Scena di prova della tappa 0.
##
## Non è gioco: serve a dimostrare che la catena Godot → GitHub Actions → iPhone
## funziona, e a leggere sul telefono quattro cose che contano davvero:
## il numero di fotogrammi, il nome della scheda video, il bagliore HDR
## (il cubo è emissivo sopra il bianco, come sarà il proiettile) e il tocco.
## Sparisce appena parte il poligono di tiro della tappa 1.

const COLORI: Array[Color] = [
	Color(1.0, 0.42, 0.08),   # arancio Nerf
	Color(0.18, 0.55, 1.0),   # blu squadra
	Color(0.15, 0.85, 0.45),  # verde
	Color(1.0, 0.85, 0.15),   # giallo
]

var _indice_colore := 0
var _tocchi := 0

@onready var _cubo: MeshInstance3D = $Cubo
@onready var _etichetta: Label = $Interfaccia/Etichetta


func _ready() -> void:
	_applica_colore()


func _process(delta: float) -> void:
	_cubo.rotate_y(delta * 0.8)
	_cubo.rotate_object_local(Vector3.RIGHT, delta * 0.35)
	_etichetta.text = "PENTAWALL — tappa 0\n%d fps · %s\n%s\ntocchi: %d (tocca per cambiare colore)" % [
		Engine.get_frames_per_second(),
		OS.get_name(),
		RenderingServer.get_video_adapter_name(),
		_tocchi,
	]


func _unhandled_input(evento: InputEvent) -> void:
	var toccato := false
	if evento is InputEventScreenTouch and evento.pressed:
		toccato = true
	elif evento is InputEventMouseButton and evento.pressed:
		toccato = true
	if toccato:
		_tocchi += 1
		_indice_colore = (_indice_colore + 1) % COLORI.size()
		_applica_colore()


func _applica_colore() -> void:
	var materiale: StandardMaterial3D = _cubo.material_override
	var colore: Color = COLORI[_indice_colore]
	materiale.albedo_color = colore
	# Sopra 1.0 di proposito: è la stessa soglia HDR su cui poggerà la
	# leggibilità del proiettile. Se sul telefono il cubo "sborda" di luce,
	# il bagliore funziona.
	materiale.emission = colore
	materiale.emission_energy_multiplier = 1.35
