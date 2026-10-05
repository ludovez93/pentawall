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
## Lo stesso colpo, ma dicendo **da chi**. Nel duello non serviva — chi sparava
## era per forza l'altro — ma in una partita a sei chi tiene il punteggio deve
## sapere a chi accreditarlo, e chi ricompare deve sapere da chi tenersi lontano.
signal preso_da(chi: Object, punti: int, muri: int)

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
## Quanto la camera resta lontana da muri e soffitti. Gli angoli del piano vicino
## stanno a 11 cm dal suo centro (5 cm avanti, schermo del telefono a 2,17 di formato,
## campo in corsa di 81 gradi), e non devono mai entrare in un muro; facendo scorrere
## la sfera il motore si concede 3-4 cm (misurato da `prova_vivo`, 04/10/2026). Più di
## 20 no: a salto pieno la testa arriva a 2,68 m e sotto le terrazze il soffitto sta a
## 2,90.
const RAGGIO_CAMERA := 0.2
const CAMPO_TERZA := 75.0
const CAMPO_PRIMA := 62.0
const LENTEZZA_PRIMA := 0.82    ## in prima si mira meglio e ci si muove peggio
const TEMPO_CAMBIO := 0.16

const CADENZA := 0.42           ## fuoco manuale: un tocco, un colpo (DECISIONI.md 6)
const PENDENZA_MASSIMA := 1.4   ## radianti di inclinazione della testa (~80°)

## Quando si viene colpiti: 25 punti a chi ha sparato, 50 se di sponda, come per i
## bersagli e per gli avversari — il conto del gioco è uno solo (`Balistica`).
const IMMUNITA := 0.8           ## secondi di pace dopo un colpo incassato
const CONTRACCOLPO := 3.4       ## m/s di spinta all'indietro

## **I segnali di velocità e del colpo** (tappa 7, blocco B). La corsa a 7,62 m/s
## era giusta nel 1999 e lo è ancora: le mancava il contorno. Una capsula che
## scivola con la camera ferma e nessun passo sembra lenta a qualunque velocità.
const CAMPO_CORSA := 6.0        ## gradi in più di campo visivo a piena corsa
const PASSO := 0.38             ## secondi fra un passo e l'altro a piena corsa (~2,9 m)
const SCOSSA := 0.1             ## secondi di tremito della camera al colpo a segno
const AMPIEZZA_SCOSSA := 0.05   ## metri di scarto della camera nel tremito
const ROLLIO_COLPO := 0.06      ## radianti di rollio della camera al colpo incassato

## **Il corpo accusa** (tappa 8, blocco G): la vibrazione in mano, e la camera che
## si abbassa un attimo quando si atterra da un salto o da una caduta.
const VIBRA_COLPO := 22         ## millisecondi, colpo dato
const VIBRA_INCASSATO := 65     ## millisecondi, colpo incassato
const ATTERRAGGIO := 0.13       ## metri di discesa della camera all'atterraggio pieno
const CADUTA_SENTITA := 3.0     ## m/s di caduta sotto i quali l'atterraggio non si sente

var comandi: Node = null        ## i comandi per il pollice, se ci sono

## **I potenziamenti** (tappa 8, blocco H): il turbo moltiplica la velocità, i punti
## doppi i punti del colpo. Li accende e li spegne chi li gestisce (`Potenziamenti`).
var spinta := 1.0
var moltiplicatore_punti := 1

var _pendenza := 0.0
var _mescola := 0.0             ## 0 = terza persona, 1 = prima
var _in_prima := false
var _ricarica := 0.0
var _immunita := 0.0
var _sensibilita_mouse := 0.0022
var _corsa := 0.0               ## 0 fermo, 1 a piena velocità, lisciato
var _prossimo_passo := 0.0
var _scossa := 0.0
var _rollio := 0.0
var _rollio_voluto := 0.0

var _testa: Node3D
var _braccio: SpringArm3D
var _camera: Camera3D
var _aspetto: Node3D
var _corpo_visibile: Node3D
## Il corpo vero (tappa 8): corre, salta, spara e accusa i colpi. In prima persona
## sparisce e resta il blaster davanti agli occhi (`_arma`).
var _corpo: Corpo
var _arma: Node3D
var _canna: Node3D
var _linea: LineaMira
## Il rinculo del blaster in prima persona: 1 appena sparato, torna a zero.
var _rinculo := 0.0
## L'atterraggio: 1 appena toccato terra da una caduta piena, torna a zero.
var _atterraggio := 0.0
var _caduta := 0.0
## Il gradino appena salito che la vista non ha ancora raggiunto, in metri
## (`Gradino`): il corpo sale in un fotogramma, gli occhi e le gambe in un decimo.
var _scalino := 0.0


## Si gioca col pollice? Sul telefono, e anche **nel browser del telefono** — dove
## il tag «mobile» non esiste e i tocchi arrivano accompagnati da eventi del mouse
## finti: senza questo controllo, un tocco solo farebbe partire due colpi.
static func a_pollice() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")


func _ready() -> void:
	collision_layer = Strati.COMBATTENTI
	collision_mask = Strati.SOLIDO
	_costruisci()
	# Il mouse si cattura al primo clic, non all'avvio: così gli attrezzi di
	# lavorazione possono aprire la scena per uno scatto senza rubare il
	# puntatore a chi sta lavorando.


func _unhandled_input(evento: InputEvent) -> void:
	# Sul telefono ogni tocco genera anche un finto evento del mouse: se non lo
	# si scarta, un colpo solo ne fa partire due.
	if a_pollice() and (evento is InputEventMouse):
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
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED and not a_pollice():
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
	if _corpo != null:
		_corpo.aggiorna(velocity, is_on_floor(), _pendenza, delta)
		_corpo.lampeggia(_immunita > 0.0 and fmod(_immunita, 0.16) > 0.08)


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
	Suoni.sparo(partenza, true)
	if _corpo != null:
		_corpo.spara()
	_rinculo = 1.0
	# Chi spara si fa sentire: gli avversari che stanno cercando hanno una
	# notizia (tappa 7, blocco C). Si passa dal gruppo e non dalla classe, così
	# il giocatore non nomina l'avversario — che nomina già lui, e in GDScript
	# due classi che si nominano a vicenda sono un ciclo.
	for chi in get_tree().get_nodes_in_group(&"avversari"):
		chi.call("senti_sparo", partenza, self)
	sparato.emit(0)
	return true


func salta() -> void:
	if is_on_floor():
		velocity.y = SPINTA_SALTO
		Suoni.salto()


func punto_di_partenza() -> Vector3:
	return _canna.global_position


func camera() -> Camera3D:
	return _camera


## Il corpo vero di chi gioca: serve a chi lo deve scaldare o fotografare.
func corpo() -> Corpo:
	return _corpo


## Il FANTASMA (tappa 11, blocco B): il corpo diventa un velo. Lo accende `Potenziamenti`.
func fantasma(acceso: bool) -> void:
	if _corpo != null:
		_corpo.fantasma(acceso)


## L'hanno preso. Stesso conto di tutti: 25 punti, 50 se di sponda.
## Restituisce falso se era immune, così chi ha sparato sa se ha fatto punti.
func incassa(muri: int, da: Object = null) -> bool:
	if _immunita > 0.0:
		return false
	_immunita = IMMUNITA
	if _corpo != null:
		_corpo.colpito()
	var valgono := Balistica.punti_del_colpo(muri)
	incassato.emit(valgono, muri)
	preso_da.emit(da, valgono, muri)
	# Il colpo incassato si **sente** (sordo) e si **vede dal lato da cui arriva**:
	# la vignetta sul bordo dello schermo è l'avviso periferico di MIGLIORIE.md
	# § 4, e il contraccolpo — che c'era già — adesso inclina la camera.
	Suoni.colpo_incassato()
	Input.vibrate_handheld(VIBRA_INCASSATO)
	var verso_schermo := Vector2(0, 1)
	if da is Node3D:
		var indietro := global_position - (da as Node3D).global_position
		indietro.y = 0.0
		if indietro.length_squared() > 0.001:
			velocity += indietro.normalized() * CONTRACCOLPO
		verso_schermo = _verso_sullo_schermo((da as Node3D).global_position)
	_rollio_voluto = ROLLIO_COLPO * (-1.0 if verso_schermo.x >= 0.0 else 1.0)
	if comandi != null and comandi.has_method("colpo_incassato_da"):
		comandi.call("colpo_incassato_da", verso_schermo)
	return true


## Da che parte dello schermo sta un punto del mondo, visto dalla camera: destra
## positiva, **giù positivo** — come lo schermo. Davanti è in alto, dietro in basso.
func _verso_sullo_schermo(punto: Vector3) -> Vector2:
	var scarto := punto - global_position
	scarto.y = 0.0
	if scarto.length_squared() < 0.001:
		return Vector2(0, 1)
	var base := _camera.global_transform.basis
	var destra := Vector3(base.x.x, 0.0, base.x.z).normalized()
	var avanti := Vector3(-base.z.x, 0.0, -base.z.z).normalized()
	return Vector2(scarto.dot(destra), -scarto.dot(avanti)).normalized()


## Da quanto è al riparo: serve a chi disegna, per far vedere che il colpo è
## arrivato.
func immune() -> bool:
	return _immunita > 0.0


## Chi è appena rinato non si può colpire per qualche secondo, e lampeggia come
## dopo un colpo (tappa 11, blocco A: `Arena.PROTEZIONE`).
func proteggi(secondi: float) -> void:
	_immunita = maxf(_immunita, secondi)


## Tutto ciò che si può colpire sa incassare, e risponde se il colpo è valso
## punti: chi spara non ha bisogno di sapere cosa ha colpito.
func _su_colpo(corpo: Object, punto: Vector3, _normale: Vector3, muri: int) -> void:
	if corpo == null or corpo == self or not corpo.has_method("incassa"):
		return
	var valido: bool = corpo.call("incassa", muri, self)
	if not valido:
		return
	# **Il colpo a segno si vede dove succede** (blocco B): il numero che sale dal
	# punto d'impatto, il marcatore sul mirino, un decimo di tremito della camera e
	# il suono pieno. Il conto dei punti è quello di tutti: 25, 50 se di sponda.
	Suoni.colpo_a_segno(muri)
	_scossa = SCOSSA
	# Il colpo si sente anche in mano: un tocco breve. Sull'app nativa del telefono
	# lo fa il motore della vibrazione; nel browser di iOS non c'è, e non succede
	# niente (tappa 8, blocco G).
	Input.vibrate_handheld(VIBRA_COLPO)
	if comandi != null and comandi.has_method("punti_dal_mondo"):
		comandi.call("segna_il_colpo")
		comandi.call("punti_dal_mondo", punto,
				Balistica.punti_del_colpo(muri) * moltiplicatore_punti, muri)


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
	if not a_pollice():
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

	var massima := VELOCITA * (LENTEZZA_PRIMA if _in_prima else 1.0) * spinta
	var voluta := verso * massima
	var presa := 1.0 if is_on_floor() else CONTROLLO_ARIA
	var piano := Vector3(velocity.x, 0.0, velocity.z)

	if verso.length_squared() > 0.001:
		piano = piano.move_toward(voluta, ACCELERAZIONE * presa * delta)
	elif is_on_floor():
		piano = piano.move_toward(Vector3.ZERO, ATTRITO * delta)

	velocity.x = piano.x
	velocity.z = piano.z
	var era_in_aria := not is_on_floor()
	if not is_on_floor():
		velocity.y -= GRAVITA * delta
		_caduta = maxf(_caduta, -velocity.y)
	elif velocity.y < 0.0:
		velocity.y = -0.1
	_scalino = minf(_scalino + Gradino.sali(self, delta), Gradino.ALTEZZA)
	move_and_slide()
	if era_in_aria and is_on_floor():
		if _caduta > CADUTA_SENTITA:
			_atterraggio = clampf((_caduta - CADUTA_SENTITA) / 6.0, 0.35, 1.0)
			Suoni.atterraggio(_atterraggio)
		_caduta = 0.0
	_segna_la_corsa(delta)


## Quanto si sta correndo, e i passi. La quota di corsa allarga il campo visivo;
## il passo suona a ritmo della velocità vera, e solo coi piedi a terra.
func _segna_la_corsa(delta: float) -> void:
	var a_terra := Vector3(velocity.x, 0.0, velocity.z).length()
	var quota := clampf(a_terra / VELOCITA, 0.0, 1.0)
	_corsa = move_toward(_corsa, quota, delta * 5.0)
	if is_on_floor() and a_terra > 2.0:
		_prossimo_passo -= delta * quota
		if _prossimo_passo <= 0.0:
			_prossimo_passo = PASSO
			Suoni.passo()
	else:
		# Il primo passo arriva presto, appena si riparte.
		_prossimo_passo = minf(_prossimo_passo, PASSO * 0.4)


func _aggiorna_camera(delta: float) -> void:
	var bersaglio := 1.0 if _in_prima else 0.0
	if not is_equal_approx(_mescola, bersaglio):
		_mescola = move_toward(_mescola, bersaglio, delta / TEMPO_CAMBIO)
	var quota := smoothstep(0.0, 1.0, _mescola)
	_braccio.spring_length = lerpf(BRACCIO_TERZA, 0.0, quota)
	_braccio.position = _spalla_libera(Vector3(lerpf(SPALLA_TERZA, 0.0, quota),
			lerpf(0.22, 0.0, quota), 0.0))
	# Il campo si allarga di qualche grado in corsa e torna fermo da fermi: è il
	# segnale di velocità che costa meno di tutti.
	_camera.fov = lerpf(CAMPO_TERZA, CAMPO_PRIMA, quota) + CAMPO_CORSA * _corsa

	# Il tremito del colpo a segno: un decimo di secondo, che si smorza.
	if _scossa > 0.0:
		_scossa = maxf(_scossa - delta, 0.0)
		var forza := AMPIEZZA_SCOSSA * (_scossa / SCOSSA)
		_camera.h_offset = randf_range(-forza, forza)
		_camera.v_offset = randf_range(-forza, forza)
	else:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
	# L'atterraggio: giù di colpo, su in un quinto di secondo.
	if _atterraggio > 0.0:
		_atterraggio = maxf(_atterraggio - delta / 0.22, 0.0)
		_camera.v_offset -= ATTERRAGGIO * sin(_atterraggio * PI * 0.5)
	# Il gradino: il corpo è già sopra, la vista e le gambe lo raggiungono.
	_scalino = move_toward(_scalino, 0.0, delta * Gradino.VISTA)
	_testa.position.y = ALTEZZA_OCCHI - _scalino
	_aspetto.position.y = -_scalino
	# Il rollio del colpo incassato: va di colpo da un lato e torna piano.
	_rollio = move_toward(_rollio, _rollio_voluto, delta * 1.2)
	_rollio_voluto = move_toward(_rollio_voluto, 0.0, delta * 0.25)
	_camera.rotation.z = _rollio
	# In prima persona il proprio corpo si vedrebbe da dentro; l'arma resta,
	# perché è metà del carattere del gioco. E si nasconde anche in terza persona
	# quando il braccio della camera si accorcia contro un muro: senza questo,
	# addossandosi a una parete si finisce a guardare l'interno della propria testa.
	_corpo_visibile.visible = quota < 0.7 and _braccio.get_hit_length() > 2.2
	_canna.position = Vector3(0.38, -0.24, -0.85).lerp(Vector3(0.30, -0.26, -1.05), quota)
	# Il blaster davanti agli occhi serve solo in prima persona: in terza persona
	# il blaster è quello che il corpo tiene in mano.
	_arma.visible = quota >= 0.7
	# Il rinculo: indietro e in su di colpo, poi torna in un decimo e mezzo.
	_rinculo = maxf(_rinculo - delta / 0.15, 0.0)
	var calcio := _rinculo * _rinculo
	_arma.position = Vector3(0.38, -0.28, -0.45).lerp(Vector3(0.24, -0.27, -0.62), quota) \
			+ Vector3(0.0, 0.015, 0.07) * calcio
	_arma.rotation.x = 0.16 * calcio


## **La spalla non attraversa i muri.** Dal telefono, il 04/10/2026: *«se sono
## attaccato ai bordi dell'arena e giro la visuale vedo il nero fuori dell'arena»*.
## La camera in terza persona è appesa a una spalla 85 cm a destra della testa, e il
## corpo è largo 42: col muro a destra, la spalla finiva dentro il muro. Il braccio
## cerca gli ostacoli **partendo dalla spalla**, e il motore ignora l'ostacolo in cui
## si parte — così la camera usciva dall'arena, fino a 2,8 m (`tools/scatti_bordo.gd`).
## Adesso la spalla si cerca dalla testa, che sta sempre dentro il corpo, facendo
## scorrere la stessa sfera del braccio: dove la sfera si ferma, si ferma la spalla.
func _spalla_libera(spalla: Vector3) -> Vector3:
	if spalla.length_squared() < 0.0001:
		return spalla
	var testa := _testa.global_position
	var domanda := PhysicsShapeQueryParameters3D.new()
	domanda.shape = _braccio.shape
	domanda.transform = Transform3D(Basis.IDENTITY, testa)
	domanda.motion = _testa.global_transform * spalla - testa
	domanda.collision_mask = Strati.SOLIDO
	domanda.exclude = [get_rid()]
	var frazioni := get_world_3d().direct_space_state.cast_motion(domanda)
	return spalla * frazioni[0]


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
	var domanda := PhysicsRayQueryParameters3D.create(testa, bocca, Strati.SOLIDO, [get_rid()])
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
	# L'ombra di contatto delle varianti dell'aspetto (tappa 10): sul corpo, non sulla
	# parte visibile, così resta sul pavimento anche mentre la vista sale un gradino.
	Aspetto.ombra(self)

	_corpo_visibile = Node3D.new()
	_aspetto.add_child(_corpo_visibile)

	# **Il corpo vero** (tappa 8): fino al 03/10/2026 qui c'erano una capsula blu e
	# una sfera gialla per casco. Per il motore resta la capsula di sopra.
	_corpo = Corpo.crea("TU")
	_corpo_visibile.add_child(_corpo)

	# Il blaster della prima persona: lo stesso giocattolo che il corpo tiene in
	# mano, davanti agli occhi. Sta nell'anima del gioco del 1999 e resta.
	_arma = Node3D.new()
	var blaster: Node3D = (load(Corpo.BLASTER) as PackedScene).instantiate()
	# Nel file guarda verso +Z: girato, la bocca va avanti.
	blaster.rotation_degrees = Vector3(0, 180, 0)
	blaster.scale = Vector3.ONE * 0.62
	_arma.add_child(blaster)

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
	_braccio.collision_mask = Strati.SOLIDO
	# **Una sfera, non la camera.** Senza forma, il braccio fa scorrere la piramide
	# della camera e la lascia **toccare** il muro: il margine vale solo per il raggio
	# di un braccio senza camera (sorgente di 4.7.2, `spring_arm_3d.cpp`). In diagonale
	# un angolo del piano vicino entrava nel muro di tre centimetri, e da lì si vede
	# fuori. Con la sfera la camera resta sempre lontana da tutto quanto il suo raggio.
	var sfera := SphereShape3D.new()
	sfera.radius = RAGGIO_CAMERA
	_braccio.shape = sfera
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



## Un corpo vero al posto della capsula (tappa 7): si nasconde quello che c'era e
## si appende il nuovo sotto la parte visibile, così in prima persona sparisce
## come spariva la capsula. L'arma di scatole si spegne: il corpo ha la sua.
func vesti_con(corpo: Node3D) -> void:
	for figlio in _corpo_visibile.get_children():
		figlio.visible = false
	_arma.visible = false
	_corpo_visibile.add_child(corpo)
