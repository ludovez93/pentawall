class_name Sonda
extends Node

## La sonda dei fotogrammi: porta a casa il numero che sta sul telefono.
##
## Il contatore in alto a sinistra lo vede solo chi gioca, e chiedere di leggerlo
## a metà partita è un giro di messaggi per un numero. Qui il gioco lo manda da
## solo: **ogni dieci secondi di partita** una richiesta al Server 2, con i numeri
## nella query string. Là Caddy risponde 204 e scrive la riga nel suo log
## (`/var/log/caddy/sonda.log`), e da lì si legge via SSH.
##
## Si misura la **coda**, non solo la media (LEARNED.md § 25): il fotogramma
## peggiore e quanti hanno sfondato i venti millesimi. Il tempo lo prende
## dall'orologio, non dal `delta`: il motore lo liscia, e liscerebbe anche lo
## scatto che si vuole vedere.
##
## Fuori dalla pagina web (PC, collaudi) la riga si stampa e basta.

const INDIRIZZO := "https://sonda.92-4-172-126.sslip.io/pentawall"
const OGNI := 10.0            ## secondi fra una spedizione e l'altra
const SOGLIA_LENTO_MS := 20.0 ## sopra, un fotogramma è «lento»
const MINIMO_FINALE := 2.0    ## sotto, la coda di una partita non vale una riga

## Chi dice quanti avversari ci sono in campo: la scena che ci ospita.
var arena: Node = null
## Come si chiama la scena nella riga: «arena» (la partita a sei) o «poligono».
var scena := "arena"

## Quanto si aspetta, all'apertura, prima di mandare la riga di saluto: il tempo
## che la pagina legga `versione.txt`, così il saluto dice quale versione gira.
const ATTESA_SALUTO := 2.0

## Sopra i 40 ms un fotogramma è uno **scatto**: a 30 al secondo ogni fotogramma
## supera i venti, e la soglia dei venti non distingue più niente.
const SOGLIA_SCATTO_MS := 40.0
## Quanto dura la misura a riposo dopo il saluto: la scena appena aperta, senza
## partita. Serve a dire se il telefono **può** andare sopra i 30, prima di
## toccare qualsiasi cosa: un tetto e un affanno si curano in modi opposti.
const RIPOSO := 5.0

var _in_partita := false
var _riposo := false
var _dal_via := 0.0
var _finestra := 0.0
var _fotogrammi := 0
var _peggiore_ms := 0.0
var _lenti := 0
var _scatti := 0
var _cpu_somma := 0.0
var _cpu_max := 0.0
## Il contesto del fotogramma peggiore della finestra: quanto ci ha messo il
## calcolo, a che velocità andava il giocatore, quanti dardi c'erano in volo.
var _peggiore_cpu := 0.0
var _peggiore_velocita := 0.0
var _peggiore_dardi := 0
var _spedite := 0
var _ultimo_usec := 0
var _versione := "?"
var _schermo := ""

## **Dove va il tempo** (tappa 9, 03/10/2026). Il 03/10 il telefono andava a 30 e
## da qui non si poteva dire se per il calcolo o per la scheda video: due mali che
## si curano in modi opposti. Adesso ogni riga porta le voci separate, in
## millesimi per fotogramma: il calcolo degli script e delle animazioni (misurato
## fra la sonda, che gira per prima, e la `Coda`, che gira per ultima), la fisica,
## e il lavoro della CPU per preparare il disegno; più quante chiamate di disegno.
## Quello che manca al tempo del fotogramma è la scheda video, o l'attesa dello
## schermo.
var _inizio_calcolo := 0
var _fine_calcolo := 0
var _inizio_fisica := 0
var _fine_fisica := 0
var _calcolo_somma := 0.0
var _fisica_somma := 0.0
var _fisica_giri := 0
var _disegno_somma := 0.0
var _gpu_somma := 0.0
var _chiamate_somma := 0


## L'ultimo a girare, a ogni fotogramma e a ogni passo di fisica: segna quando il
## calcolo è finito.
class Coda extends Node:
	var sonda: Sonda

	func _ready() -> void:
		process_priority = 1000000
		process_physics_priority = 1000000

	func _process(_delta: float) -> void:
		sonda._fine_calcolo = Time.get_ticks_usec()

	func _physics_process(_delta: float) -> void:
		sonda._fine_fisica = Time.get_ticks_usec()


func _ready() -> void:
	# La sonda gira **per prima**: segna l'inizio del calcolo; la coda la fine.
	process_priority = -1000000
	process_physics_priority = -1000000
	var coda := Coda.new()
	coda.sonda = self
	add_child(coda)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	if OS.has_feature("web"):
		# La versione la conosce solo la pagina: `versione.txt` lo scrive la
		# lavorazione accanto al gioco. Si legge una volta, in sottofondo.
		JavaScriptBridge.eval("""
			window.__pw_v = window.__pw_v || '?';
			fetch('versione.txt', {cache: 'no-cache'})
				.then(function (r) { return r.text(); })
				.then(function (t) { window.__pw_v = t.trim().slice(0, 7); })
				.catch(function () {});
		""")
		var letto: Variant = JavaScriptBridge.eval("""
			[window.innerWidth, window.innerHeight, window.devicePixelRatio,
			 (navigator.standalone || matchMedia('(display-mode: fullscreen)').matches) ? 1 : 0
			].join('|')
		""", true)
		if letto is String:
			var pezzi: PackedStringArray = String(letto).split("|")
			if pezzi.size() == 4:
				_schermo = "schermo=%sx%s&dpr=%s&app=%s" % [pezzi[0], pezzi[1], pezzi[2], pezzi[3]]
	if _schermo == "":
		var misura := DisplayServer.window_get_size()
		_schermo = "schermo=%dx%d&dpr=1&app=0" % [misura.x, misura.y]
	# Il saluto: «questa scena si è aperta, con questa versione, su questo
	# schermo». Serve a distinguere «non ha giocato qui» da «la spedizione non
	# parte»: la prima partita dal telefono (12/09/2026) non ha lasciato traccia
	# e da qui non si capiva quale delle due fosse.
	get_tree().create_timer(ATTESA_SALUTO).timeout.connect(func() -> void:
		if not is_inside_tree() or _in_partita:
			return
		_spedisci("apertura")
		# Poi cinque secondi a riposo, così com'è la scena appena aperta.
		parti()
		_riposo = true
		get_tree().create_timer(RIPOSO).timeout.connect(func() -> void:
			if is_inside_tree() and _riposo:
				fermati("riposo")))


## La partita è cominciata: da qui si conta.
func parti() -> void:
	_in_partita = true
	_riposo = false
	_dal_via = 0.0
	_spedite = 0
	_azzera()
	_ultimo_usec = Time.get_ticks_usec()


## La partita è finita (chiusa col pulsante, o vinta): l'ultima riga parte
## subito, con il motivo, se c'è abbastanza dentro da dire qualcosa.
func fermati(motivo: String) -> void:
	if not _in_partita:
		return
	_in_partita = false
	_riposo = false
	if _finestra >= MINIMO_FINALE:
		_spedisci(motivo)


func _physics_process(_delta: float) -> void:
	var adesso := Time.get_ticks_usec()
	if _in_partita and _fine_fisica > _inizio_fisica and _inizio_fisica > 0:
		_fisica_somma += float(_fine_fisica - _inizio_fisica) / 1000.0
		_fisica_giri += 1
	_inizio_fisica = adesso


func _process(_delta: float) -> void:
	var adesso_calcolo := Time.get_ticks_usec()
	var calcolo_ms := 0.0
	if _fine_calcolo > _inizio_calcolo and _inizio_calcolo > 0:
		calcolo_ms = float(_fine_calcolo - _inizio_calcolo) / 1000.0
	_inizio_calcolo = adesso_calcolo
	if not _in_partita:
		return
	var vp := get_viewport().get_viewport_rid()
	_calcolo_somma += calcolo_ms
	_disegno_somma += RenderingServer.viewport_get_measured_render_time_cpu(vp) \
			+ RenderingServer.get_frame_setup_time_cpu()
	_gpu_somma += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	_chiamate_somma += RenderingServer.viewport_get_render_info(vp,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var adesso := Time.get_ticks_usec()
	var ms := float(adesso - _ultimo_usec) / 1000.0
	_ultimo_usec = adesso
	# Il calcolo del fotogramma appena passato: quello che il motore sa di sé.
	# Il resto — fino al tempo di parete — è disegno, browser e attesa dello
	# schermo. È la separazione delle voci di LEARNED.md § 20.
	var cpu := (Performance.get_monitor(Performance.TIME_PROCESS)
			+ Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	_fotogrammi += 1
	_finestra += ms / 1000.0
	_dal_via += ms / 1000.0
	_cpu_somma += cpu
	_cpu_max = maxf(_cpu_max, cpu)
	if ms > _peggiore_ms:
		_peggiore_ms = ms
		_peggiore_cpu = cpu
		_peggiore_velocita = _velocita_del_giocatore()
		_peggiore_dardi = get_tree().get_nodes_in_group(Proiettile.GRUPPO).size()
	if ms > SOGLIA_LENTO_MS:
		_lenti += 1
	if ms > SOGLIA_SCATTO_MS:
		_scatti += 1
	if _finestra >= OGNI:
		_spedisci("")


func _velocita_del_giocatore() -> float:
	if arena == null or not arena.has_method("giocatore"):
		return 0.0
	var chi: Variant = arena.call("giocatore")
	if chi is CharacterBody3D:
		var v: Vector3 = (chi as CharacterBody3D).velocity
		return Vector2(v.x, v.z).length()
	return 0.0


## La riga, così com'è in questo momento. Pubblica perché il collaudo la legge.
func riga(motivo := "") -> String:
	var fps := float(_fotogrammi) / _finestra if _finestra > 0.0 else 0.0
	var avversari := 0
	if arena != null and arena.has_method("avversari"):
		avversari = (arena.call("avversari") as Array).size()
	elif arena != null and arena.has_method("avversario"):
		avversari = 1 if arena.call("avversario") != null else 0
	var dardi := get_tree().get_nodes_in_group(Proiettile.GRUPPO).size() if is_inside_tree() else 0
	var cpu := _cpu_somma / float(_fotogrammi) if _fotogrammi > 0 else 0.0
	var scala := Resa.scala(get_viewport()) if is_inside_tree() else 1.0
	var mem := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var testo := ("v=%s&scena=%s&n=%d&t=%d&fps=%.1f&peggiore=%d&lenti=%d&scatti=%d"
			+ "&cpu=%.1f&cpumax=%d&pegg_cpu=%d&pegg_vel=%.1f&pegg_dardi=%d"
			+ "&avv=%d&dardi=%d&scala=%.2f&mem=%d&%s") % [
		_versione.uri_encode(), scena, _spedite + 1, int(round(_dal_via)), fps,
		int(round(_peggiore_ms)), _lenti, _scatti,
		cpu, int(round(_cpu_max)), int(round(_peggiore_cpu)), _peggiore_velocita, _peggiore_dardi,
		avversari, dardi, scala, int(round(mem)), _schermo]
	var n := float(maxi(_fotogrammi, 1))
	testo += "&calcolo=%.1f&fisica=%.1f&disegno=%.1f&gpu=%.1f&chiamate=%d" % [
		_calcolo_somma / n, _fisica_somma / float(maxi(_fisica_giri, 1)),
		_disegno_somma / n, _gpu_somma / n, int(round(float(_chiamate_somma) / n))]
	if motivo == "apertura" or _spedite == 0:
		# Come si chiama la scheda video per il motore: da questo nome Godot decide se
		# fare la passata di profondità (la spegne solo se dice «Apple»). Nella prima
		# riga di ogni partita: entrando da GIOCA il saluto non parte.
		testo += "&scheda=" + RenderingServer.get_video_adapter_name().uri_encode()
	if motivo != "":
		testo += "&fine=" + motivo.uri_encode()
	return testo


func _spedisci(motivo: String) -> void:
	if OS.has_feature("web"):
		var letta: Variant = JavaScriptBridge.eval("String(window.__pw_v || '?')", true)
		if letta is String:
			_versione = String(letta)
	var testo := riga(motivo)
	_spedite += 1
	if OS.has_feature("web"):
		# `no-cors`: la risposta non ci interessa, conta che la richiesta arrivi.
		# `keepalive`: parte anche se la pagina sta per chiudersi.
		# La richiesta più semplice che un browser sappia fare: un'immagine. Niente
		# CORS, niente `keepalive`, niente operaio di servizio in mezzo (quello
		# nostro lascia passare gli altri domini, ma la strada corta non dipende
		# da nessuno). Se anche `Image` mancasse, si ripiega su `fetch`.
		var indirizzo := JSON.stringify("%s?%s" % [INDIRIZZO, testo])
		JavaScriptBridge.eval("""
			(function (u) {
				try { var i = new Image(); i.src = u; return; } catch (e) {}
				try { fetch(u, {mode: 'no-cors'}).catch(function () {}); } catch (e) {}
			})(%s);
		""" % indirizzo)
	else:
		print("sonda: ", testo)
	_azzera()


func _azzera() -> void:
	_calcolo_somma = 0.0
	_fisica_somma = 0.0
	_fisica_giri = 0
	_disegno_somma = 0.0
	_gpu_somma = 0.0
	_chiamate_somma = 0
	_finestra = 0.0
	_fotogrammi = 0
	_peggiore_ms = 0.0
	_lenti = 0
	_scatti = 0
	_cpu_somma = 0.0
	_cpu_max = 0.0
	_peggiore_cpu = 0.0
	_peggiore_velocita = 0.0
	_peggiore_dardi = 0
