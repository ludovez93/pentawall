class_name Ingresso
extends Control

## La schermata d'ingresso (tappa 7, blocco C).
##
## Fino al 17/09/2026 il gioco si apriva nel **poligono**, che è un banco di
## prova: chi arrivava dal link si trovava in una stanza con sette pulsanti e
## nessuno gli diceva cosa fare. Qui c'è il nome, **GIOCA**, e basta.
##
## I banchi di prova non spariscono — servono a noi — ma stanno **dietro un
## gesto**: cinque tocchi sulla riga della versione, in basso a destra. È la
## stessa riga che dice quale pubblicazione sta servendo la pagina, e che si
## guarda quando un difetto «non si è chiuso» (`LEARNED.md` § 32).
##
## Il pulsante del **dardo** resta in vista: 19 o 24 m/s è una domanda aperta a
## Ludovico (blocco B), e una domanda nascosta dietro un gesto non gliela si può
## più fare. Il giorno che decide, questo pulsante se ne va.

const TOCCHI_PER_APRIRE := 5

var _versione := "locale"
var _riga_versione: Button
var _tocchi := 0
var _banco: HBoxContainer
var _bottone_dardo: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_fondo()
	_titolo()
	_pulsanti()
	_leggi_la_versione()
	# Chi torna qui dal podio non deve ritrovarsi in partita al tocco seguente.
	Arena.modo_partita = false


func _fondo() -> void:
	var tinta := ColorRect.new()
	tinta.set_anchors_preset(Control.PRESET_FULL_RECT)
	tinta.color = Color(0.02, 0.02, 0.05)
	tinta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tinta)

	# Un alone al centro, nei colori dell'arena: il fondo piatto fa schermata di
	# errore, non ingresso di un gioco.
	var alone := GradientTexture2D.new()
	alone.width = 256
	alone.height = 256
	alone.fill = GradientTexture2D.FILL_RADIAL
	alone.fill_from = Vector2(0.5, 0.42)
	alone.fill_to = Vector2(1.0, 0.95)
	var sfumatura := Gradient.new()
	sfumatura.set_color(0, Color(0.16, 0.12, 0.34))
	sfumatura.set_color(1, Color(0.02, 0.02, 0.05))
	alone.gradient = sfumatura
	var quadro := TextureRect.new()
	quadro.set_anchors_preset(Control.PRESET_FULL_RECT)
	quadro.texture = alone
	quadro.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	quadro.stretch_mode = TextureRect.STRETCH_SCALE
	quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(quadro)


func _titolo() -> void:
	var nome := Label.new()
	nome.text = "PENTAWALL"
	nome.set_anchors_preset(Control.PRESET_TOP_WIDE)
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.offset_top = 120
	nome.offset_bottom = 252
	nome.add_theme_font_override("font", _titolo_spaziato())
	nome.add_theme_font_size_override("font_size", 96)
	nome.add_theme_color_override("font_color", Color(1, 1, 1, 0.97))
	nome.add_theme_color_override("font_outline_color", Color(0.35, 0.95, 0.92, 0.45))
	nome.add_theme_constant_override("outline_size", 10)
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nome)

	var sotto := Label.new()
	sotto.text = "IL DARDO RIMBALZA FINO A CINQUE MURI"
	sotto.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sotto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sotto.offset_top = 256
	sotto.offset_bottom = 300
	sotto.add_theme_font_override("font", Comandi.carattere_testo())
	sotto.add_theme_font_size_override("font_size", 22)
	sotto.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	sotto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sotto)

	# Un filo di luce fra il nome e la riga sotto: senza, a novantasei punti il
	# sottotitolo sembra appoggiato sulle gambe della W.
	var filo := ColorRect.new()
	filo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	filo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	filo.color = Color(0.35, 0.95, 0.92, 0.45)
	filo.offset_left = -110
	filo.offset_right = 110
	filo.offset_top = 236
	filo.offset_bottom = 238
	filo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(filo)


## Il carattere del titolo con le lettere staccate: a novantasei punti, attaccate,
## PENTAWALL è un blocco.
func _titolo_spaziato() -> Font:
	var variante := FontVariation.new()
	variante.base_font = Comandi.carattere_titolo()
	variante.spacing_glyph = 10
	return variante


func _pulsanti() -> void:
	var gioca := _pulsante("GIOCA", Vector2(300, 108), Color(0.2, 0.75, 0.45), _comincia)
	gioca.add_theme_font_size_override("font_size", 40)
	gioca.set_anchors_preset(Control.PRESET_CENTER)
	gioca.grow_horizontal = Control.GROW_DIRECTION_BOTH
	gioca.grow_vertical = Control.GROW_DIRECTION_BOTH
	gioca.offset_left = -150
	gioca.offset_right = 150
	gioca.offset_top = 16
	gioca.offset_bottom = 124
	add_child(gioca)

	# Il banco di prova: c'è, ma spento, finché non lo si chiama col gesto.
	_banco = HBoxContainer.new()
	_banco.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_banco.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banco.offset_top = -182
	_banco.offset_bottom = -110
	_banco.add_theme_constant_override("separation", 14)
	_banco.visible = false
	add_child(_banco)
	_banco.add_child(_pulsante("ARENA LIBERA", Vector2(210, 72), Color(0.35, 0.45, 0.7),
			func() -> void: _vai("res://scenes/arena.tscn")))
	_banco.add_child(_pulsante("POLIGONO", Vector2(180, 72), Color(0.35, 0.4, 0.55),
			func() -> void: _vai("res://scenes/poligono.tscn")))
	_banco.add_child(_pulsante("ANGOLO", Vector2(170, 72), Color(0.35, 0.4, 0.55),
			func() -> void: _vai("res://scenes/angolo.tscn")))

	_bottone_dardo = _pulsante("DARDO 19", Vector2(150, 64), Color(0.8, 0.55, 0.25),
			_commuta_dardo)
	_bottone_dardo.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_bottone_dardo.offset_left = 30
	_bottone_dardo.offset_right = 180
	_bottone_dardo.offset_top = -92
	_bottone_dardo.offset_bottom = -28
	_bottone_dardo.add_theme_font_size_override("font_size", 20)
	add_child(_bottone_dardo)
	_scrivi_il_dardo()

	_riga_versione = _pulsante("", Vector2(238, 52), Color(0, 0, 0), _tocco)
	_riga_versione.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_riga_versione.offset_left = -260
	_riga_versione.offset_right = -22
	_riga_versione.offset_top = -80
	_riga_versione.offset_bottom = -28
	_riga_versione.add_theme_font_size_override("font_size", 17)
	_riga_versione.add_theme_font_override("font", Comandi.carattere_testo())
	_riga_versione.add_theme_color_override("font_color", Color(1, 1, 1, 0.32))
	for stato in ["normal", "hover", "focus", "pressed"]:
		_riga_versione.add_theme_stylebox_override(stato, StyleBoxEmpty.new())
	add_child(_riga_versione)
	_scrivi_la_versione()


func _pulsante(testo: String, misura: Vector2, colore: Color, azione: Callable) -> Button:
	var pulsante := Button.new()
	pulsante.text = testo
	pulsante.custom_minimum_size = misura
	pulsante.add_theme_font_size_override("font_size", 24)
	pulsante.add_theme_font_override("font", Comandi.carattere_titolo())
	pulsante.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	for stato in ["normal", "hover", "focus"]:
		pulsante.add_theme_stylebox_override(stato, _sfondo(colore, 0.55))
	pulsante.add_theme_stylebox_override("pressed", _sfondo(colore, 0.85))
	pulsante.pressed.connect(azione)
	return pulsante


func _sfondo(colore: Color, opacita: float) -> StyleBoxFlat:
	var stile := StyleBoxFlat.new()
	stile.bg_color = Color(colore.r, colore.g, colore.b, opacita)
	stile.set_corner_radius_all(24)
	stile.border_width_bottom = 2
	stile.border_width_top = 2
	stile.border_width_left = 2
	stile.border_width_right = 2
	stile.border_color = Color(1, 1, 1, 0.22)
	return stile


func _comincia() -> void:
	Arena.modo_partita = true
	_vai("res://scenes/arena.tscn")


func _vai(scena: String) -> void:
	get_tree().change_scene_to_file(scena)


## Il gesto nascosto: cinque tocchi sulla riga della versione.
func _tocco() -> void:
	_tocchi += 1
	if _tocchi < TOCCHI_PER_APRIRE:
		return
	_banco.visible = true
	_riga_versione.add_theme_color_override("font_color", Color(0.35, 0.95, 0.92, 0.7))


## Se il banco di prova è aperto. Serve al collaudo, che deve poter dire se il
## gesto funziona senza guardare lo schermo.
func banco_aperto() -> bool:
	return _banco != null and _banco.visible


func _commuta_dardo() -> void:
	if is_equal_approx(Proiettile.velocita, Proiettile.VELOCITA_BASE):
		Proiettile.velocita = Proiettile.VELOCITA_VELOCE
	else:
		Proiettile.velocita = Proiettile.VELOCITA_BASE
	_scrivi_il_dardo()


func _scrivi_il_dardo() -> void:
	_bottone_dardo.text = "DARDO %d" % int(round(Proiettile.velocita))


## La versione la conosce solo la pagina: `versione.txt` lo scrive la lavorazione
## accanto al gioco. Sul PC non c'è, e la riga dice «locale».
func _leggi_la_versione() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		window.__pw_v = window.__pw_v || '?';
		fetch('versione.txt', {cache: 'no-cache'})
			.then(function (r) { return r.text(); })
			.then(function (t) { window.__pw_v = t.trim().slice(0, 7); })
			.catch(function () {});
	""")
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var letta: Variant = JavaScriptBridge.eval("String(window.__pw_v || '?')", true)
		if letta is String:
			_versione = String(letta)
		_scrivi_la_versione())


func _scrivi_la_versione() -> void:
	if _riga_versione != null:
		_riga_versione.text = "versione %s" % _versione
