class_name Giocatore
extends CharacterBody3D

## Chi gioca: movimento, le due camere, la mira e il colpo.
##
## I numeri vengono dal 1999, convertiti (400 u/s = 7,62 m/s), perché quella
## taratura reggeva già allora — RICERCA-ORIGINALE.md § 6. Sono un punto di
## partenza da tarare col pollice, non valori sacri.
##
## Le camere sono due ma il codice della mira è **uno solo**: si tira un raggio
## dal centro della camera, si trova il punto inquadrato, e il dardo parte dalla
## canna verso quel punto. Cambiare visuale sposta solo la camera (DECISIONI.md 1).

signal sparato(muri_previsti: int)
## L'hanno preso: `punti` sono quelli che vanno a chi ha sparato.
signal incassato(punti: int, muri: int)

const VELOCITA := 7.62          ## 400 u/s del 1999
const ACCELERAZIONE := 39.0     ## 2048 u/s²
const GRAVITA := 18.1           ## 950 u/s²
const SPINTA_SALTO := 6.19      ## 325 u/s, cioè un salto di 1,06 m
const CONTROLLO_ARIA := 0.35    ## sette volte quello di UT99, ed era voluto
const ATTRITO := 12.0

const ALTEZZA_OCCHI := 1.62
const RAGGIO_CORPO := 0.42
const ALTEZZA_CORPO := 1.8

const BRACCIO_TERZA := 3.9
const SPALLA_TERZA := 0.85
const CAMPO_TERZA := 75.0
const CAMPO_PRIMA := 62.0
const LENTEZZA_PRIMA := 0.82    ## in prima si mira meglio e ci si muove peggio
const TEMPO_CAMBIO := 0.16

const CADENZA := 0.42           ## fuoco manuale: un tocco, un colpo (DECISIONI.md 6)
const PENDENZA_MASSIMA := 1.4   ## radianti di inclinazione della testa (~80°)

## Quando si viene colpiti: 25 punti a chi ha sparato, raddoppiati a ogni muro,
## come per i bersagli e per gli avversari — il conto del gioco è uno solo.
const PUNTI_BASE := 25
const IMMUNITA := 0.8           ## secondi di pace dopo un colpo incassato
const CONTRACCOLPO := 3.4       ## m/s di spinta all'indietro

var comandi: Node = null        ## i comandi per il pollice, se ci sono

var _pendenza := 0.0
var _mescola := 0.0             ## 0 = terza persona, 1 = prima
var _in_prima := false
var _ricarica := 0.0
var _immunita := 0.0
var _sensibilita_mouse := 0.0022

var _testa: Node3D
var _braccio: SpringArm3D
var _camera: Camera3D
var _aspetto: Node3D
var _corpo_visibile: Node3D
var _arma: Node3D
var _canna: Node3D
var _linea: LineaMira


func _ready() -> void:
	collision_layer = Strati.COMBATTENTI
	collision_mask = Strati.MONDO
	_costruisci()
	# Il mouse si cattura al primo clic, non all'avvio: così gli attrezzi di
	# lavorazione possono aprire la scena per uno scatto senza rubare il
	# puntatore a chi sta lavorando.


func _unhandled_input(evento: InputEvent) -> void:
	# Sul telefono ogni tocco genera anche un finto evento del mouse: se non lo
	# si scarta, un colpo solo ne fa partire due.
	if OS.has_feature("mobile") and (evento is InputEventMouse):
		return

	if evento is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var scala := _camera.fov / CAMPO_TERZA
		gira(-evento.relative.x * _sensibilita_mouse * scala,
				-evento.relative.y * _sensibilita_mouse * scala)
	elif evento is InputEventKey and evento.pressed and not evento.echo:
		match evento.physical_keycode:
			KEY_V:
				cambia_camera()
			KEY_ESCAPE:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif evento is InputEventMouseButton and evento.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED and not OS.has_feature("mobile"):
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif evento.button_index == MOUSE_BUTTON_LEFT:
			spara()


func _physics_process(delta: float) -> void:
	_leggi_comandi(delta)
	_muovi(delta)


func _process(delta: float) -> void:
	_ricarica = maxf(_ricarica - delta, 0.0)
	_immunita = maxf(_immunita - delta, 0.0)
	_aggiorna_camera(delta)
	_aggiorna_linea()


## La mira, da qualunque parte arrivi: mouse o pollice.
func gira(orizzontale: float, verticale: float) -> void:
	rotate_y(orizzontale)
	_pendenza = clampf(_pendenza + verticale, -PENDENZA_MASSIMA, PENDENZA_MASSIMA)
	_testa.rotation.x = _pendenza


## Mira assoluta, in gradi. `gira` somma, questa mette: serve a chi deve
## piazzare il giocatore in un punto preciso — gli attrezzi degli scatti oggi,
## le partenze in arena domani.
func punta(giro_gradi: float, pendenza_gradi: float) -> void:
	rotation.y = deg_to_rad(giro_gradi)
	_pendenza = clampf(deg_to_rad(pendenza_gradi), -PENDENZA_MASSIMA, PENDENZA_MASSIMA)
	_testa.rotation.x = _pendenza


func cambia_camera() -> void:
	_in_prima = not _in_prima


## Il colore riservato si prova sulla scena vera: quando cambia, la linea di mira
## deve seguirlo, altrimenti promette un dardo di un altro colore.
func aggiorna_colore() -> void:
	_linea.imposta_colore(Proiettile.colore_riservato)


func in_prima_persona() -> bool:
	return _in_prima


## Che strada farebbe il colpo se partisse adesso: gli stessi tratti che disegna
## la linea di mira. Serve al collaudo, e domani all'avversario che deve capire
## se un dardo sta per arrivargli addosso.
func previsione() -> Array:
	var tiro := _soluzione_di_tiro()
	return Balistica.traiettoria(get_world_3d().direct_space_state, tiro[0], tiro[1],
			Balistica.PORTATA_MIRA, Balistica.MURI_MASSIMI, [get_rid()])


## Il colpo. Due righe, ed è tutto il sistema di mira del gioco:
## dove guardo (camera) → da dove parte (canna) → in che verso va.
func spara() -> bool:
	if _ricarica > 0.0:
		return false
	_ricarica = CADENZA
	var tiro := _soluzione_di_tiro()
	var partenza: Vector3 = tiro[0]
	var verso: Vector3 = tiro[1]
	var dardo := Proiettile.lancia(get_parent(), partenza, verso, [get_rid()], self)
	dardo.colpito.connect(_su_colpo)
	sparato.emit(0)
	return true


func salta() -> void:
	if is_on_floor():
		velocity.y = SPINTA_SALTO


func punto_di_partenza() -> Vector3:
	return _canna.global_position


func camera() -> Camera3D:
	return _camera


## L'hanno preso. Stesso conto di tutti: 25 punti, raddoppiati a ogni muro.
## Restituisce falso se era immune, così chi ha sparato sa se ha fatto punti.
func incassa(muri: int, da: Object = null) -> bool:
	if _immunita > 0.0:
		return false
	_immunita = IMMUNITA
	incassato.emit(PUNTI_BASE * int(pow(2, muri)), muri)
	if da is Node3D:
		var indietro := global_position - (da as Node3D).global_position
		indietro.y = 0.0
		if indietro.length_squared() > 0.001:
			velocity += indietro.normalized() * CONTRACCOLPO
	return true


## Da quanto è al riparo: serve a chi disegna, per far vedere che il colpo è
## arrivato.
func immune() -> bool:
	return _immunita > 0.0


## Tutto ciò che si può colpire sa incassare, e risponde se il colpo è valso
## punti: chi spara non ha bisogno di sapere cosa ha colpito.
func _su_colpo(corpo: Object, _punto: Vector3, _normale: Vector3, muri: int) -> void:
	if corpo == null or corpo == self or not corpo.has_method("incassa"):
		return
	corpo.call("incassa", muri, self)


func _leggi_comandi(delta: float) -> void:
	if comandi != null and comandi.has_method("mira_consumata"):
		var mira: Vector2 = comandi.mira_consumata()
		if mira != Vector2.ZERO:
			var scala := _camera.fov / CAMPO_TERZA
			gira(-mira.x * scala, -mira.y * scala)
		if comandi.call("fuoco_richiesto"):
			spara()
		if comandi.call("salto_richiesto"):
			salta()
	if Input.is_physical_key_pressed(KEY_SPACE):
		salta()
	if not OS.has_feature("mobile"):
		# La mira con le frecce serve quando il mouse è libero, cioè quando si
		# guarda la scena da fermi durante la lavorazione.
		var frecce := Vector2(
			Input.get_axis(&"ui_right", &"ui_left"),
			Input.get_axis(&"ui_down", &"ui_up"))
		if frecce != Vector2.ZERO and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			gira(frecce.x * 1.6 * delta, frecce.y * 1.6 * delta)


func _direzione_richiesta() -> Vector2:
	var richiesta := Vector2.ZERO
	if comandi != null and comandi.has_method("movimento"):
		richiesta = comandi.call("movimento")
	if richiesta.length_squared() < 0.01:
		var tastiera := Vector2(
			(1.0 if Input.is_physical_key_pressed(KEY_D) else 0.0) - (1.0 if Input.is_physical_key_pressed(KEY_A) else 0.0),
			(1.0 if Input.is_physical_key_pressed(KEY_S) else 0.0) - (1.0 if Input.is_physical_key_pressed(KEY_W) else 0.0))
		richiesta = tastiera.limit_length(1.0)
	return richiesta


func _muovi(delta: float) -> void:
	var richiesta := _direzione_richiesta()
	var avanti := -global_transform.basis.z
	var lato := global_transform.basis.x
	var verso := (lato * richiesta.x + avanti * -richiesta.y)
	verso.y = 0.0
	if verso.length_squared() > 1.0:
		verso = verso.normalized()

	var massima := VELOCITA * (LENTEZZA_PRIMA if _in_prima else 1.0)
	var voluta := verso * massima
	var presa := 1.0 if is_on_floor() else CONTROLLO_ARIA
	var piano := Vector3(velocity.x, 0.0, velocity.z)

	if verso.length_squared() > 0.001:
		piano = piano.move_toward(voluta, ACCELERAZIONE * presa * delta)
	elif is_on_floor():
		piano = piano.move_toward(Vector3.ZERO, ATTRITO * delta)

	velocity.x = piano.x
	velocity.z = piano.z
	if not is_on_floor():
		velocity.y -= GRAVITA * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1
	move_and_slide()


func _aggiorna_camera(delta: float) -> void:
	var bersaglio := 1.0 if _in_prima else 0.0
	if not is_equal_approx(_mescola, bersaglio):
		_mescola = move_toward(_mescola, bersaglio, delta / TEMPO_CAMBIO)
	var quota := smoothstep(0.0, 1.0, _mescola)
	_braccio.spring_length = lerpf(BRACCIO_TERZA, 0.0, quota)
	_braccio.position.x = lerpf(SPALLA_TERZA, 0.0, quota)
	_braccio.position.y = lerpf(0.22, 0.0, quota)
	_camera.fov = lerpf(CAMPO_TERZA, CAMPO_PRIMA, quota)
	# In prima persona il proprio corpo si vedrebbe da dentro; l'arma resta,
	# perché è metà del carattere del gioco. E si nasconde anche in terza persona
	# quando il braccio della camera si accorcia contro un muro: senza questo,
	# addossandosi a una parete si finisce a guardare l'interno della propria testa.
	_corpo_visibile.visible = quota < 0.7 and _braccio.get_hit_length() > 2.2
	_canna.position = Vector3(0.38, -0.24, -0.85).lerp(Vector3(0.30, -0.26, -1.05), quota)
	_arma.position = Vector3(0.38, -0.28, -0.45).lerp(Vector3(0.28, -0.30, -0.88), quota)


## Il tiro, in un posto solo: da dove parte e dove va. Lo usano sia il colpo vero
## sia la linea di mira, e devono usare **questo**, non ognuno il suo — se i due
## conti divergessero, la linea prometterebbe una traiettoria e il dardo ne
## farebbe un'altra.
func _soluzione_di_tiro() -> Array:
	var spazio := get_world_3d().direct_space_state
	var mirato := Balistica.punto_mirato(spazio, _camera, Balistica.PORTATA_MIRA, [get_rid()])
	var partenza := _bocca(spazio)
	var verso := Balistica.direzione_del_colpo(partenza, mirato, -_camera.global_transform.basis.z)
	return [partenza, verso]


## Dove sta davvero la bocca dell'arma. La canna sporge in avanti, e appoggiandosi
## a una parete si ritrova dall'altra parte del muro: sparare da lì vorrebbe dire
## attraversarlo. Se fra la testa e la canna c'è qualcosa, il colpo parte da lì.
func _bocca(spazio: PhysicsDirectSpaceState3D) -> Vector3:
	var testa := _testa.global_position
	var bocca := _canna.global_position
	var domanda := PhysicsRayQueryParameters3D.create(testa, bocca, Strati.MONDO, [get_rid()])
	var esito := spazio.intersect_ray(domanda)
	if esito.is_empty():
		return bocca
	return (esito["position"] as Vector3) + (esito["normal"] as Vector3) * 0.08


## La linea di mira si ricalcola ogni fotogramma con la stessa funzione che
## userà il dardo: se le due divergessero, il gioco mentirebbe.
func _aggiorna_linea() -> void:
	var tiro := _soluzione_di_tiro()
	var tratti := Balistica.traiettoria(get_world_3d().direct_space_state, tiro[0], tiro[1],
			Balistica.PORTATA_MIRA, Balistica.MURI_MASSIMI, [get_rid()])
	_linea.aggiorna(tratti)


func _costruisci() -> void:
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = RAGGIO_CORPO
	capsula.height = ALTEZZA_CORPO
	forma.shape = capsula
	forma.position = Vector3(0, ALTEZZA_CORPO * 0.5, 0)
	add_child(forma)

	_aspetto = Node3D.new()
	add_child(_aspetto)

	_corpo_visibile = Node3D.new()
	_aspetto.add_child(_corpo_visibile)

	var busto := MeshInstance3D.new()
	var mesh_busto := CapsuleMesh.new()
	mesh_busto.radius = RAGGIO_CORPO
	mesh_busto.height = ALTEZZA_CORPO
	busto.mesh = mesh_busto
	busto.position = Vector3(0, ALTEZZA_CORPO * 0.5, 0)
	busto.material_override = _materiale(Color(0.16, 0.42, 0.95), 0.3)
	_corpo_visibile.add_child(busto)

	var casco := MeshInstance3D.new()
	var mesh_casco := SphereMesh.new()
	mesh_casco.radius = 0.3
	mesh_casco.height = 0.52
	casco.mesh = mesh_casco
	casco.position = Vector3(0, ALTEZZA_CORPO - 0.06, 0)
	casco.material_override = _materiale(Color(0.95, 0.85, 0.12), 0.25)
	_corpo_visibile.add_child(casco)

	# L'arma di plastica vistosa: sta nell'anima del gioco del 1999 e resta.
	# Gialla e blu di proposito — l'arancio è del proiettile e di nessun altro.
	_arma = Node3D.new()
	var canna_mesh := MeshInstance3D.new()
	var mesh_canna := BoxMesh.new()
	mesh_canna.size = Vector3(0.16, 0.18, 0.7)
	canna_mesh.mesh = mesh_canna
	canna_mesh.material_override = _materiale(Color(0.95, 0.82, 0.1), 0.3)
	_arma.add_child(canna_mesh)
	var serbatoio := MeshInstance3D.new()
	var mesh_serbatoio := CylinderMesh.new()
	mesh_serbatoio.top_radius = 0.13
	mesh_serbatoio.bottom_radius = 0.13
	mesh_serbatoio.height = 0.3
	serbatoio.mesh = mesh_serbatoio
	serbatoio.rotation_degrees = Vector3(90, 0, 0)
	serbatoio.position = Vector3(0, 0.14, 0.12)
	serbatoio.material_override = _materiale(Color(0.1, 0.55, 0.95), 0.35)
	_arma.add_child(serbatoio)

	_testa = Node3D.new()
	_testa.position = Vector3(0, ALTEZZA_OCCHI, 0)
	add_child(_testa)

	# Arma e canna stanno **sotto la testa**, non sotto il corpo: devono seguire
	# l'inclinazione della mira. Attaccate al corpo, in prima persona finivano
	# dentro la faccia — la camera guardava l'interno del serbatoio.
	_testa.add_child(_arma)
	_canna = Node3D.new()
	_testa.add_child(_canna)

	_braccio = SpringArm3D.new()
	_braccio.spring_length = BRACCIO_TERZA
	# Sopra la spalla e un po' più in alto della testa: con la camera all'altezza
	# degli occhi, in terza persona il proprio corpo si mangia il centro dello
	# schermo, che è esattamente dove si mira.
	_braccio.position = Vector3(SPALLA_TERZA, 0.22, 0)
	_braccio.collision_mask = Strati.MONDO
	_braccio.margin = 0.3
	_testa.add_child(_braccio)

	_camera = Camera3D.new()
	_camera.fov = CAMPO_TERZA
	_camera.near = 0.05
	_camera.far = 220.0
	_camera.current = true
	_braccio.add_child(_camera)

	# Prima in scena, poi il colore: i materiali della linea nascono nel suo
	# `_ready`, e prima di allora non c'è niente da colorare.
	_linea = LineaMira.new()
	add_child(_linea)
	_linea.imposta_colore(Proiettile.colore_riservato)


func _materiale(colore: Color, luce: float) -> StandardMaterial3D:
	var materiale := StandardMaterial3D.new()
	materiale.albedo_color = colore
	materiale.emission_enabled = true
	materiale.emission = colore
	materiale.emission_energy_multiplier = luce
	materiale.roughness = 0.45
	return materiale
