extends SceneTree

## Collaudo dei gradini (tappa 10, blocco A).
##
## Dal telefono, il 04/10/2026: *«alcuni gradini o mini gradini si vedevano poco e mi
## bloccavo, dovevo saltare per andare avanti»*. Una capsula come il giocatore, fatta
## salire sulle nove rampe, si fermava sulla scala nord-est al bordo del catino (80 cm:
## i pavimenti a quota zero passavano sopra la rampa) e in cima alla rampa dell'ocra
## (31 cm), e nessun corpo saliva da solo oltre i 12 cm. Gli oltre 270 controlli di
## allora guardavano rimbalzi, punti e fotogrammi: nessuno camminava sulle rampe
## (`LEARNED.md` § 58). Qui si cammina.
##
## Uso:  godot --headless --path . -s tools/prova_gradini.gd

const RETE_IMPRONTA := "res://arene/palestra_cammino.json"

## I tre gradini della stanza di prova: due si salgono, il terzo è la controprova —
## due centimetri sopra il tetto, e deve restare un muro.
const GRADINI := [[0.30, true], [0.47, true], [0.50, false]]

## Quanto si aspetta chi corre verso un gradino, in secondi veri: a 7,62 m/s il
## gradino sta a mezzo secondo, e sopra ce n'è un altro abbondante.
const CORSA := 1.3

## Quanto si aspetta, al massimo, chi sale una rampa: la più lunga è la scala nord-est,
## 23 metri più il metro e mezzo prima del piede, cioè tre secondi e mezzo di corsa.
const PAZIENZA_RAMPA := 6.0

var _errori := 0
var _prove := 0


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	await _il_gradino_si_sale()
	await _nelle_rampe()
	_la_rete_non_chiede_troppo()
	_chiudi()


# ------------------------------------------------------------- la stanza di prova

## Tre corsie, un gradino per corsia. Il giocatore corre coi comandi finti, come col
## pollice; l'avversario è lo stesso corpo e usa la stessa funzione, spinto a mano.
func _il_gradino_si_sale() -> void:
	var stanza := Node3D.new()
	root.add_child(stanza)
	_scatola(stanza, Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	for i in GRADINI.size():
		var alto: float = GRADINI[i][0]
		_scatola(stanza, Vector3(_corsia(i), alto * 0.5, -10.0), Vector3(2.5, alto, 12.0))
	await physics_frame
	await physics_frame

	for i in GRADINI.size():
		var alto: float = GRADINI[i][0]
		var sale: bool = GRADINI[i][1]
		var g := Giocatore.new()
		stanza.add_child(g)
		g.global_position = Vector3(_corsia(i), 0.05, 0.0)
		g.comandi = _avanti()
		var salito := await _corri(g, func() -> void: pass)
		_conta("tu: un gradino di %d cm %s" % [roundi(alto * 100), "si sale" if sale else "resta un muro"],
				salito == sale, "a quota %.2f, z %.2f" % [g.global_position.y, g.global_position.z])
		if sale:
			# La vista raggiunge il corpo: un decimo di secondo, non di più.
			var partito := Time.get_ticks_msec()
			while Time.get_ticks_msec() - partito < 300:
				await process_frame
			var scalino: float = g.get("_scalino")
			_conta("tu: sul gradino da %d cm la vista ha raggiunto il corpo" % roundi(alto * 100),
					is_zero_approx(scalino), "mancano %.2f m" % scalino)
		g.queue_free()
		await physics_frame

	for i in GRADINI.size():
		var alto: float = GRADINI[i][0]
		var sale: bool = GRADINI[i][1]
		var bot := Avversario.crea(stanza, Vector3(_corsia(i), 0.05, 0.0), 1)
		bot.set_physics_process(false)
		var salito := await _corri(bot, func() -> void:
				bot.velocity.x = 0.0
				bot.velocity.z = -Giocatore.VELOCITA
				if not bot.is_on_floor():
					bot.velocity.y -= Giocatore.GRAVITA / float(Engine.physics_ticks_per_second)
				Gradino.sali(bot, 1.0 / float(Engine.physics_ticks_per_second))
				bot.move_and_slide())
		_conta("un avversario: un gradino di %d cm %s" % [roundi(alto * 100),
				"si sale" if sale else "resta un muro"], salito == sale,
				"a quota %.2f, z %.2f" % [bot.global_position.y, bot.global_position.z])
		bot.queue_free()
		await physics_frame
	stanza.queue_free()
	await process_frame


## Corre per `CORSA` secondi veri e dice se è salito sul gradino. `passo` è chi
## muove il corpo quando non lo muove lui (l'avversario spinto a mano).
func _corri(corpo: CharacterBody3D, passo: Callable) -> bool:
	var partito := Time.get_ticks_msec()
	while Time.get_ticks_msec() - partito < CORSA * 1000.0:
		await physics_frame
		passo.call()
	return corpo.global_position.y > 0.2 and corpo.global_position.z < -5.0


func _corsia(i: int) -> float:
	return -6.0 + 6.0 * float(i)


func _scatola(genitore: Node3D, centro: Vector3, misura: Vector3) -> void:
	var corpo := StaticBody3D.new()
	corpo.collision_layer = Strati.OSTACOLO
	corpo.collision_mask = 0
	var forma := CollisionShape3D.new()
	var scatola := BoxShape3D.new()
	scatola.size = misura
	forma.shape = scatola
	corpo.add_child(forma)
	genitore.add_child(corpo)
	corpo.position = centro


## I comandi finti: il pollice tutto in avanti, e nient'altro.
func _avanti() -> Node:
	var script := GDScript.new()
	script.source_code = "extends Node\n\nfunc movimento() -> Vector2:\n\treturn Vector2(0, -1)\n"
	script.reload()
	var comandi := Node.new()
	comandi.set_script(script)
	root.add_child(comandi)
	return comandi


# ------------------------------------------------------------------ le rampe

func _nelle_rampe() -> void:
	var arena: Node3D = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	for i in 4:
		await process_frame
		await physics_frame
	var pianta: Dictionary = arena.call("pianta")
	_nessun_pavimento_sopra(arena, pianta)
	await _le_rampe_si_salgono(arena, pianta)
	arena.queue_free()
	await process_frame


## **Nessun pavimento copre una rampa** fra i piedi e la testa di chi la sale. È il
## controllo che avrebbe trovato la scala nord-est il 26/08/2026: si scende dall'alto
## su ogni rampa, a righe, e la prima cosa che si tocca deve essere la rampa — o un
## soffitto abbastanza alto da passarci sotto in piedi.
func _nessun_pavimento_sopra(arena: Node3D, pianta: Dictionary) -> void:
	var spazio := arena.get_world_3d().direct_space_state
	var sopra := Arena.SPESSORE_PIANO + Giocatore.ALTEZZA_CORPO + 0.05
	var coperti: Array[String] = []
	var punti := 0
	for r in pianta["rampe"]:
		var da := Vector2(float(r["da"][0]), float(r["da"][1]))
		var a := Vector2(float(r["a"][0]), float(r["a"][1]))
		var lato := (a - da).normalized().orthogonal()
		var mezza := float(r["larghezza"]) * 0.5 - 0.3
		var quanti := 0
		for k in 25:
			var t := 0.02 + 0.96 * float(k) / 24.0
			var h := lerpf(float(r["quota_da"]), float(r["quota_a"]), t)
			for s in [-mezza, 0.0, mezza]:
				var p: Vector2 = da.lerp(a, t) + lato * s
				var domanda := PhysicsRayQueryParameters3D.create(Vector3(p.x, h + sopra, p.y),
						Vector3(p.x, h - 0.05, p.y), Strati.SOLIDO)
				var esito := spazio.intersect_ray(domanda)
				punti += 1
				if esito.is_empty():
					continue
				var chi: Object = esito["collider"]
				if (esito["position"] as Vector3).y > h + 0.03 and chi is Node \
						and (chi as Node).is_in_group(Muratura.GRUPPO_PAVIMENTI):
					quanti += 1
		if quanti > 0:
			coperti.append("%s (%d punti)" % [r["nome"], quanti])
	_conta("nessun pavimento sopra una rampa, fra i piedi e la testa", coperti.is_empty(),
			"; ".join(coperti) + " su %d punti" % punti)


## **Ogni rampa si sale da cima a fondo**, dal giocatore vero coi comandi finti: in
## asse e a due metri dai lati, partendo un metro e mezzo prima del piede. Dove ci si
## ferma deve esserci un muro o un pilone — qualcosa più alto del gradino — mai un
## gradino che il corpo poteva salire. Le quattro rampe del catino hanno un pilone in
## asse a un metro e mezzo dal piede: è la pianta, e conta come muro.
func _le_rampe_si_salgono(arena: Node3D, pianta: Dictionary) -> void:
	var g: Giocatore = arena.call("giocatore")
	g.comandi = _avanti()
	var spazio := arena.get_world_3d().direct_space_state
	for r in pianta["rampe"]:
		var sale_da: bool = float(r["quota_da"]) < float(r["quota_a"])
		var piede := _punto(r["da"] if sale_da else r["a"])
		var cima := _punto(r["a"] if sale_da else r["da"])
		var q_piede := minf(float(r["quota_da"]), float(r["quota_a"]))
		var q_cima := maxf(float(r["quota_da"]), float(r["quota_a"]))
		var d := (cima - piede).normalized()
		var lato := d.orthogonal()
		var lunga := piede.distance_to(cima)
		var in_cima := 0
		var su_un_gradino: Array[String] = []
		for s in [0.0, -2.0, 2.0]:
			var via: Vector2 = piede - d * 1.5 + lato * s
			g.global_position = Vector3(via.x, q_piede + 0.1, via.y)
			g.velocity = Vector3.ZERO
			g.punta(rad_to_deg(atan2(-d.x, -d.y)), 0.0)
			await physics_frame
			var esito: Array = await _sali(g, via, d, lunga + 3.5)
			var fatto: float = esito[0]
			var fermo: bool = esito[1]
			if not fermo and absf(g.global_position.y - q_cima) < 0.15:
				in_cima += 1
			elif fermo and not _muro_davanti(spazio, g, d):
				su_un_gradino.append("a %+.0f m, %.1f m dentro, quota %.2f" % [s, fatto - 1.5,
						g.global_position.y])
		_conta("«%s» si sale da cima a fondo" % r["nome"], in_cima > 0,
				"nessuna delle tre righe arriva in cima")
		_conta("«%s»: dove ci si ferma c'è un muro, mai un gradino" % r["nome"],
				su_un_gradino.is_empty(), "; ".join(su_un_gradino))
	g.comandi = null


## Corre lungo la rampa: torna quanto ha fatto e se si è fermato prima della fine.
func _sali(g: Giocatore, via: Vector2, d: Vector2, quanto: float) -> Array:
	var partito := Time.get_ticks_msec()
	var ultimo := 0.0
	var fermo_da := Time.get_ticks_msec()
	while Time.get_ticks_msec() - partito < PAZIENZA_RAMPA * 1000.0:
		await physics_frame
		var fatto := Vector2(g.global_position.x - via.x, g.global_position.z - via.y).dot(d)
		if fatto >= quanto:
			return [fatto, false]
		if fatto > ultimo + 0.02:
			ultimo = fatto
			fermo_da = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - fermo_da > 400:
			return [fatto, true]
	return [ultimo, true]


## Davanti ai piedi c'è qualcosa più alto del gradino? Un raggio appena sopra i 48
## cm, nel verso della corsa: se tocca, chi ferma è un muro.
func _muro_davanti(spazio: PhysicsDirectSpaceState3D, g: Giocatore, d: Vector2) -> bool:
	var da := g.global_position + Vector3(0, Gradino.ALTEZZA + 0.1, 0)
	var domanda := PhysicsRayQueryParameters3D.create(da,
			da + Vector3(d.x, 0, d.y) * (Giocatore.RAGGIO_CORPO + 0.4), Strati.SOLIDO, [g.get_rid()])
	return not spazio.intersect_ray(domanda).is_empty()


# ------------------------------------------------------------------ la rete

## La rete di cammino non chiede mai un gradino che il corpo non sale: fino al
## 04/10/2026 era cotta con 40 cm mentre il corpo ne saliva 12, e la strada degli
## avversari passava dove i piedi si fermavano.
func _la_rete_non_chiede_troppo() -> void:
	var scheda: Variant = JSON.parse_string(FileAccess.get_file_as_string(RETE_IMPRONTA))
	var scalino := -1.0
	if scheda is Dictionary and (scheda as Dictionary).has("cotta_per"):
		scalino = float(scheda["cotta_per"].get("scalino", -1.0))
	_conta("la rete sale al massimo quanto il corpo", scalino > 0.0 and scalino <= Gradino.ALTEZZA,
			"rete %.2f m, corpo %.2f m" % [scalino, Gradino.ALTEZZA])


# ------------------------------------------------------------------ attrezzi

func _punto(p: Array) -> Vector2:
	return Vector2(float(p[0]), float(p[1]))


func _conta(cosa: String, esito: bool, dettaglio := "") -> void:
	_prove += 1
	if esito:
		print("  ok   ", cosa)
	else:
		_errori += 1
		print("  NO   ", cosa, ("   (%s)" % dettaglio) if dettaglio != "" else "")


func _chiudi() -> void:
	print("\n%d prove, %d errori" % [_prove, _errori])
	quit(1 if _errori > 0 else 0)
