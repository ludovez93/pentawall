extends SceneTree

## Attrezzo di lavorazione: **quanto calcolo costa ogni pezzo della partita**.
##
## Senza schermo il motore non disegna: la durata di un fotogramma è tutto e solo
## calcolo — script, animazioni, fisica, avversari. Si toglie il tetto ai
## fotogrammi al secondo e si spegne un pezzo alla volta, misurando in coppia
## con tutto acceso prima e dopo (LEARNED.md § 20: il rumore della macchina si
## vede solo così).
##
##   godot --headless --path . -s tools/misura_calcolo.gd

const SECONDI := 4.0

var _arena: Node


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	Engine.max_fps = 0
	Arena.modo_partita = true
	_arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(_arena)
	var scadenza := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < scadenza and float(_arena.call("conto_alla_rovescia")) > 0.0:
		await process_frame
	await _secondi(2.0)
	for prima in [true, false]:
		var staffa := Staffa.new()
		staffa.prima = prima
		staffa.misura = _staffe
		staffa.process_priority = -1000000 if prima else 1000000
		root.add_child(staffa)

	var prove := [
		["tutto acceso", func(_s: bool) -> void: pass],
		["senza animazioni dei corpi", func(spento: bool) -> void:
			for albero in _arena.find_children("*", "AnimationTree", true, false):
				(albero as AnimationTree).active = not spento],
		["senza torsione del busto", func(spento: bool) -> void:
			for t in _arena.find_children("*", "Torsione", true, false):
				(t as SkeletonModifier3D).active = not spento],
		["senza pubblico", func(spento: bool) -> void:
			var p := _arena.get_node_or_null("pubblico")
			if p != null:
				p.process_mode = Node.PROCESS_MODE_DISABLED if spento else Node.PROCESS_MODE_INHERIT],
		["senza avversari (fermi)", func(spento: bool) -> void:
			for b in _arena.call("avversari"):
				(b as Node).process_mode = Node.PROCESS_MODE_DISABLED if spento else Node.PROCESS_MODE_INHERIT],
		["senza particelle", func(spento: bool) -> void:
			for p in _arena.find_children("*", "GPUParticles3D", true, false):
				(p as Node).process_mode = Node.PROCESS_MODE_DISABLED if spento else Node.PROCESS_MODE_INHERIT
			for p in _arena.find_children("*", "CPUParticles3D", true, false):
				(p as Node).process_mode = Node.PROCESS_MODE_DISABLED if spento else Node.PROCESS_MODE_INHERIT],
		["senza interfaccia (comandi)", func(spento: bool) -> void:
			for c in _arena.find_children("*", "Comandi", true, false):
				(c as Node).process_mode = Node.PROCESS_MODE_DISABLED if spento else Node.PROCESS_MODE_INHERIT],
		["senza suoni", func(spento: bool) -> void:
			for c in _arena.find_children("*", "Suoni", true, false):
				(c as Node).process_mode = Node.PROCESS_MODE_DISABLED if spento else Node.PROCESS_MODE_INHERIT],
		["senza giocatore", func(spento: bool) -> void:
			var g := _arena.call("giocatore") as Node
			g.process_mode = Node.PROCESS_MODE_DISABLED if spento else Node.PROCESS_MODE_INHERIT],
		["senza lo script dell'arena", func(spento: bool) -> void:
			_arena.set_process(not spento)
			_arena.set_physics_process(not spento)],
		["tutto fermo", func(spento: bool) -> void:
			_arena.process_mode = Node.PROCESS_MODE_DISABLED if spento else Node.PROCESS_MODE_INHERIT],
		["senza potenziamenti", func(spento: bool) -> void:
			var p := _arena.get_node_or_null("potenziamenti")
			if p != null:
				p.process_mode = Node.PROCESS_MODE_DISABLED if spento else Node.PROCESS_MODE_INHERIT],
	]
	print("\n%-30s %9s %9s %9s" % ["", "acceso", "spento", "costo"])
	for prova in prove:
		var acceso := await _misura()
		(prova[1] as Callable).call(true)
		await _secondi(0.5)
		var spento := await _misura()
		(prova[1] as Callable).call(false)
		await _secondi(0.5)
		print("%-30s %7.2f ms %7.2f ms %7.2f ms" % [prova[0], acceso, spento, acceso - spento])
	quit()


## Il calcolo medio di un fotogramma, in millesimi, su `SECONDI` secondi veri: fra
## un nodo che gira per primo e uno che gira per ultimo (come la sonda, tappa 9).
## Senza schermo il motore ha un tetto ai fotogrammi, e l'intervallo non lo vede.
func _misura() -> float:
	_staffe.somma = 0.0
	_staffe.giri = 0
	var inizio := Time.get_ticks_usec()
	while Time.get_ticks_usec() - inizio < int(SECONDI * 1000000.0):
		await process_frame
	return _staffe.somma / float(maxi(_staffe.giri, 1))


class Staffa extends Node:
	var prima := true
	var misura: Staffe
	func _process(_d: float) -> void:
		if prima:
			misura.inizio = Time.get_ticks_usec()
		elif misura.inizio > 0:
			misura.somma += float(Time.get_ticks_usec() - misura.inizio) / 1000.0
			misura.giri += 1


class Staffe extends RefCounted:
	var inizio := 0
	var somma := 0.0
	var giri := 0


var _staffe := Staffe.new()


func _secondi(s: float) -> void:
	var fine := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < fine:
		await process_frame
