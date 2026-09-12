class_name Resa
extends RefCounted

## La resa 3D sul telefono (tappa 7, blocco 0).
##
## L'iPhone dà al gioco 874 × 402 punti a **tre pixel per punto**: il disegno 3D
## esce a 2622 × 1206, tre milioni di pixel, con l'antialias a due campioni e il
## bagliore che è una passata a schermo intero. La prima partita misurata dal
## telefono (12/09/2026) è andata a 30 fotogrammi al secondo, mai uno sopra.
## Il primo rimedio del piano è questo: la scena si disegna a **tre quarti** e
## lo schermo la stira, l'interfaccia resta nitida perché non passa di qui.
## Solo sul telefono: sul PC la misura resta quella di sempre.

const SCALA_TELEFONO := 0.75


static func regola(viewport: Viewport) -> void:
	if not Giocatore.a_pollice():
		return
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = SCALA_TELEFONO


## La scala in uso, per la riga della sonda.
static func scala(viewport: Viewport) -> float:
	return viewport.scaling_3d_scale
