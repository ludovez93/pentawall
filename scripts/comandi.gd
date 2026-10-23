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
signal sfida_richiesta
signal livello_richiesto
## I due della partita (blocco C): il podio li accende, e la scena decide cosa
## vuol dire ricominciare o uscire.
signal rigioca_richiesta
signal uscita_richiesta
## Il pulsante LANCIA della PALLA (tappa 11, blocco D2).
signal lancio_richiesto

const RAGGIO_LEVA := 96.0
const ZONA_MORTA := 12.0
const SOGLIA_TRASCINAMENTO := 16.0  ## pixel oltre i quali un tocco è mira, non colpo
const TEMPO_COLPO := 0.28           ## secondi entro cui un tocco breve vale come colpo
const SENSIBILITA := 0.0034

## La seconda colonna di pulsanti, quella che riempie la scena: a sinistra della
## prima e più in alto di SALTA, così non si accavalla con niente.
const COLONNA_SCENA := -300.0
const ALTEZZA_SCENA := -330.0
const PASSO_SCENA := -94.0

var _dito_sinistro := -1
var _dito_destro := -1
var _centro_leva := Vector2.ZERO
var _punta_leva := Vector2.ZERO
## Dove stava il pollice destro l'ultima volta che l'abbiamo visto. Lo teniamo
## noi invece di fidarci di `evento.relative`: sulla pagina web Godot 4.7.2
## misura quello scarto contro l'ultima posizione **dell'altro dito**, e con
## due pollici giù la visuale saltava di mezzo giro (LEARNED.md § 21).
var _punto_destro := Vector2.ZERO
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
var _bottone_sfida: Button
var _bottone_livello: Button
var _pulsanti_di_scena := 0
var _classifica: VBoxContainer
var _righe_classifica: Array[Dictionary] = []

## **Il colpo che si vede** (tappa 7, blocco B). Tre cose, tutte brevi: il
## marcatore sul mirino quando un colpo va a segno, la vignetta rossa sul bordo da
## cui arriva un colpo incassato, e i numeri che salgono dal punto d'impatto.
const DURATA_MARCATORE := 0.16
const DURATA_VIGNETTA := 0.55
const VITA_ETICHETTA := 1.0
const SALITA_ETICHETTA := 70.0   ## punti di schermo percorsi salendo
const ETICHETTE_IN_RISERVA := 6  ## costruite all'apertura, mai in partita

var _marcatore := 0.0
var _vignetta := 0.0
var _verso_vignetta := Vector2(0, 1)
## `{"etichetta": Label, "punto": Vector3, "vita": float}`
var _etichette_volanti: Array[Dictionary] = []
## In GARA i colpi non fanno punti (tappa 11, blocco D1): l'etichetta che sale dal colpo
## dice che l'hai fermato, non quanto vale.
var senza_punti := false
## La freccia sul bordo dello schermo: dove sta la prossima bandiera quando non la vedi.
## `Vector3.INF`: spenta.
var _freccia_meta := Vector3.INF
var _freccia_colore := Color.WHITE
var _freccia_testo := ""
## La bandiera è nello schermo ma dietro un muro: al posto della freccia, il segnalino.
var _freccia_coperta := false
## La PALLA (tappa 11, blocco D2): il pulsante LANCIA, e i sette pallini in alto — `0`
## niente, `1` segnata, `2` portata, `3` segnata e portata. Vuoto: spenti.
var _lancia: Button
var _colore_lancia := Color.WHITE
var _pallini: Array = []
var _colori_pallini: Array = []
const MARGINE_FRECCIA := 110.0
## Di quanti punti di schermo l'etichetta parte sopra il colpo: grande (tappa 11), la
## scritta coprirebbe chi l'ha preso.
var _alza_etichette := 70.0 if Aspetto.corpi_a_cartone() else 26.0
var _prossima_etichetta := 0


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
	if _tempo_fischio > 0.0:
		_tempo_fischio -= delta
		_fischio.modulate.a = clampf(_tempo_fischio / 0.5, 0.0, 1.0)
		if _tempo_fischio <= 0.0:
			_fischio.text = ""
	_marcatore = maxf(_marcatore - delta, 0.0)
	_vignetta = maxf(_vignetta - delta, 0.0)
	_muovi_le_etichette(delta)
	_disegno.queue_redraw()


## Il marcatore sul mirino: un colpo è andato a segno.
func segna_il_colpo() -> void:
	_marcatore = DURATA_MARCATORE


## Un colpo incassato, e da che parte dello schermo è arrivato (destra positiva,
## giù positivo: davanti è in alto, dietro in basso).
func colpo_incassato_da(verso: Vector2) -> void:
	_vignetta = DURATA_VIGNETTA
	_verso_vignetta = verso if verso.length_squared() > 0.01 else Vector2(0, 1)


## I punti che salgono dal punto d'impatto: «+50 · DI SPONDA». Le etichette sono
## sei, in riserva; la settima riusa la più vecchia.
func punti_dal_mondo(dove: Vector3, punti: int, muri: int, bonus := false) -> void:
	if _etichette_volanti.is_empty():
		return
	var voce: Dictionary = _etichette_volanti[_prossima_etichetta]
	_prossima_etichetta = (_prossima_etichetta + 1) % _etichette_volanti.size()
	voce["punto"] = dove
	voce["vita"] = VITA_ETICHETTA
	var etichetta: Label = voce["etichetta"]
	etichetta.text = TESTO_FERMATO if senza_punti and not bonus else testo_del_colpo(punti, muri, bonus)
	etichetta.visible = true
	etichetta.modulate.a = 1.0


## Il testo del colpo. Dice **di sponda**, non quanti muri: dal 05/10/2026 un colpo di
## sponda vale uguale con una o con cinque (DECISIONI.md § 20). Un bersaglio bonus vale il
## suo numero comunque lo si prenda, e dice solo quello (tappa 11, blocco F).
static func testo_del_colpo(punti: int, muri: int, bonus := false) -> String:
	if bonus:
		return "+%d · BERSAGLIO" % punti
	return ("+%d · DIRETTO" if muri <= 0 else "+%d · DI SPONDA") % punti


## L'etichetta del colpo a segno in GARA: chi l'incassa torna alla sua ultima bandiera.
const TESTO_FERMATO := "FERMATO!"


## L'annuncio grosso del colpo, al centro: «DIRETTO · 25», «DI SPONDA · 50».
static func annuncio_del_colpo(punti: int, muri: int) -> String:
	return ("DIRETTO · %d" if muri <= 0 else "DI SPONDA · %d") % punti


## Le etichette seguono il punto del mondo fotogramma per fotogramma, salendo e
## sfumando. La camera proietta nel rettangolo visibile della finestra, che con la
## tela stirata è già la misura in cui vivono i controlli (854 × 390 sul telefono
## diventano 1576 × 720 per tutti e due): nessuna trasformazione in mezzo. Con una
## in più l'etichetta finiva dieci schermi più in là — visto dal collaudo.
func _muovi_le_etichette(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	for voce in _etichette_volanti:
		if float(voce["vita"]) <= 0.0:
			continue
		voce["vita"] = float(voce["vita"]) - delta
		var etichetta: Label = voce["etichetta"]
		if float(voce["vita"]) <= 0.0 or camera == null \
				or camera.is_position_behind(voce["punto"]):
			etichetta.visible = false
			continue
		var quota := 1.0 - float(voce["vita"]) / VITA_ETICHETTA
		var dove: Vector2 = camera.unproject_position(voce["punto"])
		etichetta.position = dove - etichetta.size * 0.5 \
				- Vector2(0.0, _alza_etichette + SALITA_ETICHETTA * quota)
		etichetta.modulate.a = clampf((1.0 - quota) * 2.2, 0.0, 1.0)


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
				_punto_destro = evento.position
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
			# Lo scarto se lo calcola il gioco, da dove stava questo dito la
			# volta prima. `evento.relative` sulla pagina web è quello sbagliato.
			var passo: Vector2 = evento.position - _punto_destro
			_punto_destro = evento.position
			_percorso_destro += passo.length()
			_mira += passo * SENSIBILITA


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


## **Il fischio d'inizio**: 3 · 2 · 1 · VIA, al centro dello schermo e grande
## quanto serve. L'annuncio normale sta in alto ed è alto cinquantadue punti: per
## un conto alla rovescia è un sottotitolo, non un via.
func fischio(testo: String) -> void:
	if _fischio == null:
		_fischio = _etichetta(130, Color(1, 1, 1, 1))
		_fischio.add_theme_font_override("font", carattere_titolo())
		_fischio.add_theme_constant_override("outline_size", 12)
		_fischio.set_anchors_preset(Control.PRESET_CENTER)
		_fischio.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_fischio.grow_vertical = Control.GROW_DIRECTION_BOTH
		_fischio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_fischio.offset_left = -300
		_fischio.offset_right = 300
		_fischio.offset_top = -110
		_fischio.offset_bottom = 60
		add_child(_fischio)
	_fischio.text = testo
	_fischio.modulate.a = 1.0
	_tempo_fischio = 0.9


## **Il pulsante LANCIA** (tappa 11, blocco D2, la proposta approvata il 13/10/2026):
## compare accanto al fuoco solo quando porti una palla, nel colore di quella che parte; il
## fuoco resta il blaster, così chi porta può difendersi. Tondo come FUOCO e SALTA, sopra il
## fuoco.
func lancia(visibile: bool, colore := Color.WHITE) -> void:
	if _lancia == null:
		if not visibile:
			return
		_lancia = _pulsante("LANCIA", Vector2(-176, -334), Vector2(124, 124), colore,
				func() -> void: lancio_richiesto.emit())
		_lancia.set_meta("lancia", true)
		_lancia.add_theme_font_size_override("font_size", 24)
	if visibile and not colore.is_equal_approx(_colore_lancia):
		_colore_lancia = colore
		for stato in ["normal", "hover", "focus"]:
			_lancia.add_theme_stylebox_override(stato, _tondo(colore, 0.72, 124))
		_lancia.add_theme_stylebox_override("pressed", _tondo(colore, 0.95, 124))
	_lancia.visible = visibile


func lancia_visibile() -> bool:
	return _lancia != null and _lancia.visible


func colore_del_lancio() -> Color:
	return _colore_lancia


## I sette pallini: uno per palla, nel suo colore. Segnata, pieno; portata, l'anello acceso e
## più grande; né l'una né l'altra, solo il contorno.
func pallini(stati: Array, colori: Array = []) -> void:
	_pallini = stati
	_colori_pallini = colori


func _disegna_i_pallini() -> void:
	if _pallini.is_empty():
		return
	var passo := 34.0
	var y := 132.0
	var x := _disegno.size.x - 34.0 - passo * float(_pallini.size() - 1)
	for i in _pallini.size():
		var colore: Color = _colori_pallini[i] if i < _colori_pallini.size() else Color.WHITE
		var stato := int(_pallini[i])
		var centro := Vector2(x + passo * float(i), y)
		if stato & 1:
			_disegno.draw_circle(centro, 11.0, colore)
		else:
			_disegno.draw_circle(centro, 11.0, Color(0.03, 0.03, 0.08, 0.45))
		_disegno.draw_arc(centro, 11.0, 0.0, TAU, 24, Color(colore.r, colore.g, colore.b, 0.95), 2.5, true)
		if stato & 2:
			_disegno.draw_arc(centro, 16.0, 0.0, TAU, 28, Color(1, 1, 1, 0.95), 3.0, true)


## Il numero della bandiera coperta in un tondo nel suo colore, con la punta in giù verso
## il punto dove sta.
func _disegna_il_segnalino(dove: Vector2) -> void:
	var tondo := dove - Vector2(0, 46.0)
	var punta := PackedVector2Array([dove, tondo + Vector2(-16.0, 20.0), tondo + Vector2(16.0, 20.0)])
	_disegno.draw_colored_polygon(punta, _freccia_colore)
	_disegno.draw_circle(tondo, 28.0, _freccia_colore)
	_disegno.draw_arc(tondo, 28.0, 0.0, TAU, 32, Color(1, 1, 1, 0.95), 4.0, true)
	var font := carattere_titolo()
	var dove_testo := tondo + Vector2(-40.0, 15.0)
	_disegno.draw_string_outline(font, dove_testo, _freccia_testo, HORIZONTAL_ALIGNMENT_CENTER,
			80.0, 40, 8, Color(0.02, 0.02, 0.06, 0.85))
	_disegno.draw_string(font, dove_testo, _freccia_testo, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 40,
			Color(1, 1, 1, 0.98))


## L'annuncio grosso al centro: quanti muri ha fatto il colpo e quanto vale.
func annuncia(testo: String) -> void:
	_avviso.text = testo
	_tempo_avviso = 1.6
	_avviso.modulate.a = 1.0


## Il pulsante del duello dice cosa farà, non in che stato è: acceso, l'unica
## cosa che può fare è chiudere.
func scrivi_sfida(testo: String) -> void:
	if _bottone_sfida != null:
		_bottone_sfida.text = testo


## Spegne i due pulsanti del duello, per le scene che non ne hanno uno. Si
## nascondono invece di non essere costruiti, così i sei che il pollice ha già
## imparato restano dove stanno in tutte le scene.
func spegni_il_duello() -> void:
	if _bottone_sfida != null:
		_bottone_sfida.visible = false
	if _bottone_livello != null:
		_bottone_livello.visible = false


## Un pulsante che chiede la scena, non i comandi: si impila in una **seconda
## colonna** a sinistra della prima, così i sei che il pollice ha già imparato
## non si spostano di un pixel. Serve da quando le scene sono due e ognuna ha
## roba sua da accendere.
func pulsante_di_scena(testo: String, colore: Color, azione: Callable) -> Button:
	var alto := ALTEZZA_SCENA + PASSO_SCENA * _pulsanti_di_scena
	_pulsanti_di_scena += 1
	return _pulsante(testo, Vector2(COLONNA_SCENA, alto), Vector2(126, 84), colore, azione)


## **La classifica.** In un duello bastava una riga — «TU 25 — LUI 0» — perché i
## nomi erano due e la differenza si leggeva a colpo d'occhio. In sei quella riga
## non si legge più: serve una colonna, ordinata, dove la propria posizione si
## trova senza cercarla.
##
## Sta in alto a sinistra perché è l'unica fascia dello schermo che non ha né
## pulsanti né pollici sopra, e le righe si costruiscono una volta sola: in
## partita cambiano i numeri, non i nodi.
##
## Ogni riga è `{"posizione": int, "nome": String, "punti": int, "tu": bool}`, già
## in ordine. La posizione arriva dal dato e non dall'ordine delle righe, perché
## in partita se ne mostrano quattro su sei: le prime tre e la tua.
func classifica(righe: Array) -> void:
	_classifica.visible = true
	for i in _righe_classifica.size():
		var riga: Dictionary = _righe_classifica[i]
		var pannello: PanelContainer = riga["pannello"]
		if i >= righe.size():
			pannello.visible = false
			continue
		pannello.visible = true
		var dato: Dictionary = righe[i]
		var tuo := bool(dato.get("tu", false))
		(riga["posizione"] as Label).text = "%d" % int(dato["posizione"])
		(riga["nome"] as Label).text = String(dato["nome"])
		(riga["punti"] as Label).text = valore_di(dato)
		var tinta := Color(1, 1, 1, 0.98) if tuo else Color(1, 1, 1, 0.62)
		for chiave in ["posizione", "nome", "punti"]:
			(riga[chiave] as Label).add_theme_color_override("font_color", tinta)
		pannello.add_theme_stylebox_override("panel",
				_riga_accesa() if tuo else _vuoto())


## Il numero di una riga: i punti, o quello che la riga dice al loro posto — in GARA le
## bandiere, «3/7».
static func valore_di(dato: Dictionary) -> String:
	return String(dato["testo"]) if dato.has("testo") else "%d" % int(dato["punti"])


## Si spegne quando la partita non c'è: fuori dalla sfida l'arena è un posto in
## cui si gira per guardarla, e una classifica ferma a zero è rumore.
func spegni_la_classifica() -> void:
	if _classifica != null:
		_classifica.visible = false


func _costruisci_la_classifica() -> void:
	_classifica = VBoxContainer.new()
	_classifica.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_classifica.position = Vector2(28, 112)
	_classifica.add_theme_constant_override("separation", 2)
	_classifica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_classifica)

	for i in 8:
		var pannello := PanelContainer.new()
		pannello.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pannello.add_theme_stylebox_override("panel", _vuoto())
		var riga := HBoxContainer.new()
		riga.add_theme_constant_override("separation", 10)
		riga.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pannello.add_child(riga)

		# Diciannove e non ventidue: sul telefono in orizzontale lo schermo è alto
		# trecentonovanta punti, e ogni riga che cresce mangia la fascia dove sta
		# il pollice sinistro.
		var posizione := _etichetta(19, Color(1, 1, 1, 0.62))
		posizione.custom_minimum_size = Vector2(22, 0)
		posizione.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var nome := _etichetta(19, Color(1, 1, 1, 0.62))
		nome.custom_minimum_size = Vector2(118, 0)
		var punti := _etichetta(19, Color(1, 1, 1, 0.62))
		punti.custom_minimum_size = Vector2(58, 0)
		punti.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		for pezzo in [posizione, nome, punti]:
			riga.add_child(pezzo)

		_classifica.add_child(pannello)
		_righe_classifica.append({"pannello": pannello, "posizione": posizione,
				"nome": nome, "punti": punti})


## Il fondo di una riga qualunque: niente. Serve un oggetto vero lo stesso,
## perché togliere lo stile a un pannello lo fa tornare a quello del tema. I
## margini ci sono anche qui: se li avesse solo la riga accesa, la classifica
## ballerebbe di quattro pixel ogni volta che si cambia posizione.
func _vuoto() -> StyleBoxEmpty:
	var stile := StyleBoxEmpty.new()
	stile.content_margin_left = 8
	stile.content_margin_right = 8
	stile.content_margin_top = 2
	stile.content_margin_bottom = 2
	return stile


## La riga tua: un fondo chiaro appena accennato. Il raggio è piccolo — quello
## dei pulsanti sarebbe una pasticca su una riga alta ventotto pixel.
func _riga_accesa() -> StyleBoxFlat:
	var stile := StyleBoxFlat.new()
	stile.bg_color = Color(1, 1, 1, 0.15)
	stile.set_corner_radius_all(6)
	stile.content_margin_left = 8
	stile.content_margin_right = 8
	stile.content_margin_top = 2
	stile.content_margin_bottom = 2
	return stile


func _disegna() -> void:
	_disegna_la_vignetta()
	_disegna_la_freccia()
	_disegna_i_pallini()
	var chiaro := Color(1, 1, 1, 0.5)
	# Il mirino: al centro, sempre, in tutte e due le visuali.
	var centro := _disegno.size * 0.5
	_disegno.draw_circle(centro, 3.0, Color(1, 1, 1, 0.9))
	for verso in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		_disegno.draw_line(centro + verso * 11.0, centro + verso * 20.0, chiaro, 2.0)
	# Il marcatore del colpo a segno: quattro tacche in diagonale, nel colore del
	# dardo, che si aprono e spariscono in un sesto di secondo.
	if _marcatore > 0.0:
		var quota := _marcatore / DURATA_MARCATORE
		var tinta := Proiettile.colore_riservato
		tinta.a = quota
		var apertura := 14.0 + (1.0 - quota) * 10.0
		for verso in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var v: Vector2 = (verso as Vector2).normalized()
			_disegno.draw_line(centro + v * apertura, centro + v * (apertura + 12.0), tinta, 3.0)

	if _dito_sinistro != -1:
		_disegno.draw_arc(_centro_leva, RAGGIO_LEVA, 0.0, TAU, 40, Color(1, 1, 1, 0.28), 3.0)
		var punta := _centro_leva + (_punta_leva - _centro_leva).limit_length(RAGGIO_LEVA)
		_disegno.draw_circle(punta, 34.0, Color(1, 1, 1, 0.22))
		_disegno.draw_arc(punta, 34.0, 0.0, TAU, 28, Color(1, 1, 1, 0.6), 2.0)
	else:
		# Il segno di dove si appoggia il pollice sinistro, tenue.
		var riposo := Vector2(RAGGIO_LEVA + 60.0, _disegno.size.y - RAGGIO_LEVA - 50.0)
		_disegno.draw_arc(riposo, RAGGIO_LEVA * 0.8, 0.0, TAU, 40, Color(1, 1, 1, 0.12), 2.0)


## La vignetta del colpo incassato: una fascia rossa sul bordo da cui è arrivato,
## piena sul bordo e trasparente verso il centro. Se arriva di traverso si
## accendono due bordi, ognuno per quanto gli spetta: non è un radar, è un avviso.
func _disegna_la_vignetta() -> void:
	if _vignetta <= 0.0:
		return
	var forza := clampf(_vignetta / DURATA_VIGNETTA, 0.0, 1.0)
	var misura := _disegno.size
	var verso := _verso_vignetta
	for lato in [
		{"peso": maxf(verso.x, 0.0), "da": Vector2(misura.x, 0), "a": Vector2(misura.x, misura.y),
			"dentro": Vector2(-misura.x * 0.32, 0)},
		{"peso": maxf(-verso.x, 0.0), "da": Vector2(0, 0), "a": Vector2(0, misura.y),
			"dentro": Vector2(misura.x * 0.32, 0)},
		{"peso": maxf(-verso.y, 0.0), "da": Vector2(0, 0), "a": Vector2(misura.x, 0),
			"dentro": Vector2(0, misura.y * 0.34)},
		{"peso": maxf(verso.y, 0.0), "da": Vector2(0, misura.y), "a": Vector2(misura.x, misura.y),
			"dentro": Vector2(0, -misura.y * 0.34)},
	]:
		var peso: float = lato["peso"]
		if peso < 0.3:
			continue
		var bordo := Color(0.95, 0.12, 0.16, 0.62 * forza * peso)
		var niente := Color(0.95, 0.12, 0.16, 0.0)
		var da: Vector2 = lato["da"]
		var a: Vector2 = lato["a"]
		var dentro: Vector2 = lato["dentro"]
		_disegno.draw_polygon(
				PackedVector2Array([da, a, a + dentro, da + dentro]),
				PackedColorArray([bordo, bordo, niente, niente]))


func _costruisci() -> void:
	_disegno = Control.new()
	_disegno.set_anchors_preset(Control.PRESET_FULL_RECT)
	_disegno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disegno.draw.connect(_disegna)
	add_child(_disegno)

	# Le etichette dei punti che salgono dal colpo: nascono qui, spente, e in
	# partita cambiano solo testo e posizione.
	for i in ETICHETTE_IN_RISERVA:
		# Nelle prove dell'arena aperta (tappa 11) i punti saltano fuori grandi, col bordo
		# scuro, dove succede: nei giochi del riferimento si leggono senza cercarli.
		var grandi := Aspetto.corpi_a_cartone()
		var etichetta := _etichetta(54 if grandi else 30, Color(1, 1, 1, 1))
		etichetta.add_theme_font_override("font", carattere_titolo())
		if grandi:
			etichetta.add_theme_constant_override("outline_size", 14)
			etichetta.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.18))
		etichetta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		etichetta.visible = false
		add_child(etichetta)
		_etichette_volanti.append({"etichetta": etichetta, "punto": Vector3.ZERO, "vita": 0.0})

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
	# I due della tappa 2: accendere il duello, e cambiare avversario senza
	# uscire dalla partita — i tre livelli si confrontano col pollice, non a
	# parole (MIGLIORIE.md § 1).
	_bottone_sfida = _pulsante("SFIDA", Vector2(-160, -524), Vector2(120, 84),
			Color(0.2, 0.75, 0.45), func() -> void: sfida_richiesta.emit())
	_bottone_livello = _pulsante("LIVELLO", Vector2(-160, -618), Vector2(120, 84),
			Color(0.35, 0.4, 0.55), func() -> void: livello_richiesto.emit())
	# La classifica si costruisce qui, spenta, insieme a tutto il resto: farla
	# nascere al primo colpo di una partita vorrebbe dire pagare ventiquattro
	# etichette e i loro caratteri **nel fotogramma in cui si preme SFIDA**, che è
	# esattamente il momento in cui non si può (misurato il 27/08/2026).
	_costruisci_la_classifica()
	_classifica.visible = false


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
	pulsante.add_theme_font_override("font", carattere_titolo())
	pulsante.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	for stato in ["normal", "hover", "focus"]:
		pulsante.add_theme_stylebox_override(stato, _sfondo(colore, 0.34))
	pulsante.add_theme_stylebox_override("pressed", _sfondo(colore, 0.75))
	pulsante.pressed.connect(azione)
	add_child(pulsante)
	return pulsante


const ICONA_FUOCO := "res://assets/ui/fuoco.svg"
const ICONA_SALTA := "res://assets/ui/salta.svg"
const ICONA_ESCI := "res://assets/ui/esci.svg"


## Un pulsante tondo: pieno, senza bordo a caramella, con un'ombra morbida.
func _tondo(colore: Color, opacita: float, lato: float) -> StyleBoxFlat:
	var stile := StyleBoxFlat.new()
	stile.bg_color = Color(colore.r, colore.g, colore.b, opacita)
	stile.set_corner_radius_all(int(lato * 0.5))
	stile.anti_aliasing = true
	stile.shadow_color = Color(0, 0, 0, 0.25)
	stile.shadow_size = 8
	stile.shadow_offset = Vector2(0, 3)
	return stile


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
	etichetta.add_theme_font_override("font", carattere_testo())
	etichetta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etichetta



# ------------------------------------------------------------------ la partita

## I due caratteri dell'interfaccia (tappa 7): i titoli in Russo One, i testi in
## Exo 2 semi-grasso. Caricati una volta; se mancano si torna a quello del motore.
const CARATTERE_TESTO := "res://assets/font/Exo2.ttf"
const CARATTERE_TITOLO := "res://assets/font/RussoOne-Regular.ttf"
static var _testo: Font = null
static var _titolo: Font = null

var _cronometro: Label
var _posizione_grande: Label
var _punti_piccoli: Label
var _in_partita := false
var _bottone_esci: Button
var _podio: PanelContainer
var _podio_posizione: Label
var _righe_podio: Array[Dictionary] = []
var _fischio: Label
var _tempo_fischio := 0.0
var _pillole: HBoxContainer


static func carattere_testo() -> Font:
	if _testo == null:
		var base: Font = load(CARATTERE_TESTO) if ResourceLoader.exists(CARATTERE_TESTO) else null
		if base == null:
			_testo = ThemeDB.fallback_font
		else:
			var variante := FontVariation.new()
			variante.base_font = base
			var server := TextServerManager.get_primary_interface()
			variante.variation_opentype = {server.name_to_tag("weight"): 640}
			_testo = variante
	return _testo


static func carattere_titolo() -> Font:
	if _titolo == null:
		if ResourceLoader.exists(CARATTERE_TITOLO):
			_titolo = load(CARATTERE_TITOLO)
		else:
			_titolo = ThemeDB.fallback_font
	return _titolo


## L'interfaccia della partita al posto di quella di collaudo: via la riga
## tecnica e i pulsanti di prova, dentro il cronometro, la posizione e i punti.
## Restano il mirino, la leva, FUOCO e SALTA: quelli sono il gioco.
func modalita_partita(tempo: String, posizione: int, punti: int, sotto := "") -> void:
	if not _in_partita:
		_accendi_la_partita()
		_in_partita = true
	_cronometro.text = tempo
	_posizione_grande.text = "%d°" % posizione
	# In GARA, al posto dei punti, la bandiera che devi toccare: «BANDIERA 3 DI 7».
	_punti_piccoli.text = sotto if sotto != "" else "%d PUNTI" % punti


## **La freccia della GARA** (tappa 11, blocco D1): quando la prossima bandiera è fuori
## dallo schermo, sul bordo una freccia nel suo colore dice da che parte girarsi, col
## numero accanto. Quando è nello schermo ma dietro un muro (`coperta`), sopra il punto dove
## sta compare il suo numero in un tondo, che punta giù: dalla griglia la prima bandiera è
## dietro un muro, e senza niente non si sapeva dove andare (scatto del 23/10/2026). In
## vista, niente: c'è la colonna. `Vector3.INF` la spegne.
func freccia(meta: Vector3, colore := Color.WHITE, testo := "", coperta := false) -> void:
	_freccia_meta = meta
	_freccia_colore = colore
	_freccia_testo = testo
	_freccia_coperta = coperta


## Il segnalino della bandiera coperta, se c'è: il punto dello schermo sopra cui sta.
## `Vector2.INF` quando non c'è.
func dove_il_segnalino() -> Vector2:
	if _freccia_meta == Vector3.INF or not _freccia_coperta or _disegno == null:
		return Vector2.INF
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(_freccia_meta):
		return Vector2.INF
	var punto := camera.unproject_position(_freccia_meta)
	if not Rect2(Vector2.ZERO, _disegno.size).grow(-MARGINE_FRECCIA).has_point(punto):
		return Vector2.INF
	return punto


## Se la freccia è sul bordo in questo momento, e dove: serve al collaudo. `Vector2.INF`
## quando non c'è (spenta, o la bandiera è sullo schermo).
func dove_la_freccia() -> Vector2:
	if _freccia_meta == Vector3.INF or _disegno == null:
		return Vector2.INF
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector2.INF
	var misura := _disegno.size
	var centro := misura * 0.5
	var dietro := camera.is_position_behind(_freccia_meta)
	var punto := camera.unproject_position(_freccia_meta)
	if not dietro and Rect2(Vector2.ZERO, misura).grow(-MARGINE_FRECCIA).has_point(punto):
		return Vector2.INF
	var verso := punto - centro
	if dietro:
		# Alle spalle la proiezione esce rovesciata: si raddrizza, e la freccia va sempre
		# verso il basso — dietro è giù, come la vignetta del colpo incassato.
		verso = Vector2(-verso.x, absf(verso.y) + misura.y * 0.5)
	if verso.length_squared() < 1.0:
		verso = Vector2(0, 1)
	verso = verso.normalized()
	var t := minf((centro.x - MARGINE_FRECCIA) / maxf(absf(verso.x), 0.001),
			(centro.y - MARGINE_FRECCIA) / maxf(absf(verso.y), 0.001))
	return centro + verso * t


func _disegna_la_freccia() -> void:
	var segnalino := dove_il_segnalino()
	if segnalino != Vector2.INF:
		_disegna_il_segnalino(segnalino)
		return
	var dove := dove_la_freccia()
	if dove == Vector2.INF:
		return
	var verso := (dove - _disegno.size * 0.5).normalized()
	var lato := Vector2(-verso.y, verso.x)
	# Grande e col bordo bianco: piccola e blu, sul pavimento chiaro si perdeva (23/10/2026).
	var punta := dove + verso * 34.0
	var dietro := dove - verso * 20.0
	var tre := PackedVector2Array([punta, dietro + lato * 32.0, dietro - lato * 32.0])
	_disegno.draw_colored_polygon(tre, _freccia_colore)
	_disegno.draw_polyline(PackedVector2Array([punta, dietro + lato * 32.0, dietro - lato * 32.0,
			punta]), Color(1, 1, 1, 0.95), 4.0, true)
	if _freccia_testo == "":
		return
	# Il numero in un tondo del colore della bandiera, dietro la freccia.
	var font := carattere_titolo()
	var tondo := dove - verso * 64.0
	_disegno.draw_circle(tondo, 28.0, _freccia_colore)
	_disegno.draw_arc(tondo, 28.0, 0.0, TAU, 32, Color(1, 1, 1, 0.95), 4.0, true)
	var dove_testo := tondo + Vector2(-40.0, 15.0)
	_disegno.draw_string_outline(font, dove_testo, _freccia_testo, HORIZONTAL_ALIGNMENT_CENTER,
			80.0, 40, 8, Color(0.02, 0.02, 0.06, 0.85))
	_disegno.draw_string(font, dove_testo, _freccia_testo, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 40,
			Color(1, 1, 1, 0.98))


## Il giro che si fa una volta sola, quando la partita comincia: costa
## l'attraversamento di tutti i pulsanti, e in partita si chiama sessanta volte
## al secondo.
func _accendi_la_partita() -> void:
	_riga_alta.visible = false
	_riga_bassa.visible = false
	# I due pulsanti del gioco: **tondi e a icona** (tappa 8, blocco G), come in ogni
	# sparatutto per telefono di oggi — il dardo che parte, le due frecce in su. E
	# coprenti: a un terzo di opacità il loro colore lo faceva il muro dietro.
	var pieni := {"FUOCO": Color(0.95, 0.3, 0.35), "SALTA": Color(0.2, 0.6, 1.0)}
	var icone := {"FUOCO": ICONA_FUOCO, "SALTA": ICONA_SALTA}
	for figlio in get_children():
		if not (figlio is Button):
			continue
		var pulsante := figlio as Button
		if pulsante.has_meta("lancia"):
			continue
		if not pieni.has(pulsante.text):
			pulsante.visible = false
			continue
		var lato := pulsante.offset_right - pulsante.offset_left
		for stato in ["normal", "hover", "focus"]:
			pulsante.add_theme_stylebox_override(stato, _tondo(pieni[pulsante.text], 0.62, lato))
		pulsante.add_theme_stylebox_override("pressed", _tondo(pieni[pulsante.text], 0.92, lato))
		pulsante.set_meta("nome", pulsante.text)
		pulsante.icon = load(icone[pulsante.text])
		pulsante.expand_icon = true
		pulsante.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pulsante.add_theme_constant_override("icon_max_width", int(lato * 0.52))
		pulsante.text = ""
	# Due righe sole in partita, quindi possono essere grandi quanto servono.
	for riga in _righe_classifica:
		for chiave in ["posizione", "nome", "punti"]:
			(riga[chiave] as Label).add_theme_font_size_override("font_size", 25)
		(riga["nome"] as Label).custom_minimum_size = Vector2(150, 0)
		(riga["punti"] as Label).custom_minimum_size = Vector2(72, 0)
	if _cronometro == null:
		_costruisci_la_partita()
	# La porta della stanza. Sul telefono il gioco sta a schermo intero e non ha
	# un tasto indietro: senza questo, una partita da tre minuti è una stanza
	# senza uscita. Piccolo e spento, in alto a sinistra, dove non passa nessun
	# pollice.
	if _bottone_esci == null:
		_bottone_esci = _pulsante("", Vector2.ZERO, Vector2(60, 60),
				Color(0.35, 0.4, 0.55), func() -> void: uscita_richiesta.emit())
		_bottone_esci.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_bottone_esci.offset_left = 26
		_bottone_esci.offset_top = 18
		_bottone_esci.offset_right = 26 + 60
		_bottone_esci.offset_bottom = 18 + 60
		for stato in ["normal", "hover", "focus"]:
			_bottone_esci.add_theme_stylebox_override(stato, _tondo(Color(0.10, 0.10, 0.18), 0.55, 60))
		_bottone_esci.add_theme_stylebox_override("pressed", _tondo(Color(0.10, 0.10, 0.18), 0.85, 60))
		_bottone_esci.set_meta("nome", "ESCI")
		_bottone_esci.icon = load(ICONA_ESCI)
		_bottone_esci.expand_icon = true
		_bottone_esci.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_bottone_esci.add_theme_constant_override("icon_max_width", 30)
		_bottone_esci.modulate.a = 0.7
	_bottone_esci.visible = true


func _costruisci_la_partita() -> void:
	var pillola := PanelContainer.new()
	pillola.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pillola.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pillola.offset_top = 14
	pillola.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.03, 0.03, 0.08, 0.55)
	fondo.set_corner_radius_all(20)
	fondo.content_margin_left = 26
	fondo.content_margin_right = 26
	fondo.content_margin_top = 2
	fondo.content_margin_bottom = 6
	pillola.add_theme_stylebox_override("panel", fondo)
	add_child(pillola)
	_cronometro = _etichetta(46, Color(1, 1, 1, 0.98))
	_cronometro.add_theme_font_override("font", carattere_titolo())
	_cronometro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pillola.add_child(_cronometro)

	_posizione_grande = _etichetta(56, Color(1, 1, 1, 0.98))
	_posizione_grande.add_theme_font_override("font", carattere_titolo())
	_posizione_grande.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_posizione_grande.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_posizione_grande.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_posizione_grande.offset_right = -30
	_posizione_grande.offset_top = 8
	add_child(_posizione_grande)

	_punti_piccoli = _etichetta(22, Color(1, 1, 1, 0.82))
	_punti_piccoli.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_punti_piccoli.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_punti_piccoli.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_punti_piccoli.offset_right = -32
	_punti_piccoli.offset_top = 78
	add_child(_punti_piccoli)


# ------------------------------------------------------------------- il podio

## **Il podio.** Scaduto il tempo, la partita si guarda da fuori: i sei in ordine
## d'arrivo, la tua posizione grande, e **RIGIOCA a un tocco** — che è il momento
## in cui il gioco chiede «un'altra?», la domanda di tutta la tappa 7.
##
## Le righe arrivano già ordinate da chi tiene il punteggio: qui si scrivono e
## basta. Si costruisce la prima volta che serve e poi si riaccende: a fine
## partita un fotogramma lento non si vede, ma il podio si riapre a ogni RIGIOCA.
func podio(righe: Array, posizione: int) -> void:
	if _podio == null:
		_costruisci_il_podio()
	_podio_posizione.text = "SEI %d°" % posizione
	for i in _righe_podio.size():
		var riga: Dictionary = _righe_podio[i]
		var scatola: HBoxContainer = riga["riga"]
		if i >= righe.size():
			scatola.visible = false
			continue
		scatola.visible = true
		var dato: Dictionary = righe[i]
		var tuo := bool(dato.get("tu", false))
		(riga["posizione"] as Label).text = "%d°" % int(dato["posizione"])
		(riga["nome"] as Label).text = String(dato["nome"])
		(riga["punti"] as Label).text = valore_di(dato)
		var tinta := Color(1, 0.86, 0.35, 1.0) if tuo else Color(1, 1, 1, 0.72)
		for chiave in ["posizione", "nome", "punti"]:
			(riga[chiave] as Label).add_theme_color_override("font_color", tinta)
	_podio.visible = true
	# La colonna di sinistra dice le stesse cose del podio, in piccolo: si spegne.
	spegni_la_classifica()
	if _bottone_esci != null:
		_bottone_esci.visible = false


## **Le pillole dei potenziamenti** (tappa 8, blocco H; tutte insieme dalla tappa 11):
## sotto il cronometro, una per potenziamento, nel colore della sua palla e con i
## secondi che restano. `voci`: `[{"testo", "colore"}]`; vuoto = spente.
func potenziamenti(voci: Array) -> void:
	if _pillole == null:
		if voci.is_empty():
			return
		# Larga quanto lo schermo e centrata dentro: con una pillola o con sei, la fila
		# resta sotto il cronometro.
		_pillole = HBoxContainer.new()
		_pillole.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_pillole.offset_top = 86
		_pillole.alignment = BoxContainer.ALIGNMENT_CENTER
		_pillole.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pillole.add_theme_constant_override("separation", 8)
		add_child(_pillole)
	while _pillole.get_child_count() < voci.size():
		_pillole.add_child(_pillola())
	for i in _pillole.get_child_count():
		var pillola := _pillole.get_child(i) as PanelContainer
		pillola.visible = i < voci.size()
		if not pillola.visible:
			continue
		var colore: Color = voci[i]["colore"]
		(pillola.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(colore.r, colore.g, colore.b, 0.92)
		(pillola.get_child(0) as Label).text = String(voci[i]["testo"])
	_pillole.visible = not voci.is_empty()


func _pillola() -> PanelContainer:
	var pillola := PanelContainer.new()
	pillola.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fondo := StyleBoxFlat.new()
	fondo.set_corner_radius_all(16)
	fondo.content_margin_left = 18
	fondo.content_margin_right = 18
	fondo.content_margin_top = 2
	fondo.content_margin_bottom = 4
	pillola.add_theme_stylebox_override("panel", fondo)
	var testo := _etichetta(24, Color(0.06, 0.04, 0.10, 1.0))
	testo.add_theme_font_override("font", carattere_titolo())
	testo.add_theme_constant_override("outline_size", 0)
	pillola.add_child(testo)
	return pillola


func spegni_il_podio() -> void:
	if _podio != null:
		_podio.visible = false
	if _bottone_esci != null and _in_partita:
		_bottone_esci.visible = true


func _costruisci_il_podio() -> void:
	_podio = PanelContainer.new()
	_podio.set_anchors_preset(Control.PRESET_CENTER)
	_podio.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_podio.grow_vertical = Control.GROW_DIRECTION_BOTH
	_podio.custom_minimum_size = Vector2(520, 0)
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.03, 0.03, 0.09, 0.92)
	fondo.set_corner_radius_all(26)
	fondo.border_width_bottom = 2
	fondo.border_width_top = 2
	fondo.border_width_left = 2
	fondo.border_width_right = 2
	fondo.border_color = Color(1, 1, 1, 0.16)
	fondo.content_margin_left = 34
	fondo.content_margin_right = 34
	fondo.content_margin_top = 18
	fondo.content_margin_bottom = 20
	_podio.add_theme_stylebox_override("panel", fondo)
	add_child(_podio)

	var colonna := VBoxContainer.new()
	colonna.add_theme_constant_override("separation", 4)
	_podio.add_child(colonna)

	_podio_posizione = _etichetta(44, Color(1, 1, 1, 0.98))
	_podio_posizione.add_theme_font_override("font", carattere_titolo())
	_podio_posizione.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonna.add_child(_podio_posizione)

	for i in 6:
		var riga := HBoxContainer.new()
		riga.add_theme_constant_override("separation", 14)
		riga.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var posizione := _etichetta(24, Color(1, 1, 1, 0.72))
		posizione.custom_minimum_size = Vector2(46, 0)
		posizione.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var nome := _etichetta(24, Color(1, 1, 1, 0.72))
		nome.custom_minimum_size = Vector2(230, 0)
		var punti := _etichetta(24, Color(1, 1, 1, 0.72))
		punti.custom_minimum_size = Vector2(100, 0)
		punti.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		for pezzo in [posizione, nome, punti]:
			riga.add_child(pezzo)
		colonna.add_child(riga)
		_righe_podio.append({"riga": riga, "posizione": posizione, "nome": nome,
				"punti": punti})

	var tasti := HBoxContainer.new()
	tasti.add_theme_constant_override("separation", 16)
	tasti.alignment = BoxContainer.ALIGNMENT_CENTER
	colonna.add_child(tasti)
	tasti.add_child(_tasto_del_podio("RIGIOCA", Color(0.2, 0.75, 0.45),
			func() -> void: rigioca_richiesta.emit()))
	tasti.add_child(_tasto_del_podio("ESCI", Color(0.35, 0.4, 0.55),
			func() -> void: uscita_richiesta.emit()))


## I pulsanti del podio stanno **dentro** il pannello, quindi non si posizionano
## come gli altri: li mette in fila il contenitore.
func _tasto_del_podio(testo: String, colore: Color, azione: Callable) -> Button:
	var pulsante := Button.new()
	pulsante.text = testo
	pulsante.custom_minimum_size = Vector2(190, 76)
	pulsante.add_theme_font_size_override("font_size", 26)
	pulsante.add_theme_font_override("font", carattere_titolo())
	pulsante.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	for stato in ["normal", "hover", "focus"]:
		pulsante.add_theme_stylebox_override(stato, _sfondo(colore, 0.62))
	pulsante.add_theme_stylebox_override("pressed", _sfondo(colore, 0.9))
	pulsante.pressed.connect(azione)
	return pulsante
