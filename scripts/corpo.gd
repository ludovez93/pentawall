class_name Corpo
extends Node3D

## Un concorrente con un corpo vero, che si muove (tappa 8, blocco D).
##
## Fino al 03/10/2026 in partita c'erano capsule che scivolavano: niente gambe,
## niente faccia, nessuna animazione. I corpi buoni c'erano già — gli umani di
## Quaternius, scelti da Ludovico il 12/09/2026 — ma vivevano solo nell'attrezzo
## degli scatti. Qui diventano il corpo di tutti: tuo e dei cinque avversari.
##
## Cosa fa:
## - **corre con la velocità vera dei piedi**: fermo, corsetta e scatto si mescolano
##   secondo la velocità, e il passo accelera o rallenta con lei — niente piedi che
##   pattinano;
## - **il busto mira mentre le gambe corrono** (`Torsione`): si può correre di lato e
##   all'indietro continuando a puntare il blaster dove si guarda;
## - **salta, spara, accusa il colpo** con le animazioni della libreria;
## - porta **la divisa** (`tuta.gdshader`): tuta, inserti, guanti, scarpe.
##
## Non tocca la fisica né le regole: chi lo porta resta una capsula per il motore,
## e il dardo continua a partire dalla canna di sempre. Cambia solo cosa si vede.
##
## Tutto il materiale è libero (`assets/LICENZE.md`): corpi, capelli e animazioni
## Quaternius (CC0), blaster Kenney (CC0).

const MODELLI := "res://assets/models/quaternius/base/"
const ANIMAZIONI := "res://assets/models/quaternius/UAL1_Standard.glb"
const CAPELLI := "res://assets/models/quaternius/capelli/"
const TUTA := "res://assets/materials/tuta.gdshader"
const BLASTER := "res://assets/models/kenney/blaster/blaster-a.glb"

## **Chi è chi.** Sei facce diverse, riconoscibili a vista: il contorno lime dice
## «avversario», il corpo dice **quale**. Le tute evitano i tre colori che parlano —
## l'arancio del dardo, il ciano delle sponde, il lime del contorno — e il viola del
## neon dell'arena. *Scelte di lavorazione del 03/10/2026, rifacibili.*
const PERSONAGGI := {
	"TU": {"sesso": "Male", "tuta": Color(0.13, 0.36, 0.95), "secondo": Color(0.95, 0.95, 0.97),
			"capelli": ["Hair_SimpleParted"], "tinta_capelli": Color(0.55, 0.36, 0.22)},
	"BRACE": {"sesso": "Male", "tuta": Color(0.84, 0.12, 0.20), "secondo": Color(0.12, 0.12, 0.14),
			"capelli": ["Hair_Buzzed", "Hair_Beard"], "tinta_capelli": Color(0.16, 0.12, 0.10)},
	"QUARZO": {"sesso": "Female", "tuta": Color(0.90, 0.91, 0.95), "secondo": Color(0.26, 0.30, 0.46),
			"capelli": ["Hair_Buns"], "tinta_capelli": Color(1.0, 0.92, 0.78)},
	"LAMPO": {"sesso": "Female", "tuta": Color(0.98, 0.80, 0.12), "secondo": Color(0.12, 0.12, 0.14),
			"capelli": ["Hair_BuzzedFemale"], "tinta_capelli": Color(0.14, 0.11, 0.10)},
	"NEBBIA": {"sesso": "Female", "tuta": Color(0.90, 0.30, 0.64), "secondo": Color(0.96, 0.96, 0.98),
			"capelli": ["Hair_Long"], "tinta_capelli": Color(0.42, 0.18, 0.14)},
	"TORO": {"sesso": "Male", "tuta": Color(0.15, 0.15, 0.18), "secondo": Color(0.84, 0.12, 0.20),
			"capelli": ["Hair_SimpleParted", "Hair_Beard"], "tinta_capelli": Color(0.28, 0.20, 0.14)},
}

## L'altezza del modello nel file, e quella dei corpi del gioco (la capsula del
## giocatore e dell'avversario, che sono alte uguali).
const ALTEZZA_MODELLO := 1.8
const ALTEZZA_CORPO := 1.8

## Le velocità a cui le due corse della libreria **appoggiano i piedi senza
## scivolare**, misurate sui piedi del modello il 03/10/2026 (escursione del piede
## a terra diviso il tempo d'appoggio): la corsetta a 3,5 m/s, lo scatto a 6,3.
## Il gioco corre a 7,62: lo scatto si accelera di un quinto, e regge.
const VELOCITA_CORSETTA := 3.5
const VELOCITA_SCATTO := 6.3

## Oltre questo angolo fra dove si guarda e dove si va, non si gira più il bacino:
## si corre all'indietro, con il busto sulla mira.
const LIMITE_INDIETRO := deg_to_rad(110.0)
const GIRO_MASSIMO_GAMBE := deg_to_rad(80.0)

## Le ossa del busto: è qui che vivono la mira, lo sparo e il colpo incassato,
## mentre le gambe continuano a fare quello che dice la corsa.
const OSSA_BUSTO := ["spine_02", "spine_03", "neck_01", "Head",
		"clavicle_l", "upperarm_l", "lowerarm_l", "hand_l",
		"clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"]
const DITA := ["index", "middle", "pinky", "ring", "thumb"]

const DURATA_LAMPO_BOCCA := 0.06

## **Il ritmo delle animazioni** (04/10/2026). In Compatibility uno scheletro che si
## muove costa tre volte: l'albero delle animazioni lo calcola, lo scheletro rimanda
## le sue ossa al motore di disegno, e **ogni pezzo del corpo si deforma con un
## passaggio suo sulla scheda** (`mesh_storage.cpp` di 4.7.2). Con la torsione del
## busto lo scheletro si ricalcolava a ogni fotogramma, per tutti e sei. Nel browser
## del PC fermare gli scheletri vale quanto togliere i corpi: da 42-47 a 25 ms a
## fotogramma (`BancoScheda`, 04/10/2026). Adesso chi è vicino si anima a ogni
## fotogramma, chi è lontano uno sì e uno no o uno su tre, e chi sta fuori
## dall'inquadratura uno su quattro: a venti metri, su un telefono, trenta passi al
## secondo non si distinguono da sessanta. Misurato nello stesso browser alternando
## le due regole: 37 ms a fotogramma contro 42, in quattro coppie su quattro.
const RITMO_VICINO := 10.0   ## metri dalla camera: fin qui, ogni fotogramma
const RITMO_MEDIO := 25.0    ## fin qui uno su due; oltre, uno su tre
const OGNI_FUORI := 4        ## fuori dall'inquadratura: uno su quattro
const RAGGIO_INQUADRATO := 1.2  ## un corpo è inquadrato se ne entra anche solo un pezzo
## Tutti a ogni fotogramma, come prima del 04/10/2026: lo accende solo il banco della
## scheda video (`BancoScheda`), per misurare quanto vale il ritmo.
static var ritmo_pieno := false

static var _libreria: AnimationLibrary = null

## **Modelli, capelli, blaster e la tuta, letti una volta per tutto il gioco**
## (tappa 9). Con `load` restavano in memoria solo finché qualcuno li usava: chiuso
## l'ingresso si buttavano, e il primo avversario in campo li rileggeva — 1,3 secondi
## per il primo corpo femminile, misurato sul PC il 03/10/2026, di più sul telefono.
## E con loro se ne andavano i loro shader, da ricompilare.
static var _letti := {}


static func _leggi(percorso: String) -> Resource:
	if not _letti.has(percorso):
		_letti[percorso] = load(percorso)
	return _letti[percorso]

var chi := "BRACE"

var _modello: Node3D
var _scheletro: Skeleton3D
var _albero: AnimationTree
var _torsione: Torsione
var _materiale: ShaderMaterial
var _blaster: Node3D
var _lampo_bocca: MeshInstance3D
var _vita_lampo_bocca := 0.0
var _angolo_gambe := 0.0
var _in_aria := 0.0
var _lampo := 0.0
var _lampeggio := false
## Quanti fotogrammi sono passati dall'ultimo passo dell'animazione, e quanto tempo.
## Si parte «in ritardo», così il primo fotogramma in scena ha già la sua posa.
var _turno := 1 << 20
var _accumulato := 0.0
## Le passate del contorno: per ogni pezzo di pelle, il materiale e il primo guscio
## da appendergli dietro (`contorni`).
var _contorno: Array = []
var _contorno_acceso := false


static func crea(nome: String) -> Corpo:
	var corpo := Corpo.new()
	corpo.chi = nome if PERSONAGGI.has(nome) else "BRACE"
	corpo.name = "Corpo"
	corpo._costruisci()
	return corpo


## I colori della squadra di un concorrente: servono a chi disegna intorno a lui
## (la targhetta col nome, le particelle del colpo).
static func colore_di(nome: String) -> Color:
	var dati: Dictionary = PERSONAGGI.get(nome, PERSONAGGI["BRACE"])
	return dati["tuta"]


func _process(delta: float) -> void:
	_accumulato += delta
	_turno += 1
	if _turno >= _ogni():
		_albero.advance(_accumulato)
		_scheletro.advance(_accumulato)
		_accumulato = 0.0
		_turno = 0
	if _vita_lampo_bocca > 0.0:
		_vita_lampo_bocca -= delta
		var quota := clampf(_vita_lampo_bocca / DURATA_LAMPO_BOCCA, 0.0, 1.0)
		_lampo_bocca.visible = _vita_lampo_bocca > 0.0
		_lampo_bocca.scale = Vector3.ONE * (0.6 + 0.6 * (1.0 - quota))
	if _lampo > 0.0:
		_lampo = maxf(_lampo - delta, 0.0)
	if _materiale == null:
		return
	var luce := 0.0
	if _lampo > 0.0:
		luce = 2.2 * (_lampo / 0.12)
	elif _lampeggio:
		luce = 0.55
	_materiale.set_shader_parameter("lampo", luce)


## Ogni quanti fotogrammi questo corpo fa un passo d'animazione: dipende da dove sta
## rispetto alla camera che disegna.
func _ogni() -> int:
	if ritmo_pieno:
		return 1
	if not is_visible_in_tree():
		return OGNI_FUORI
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return 1
	var centro := global_position + Vector3(0.0, ALTEZZA_CORPO * 0.5, 0.0)
	for piano in camera.get_frustum():
		if piano.distance_to(centro) > RAGGIO_INQUADRATO:
			return OGNI_FUORI
	var distanza := camera.global_position.distance_to(centro)
	if distanza < RITMO_VICINO:
		return 1
	return 2 if distanza < RITMO_MEDIO else 3


# ------------------------------------------------------------------ comandi

## Il corpo segue chi lo porta: velocità nel mondo, piedi a terra o no, e la
## pendenza della mira (positiva in su, in radianti). Si chiama una volta per
## fotogramma.
func aggiorna(velocita: Vector3, a_terra: bool, pendenza: float, delta: float) -> void:
	var base := global_transform.basis.orthonormalized()
	var locale := base.inverse() * velocita
	# x a destra, y in avanti: avanti per il corpo è −Z.
	var piano := Vector2(locale.x, -locale.z)
	var quanto := piano.length()

	var voluto := 0.0
	var indietro := false
	if quanto > 0.6:
		# Positivo verso sinistra, come le rotazioni attorno a +Y.
		voluto = atan2(-piano.x, piano.y)
		if absf(voluto) > LIMITE_INDIETRO:
			indietro = true
			voluto = wrapf(voluto - PI, -PI, PI)
		voluto = clampf(voluto, -GIRO_MASSIMO_GAMBE, GIRO_MASSIMO_GAMBE)
	_angolo_gambe = lerp_angle(_angolo_gambe, voluto, 1.0 - exp(-delta * 12.0))
	_modello.rotation.y = PI + _angolo_gambe
	_torsione.angolo = -_angolo_gambe

	_albero.set("parameters/corsa/blend_position", clampf(quanto, 0.0, VELOCITA_SCATTO))
	var naturale := VELOCITA_CORSETTA
	if quanto > VELOCITA_CORSETTA:
		naturale = lerpf(VELOCITA_CORSETTA, VELOCITA_SCATTO,
				clampf((quanto - VELOCITA_CORSETTA) / (VELOCITA_SCATTO - VELOCITA_CORSETTA), 0.0, 1.0))
	var ritmo := 1.0
	if quanto > 0.6:
		ritmo = clampf(quanto / naturale, 0.55, 1.45)
	_albero.set("parameters/passo/scale", -ritmo if indietro else ritmo)

	_in_aria = move_toward(_in_aria, 0.0 if a_terra else 1.0, delta * 7.0)
	_albero.set("parameters/aria/blend_amount", _in_aria)
	_albero.set("parameters/mira/blend_position", clampf(pendenza / deg_to_rad(55.0), -1.0, 1.0))


## Lo sparo: il busto rincula e alla bocca del blaster si accende un lampo.
func spara() -> void:
	_albero.set("parameters/sparo/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	if _lampo_bocca != null:
		_lampo_bocca.global_position = bocca()
		_lampo_bocca.visible = true
		_vita_lampo_bocca = DURATA_LAMPO_BOCCA


## Scalda il lampo dello sparo: si disegna una volta, trasparente, davanti alla
## camera, così il primo colpo vero trova lo shader già pronto (`LEARNED.md` § 26).
func scalda(camera: Camera3D) -> void:
	if camera == null or _lampo_bocca == null:
		return
	var pelle := _lampo_bocca.material_override as StandardMaterial3D
	var colore := pelle.albedo_color
	pelle.albedo_color = Color(colore.r, colore.g, colore.b, 0.0)
	_lampo_bocca.global_position = camera.global_position - camera.global_transform.basis.z * 0.6
	_lampo_bocca.visible = true
	var chi := get_instance_id()
	get_tree().create_timer(0.2).timeout.connect(func() -> void:
		var io := instance_from_id(chi) as Corpo
		pelle.albedo_color = colore
		if io != null and is_instance_valid(io) and io._vita_lampo_bocca <= 0.0:
			io._lampo_bocca.visible = false)


## Il colpo incassato: il busto accusa e la divisa fa luce per un decimo di secondo.
func colpito() -> void:
	_albero.set("parameters/colpo/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_lampo = 0.12


## Il lampeggio dell'immunità, acceso e spento da chi la conta.
func lampeggia(acceso: bool) -> void:
	_lampeggio = acceso


## Dove sta la bocca del blaster in questo momento: la punta della scatola del
## modello più avanti nella direzione in cui guarda il corpo. Serve al lampo, non al
## dardo — il dardo parte dalla canna del gioco, come sempre.
func bocca() -> Vector3:
	if _blaster == null:
		return global_position + Vector3(0, 1.4, 0)
	# Nel file la canna guarda verso +Z del blaster.
	var avanti := _blaster.global_transform.basis.z.normalized()
	var migliore := _blaster.global_position
	var quanto := -INF
	for nodo in _tutti(_blaster):
		if not (nodo is MeshInstance3D):
			continue
		var pezzo := nodo as MeshInstance3D
		var scatola := pezzo.get_aabb()
		for i in 8:
			var angolo := pezzo.global_transform * scatola.get_endpoint(i)
			var d := angolo.dot(avanti)
			if d > quanto:
				quanto = d
				migliore = angolo
	return migliore


## I due gusci del contorno, solo sulla pelle che si vede da fuori: corpo e capelli.
## Occhi e sopracciglia stanno dentro la testa, e un contorno su di loro sarebbe
## lavoro della scheda video per niente. `quota_filo` è lo spessore del filo scuro
## rispetto al contorno acceso (lo decide chi porta il corpo). Torna
## `{materiale, quota}`; si accendono e si spengono con `accendi_contorni`.
##
## **Sono due passate in più dello stesso pezzo, non due copie** (04/10/2026). Fino ad
## allora ogni guscio era una copia del corpo, e in Compatibility ogni copia di un
## corpo animato si deforma per conto suo: tre deformazioni del corpo intero per ogni
## avversario dentro i quindici metri. Una passata in più disegna di nuovo il corpo
## già deformato.
func contorni(scuro: Color, acceso: Color, quota_filo: float) -> Array:
	var fuori := []
	_contorno.clear()
	for nodo in _tutti(_modello):
		if not (nodo is MeshInstance3D):
			continue
		var pezzo := nodo as MeshInstance3D
		if pezzo.name.begins_with("Eye") or _e_blaster(pezzo):
			continue
		# La passata si appende al materiale del pezzo, che dev'essere solo suo: il
		# corpo ha già la sua tuta, i capelli la loro tinta.
		if pezzo.material_override == null:
			pezzo.material_override = pezzo.get_active_material(0).duplicate()
		var filo := pelle_contorno(scuro)
		var esterno := pelle_contorno(acceso)
		filo.next_pass = esterno
		_contorno.append([pezzo.material_override, filo])
		fuori.append({"materiale": filo, "quota": quota_filo})
		fuori.append({"materiale": esterno, "quota": 1.0})
	_contorno_acceso = false
	accendi_contorni(true)
	return fuori


## Il contorno acceso o spento. Spento non vuol dire trasparente: le passate se ne
## vanno, e la scheda non disegna niente in più.
func accendi_contorni(acceso: bool) -> void:
	if acceso == _contorno_acceso:
		return
	_contorno_acceso = acceso
	for coppia in _contorno:
		(coppia[0] as Material).next_pass = coppia[1] if acceso else null


func contorni_accesi() -> bool:
	return _contorno_acceso


## **Il blaster dritto sulla mira.** La mano della posa di mira è girata come la
## fa girare l'animazione, e un blaster appeso così com'è usciva con la canna verso
## il soffitto (visto negli scatti del 03/10/2026). Qui lo si raddrizza una volta,
## alla costruzione: si mette lo scheletro **nella posa di mira dritta** letta dalla
## libreria, si guarda dove sta la mano, e si gira il blaster perché la canna vada
## dove guarda il corpo e l'impugnatura scenda verso terra. Da lì in poi il blaster
## segue la mano — rinculo, corsa, colpo incassato — senza altri conti.
##
## Tutto nello spazio del corpo e con le trasformazioni locali: il corpo qui non è
## ancora nella scena, e la posa non dipende da cosa sta facendo l'animazione in
## quel momento (un primo tentativo la leggeva al secondo fotogramma, e chi stava
## già sparando si ritrovava il blaster girato di lato).
const PRESA := Vector3(0.0, -0.035, -0.06)  ## dal polso al palmo: un filo sotto, un filo avanti
const MISURA_BLASTER := 0.7


func _fissa_il_blaster() -> void:
	var mano := _scheletro.find_bone("hand_r")
	var posa_di_mira := libreria().get_animation(&"Pistol_Aim_Neutral") if libreria() != null else null
	if mano < 0 or posa_di_mira == null or _blaster == null:
		return
	# Le pose locali della posa di mira, osso per osso. Il conto della mano si fa a
	# mano, risalendo la catena delle ossa: fuori dalla scena lo scheletro non
	# ricalcola le sue pose globali, e si leggerebbe la posa di riposo, a braccia
	# aperte (successo al primo tentativo: blaster con la canna al soffitto).
	var locali := {}
	for traccia in posa_di_mira.get_track_count():
		var osso := _scheletro.find_bone(String(posa_di_mira.track_get_path(traccia)).get_slice(":", 1))
		if osso < 0:
			continue
		var t: Transform3D = locali.get(osso, _scheletro.get_bone_rest(osso))
		match posa_di_mira.track_get_type(traccia):
			Animation.TYPE_ROTATION_3D:
				var q := posa_di_mira.rotation_track_interpolate(traccia, 0.0)
				t = Transform3D(Basis(q).scaled(t.basis.get_scale()), t.origin)
			Animation.TYPE_POSITION_3D:
				t.origin = posa_di_mira.position_track_interpolate(traccia, 0.0)
		locali[osso] = t
	var catena_ossa: Array[int] = []
	var o := mano
	while o >= 0:
		catena_ossa.push_front(o)
		o = _scheletro.get_bone_parent(o)
	var mano_nello_scheletro := Transform3D()
	for b in catena_ossa:
		mano_nello_scheletro = mano_nello_scheletro * (locali.get(b, _scheletro.get_bone_rest(b)) as Transform3D)
	# Dal corpo allo scheletro: il modello girato e scalato, l'armatura, lo scheletro.
	var catena := _modello.transform
	var nodo: Node = _scheletro
	var passi: Array[Transform3D] = []
	while nodo != _modello and nodo != null:
		passi.push_front((nodo as Node3D).transform)
		nodo = nodo.get_parent()
	for passo in passi:
		catena = catena * passo
	var mano_nel_corpo := catena * mano_nello_scheletro
	var scala := mano_nel_corpo.basis.get_scale().x
	# La canna del blaster guarda verso +Z nel suo file; il corpo guarda verso −Z.
	var voluta := Basis(Vector3.UP, PI).scaled(Vector3.ONE * MISURA_BLASTER * scala)
	var presa := mano_nel_corpo.origin + PRESA
	# Il blaster pende dall'attacco della mano, la cui posa è quella dell'osso nello
	# scheletro: quindi la sua trasformazione locale si misura da lì.
	_blaster.transform = mano_nel_corpo.affine_inverse() * Transform3D(voluta, presa)


func _e_blaster(pezzo: Node) -> bool:
	return _blaster != null and (pezzo == _blaster or _blaster.is_ancestor_of(pezzo))


# ------------------------------------------------------------------ costruzione

func _costruisci() -> void:
	var dati: Dictionary = PERSONAGGI[chi]
	var file := "Superhero_%s_FullBody" % String(dati["sesso"])
	_modello = (_leggi(MODELLI + file + ".gltf") as PackedScene).instantiate()
	# Nel file guarda verso +Z; da noi avanti è −Z.
	_modello.rotation.y = PI
	_modello.scale = Vector3.ONE * (ALTEZZA_CORPO / ALTEZZA_MODELLO)
	add_child(_modello)
	_scheletro = _modello.find_child("Skeleton3D", true, false) as Skeleton3D
	_senza_rilievo(_modello)

	_vesti(String(dati["sesso"]), dati)
	for taglio in dati["capelli"]:
		_pettina(String(taglio), dati["tinta_capelli"])
	_arma()
	_fissa_il_blaster()
	_animazioni()

	_torsione = Torsione.new()
	_torsione.name = "Torsione"
	_scheletro.add_child(_torsione)
	# Albero e scheletro vanno avanti solo quando lo dice il ritmo (`_process`).
	_scheletro.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL


func _vesti(sesso: String, dati: Dictionary) -> void:
	var grande: MeshInstance3D = null
	var quanti := 0
	# Il pezzo più grande è il corpo. Si contano i vertici, non le facce:
	# `get_faces` costruisce l'elenco intero dei triangoli solo per contarli.
	for nodo in _tutti(_modello):
		if nodo is MeshInstance3D and (nodo as MeshInstance3D).mesh is ArrayMesh:
			var mesh := (nodo as MeshInstance3D).mesh as ArrayMesh
			var vertici := 0
			for s in mesh.get_surface_count():
				vertici += mesh.surface_get_array_len(s)
			if vertici > quanti:
				quanti = vertici
				grande = nodo
	if grande == null:
		return
	var vecchio := grande.get_active_material(0) as BaseMaterial3D
	_materiale = ShaderMaterial.new()
	_materiale.shader = _leggi(TUTA)
	if vecchio != null:
		_materiale.set_shader_parameter("base", vecchio.albedo_texture)
		_materiale.set_shader_parameter("normale", vecchio.normal_texture)
		_materiale.set_shader_parameter("rugosita", vecchio.roughness_texture)
	_materiale.set_shader_parameter("maschera", _leggi(MODELLI + "Maschera_Testa_" + sesso + ".png"))
	_materiale.set_shader_parameter("divisa", _leggi(MODELLI + "Maschera_Divisa_" + sesso + ".png"))
	_materiale.set_shader_parameter("tuta", dati["tuta"])
	_materiale.set_shader_parameter("secondo", dati["secondo"])
	grande.material_override = _materiale


## I capelli: nel pacchetto stanno a parte, fermi nella posa di riposo del corpo.
## Si appendono all'osso della testa, spostati all'indietro di quanto la testa sta
## avanti a riposo: così seguono la testa da qualunque posa.
func _pettina(taglio: String, tinta: Color) -> void:
	var testa := _scheletro.find_bone("Head")
	if testa < 0:
		return
	var scena := _leggi(CAPELLI + taglio + ".gltf") as PackedScene
	if scena == null:
		return
	var attacco := BoneAttachment3D.new()
	attacco.bone_name = "Head"
	_scheletro.add_child(attacco)
	var pettinatura: Node3D = scena.instantiate()
	pettinatura.transform = _scheletro.get_bone_global_rest(testa).affine_inverse()
	attacco.add_child(pettinatura)
	for nodo in _tutti(pettinatura):
		if nodo is MeshInstance3D:
			var pezzo := nodo as MeshInstance3D
			var materiale := pezzo.get_active_material(0)
			if materiale is BaseMaterial3D:
				var tinto := (materiale as BaseMaterial3D).duplicate() as BaseMaterial3D
				tinto.albedo_color = tinta
				tinto.normal_enabled = false
				pezzo.material_override = tinto


## **Occhi, sopracciglia e capelli senza mappa del rilievo** (tappa 9). A due metri
## sullo schermo di un telefono non si vede, ma ognuno dei tre modi in cui il
## pacchetto la usava era uno shader suo — e sul telefono uno shader in più sono
## cinque compilazioni. Senza, usano lo stesso del blaster. I materiali del modello
## sono condivisi da tutti i corpi dello stesso sesso: si toccano una volta.
static func _senza_rilievo(radice: Node) -> void:
	for nodo in _tutti(radice):
		if nodo is MeshInstance3D and (nodo as MeshInstance3D).mesh != null:
			var pezzo := nodo as MeshInstance3D
			for s in pezzo.mesh.get_surface_count():
				var materiale := pezzo.get_active_material(s)
				if materiale is BaseMaterial3D:
					(materiale as BaseMaterial3D).normal_enabled = false


func _arma() -> void:
	var attacco := BoneAttachment3D.new()
	attacco.bone_name = "hand_r"
	attacco.name = "Mano"
	_scheletro.add_child(attacco)
	_blaster = (_leggi(BLASTER) as PackedScene).instantiate()
	attacco.add_child(_blaster)

	# Il lampo alla bocca: un disco caldo che si apre e sparisce in sei centesimi.
	# Resta **sotto la soglia del bagliore** — sopra ci va solo il dardo, che nasce
	# proprio lì e deve essere lui la cosa più luminosa.
	_lampo_bocca = MeshInstance3D.new()
	var disco := QuadMesh.new()
	disco.size = Vector2(0.34, 0.34)
	_lampo_bocca.mesh = disco
	_lampo_bocca.material_override = _pelle_lampo_bocca()
	_lampo_bocca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lampo_bocca.top_level = true
	_lampo_bocca.visible = false
	add_child(_lampo_bocca)


static var _pelle_bocca: StandardMaterial3D = null


static func _pelle_lampo_bocca() -> StandardMaterial3D:
	if _pelle_bocca != null:
		return _pelle_bocca
	var sfumatura := Gradient.new()
	sfumatura.set_color(0, Color(1.0, 0.95, 0.80, 1.0))
	sfumatura.set_color(1, Color(1.0, 0.80, 0.45, 0.0))
	var disco := GradientTexture2D.new()
	disco.width = 64
	disco.height = 64
	disco.fill = GradientTexture2D.FILL_RADIAL
	disco.fill_from = Vector2(0.5, 0.5)
	disco.fill_to = Vector2(1.0, 0.5)
	disco.gradient = sfumatura
	_pelle_bocca = StandardMaterial3D.new()
	_pelle_bocca.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pelle_bocca.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pelle_bocca.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_pelle_bocca.albedo_texture = disco
	_pelle_bocca.albedo_color = Color(0.98, 0.94, 0.86, 1.0)
	_pelle_bocca.disable_receive_shadows = true
	return _pelle_bocca


## La libreria di animazioni, letta una volta per tutti: è un file da sette
## megabyte e i sei corpi la condividono.
static func libreria() -> AnimationLibrary:
	if _libreria != null:
		return _libreria
	var scena: Node = (load(ANIMAZIONI) as PackedScene).instantiate()
	var origine := scena.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if origine != null:
		_libreria = origine.get_animation_library(&"")
	scena.free()
	return _libreria


## L'albero delle animazioni, costruito qui e non in una scena: è lo stesso per
## tutti e sei, e scritto in codice si legge in un posto solo.
##
##     corsa (fermo · corsetta · scatto, secondo la velocità)
##       └ passo (il ritmo dei piedi, negativo all'indietro)
##           └ aria (si mescola al salto quando i piedi lasciano terra)
##               └ busto (la posa di mira sopra, dalla seconda vertebra in su)
##                   └ sparo (colpo, solo il busto)
##                       └ colpo (colpo incassato, solo il busto)
func _animazioni() -> void:
	_albero = AnimationTree.new()
	_albero.name = "Animazioni"
	_albero.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_albero.add_animation_library(&"", libreria())
	_modello.add_child(_albero)

	var radice := AnimationNodeBlendTree.new()

	var corsa := AnimationNodeBlendSpace1D.new()
	corsa.min_space = 0.0
	corsa.max_space = VELOCITA_SCATTO
	corsa.add_blend_point(_animazione("Pistol_Idle"), 0.0, -1, &"fermo")
	corsa.add_blend_point(_animazione("Jog_Fwd"), VELOCITA_CORSETTA, -1, &"corsetta")
	corsa.add_blend_point(_animazione("Sprint"), VELOCITA_SCATTO, -1, &"scatto")
	radice.add_node(&"corsa", corsa, Vector2(0, 0))

	radice.add_node(&"passo", AnimationNodeTimeScale.new(), Vector2(200, 0))
	radice.connect_node(&"passo", 0, &"corsa")

	radice.add_node(&"in_volo", _animazione("Jump"), Vector2(200, 160))
	radice.add_node(&"aria", AnimationNodeBlend2.new(), Vector2(400, 0))
	radice.connect_node(&"aria", 0, &"passo")
	radice.connect_node(&"aria", 1, &"in_volo")

	var mira := AnimationNodeBlendSpace1D.new()
	mira.min_space = -1.0
	mira.max_space = 1.0
	mira.add_blend_point(_animazione("Pistol_Aim_Down"), -1.0, -1, &"giu")
	mira.add_blend_point(_animazione("Pistol_Aim_Neutral"), 0.0, -1, &"dritto")
	mira.add_blend_point(_animazione("Pistol_Aim_Up"), 1.0, -1, &"su")
	radice.add_node(&"mira", mira, Vector2(400, 160))

	var busto := AnimationNodeBlend2.new()
	_filtro_busto(busto, false)
	radice.add_node(&"busto", busto, Vector2(600, 0))
	radice.connect_node(&"busto", 0, &"aria")
	radice.connect_node(&"busto", 1, &"mira")

	var sparo := AnimationNodeOneShot.new()
	sparo.fadein_time = 0.03
	sparo.fadeout_time = 0.14
	_filtro_busto(sparo, false)
	radice.add_node(&"sparo", sparo, Vector2(800, 0))
	radice.add_node(&"colpo_di_blaster", _animazione("Pistol_Shoot"), Vector2(800, 160))
	radice.connect_node(&"sparo", 0, &"busto")
	radice.connect_node(&"sparo", 1, &"colpo_di_blaster")

	var colpo := AnimationNodeOneShot.new()
	colpo.fadein_time = 0.03
	colpo.fadeout_time = 0.10
	_filtro_busto(colpo, true)
	radice.add_node(&"colpo", colpo, Vector2(1000, 0))
	radice.add_node(&"incassato", _animazione("Hit_Chest"), Vector2(1000, 160))
	radice.connect_node(&"colpo", 0, &"sparo")
	radice.connect_node(&"colpo", 1, &"incassato")

	radice.connect_node(&"output", 0, &"colpo")
	_albero.tree_root = radice
	_albero.active = true
	_albero.set("parameters/busto/blend_amount", 1.0)


func _animazione(nome: String) -> AnimationNodeAnimation:
	var nodo := AnimationNodeAnimation.new()
	nodo.animation = StringName(nome)
	return nodo


## Il filtro del busto: le tracce delle ossa dalla seconda vertebra in su, dita
## comprese. `con_vita` aggiunge la prima vertebra — il colpo incassato piega anche
## lei.
func _filtro_busto(nodo: AnimationNode, con_vita: bool) -> void:
	nodo.filter_enabled = true
	var ossa: Array = OSSA_BUSTO.duplicate()
	if con_vita:
		ossa.append("spine_01")
	for lato in ["l", "r"]:
		for dito in DITA:
			for n in ["01", "02", "03"]:
				ossa.append("%s_%s_%s" % [dito, n, lato])
	for osso in ossa:
		nodo.set_filter_path(NodePath("Armature/Skeleton3D:" + String(osso)), true)


## La pelle del contorno: la forma vista **da dentro** e cresciuta di poco, senza
## luci di scena addosso — così il contorno è identico in ogni angolo dell'arena,
## esattamente come il dardo. Resta **sotto la soglia del bagliore**.
static func pelle_contorno(colore: Color) -> StandardMaterial3D:
	var materiale := StandardMaterial3D.new()
	materiale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materiale.albedo_color = colore
	materiale.cull_mode = BaseMaterial3D.CULL_FRONT
	materiale.grow = true
	materiale.grow_amount = 0.055
	materiale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materiale.disable_receive_shadows = true
	return materiale


static func _tutti(nodo: Node) -> Array:
	var elenco := []
	for figlio in nodo.get_children():
		elenco.append(figlio)
		elenco.append_array(_tutti(figlio))
	return elenco
