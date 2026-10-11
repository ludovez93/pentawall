class_name Impatto
extends Node3D

## **Il colpo che si vede** (tappa 11, blocco C2, 11/10/2026). Dalla diagnosi C1: da noi
## il colpo andava a segno e sul bersaglio non succedeva niente; nei giochi del
## riferimento scoppia una stella, escono gli sbuffi e il colpito si piega
## (`c1-diagnosi.png`, punto 2). Qui la stella e due sbuffi. Il corpo non si piega: chi è
## colpito ricompare subito altrove, e il punto lo segnano la stella e lo sbuffo di
## `Scintille.spento`.
##
## Tutto in quadrati sempre girati verso la camera, senza luce, con la trasparenza: lo
## stesso tipo di materiale del lampo alla bocca, quindi sul telefono niente da compilare.
## Crescono e calano cambiando la misura del quadrato, non la scala del nodo (un quadrato
## girato verso la camera la scala del nodo la ignora, a meno di un interruttore che
## farebbe uno shader nuovo).

const DURATA := 0.42
const STELLA := 2.2      ## metri, al massimo
const SBUFFO := 0.95
const ORO := Color(1.0, 0.86, 0.30)

static var _pelle_stella: StandardMaterial3D = null
static var _pelle_sbuffo: StandardMaterial3D = null

var _vita := 0.0
var _stella: MeshInstance3D
var _sbuffi: Array[MeshInstance3D] = []
var _versi: Array[Vector3] = []


## Un impatto nel punto `dove`, appeso all'arena di chi lo chiede (anche dentro la vetrina
## dell'ingresso, che è un altro mondo).
static func crea(vicino: Node, dove: Vector3) -> Impatto:
	var impatto := Impatto.new()
	var casa := vicino
	while casa != null and not (casa is Arena):
		casa = casa.get_parent()
	(casa if casa != null else vicino).add_child(impatto)
	impatto.top_level = true
	impatto.global_position = dove
	return impatto


func _ready() -> void:
	_stella = _quadro(pelle_stella())
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for k in 2:
		_sbuffi.append(_quadro(pelle_sbuffo()))
		var angolo := rng.randf_range(-0.6, 0.6) + PI * float(k)
		_versi.append(Vector3(cos(angolo), rng.randf_range(0.3, 0.7), sin(angolo)))
	_muovi()


func _process(delta: float) -> void:
	_vita += delta
	if _vita >= DURATA:
		queue_free()
		return
	_muovi()


## La stella si apre in sei centesimi e si chiude entro un terzo di secondo; gli sbuffi
## si gonfiano andando di lato e in su, e poi si sgonfiano.
func _muovi() -> void:
	var t := _vita / DURATA
	var stella := STELLA * (smoothstep(0.0, 0.14, t) * (1.0 - smoothstep(0.35, 0.8, t)))
	(_stella.mesh as QuadMesh).size = Vector2(stella, stella)
	for k in _sbuffi.size():
		var misura := SBUFFO * sin(clampf(t * 1.15, 0.0, 1.0) * PI) * (0.8 + 0.2 * float(k))
		(_sbuffi[k].mesh as QuadMesh).size = Vector2(misura, misura)
		_sbuffi[k].position = _versi[k] * (0.25 + 0.9 * t)


func _quadro(pelle: Material) -> MeshInstance3D:
	var pezzo := MeshInstance3D.new()
	pezzo.mesh = QuadMesh.new()
	pezzo.material_override = pelle
	pezzo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pezzo)
	return pezzo


static func pelle_stella() -> StandardMaterial3D:
	if _pelle_stella == null:
		_pelle_stella = _pelle(_disegna_stella(), ORO)
	return _pelle_stella


static func pelle_sbuffo() -> StandardMaterial3D:
	if _pelle_sbuffo == null:
		var sfumatura := Gradient.new()
		sfumatura.offsets = PackedFloat32Array([0.0, 0.72, 1.0])
		sfumatura.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.95, 0.96, 1.0, 1),
				Color(0.88, 0.90, 1.0, 0.0)])
		var disco := GradientTexture2D.new()
		disco.width = 64
		disco.height = 64
		disco.fill = GradientTexture2D.FILL_RADIAL
		disco.fill_from = Vector2(0.5, 0.5)
		disco.fill_to = Vector2(1.0, 0.5)
		disco.gradient = sfumatura
		_pelle_sbuffo = _pelle(disco, Color(1, 1, 1, 0.92))
	return _pelle_sbuffo


## Le stesse voci del lampo alla bocca (`Corpo._pelle_lampo_bocca`): stesso shader.
static func _pelle(trama: Texture2D, colore: Color) -> StandardMaterial3D:
	var pelle := StandardMaterial3D.new()
	pelle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pelle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pelle.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pelle.albedo_texture = trama
	pelle.albedo_color = colore
	pelle.disable_receive_shadows = true
	return pelle


## Una stella a cinque punte, bianca col bordo arancio: il colore lo dà il materiale,
## il bordo resta più scuro.
static func _disegna_stella() -> ImageTexture:
	var lato := 128
	var fuori := PackedVector2Array()
	var dentro := PackedVector2Array()
	for k in 10:
		var angolo := -PI * 0.5 + PI * float(k) / 5.0
		var raggio := 0.48 if k % 2 == 0 else 0.22
		var punto := Vector2(cos(angolo), sin(angolo))
		fuori.append(Vector2(0.5, 0.52) + punto * raggio)
		dentro.append(Vector2(0.5, 0.52) + punto * raggio * 0.72)
	var immagine := Image.create(lato, lato, false, Image.FORMAT_RGBA8)
	immagine.fill(Color(0, 0, 0, 0))
	for y in lato:
		for x in lato:
			var p := Vector2((float(x) + 0.5) / lato, (float(y) + 0.5) / lato)
			if Geometry2D.is_point_in_polygon(p, dentro):
				immagine.set_pixel(x, y, Color(1, 1, 1, 1))
			elif Geometry2D.is_point_in_polygon(p, fuori):
				immagine.set_pixel(x, y, Color(1.0, 0.45, 0.12, 1))
	return ImageTexture.create_from_image(immagine)
