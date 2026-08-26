class_name Comandi
extends CanvasLayer

## I comandi per il pollice, e il poco di interfaccia che serve al poligono.
##
## Schema: pollice sinistro sulla metà sinistra dello schermo per muoversi (la
## leva compare dove si appoggia il dito, non in un punto fisso), pollice destro
## sulla metà destra per mirare. Un tocco destro che non trascina è un colpo, e
## c'è comunque il pulsante FUOCO per chi preferisce.
##
## Tutto è ancorato ai bordi e mai a coordinate fisse: sul telefono lo schermo è
## più largo di quello di prova e i pulsanti devono restare sotto il pollice.

signal colore_richiesto
signal camera_richiesta

const RAGGIO_LEVA := 96.0
const ZONA_MORTA := 12.0
const SOGLIA_TRASCINAMENTO := 16.0  ## pixel oltre i quali un tocco è mira, non colpo
const TEMPO_COLPO := 0.28           ## secondi entro cui un tocco breve vale come colpo
const SENSIBILITA := 0.0034

var _dito_sinistro := -1
var _dito_destro := -1
var _centro_leva := Vector2.ZERO
var _punta_leva := Vector2.ZERO
var _movimento := Vector2.ZERO
var _mira := Vector2.ZERO
var _fuoco := false
var _salto := false
var _percorso_destro := 0.0
var _tempo_destro := 0.0

var _disegno: Control
var _riga_alta: Label
var _riga_bassa: Label
var _avviso: Label
var _tempo_avviso := 0.0


func _ready() -> void:
	layer = 10
	_costruisci()


func _process(delta: float) -> void:
	if _dito_destro != -1:
		_tempo_destro += delta
	if _tempo_avviso > 0.0:
		_tempo_avviso -= delta
		_avviso.modulate.a = clampf(_tempo_avviso, 0.0, 1.0)
		if _tempo_avviso <= 0.0:
			_avviso.text = ""
	_disegno.queue_redraw()


func _unhandled_input(evento: InputEvent) -> void:
	var meta := _disegno.size.x * 0.5

	if evento is InputEventScreenTouch:
		if evento.pressed:
			if evento.position.x < meta and _dito_sinistro == -1:
				_dito_sinistro = evento.index
				_centro_leva = evento.position
				_punta_leva = evento.position
			elif evento.position.x >= meta and _dito_destro == -1:
				_dito_destro = evento.index
				_percorso_destro = 0.0
				_tempo_destro = 0.0
		else:
			if evento.index == _dito_sinistro:
				_dito_sinistro = -1
				_movimento = Vector2.ZERO
			elif evento.index == _dito_destro:
				# Tocco corto e fermo: è un colpo. Se ha trascinato, stava mirando.
				if _percorso_destro < SOGLIA_TRASCINAMENTO and _tempo_destro < TEMPO_COLPO:
					_fuoco = true
				_dito_destro = -1

	elif evento is InputEventScreenDrag:
		if evento.index == _dito_sinistro:
			_punta_leva = evento.position
			var scarto := _punta_leva - _centro_leva
			if scarto.length() < ZONA_MORTA:
				_movimento = Vector2.ZERO
			else:
				_movimento = scarto.limit_length(RAGGIO_LEVA) / RAGGIO_LEVA
		elif evento.index == _dito_destro:
			_percorso_destro += evento.relative.length()
			_mira += evento.relative * SENSIBILITA


## Lo scarto della leva, da −1 a 1. La y è positiva verso il basso, come lo schermo.
func movimento() -> Vector2:
	return _movimento


## Quanto si è mirato dall'ultima lettura. Si consuma: chi la legge la azzera.
func mira_consumata() -> Vector2:
	var valore := _mira
	_mira = Vector2.ZERO
	return valore


func fuoco_richiesto() -> bool:
	var valore := _fuoco
	_fuoco = false
	return valore


func salto_richiesto() -> bool:
	var valore := _salto
	_salto = false
	return valore


func scrivi_alto(testo: String) -> void:
	_riga_alta.text = testo


func scrivi_basso(testo: String) -> void:
	_riga_bassa.text = testo


## L'annuncio grosso al centro: quanti muri ha fatto il colpo e quanto vale.
func annuncia(testo: String) -> void:
	_avviso.text = testo
	_tempo_avviso = 1.6
	_avviso.modulate.a = 1.0


func _disegna() -> void:
	var chiaro := Color(1, 1, 1, 0.5)
	# Il mirino: al centro, sempre, in tutte e due le visuali.
	var centro := _disegno.size * 0.5
	_disegno.draw_circle(centro, 3.0, Color(1, 1, 1, 0.9))
	for verso in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		_disegno.draw_line(centro + verso * 11.0, centro + verso * 20.0, chiaro, 2.0)

	if _dito_sinistro != -1:
		_disegno.draw_arc(_centro_leva, RAGGIO_LEVA, 0.0, TAU, 40, Color(1, 1, 1, 0.28), 3.0)
		var punta := _centro_leva + (_punta_leva - _centro_leva).limit_length(RAGGIO_LEVA)
		_disegno.draw_circle(punta, 34.0, Color(1, 1, 1, 0.22))
		_disegno.draw_arc(punta, 34.0, 0.0, TAU, 28, Color(1, 1, 1, 0.6), 2.0)
	else:
		# Il segno di dove si appoggia il pollice sinistro, tenue.
		var riposo := Vector2(RAGGIO_LEVA + 60.0, _disegno.size.y - RAGGIO_LEVA - 50.0)
		_disegno.draw_arc(riposo, RAGGIO_LEVA * 0.8, 0.0, TAU, 40, Color(1, 1, 1, 0.12), 2.0)


func _costruisci() -> void:
	_disegno = Control.new()
	_disegno.set_anchors_preset(Control.PRESET_FULL_RECT)
	_disegno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disegno.draw.connect(_disegna)
	add_child(_disegno)

	_riga_alta = _etichetta(30, Color(1, 1, 1, 0.95))
	_riga_alta.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_riga_alta.position = Vector2(28, 20)
	_riga_alta.size = Vector2(700, 44)
	add_child(_riga_alta)

	_riga_bassa = _etichetta(20, Color(1, 1, 1, 0.6))
	_riga_bassa.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_riga_bassa.position = Vector2(28, 62)
	_riga_bassa.size = Vector2(900, 40)
	add_child(_riga_bassa)

	_avviso = _etichetta(52, Color(1, 1, 1, 1))
	_avviso.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_avviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avviso.offset_top = 108
	_avviso.offset_bottom = 190
	_avviso.text = ""
	add_child(_avviso)

	_pulsante("FUOCO", Vector2(-190, -190), Vector2(150, 150), Color(0.95, 0.3, 0.35),
			func() -> void: _fuoco = true)
	_pulsante("SALTA", Vector2(-352, -150), Vector2(112, 112), Color(0.2, 0.6, 1.0),
			func() -> void: _salto = true)
	_pulsante("VISUALE", Vector2(-160, -330), Vector2(120, 96), Color(0.35, 0.4, 0.55),
			func() -> void: camera_richiesta.emit())
	_pulsante("COLORE", Vector2(-160, -430), Vector2(120, 84), Color(0.35, 0.4, 0.55),
			func() -> void: colore_richiesto.emit())


func _pulsante(testo: String, scarto: Vector2, misura: Vector2, colore: Color,
		azione: Callable) -> Button:
	var pulsante := Button.new()
	pulsante.text = testo
	pulsante.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pulsante.offset_left = scarto.x
	pulsante.offset_top = scarto.y
	pulsante.offset_right = scarto.x + misura.x
	pulsante.offset_bottom = scarto.y + misura.y
	pulsante.add_theme_font_size_override("font_size", 22)
	pulsante.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	for stato in ["normal", "hover", "focus"]:
		pulsante.add_theme_stylebox_override(stato, _sfondo(colore, 0.34))
	pulsante.add_theme_stylebox_override("pressed", _sfondo(colore, 0.75))
	pulsante.pressed.connect(azione)
	add_child(pulsante)
	return pulsante


func _sfondo(colore: Color, opacita: float) -> StyleBoxFlat:
	var stile := StyleBoxFlat.new()
	stile.bg_color = Color(colore.r, colore.g, colore.b, opacita)
	stile.set_corner_radius_all(22)
	stile.border_width_bottom = 2
	stile.border_width_top = 2
	stile.border_width_left = 2
	stile.border_width_right = 2
	stile.border_color = Color(1, 1, 1, 0.25)
	return stile


func _etichetta(dimensione: int, colore: Color) -> Label:
	var etichetta := Label.new()
	etichetta.add_theme_font_size_override("font_size", dimensione)
	etichetta.add_theme_color_override("font_color", colore)
	etichetta.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	etichetta.add_theme_constant_override("outline_size", 6)
	etichetta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etichetta
