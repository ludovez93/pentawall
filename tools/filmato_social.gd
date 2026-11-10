extends SceneTree

## Attrezzo di lavorazione: **gira un filmato di gioco vero** per i social.
## Non è un collaudo e non tocca il gioco: fa partire una partita, mette il
## giocatore dietro le spalle di chi sta combattendo, lo fa mirare e sparare, e
## salva un fotogramma per volta. Il montaggio lo fa ffmpeg fuori di qui.
##
## I fotogrammi escono in `res://filmato/f00000.jpg`, uno per frame, già nella
## misura della finestra: per il verticale si lancia con --resolution 720x1280.
##
## Con --fixed-fps 30 ogni passo del gioco vale esattamente 1/30 di secondo,
## quindi il filmato è a velocità giusta anche se salvare le immagini è lento
## (senza, il gioco andrebbe al rallentatore e non si saprebbe di quanto).
##
##   godot --path . --resolution 720x1280 --fixed-fps 30 -s tools/filmato_social.gd -- [segmenti] [secondi]
##
## Ogni segmento è un momento continuo: fra un segmento e l'altro il giocatore
## si sposta, e quello stacco diventa il taglio del montaggio.

const CARTELLA := "res://filmato"
const FPS := 60
const DIETRO := 6.5
const CADENZA := 28      ## un colpo ogni 14 fotogrammi, cioè poco meno di mezzo secondo
const GIRO_AL_FRAME := 3.0  ## gradi: la mira si muove, non scatta

## Quanti fotogrammi sono passati dall'inizio: con --fixed-fps 30 e --write-movie
## servono a dire al montaggio dove comincia e dove finisce ogni momento.
var _conta := 0


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var segmenti := int(argomenti[0]) if argomenti.size() > 0 else 6
	var secondi := float(argomenti[1]) if argomenti.size() > 1 else 4.0
	for vecchio in _elenco_vecchi():
		DirAccess.remove_absolute(vecchio)
	DirAccess.make_dir_recursive_absolute(CARTELLA)

	Arena.modo_partita = true
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	for i in 60:
		await _passo()

	# si aspetta che finisca il conto alla rovescia: prima non c'è partita da filmare
	var scadenza := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < scadenza and float(arena.call("conto_alla_rovescia")) > 0.0:
		await _passo()
	for i in 60:
		await _passo()

	# Via l'interfaccia: il filmato deve mostrare il gioco, non raccontarlo.
	# Niente classifica, niente annunci, niente bottoni.
	for figlio in arena.get_children():
		if figlio is Comandi:
			(figlio as CanvasItem if figlio is CanvasItem else figlio).set("visible", false)

	var giocatore: Giocatore = arena.call("giocatore")
	var spazio := giocatore.get_world_3d().direct_space_state
	var fotogramma := 0
	var girati := 0
	var tentativi := 0

	while girati < segmenti and tentativi < segmenti * 25:
		tentativi += 1
		var coppia := _coppia_in_lotta(arena.call("avversari"), spazio)
		if coppia.is_empty():
			for i in 20:
				await _passo()
			continue
		var chi: Node3D = coppia[0]
		var contro: Node3D = coppia[1]
		# Ci si mette **di lato al duello**, non dietro le spalle di uno dei due:
		# così si vedono tutti e due, i dardi che attraversano l'inquadratura, e
		# l'avversario che si muove invece di darci la schiena.
		var asse := (contro.global_position - chi.global_position)
		asse.y = 0.0
		asse = asse.normalized()
		var fianco := Vector3(asse.z, 0.0, -asse.x)
		var centro := (chi.global_position + contro.global_position) * 0.5
		var dove := centro + fianco * DIETRO - asse * 2.0
		if not _libero(spazio, dove + Vector3.UP * 0.9, giocatore):
			dove = centro - fianco * DIETRO - asse * 2.0
			if not _libero(spazio, dove + Vector3.UP * 0.9, giocatore):
				continue
		giocatore.global_position = dove
		giocatore.velocity = Vector3.ZERO
		# La camera scivola: un'inquadratura ferma, in un reel, è una fotografia.
		var scorrimento := fianco * (1.6 if randf() < 0.5 else -1.6)

		var inizio := _conta
		var passi := int(secondi * FPS)
		for passo in passi:
			var bersaglio: Node3D = chi if is_instance_valid(chi) else null
			if bersaglio != null:
				var mira := bersaglio.global_position + Vector3.UP * 1.0 - (giocatore.global_position + Vector3.UP * 1.6)
				var giro := rad_to_deg(atan2(-mira.x, -mira.z))
				var pendenza := rad_to_deg(atan2(mira.y, Vector2(mira.x, mira.z).length()))
				giocatore.punta(_avvicina(giocatore.rotation_degrees.y, giro), pendenza - 1.5)
			if passo % CADENZA == 0 and passo > 6:
				giocatore.spara()
			giocatore.velocity = Vector3(scorrimento.x, giocatore.velocity.y, scorrimento.z)
			await _passo()
		girati += 1
		print("MOMENTO %d: da %.2f a %.2f secondi" % [girati, inizio / float(FPS), _conta / float(FPS)])

	print("FATTO: filmato lungo %.2f secondi" % (_conta / float(FPS)))
	quit()


## La mira si avvicina al bersaglio di qualche grado per volta: uno scatto secco
## si vede che è una macchina, un movimento no.
func _passo() -> void:
	await process_frame
	_conta += 1


func _avvicina(da: float, a: float) -> float:
	var differenza := wrapf(a - da, -180.0, 180.0)
	return da + clampf(differenza, -GIRO_AL_FRAME, GIRO_AL_FRAME)


## Un avversario che ha un bersaglio fra 7 e 22 metri, in vista.
func _coppia_in_lotta(avversari: Array, spazio: PhysicsDirectSpaceState3D) -> Array:
	for chi in avversari:
		var bersaglio: Node3D = (chi as Avversario).bersaglio
		if bersaglio == null or not is_instance_valid(bersaglio):
			continue
		var distanza := (chi as Node3D).global_position.distance_to(bersaglio.global_position)
		if distanza < 7.0 or distanza > 22.0:
			continue
		var raggio := PhysicsRayQueryParameters3D.create(
				(chi as Node3D).global_position + Vector3.UP * 1.4,
				bersaglio.global_position + Vector3.UP * 1.4)
		raggio.exclude = [(chi as CollisionObject3D).get_rid()]
		var tocco := spazio.intersect_ray(raggio)
		if tocco.is_empty() or tocco["collider"] == bersaglio:
			return [chi, bersaglio]
	return []


func _libero(spazio: PhysicsDirectSpaceState3D, punto: Vector3, giocatore: Giocatore) -> bool:
	var sfera := SphereShape3D.new()
	sfera.radius = 0.6
	var domanda := PhysicsShapeQueryParameters3D.new()
	domanda.shape = sfera
	domanda.transform = Transform3D(Basis(), punto)
	domanda.exclude = [giocatore.get_rid()]
	return spazio.intersect_shape(domanda, 1).is_empty()


func _elenco_vecchi() -> Array:
	var fuori: Array = []
	var cartella := DirAccess.open(CARTELLA)
	if cartella == null:
		return fuori
	for nome in cartella.get_files():
		if nome.ends_with(".jpg"):
			fuori.append(CARTELLA + "/" + nome)
	return fuori
