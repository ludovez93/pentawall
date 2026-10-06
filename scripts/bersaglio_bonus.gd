class_name BersaglioBonus
extends StaticBody3D

## **Un bersaglio bonus** (tappa 11, blocco F). Dal telefono, il 06/10/2026: *«manca dove
## sparare per prendere bonus come nel gioco originale»*.
##
## Nel 1999 erano i `winky_target` (`RICERCA-ORIGINALE.md` § 2, letti nelle otto mappe
## dello scontro): un disco appeso dove lo metteva chi disegnava la mappa, che colpito
## con qualunque arma dava i suoi punti a chi sparava, girava mostrando il valore e poi
## restava spento per un tempo che cresceva col valore. Questo è lo stesso, con due
## differenze nostre:
##
## - **i numeri**: 100, 200 e 400 invece di 250, 500 e 1.000. Là un'eliminazione voleva
##   più colpi e lasciava a terra una pillola da 250-1.000; da noi ogni colpo vale 25, e
##   un bersaglio da 1.000 varrebbe la partita.
## - **il tempo da spento** è tarato sulla partita da tre minuti (misura F0, `PLAN.md`):
##   chi resta fermo davanti a un bersaglio per tutta la partita non arriva ai punti di
##   chi gioca, e quello da 400 si accende una volta sola.
##
## Si prende dritto o di sponda, e vale il numero che porta scritto: qui la sponda non
## raddoppia (`DECISIONI.md` § 20). Lo prendono anche gli avversari, quando non hanno
## nessuno da attaccare (`Avversario.bonus`).

## Colpito: chi l'ha preso e quanto vale. I punti doppi li conta l'arena.
signal preso(chi: Object, punti: int)

## Un metro e sessanta di disco. Da un metro, negli scatti da dodici metri era una moneta di
## venti pixel e il numero non si leggeva; nel 1999 chi disegnava la mappa li faceva spesso
## una volta e mezzo o due la misura normale (`DrawScale` 1,5-2).
const RAGGIO := 0.8
const SPESSORE := 0.1
## Quanto gira dopo il colpo, mostrando ancora i colori: poi si spegne.
const GIRA := 1.2
const VELOCITA_GIRO := 14.0

const ORO := Color(1.0, 0.74, 0.16)
const BIANCO := Color(0.95, 0.95, 0.97)
const BORDO := Color(0.10, 0.13, 0.32)
const GRIGIO := Color(0.34, 0.35, 0.42)
const NUMERO := Color(0.08, 0.10, 0.26)

var valore := 100
## Secondi di buio dopo il colpo, giro compreso.
var spento_per := 60.0
## Chi decide se un colpo adesso conta: prima del via e a partita finita no. Senza,
## conta sempre (il banco di prova).
var conta := Callable()

var _spento := 0.0
var _gira := 0.0
var _faccia: Node3D
var _anelli: Array[MeshInstance3D] = []
var _accesi: Array[Material] = []
var _grigio: StandardMaterial3D
var _numero: Label3D


## `giro`: in gradi, dove guarda il disco — 0 verso sud (+z), 90 verso est (+x).
static func crea(genitore: Node, dove: Vector3, giro: float, punti: int,
		spento: float) -> BersaglioBonus:
	var bersaglio := BersaglioBonus.new()
	bersaglio.valore = punti
	bersaglio.spento_per = spento
	genitore.add_child(bersaglio)
	bersaglio.global_position = dove
	bersaglio.rotation_degrees.y = giro
	return bersaglio


func _ready() -> void:
	collision_layer = Strati.BERSAGLIO
	collision_mask = 0
	_costruisci()


func acceso() -> bool:
	return _spento <= 0.0


## Il centro del disco, dove mira chi gli spara.
func centro() -> Vector3:
	return global_position


## La stessa firma di chiunque si possa colpire (`Avversario.incassa`): vero se il colpo
## è valso punti.
func incassa(_muri: int, da: Object = null) -> bool:
	if _spento > 0.0:
		return false
	if conta.is_valid() and not bool(conta.call()):
		return false
	_spento = spento_per
	_gira = GIRA
	collision_layer = 0
	Suoni.bersaglio_preso(global_position)
	preso.emit(da, valore)
	return true


## Di nuovo acceso, fermo e di faccia: si riparte da zero.
func riparti() -> void:
	_spento = 0.0
	_gira = 0.0
	_faccia.rotation = Vector3.ZERO
	_colori(true)
	collision_layer = Strati.BERSAGLIO


func _process(delta: float) -> void:
	if _gira > 0.0:
		_gira -= delta
		_faccia.rotate_y(VELOCITA_GIRO * delta)
		if _gira <= 0.0:
			_faccia.rotation = Vector3.ZERO
			_colori(false)
	if _spento > 0.0:
		_spento -= delta
		if _spento <= 0.0:
			riparti()
			Suoni.bersaglio_acceso(global_position)


func _colori(acceso_: bool) -> void:
	for i in _anelli.size():
		_anelli[i].material_override = _accesi[i] if acceso_ else _grigio
	_numero.visible = acceso_


func _costruisci() -> void:
	# La forma che si colpisce: il disco intero, fermo anche quando la faccia gira.
	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = RAGGIO
	cilindro.height = SPESSORE
	forma.shape = cilindro
	forma.rotation_degrees = Vector3(90, 0, 0)
	add_child(forma)

	_faccia = Node3D.new()
	add_child(_faccia)
	# Il retro scuro e tre anelli davanti, ognuno un dito più avanti dell'altro: mai due
	# facce nello stesso piano (`tools/facce_doppie.gd`).
	var pezzi := [
		{"raggio": RAGGIO, "alto": SPESSORE, "avanti": 0.0, "colore": BORDO},
		{"raggio": RAGGIO * 0.9, "alto": 0.02, "avanti": SPESSORE * 0.5 + 0.007, "colore": ORO},
		{"raggio": RAGGIO * 0.66, "alto": 0.02, "avanti": SPESSORE * 0.5 + 0.013, "colore": BIANCO},
		{"raggio": RAGGIO * 0.4, "alto": 0.02, "avanti": SPESSORE * 0.5 + 0.019, "colore": ORO},
	]
	_grigio = _materiale(GRIGIO, 0.12)
	for pezzo in pezzi:
		var anello := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = pezzo["raggio"]
		mesh.bottom_radius = pezzo["raggio"]
		mesh.height = pezzo["alto"]
		mesh.radial_segments = 24
		anello.mesh = mesh
		anello.rotation_degrees = Vector3(90, 0, 0)
		anello.position = Vector3(0, 0, pezzo["avanti"])
		anello.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var materiale := _materiale(pezzo["colore"], 0.35)
		anello.material_override = materiale
		_faccia.add_child(anello)
		_anelli.append(anello)
		_accesi.append(materiale)

	# Il numero, scritto come le scritte dell'arena (`Vestizione._campo_del_catino`):
	# stesso carattere e stesse impostazioni, così sul telefono non nasce uno shader nuovo.
	_numero = Label3D.new()
	_numero.text = str(valore)
	_numero.font = Vestizione.carattere_insegne()
	_numero.font_size = 160
	_numero.pixel_size = 0.0038
	_numero.position = Vector3(0, 0, SPESSORE * 0.5 + 0.032)
	_numero.modulate = NUMERO
	_numero.outline_size = 0
	_numero.shaded = false
	_numero.double_sided = true
	_numero.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	_faccia.add_child(_numero)


## Lo stesso materiale dei bersagli del poligono (`Bersaglio`): colore, un filo di luce
## propria sotto la soglia del bagliore. Cambiano i valori, non lo shader.
func _materiale(colore: Color, luce: float) -> StandardMaterial3D:
	var materiale := StandardMaterial3D.new()
	materiale.albedo_color = colore
	materiale.emission_enabled = true
	materiale.emission = colore
	materiale.emission_energy_multiplier = luce
	materiale.roughness = 0.5
	return materiale
