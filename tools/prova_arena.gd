extends SceneTree

## Collaudo dell'arena intera (tappa 5).
##
## Metà di questi controlli non guardano il codice: guardano **la pianta**, che è
## un file di testo (`arene/palestra.json`) e si può correggere senza che nessuno
## se ne accorga. Un'arena sbagliata sulla carta si costruisce benissimo.
##
## Uso:  godot --path . -s tools/prova_arena.gd

const PIANTA := "res://arene/palestra.json"
const RETE := "res://arene/palestra_cammino.res"
const IMPRONTA := "res://arene/palestra_cammino.json"

## Quanto può mancare all'arrivo perché un percorso valga «ci si arriva». Il motore
## di navigazione, quando la meta è irraggiungibile, **non risponde vuoto**: dà la
## strada fino al punto più vicino che ha trovato. Senza questo controllo la prova
## direbbe sempre di sì (LEARNED.md § 19).
const ARRIVO := 2.5

## Quanto si aspetta un avversario che deve attraversare l'arena. La diagonale è 93
## metri e si percorre in 12,2 secondi in linea retta: a piedi, fra rampe e giri,
## il doppio abbondante. Si aspetta **un esito**, non un numero di fotogrammi
## (LEARNED.md § 17), e il tetto serve solo a non restare appesi.
const PAZIENZA_MS := 30000

var _errori := 0
var _prove := 0
var _arena: Node


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var pianta: Dictionary = Arena.carica_pianta(PIANTA)
	_la_pianta_ha_senso(pianta)

	_arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(_arena)
	await process_frame
	await process_frame
	_la_scena_dice_la_stessa_cosa(pianta)
	_il_disegno_paga_il_rimbalzo(pianta)
	await _la_rete_di_cammino(pianta)
	await _lavversario_ti_raggiunge(pianta)
	await _la_partita()

	_chiudi()


# ------------------------------------------------------------------ la pianta

func _la_pianta_ha_senso(pianta: Dictionary) -> void:
	var mis: Dictionary = pianta["misura"]
	var diagonale := Vector2(float(mis["larghezza"]), float(mis["profondita"])).length()
	_conta("la diagonale sta fra 90 e 100 metri (decisione 12)",
			diagonale > 90.0 and diagonale < 100.0, "%.1f m" % diagonale)
	_conta("la traversata dura fra 11 e 13 secondi a 7,62 m/s",
			diagonale / 7.62 > 11.0 and diagonale / 7.62 < 13.0, "%.1f s" % (diagonale / 7.62))
	_conta("ci sono almeno sei partenze", pianta["partenze"].size() >= 6,
			"%d" % pianta["partenze"].size())
	_sponde_dappertutto(pianta)
	_nessuno_nasce_addosso_a_un_bersaglio(pianta)
	_le_quote_hanno_un_nome(pianta)


## Le sponde stanno dappertutto: è la decisione del committente del 26/08/2026 —
## ci si spara addosso ovunque, e il rimbalzo è un'opzione che paga, mai un
## obbligo. Se una zona resta senza, quella zona è un corridoio con un neon.
func _sponde_dappertutto(pianta: Dictionary) -> void:
	var conti := {"nord": 0, "sud": 0, "est": 0, "ovest": 0, "cuore": 0}
	for s in pianta["sponde"]:
		var x := float(s["centro"][0])
		var z := float(s["centro"][1])
		if absf(x) <= 13.0 and absf(z) <= 13.0:
			conti["cuore"] += 1
		elif absf(z) > absf(x):
			conti["nord" if z < 0.0 else "sud"] += 1
		else:
			conti["est" if x > 0.0 else "ovest"] += 1
	var magra := ""
	for dove in conti:
		if int(conti[dove]) < 3:
			magra = "%s ne ha %d" % [dove, conti[dove]]
	_conta("ci sono sponde in tutte e quattro le ali e nel cuore", magra == "", magra)


## Nascere addosso a un bersaglio vuol dire venticinque punti gratis a
## ripetizione. Trovato da Fable **sulla pianta**, il 26/08/2026, prima che
## l'arena esistesse: la partenza della tribuna stava a tre metri dal suo
## bersaglio. La distanza si misura nello spazio e non in pianta, o un bersaglio
## sette metri sotto un pavimento risulta addosso a chi ci cammina sopra.
func _nessuno_nasce_addosso_a_un_bersaglio(pianta: Dictionary) -> void:
	var vicino := ""
	for p in pianta["partenze"]:
		for b in pianta["bersagli"]:
			var d := _dove(p["dove"], p["quota"]).distance_to(_dove(b["dove"], b["quota"]))
			if d < 6.0:
				vicino = "%s è a %.1f m da «%s»" % [p["nome"], d, b["nome"]]
	_conta("nessuno nasce a meno di sei metri da un bersaglio", vicino == "", vicino)


## Quattro quote, e ognuna con un nome: è il modo in cui ci si orienta in
## un'arena grande senza mappa (catino, campo, terrazze, ballatoio).
func _le_quote_hanno_un_nome(pianta: Dictionary) -> void:
	var quote := {}
	for zona in pianta["zone"]:
		quote[float(zona["quota"])] = true
	_conta("l'arena ha almeno tre quote diverse", quote.size() >= 3,
			"%d quote" % quote.size())
	var dislivello := float(pianta["misura"]["quote"][-1]) - float(pianta["misura"]["quote"][0])
	_conta("il dislivello sta fra 6 e 12 metri", dislivello >= 6.0 and dislivello <= 12.0,
			"%.1f m" % dislivello)


func _dove(p: Array, quota: Variant) -> Vector3:
	return Vector3(float(p[0]), float(quota), float(p[1]))


# ------------------------------------------------------------------ la scena

func _la_scena_dice_la_stessa_cosa(pianta: Dictionary) -> void:
	var muri := get_nodes_in_group(Muratura.GRUPPO_MURI)
	var sponde := get_nodes_in_group(Muratura.GRUPPO_SPONDE)
	_conta("la scena costruisce tutte le sponde della pianta, e solo quelle",
			sponde.size() == pianta["sponde"].size(),
			"%d costruite su %d" % [sponde.size(), pianta["sponde"].size()])
	_conta("costruisce piani, rampe e muri",
			muri.size() >= pianta["muri"].size() + pianta["zone"].size() + pianta["rampe"].size(),
			"%d corpi solidi" % muri.size())
	_conta("nessuna superficie è muro e sponda insieme",
			_nessuna_in_comune(muri, sponde), "qualcuna sta in tutti e due i gruppi")

	for sponda in sponde:
		if (sponda as CollisionObject3D).collision_layer != Strati.MONDO:
			_conta("le sponde stanno sullo strato che riflette", false, "una sta sull'altro")
			return
	_conta("le sponde stanno sullo strato che riflette", true)

	var giocatore: Giocatore = _arena.call("giocatore")
	_conta("il giocatore parte dentro l'arena",
			absf(giocatore.global_position.x) < 33.0 and absf(giocatore.global_position.z) < 33.0,
			str(giocatore.global_position))
	_conta("si comincia con la regola nuova", bool(_arena.call("solo_sponde")),
			"si comincia da «rimbalza tutto»")


# ------------------------------------------------------------------ il cammino

## La rete di cammino non è codice e non è la pianta: è una **terza cosa**, cotta
## da un attrezzo e salvata nel repository. Per questo ha il difetto delle cose
## cotte — invecchia da sola. Il giorno che si sposta un muro nel `.json` e nessuno
## ricuoce, il bot cammina dentro il muro e non se ne accorge nessuno: è il motivo
## per cui accanto alla rete c'è l'impronta della pianta da cui è nata.
func _la_rete_di_cammino(pianta: Dictionary) -> void:
	_conta("la rete di cammino esiste", ResourceLoader.exists(RETE), RETE)

	var scheda := {}
	if FileAccess.file_exists(IMPRONTA):
		var letto: Variant = JSON.parse_string(FileAccess.get_file_as_string(IMPRONTA))
		if letto is Dictionary:
			scheda = letto as Dictionary
	_conta("la rete è cotta dalla pianta di oggi",
			String(scheda.get("impronta", "")) == FileAccess.get_sha256(PIANTA),
			"la pianta è cambiata dopo la cottura: rilancia tools/cuoci_percorsi.gd")

	var mappa: RID = _arena.get_world_3d().navigation_map
	await physics_frame
	NavigationServer3D.map_force_update(mappa)
	_conta("l'arena carica la rete davvero",
			not NavigationServer3D.map_get_regions(mappa).is_empty(),
			"nessuna regione di navigazione nella scena")

	# Da ogni partenza si arriva a tutte le altre. Se una coppia non si parla,
	# quella è la partenza da cui il bot non ti raggiungerà mai — e in partita si
	# vedrebbe come un avversario che non arriva, non come un errore.
	var rotte_rotte: Array[String] = []
	var partenze: Array = pianta["partenze"]
	for i in partenze.size():
		for j in partenze.size():
			if i == j:
				continue
			var da := _dove(partenze[i]["dove"], float(partenze[i]["quota"]) + 0.4)
			var a := _dove(partenze[j]["dove"], float(partenze[j]["quota"]) + 0.4)
			if not _ci_si_arriva(mappa, da, a):
				rotte_rotte.append("«%s» → «%s»" % [partenze[i]["nome"], partenze[j]["nome"]])
	_conta("da ogni partenza si arriva a tutte le altre", rotte_rotte.is_empty(),
			"%d rotte rotte: %s" % [rotte_rotte.size(), ", ".join(rotte_rotte)])

	# Le zone che hanno un nome sono i posti di cui si dice «sono nell'ocra»: se una
	# non si raggiunge a piedi, è una stanza che esiste solo per il giocatore.
	# **Si elencano tutte**, non la prima: aggiustarne una alla volta vuol dire
	# rifare il giro una volta per ognuna.
	var isolate: Array[String] = []
	var casa := _dove(partenze[0]["dove"], float(partenze[0]["quota"]) + 0.4)
	for zona in pianta["zone"]:
		if not zona.has("etichetta"):
			continue
		if not _ci_si_arriva(mappa, casa, _dove(zona["etichetta"], float(zona["quota"]) + 0.4)):
			isolate.append(String(zona["nome"]))
	_conta("tutte le zone con un nome si raggiungono a piedi", isolate.is_empty(),
			", ".join(isolate))

	# La controprova, che è quella che rende vere le due prove qui sopra: un punto
	# fuori dall'arena **non** deve risultare raggiungibile. Se lo risultasse,
	# vorrebbe dire che questa misura dice sempre di sì (LEARNED.md § 19).
	_conta("fuori dall'arena non ci si arriva",
			not _ci_si_arriva(mappa, casa, Vector3(0, 0.4, 58.0)),
			"la prova del percorso passa anche dove non c'è pavimento")


# ------------------------------------------------------------------ il disegno

## **Da ogni partenza esiste un colpo a uno o due muri che arriva dove non vedi.**
##
## È l'unico controllo che misura il **disegno** invece del codice, ed è la
## promessa della tappa: se da una partenza non esiste nessun tiro di sponda che
## porti il dardo in un punto fuori vista, quella zona non è un campo da gioco per
## questo gioco — è un corridoio con un neon addosso, e il rimbalzo lì non serve a
## niente.
##
## Si cerca come cerca un giocatore: ventaglio di direzioni attorno a sé, qualche
## alzo, e il **risolutore vero** — la stessa funzione che gli disegna la linea di
## mira. Non una geometria scritta apposta per la prova.
func _il_disegno_paga_il_rimbalzo(pianta: Dictionary) -> void:
	var spazio: PhysicsDirectSpaceState3D = _arena.get_world_3d().direct_space_state
	var giocatore: Giocatore = _arena.call("giocatore")
	var esclusi: Array[RID] = [giocatore.get_rid()]
	var senza: Array[String] = []
	for p in pianta["partenze"]:
		var occhi := _dove(p["dove"], float(p["quota"]) + Giocatore.ALTEZZA_OCCHI)
		if _colpo_di_sponda_al_coperto(spazio, occhi, esclusi) == Vector3.ZERO:
			senza.append(String(p["nome"]))
	_conta("da ogni partenza esiste il colpo di sponda verso un punto non in vista",
			senza.is_empty(), ", ".join(senza))

	# **La controprova** (LEARNED.md § 19), e va fatta o questa misura non vale
	# niente: si spengono le sponde — le stesse superfici, sullo strato che assorbe
	# invece di riflettere — e da quella stessa partenza il colpo non deve più
	# esistere. Se esistesse lo stesso, a trovarlo non erano le sponde ma un
	# artefatto del conto.
	var sponde := get_nodes_in_group(Muratura.GRUPPO_SPONDE)
	for sponda in sponde:
		(sponda as CollisionObject3D).collision_layer = Strati.OSTACOLO
	var casa := _dove(pianta["partenze"][0]["dove"],
			float(pianta["partenze"][0]["quota"]) + Giocatore.ALTEZZA_OCCHI)
	var senza_sponde := _colpo_di_sponda_al_coperto(spazio, casa, esclusi)
	for sponda in sponde:
		(sponda as CollisionObject3D).collision_layer = Strati.MONDO
	_conta("e spente le sponde non esiste più", senza_sponde == Vector3.ZERO,
			"lo trova lo stesso: non erano le sponde a farlo")


## Cerca un colpo che, dopo uno o due muri, finisca in un punto che da lì non si
## vede. Restituisce il punto trovato, o zero se non esiste.
func _colpo_di_sponda_al_coperto(spazio: PhysicsDirectSpaceState3D, occhi: Vector3,
		esclusi: Array[RID], lontananza := 8.0) -> Vector3:
	for giro in 144:
		for alzo in [-16.0, -10.0, -5.0, 0.0, 6.0, 14.0]:
			var verso := Vector3.FORWARD.rotated(Vector3.RIGHT, deg_to_rad(alzo)) \
					.rotated(Vector3.UP, deg_to_rad(giro * 2.5))
			var tratti := Balistica.traiettoria(spazio, occhi, verso,
					Balistica.PORTATA_MIRA, 2, esclusi)
			# Meno di due tratti vuol dire nessun rimbalzo: quello è un tiro
			# diretto, e i tiri diretti li sa fare anche un corridoio.
			if tratti.size() < 2:
				continue
			var ultimo: Balistica.Tratto = tratti[-1]
			# Il dardo deve finire **su qualcosa**: un tratto che si perde nel
			# vuoto arriva a centoquaranta metri, cioè fuori dall'arena.
			if ultimo.corpo == null:
				continue
			# Staccato dalla parete, o il raggio di controllo ricolpisce lei.
			var arrivo: Vector3 = ultimo.a + (ultimo.da - ultimo.a).normalized() * 0.4
			if occhi.distance_to(arrivo) < lontananza:
				continue
			var domanda := PhysicsRayQueryParameters3D.create(occhi, arrivo,
					Strati.TIRO, esclusi)
			if not spazio.intersect_ray(domanda).is_empty():
				return arrivo
	return Vector3.ZERO


## Ci si arriva a piedi? Non basta che il motore risponda: la risposta va guardata
## in fondo, perché una strada verso un posto irraggiungibile finisce dove capita.
func _ci_si_arriva(mappa: RID, da: Vector3, a: Vector3, tolleranza := ARRIVO) -> bool:
	var strada := NavigationServer3D.map_get_path(mappa, da, a, true)
	if strada.is_empty():
		return false
	return strada[-1].distance_to(a) <= tolleranza


## La prova che il piano chiede per davvero: **l'avversario ti raggiunge da
## qualunque angolo**. Le altre guardano la rete; questa guarda un corpo che
## cammina, con la fisica accesa e i secondi veri.
##
## La sfida resta spenta apposta: acceso il duello, un colpo preso teletrasporta
## chi lo prende, e la misura finirebbe per misurare la ricomparsa.
func _lavversario_ti_raggiunge(pianta: Dictionary) -> void:
	var giocatore: Giocatore = _arena.call("giocatore")
	var partenze: Array = pianta["partenze"]
	# Tre traversate, scelte per essere le più scomode: la diagonale intera, il
	# ballatoio (sette metri più in alto, e ci si sale solo dalle terrazze) e il
	# fondo del corridoio del mattone.
	for coppia in [[0, 3], [4, 5], [2, 0]]:
		var casa: int = coppia[0]
		var lontano: int = coppia[1]
		giocatore.global_position = _dove(partenze[casa]["dove"],
				float(partenze[casa]["quota"]) + 0.4)
		giocatore.velocity = Vector3.ZERO
		var bot := Avversario.crea(_arena, _dove(partenze[lontano]["dove"],
				float(partenze[lontano]["quota"]) + 0.4), 1)
		bot.bersaglio = giocatore

		var partito := Time.get_ticks_msec()
		var arrivato := false
		var lontananza := bot.global_position.distance_to(giocatore.global_position)
		while Time.get_ticks_msec() - partito < PAZIENZA_MS:
			await physics_frame
			if bot.global_position.distance_to(giocatore.global_position) <= Avversario.DISTANZA_MASSIMA:
				arrivato = true
				break
		var quanto := (Time.get_ticks_msec() - partito) / 1000.0
		_conta("da «%s» ti raggiunge a «%s»" % [partenze[lontano]["nome"], partenze[casa]["nome"]],
				arrivato, "partito da %.0f m, dopo %.0f s è ancora a %.0f m" % [lontananza,
				quanto, bot.global_position.distance_to(giocatore.global_position)])
		if arrivato:
			print("       (%.0f m in %.1f s)" % [lontananza, quanto])
		bot.bersaglio = null
		bot.queue_free()
		await process_frame


# ------------------------------------------------------------------ la partita

## Il duello a 500 dentro l'arena: chi entra, dove nasce, e cosa succede a chi
## viene colpito.
func _la_partita() -> void:
	var giocatore: Giocatore = _arena.call("giocatore")
	_arena.call("avvia_sfida")
	await process_frame
	var bot: Avversario = _arena.call("avversario")
	_conta("la sfida fa entrare l'avversario", bot != null)
	if bot == null:
		return

	_conta("chi comincia non nasce in faccia all'altro",
			not _si_vedono(giocatore, bot),
			"le due partenze si guardano: %.0f m" %
			giocatore.global_position.distance_to(bot.global_position))

	# La ricomparsa: chi viene centrato ricompare da un'altra parte, e mai in vista
	# di chi l'ha appena preso. È la regola del 1999 (§ 2 della ricerca), ed è il
	# motivo per cui in un'arena da sessantasei metri le partenze sono sei.
	# L'immunità dura otto decimi di secondo dopo un colpo incassato, e nella
	# misura di prima il bot gli ha sparato addosso: senza aspettare che scada,
	# questo colpo non vale, la ricomparsa non parte e la prova fallisce **per il
	# motivo sbagliato** (LEARNED.md § 16).
	var attesa := Time.get_ticks_msec()
	while giocatore.immune() and Time.get_ticks_msec() - attesa < 2000:
		await physics_frame
	var prima := giocatore.global_position
	_conta("il colpo di prova conta davvero", giocatore.incassa(0, bot),
			"il giocatore era ancora immune")
	await process_frame
	await process_frame
	var spostato := giocatore.global_position.distance_to(prima)
	_conta("chi viene colpito ricompare da un'altra parte", spostato > 8.0,
			"si è spostato di %.1f m" % spostato)
	_conta("e non ricompare in faccia a chi l'ha preso", not _si_vedono(giocatore, bot))

	# Un colpo a cinque muri vale 800: sopra il traguardo, quindi la partita
	# finisce. Il segno visibile è che l'avversario smette di giocare.
	bot.incassa(5, giocatore)
	await process_frame
	await process_frame
	var punti: Array = _arena.call("punteggi")
	_conta("un colpo a cinque muri vale 800 punti", int(punti[0]) == 800, str(punti))
	_conta("a 500 la partita finisce", bot.bersaglio == null,
			"l'avversario gioca ancora")

	_arena.call("chiudi_sfida")
	await process_frame
	_conta("chiusa la sfida, l'arena torna quella di prima",
			not bool(_arena.call("in_sfida")) and _arena.call("avversario") == null)


## Si vedono? Lo stesso raggio con cui l'avversario decide se ha la linea libera.
func _si_vedono(uno: Node3D, altro: Node3D) -> bool:
	var da := uno.global_position + Vector3(0, Avversario.ALTEZZA_PETTO, 0)
	var a := altro.global_position + Vector3(0, Avversario.ALTEZZA_PETTO, 0)
	var domanda := PhysicsRayQueryParameters3D.create(da, a, Strati.SOLIDO)
	return _arena.get_world_3d().direct_space_state.intersect_ray(domanda).is_empty()


func _nessuna_in_comune(a: Array, b: Array) -> bool:
	for uno in a:
		if b.has(uno):
			return false
	return true


# ------------------------------------------------------------------ esito

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
