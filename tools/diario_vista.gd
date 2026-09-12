extends SceneTree

## Diario di lavorazione: gli avversari sparano al giocatore senza vederlo?
## E quanto tempo passano a inseguirlo senza averlo in vista?
## Dal telefono, 12/09/2026: «gli avversari sanno già dove sono, mi cominciano a
## sparare anche dietro i muri». Si misura, non si discute (LEARNED.md § 18).
##   godot --headless --path . -s tools/diario_vista.gd

const DURATA_MS := 25000

var _arena: Node
var _giocatore: Giocatore
var _visti := {}
var _colpi_al_giocatore := 0
var _colpi_senza_vista_petto := 0
var _colpi_senza_vista_bocca := 0
var _campioni := 0
var _inseguono_senza_vedere := 0


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	_arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(_arena)
	await process_frame
	await process_frame
	_giocatore = _arena.call("giocatore")
	_arena.call("avvia_sfida")
	var scadenza := Time.get_ticks_msec() + DURATA_MS
	var prossimo_spostamento := 0
	while Time.get_ticks_msec() < scadenza:
		await physics_frame
		# Il giocatore gira per l'arena: ogni cinque secondi una partenza diversa,
		# così le linee di vista cambiano.
		if Time.get_ticks_msec() > prossimo_spostamento:
			prossimo_spostamento = Time.get_ticks_msec() + 5000
			_arena.call("passa_alla_partenza_seguente")
		_conta_i_dardi()
		_conta_gli_inseguimenti()
	print("\ncolpi degli avversari verso il giocatore: %d" % _colpi_al_giocatore)
	print("  sparati con la linea bocca→petto chiusa: %d" % _colpi_senza_vista_bocca)
	print("  sparati con la linea petto→petto chiusa:  %d" % _colpi_senza_vista_petto)
	print("campioni di inseguimento: %d, di cui senza vedere il giocatore: %d (%.0f%%)" % [
		_campioni, _inseguono_senza_vedere,
		100.0 * _inseguono_senza_vedere / maxf(_campioni, 1)])
	quit()


func _conta_i_dardi() -> void:
	for nodo in get_nodes_in_group(Proiettile.GRUPPO):
		var dardo := nodo as Proiettile
		if dardo == null or _visti.has(dardo.get_instance_id()):
			continue
		_visti[dardo.get_instance_id()] = true
		var bot := dardo.tiratore as Avversario
		if bot == null or bot.bersaglio != _giocatore:
			continue
		_colpi_al_giocatore += 1
		var petto := _giocatore.global_position + Vector3(0, Avversario.ALTEZZA_PETTO, 0)
		if not _libera(bot.global_position + Vector3(0, Avversario.ALTEZZA_PETTO, 0), petto, bot):
			_colpi_senza_vista_petto += 1
		if not _libera(bot.call("_bocca"), petto, bot):
			_colpi_senza_vista_bocca += 1


func _conta_gli_inseguimenti() -> void:
	for bot in _arena.call("avversari"):
		if bot.bersaglio != _giocatore:
			continue
		_campioni += 1
		var petto := _giocatore.global_position + Vector3(0, Avversario.ALTEZZA_PETTO, 0)
		if not _libera(bot.global_position + Vector3(0, Avversario.ALTEZZA_PETTO, 0), petto, bot):
			_inseguono_senza_vedere += 1


func _libera(da: Vector3, a: Vector3, chi: CollisionObject3D) -> bool:
	var esclusi: Array[RID] = [chi.get_rid()]
	var domanda := PhysicsRayQueryParameters3D.create(da, a, Strati.SOLIDO, esclusi)
	return _arena.get_world_3d().direct_space_state.intersect_ray(domanda).is_empty()
