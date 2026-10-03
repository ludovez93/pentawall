class_name Scintille
extends Node3D

## Le particelle del gioco (tappa 8, blocco G: «il colpo si vede»).
##
## Fino al 03/10/2026 un colpo a segno era un lampo e un numero, un rimbalzo un
## anello, una ricomparsa niente: chi riappariva dall'altra parte dell'arena
## compariva e basta. Le pubblicità dei giochi veri, guardate fotogramma per
## fotogramma lo stesso giorno, hanno in ogni scatto qualcosa che esplode, schizza o
## si apre. Qui ci sono le cinque cose che servono:
## - **il colpo**: schegge di gommapiuma nel colore del dardo, che schizzano dal
##   punto d'impatto e cadono;
## - **il rimbalzo**: scintille ciano lungo la normale della sponda (insieme
##   all'anello di sempre);
## - **il dardo che si spegne** contro un muro: uno sbuffo chiaro;
## - **la ricomparsa**: una colonna di luce nel colore di chi riappare, che sale
##   dai piedi — e lo sbuffo nel posto da cui è sparito;
## - **la presa di un potenziamento**: una corona nel suo colore.
##
## Tutto **in riserva**, costruito all'apertura della scena e riusato a giro: niente
## nasce durante la partita (`LEARNED.md` § 25). Particelle sulla CPU, piccole e
## poche: su un telefono, in un browser, la scheda video ha già il suo da fare.
## Una sola istanza per scena, che si registra in `attivo`, come `Suoni`.

const IN_RISERVA := 6

## Le scintille delle sponde: lo stesso ciano dei neon delle sponde (`Arena`).
const CIANO := Color(0.30, 0.99, 0.95)

static var attivo: Scintille = null

## Le riserve: `{nome: {"nodi": Array[CPUParticles3D], "prossimo": int}}`.
var _riserve := {}


func _ready() -> void:
	attivo = self
	_riserva("colpo", _fai_colpo)
	_riserva("rimbalzo", _fai_rimbalzo)
	_riserva("spento", _fai_spento)
	_riserva("ricomparsa", _fai_ricomparsa)
	_riserva("presa", _fai_presa)


func _exit_tree() -> void:
	if attivo == self:
		attivo = null


# ------------------------------------------------------------------ chi le chiama

static func colpo(dove: Vector3, normale: Vector3, colore: Color) -> void:
	if attivo != null:
		attivo._accendi("colpo", dove, normale, colore)


static func rimbalzo(dove: Vector3, normale: Vector3) -> void:
	if attivo != null:
		attivo._accendi("rimbalzo", dove, normale, CIANO)


static func spento(dove: Vector3, normale: Vector3) -> void:
	if attivo != null:
		attivo._accendi("spento", dove, normale, Color(0.92, 0.90, 1.0))


static func ricomparsa(dove: Vector3, colore: Color) -> void:
	if attivo != null:
		attivo._accendi("ricomparsa", dove, Vector3.UP, colore)


static func presa(dove: Vector3, colore: Color) -> void:
	if attivo != null:
		attivo._accendi("presa", dove, Vector3.UP, colore)


## **Scalda le particelle** all'apertura della scena: la prima volta che un tipo si
## accende il motore compila il suo shader, ed è un fotogramma lento proprio sul
## primo colpo (`LEARNED.md` § 26 e 27). Se ne accende uno per tipo davanti alla
## camera, **trasparente**: si disegna — quindi si compila — e non si vede.
func scalda(camera: Camera3D) -> void:
	if camera == null:
		return
	var dove := camera.global_position - camera.global_transform.basis.z * 0.6
	for nome in _riserve:
		_accendi(String(nome), dove, Vector3.UP, Color(1, 1, 1, 0))


## Quante particelle sono accese adesso: serve al collaudo, che deve poter dire se
## un colpo ha fatto schizzare qualcosa senza guardare lo schermo.
func accese(nome: String) -> int:
	var conta := 0
	for nodo in (_riserve[nome]["nodi"] as Array):
		if (nodo as CPUParticles3D).emitting:
			conta += 1
	return conta


# ------------------------------------------------------------------ meccanica

func _accendi(nome: String, dove: Vector3, normale: Vector3, colore: Color) -> void:
	var riserva: Dictionary = _riserve[nome]
	var nodi: Array = riserva["nodi"]
	var quale := int(riserva["prossimo"])
	riserva["prossimo"] = (quale + 1) % nodi.size()
	var particelle := nodi[quale] as CPUParticles3D
	particelle.global_position = dove + normale * 0.04
	if normale.length_squared() > 0.001:
		particelle.direction = normale.normalized()
	particelle.color = colore
	particelle.restart()


func _riserva(nome: String, fabbrica: Callable) -> void:
	var nodi: Array = []
	for i in IN_RISERVA:
		var particelle: CPUParticles3D = fabbrica.call()
		particelle.one_shot = true
		particelle.emitting = false
		particelle.local_coords = false
		particelle.name = "%s_%d" % [nome, i]
		add_child(particelle)
		nodi.append(particelle)
	_riserve[nome] = {"nodi": nodi, "prossimo": 0}


## Un granello: un quadratino sempre girato verso la camera, del colore della
## particella, che sfuma verso la fine. Una forma e un materiale per tipo.
func _granello(misura: float, morbido: bool) -> QuadMesh:
	var forma := QuadMesh.new()
	forma.size = Vector2(misura, misura)
	var pelle := StandardMaterial3D.new()
	pelle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pelle.vertex_color_use_as_albedo = true
	pelle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pelle.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pelle.disable_receive_shadows = true
	if morbido:
		pelle.albedo_texture = _disco()
	forma.material = pelle
	return forma


static var _tondo: GradientTexture2D = null


static func _disco() -> GradientTexture2D:
	if _tondo != null:
		return _tondo
	var sfumatura := Gradient.new()
	sfumatura.set_color(0, Color(1, 1, 1, 1))
	sfumatura.set_color(1, Color(1, 1, 1, 0))
	_tondo = GradientTexture2D.new()
	_tondo.width = 32
	_tondo.height = 32
	_tondo.fill = GradientTexture2D.FILL_RADIAL
	_tondo.fill_from = Vector2(0.5, 0.5)
	_tondo.fill_to = Vector2(1.0, 0.5)
	_tondo.gradient = sfumatura
	return _tondo


## La sfumatura nel tempo: piena per i primi due terzi, poi sparisce.
func _sfuma() -> Gradient:
	var sfumatura := Gradient.new()
	sfumatura.set_color(0, Color(1, 1, 1, 1))
	sfumatura.add_point(0.6, Color(1, 1, 1, 0.9))
	sfumatura.set_color(sfumatura.get_point_count() - 1, Color(1, 1, 1, 0))
	return sfumatura


func _base(quante: int, vita: float, misura: float, morbido: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = quante
	p.lifetime = vita
	p.explosiveness = 1.0
	p.mesh = _granello(misura, morbido)
	p.color_ramp = _sfuma()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _fai_colpo() -> CPUParticles3D:
	var p := _base(18, 0.5, 0.09, false)
	p.spread = 75.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 6.5
	p.gravity = Vector3(0, -11.0, 0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	return p


func _fai_rimbalzo() -> CPUParticles3D:
	var p := _base(10, 0.28, 0.07, true)
	p.spread = 55.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -4.0, 0)
	p.damping_min = 4.0
	p.damping_max = 6.0
	return p


func _fai_spento() -> CPUParticles3D:
	var p := _base(8, 0.35, 0.16, true)
	p.spread = 60.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, 0.6, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.6
	return p


func _fai_ricomparsa() -> CPUParticles3D:
	var p := _base(36, 0.75, 0.14, true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.55
	p.emission_ring_inner_radius = 0.35
	p.emission_ring_height = 0.1
	p.spread = 8.0
	p.initial_velocity_min = 2.2
	p.initial_velocity_max = 4.2
	p.gravity = Vector3.ZERO
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.explosiveness = 0.7
	return p


func _fai_presa() -> CPUParticles3D:
	var p := _base(24, 0.55, 0.12, true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, 1.5, 0)
	p.damping_min = 2.0
	p.damping_max = 3.0
	return p
