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

## **Il vestito del misto 1** (tappa 11, blocco C3a): lamelle navy inclinate, cifre in
## oro, il quadrato del posto oro, argento, bronzo. I numeri sono le misure del disegno
## approvato, sulla tela alta 720 (sul telefono 854 x 390 punti diventano 1576 x 720).
const NAVY := Color("0f1b3d")
const NAVY_CHIARO := Color("2a3a66")
const ORO := Color("ffc42e")
const ARGENTO := Color("c8d0dc")
const BRONZO := Color("b87333")
const ROSSO_FUOCO := Color("f2423b")
## Quanto pende una lamella: 0,20 sono circa undici gradi, tutte nello stesso verso.
const OBLIQUO := 0.20

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
## L'annuncio è una lamella con dentro un testo a colori: il numero in oro vuole un
## pezzo di testo colorato da solo, e una Label tinge tutto o niente.
var _pannello_avviso: PanelContainer
var _avviso: RichTextLabel
var _testo_avviso := ""
var _tempo_avviso := 0.0
var _bottone_sfida: Button
var _bottone_livello: Button
var _pulsanti_di_scena := 0
var _classifica: VBoxContainer
var _righe_classifica: Array[Dictionary] = []
## Gli stili della colonna, fatti una volta sola all'apertura.
var _stile_riga: StyleBoxFlat
var _stile_riga_tua: StyleBoxFlat
var _stili_quadrato: Array[StyleBoxFlat] = []

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
var _anello_lancia: Panel
var _pallini: Array = []
var _colori_pallini: Array = []
const MARGINE_FRECCIA := 110.0
## La lamella dei sette pallini della PALLA: quanto è larga, e quindi quanto si sposta
## la posizione per farle posto.
const LARGO_PALLINI := 212.0
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
		_pannello_avviso.modulate.a = clampf(_tempo_avviso, 0.0, 1.0)
		if _tempo_avviso <= 0.0:
			_testo_avviso = ""
			_avviso.text = ""
			_pannello_avviso.visible = false
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
		# Senza scatola: il VIA è scritto sul campo, bianco col contorno navy (misto 1).
		_fischio = _etichetta(148, Color.WHITE, 10)
		_fischio.add_theme_font_override("font", carattere_titolo())
		_fischio.set_anchors_preset(Control.PRESET_CENTER)
		_fischio.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_fischio.grow_vertical = Control.GROW_DIRECTION_BOTH
		_fischio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_fischio.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_fischio.offset_left = -400
		_fischio.offset_right = 400
		_fischio.offset_top = -110
		_fischio.offset_bottom = 110
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
		_lancia = _pulsante("LANCIA", Vector2(-176, -334), Vector2(124, 124), NAVY,
				func() -> void: lancio_richiesto.emit())
		_lancia.set_meta("lancia", true)
		_lancia.add_theme_font_size_override("font_size", 30)
		# **Corpo navy, anello nel colore della palla** (LEARNED § 73, corretto il 25/10/2026):
		# pieno nel colore, con la palla rossa in mano LANCIA e FUOCO erano due tondi rossi
		# identici, e sotto il pollice davanti alla porta si sbagliava bottone. Il navy sta su
		# qualunque muro; il colore, che dice *quale* palla parte, è l'anello.
		for stato in ["normal", "hover", "focus"]:
			_lancia.add_theme_stylebox_override(stato, _tondo(NAVY, 0.92, 124))
		_lancia.add_theme_stylebox_override("pressed", _tondo(NAVY, 1.0, 124))
		_anello_lancia = _anello(124, colore)
		_lancia.add_child(_anello_lancia)
	if visibile and not colore.is_equal_approx(_colore_lancia):
		_colore_lancia = colore
		(_anello_lancia.get_theme_stylebox("panel") as StyleBoxFlat).border_color = colore
	_lancia.visible = visibile


func lancia_visibile() -> bool:
	return _lancia != null and _lancia.visible


func colore_del_lancio() -> Color:
	return _colore_lancia


## I sette pallini: uno per palla. Segnata, pieno nel suo colore; portata, bianco con
## l'anello del colore; né l'una né l'altra, navy chiaro.
func pallini(stati: Array, colori: Array = []) -> void:
	var c_erano := not _pallini.is_empty()
	_pallini = stati
	_colori_pallini = colori
	if c_erano != (not _pallini.is_empty()):
		_sistema_la_posizione()


## I sette pallini stanno nella loro lamella, in alto a destra accanto alla posizione:
## segnata, pieno nel colore; portata, l'anello acceso; nessuna delle due, navy chiaro.
## Si disegnano invece di costruirli perché sono sette tondi che cambiano ogni gol.
func _disegna_i_pallini() -> void:
	if _pallini.is_empty():
		return
	var alto := 60.0
	var sopra := 18.0
	var destra := _disegno.size.x - 24.0
	_disegna_unalamella(Rect2(destra - LARGO_PALLINI, sopra, LARGO_PALLINI, alto),
			Color(NAVY.r, NAVY.g, NAVY.b, 0.82))
	var passo := 28.0
	var y := sopra + alto * 0.5
	var x := destra - LARGO_PALLINI * 0.5 - passo * (float(_pallini.size()) - 1.0) * 0.5
	for i in _pallini.size():
		var colore: Color = _colori_pallini[i] if i < _colori_pallini.size() else Color.WHITE
		var stato := int(_pallini[i])
		var centro := Vector2(x + passo * float(i), y)
		if stato & 2:
			_disegno.draw_circle(centro, 10.0, Color.WHITE)
			_disegno.draw_arc(centro, 8.5, 0.0, TAU, 24, colore, 3.0, true)
		elif stato & 1:
			_disegno.draw_circle(centro, 10.0, colore)
		else:
			_disegno.draw_circle(centro, 10.0, NAVY_CHIARO)


## Una lamella disegnata a mano, per i pezzi che non sono nodi: stessa inclinazione
## degli StyleBox, cima verso destra.
func _disegna_unalamella(rett: Rect2, colore: Color) -> void:
	var pende := OBLIQUO * rett.size.y * 0.5
	_disegno.draw_colored_polygon(PackedVector2Array([
			Vector2(rett.position.x + pende, rett.position.y),
			Vector2(rett.end.x + pende, rett.position.y),
			Vector2(rett.end.x - pende, rett.end.y),
			Vector2(rett.position.x - pende, rett.end.y)]), colore)
	_disegno.draw_line(Vector2(rett.position.x + pende, rett.position.y + 1.0),
			Vector2(rett.end.x + pende, rett.position.y + 1.0),
			Color(ARGENTO.r, ARGENTO.g, ARGENTO.b, 0.5), 2.0)


## Il numero della bandiera coperta in un tondo nel suo colore, con la punta in giù verso
## il punto dove sta.
## Il disco navy col numero in oro, e attorno l'anello nel colore della bandiera: il
## colore dice quale bandiera è, il navy fa da fondo al numero su qualunque muro.
func _disegna_il_segnalino(dove: Vector2) -> void:
	var tondo := dove - Vector2(0, 46.0)
	var punta := PackedVector2Array([dove, tondo + Vector2(-16.0, 20.0), tondo + Vector2(16.0, 20.0)])
	_disegno.draw_colored_polygon(punta, Color(NAVY.r, NAVY.g, NAVY.b, 0.9))
	_disegno.draw_circle(tondo, 28.0, Color(NAVY.r, NAVY.g, NAVY.b, 0.9))
	_disegno.draw_arc(tondo, 28.0, 0.0, TAU, 32, _freccia_colore, 4.0, true)
	_numero_della_bandiera(tondo)


## L'annuncio grosso al centro, in una lamella: cosa è appena successo e quanto vale.
## **Le cifre sono oro**, il resto bianco (il disegno del misto 1, momenti 2 e 4).
func annuncia(testo: String) -> void:
	_testo_avviso = testo
	_avviso.text = "[center]%s[/center]" % cifre_in_oro(testo)
	# Un testo a colori non dice da solo quanto è largo (la sua misura minima è zero, e
	# dentro una lamella finirebbe spezzato): la larghezza la misura il carattere.
	_avviso.custom_minimum_size.x = carattere_titolo().get_string_size(
			testo, HORIZONTAL_ALIGNMENT_LEFT, -1, 63).x + 4.0
	_pannello_avviso.visible = testo != ""
	_pannello_avviso.modulate.a = 1.0
	_tempo_avviso = 1.6


## Quello che l'annuncio dice adesso, senza i colori: lo leggono i collaudi.
func testo_annunciato() -> String:
	return _testo_avviso


static var _numeri: RegEx = null


## «+25 · DIRETTO» → il «+25» in oro. Vale per ogni numero del testo, col suo segno più:
## i punti, i secondi rubati, il numero della bandiera.
static func cifre_in_oro(testo: String) -> String:
	if _numeri == null:
		_numeri = RegEx.new()
		_numeri.compile("(\\+?\\d+)")
	return _numeri.sub(testo, "[color=#ffc42e]$1[/color]", true)


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
		var posto := int(dato["posizione"])
		(riga["posizione"] as Label).text = "%d" % posto
		(riga["nome"] as Label).text = String(dato["nome"])
		(riga["punti"] as Label).text = valore_di(dato)
		# La tua riga è bianca col testo navy: l'oro resta al primo.
		var tinta := NAVY if tuo else Color.WHITE
		for chiave in ["nome", "punti"]:
			(riga[chiave] as Label).add_theme_color_override("font_color", tinta)
		pannello.add_theme_stylebox_override("panel",
				_stile_riga_tua if tuo else _stile_riga)
		(riga["quadrato"] as PanelContainer).add_theme_stylebox_override("panel",
				_stili_quadrato[mini(posto, 4) - 1])
		(riga["posizione"] as Label).add_theme_color_override("font_color",
				NAVY if posto <= 3 else Color.WHITE)


## Il numero di una riga: i punti, o quello che la riga dice al loro posto — in GARA le
## bandiere, «3/7».
static func valore_di(dato: Dictionary) -> String:
	return String(dato["testo"]) if dato.has("testo") else "%d" % int(dato["punti"])


## Si spegne quando la partita non c'è: fuori dalla sfida l'arena è un posto in
## cui si gira per guardarla, e una classifica ferma a zero è rumore.
func spegni_la_classifica() -> void:
	if _classifica != null:
		_classifica.visible = false


## La colonna sta a sinistra, sotto l'ESCI: righe larghe 250 e alte 44, la quarta
## finisce a 286, lontana dalla fascia dove si appoggia il pollice sinistro.
## **Gli stili si fanno una volta sola**: in partita la classifica si riscrive a ogni
## colpo, e fabbricare sei StyleBox per riga sessanta volte al secondo è lavoro buttato.
func _costruisci_la_classifica() -> void:
	_stile_riga = lamella(NAVY, 0.82, 10, 18)
	_stile_riga_tua = lamella(Color.WHITE, 1.0, 10, 18)
	for posto in [1, 2, 3, 4]:
		_stili_quadrato.append(_quadrato(colore_del_posto(posto)))

	_classifica = VBoxContainer.new()
	_classifica.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_classifica.position = Vector2(24, 92)
	_classifica.add_theme_constant_override("separation", 6)
	_classifica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_classifica)

	for i in 8:
		var pannello := PanelContainer.new()
		pannello.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pannello.custom_minimum_size = Vector2(250, 44)
		pannello.add_theme_stylebox_override("panel", _stile_riga)
		var riga := HBoxContainer.new()
		riga.add_theme_constant_override("separation", 12)
		riga.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pannello.add_child(riga)

		# Il quadrato del posto: oro, argento, bronzo, e navy chiaro dal quarto in giù.
		var quadrato := PanelContainer.new()
		quadrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quadrato.custom_minimum_size = Vector2(36, 32)
		quadrato.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		quadrato.add_theme_stylebox_override("panel", _stili_quadrato[0])
		var posizione := _etichetta(28, NAVY)
		posizione.add_theme_font_override("font", carattere_titolo())
		posizione.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		posizione.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		quadrato.add_child(posizione)
		riga.add_child(quadrato)

		var nome := _etichetta(26, Color.WHITE)
		nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var punti := _etichetta(30, Color.WHITE)
		punti.add_theme_font_override("font", carattere_titolo())
		punti.custom_minimum_size = Vector2(58, 0)
		punti.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		punti.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		for pezzo in [nome, punti]:
			riga.add_child(pezzo)

		_classifica.add_child(pannello)
		_righe_classifica.append({"pannello": pannello, "quadrato": quadrato,
				"posizione": posizione, "nome": nome, "punti": punti})


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
		# I punti saltano fuori dove succede, in Bebas col contorno navy: sono l'unica
		# scritta che vive sulla scena nuda, e senza contorno sul cielo chiaro sparisce.
		var etichetta := _etichetta(37, Color.WHITE, 8)
		etichetta.add_theme_font_override("font", carattere_titolo())
		etichetta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		etichetta.visible = false
		add_child(etichetta)
		_etichette_volanti.append({"etichetta": etichetta, "punto": Vector3.ZERO, "vita": 0.0})

	_riga_alta = _etichetta(30, Color(1, 1, 1, 0.95), 6)
	_riga_alta.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_riga_alta.position = Vector2(28, 20)
	_riga_alta.size = Vector2(700, 44)
	add_child(_riga_alta)

	_riga_bassa = _etichetta(20, Color(1, 1, 1, 0.6), 6)
	_riga_bassa.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_riga_bassa.position = Vector2(28, 62)
	_riga_bassa.size = Vector2(900, 40)
	add_child(_riga_bassa)

	# La lamella dell'annuncio: centrata, il suo centro a 236 come nel disegno.
	_pannello_avviso = PanelContainer.new()
	_pannello_avviso.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_pannello_avviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pannello_avviso.offset_top = 196
	_pannello_avviso.custom_minimum_size = Vector2(0, 80)
	_pannello_avviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pannello_avviso.add_theme_stylebox_override("panel", lamella(NAVY, 0.85, 60, 60))
	_pannello_avviso.visible = false
	add_child(_pannello_avviso)
	_avviso = RichTextLabel.new()
	_avviso.bbcode_enabled = true
	_avviso.fit_content = true
	_avviso.scroll_active = false
	_avviso.autowrap_mode = TextServer.AUTOWRAP_OFF
	_avviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avviso.add_theme_font_override("normal_font", carattere_titolo())
	_avviso.add_theme_font_size_override("normal_font_size", 63)
	_avviso.add_theme_color_override("default_color", Color.WHITE)
	_pannello_avviso.add_child(_avviso)

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


## L'anello dentro un pulsante tondo: un pannello vuoto col solo bordo, sei punti dentro
## il suo. Navy nel FUOCO, nel colore della palla portata nel LANCIA.
func _anello(lato: float, colore := NAVY) -> Panel:
	var anello := Panel.new()
	anello.set_anchors_preset(Control.PRESET_FULL_RECT)
	anello.offset_left = 6
	anello.offset_top = 6
	anello.offset_right = -6
	anello.offset_bottom = -6
	anello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stile := StyleBoxFlat.new()
	stile.bg_color = Color(0, 0, 0, 0)
	stile.set_corner_radius_all(int(lato * 0.5))
	stile.set_border_width_all(6)
	stile.border_color = colore
	stile.anti_aliasing = true
	anello.add_theme_stylebox_override("panel", stile)
	return anello


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


## Un'etichetta dell'interfaccia. **Il contorno si chiede**: dentro una lamella il testo
## sta su un fondo e un contorno lo sporcherebbe; sulla scena nuda (il VIA, i punti che
## salgono, i numeri delle bandiere) senza contorno non si legge.
func _etichetta(dimensione: int, colore: Color, contorno := 0) -> Label:
	var etichetta := Label.new()
	etichetta.add_theme_font_size_override("font_size", dimensione)
	etichetta.add_theme_color_override("font_color", colore)
	if contorno > 0:
		etichetta.add_theme_color_override("font_outline_color", NAVY)
		etichetta.add_theme_constant_override("outline_size", contorno)
	etichetta.add_theme_font_override("font", carattere_testo())
	etichetta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etichetta


## **Una lamella**: il pezzo di cui è fatta tutta l'interfaccia. Navy all'82 % con il
## filo d'argento in cima, che tiene il profilo anche sopra i muri blu; oro per la tua
## riga del podio e per RIGIOCA; bianca per la tua riga della classifica.
static func lamella(colore: Color, opacita := 0.82, margine_sx := 20, margine_dx := 20) -> StyleBoxFlat:
	var stile := StyleBoxFlat.new()
	stile.bg_color = Color(colore.r, colore.g, colore.b, opacita)
	stile.set_corner_radius_all(4)
	stile.skew = Vector2(OBLIQUO, 0.0)
	stile.border_width_top = 2
	stile.border_color = Color(ARGENTO.r, ARGENTO.g, ARGENTO.b, 0.5)
	stile.shadow_color = Color(0, 0, 0, 0.3)
	stile.shadow_size = 10
	stile.shadow_offset = Vector2(0, 4)
	stile.content_margin_left = margine_sx
	stile.content_margin_right = margine_dx
	stile.content_margin_top = 0
	stile.content_margin_bottom = 0
	stile.anti_aliasing = true
	return stile


## Il quadrato del posto dentro la riga: pende come la lamella, la cifra dentro sta dritta.
func _quadrato(colore: Color) -> StyleBoxFlat:
	var stile := StyleBoxFlat.new()
	stile.bg_color = colore
	stile.set_corner_radius_all(3)
	stile.skew = Vector2(OBLIQUO, 0.0)
	stile.anti_aliasing = true
	return stile


## Oro al primo, argento al secondo, bronzo al terzo; dal quarto in giu' navy chiaro.
static func colore_del_posto(posto: int) -> Color:
	match posto:
		1: return ORO
		2: return ARGENTO
		3: return BRONZO
	return NAVY_CHIARO



# ------------------------------------------------------------------ la partita

## I due caratteri dell'interfaccia (tappa 11, blocco C3a, il misto 1 scelto il
## 24/10/2026): le cifre e i titoli in **Bebas Neue**, i testi in **Barlow Condensed**
## SemiBold. Russo One ed Exo 2 venivano dalla Home al neon e non da un'arena-giocattolo.
## Tutti e due SIL OFL. Caricati una volta; se mancano si torna a quello del motore.
const CARATTERE_TESTO := "res://assets/font/BarlowCondensed-SemiBold.ttf"
const CARATTERE_TITOLO := "res://assets/font/BebasNeue-Regular.ttf"
static var _testo: Font = null
static var _titolo: Font = null

var _cronometro: Label
var _pannello_posizione: PanelContainer
var _posizione_grande: Label
var _punti_piccoli: Label
var _in_partita := false
var _bottone_esci: Button
var _podio: Control
var _podio_posizione: Label
var _podio_tempo: Label
var _righe_podio: Array[Dictionary] = []
var _fischio: Label
var _tempo_fischio := 0.0
var _pillole: HBoxContainer


static func carattere_testo() -> Font:
	if _testo == null:
		# Il file è già SemiBold: il peso non si chiede più al motore (Exo 2 era
		# variabile, Barlow Condensed no, e una FontVariation su un carattere fisso
		# non fa niente).
		var base: Font = load(CARATTERE_TESTO) if ResourceLoader.exists(CARATTERE_TESTO) else null
		_testo = base if base != null else ThemeDB.fallback_font
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
	# In GARA, al posto dei punti, la bandiera che devi toccare: «· BANDIERA 3 DI 7».
	_punti_piccoli.text = ("· " + sotto) if sotto != "" else "%d PUNTI" % punti


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
	_disegno.draw_colored_polygon(tre, Color(NAVY.r, NAVY.g, NAVY.b, 0.9))
	_disegno.draw_polyline(PackedVector2Array([punta, dietro + lato * 32.0, dietro - lato * 32.0,
			punta]), _freccia_colore, 4.0, true)
	if _freccia_testo == "":
		return
	# Il numero in un disco navy con l'anello nel colore della bandiera, dietro la freccia.
	var tondo := dove - verso * 64.0
	_disegno.draw_circle(tondo, 28.0, Color(NAVY.r, NAVY.g, NAVY.b, 0.9))
	_disegno.draw_arc(tondo, 28.0, 0.0, TAU, 32, _freccia_colore, 4.0, true)
	_numero_della_bandiera(tondo)


## Il numero della bandiera dentro il disco: Bebas oro, col contorno navy.
func _numero_della_bandiera(tondo: Vector2) -> void:
	var font := carattere_titolo()
	var dove_testo := tondo + Vector2(-40.0, 14.0)
	_disegno.draw_string_outline(font, dove_testo, _freccia_testo, HORIZONTAL_ALIGNMENT_CENTER,
			80.0, 38, 8, NAVY)
	_disegno.draw_string(font, dove_testo, _freccia_testo, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 38,
			ORO)


## Il giro che si fa una volta sola, quando la partita comincia: costa
## l'attraversamento di tutti i pulsanti, e in partita si chiama sessanta volte
## al secondo.
func _accendi_la_partita() -> void:
	_riga_alta.visible = false
	_riga_bassa.visible = false
	# I due pulsanti del gioco: **tondi e a icona** (tappa 8, blocco G), come in ogni
	# sparatutto per telefono di oggi — il dardo che parte, le due frecce in su. E
	# coprenti: a un terzo di opacità il loro colore lo faceva il muro dietro.
	# Il rosso del fuoco e il navy del salto: gli stessi due colori di tutto il resto.
	var pieni := {"FUOCO": ROSSO_FUOCO, "SALTA": NAVY}
	var coprenza := {"FUOCO": 0.92, "SALTA": 0.70}
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
		var coprente: float = coprenza[pulsante.text]
		for stato in ["normal", "hover", "focus"]:
			pulsante.add_theme_stylebox_override(stato, _tondo(pieni[pulsante.text], coprente, lato))
		pulsante.add_theme_stylebox_override("pressed",
				_tondo(pieni[pulsante.text], minf(coprente + 0.3, 1.0), lato))
		# L'anello navy dentro il FUOCO, a sei dal bordo: è quello che lo stacca da
		# qualunque muro rosso gli finisca dietro.
		if pulsante.text == "FUOCO" and not pulsante.has_meta("anello"):
			pulsante.add_child(_anello(lato))
			pulsante.set_meta("anello", true)
		pulsante.set_meta("nome", pulsante.text)
		pulsante.icon = load(icone[pulsante.text])
		pulsante.expand_icon = true
		pulsante.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pulsante.add_theme_constant_override("icon_max_width", int(lato * 0.52))
		pulsante.text = ""
	if _cronometro == null:
		_costruisci_la_partita()
	# La porta della stanza. Sul telefono il gioco sta a schermo intero e non ha
	# un tasto indietro: senza questo, una partita da tre minuti è una stanza
	# senza uscita. Piccolo e spento, in alto a sinistra, dove non passa nessun
	# pollice.
	if _bottone_esci == null:
		_bottone_esci = _pulsante("", Vector2.ZERO, Vector2(64, 60),
				NAVY, func() -> void: uscita_richiesta.emit())
		_bottone_esci.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_bottone_esci.offset_left = 24
		_bottone_esci.offset_top = 18
		_bottone_esci.offset_right = 24 + 64
		_bottone_esci.offset_bottom = 18 + 60
		for stato in ["normal", "hover", "focus"]:
			_bottone_esci.add_theme_stylebox_override(stato, lamella(NAVY, 0.82, 0, 0))
		_bottone_esci.add_theme_stylebox_override("pressed", lamella(NAVY, 0.95, 0, 0))
		_bottone_esci.set_meta("nome", "ESCI")
		_bottone_esci.icon = load(ICONA_ESCI)
		_bottone_esci.expand_icon = true
		_bottone_esci.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_bottone_esci.add_theme_constant_override("icon_max_width", 33)
	_bottone_esci.visible = true


## **Il tabellone** (misto 1): il cronometro in una lamella al centro, la posizione in
## una a destra, la colonna della classifica a sinistra. Tutto nella fascia alta, che è
## l'unica senza pollici sopra.
func _costruisci_la_partita() -> void:
	var pillola := PanelContainer.new()
	pillola.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pillola.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pillola.offset_top = 18
	pillola.custom_minimum_size = Vector2(164, 60)
	pillola.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pillola.add_theme_stylebox_override("panel", lamella(NAVY, 0.82))
	add_child(pillola)
	_cronometro = _etichetta(52, Color.WHITE)
	_cronometro.add_theme_font_override("font", carattere_titolo())
	_cronometro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cronometro.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pillola.add_child(_cronometro)

	# La posizione e quello che le sta accanto — i punti, o la bandiera in GARA — stanno
	# nella stessa lamella, che **cresce col testo**: «BANDIERA 3 DI 7» è lungo il doppio
	# di «25 PUNTI», e una larghezza fissa lo manderebbe a capo.
	_pannello_posizione = PanelContainer.new()
	_pannello_posizione.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pannello_posizione.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_pannello_posizione.offset_top = 18
	_pannello_posizione.custom_minimum_size = Vector2(300, 60)
	_pannello_posizione.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pannello_posizione.add_theme_stylebox_override("panel", lamella(NAVY, 0.82))
	add_child(_pannello_posizione)
	var dentro := HBoxContainer.new()
	dentro.add_theme_constant_override("separation", 12)
	dentro.alignment = BoxContainer.ALIGNMENT_CENTER
	dentro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pannello_posizione.add_child(dentro)

	_posizione_grande = _etichetta(55, Color.WHITE)
	_posizione_grande.add_theme_font_override("font", carattere_titolo())
	_posizione_grande.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dentro.add_child(_posizione_grande)

	_punti_piccoli = _etichetta(26, Color.WHITE)
	_punti_piccoli.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dentro.add_child(_punti_piccoli)
	_sistema_la_posizione()


## Dove finisce la lamella della posizione: contro il bordo destro, o più a sinistra per
## lasciare il posto ai sette pallini della PALLA.
func _sistema_la_posizione() -> void:
	if _pannello_posizione == null:
		return
	var margine := 24.0 if _pallini.is_empty() else 24.0 + LARGO_PALLINI + 12.0
	_pannello_posizione.offset_left = -margine
	_pannello_posizione.offset_right = -margine


# ------------------------------------------------------------------- il podio

## **Il podio.** Scaduto il tempo, la partita si guarda da fuori: i sei in ordine
## d'arrivo, la tua posizione grande, e **RIGIOCA a un tocco** — che è il momento
## in cui il gioco chiede «un'altra?», la domanda di tutta la tappa 7.
##
## Le righe arrivano già ordinate da chi tiene il punteggio: qui si scrivono e
## basta. Si costruisce la prima volta che serve e poi si riaccende: a fine
## partita un fotogramma lento non si vede, ma il podio si riapre a ogni RIGIOCA.
func podio(righe: Array, posizione: int, tempo := "") -> void:
	if _podio == null:
		_costruisci_il_podio()
	# **Il verdetto sta nel titolo, non in un annuncio sopra il podio** (corretto il
	# 25/10/2026): annuncio e podio partivano nello stesso istante e nello stesso posto, e
	# «HAI VINTO» copriva la tua riga della classifica prima di sbiadirci dietro. Chi ha
	# vinto, quando non sei tu, si legge nella prima riga, quella col quadrato oro.
	annuncia("")
	_podio_posizione.text = "HAI VINTO" if posizione == 1 else "SEI %d°" % posizione
	# Il tempo, quando la partita l'ha chiusa un traguardo e non il cronometro: in una gara
	# è il risultato, e il podio copre il quadrante.
	_podio_tempo.text = tempo
	_podio_tempo.visible = tempo != ""
	for i in _righe_podio.size():
		var riga: Dictionary = _righe_podio[i]
		var scatola: PanelContainer = riga["riga"]
		if i >= righe.size():
			scatola.visible = false
			continue
		scatola.visible = true
		var dato: Dictionary = righe[i]
		var tuo := bool(dato.get("tu", false))
		var posto := int(dato["posizione"])
		(riga["posizione"] as Label).text = "%d" % posto
		(riga["nome"] as Label).text = String(dato["nome"])
		(riga["punti"] as Label).text = valore_di(dato)
		var tinta := NAVY if tuo else Color.WHITE
		for chiave in ["nome", "punti"]:
			(riga[chiave] as Label).add_theme_color_override("font_color", tinta)
		scatola.add_theme_stylebox_override("panel",
				_stile_riga_tua if tuo else _stile_riga)
		(riga["quadrato"] as PanelContainer).add_theme_stylebox_override("panel",
				_stili_quadrato[mini(posto, 4) - 1])
		(riga["posizione"] as Label).add_theme_color_override("font_color",
				NAVY if posto <= 3 else Color.WHITE)
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
		_pillole.offset_top = 90
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
		var testo := pillola.get_child(0) as Label
		testo.text = String(voci[i]["testo"])
		# Scritta bianca sul colore scuro, navy su quello chiaro: il giallo del punti
		# doppi con sopra il bianco non si leggeva.
		testo.add_theme_color_override("font_color",
				NAVY if colore.get_luminance() > 0.55 else Color.WHITE)
	_pillole.visible = not voci.is_empty()


func _pillola() -> PanelContainer:
	var pillola := PanelContainer.new()
	pillola.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pillola.custom_minimum_size = Vector2(0, 40)
	pillola.add_theme_stylebox_override("panel", lamella(Color.WHITE, 0.92, 18, 18))
	var testo := _etichetta(24, Color.WHITE)
	testo.add_theme_font_override("font", carattere_titolo())
	testo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pillola.add_child(testo)
	return pillola


func spegni_il_podio() -> void:
	if _podio != null:
		_podio.visible = false
	if _bottone_esci != null and _in_partita:
		_bottone_esci.visible = true


## **Il podio del misto 1**: niente pannello scuro: un velo navy su tutto, il titolo in
## una lamella oro e sotto le sei righe, la tua bianca. I due pulsanti chiudono la pila.
func _costruisci_il_podio() -> void:
	_podio = Control.new()
	_podio.set_anchors_preset(Control.PRESET_FULL_RECT)
	_podio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_podio)

	var velo := ColorRect.new()
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.color = Color(NAVY.r, NAVY.g, NAVY.b, 0.4)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_podio.add_child(velo)

	var colonna := VBoxContainer.new()
	colonna.set_anchors_preset(Control.PRESET_CENTER)
	colonna.grow_horizontal = Control.GROW_DIRECTION_BOTH
	colonna.grow_vertical = Control.GROW_DIRECTION_BOTH
	colonna.add_theme_constant_override("separation", 6)
	colonna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_podio.add_child(colonna)

	var titolo := PanelContainer.new()
	titolo.custom_minimum_size = Vector2(420, 64)
	titolo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	titolo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titolo.add_theme_stylebox_override("panel", lamella(ORO, 1.0))
	_podio_posizione = _etichetta(52, NAVY)
	_podio_posizione.add_theme_font_override("font", carattere_titolo())
	_podio_posizione.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_podio_posizione.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titolo.add_child(_podio_posizione)
	colonna.add_child(titolo)

	# Sotto il titolo, in oro sul velo: «IN 44,6 S». Si accende solo quando c'è un tempo da
	# dire, cioè quando la partita è finita a un traguardo. Il contorno navy perché l'oro,
	# da solo sul cielo azzurro dietro il podio, spariva (LEARNED § 73).
	_podio_tempo = _etichetta(32, ORO, 8)
	_podio_tempo.add_theme_font_override("font", carattere_titolo())
	_podio_tempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_podio_tempo.visible = false
	colonna.add_child(_podio_tempo)

	for i in 6:
		var scatola := PanelContainer.new()
		scatola.custom_minimum_size = Vector2(560, 48)
		scatola.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		scatola.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scatola.add_theme_stylebox_override("panel", _stile_riga)
		var riga := HBoxContainer.new()
		riga.add_theme_constant_override("separation", 16)
		riga.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scatola.add_child(riga)

		var quadrato := PanelContainer.new()
		quadrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quadrato.custom_minimum_size = Vector2(36, 32)
		quadrato.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		quadrato.add_theme_stylebox_override("panel", _stili_quadrato[0])
		var posizione := _etichetta(28, NAVY)
		posizione.add_theme_font_override("font", carattere_titolo())
		posizione.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		posizione.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		quadrato.add_child(posizione)
		riga.add_child(quadrato)

		var nome := _etichetta(28, Color.WHITE)
		nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var punti := _etichetta(30, Color.WHITE)
		punti.add_theme_font_override("font", carattere_titolo())
		punti.custom_minimum_size = Vector2(90, 0)
		punti.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		punti.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		for pezzo in [nome, punti]:
			riga.add_child(pezzo)

		colonna.add_child(scatola)
		_righe_podio.append({"riga": scatola, "quadrato": quadrato,
				"posizione": posizione, "nome": nome, "punti": punti})

	var tasti := HBoxContainer.new()
	tasti.add_theme_constant_override("separation", 20)
	tasti.alignment = BoxContainer.ALIGNMENT_CENTER
	tasti.custom_minimum_size = Vector2(0, 90)
	tasti.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonna.add_child(tasti)
	tasti.add_child(_tasto_del_podio("RIGIOCA", ORO, NAVY,
			func() -> void: rigioca_richiesta.emit()))
	tasti.add_child(_tasto_del_podio("ESCI", NAVY, Color.WHITE,
			func() -> void: uscita_richiesta.emit()))


## I pulsanti del podio stanno **dentro** il pannello, quindi non si posizionano
## come gli altri: li mette in fila il contenitore.
func _tasto_del_podio(testo: String, colore: Color, tinta: Color, azione: Callable) -> Button:
	var pulsante := Button.new()
	pulsante.text = testo
	pulsante.custom_minimum_size = Vector2(240, 80)
	pulsante.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pulsante.add_theme_font_size_override("font_size", 34)
	pulsante.add_theme_font_override("font", carattere_titolo())
	pulsante.add_theme_color_override("font_color", tinta)
	pulsante.add_theme_color_override("font_hover_color", tinta)
	pulsante.add_theme_color_override("font_pressed_color", tinta)
	for stato in ["normal", "hover", "focus"]:
		pulsante.add_theme_stylebox_override(stato, lamella(colore, 0.95))
	pulsante.add_theme_stylebox_override("pressed", lamella(colore, 1.0))
	pulsante.pressed.connect(azione)
	return pulsante
