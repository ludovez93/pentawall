class_name Proiettile
extends Node3D

## Il dardo. Si muove **a mano** a ogni fotogramma, con un raggio che copre tutto
## lo spostamento: a 19 m/s un corpo fisico attraverserebbe i muri sottili.
## Il moto è la stessa `Balistica.traiettoria` della linea di mira, chiamata con
## la portata di un fotogramma invece che con quella della mira.
##
## La resa segue DECISIONI.md § B, punto per punto: nucleo bianco, guscio nel
## colore riservato, filo scuro, senza luci di scena addosso, dimensione minima
## a schermo, scia corta, lampo secco a ogni rimbalzo.

signal colpito(corpo: Object, punto: Vector3, normale: Vector3, muri: int)
signal rimbalzato(punto: Vector3, normale: Vector3, muri: int)
signal spento(punto: Vector3, muri: int)

## 1000 u/s del Sidewinder del 1999 = 19 m/s (RICERCA-ORIGINALE.md § 5).
const VELOCITA := 19.0
const VITA_MASSIMA := 6.0      ## secondi, rete di sicurezza se non colpisce mai niente
const RAGGIO := 0.1            ## metri: un dardo grosso, si deve vedere
const SCIA_MASSIMA := 2.6      ## metri di scia dietro al dardo
const FRAZIONE_MINIMA := 0.009 ## quota minima di altezza schermo occupata (~0,9%)
const INGRANDIMENTO_MASSIMO := 5.0

## Il gruppo dei dardi in volo: chi deve schivare li cerca qui.
const GRUPPO := &"dardi"

## Il colore riservato al proiettile. Nessuna superficie d'arena può usarlo a
## piena saturazione: è la regola che discende da DECISIONI.md § B.
## Si conferma qui sul poligono, sulla scena vera — per questo è cambiabile a caldo.
static var colore_riservato := Color(1.0, 0.62, 0.24)

## Chi l'ha sparato. Serve a chi guarda i dardi in volo per sapere se sono suoi:
## un avversario non deve schivare i propri colpi.
var tiratore: Object = null

var _verso := Vector3.FORWARD
var _muri := 0
var _vita := 0.0
var _spegnimento := false
var _esclusi: Array[RID] = []
var _coda := Vector3.ZERO       ## da dove parte la scia
var _lampo_acceso := 0.0

var _corpo: Node3D
var _nucleo: MeshInstance3D
var _guscio: MeshInstance3D
var _filo: MeshInstance3D
var _scia: MeshInstance3D
var _lampo: MeshInstance3D


## Si lancia così: Proiettile.lancia(scena, canna, verso, esclusi, chi spara).
static func lancia(genitore: Node, origine: Vector3, verso: Vector3,
		esclusi: Array[RID] = [], chi_spara: Object = null) -> Proiettile:
	var dardo := Proiettile.new()
	dardo._verso = verso.normalized()
	dardo._esclusi = esclusi
	dardo.tiratore = chi_spara
	genitore.add_child(dardo)
	dardo.global_position = origine
	dardo._coda = origine
	return dardo


func _ready() -> void:
	set_as_top_level(true)
	# Chi deve schivare guarda qui: nessuno ha bisogno di annunciare un colpo,
	# basta che il dardo esista (MIGLIORIE.md § 1, «ogni colpo avvisa»).
	add_to_group(GRUPPO)
	_costruisci()


## Dove sta andando adesso: dopo un rimbalzo non è più la direzione di partenza.
func verso() -> Vector3:
	return _verso


## Quanti muri gli restano. Chi ne prevede la strada deve chiederlo a lui: il
## conto dei cinque attraversa i fotogrammi, e da fuori non si indovina.
func muri_restanti() -> int:
	return maxi(Balistica.MURI_MASSIMI - _muri, 0)


## I corpi che questo dardo attraversa: chi l'ha sparato. Chi ne ricalcola la
## traiettoria deve escluderli anche lui, o prevede un urto che non avverrà.
func esclusi() -> Array[RID]:
	return _esclusi


## Un dardo che sta morendo non fa più male a nessuno.
func in_volo() -> bool:
	return not _spegnimento


func _process(delta: float) -> void:
	_vita += delta
	if _vita > VITA_MASSIMA and not _spegnimento:
		_spegni()

	if not _spegnimento:
		_avanza(delta)

	_aggiorna_scia()
	_aggiorna_dimensione()

	if _lampo_acceso > 0.0:
		_lampo_acceso -= delta
		var quota := clampf(_lampo_acceso / 0.09, 0.0, 1.0)
		_lampo.visible = true
		_lampo.scale = Vector3.ONE * (0.5 + (1.0 - quota) * 1.6)
		var materiale: StandardMaterial3D = _lampo.material_override
		materiale.albedo_color = Color(2.4, 2.4, 2.4, quota)
	else:
		_lampo.visible = false

	if _spegnimento and _lampo_acceso <= 0.0:
		queue_free()


## Un fotogramma di volo. La distanza da coprire è velocità × tempo, e la
## traiettoria la risolve la stessa funzione della mira: i muri già consumati si
## scalano da quelli disponibili, così il conto dei cinque attraversa i fotogrammi
## senza perdersi.
func _avanza(delta: float) -> void:
	var spazio := get_world_3d().direct_space_state
	var passo := VELOCITA * delta
	var tratti := Balistica.traiettoria(spazio, global_position, _verso, passo,
			Balistica.MURI_MASSIMI - _muri, _esclusi)
	if tratti.is_empty():
		global_position += _verso * passo
		return

	for tratto in tratti:
		global_position = tratto.a
		if tratto.bersaglio:
			colpito.emit(tratto.corpo, tratto.a, tratto.normale, _muri)
			_accendi_lampo(tratto.a)
			_spegni()
			return
		if tratto.muro:
			if tratto.esaurito:
				# Sesto muro: il dardo muore qui. È il limite che dà il nome al gioco.
				_accendi_lampo(tratto.a)
				_spegni()
				return
			_muri += 1
			_verso = _verso.bounce(tratto.normale).normalized()
			_coda = tratto.a
			_accendi_lampo(tratto.a)
			rimbalzato.emit(tratto.a, tratto.normale, _muri)
	# L'ultimo tratto può finire nel vuoto: la posizione è già quella giusta.


func _spegni() -> void:
	if _spegnimento:
		return
	_spegnimento = true
	_corpo.visible = false
	_scia.visible = false
	spento.emit(global_position, _muri)
	if _lampo_acceso <= 0.0:
		queue_free()


func _accendi_lampo(punto: Vector3) -> void:
	_lampo_acceso = 0.09
	_lampo.global_position = punto


## La scia: un segmento corto dietro al dardo, che si accorcia da sola dopo un
## rimbalzo perché la coda resta attaccata al punto d'urto.
func _aggiorna_scia() -> void:
	if _spegnimento:
		return
	var indietro := global_position - _coda
	var lunghezza := indietro.length()
	if lunghezza > SCIA_MASSIMA:
		_coda = global_position - indietro.normalized() * SCIA_MASSIMA
		lunghezza = SCIA_MASSIMA
	if lunghezza < 0.05:
		_scia.visible = false
		return
	_scia.visible = true
	_scia.global_position = (global_position + _coda) * 0.5
	_scia.look_at(global_position, Vector3.UP, true)
	_scia.scale = Vector3(1.0, 1.0, lunghezza)


## Dimensione minima a schermo: da lontano il dardo non deve diventare un puntino
## su un telefono. Si ragiona in angolo apparente, non in pixel, così il conto non
## dipende dalla risoluzione dello schermo.
func _aggiorna_dimensione() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var distanza := maxf(camera.global_position.distance_to(global_position), 0.05)
	var apparente := 2.0 * atan(RAGGIO / distanza)
	var campo := deg_to_rad(camera.fov)
	var frazione := apparente / campo
	var fattore := 1.0
	if frazione < FRAZIONE_MINIMA:
		fattore = minf(FRAZIONE_MINIMA / maxf(frazione, 0.00001), INGRANDIMENTO_MASSIMO)
	_corpo.scale = Vector3.ONE * fattore


## Le forme e i materiali del dardo, fatti **una volta sola** e prestati a tutti.
##
## Prima nascevano da zero a ogni colpo: nove fra mesh e materiali, e ognuno vuole
## la sua fetta di memoria sulla scheda video. Misurato il 26/08/2026, dopo che il
## difetto era arrivato dal telefono — *«se faccio fuoco tante volte mentre mi
## muovo c'è qualche scatto»*: **sedici fotogrammi lenti su milleduecento, e tutti
## e sedici erano quello subito dopo lo sparo**. Non era il volo, non erano i
## rimbalzi: era la nascita.
static var _forma_guscio: SphereMesh = null
static var _forma_nucleo: SphereMesh = null
static var _forma_scia: BoxMesh = null
static var _forma_lampo: QuadMesh = null
static var _pelle_filo: StandardMaterial3D = null
static var _pelle_guscio: StandardMaterial3D = null
static var _pelle_nucleo: StandardMaterial3D = null
static var _pelle_scia: StandardMaterial3D = null


## Prepara il corredo condiviso, se non c'è già, e gli rimette il colore riservato
## del momento. Le tre assegnazioni di colore costano nulla e tolgono di mezzo il
## problema di tenere sincronizzato un materiale statico con un pulsante che lo
## cambia a caldo: chi nasce adesso nasce già del colore giusto.
static func _corredo() -> void:
	if _forma_guscio == null:
		_forma_guscio = _sfera(RAGGIO)
		_forma_nucleo = _sfera(RAGGIO * 0.34)
		_forma_scia = BoxMesh.new()
		_forma_scia.size = Vector3(0.05, 0.05, 1.0)
		_forma_lampo = QuadMesh.new()
		_forma_lampo.size = Vector2(0.55, 0.55)

		# Filo scuro: la stessa sfera vista da dentro, un filo più grande. Serve a
		# staccare il dardo dai fondi chiari, come il nucleo lo stacca dagli scuri.
		_pelle_filo = _materiale_piatto(Color(0.02, 0.02, 0.05))
		_pelle_filo.cull_mode = BaseMaterial3D.CULL_FRONT
		_pelle_filo.grow = true
		# Sottile: a dieci pixel di distanza un filo grosso si mangia il guscio
		# colorato e il dardo diventa una palla nera. Verificato guardandolo.
		_pelle_filo.grow_amount = 0.012

		_pelle_guscio = _materiale_piatto(colore_riservato * 1.9)
		# Nucleo bianco puro: è lui che sfonda il bianco e prende il bagliore.
		# Piccolo, perché serve a staccare il dardo dai fondi scuri, non a essere
		# tutto il dardo: se cresce, i colori riservati diventano indistinguibili.
		_pelle_nucleo = _materiale_piatto(Color(3.4, 3.4, 3.4))
		_pelle_scia = _materiale_piatto(colore_riservato * 1.25)
		_pelle_scia.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_pelle_guscio.albedo_color = colore_riservato * 1.9
	var scia := colore_riservato * 1.25
	scia.a = 0.5
	_pelle_scia.albedo_color = scia


func _costruisci() -> void:
	_corredo()
	_corpo = Node3D.new()
	add_child(_corpo)

	_filo = MeshInstance3D.new()
	_senza_ombra(_filo)
	_filo.mesh = _forma_guscio
	_filo.material_override = _pelle_filo
	_corpo.add_child(_filo)

	_guscio = MeshInstance3D.new()
	_senza_ombra(_guscio)
	_guscio.mesh = _forma_guscio
	_guscio.material_override = _pelle_guscio
	_corpo.add_child(_guscio)

	_nucleo = MeshInstance3D.new()
	_senza_ombra(_nucleo)
	_nucleo.mesh = _forma_nucleo
	_nucleo.material_override = _pelle_nucleo
	_corpo.add_child(_nucleo)

	_scia = MeshInstance3D.new()
	_senza_ombra(_scia)
	_scia.set_as_top_level(true)
	_scia.mesh = _forma_scia
	_scia.material_override = _pelle_scia
	add_child(_scia)

	_lampo = MeshInstance3D.new()
	_senza_ombra(_lampo)
	_lampo.set_as_top_level(true)
	_lampo.mesh = _forma_lampo
	# Il lampo è l'unico materiale che resta suo: si accende e si spegne per conto
	# proprio, e condividerlo farebbe lampeggiare insieme tutti i dardi in volo.
	# Nove allocazioni a colpo sono diventate una.
	var materiale_lampo := _materiale_piatto(Color(2.4, 2.4, 2.4))
	materiale_lampo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materiale_lampo.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_lampo.material_override = materiale_lampo
	_lampo.visible = false
	add_child(_lampo)


## Il dardo non fa ombra: e' un oggetto senza luci di scena addosso, e un'ombra
## nera che gli corre dietro lo smentirebbe. Costa anche meno.
func _senza_ombra(pezzo: GeometryInstance3D) -> GeometryInstance3D:
	pezzo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return pezzo


static func _sfera(raggio: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = raggio
	mesh.height = raggio * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh


## Senza luci di scena addosso: il dardo è identico nella grotta verde, nel tempio
## rosso e nel nero dello spazio. In un materiale non illuminato il colore finale
## è l'albedo, e per questo l'albedo può superare 1: è così che prende il bagliore.
static func _materiale_piatto(colore: Color) -> StandardMaterial3D:
	var materiale := StandardMaterial3D.new()
	materiale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materiale.albedo_color = colore
	materiale.disable_receive_shadows = true
	return materiale
