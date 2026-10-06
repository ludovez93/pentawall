class_name BancoScheda
extends Node

## **Il banco della scheda video** (tappa 9, seconda parte, 04/10/2026).
##
## Il telefono va a 30 fotogrammi al secondo, e la sonda dice che il gioco lavora
## 5-6 ms su 33: il resto è la scheda video, o il browser fra il gioco e la scheda. Da
## qui la scheda del telefono non si misura, e tagliare al buio costerebbe una partita
## per ogni tentativo. Il banco si apre da un indirizzo (`…/pentawall/?scheda`),
## entra in partita da solo, ferma i sei corpi in vista dal ballatoio e poi **spegne
## una cosa alla volta**. Per ognuna misura due numeri:
## - i fotogrammi al secondo come li vede chi gioca, a scalini (60 o 30);
## - **il costo vero di un fotogramma**: a fine fotogramma si chiede un pixel alla
##   scheda video, e la risposta arriva solo quando la scheda ha finito tutto. Così lo
##   scalino dei 30 non nasconde niente: 19 ms e 31 ms restano due numeri diversi.
## Il costo si divide in due: **il lavoro** del gioco (calcolo e preparazione del
## disegno, fino all'ultima chiamata) e **l'attesa** della scheda dopo l'ultima
## chiamata. Ogni misura manda una riga alla sonda, con `scena=banco`. Dal gioco normale non si
## arriva qui, e i banchi di prova dietro i cinque tocchi sono un'altra cosa.
##
## **Il telefono ha due velocità** (04/10/2026, primo banco in Safari). Per i primi
## 20-35 secondi di gioco un fotogramma costava 12 ms; poi, con la stessa inquadratura
## ferma, 43-46 ms, fino alla fine. Le partite dalla Home fanno lo stesso: 60 fotogrammi
## per una ventina di secondi, poi meno. Sul PC, in due minuti e mezzo di partita, nodi e
## memoria restano fermi: non è il gioco che cresce, è il telefono che dopo lo scatto
## iniziale rallenta (calore o tetto di consumo: da qui non si distingue). Quello che
## conta è la seconda velocità, dove si gioca quasi tutta la partita. Quindi il banco:
## - prima **scalda**: misura l'inquadratura com'è (`caldo`) per un minuto e mezzo, e
##   le righe mostrano quando il telefono cambia velocità;
## - poi misura **a coppie**: ogni voce subito dopo una misura di riferimento (`base`),
##   così ogni confronto è fra due momenti vicini, con il telefono nello stesso stato.
##   Nel primo banco le voci stavano in fila fra due «base», e quando il telefono ha
##   cambiato velocità a metà non si poteva più confrontare niente.

## Le voci, in ordine; ognuna preceduta da una misura «base».
## «animazioni» lascia i corpi in scena ma ferma i loro scheletri: in Compatibility
## ogni pezzo di corpo animato si deforma a ogni fotogramma con un passaggio suo sulla
## scheda (`mesh_storage.cpp` di 4.7.2, `update_mesh_instances`), e questa voce dice
## quanto costa deformare rispetto a disegnare.
## «pieno» rimette tutti i corpi ad animarsi a ogni fotogramma, com'era fino al
## 04/10/2026 (`Corpo.ritmo_pieno`): dice quanto vale il ritmo.
## Le voci si possono scegliere dall'indirizzo: `?scheda=risoluzione,lampade`; e il
## riscaldamento con `caldo=` in secondi (`?scheda=lampade&caldo=0`).
## «pixel» rimette la luce su ogni pixel ai pezzi dell'arena, com'era fino al
## 04/10/2026 (`Arena._luce_per_vertice`): dice quanto vale ancora quella scelta. Nel
## banco di quel giorno, alla seconda velocità del telefono, la luce per vertice ha
## portato il fotogramma da 46 a 11 ms.
const VOCI := ["bagliore", "antialias", "lampade", "pixel", "animazioni", "pieno", "corpi",
		"contorni", "pubblico", "superfici", "interfaccia", "risoluzione", "vuota"]
## Quanto si scalda, in secondi, prima delle coppie.
const RISCALDA := 90.0
## Fotogrammi dopo ogni cambio, prima di misurare: il primo fotogramma di una voce
## nuova può compilare uno shader.
const ASSESTA := 20
## Fotogrammi contati per i fotogrammi al secondo.
const CONTA := 40
## Fotogrammi pesati uno per uno, aspettando la scheda video.
const PESA := 40
## Fotogrammi dopo aver riacceso, prima della misura seguente.
const RIPOSA := 10
## Dove si ferma chi gioca: sul ballatoio, che guarda il cuore dell'arena.
const DOVE_GIOCATORE := Vector3(0.0, 7.05, 24.25)
## Dove si fermano gli avversari: due sul ballatoio, dentro i quindici metri del
## contorno; tre nel catino e nell'ala ocra, lontani. Posti cresciuti con l'arena
## (× 80/66, 06/10/2026).
const POSTI := [Vector3(-6.05, 7.0, 20.0), Vector3(6.05, 7.0, 20.6), Vector3(-4.85, -2.0, 0.0),
		Vector3(4.85, -2.0, -3.65), Vector3(0.0, 0.0, -23.0)]

## La pesa, in JavaScript. Prima di ogni fotogramma si aspetta che la scheda abbia
## finito il precedente; alla fine si aspetta che abbia finito questo. Si aspetta
## chiedendo un pixel dello schermo: il browser non può rispondere prima.
const PESA_JS := """
	(function () {
		if (window.__pw_banco) return;
		var B = window.__pw_banco = { sincro: false, t0: 0, costi: [] };
		var tela = document.getElementById('canvas');
		var gl = tela && tela.getContext('webgl2');
		var pixel = new Uint8Array(4);
		B.aspetta = function () {
			if (!gl) return;
			var letto = gl.getParameter(gl.READ_FRAMEBUFFER_BINDING);
			var pacco = gl.getParameter(gl.PIXEL_PACK_BUFFER_BINDING);
			if (pacco) gl.bindBuffer(gl.PIXEL_PACK_BUFFER, null);
			gl.bindFramebuffer(gl.READ_FRAMEBUFFER, null);
			gl.readPixels(0, 0, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, pixel);
			gl.bindFramebuffer(gl.READ_FRAMEBUFFER, letto);
			if (pacco) gl.bindBuffer(gl.PIXEL_PACK_BUFFER, pacco);
		};
		var raf = window.requestAnimationFrame.bind(window);
		window.requestAnimationFrame = function (cb) {
			return raf(function (ts) {
				if (B.sincro) B.aspetta();
				B.t0 = performance.now();
				cb(ts);
			});
		};
		B.fine = function () {
			if (!B.sincro) return;
			var lavoro = performance.now() - B.t0;
			B.aspetta();
			B.costi.push(lavoro.toFixed(2) + ':' + (performance.now() - B.t0).toFixed(2));
		};
		B.leggi = function () { var c = B.costi; B.costi = []; return c.join(','); };
	})();
"""

var arena: Node
var sonda: Sonda
## Le voci di questo giro: tutte, o quelle scritte nell'indirizzo.
var voci: Array = VOCI
## I secondi di riscaldamento di questo giro: `RISCALDA`, o `caldo=` nell'indirizzo.
var riscaldamento := RISCALDA
var _pesando := false
var _scritta: Label
## Com'era ogni cosa spenta, per rimetterla esattamente com'era.
var _salvati := {}
var _piatti := {}
var _pixel := {}


func _ready() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	if OS.has_feature("web"):
		JavaScriptBridge.eval(PESA_JS)
		var caldo: Variant = JavaScriptBridge.eval(
				"String(new URLSearchParams(window.location.search).get('caldo') || '')", true)
		if caldo is String and (caldo as String).is_valid_float():
			riscaldamento = maxf(float(caldo), 0.0)
	RenderingServer.frame_post_draw.connect(_dopo_il_disegno)
	_cartello()
	_lavora()


func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(_dopo_il_disegno):
		RenderingServer.frame_post_draw.disconnect(_dopo_il_disegno)


func _dopo_il_disegno() -> void:
	if _pesando and OS.has_feature("web"):
		JavaScriptBridge.eval("window.__pw_banco.fine()")


func _lavora() -> void:
	_scrivi("MISURO LA SCHEDA VIDEO · ASPETTO IL VIA")
	while float(arena.call("conto_alla_rovescia")) > 0.0 \
			or (arena.call("avversari") as Array).size() < Arena.NOMI.size():
		await get_tree().process_frame
	# Da qui le righe sono del banco: quelle della partita si chiudono.
	if sonda != null:
		sonda.fermati("banco")
	_metti_in_posa()
	await _fotogrammi(90)
	var n := 0
	var inizio := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - inizio) / 1000.0 < riscaldamento:
		_scrivi("MISURO LA SCHEDA VIDEO · SCALDO · NON TOCCARE")
		n += 1
		await _misura(n, "caldo")
	for i in voci.size():
		_scrivi("MISURO LA SCHEDA VIDEO · %d DI %d · NON TOCCARE" % [i + 1, voci.size()])
		n += 1
		await _misura(n, "base")
		n += 1
		await _misura(n, voci[i])
	# L'ultima riga lo dice, così chi la legge sa che il giro è finito.
	n += 1
	await _misura(n, "base", true)
	_scrivi("FATTO · PUOI CHIUDERE")


## Una misura: si spegne la voce («base» e «caldo» non spengono niente), si aspetta
## che si assesti, si conta, si pesa, si manda la riga e si riaccende.
func _misura(n: int, voce: String, ultima := false) -> void:
	_spegni(voce)
	await _fotogrammi(ASSESTA)
	var conto: Array = await _conta()
	var pesata: Array = await _pesa()
	_manda(n, voce, conto, pesata[0], pesata[1], ultima)
	_riaccendi(voce)
	await _fotogrammi(RIPOSA)


## Tutti fermi, sempre nello stesso posto: le voci si confrontano solo se
## l'inquadratura è la stessa. Gli avversari smettono di pensare e di camminare, ma
## la loro animazione continua e il contorno resta vivo.
func _metti_in_posa() -> void:
	var giocatore: Giocatore = arena.call("giocatore")
	giocatore.global_position = DOVE_GIOCATORE
	giocatore.velocity = Vector3.ZERO
	giocatore.punta(0.0, -12.0)
	var bots: Array = arena.call("avversari")
	for i in bots.size():
		var bot := bots[i] as Avversario
		bot.set_physics_process(false)
		bot.velocity = Vector3.ZERO
		bot.global_position = POSTI[i % POSTI.size()]
		bot.rotation.y = PI


func _spegni(voce: String) -> void:
	var vp := get_viewport()
	match voce:
		"bagliore":
			_ambiente().glow_enabled = false
		"antialias":
			_salvati["msaa"] = vp.msaa_3d
			vp.msaa_3d = Viewport.MSAA_DISABLED
		"lampade":
			for luce in arena.find_children("*", "OmniLight3D", true, false):
				if (luce as Node3D).visible:
					_salvati[luce] = true
					(luce as Node3D).visible = false
		"animazioni":
			for corpo in _corpi():
				(corpo.get("_albero") as AnimationTree).active = false
				(corpo.get("_torsione") as SkeletonModifier3D).active = false
		"pieno":
			Corpo.ritmo_pieno = true
		"corpi":
			for bot in arena.call("avversari"):
				(bot as Node3D).visible = false
			(arena.call("giocatore") as Giocatore).corpo().visible = false
		"contorni":
			for bot in arena.call("avversari"):
				# Il contorno si riaccende a ogni fotogramma: per spegnerlo si ferma chi
				# lo riaccende.
				(bot as Node).set_process(false)
				((bot as Node).get("_corpo") as Corpo).accendi_contorni(false)
		"pubblico":
			var pubblico := arena.get_node_or_null("pubblico") as Node3D
			if pubblico != null:
				pubblico.visible = false
		"superfici":
			# Le superfici vere (texture, rilievo, proiezione dal mondo) diventano tinte
			# piatte dello stesso colore, con uno shader già compilato.
			var vere: Array = Vestizione._pronti.values()
			for nodo in arena.find_children("*", "MeshInstance3D", true, false):
				var pezzo := nodo as MeshInstance3D
				if pezzo.material_override != null and vere.has(pezzo.material_override):
					_salvati[pezzo] = pezzo.material_override
					pezzo.material_override = _piatto(pezzo.material_override as StandardMaterial3D)
		"pixel":
			for nodo in arena.find_children("*", "MeshInstance3D", true, false):
				var pezzo := nodo as MeshInstance3D
				var materiale := pezzo.material_override as BaseMaterial3D
				if materiale == null or materiale.shading_mode != BaseMaterial3D.SHADING_MODE_PER_VERTEX:
					continue
				_salvati[pezzo] = materiale
				pezzo.material_override = _per_pixel(materiale)
		"interfaccia":
			(arena.get("_comandi") as CanvasLayer).visible = false
		"risoluzione":
			_salvati["modo"] = vp.scaling_3d_mode
			_salvati["scala"] = vp.scaling_3d_scale
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = Resa.SCALA_MINIMA
		"vuota":
			var camera := vp.get_camera_3d()
			_salvati["maschera"] = camera.cull_mask
			camera.cull_mask = 0


func _riaccendi(voce: String) -> void:
	var vp := get_viewport()
	match voce:
		"bagliore":
			_ambiente().glow_enabled = true
		"antialias":
			vp.msaa_3d = _salvati["msaa"]
		"lampade":
			for luce in _salvati:
				if luce is OmniLight3D:
					(luce as Node3D).visible = true
		"animazioni":
			for corpo in _corpi():
				(corpo.get("_albero") as AnimationTree).active = true
				(corpo.get("_torsione") as SkeletonModifier3D).active = true
		"pieno":
			Corpo.ritmo_pieno = false
		"corpi":
			for bot in arena.call("avversari"):
				(bot as Node3D).visible = true
			(arena.call("giocatore") as Giocatore).corpo().visible = true
		"contorni":
			for bot in arena.call("avversari"):
				(bot as Node).set_process(true)
		"pubblico":
			var pubblico := arena.get_node_or_null("pubblico") as Node3D
			if pubblico != null:
				pubblico.visible = true
		"superfici", "pixel":
			for pezzo in _salvati:
				if pezzo is MeshInstance3D:
					(pezzo as MeshInstance3D).material_override = _salvati[pezzo]
		"interfaccia":
			(arena.get("_comandi") as CanvasLayer).visible = true
		"risoluzione":
			vp.scaling_3d_mode = _salvati["modo"]
			vp.scaling_3d_scale = _salvati["scala"]
		"vuota":
			vp.get_camera_3d().cull_mask = _salvati["maschera"]
	_salvati.clear()


## I sei corpi: il tuo e quelli degli avversari.
func _corpi() -> Array[Corpo]:
	var tutti: Array[Corpo] = [(arena.call("giocatore") as Giocatore).corpo()]
	for bot in arena.call("avversari"):
		var corpo := (bot as Node).get("_corpo") as Corpo
		if corpo != null:
			tutti.append(corpo)
	return tutti


func _ambiente() -> Environment:
	for figlio in arena.get_children():
		if figlio is WorldEnvironment:
			return (figlio as WorldEnvironment).environment
	return Environment.new()


func _piatto(vero: StandardMaterial3D) -> StandardMaterial3D:
	if not _piatti.has(vero):
		var piatto := Muratura.tinta_unita(vero.albedo_color, 0.8)
		# Con la luce del vero: la voce misura le texture, non la luce.
		piatto.shading_mode = vero.shading_mode
		_piatti[vero] = piatto
	return _piatti[vero]


## Lo stesso materiale, con la luce calcolata su ogni pixel.
func _per_pixel(vero: BaseMaterial3D) -> BaseMaterial3D:
	if not _pixel.has(vero):
		var copia := vero.duplicate() as BaseMaterial3D
		copia.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_pixel[vero] = copia
	return _pixel[vero]


## I fotogrammi al secondo come li vede chi gioca, le chiamate di disegno e, dove il
## motore lo sa (sul PC, non nel browser), il tempo della scheda.
func _conta() -> Array:
	var vp := get_viewport().get_viewport_rid()
	var chiamate := 0
	var gpu := 0.0
	var inizio := Time.get_ticks_usec()
	for i in CONTA:
		await get_tree().process_frame
		chiamate += RenderingServer.viewport_get_render_info(vp,
				RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
				RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	var secondi := float(Time.get_ticks_usec() - inizio) / 1000000.0
	return [float(CONTA) / secondi, float(chiamate) / CONTA, gpu / CONTA]


## Il costo vero di ogni fotogramma, aspettando la scheda, e quanto di quel costo
## è lavoro del gioco. Solo nel browser. Torna `[lavori, costi]`.
func _pesa() -> Array:
	var lavori := PackedFloat64Array()
	var costi := PackedFloat64Array()
	if not OS.has_feature("web"):
		return [lavori, costi]
	JavaScriptBridge.eval("window.__pw_banco.costi = []; window.__pw_banco.sincro = true;")
	_pesando = true
	await _fotogrammi(PESA)
	_pesando = false
	JavaScriptBridge.eval("window.__pw_banco.sincro = false;")
	var letti: Variant = JavaScriptBridge.eval("window.__pw_banco.leggi()", true)
	if letti is String:
		for coppia in String(letti).split(",", false):
			var due := coppia.split(":")
			lavori.append(float(due[0]))
			costi.append(float(due[1]))
	# I primi due stanno a cavallo dell'accensione: il primo fotogramma non aveva
	# aspettato la scheda prima di cominciare.
	return [lavori.slice(2), costi.slice(2)]


func _manda(n: int, voce: String, conto: Array, lavori: PackedFloat64Array,
		costi: PackedFloat64Array, ultima := false) -> void:
	var ordinati := costi.duplicate()
	ordinati.sort()
	var massimo := ordinati[ordinati.size() - 1] if not ordinati.is_empty() else -1.0
	var vp := get_viewport()
	var testo := ("scena=banco&voce=%s&n=%d&fps=%.1f&costo=%.1f&lavoro=%.1f&costo_max=%.1f"
			+ "&pesati=%d&chiamate=%d&gpu=%.1f&scala=%.2f&msaa=%d") % [
		voce, n, float(conto[0]), _mediano(costi), _mediano(lavori), massimo, ordinati.size(),
		int(round(float(conto[1]))), float(conto[2]), vp.scaling_3d_scale, vp.msaa_3d]
	if ultima:
		testo += "&ultima=1"
	if sonda != null:
		sonda.manda(testo)
	else:
		print("banco: ", testo)


static func _mediano(valori: PackedFloat64Array) -> float:
	if valori.is_empty():
		return -1.0
	var ordinati := valori.duplicate()
	ordinati.sort()
	return ordinati[ordinati.size() / 2]


func _fotogrammi(quanti: int) -> void:
	for i in quanti:
		await get_tree().process_frame


func _cartello() -> void:
	var strato := CanvasLayer.new()
	strato.layer = 50
	add_child(strato)
	_scritta = Label.new()
	_scritta.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_scritta.offset_top = 64.0
	_scritta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scritta.add_theme_font_size_override("font_size", 20)
	_scritta.add_theme_color_override("font_color", Color.WHITE)
	_scritta.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_scritta.add_theme_constant_override("outline_size", 8)
	strato.add_child(_scritta)


func _scrivi(testo: String) -> void:
	if _scritta != null:
		_scritta.text = testo
