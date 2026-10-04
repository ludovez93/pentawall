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
## un gradino, fino a metà.
##
## **Si giudica in fondo alla discesa, non a ogni gradino** (04/10/2026). Sul
## telefono i fotogrammi vanno a scalini, 60 o 30, perché lo schermo aspetta il suo
## turno: un gradino che toglie tre millesimi su venti lascia i fotogrammi a 30.
## Fino al 04/10 ogni gradino doveva rendere il 12%, e nella partita di quel giorno
## la discesa si è fermata a 0,65 senza mai provare i gradini sotto. Adesso si
## scende finché si torna sopra i 50 o si arriva a metà; e se a metà i fotogrammi non
## sono saliti almeno del 12%, il limite non è la scheda video ma il calcolo: una
## scena sfocata non serve a niente, si torna dov'era e non si tocca più.
##
## **Si parte da 0,65, non più da tre quarti** (04/10/2026, sera). Nella partita del
## pomeriggio la discesa è arrivata a metà, ha confrontato i fotogrammi con quelli di
## un momento in cui la scena era più leggera, ed è tornata a tre quarti: 21-27
## fotogrammi nei tratti pesanti, contro i 28-33 del mattino a 0,65 — un terzo di
## pixel in più, un quarto di tempo in più. Il telefono aspetta la scheda (`lavoro=`
## 3-11 ms su 37-47), quindi i pixel contano. Partendo da 0,65 il caso peggiore è il
## mattino. La regola giusta guarderà il lavoro, non i fotogrammi di due momenti
## diversi (`PLAN.md`, tappa 9, terza parte).

const SCALA_TELEFONO := 0.65
const SCALA_MINIMA := 0.5
const GRADINO := 0.1
## Sotto questi fotogrammi al secondo si prova a scendere.
const SOGLIA := 50.0
## Di quanto deve salire, in fondo alla discesa, perché la discesa resti.
const GUADAGNO := 1.12
const GIRO := 2.0
## I primi secondi della partita non contano: entrano i corpi, parte il fischio.
const ATTESA := 3.0

var _attesa := ATTESA
var _tempo := 0.0
var _fotogrammi := 0
var _prova_da := -1.0        ## i fotogrammi al secondo prima della discesa
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
	if al_secondo >= SOGLIA:
		# Sopra la soglia: se si stava scendendo, il gradino giusto è questo.
		if _prova_da > 0.0:
			_ferma = true
		return
	if _prova_da < 0.0:
		_prova_da = al_secondo
		_scala_prima = adesso
	if adesso > SCALA_MINIMA + 0.001:
		viewport.scaling_3d_scale = maxf(adesso - GRADINO, SCALA_MINIMA)
		return
	# A metà, e ancora sotto: se la discesa non ha reso, il limite è altrove. Si
	# torna dov'era e si smette.
	if al_secondo < _prova_da * GUADAGNO:
		viewport.scaling_3d_scale = _scala_prima
	_ferma = true


## Se ha smesso di adattarsi: serve al collaudo.
func ferma() -> bool:
	return _ferma
