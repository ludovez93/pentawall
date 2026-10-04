class_name Gradino
extends RefCounted

## **Il gradino che si sale da solo** (tappa 10, blocco A).
##
## Un corpo è una capsula che scivola, e da sola una capsula di 42 cm di raggio con
## 45° di pendenza massima supera solo i dislivelli sotto i 12 cm. Il fianco di una
## rampa a mezzo metro dal piede, 27 cm, la fermava, e dal telefono si andava avanti
## solo saltando (*«mi bloccavo, dovevo saltare per andare avanti»*, 04/10/2026).
## Nel 1999 si saliva da soli fino a 25 unità, cioè 48 cm (`Pawn.MaxStepHeight`,
## letto nel sorgente): quel numero si tiene, perché è quello che fa sembrare normale
## correre in un'arena piena di dislivelli.
##
## Come: prima di muoversi si prova il passo. Se urta qualcosa di ripido, si prova lo
## stesso passo 48 cm più in alto e da lì si riscende fino al pavimento; se il
## pavimento c'è, il corpo sale di quanto serve e il passo lo fa `move_and_slide` come
## sempre. Sopra i 48 cm il passo alto urta ancora: è un muro, e resta un muro.
## Lo usano il giocatore e gli avversari, che sono lo stesso corpo.

const ALTEZZA := 0.48

## Quanto avanti si prova il passo alto, almeno. Un fotogramma di corsa sono 13 cm, e
## da lì la capsula riscenderebbe sullo spigolo del gradino con la normale a 40-45°,
## al limite di quello che vale come pavimento. Trenta centimetri la portano sopra.
const AVANTI := 0.3

## Quanto in fretta la vista raggiunge il corpo che è salito: 48 cm in un decimo di
## secondo. Il corpo sale in un fotogramma, gli occhi no — anche il 1999 ammorbidiva
## la vista sul gradino (`PlayerPawn.uc`).
const VISTA := 4.8


## Da chiamare subito prima di `move_and_slide()`, con la velocità già decisa.
## Torna quanto è salito il corpo, zero se niente: serve a chi ammorbidisce la vista.
static func sali(corpo: CharacterBody3D, delta: float) -> float:
	if not corpo.is_on_floor():
		return 0.0
	var passo := Vector3(corpo.velocity.x, 0.0, corpo.velocity.z) * delta
	if passo.length_squared() < 0.000001:
		return 0.0
	var da := corpo.global_transform
	var urto := KinematicCollision3D.new()
	if not corpo.test_move(da, passo, urto):
		return 0.0
	# Una pendenza che regge il peso la sale già `move_and_slide`.
	var pavimento := cos(corpo.floor_max_angle)
	if urto.get_normal().y >= pavimento:
		return 0.0
	var su := Vector3.UP * ALTEZZA
	if corpo.test_move(da, su):
		return 0.0
	var alto := da.translated(su)
	var avanti := passo.normalized() * maxf(passo.length(), AVANTI)
	if corpo.test_move(alto, avanti):
		return 0.0
	alto = alto.translated(avanti)
	var giu := KinematicCollision3D.new()
	if not corpo.test_move(alto, Vector3.DOWN * (ALTEZZA + 0.05), giu):
		return 0.0
	if giu.get_normal().y < pavimento:
		return 0.0
	# Quanto è alto il gradino si legge dal punto toccato, non dalla discesa: la capsula
	# ha il fondo tondo, e sullo spigolo si appoggia qualche centimetro più in basso del
	# gradino. Contando la discesa, uno da 50 cm risultava da 47 e passava (collaudo
	# del 04/10/2026, `tools/prova_gradini.gd`).
	if giu.get_position().y - da.origin.y > ALTEZZA:
		return 0.0
	var salita := ALTEZZA - giu.get_travel().length()
	if salita < 0.02:
		return 0.0
	corpo.global_position.y += salita
	return salita
