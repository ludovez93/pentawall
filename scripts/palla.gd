class_name Palla
extends RigidBody3D

## **Una palla della PALLA** (tappa 11, blocco D2).
##
## Nel 1999 il BallBlast aveva sei palle colorate — blu 750, verde 1.000, gialla 1.250,
## arancione 1.500, rossa 1.750, viola 2.000 — e la dorata da 5.000, che compariva solo
## quando qualcuno le aveva segnate tutte e sei (`RICERCA-ORIGINALE.md` § 2). Da noi i
## valori sono divisi per dieci, che è il nostro rapporto fra un colpo e un'eliminazione:
## 75, 100, 125, 150, 175, 200 e la dorata 500 (`PLAN.md`, tappa 11, blocco D2).
##
## Com'è fatta (*mio*, dal piano): grande, a spicchi bianchi e colorati come un pallone da
## spiaggia, col valore scritto sopra. Quattro colori su sette sono anche quelli delle sfere
## dei potenziamenti: le distingue la forma, la palla rotola a terra e la sfera sta sospesa
## e si accende.
##
## Tre stati: **libera** (rotola, rimbalza, si prende passandoci sopra), **portata** (gira
## piccola intorno a chi la porta) e **lanciata** (vola ad arco; chi l'ha lanciata è
## l'autore del gol, finché qualcuno non la prende). Le regole — chi la prende, chi segna,
## la dorata — le tengono `Palle` e l'arena.

## I sette valori e i sette colori, nell'ordine del 1999. L'ultima è la dorata.
const VALORI := [75, 100, 125, 150, 175, 200, 500]
const COLORI: Array[Color] = [
	Color(0.18, 0.44, 1.0),   # blu
	Color(0.16, 0.80, 0.32),  # verde
	Color(1.0, 0.90, 0.18),   # gialla
	Color(1.0, 0.50, 0.10),   # arancione
	Color(0.96, 0.18, 0.18),  # rossa
	Color(0.62, 0.26, 0.96),  # viola
	Color(1.0, 0.70, 0.10),   # dorata
]
const DORATA := 6

const RAGGIO := 0.4
## Le palle cadono come i corpi (950 u/s² del 1999, `Giocatore.GRAVITA`), non con la gravità
## di serie del motore.
const GRAVITA := 18.1
## Portata, sta piccola sulla schiena di chi la porta.
const SCALA_PORTATA := 0.42
## Il freno dell'aria, al secondo: lo stesso usa `Palle.traiettoria`, così la strada
## disegnata è quella vera. Al posto di quello di serie del progetto, non sommato.
const FRENO_IN_VOLO := 0.05
const FRENO_DEL_GIRO := 1.2

var indice := 0
var valore := 75
var colore := Color.WHITE
## Chi la porta adesso, o nessuno.
var portata_da: Node3D = null
## Chi l'ha lanciata per ultimo: è lui che segna se entra in porta. Si perde quando qualcuno
## la prende.
var lanciata_da: Node3D = null
## Da quanto è in campo senza che nessuno la tocchi: serve a ritrovare le palle perse.
var ferma_da := 0.0
## Fino a quando chi l'ha appena lanciata non la riprende: un secondo, o gli resterebbe in mano.
var _intoccabile_per: Node3D = null
var _intoccabile_fino := 0.0
var _numero: Label3D
var _globo: MeshInstance3D
var _in_campo := false


static func crea(genitore: Node, quale: int) -> Palla:
	var palla := Palla.new()
	palla.indice = quale
	palla.valore = int(VALORI[quale])
	palla.colore = COLORI[quale]
	palla.name = "palla_%d" % quale
	genitore.add_child(palla)
	return palla


func _ready() -> void:
	mass = 0.6
	gravity_scale = GRAVITA / float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	continuous_cd = true
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = FRENO_IN_VOLO
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = FRENO_DEL_GIRO
	var materiale := PhysicsMaterial.new()
	materiale.bounce = 0.55
	materiale.friction = 0.7
	physics_material_override = materiale
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	var forma := CollisionShape3D.new()
	var sfera := SphereShape3D.new()
	sfera.radius = RAGGIO
	forma.shape = sfera
	add_child(forma)
	_costruisci()
	fuori_campo()


## In campo e libera, ferma o che rotola.
func libera() -> bool:
	return _in_campo and portata_da == null


func in_campo() -> bool:
	return _in_campo


## Si può prendere adesso, da `chi`? Chi l'ha appena lanciata no, per un secondo.
func si_prende(chi: Node3D, adesso: float) -> bool:
	return libera() and not (chi == _intoccabile_per and adesso < _intoccabile_fino)


## Fuori dal campo: né si vede né si tocca. È la dorata prima del suo momento, e una palla
## segnata mentre torna dal cannone.
func fuori_campo() -> void:
	_in_campo = false
	portata_da = null
	lanciata_da = null
	visible = false
	freeze = true
	collision_layer = 0
	collision_mask = 0


## Presa: smette di rotolare e gira intorno a chi la porta.
func prendi(chi: Node3D) -> void:
	portata_da = chi
	lanciata_da = null
	freeze = true
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	# Si rimpicciolisce il globo, non il corpo: la scala di un corpo fisico la rimette il
	# motore (scatto del 23/10/2026, le palle sulla schiena erano grandi come chi le porta).
	_globo.scale = Vector3.ONE * SCALA_PORTATA
	_numero.visible = false
	ferma_da = 0.0


## In campo, libera, in `dove` con la spinta data: lasciata cadere, sparata da un cannone,
## lanciata. `autore` è chi segna se entra in porta (nessuno se cade o esce da un cannone);
## `escluso` chi non la può riprendere per un secondo — chi l'ha lanciata, o chi l'ha persa
## perché colpito, che se no se la riprende prima di sparire (collaudo del 23/10/2026).
func in_campo_da(dove: Vector3, spinta: Vector3, autore: Node3D = null, adesso := 0.0,
		escluso: Node3D = null) -> void:
	_in_campo = true
	visible = true
	portata_da = null
	lanciata_da = autore
	_intoccabile_per = escluso if escluso != null else autore
	_intoccabile_fino = adesso + 1.0
	_globo.scale = Vector3.ONE
	_numero.visible = true
	collision_layer = Strati.PALLE
	collision_mask = Strati.SOLIDO
	freeze = false
	global_position = dove
	linear_velocity = spinta
	angular_velocity = Vector3.ZERO
	ferma_da = 0.0


## Mentre è portata: dove sta, girandole intorno.
func segui(dove: Vector3) -> void:
	global_position = dove


## Il globo a spicchi: sedici spicchi dal polo al polo, uno bianco e uno colorato. I colori
## stanno nei vertici, così basta un materiale per tutte e sette.
func _costruisci() -> void:
	_globo = MeshInstance3D.new()
	_globo.mesh = Palla.globo(colore, RAGGIO)
	_globo.material_override = Palla.pelle(indice == DORATA)
	add_child(_globo)

	_numero = Avversario.targhetta("%d" % valore)
	_numero.font_size = 96
	if _numero.fixed_size:
		_numero.pixel_size = 0.0008
	else:
		_numero.pixel_size = 0.005
	_numero.modulate = Color(colore.r, colore.g, colore.b, 0.98).lightened(0.25)
	_numero.position = Vector3(0, RAGGIO + 0.55, 0)
	add_child(_numero)


static var _pelli := {}


## Il materiale delle palle: il colore dai vertici, lucido. La dorata è un po' metallo.
static func pelle(dorata: bool) -> StandardMaterial3D:
	if not _pelli.has(dorata):
		var materiale := StandardMaterial3D.new()
		materiale.vertex_color_use_as_albedo = true
		materiale.roughness = 0.3
		materiale.metallic = 0.45 if dorata else 0.0
		_pelli[dorata] = materiale
	return _pelli[dorata]


## Una sfera a spicchi coi colori nei vertici, ogni spicchio coi suoi (non condivisi coi
## vicini, o i colori sfumerebbero fra uno spicchio e l'altro).
static func globo(tinta: Color, raggio: float, spicchi := 16, anelli := 10) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bianco := Color(0.96, 0.96, 0.98)
	for s in spicchi:
		var c := tinta if s % 2 == 0 else bianco
		var a0 := TAU * float(s) / float(spicchi)
		var a1 := TAU * float(s + 1) / float(spicchi)
		for r in anelli:
			var t0 := PI * float(r) / float(anelli)
			var t1 := PI * float(r + 1) / float(anelli)
			var p00 := Vector3(sin(t0) * cos(a0), cos(t0), sin(t0) * sin(a0))
			var p01 := Vector3(sin(t0) * cos(a1), cos(t0), sin(t0) * sin(a1))
			var p10 := Vector3(sin(t1) * cos(a0), cos(t1), sin(t1) * sin(a0))
			var p11 := Vector3(sin(t1) * cos(a1), cos(t1), sin(t1) * sin(a1))
			# In senso orario visti da fuori: per Godot è il davanti (`LEARNED.md` § 42).
			for p in [p00, p10, p11, p00, p11, p01]:
				st.set_color(c)
				st.set_normal(p)
				st.add_vertex(p * raggio)
	return st.commit()
