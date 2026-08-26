extends SceneTree

## Attrezzo di diagnosi: mette un avversario dall'altra parte dell'arena e scrive
## riga per riga cosa sta facendo mentre cammina. Non fa parte del gioco.
##
## Esiste perché sul cammino le ipotesi sono costate ogni volta più della misura
## (LEARNED.md § 18 e § 25): dove sta, quanto corre, se tocca terra, quanti passi
## ha davanti e dove sta puntando. Cinque righe di stampa dicono in un colpo quello
## che il ragionamento non chiude.
##
## Uso:  godot --path . -s tools/diario_cammino.gd

const OGNI_MS := 500
const QUANTO_MS := 30000

## Chi sta dove: `-- 2 0` mette il giocatore alla terza partenza e il bot alla
## prima. Senza, la coppia di prima.

var _arena: Node


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	_arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(_arena)
	await process_frame
	await process_frame

	var pianta: Dictionary = _arena.call("pianta")
	var partenze: Array = pianta["partenze"]
	var giocatore: Giocatore = _arena.call("giocatore")
	var indici := OS.get_cmdline_user_args()
	var casa := int(indici[0]) if indici.size() > 0 else 0
	var lontano := int(indici[1]) if indici.size() > 1 else 3
	giocatore.global_position = _dove(partenze[casa])
	giocatore.velocity = Vector3.ZERO

	var mappa: RID = _arena.get_world_3d().navigation_map
	await physics_frame
	NavigationServer3D.map_force_update(mappa)

	var bot := Avversario.crea(_arena, _dove(partenze[lontano]), 1)
	bot.bersaglio = giocatore
	print("giocatore a ", giocatore.global_position, "   bot a ", bot.global_position)

	var strada := NavigationServer3D.map_get_path(mappa, bot.global_position,
			giocatore.global_position, true)
	print("la strada ha %d punti, lunga %.1f m" % [strada.size(), _lunghezza(strada)])
	for i in mini(strada.size(), 6):
		print("   punto %d: %s" % [i, strada[i]])

	var partito := Time.get_ticks_msec()
	var prossima := 0
	while Time.get_ticks_msec() - partito < QUANTO_MS:
		await physics_frame
		var passato := Time.get_ticks_msec() - partito
		if passato < prossima:
			continue
		prossima = passato + OGNI_MS
		var piano := Vector3(bot.velocity.x, 0, bot.velocity.z)
		print("%5.1f s  dove %s  distanza %5.1f  velocita %4.1f m/s  terra %s  cammina %s  schiva %s" % [
			passato / 1000.0, _corto(bot.global_position),
			bot.global_position.distance_to(giocatore.global_position),
			piano.length(), "si" if bot.is_on_floor() else "NO",
			"si" if bot.in_cammino() else "NO",
			"si" if bot.in_schivata() else "no"])

	quit()


func _dove(p: Dictionary) -> Vector3:
	return Vector3(float(p["dove"][0]), float(p["quota"]) + 0.4, float(p["dove"][1]))


func _corto(v: Vector3) -> String:
	return "(%6.1f %5.1f %6.1f)" % [v.x, v.y, v.z]


func _lunghezza(strada: PackedVector3Array) -> float:
	var quanto := 0.0
	for i in range(1, strada.size()):
		quanto += strada[i].distance_to(strada[i - 1])
	return quanto
