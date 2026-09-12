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

var _in_partita := false
var _dal_via := 0.0
var _finestra := 0.0
var _fotogrammi := 0
var _peggiore_ms := 0.0
var _lenti := 0
var _spedite := 0
var _ultimo_usec := 0
var _versione := "?"
var _schermo := ""


func _ready() -> void:
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
		if is_inside_tree() and not _in_partita:
			_spedisci("apertura"))


## La partita è cominciata: da qui si conta.
func parti() -> void:
	_in_partita = true
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
	if _finestra >= MINIMO_FINALE:
		_spedisci(motivo)


func _process(_delta: float) -> void:
	if not _in_partita:
		return
	var adesso := Time.get_ticks_usec()
	var ms := float(adesso - _ultimo_usec) / 1000.0
	_ultimo_usec = adesso
	_fotogrammi += 1
	_finestra += ms / 1000.0
	_dal_via += ms / 1000.0
	_peggiore_ms = maxf(_peggiore_ms, ms)
	if ms > SOGLIA_LENTO_MS:
		_lenti += 1
	if _finestra >= OGNI:
		_spedisci("")


## La riga, così com'è in questo momento. Pubblica perché il collaudo la legge.
func riga(motivo := "") -> String:
	var fps := float(_fotogrammi) / _finestra if _finestra > 0.0 else 0.0
	var avversari := 0
	if arena != null and arena.has_method("avversari"):
		avversari = (arena.call("avversari") as Array).size()
	elif arena != null and arena.has_method("avversario"):
		avversari = 1 if arena.call("avversario") != null else 0
	var dardi := get_tree().get_nodes_in_group(Proiettile.GRUPPO).size() if is_inside_tree() else 0
	var testo := "v=%s&scena=%s&n=%d&t=%d&fps=%.1f&peggiore=%d&lenti=%d&avv=%d&dardi=%d&%s" % [
		_versione.uri_encode(), scena, _spedite + 1, int(round(_dal_via)), fps,
		int(round(_peggiore_ms)), _lenti, avversari, dardi, _schermo]
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
	_finestra = 0.0
	_fotogrammi = 0
	_peggiore_ms = 0.0
	_lenti = 0
