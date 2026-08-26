extends SceneTree

## Collaudo dei comandi per il pollice: muovere e mirare **insieme**.
##
## Perché esiste. Alla prima prova col dito vero, il 26/08/2026, la visuale
## saltava di colpo appena i due pollici lavoravano insieme; con un dito solo
## non succedeva mai. La causa non è nel gioco, è nel ponte dei tocchi della
## piattaforma web di Godot 4.7.2, letto riga per riga:
##
##   platform/web/js/libs/library_godot_input.js  →  passa `evt.changedTouches`,
##   cioè i soli tocchi cambiati in quell'evento, con identificativo e posizione
##   presi dallo stesso posto `i` dell'elenco.
##
##   platform/web/display_server_web.cpp, `_touch_callback` →
##       ev->set_index(touch_event.identifier[i]);   // l'indice è il DITO
##       Point2 &prev = ds->touches[i];              // la memoria è il POSTO
##       ev->set_relative(ev->get_position() - prev);
##
## L'indice dell'evento è l'identificativo del dito, ma la posizione precedente
## è tenuta per posto nell'elenco. Con un dito solo i due coincidono sempre.
## Con due dita si incrociano: il pollice destro riceve uno scarto misurato
## contro l'ultima posizione del **sinistro**, cioè mezzo schermo in un
## fotogramma solo. Da qui il salto della visuale — e anche il colpo che non
## parte più, perché mezzo schermo di scarto conta come trascinamento.
##
## Il rimedio non tocca il motore: `comandi.gd` non si fida più di
## `evento.relative` e lo scarto se lo calcola da sé, tenendo l'ultima
## posizione **per dito** — che l'indice, quello, è giusto.
##
## Questo collaudo riproduce il ponte web difetto compreso (`MotoreWeb`), così
## la prova gira sul PC senza telefono e senza browser.
##
## Uso:  godot --headless --path . -s tools/prova_comandi.gd


## Il ponte tocchi della piattaforma web di Godot 4.7.2, riprodotto fedelmente:
## la memoria della posizione precedente sta nel POSTO dell'evento, mentre
## l'indice dell'evento è l'identificativo del DITO.
class MotoreWeb:
	const GIU := 0
	const SU := 1
	const MUOVE := 2

	var _posto: Array[Vector2] = []

	func _init() -> void:
		_posto.resize(32)
		_posto.fill(Vector2.ZERO)

	## `cambiati` è [[identificativo, posizione], ...]: i soli tocchi cambiati
	## in questo evento, come `evt.changedTouches` del browser.
	func eventi(tipo: int, cambiati: Array) -> Array:
		var fuori := []
		for i in cambiati.size():
			var dito: int = cambiati[i][0]
			var punto: Vector2 = cambiati[i][1]
			if tipo == MUOVE:
				var mossa := InputEventScreenDrag.new()
				mossa.index = dito
				mossa.position = punto
				mossa.relative = punto - _posto[i]
				_posto[i] = punto
				fuori.append(mossa)
			else:
				var tocco := InputEventScreenTouch.new()
				tocco.index = dito
				tocco.position = punto
				tocco.pressed = tipo == GIU
				_posto[i] = punto
				fuori.append(tocco)
		return fuori


const SINISTRO := 4      ## identificativi come li dà Safari: numeri qualunque
const DESTRO := 17

var _errori := 0
var _prove := 0
var _comandi: Comandi
var _web: MotoreWeb
var _scarto_visto := Vector2.ZERO   ## l'ultimo scarto che il motore ha dato al destro


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	_comandi = Comandi.new()
	root.add_child(_comandi)
	await process_frame
	await process_frame

	var schermo := root.get_visible_rect().size
	_conta("lo schermo ha una larghezza", schermo.x > 0.0, str(schermo))
	if schermo.x <= 0.0:
		_chiudi()
		return

	var sx := Vector2(schermo.x * 0.16, schermo.y * 0.70)   # metà sinistra: la leva
	var dx := Vector2(schermo.x * 0.78, schermo.y * 0.50)   # metà destra: la mira
	var lontananza := dx.x - sx.x

	_premessa_i_due_lati(sx, dx)
	_due_pollici_insieme(sx, dx, lontananza)
	_stesso_evento_ordine_invertito(sx, dx, lontananza)
	_sinistro_che_si_stacca(sx, dx, lontananza)
	_un_dito_solo(dx)
	_il_colpo_mentre_ci_si_muove(sx, dx)
	_destro_che_sconfina(sx, dx, schermo)

	_chiudi()


## Premessa di tutto il resto: i due lati dello schermo fanno cose diverse.
## Se cadesse questa, ogni prova qui sotto passerebbe per il motivo sbagliato.
func _premessa_i_due_lati(sx: Vector2, dx: Vector2) -> void:
	_apri()
	_manda(MotoreWeb.GIU, [[SINISTRO, sx]])
	_manda(MotoreWeb.MUOVE, [[SINISTRO, sx + Vector2(50, 0)]])
	_conta("il pollice sinistro muove la leva", _comandi.movimento().length() > 0.1,
			str(_comandi.movimento()))
	_conta("il pollice sinistro non mira", _comandi.mira_consumata() == Vector2.ZERO)
	_chiudi_dita(sx, dx)

	_apri()
	_manda(MotoreWeb.GIU, [[DESTRO, dx]])
	_manda(MotoreWeb.MUOVE, [[DESTRO, dx + Vector2(40, 0)]])
	_conta("il pollice destro mira", _comandi.mira_consumata().length() > 0.0)
	_conta("il pollice destro non muove la leva", _comandi.movimento() == Vector2.ZERO,
			str(_comandi.movimento()))
	_chiudi_dita(sx, dx)


## Il caso vero: si tiene la leva col sinistro e si mira col destro, a turno.
func _due_pollici_insieme(sx: Vector2, dx: Vector2, lontananza: float) -> void:
	_apri()
	_manda(MotoreWeb.GIU, [[SINISTRO, sx]])
	_manda(MotoreWeb.GIU, [[DESTRO, dx]])
	_comandi.mira_consumata()

	# Dieci giri alternati: il sinistro spinge la leva, il destro mira piano.
	var mirato := Vector2.ZERO
	var punta_sx := sx
	var punta_dx := dx
	for giro in 10:
		punta_sx += Vector2(3, -2)
		_manda(MotoreWeb.MUOVE, [[SINISTRO, punta_sx]])
		var passo := Vector2(8, -4)
		punta_dx += passo
		mirato += passo
		_manda(MotoreWeb.MUOVE, [[DESTRO, punta_dx]])

	# Controprova della premessa (lezione 19): il difetto del motore si è
	# davvero realizzato, cioè l'ultimo scarto ricevuto è mezzo schermo invece
	# dei nove pixel che il dito ha percorso. Se questo non succedesse, la
	# prova qui sotto non starebbe misurando niente.
	_conta("il motore web dà davvero lo scarto dell'altro dito",
			_scarto_visto.length() > lontananza * 0.5,
			"scarto ricevuto: %.1f px, dito mosso: 8,9 px" % _scarto_visto.length())

	var atteso := mirato * Comandi.SENSIBILITA
	var letto := _comandi.mira_consumata()
	_conta("la mira segue solo il pollice destro",
			letto.distance_to(atteso) < 0.0005,
			"letto %s, atteso %s" % [letto, atteso])
	_chiudi_dita(sx, dx)


## Tutti e due i pollici nello stesso evento, e l'ordine dell'elenco che cambia
## fra un evento e l'altro: il browser non garantisce nessun ordine.
func _stesso_evento_ordine_invertito(sx: Vector2, dx: Vector2, lontananza: float) -> void:
	_apri()
	_manda(MotoreWeb.GIU, [[SINISTRO, sx]])
	_manda(MotoreWeb.GIU, [[DESTRO, dx]])
	_comandi.mira_consumata()

	var mirato := Vector2.ZERO
	var punta_sx := sx
	var punta_dx := dx
	for giro in 8:
		punta_sx += Vector2(2, 1)
		var passo := Vector2(-6, 3)
		punta_dx += passo
		mirato += passo
		if giro % 2 == 0:
			_manda(MotoreWeb.MUOVE, [[SINISTRO, punta_sx], [DESTRO, punta_dx]])
		else:
			_manda(MotoreWeb.MUOVE, [[DESTRO, punta_dx], [SINISTRO, punta_sx]])

	_conta("con l'ordine invertito il motore sbanda davvero",
			_scarto_visto.length() > lontananza * 0.5,
			"scarto ricevuto: %.1f px" % _scarto_visto.length())
	var atteso := mirato * Comandi.SENSIBILITA
	var letto := _comandi.mira_consumata()
	_conta("la mira regge anche quando i due arrivano insieme",
			letto.distance_to(atteso) < 0.0005,
			"letto %s, atteso %s" % [letto, atteso])
	_chiudi_dita(sx, dx)


## Si molla la leva e si continua a mirare: il dito che si stacca lascia la sua
## posizione nel posto che poi toccherà al destro.
func _sinistro_che_si_stacca(sx: Vector2, dx: Vector2, lontananza: float) -> void:
	_apri()
	_manda(MotoreWeb.GIU, [[SINISTRO, sx]])
	_manda(MotoreWeb.GIU, [[DESTRO, dx]])
	_manda(MotoreWeb.SU, [[SINISTRO, sx]])
	_comandi.mira_consumata()

	var passo := Vector2(12, 6)
	_manda(MotoreWeb.MUOVE, [[DESTRO, dx + passo]])
	_conta("dopo il distacco il motore sbanda davvero",
			_scarto_visto.length() > lontananza * 0.5,
			"scarto ricevuto: %.1f px" % _scarto_visto.length())
	var atteso := passo * Comandi.SENSIBILITA
	var letto := _comandi.mira_consumata()
	_conta("la mira regge subito dopo aver mollato la leva",
			letto.distance_to(atteso) < 0.0005,
			"letto %s, atteso %s" % [letto, atteso])
	_chiudi_dita(sx, dx)


## Quello che già funzionava deve continuare a funzionare identico.
func _un_dito_solo(dx: Vector2) -> void:
	_apri()
	_manda(MotoreWeb.GIU, [[DESTRO, dx]])
	_comandi.mira_consumata()
	var mirato := Vector2.ZERO
	var punta := dx
	for giro in 6:
		var passo := Vector2(7, -3)
		punta += passo
		mirato += passo
		_manda(MotoreWeb.MUOVE, [[DESTRO, punta]])
	var atteso := mirato * Comandi.SENSIBILITA
	var letto := _comandi.mira_consumata()
	_conta("con un dito solo la mira è quella di sempre",
			letto.distance_to(atteso) < 0.0005,
			"letto %s, atteso %s" % [letto, atteso])
	_manda(MotoreWeb.SU, [[DESTRO, punta]])
	_comandi.fuoco_richiesto()


## L'altra faccia dello stesso difetto: mezzo schermo di scarto conta come
## trascinamento, e il tocco breve smette di sparare mentre ci si muove.
func _il_colpo_mentre_ci_si_muove(sx: Vector2, dx: Vector2) -> void:
	_apri()
	_manda(MotoreWeb.GIU, [[SINISTRO, sx]])
	_manda(MotoreWeb.GIU, [[DESTRO, dx]])
	_comandi.fuoco_richiesto()
	# La leva spinge, e intanto il pollice destro tocca e stacca quasi fermo:
	# due pixel di tremolio, ben sotto la soglia del trascinamento.
	_manda(MotoreWeb.MUOVE, [[SINISTRO, sx + Vector2(6, -4)]])
	_manda(MotoreWeb.MUOVE, [[DESTRO, dx + Vector2(2, 0)]])
	_manda(MotoreWeb.SU, [[DESTRO, dx + Vector2(2, 0)]])
	_conta("il colpo parte anche mentre ci si muove", _comandi.fuoco_richiesto())
	_chiudi_dita(sx, dx)


## Un pollice partito a destra che sconfina nella metà sinistra resta la mira:
## il canale segue il dito, non la metà dello schermo.
func _destro_che_sconfina(sx: Vector2, dx: Vector2, schermo: Vector2) -> void:
	_apri()
	_manda(MotoreWeb.GIU, [[DESTRO, dx]])
	_comandi.mira_consumata()
	var oltre := Vector2(schermo.x * 0.30, dx.y)
	_manda(MotoreWeb.MUOVE, [[DESTRO, oltre]])
	var atteso := (oltre - dx) * Comandi.SENSIBILITA
	var letto := _comandi.mira_consumata()
	_conta("il pollice destro che sconfina continua a mirare",
			letto.distance_to(atteso) < 0.0005,
			"letto %s, atteso %s" % [letto, atteso])
	_conta("e non muove la leva", _comandi.movimento() == Vector2.ZERO,
			str(_comandi.movimento()))
	_chiudi_dita(sx, dx)


func _apri() -> void:
	_web = MotoreWeb.new()
	_scarto_visto = Vector2.ZERO


func _manda(tipo: int, cambiati: Array) -> void:
	for evento in _web.eventi(tipo, cambiati):
		if evento is InputEventScreenDrag and evento.index == DESTRO:
			_scarto_visto = evento.relative
		_comandi._unhandled_input(evento)


func _chiudi_dita(sx: Vector2, dx: Vector2) -> void:
	_manda(MotoreWeb.SU, [[SINISTRO, sx]])
	_manda(MotoreWeb.SU, [[DESTRO, dx]])
	_comandi.mira_consumata()
	_comandi.fuoco_richiesto()


func _conta(nome: String, esito: bool, dettaglio: String = "") -> bool:
	_prove += 1
	if esito:
		print("  OK   ", nome)
	else:
		_errori += 1
		print("  NO   ", nome, "  →  ", dettaglio)
	return esito


func _chiudi() -> void:
	print("")
	if _errori == 0:
		print("COMANDI: %d prove, tutte passate." % _prove)
		quit(0)
	else:
		print("COMANDI: %d prove, %d FALLITE." % [_prove, _errori])
		quit(1)
