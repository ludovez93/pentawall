class_name Resa
extends Node

## La resa 3D sul telefono (tappa 7, blocco 0; adattiva dalla tappa 9).
##
## L'iPhone dà al gioco 874 × 402 punti a **tre pixel per punto**: il disegno 3D
## esce a 2622 × 1206, tre milioni di pixel, con l'antialias a due campioni e il
## bagliore che è una passata a schermo intero. La prima partita misurata dal
## telefono (12/09/2026) è andata a 30 fotogrammi al secondo, mai uno sopra.
## Il primo rimedio del piano è questo: la scena si disegna a **tre quarti** e
## lo schermo la stira, l'interfaccia resta nitida perché non passa di qui.
## Solo sul telefono: sul PC la misura resta quella di sempre.
##
## **E si adatta** (tappa 9, 03/10/2026). Con i materiali veri della tappa 8 il
## telefono è tornato a 30: tre quarti non bastano più. In partita, ogni due
## secondi si guarda quanti fotogrammi sono passati; sotto i 50 la scena scende di
## un gradino, fino a metà. **Ogni gradino è una prova**: se nel giro dopo i
## fotogrammi non salgono, il limite non è la scheda video ma il calcolo, e
## scendere ancora sfocherebbe la scena per niente — si torna al gradino di prima
## e non si tocca più.

const SCALA_TELEFONO := 0.75
const SCALA_MINIMA := 0.5
const GRADINO := 0.1
## Sotto questi fotogrammi al secondo si prova a scendere.
const SOGLIA := 50.0
## Di quanto deve salire un giro dopo un gradino, perché il gradino resti.
const GUADAGNO := 1.12
const GIRO := 2.0
## I primi secondi della partita non contano: entrano i corpi, parte il fischio.
const ATTESA := 3.0

var _attesa := ATTESA
var _tempo := 0.0
var _fotogrammi := 0
var _prova_da := -1.0        ## i fotogrammi al secondo prima dell'ultimo gradino
var _scala_prima := SCALA_TELEFONO
var _ferma := false


static func regola(viewport: Viewport) -> void:
	if not Giocatore.a_pollice():
		return
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = SCALA_TELEFONO


## La scala in uso, per la riga della sonda.
static func scala(viewport: Viewport) -> float:
	return viewport.scaling_3d_scale


func _process(delta: float) -> void:
	if _ferma or not Giocatore.a_pollice():
		return
	if _attesa > 0.0:
		_attesa -= delta
		return
	_tempo += delta
	_fotogrammi += 1
	if _tempo < GIRO:
		return
	_decidi(float(_fotogrammi) / _tempo)
	_tempo = 0.0
	_fotogrammi = 0


## Una decisione per giro. Il collaudo la chiama direttamente, senza telefono.
func _decidi(al_secondo: float) -> void:
	var viewport := get_viewport()
	var adesso := viewport.scaling_3d_scale
	if _prova_da > 0.0:
		if al_secondo < _prova_da * GUADAGNO:
			# Il gradino non ha reso: il limite è altrove. Si torna su e si smette.
			viewport.scaling_3d_scale = _scala_prima
			_ferma = true
			return
		_prova_da = -1.0
	if al_secondo < SOGLIA and adesso > SCALA_MINIMA + 0.001:
		_prova_da = al_secondo
		_scala_prima = adesso
		viewport.scaling_3d_scale = maxf(adesso - GRADINO, SCALA_MINIMA)


## Se ha smesso di adattarsi: serve al collaudo.
func ferma() -> bool:
	return _ferma
