class_name Resa
extends Node

## La resa 3D sul telefono (tappa 7, blocco 0; adattiva dalla tappa 9).
##
## L'iPhone dà al gioco 874 × 402 punti a **tre pixel per punto**: il disegno 3D
## esce a 2622 × 1206, tre milioni di pixel, con l'antialias a due campioni e il
## bagliore che è una passata a schermo intero. La prima partita misurata dal
## telefono (12/09/2026) è andata a 30 fotogrammi al secondo, mai uno sopra.
## Il primo rimedio del piano è questo: la scena si disegna più piccola e lo
## schermo la stira, l'interfaccia resta nitida perché non passa di qui.
## Solo sul telefono: sul PC la misura resta quella di sempre.
##
## **Si parte da 0,65** (04/10/2026): a tre quarti, con i materiali veri della
## tappa 8, il telefono faceva 21-27 fotogrammi nei tratti pesanti, a 0,65 28-33.
##
## **E si scende guardando il lavoro** (tappa 9, terza parte, 04/10/2026). Ogni due
## secondi si guarda il fotogramma: se sta sotto i 50 al secondo e il gioco ne ha
## lavorato meno di metà, il resto è attesa della scheda video, e meno pixel servono
## sempre: si scende di un gradino, fino a metà. Se invece il gioco lavora quasi
## tutto il fotogramma, il limite è il calcolo e una scena sfocata non serve: non si
## tocca niente. Non si risale mai: la scena che pesa torna appena ci si gira, e una
## risoluzione che va su e giù si vede.
## Le due regole di prima confrontavano i fotogrammi di due momenti diversi — prima
## e dopo la discesa — e nella partita del 04/10 hanno riportato la scena a tre
## quarti perché nel frattempo il giocatore guardava un posto più pesante
## (`LEARNED.md` § 53). Lavoro e fotogramma invece sono misurati nello stesso momento.

const SCALA_TELEFONO := 0.65
const SCALA_MINIMA := 0.5
const GRADINO := 0.1
## Sotto questi fotogrammi al secondo si guarda dov'è il limite.
const SOGLIA := 50.0
## Se il gioco lavora meno di questa parte del fotogramma, il resto è attesa della
## scheda video. Sul telefono il 04/10 era fra un decimo e un quarto (3-11 ms su
## 37-47); nel browser del PC, dove il limite è il calcolo, fra due terzi e nove
## decimi.
const QUOTA_LAVORO := 0.5
## Un fotogramma più lungo di così non è la scena che pesa: è la pagina ferma o un
## blocco. La finestra che lo contiene non si giudica.
const PAUSA_MS := 250.0
const GIRO := 2.0
## I primi secondi della partita non contano: entrano i corpi, parte il fischio.
const ATTESA := 3.0

var _attesa := ATTESA
var _ferma := false
var _ultimo := 0
var _tempo_ms := 0.0
var _fotogrammi := 0
var _peggiore_ms := 0.0
## Il lavoro, come nella sonda: dal primo script del fotogramma all'ultima chiamata
## di disegno.
var _inizio_giro := 0
var _giro_aperto := false
var _lavoro_ms := 0.0
var _lavori := 0


static func regola(viewport: Viewport) -> void:
	if not Giocatore.a_pollice():
		return
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = SCALA_TELEFONO


## La scala in uso, per la riga della sonda.
static func scala(viewport: Viewport) -> float:
	return viewport.scaling_3d_scale


func _ready() -> void:
	# Gira per primo, come la sonda: il lavoro si conta dal primo script.
	process_priority = -1000000
	process_physics_priority = -1000000
	RenderingServer.frame_post_draw.connect(_fine_del_giro)


func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(_fine_del_giro):
		RenderingServer.frame_post_draw.disconnect(_fine_del_giro)


func _apri_il_giro() -> void:
	if not _giro_aperto:
		_giro_aperto = true
		_inizio_giro = Time.get_ticks_usec()


func _fine_del_giro() -> void:
	if _giro_aperto:
		_lavoro_ms += float(Time.get_ticks_usec() - _inizio_giro) / 1000.0
		_lavori += 1
	_giro_aperto = false


func _physics_process(_delta: float) -> void:
	_apri_il_giro()


func _process(delta: float) -> void:
	_apri_il_giro()
	if _ferma or not Giocatore.a_pollice():
		return
	var adesso := Time.get_ticks_usec()
	var ms := float(adesso - _ultimo) / 1000.0
	_ultimo = adesso
	if _attesa > 0.0:
		_attesa -= delta
		_azzera()
		return
	_tempo_ms += ms
	_fotogrammi += 1
	_peggiore_ms = maxf(_peggiore_ms, ms)
	if _tempo_ms < GIRO * 1000.0:
		return
	_decidi(float(_fotogrammi) * 1000.0 / _tempo_ms, _lavoro_ms / float(maxi(_lavori, 1)),
			_peggiore_ms)
	_azzera()


## Una decisione per giro. Il collaudo la chiama direttamente, senza telefono.
func _decidi(al_secondo: float, lavoro_ms: float, peggiore_ms := 0.0) -> void:
	if peggiore_ms > PAUSA_MS or al_secondo >= SOGLIA:
		return
	if lavoro_ms >= 1000.0 / al_secondo * QUOTA_LAVORO:
		return
	var viewport := get_viewport()
	viewport.scaling_3d_scale = maxf(viewport.scaling_3d_scale - GRADINO, SCALA_MINIMA)
	_ferma = viewport.scaling_3d_scale <= SCALA_MINIMA + 0.001


## Se è arrivata in fondo: serve al collaudo.
func ferma() -> bool:
	return _ferma


func _azzera() -> void:
	_tempo_ms = 0.0
	_fotogrammi = 0
	_peggiore_ms = 0.0
	_lavoro_ms = 0.0
	_lavori = 0
