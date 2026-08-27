class_name Avversario
extends CharacterBody3D

## Lo sparring partner: la tappa 2.
##
## L'originale del 1999 non era stupido — la mira con l'anticipo c'era, scritta
## bene, e la schivata pure. Erano **spente ai livelli bassi** da tre interruttori,
## e questo gli è costato la fama di gioco per bambini (RICERCA-ORIGINALE.md § 8).
## Qui le tre capacità sono **sempre accese, a ogni livello**: anticipa, schiva, e
## ogni colpo lo avvisa. Fra facile e duro cambiano solo tempo di reazione,
## precisione e cadenza — mai **cosa sa fare** (MIGLIORIE.md § 1).
##
## E c'è il pezzo che il 1999 non poteva avere: schiva anche i rimbalzi. Il conto
## della traiettoria lo stiamo già facendo per disegnare la linea di mira al
## giocatore; lo stesso conto, letto dall'altra parte, dice all'avversario che sta
## per arrivargli addosso qualcosa da dietro l'angolo.

## Il giocatore l'ha centrato: punti a lui. Stesso segnale dei bersagli, così chi
## tiene il punteggio non deve sapere cosa ha colpito.
## I candidati per il colore dell'alone, che è il **terzo colore riservato** del
## gioco dopo il bianco-arancio del dardo e il ciano-turchese delle sponde. Si
## sceglie sulla scena vera con il pulsante ALONE, non su un campionario.
const ALONI := [
	{"nome": "verde lime", "colore": Color(0.60, 1.0, 0.24)},
	{"nome": "bianco", "colore": Color(0.96, 0.96, 0.92)},
	{"nome": "magenta", "colore": Color(1.0, 0.30, 0.72)},
]

## Il contorno lavora **da tre a quindici metri**, e oltre si spegne. Non è un
## limite tecnico, è una regola di gioco: un contorno che ti trova l'avversario
## in fondo all'arena è il marcatore da sparatutto moderno, e questo è un gioco a
## punti del 1999 rifatto oggi. Da lontano l'avversario lo si cerca — e quando
## spara è il suo dardo incandescente a tradirlo.
const PORTATA_ALONE := 15.0
const DISSOLVENZA_ALONE := 3.5

## Lo spessore del contorno si misura **sullo schermo, non nel mondo**: `grow`
## lavora in metri, quindi da vicino diventerebbe un tubo e da lontano un filo.
## Questo è il numero che tiene fermo il tratto: metri di crescita per metro di
## distanza.
const SPESSORE_PER_METRO := 0.0069
const SPESSORE_FILO := 0.4  ## il filo scuro è una frazione del contorno

## Il contorno si può spegnere, per confrontare col pollice invece che a parole.
static var ALONE_ACCESO := true
static var alone_scelto := 0

## Il colore della squadra: cremisi, quella di casa. Non è riservato a niente ed
## è giusto così — cambia da squadra a squadra, ed è l'alone a rendere leggibile
## chiunque lo indossi.
static var colore_squadra := Color(0.86, 0.14, 0.22)

var _contorni: Array[Dictionary] = []

signal centrato(punti: int, muri: int)
## Ha centrato il suo bersaglio: punti a sé.
signal ha_centrato(punti: int, muri: int)
## Lo stesso colpo di `centrato`, ma dicendo **da chi** è arrivato. È il segnale
## su cui si regge la partita a sei: là un colpo può venire da chiunque, e
## `centrato` da solo non basta più a sapere a chi vanno i punti.
signal preso_da(chi: Object, punti: int, muri: int)

## Il corpo si muove con i numeri del giocatore, non con numeri suoi: se corresse
## a una velocità diversa, tarare i comandi guardando lui non direbbe niente.
const ALTEZZA_OCCHI := 1.62
const ALTEZZA_PETTO := 0.95
const ALTEZZA_SPALLE := 1.55
const RAGGIO_CORPO := 0.42
const ALTEZZA_CORPO := 1.8

const PUNTI_BASE := 25          ## come i bersagli: 25, e raddoppia a ogni muro
const IMMUNITA := 0.8           ## secondi di pace dopo un colpo incassato
const CONTRACCOLPO := 3.4       ## m/s di spinta all'indietro quando incassa

## La schivata è il balzo laterale dell'originale: 400 u/s, più lenta di quella
## del giocatore, che ne faceva 600 (RICERCA-ORIGINALE.md § 8).
const VELOCITA_SCHIVATA := 7.62
const DURATA_SCHIVATA := 0.34
const SPAZIO_MINIMO_SCHIVATA := 1.1  ## metri liberi di lato, o si schiva dentro un muro

## Quanto avanti guarda l'allarme. Oltre, sarebbe preveggenza: reagirebbe a colpi
## che non sono ancora un pericolo.
const ORIZZONTE_ALLARME := 1.3   ## secondi di volo del dardo
const ESAMI_AL_SECONDO := 20.0

## Quanto deve passargli vicino un dardo perché sia un pericolo: mezzo corpo, il
## raggio del dardo, e un dito di margine.
const MARGINE_PERICOLO := 0.18

## La distanza a cui gli piace stare: abbastanza vicino da colpire, abbastanza
## lontano da avere il tempo di schivare.
const DISTANZA_MINIMA := 6.0
const DISTANZA_MASSIMA := 14.0

## Ogni quanto si richiede la strada. Un percorso è una domanda al motore di
## navigazione: farla a ogni fotogramma vuol dire pagarla sessanta volte al secondo
## per una risposta che cambia a passo d'uomo.
const RICALCOLO_PERCORSO := 0.5

## Quanto ci si avvicina a un passo del percorso prima di puntare al successivo.
## Più stretto di così si gira attorno ai punti invece di attraversarli.
const PASSO_PRESO := 1.2

## Quanto tempo di spinta senza moto basta per dire «sono incastrato».
##
## Serve perché i punti di un percorso stanno **sugli spigoli**: la rete si ritira
## di mezzo metro dai muri, e puntare dritto al suo vertice vuol dire strusciare
## contro l'angolo — dove non c'è niente da far scivolare, perché il muro è quasi
## perpendicolare al moto. Misurato il 26/08/2026: undici secondi fermo contro il
## pilastro dell'ocra, con la spinta al massimo e la velocità a zero.
const PAZIENZA_INCASTRO := 0.45

## Le tre tarature. Cambiano **solo** come esegue, mai cosa sa fare.
const TARATURE := [
	{
		"nome": "facile",
		"reazione": 0.45,      ## secondi prima di accorgersi di un dardo in arrivo
		"errore_gradi": 4.5,   ## quanto può sbagliare la mira
		"ricarica": 1.8,       ## moltiplicatore della cadenza del giocatore
		"lato_giusto": 0.5,    ## quante volte schiva dalla parte con più spazio
		"salto": 0.10,         ## quanto spesso salta cambiando direzione
	},
	{
		"nome": "medio",
		"reazione": 0.25,
		"errore_gradi": 2.2,
		"ricarica": 1.3,
		"lato_giusto": 0.85,
		"salto": 0.18,
	},
	{
		"nome": "duro",
		"reazione": 0.12,
		"errore_gradi": 0.8,
		"ricarica": 1.0,
		"lato_giusto": 1.0,
		"salto": 0.28,
	},
]

## Chi insegue e a chi spara. Senza, resta dov'è — ma continua a schivare: è così
## che i collaudi possono sparargli addosso senza rincorrerlo.
var bersaglio: Node3D = null

var _livello := 1
var _ricarica := 0.0
var _immunita := 0.0
var _schivata := 0.0
var _verso_schivata := Vector3.ZERO
var _strafe := 1.0
var _cambio_strafe := 0.0
var _prossimo_esame := 0.0
var _posizione_vista := Vector3.ZERO
var _velocita_vista := Vector3.ZERO
var _prima_occhiata := true

## I dardi già visti: quanto manca prima che l'occhio li registri, e quelli su cui
## la schivata è già partita. Chiave: l'identificativo del dardo.
var _allarmi := {}
var _gia_schivati := {}

## La strada verso il bersaglio, e a che punto la sta percorrendo.
var _percorso := PackedVector3Array()
var _passo := 0
var _prossimo_percorso := 0.0
var _stava_camminando := false
var _fermo_da := 0.0

var _aspetto: Node3D
var _canna: Node3D
var _pezzi: Array = []  ## {materiale, luce}: la luce di riposo, per il lampeggio


static func crea(genitore: Node, dove: Vector3, livello: int = 1) -> Avversario:
	var bot := Avversario.new()
	bot._livello = clampi(livello, 0, TARATURE.size() - 1)
	genitore.add_child(bot)
	bot.global_position = dove
	return bot


func _ready() -> void:
	collision_layer = Strati.COMBATTENTI
	collision_mask = Strati.SOLIDO
	_costruisci()


## Il contorno si aggiorna con il disegno, non con la fisica: dipende da dove sta
## la camera, e la camera si muove a ogni fotogramma.
func _process(_delta: float) -> void:
	_aggiorna_i_contorni()


func _physics_process(delta: float) -> void:
	_ricarica = maxf(_ricarica - delta, 0.0)
	_immunita = maxf(_immunita - delta, 0.0)
	_lampeggia()
	_guarda_il_bersaglio(delta)

	_prossimo_esame -= delta
	if _prossimo_esame <= 0.0:
		_prossimo_esame = 1.0 / ESAMI_AL_SECONDO
		_esamina_i_dardi()
	_scala_gli_allarmi(delta)

	_aggiorna_il_percorso(delta)
	_muovi(delta)
	_controlla_se_sono_incastrato(delta)
	_mira_e_spara()


func livello() -> int:
	return _livello


func nome_livello() -> String:
	return String(TARATURE[_livello]["nome"])


func imposta_livello(nuovo: int) -> void:
	_livello = clampi(nuovo, 0, TARATURE.size() - 1)
	_ricarica = 0.0


func passa_al_livello_seguente() -> void:
	imposta_livello((_livello + 1) % TARATURE.size())


## L'hanno preso. Stesso conto dei bersagli: 25 punti, raddoppiati a ogni muro —
## un colpo a cinque sponde ne vale 800. Restituisce falso se era immune, così
## chi ha sparato sa se ha fatto punti davvero.
func incassa(muri: int, da: Object = null) -> bool:
	if _immunita > 0.0:
		return false
	_immunita = IMMUNITA
	var valgono := PUNTI_BASE * int(pow(2, muri))
	centrato.emit(valgono, muri)
	preso_da.emit(da, valgono, muri)
	if da is Node3D:
		var indietro := global_position - (da as Node3D).global_position
		indietro.y = 0.0
		if indietro.length_squared() > 0.001:
			velocity += indietro.normalized() * CONTRACCOLPO
	return true


## Dove mira adesso: il punto **davanti** al bersaglio, non il bersaglio.
## È pubblica perché è la cosa che il collaudo deve poter guardare da fuori.
func punto_di_mira() -> Vector3:
	if bersaglio == null or not is_instance_valid(bersaglio):
		return global_position - global_transform.basis.z * 10.0
	var centro := _centro_del_bersaglio()
	var bocca := _bocca()
	# Due giri: il tempo di volo dipende dalla distanza, e la distanza dipende dal
	# punto anticipato. È la correzione del 1999, che funzionava anche in bassa
	# gravità perché teneva conto della zona (RICERCA-ORIGINALE.md § 8).
	var mira := centro
	for giro in 2:
		var tempo := bocca.distance_to(mira) / Proiettile.VELOCITA
		mira = centro + _velocita_vista * tempo
	return mira


## Quanto tempo manca prima che un dardo gli arrivi addosso, contando tutti i
## rimbalzi che gli restano. Negativo se quel dardo non è un problema.
##
## Qui sta il cuore della tappa: **è la stessa funzione della linea di mira**.
## Chi sa leggere un rimbalzo lo schiva, chiunque sia.
func tempo_all_impatto(dardo: Proiettile) -> float:
	if dardo == null or not is_instance_valid(dardo) or not dardo.in_volo():
		return -1.0
	var portata := Proiettile.VELOCITA * ORIZZONTE_ALLARME
	var tratti := Balistica.traiettoria(get_world_3d().direct_space_state,
			dardo.global_position, dardo.verso(), portata,
			dardo.muri_restanti(), dardo.esclusi())
	if tratti.is_empty():
		return -1.0
	# Due altezze invece di una: un corpo è alto quasi due metri, e un colpo alla
	# testa misurato dal petto sembrerebbe passare lontano.
	var soglia := RAGGIO_CORPO + Proiettile.RAGGIO + MARGINE_PERICOLO
	var migliore := -1.0
	for altezza in [ALTEZZA_PETTO, ALTEZZA_SPALLE]:
		var esito := Balistica.avvicinamento(tratti, global_position + Vector3(0, altezza, 0))
		if float(esito[0]) <= soglia:
			var tempo := float(esito[1]) / Proiettile.VELOCITA
			if migliore < 0.0 or tempo < migliore:
				migliore = tempo
	return migliore


## Sta schivando in questo momento.
func in_schivata() -> bool:
	return _schivata > 0.0


func _centro_del_corpo() -> Vector3:
	return global_position + Vector3(0, ALTEZZA_PETTO, 0)


func _centro_del_bersaglio() -> Vector3:
	return _posizione_vista + Vector3(0, ALTEZZA_PETTO, 0)


## Dove sta davvero la bocca dell'arma. La canna sporge in avanti e appoggiandosi
## a una parete finirebbe dall'altra parte del muro: sparare da lì vorrebbe dire
## attraversarlo. È lo stesso controllo che fa il giocatore, per lo stesso motivo.
func _bocca() -> Vector3:
	var spalla := global_position + Vector3(0, ALTEZZA_OCCHI, 0)
	var punta := _canna.global_position
	var domanda := PhysicsRayQueryParameters3D.create(spalla, punta, Strati.SOLIDO, [get_rid()])
	var esito := get_world_3d().direct_space_state.intersect_ray(domanda)
	if esito.is_empty():
		return punta
	return (esito["position"] as Vector3) + (esito["normal"] as Vector3) * 0.08


## L'avversario **guarda**, non legge nel pensiero: la velocità del bersaglio la
## ricava dagli spostamenti, come farebbe un giocatore. Così l'anticipo funziona
## contro qualunque cosa si muova, e non solo contro chi ha una velocità da
## esibire.
func _guarda_il_bersaglio(delta: float) -> void:
	if bersaglio == null or not is_instance_valid(bersaglio):
		return
	var adesso := bersaglio.global_position
	if _prima_occhiata:
		_prima_occhiata = false
		_posizione_vista = adesso
		_velocita_vista = Vector3.ZERO
		return
	if delta > 0.0:
		var grezza := (adesso - _posizione_vista) / delta
		grezza.y = 0.0
		# Un filo di livellamento: senza, un urto contro un muro manderebbe
		# l'anticipo a dieci metri di distanza per un solo fotogramma.
		_velocita_vista = _velocita_vista.lerp(grezza, 0.35)
	_posizione_vista = adesso


## L'allarme: guarda i dardi in volo che non sono suoi e segna quelli che gli
## arriveranno addosso. Non serve che nessuno glielo dica — nell'originale
## l'avviso era una proprietà per arma, e quasi nessuna ce l'aveva.
func _esamina_i_dardi() -> void:
	for nodo in get_tree().get_nodes_in_group(Proiettile.GRUPPO):
		var dardo := nodo as Proiettile
		if dardo == null or dardo.tiratore == self:
			continue
		var chiave := dardo.get_instance_id()
		if tempo_all_impatto(dardo) < 0.0:
			# Non è più un pericolo: si dimentica del tutto. Anche la schivata
			# già fatta, perché lo stesso dardo può tornare indietro dopo un
			# rimbalzo — e allora è un pericolo nuovo, da schivare di nuovo.
			_allarmi.erase(chiave)
			_gia_schivati.erase(chiave)
		elif not _allarmi.has(chiave) and not _gia_schivati.has(chiave):
			_allarmi[chiave] = float(TARATURE[_livello]["reazione"])


## Il tempo di reazione: l'allarme è acceso, ma l'avversario si muove solo quando
## se ne accorge. È qui che sta la differenza fra facile e duro — non nel sapere
## schivare, che lo sanno tutti.
func _scala_gli_allarmi(delta: float) -> void:
	for chiave in _allarmi.keys():
		var dardo := instance_from_id(int(chiave)) as Proiettile
		if dardo == null or not dardo.in_volo():
			_allarmi.erase(chiave)
			continue
		_allarmi[chiave] = float(_allarmi[chiave]) - delta
		if float(_allarmi[chiave]) <= 0.0:
			_allarmi.erase(chiave)
			_gia_schivati[chiave] = true
			_schiva(dardo)
	# Le chiavi dei dardi spariti non restano in giro a occupare posto.
	for chiave in _gia_schivati.keys():
		if not is_instance_id_valid(int(chiave)):
			_gia_schivati.erase(chiave)


## Il balzo. Di lato rispetto al dardo, verso la parte dove c'è spazio: schivare
## dentro un muro è peggio che non schivare.
func _schiva(dardo: Proiettile) -> void:
	var lato := dardo.verso().cross(Vector3.UP)
	lato.y = 0.0
	if lato.length_squared() < 0.001:
		lato = global_transform.basis.x
	lato = lato.normalized()

	var spazio_a := _spazio_libero(lato)
	var spazio_b := _spazio_libero(-lato)
	var migliore := lato
	if absf(spazio_a - spazio_b) > 0.3:
		migliore = lato if spazio_a > spazio_b else -lato
	else:
		# Spazio uguale da tutte e due le parti: si continua da dove si stava già
		# andando. Cambiare lato a metà scarto vuol dire **rientrare** nella
		# traiettoria del dardo — e da fuori sembra un avversario ubriaco.
		var moto := Vector3(velocity.x, 0.0, velocity.z)
		if moto.dot(lato) < -0.5:
			migliore = -lato

	var scelto := migliore
	if randf() > float(TARATURE[_livello]["lato_giusto"]):
		scelto = -migliore
	# Il lato sbagliato è un errore di scelta, non un suicidio: se di là c'è un
	# muro a un metro il balzo non parte, e l'errore si vede lo stesso.
	if _spazio_libero(scelto) < SPAZIO_MINIMO_SCHIVATA:
		scelto = migliore
	if _spazio_libero(scelto) < SPAZIO_MINIMO_SCHIVATA:
		# Chiuso da tutte e due le parti: si salta, che è l'altra via d'uscita.
		if is_on_floor():
			velocity.y = Giocatore.SPINTA_SALTO
		return

	_verso_schivata = scelto
	_schivata = DURATA_SCHIVATA


func _spazio_libero(verso: Vector3) -> float:
	var portata := SPAZIO_MINIMO_SCHIVATA + 1.5
	var da := _centro_del_corpo()
	var domanda := PhysicsRayQueryParameters3D.create(da, da + verso * portata,
			Strati.SOLIDO, [get_rid()])
	var esito := get_world_3d().direct_space_state.intersect_ray(domanda)
	if esito.is_empty():
		return portata
	return da.distance_to(esito["position"])


## Il movimento: gira intorno al bersaglio tenendosi a distanza di tiro. Non è un
## percorso calcolato — in una stanza sola non serve, e il navmesh è di un'altra
## tappa — ma non resta mai fermo, che è la cosa che conta per chi deve imparare
## ad anticipare.
func _muovi(delta: float) -> void:
	var voluta := Vector3.ZERO
	if _schivata > 0.0:
		_schivata -= delta
		voluta = _verso_schivata * VELOCITA_SCHIVATA
	elif bersaglio != null and is_instance_valid(bersaglio):
		voluta = _direzione_tattica(delta) * Giocatore.VELOCITA

	var presa := 1.0 if is_on_floor() else Giocatore.CONTROLLO_ARIA
	var piano := Vector3(velocity.x, 0.0, velocity.z)
	if voluta.length_squared() > 0.001:
		piano = piano.move_toward(voluta, Giocatore.ACCELERAZIONE * presa * delta)
	elif is_on_floor():
		piano = piano.move_toward(Vector3.ZERO, Giocatore.ATTRITO * delta)
	velocity.x = piano.x
	velocity.z = piano.z

	if not is_on_floor():
		velocity.y -= Giocatore.GRAVITA * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1
	move_and_slide()

	# Guarda dove spara, non dove corre: l'arma deve seguire la mira, o si vede
	# un avversario che colpisce di spalle.
	var verso_mira := punto_di_mira() - global_position
	verso_mira.y = 0.0
	if verso_mira.length_squared() > 0.01:
		rotation.y = atan2(-verso_mira.x, -verso_mira.z)


func _direzione_tattica(delta: float) -> Vector3:
	var verso_lui := bersaglio.global_position - global_position
	verso_lui.y = 0.0
	var distanza := verso_lui.length()
	if distanza < 0.01:
		return Vector3.ZERO
	verso_lui = verso_lui.normalized()
	var lato := verso_lui.cross(Vector3.UP).normalized()

	_cambio_strafe -= delta
	if _cambio_strafe <= 0.0:
		_cambio_strafe = randf_range(1.1, 2.3)
		_strafe = -_strafe
		if is_on_floor() and randf() < float(TARATURE[_livello]["salto"]):
			velocity.y = Giocatore.SPINTA_SALTO

	var lo_vede := _lo_vede()

	# Lontano o coperto: si **cammina**, e la strada la dà la rete di cammino. In
	# una scena che non ne ha — il poligono, l'angolo — la strada è vuota e vale
	# tutto quello che c'era prima.
	var strada := _direzione_del_cammino(distanza, lo_vede)
	if strada != Vector3.ZERO:
		return strada

	var direzione := lato * _strafe
	if distanza > DISTANZA_MASSIMA:
		direzione += verso_lui * 1.2
	elif distanza < DISTANZA_MINIMA:
		direzione -= verso_lui * 1.2
	if not lo_vede:
		# Coperto: si sposta di lato per riaprirsi la linea, invece di restare lì
		# a sparare contro un pilastro.
		direzione += lato * _strafe * 0.8

	# Anti-incastro: se davanti c'è un muro si gira dall'altra parte. In una
	# stanza sola vale più di un percorso calcolato.
	if direzione.length_squared() > 0.001:
		direzione = direzione.normalized()
		if _spazio_libero(direzione) < 1.2:
			_strafe = -_strafe
			_cambio_strafe = randf_range(0.6, 1.2)
			direzione = (lato * _strafe).normalized()
	return direzione


# ------------------------------------------------------------------ il cammino

## La strada verso il bersaglio, ricalcolata due volte al secondo.
##
## Serve dall'arena intera in poi. In una stanza sola non serviva — girargli
## intorno bastava, ed era scritto nel codice — ma con rampe, scala e ballatoio un
## avversario senza percorso si incastra nel primo angolo, e un avversario
## incastrato rende impossibile giudicare se perdere contro di lui sembra giusto.
##
## La rete è **cotta in anticipo** (`tools/cuoci_percorsi.gd`) perché la pagina web
## gira senza thread: qui si fa solo la domanda. Dove la rete non c'è la risposta è
## vuota, e allora comanda la tattica di sempre.
func _aggiorna_il_percorso(delta: float) -> void:
	_prossimo_percorso -= delta
	if _prossimo_percorso > 0.0:
		return
	_prossimo_percorso = RICALCOLO_PERCORSO
	if bersaglio == null or not is_instance_valid(bersaglio):
		_percorso = PackedVector3Array()
		return
	var mappa := get_world_3d().navigation_map
	if NavigationServer3D.map_get_regions(mappa).is_empty():
		_percorso = PackedVector3Array()
		return
	_percorso = NavigationServer3D.map_get_path(mappa, global_position,
			bersaglio.global_position, true)
	_passo = 0


## Cambia bersaglio, che in una partita a sei succede di continuo.
##
## Non basta assegnare il campo: chi guarda si porta dietro **la posizione vista
## la volta prima**, e passando da un bersaglio all'altro quello scarto diventa
## una velocità di quaranta metri al secondo — l'anticipo sparerebbe fuori
## dall'arena per un fotogramma. Si riparte dall'occhiata come se lo vedesse
## adesso, e si butta la strada, che portava dall'altro.
func punta_a(nuovo_bersaglio: Node3D) -> void:
	if nuovo_bersaglio == bersaglio:
		return
	bersaglio = nuovo_bersaglio
	_prima_occhiata = true
	_velocita_vista = Vector3.ZERO
	if nuovo_bersaglio != null:
		_posizione_vista = nuovo_bersaglio.global_position
	ricomincia_il_cammino()


## Butta la strada che stava seguendo. Serve a chi lo sposta di colpo — la
## ricomparsa dopo un colpo incassato — perché senza continuerebbe mezzo secondo a
## camminare verso un punto che ormai sta dall'altra parte dell'arena.
func ricomincia_il_cammino() -> void:
	_percorso = PackedVector3Array()
	_passo = 0
	_prossimo_percorso = 0.0


## Sta seguendo una strada in questo momento. Serve al collaudo, che deve poter
## distinguere «cammina» da «gli gira intorno» senza aprire il codice.
func in_cammino() -> bool:
	return not _percorso.is_empty()


## Quando la spinta non produce moto, il passo si dà per preso e si salta: contro
## uno spigolo un corpo resta lì finché qualcosa non lo smuove, e il salto è quello
## che farebbe chiunque. La strada non si richiede subito — sarebbe la stessa, con
## lo stesso spigolo davanti — ma dopo un secondo.
func _controlla_se_sono_incastrato(delta: float) -> void:
	if not _stava_camminando:
		_fermo_da = 0.0
		return
	if Vector3(velocity.x, 0.0, velocity.z).length() > 1.0:
		_fermo_da = 0.0
		return
	_fermo_da += delta
	if _fermo_da < PAZIENZA_INCASTRO:
		return
	_fermo_da = 0.0
	_passo += 1
	_prossimo_percorso = maxf(_prossimo_percorso, 1.0)
	if is_on_floor():
		velocity.y = Giocatore.SPINTA_SALTO


func _direzione_del_cammino(distanza: float, lo_vede: bool) -> Vector3:
	_stava_camminando = false
	if _percorso.is_empty():
		return Vector3.ZERO
	# A tiro e in vista comanda la tattica: avvicinarsi ancora seguendo la strada
	# vorrebbe dire camminargli addosso in linea retta, che è il modo più semplice
	# di farsi anticipare.
	if distanza <= DISTANZA_MASSIMA and lo_vede:
		return Vector3.ZERO
	var passo := _prossimo_passo()
	if passo.length_squared() < 0.04:
		return Vector3.ZERO
	_stava_camminando = true
	return passo.normalized()


## Il primo passo che vale ancora la pena inseguire. Quelli che si ha già addosso
## si buttano, o si resta a girare attorno a un punto raggiunto.
func _prossimo_passo() -> Vector3:
	while _passo < _percorso.size():
		var scarto := _percorso[_passo] - global_position
		scarto.y = 0.0
		if scarto.length() > PASSO_PRESO or _passo == _percorso.size() - 1:
			return scarto
		_passo += 1
	return Vector3.ZERO


func _lo_vede() -> bool:
	if bersaglio == null or not is_instance_valid(bersaglio):
		return false
	var esclusi: Array[RID] = [get_rid()]
	var domanda := PhysicsRayQueryParameters3D.create(_bocca(),
			_centro_del_bersaglio(), Strati.TIRO, esclusi)
	var esito := get_world_3d().direct_space_state.intersect_ray(domanda)
	if esito.is_empty():
		return false
	return esito["collider"] == bersaglio


## Il colpo. Anticipa sempre — a ogni livello, dal primo minuto di gioco: un
## avversario che non anticipa insegna al giocatore che l'anticipo non serve.
func _mira_e_spara() -> void:
	if bersaglio == null or not is_instance_valid(bersaglio) or _ricarica > 0.0:
		return
	if not _lo_vede():
		return
	_ricarica = Giocatore.CADENZA * float(TARATURE[_livello]["ricarica"])

	var partenza := _bocca()
	var verso := punto_di_mira() - partenza
	if verso.length_squared() < 0.01:
		return
	var esclusi: Array[RID] = [get_rid()]
	var dardo := Proiettile.lancia(get_parent(), partenza, _sbaglia(verso.normalized()),
			esclusi, self)
	dardo.colpito.connect(_su_colpo)


## L'errore di mira: un cono attorno alla direzione giusta, largo quanto dice la
## taratura. È **questo** che separa facile da duro, insieme alla reazione.
func _sbaglia(verso: Vector3) -> Vector3:
	var apertura := deg_to_rad(float(TARATURE[_livello]["errore_gradi"]))
	if apertura <= 0.0:
		return verso
	var asse := verso.cross(Vector3.UP)
	if asse.length_squared() < 0.001:
		asse = Vector3.RIGHT
	var sbandata := verso.rotated(asse.normalized(), randf_range(-apertura, apertura))
	return sbandata.rotated(verso, randf_range(0.0, TAU)).normalized()


## Chi tiene il punteggio non deve sapere cosa è stato colpito: tutto ciò che si
## può colpire sa incassare, e risponde se il colpo è valso punti. È anche il
## motivo per cui questo file non nomina mai la classe del giocatore.
func _su_colpo(corpo: Object, _punto: Vector3, _normale: Vector3, muri: int) -> void:
	if corpo == null or corpo == self or not corpo.has_method("incassa"):
		return
	var valido: bool = corpo.call("incassa", muri, self)
	if valido and corpo == bersaglio:
		ha_centrato.emit(PUNTI_BASE * int(pow(2, muri)), muri)


## Appena colpito si accende: senza, si vedrebbe un avversario incassare un colpo
## e non succedere niente, e sembrerebbe rotto.
func _lampeggia() -> void:
	var acceso := _immunita > 0.0 and fmod(_immunita, 0.16) > 0.08
	for pezzo in _pezzi:
		var materiale: StandardMaterial3D = pezzo["materiale"]
		var luce: float = pezzo["luce"]
		materiale.emission_energy_multiplier = luce * 3.0 if acceso else luce


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

	# Cremisi e bianco: la squadra avversaria. Non arancio, non ciano, non
	# magenta — quei tre sono i candidati del dardo, e il colore del dardo non lo
	# indossa nessuno (DECISIONI.md § B).
	var mesh_busto := CapsuleMesh.new()
	mesh_busto.radius = RAGGIO_CORPO
	mesh_busto.height = ALTEZZA_CORPO

	# **L'alone.** È la risposta alla domanda della tappa 4, ed è lo stesso
	# meccanismo del filo scuro del dardo, rovesciato: la stessa capsula un filo
	# più grande, vista da dentro, così del corpo resta solo il contorno.
	#
	# Serve perché il colore del corpo **non può** essere riservato — è quello
	# della squadra, e le squadre sono il contenuto del gioco (DECISIONI.md 8).
	# Un cremisi davanti a una parete di mattoni sparisce, e sparirebbe qualunque
	# tinta davanti alla parete giusta: in un'arena satura non esiste un colore
	# che vada bene dappertutto. Il contorno invece non dipende dal fondo — è la
	# stessa strada del dardo, che si separa **per luminanza e per disegno, non
	# per tinta** (DECISIONI.md § B).
	if ALONE_ACCESO:
		var mesh_alone_casco := SphereMesh.new()
		mesh_alone_casco.radius = 0.3
		mesh_alone_casco.height = 0.52
		# **Due gusci, non uno**, ed è di nuovo il dardo: filo scuro attaccato al
		# corpo, contorno acceso fuori. Con il solo contorno acceso, una squadra
		# della sua stessa famiglia di colore se lo mangerebbe — il magenta sul
		# cremisi si fondeva, verificato guardandolo. Il filo scuro in mezzo fa sì
		# che il contorno non tocchi mai il colore della squadra, **qualunque**
		# colore sia: è il punto di tutta la tappa.
		for guscio in [
			{"grande": false, "colore": Color(0.03, 0.03, 0.06)},
			{"grande": true, "colore": Color(ALONI[alone_scelto]["colore"])},
		]:
			var quota: float = 1.0 if guscio["grande"] else SPESSORE_FILO
			for pezzo in [
				{"mesh": mesh_busto, "dove": Vector3(0, ALTEZZA_CORPO * 0.5, 0)},
				{"mesh": mesh_alone_casco, "dove": Vector3(0, ALTEZZA_CORPO - 0.06, 0)},
			]:
				var strato := MeshInstance3D.new()
				strato.mesh = pezzo["mesh"]
				strato.position = pezzo["dove"]
				var pelle := _pelle_alone(guscio["colore"])
				strato.material_override = pelle
				strato.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_aspetto.add_child(strato)
				_contorni.append({"materiale": pelle, "quota": quota})

	var busto := MeshInstance3D.new()
	busto.mesh = mesh_busto
	busto.position = Vector3(0, ALTEZZA_CORPO * 0.5, 0)
	busto.material_override = _materiale(colore_squadra, 0.3)
	_aspetto.add_child(busto)

	var casco := MeshInstance3D.new()
	var mesh_casco := SphereMesh.new()
	mesh_casco.radius = 0.3
	mesh_casco.height = 0.52
	casco.mesh = mesh_casco
	casco.position = Vector3(0, ALTEZZA_CORPO - 0.06, 0)
	casco.material_override = _materiale(Color(0.93, 0.93, 0.96), 0.25)
	_aspetto.add_child(casco)

	# La visiera guarda avanti: si deve capire in un colpo d'occhio da che parte
	# sta guardando, perché è da lì che arriva il colpo.
	var visiera := MeshInstance3D.new()
	var mesh_visiera := BoxMesh.new()
	mesh_visiera.size = Vector3(0.34, 0.12, 0.1)
	visiera.mesh = mesh_visiera
	visiera.position = Vector3(0, ALTEZZA_CORPO - 0.06, -0.26)
	visiera.material_override = _materiale(Color(0.08, 0.1, 0.18), 0.1)
	_aspetto.add_child(visiera)

	# L'arma sporge **fuori** dal busto: a mezzo raggio di distanza dall'asse
	# restava sepolta dentro la capsula, e da fuori si vedeva solo uno spigolo
	# giallo. Il corpo ha raggio 0,42: qui si sta a 0,52.
	var arma := Node3D.new()
	arma.position = Vector3(0.52, ALTEZZA_OCCHI - 0.2, -0.45)
	_aspetto.add_child(arma)
	var canna_mesh := MeshInstance3D.new()
	var mesh_canna := BoxMesh.new()
	mesh_canna.size = Vector3(0.16, 0.18, 0.7)
	canna_mesh.mesh = mesh_canna
	canna_mesh.material_override = _materiale(Color(0.95, 0.82, 0.1), 0.3)
	arma.add_child(canna_mesh)
	var serbatoio := MeshInstance3D.new()
	var mesh_serbatoio := CylinderMesh.new()
	mesh_serbatoio.top_radius = 0.13
	mesh_serbatoio.bottom_radius = 0.13
	mesh_serbatoio.height = 0.3
	serbatoio.mesh = mesh_serbatoio
	serbatoio.rotation_degrees = Vector3(90, 0, 0)
	serbatoio.position = Vector3(0, 0.14, 0.12)
	serbatoio.material_override = _materiale(Color(0.85, 0.2, 0.3), 0.35)
	arma.add_child(serbatoio)

	_canna = Node3D.new()
	_canna.position = Vector3(0.52, ALTEZZA_OCCHI - 0.14, -0.9)
	_aspetto.add_child(_canna)


## La pelle del contorno: la capsula vista **da dentro** e cresciuta di poco, senza
## luci di scena addosso — così il contorno è identico nella grotta verde e nel
## tempio rosso, esattamente come il dardo. Resta **sotto la soglia del bagliore**:
## sopra l'uno ci va solo il dardo, e un avversario non deve mai brillare più del
## colpo che gli stai tirando.
static func _pelle_alone(colore: Color) -> StandardMaterial3D:
	var materiale := StandardMaterial3D.new()
	materiale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materiale.albedo_color = colore
	materiale.cull_mode = BaseMaterial3D.CULL_FRONT
	materiale.grow = true
	materiale.grow_amount = 0.055
	materiale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materiale.disable_receive_shadows = true
	return materiale


## Il contorno, fotogramma per fotogramma: spessore fermo sullo schermo e
## dissolvenza oltre la portata. Sono le due cose che lo tengono un **segnale**
## invece che una decorazione che cresce e cala da sola.
func _aggiorna_i_contorni() -> void:
	if _contorni.is_empty():
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var distanza := camera.global_position.distance_to(
			global_position + Vector3(0, ALTEZZA_CORPO * 0.5, 0))
	var spessore := clampf(distanza * SPESSORE_PER_METRO, 0.02, 0.14)
	var quanto := clampf((PORTATA_ALONE - distanza) / DISSOLVENZA_ALONE, 0.0, 1.0)
	for contorno in _contorni:
		var materiale: StandardMaterial3D = contorno["materiale"]
		materiale.grow_amount = spessore * float(contorno["quota"])
		materiale.albedo_color.a = quanto


func _materiale(colore: Color, luce: float) -> StandardMaterial3D:
	var materiale := StandardMaterial3D.new()
	materiale.albedo_color = colore
	materiale.emission_enabled = true
	materiale.emission = colore
	materiale.emission_energy_multiplier = luce
	materiale.roughness = 0.45
	_pezzi.append({"materiale": materiale, "luce": luce})
	return materiale
