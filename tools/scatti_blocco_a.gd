extends SceneTree

## Attrezzo di lavorazione: **l'immagine del blocco A della tappa 14** — una schermata
## vera dello scontro nel PARCO GONFIABILE, da mettere accanto alla pubblicità di
## riferimento. La partita gira davvero; dopo qualche secondo chi gioca si mette nel
## posto scelto, con tre avversari davanti e la tribuna dietro di loro, e tira al più
## centrale: lo scatto parte quando la stella del colpo è aperta.
##   godot --path . --resolution 854x390 --fixed-fps 30 -s tools/scatti_blocco_a.gd -- [scala] [prova]
## `scala` è la scala della scena (0.65 quella del telefono di oggi, 1.0 piena). Con
## `prova` fotografa solo le inquadrature candidate, senza comporre.
## Gli scatti escono in `scatti/` come `A14-<scala>.png` (e `A14-prova-<n>.png`).
## Con `schiene`, `sequenza <nome>`, `presa <nome>`, `lampo <nome>`, `dondolio <nome>`,
## `parola <nome>`, `doppio <nome>` e `podio <nome> [secondo]` al posto di `prova` fa le serie di fotogrammi
## dei blocchi C, D, E e F (`S14-<nome>-…-NN.png`): si mettono in striscia con
## `tools/striscia.py`.

const CARTELLA := "res://scatti"

## Le inquadrature: dove sta chi gioca, verso dove guarda (gradi, 0 = nord, 90 = ovest),
## e gli avversari in metri davanti (primo numero) e a destra (secondo) di chi gioca.
## Il primo avversario è quello a cui si tira. La prima inquadratura è quella dello scatto;
## le altre servono con `prova`, per sceglierla guardando.
const INQUADRATURE := [
	{"posto": Vector3(-18.5, 0.0, -11.0), "giro": 50.0,
			"avversari": [Vector2(6.0, -3.4), Vector2(7.8, -7.6), Vector2(3.4, 4.6), Vector2(12.0, 3.0)]},
	{"posto": Vector3(-18.5, 0.0, -11.0), "giro": 60.0,
			"avversari": [Vector2(8.0, 1.6), Vector2(6.0, -3.4), Vector2(11.5, 5.0)]},
	{"posto": Vector3(-20.0, 0.0, -8.0), "giro": 55.0,
			"avversari": [Vector2(8.0, 1.2), Vector2(6.5, -3.6), Vector2(11.0, 4.5)]},
	{"posto": Vector3(-19.0, 0.0, -6.0), "giro": 62.0,
			"avversari": [Vector2(8.0, 1.5), Vector2(6.0, -3.5), Vector2(12.0, 4.5)]},
	{"posto": Vector3(-21.0, 0.0, -12.0), "giro": 45.0,
			"avversari": [Vector2(7.5, 1.4), Vector2(6.0, -3.4), Vector2(10.5, 4.5)]},
	{"posto": Vector3(-18.5, 0.0, -11.0), "giro": 68.0,
			"avversari": [Vector2(8.0, 1.6), Vector2(6.0, -3.4), Vector2(11.5, 5.0)]},
]
## La pendenza della visuale di chi corre: il personaggio si vede intero.
const PENDENZA := -11.0
## Secondi di partita prima di comporre: la classifica e il tabellone hanno dei punti.
const PARTITA := 14.0

var _messi: Array[Node3D] = []
var _posti: Array[Vector3] = []
var _disarmati := false


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var scala := float(argomenti[0]) if argomenti.size() > 0 else 0.65
	var prova := argomenti.size() > 1 and argomenti[1] == "prova"
	var di_prima := Aspetto.scelta()
	Aspetto.scegli(Aspetto.GONFIABILE)
	DirAccess.make_dir_recursive_absolute(CARTELLA)
	Arena.modo_partita = true
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = scala
	# L'arena nasce a passi: prima che ci sia chi gioca il conto alla rovescia è già zero.
	var scadenza := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < scadenza and arena.call("giocatore") == null:
		await process_frame
	await _riposa(20)
	while Time.get_ticks_msec() < scadenza and float(arena.call("conto_alla_rovescia")) > 0.0:
		await process_frame
	var giocatore: Giocatore = arena.call("giocatore")
	if argomenti.size() > 1 and argomenti[1] == "schiene":
		await _schiene(arena, giocatore)
		Aspetto.scegli(di_prima)
		quit()
		return
	await _riposa(int(PARTITA * 30.0))
	if argomenti.size() > 1 and argomenti[1] == "presa":
		await _presa(arena, giocatore, argomenti[2] if argomenti.size() > 2 else "dopo")
		Aspetto.scegli(di_prima)
		quit()
		return
	if argomenti.size() > 1 and argomenti[1] == "sequenza":
		await _sequenza(arena, giocatore, argomenti[2] if argomenti.size() > 2 else "dopo")
		Aspetto.scegli(di_prima)
		quit()
		return
	if argomenti.size() > 1 and argomenti[1] in ["parola", "doppio", "podio", "dondolio", "lampo"]:
		var nome: String = argomenti[2] if argomenti.size() > 2 else "dopo"
		match argomenti[1]:
			"parola": await _parola(arena, giocatore, nome)
			"doppio": await _doppio(arena, giocatore, nome)
			"dondolio": await _dondolio(arena, giocatore, nome)
			"lampo": await _lampo(arena, giocatore, nome)
			"podio": await _podio(arena, nome, argomenti.size() > 3 and argomenti[3] == "secondo")
		Aspetto.scegli(di_prima)
		quit()
		return
	if prova:
		for i in INQUADRATURE.size():
			_disponi(arena, giocatore, INQUADRATURE[i])
			await _fermi(12)
			giocatore.set("_immunita", 0.0)
			await _fermi(2)
			await _scatta("A14-prova-%d.png" % i)
	else:
		var fatto := false
		for tentativo in 4:
			if await _componi(arena, giocatore, INQUADRATURE[0]):
				await _scatta("A14-%s.png" % str(scala).replace(".", ""))
				fatto = true
				break
			await _riposa(45)
		print("blocco A: %s, scala %.2f" % ["scatto fatto" if fatto else "NESSUN COLPO A SEGNO", scala])
	Aspetto.scegli(di_prima)
	quit()


## **I sei di schiena** (tappa 14, blocco C): i cinque avversari in fila a dodici metri,
## girati come chi gioca, e poi a trenta. A dodici si deve dire chi è chi senza leggere i
## nomi; a trenta nome e anello si devono ancora vedere. La partita si ferma: gli scatti
## vogliono i corpi dove li si mette.
func _schiene(arena: Node, giocatore: Giocatore) -> void:
	await _riposa(20)
	arena.set("_finita", true)
	var avversari: Array = arena.call("avversari")
	# Fermi davvero: senza la loro fisica non si girano a guardare chi gioca.
	for bot in avversari:
		(bot as Node).set_physics_process(false)
	# A dodici metri tutti e cinque, a due metri e mezzo l'uno dall'altro, sul tratto
	# libero davanti alla tribuna; a trenta solo tre, più larghi, perché i nomi hanno
	# misura fissa sullo schermo e si coprirebbero. Trenta metri liberi nell'arena non ci
	# sono: per quello scatto si spengono gli oggetti in campo (solo alla vista).
	for prova in [[12.0, 5, 2.4, Vector3(-18.5, 0.0, -11.0), 85.0],
			[30.0, 3, 4.4, Vector3(-21.0, 0.0, 12.0), 0.0]]:
		var lontano := float(prova[0])
		var quanti := int(prova[1])
		var posto: Vector3 = prova[3]
		var giro := float(prova[4])
		var avanti := Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(giro))
		var destra := Vector3(1, 0, 0).rotated(Vector3.UP, deg_to_rad(giro))
		var oggetti := arena.get_node_or_null("oggetti_gonfiabili") as Node3D
		if oggetti != null:
			oggetti.visible = lontano < 20.0
		for f in 24:
			giocatore.global_position = posto
			giocatore.velocity = Vector3.ZERO
			giocatore.punta(giro, -9.0)
			giocatore.set("_immunita", 0.0)
			for i in avversari.size():
				var bot := avversari[i] as Avversario
				bot.set("_immunita", 0.0)
				bot.velocity = Vector3.ZERO
				bot.rotation.y = deg_to_rad(giro)
				if i < quanti:
					bot.global_position = posto + avanti * lontano 							+ destra * (-0.6 + float(prova[2]) * (float(i) - float(quanti - 1) * 0.5))
				else:
					bot.global_position = Vector3(30.0, 0.0, 20.0 + 3.0 * float(i))
			await process_frame
		await _scatta("C14-schiene-%dm.png" % int(lontano))


## **Le sequenze** (tappa 14, blocchi E e F): il movimento si guarda in movimento, su
## fotogrammi di fila e non su uno solo (`LEARNED.md` § 75). Due serie, nella stessa
## inquadratura dello scatto: il colpo (quattordici fotogrammi di fila dallo sparo: lampo
## alla canna, scia, stella, punti, scatto della camera, anello della ricarica) e il
## dopo (dieci fotogrammi, uno ogni due: il pubblico che salta, festoni e palloni).
## Escono come `S14-<nome>-colpo-NN.png` e `S14-<nome>-tifo-NN.png`.
func _sequenza(arena: Node, giocatore: Giocatore, nome: String) -> void:
	var quadro: Dictionary = INQUADRATURE[0]
	_disarmati = true
	_disponi(arena, giocatore, quadro)
	await _fermi(20)
	giocatore.set("_immunita", 0.0)
	for colpo in 8:
		var prima := _punti_miei(arena)
		var mira := _posti[0] + Vector3.UP * 1.0 - (giocatore.global_position + Vector3.UP * 1.6)
		var lontano := Vector2(mira.x, mira.z).length()
		var spalla := rad_to_deg(atan2(Giocatore.SPALLA_TERZA, lontano + Giocatore.BRACCIO_TERZA))
		var scarto := 1.5 * float((colpo + 1) / 2) * (1.0 if colpo % 2 == 0 else -1.0)
		giocatore.punta(rad_to_deg(atan2(-mira.x, -mira.z)) + spalla + scarto,
				rad_to_deg(atan2(mira.y, lontano)) - 2.0)
		await _fermi(3)
		giocatore.spara()
		var fotogrammi: Array[Image] = []
		var a_segno := false
		for i in 14:
			await _fermi(1)
			await RenderingServer.frame_post_draw
			fotogrammi.append(root.get_texture().get_image())
			if _punti_miei(arena) == prima + 25:
				a_segno = true
		if not a_segno:
			continue
		for i in fotogrammi.size():
			fotogrammi[i].save_png("%s/S14-%s-colpo-%02d.png" % [CARTELLA, nome, i])
		_messi.remove_at(0)
		_posti.remove_at(0)
		giocatore.punta(float(quadro["giro"]), PENDENZA)
		for i in 10:
			await _fermi(2)
			await _scatta("S14-%s-tifo-%02d.png" % [nome, i])
		print("sequenza %s: fatta" % nome)
		return
	print("sequenza %s: NESSUN COLPO A SEGNO" % nome)


## **Il sorpasso** (tappa 14, blocco F): chi gioca è secondo a dieci punti dal primo, e il
## colpo a segno lo porta in testa. È il caso vero: «SEI PRIMO!» arriva insieme al
## «+25 · DIRETTO». Venticinque fotogrammi, uno ogni due (un secondo e sei decimi).
func _parola(arena: Node, giocatore: Giocatore, nome: String) -> void:
	var quadro: Dictionary = INQUADRATURE[0]
	_disarmati = true
	_disponi(arena, giocatore, quadro)
	await _fermi(20)
	giocatore.set("_immunita", 0.0)
	for colpo in 8:
		var righe: Array = arena.get("_concorrenti")
		for i in righe.size():
			righe[i]["punti"] = [50, 60, 40, 30, 20, 10][i]
		arena.set("_posizione_annunciata", 2)
		arena.set("_attesa_annuncio", 0.0)
		arena.call("_aggiorna_la_classifica")
		var mira := _posti[0] + Vector3.UP * 1.0 - (giocatore.global_position + Vector3.UP * 1.6)
		var lontano := Vector2(mira.x, mira.z).length()
		var spalla := rad_to_deg(atan2(Giocatore.SPALLA_TERZA, lontano + Giocatore.BRACCIO_TERZA))
		var scarto := 1.5 * float((colpo + 1) / 2) * (1.0 if colpo % 2 == 0 else -1.0)
		giocatore.punta(rad_to_deg(atan2(-mira.x, -mira.z)) + spalla + scarto,
				rad_to_deg(atan2(mira.y, lontano)) - 2.0)
		await _fermi(3)
		giocatore.spara()
		var fotogrammi: Array[Image] = []
		var a_segno := false
		for i in 50:
			await _fermi(1)
			await RenderingServer.frame_post_draw
			if i % 2 == 0:
				fotogrammi.append(root.get_texture().get_image())
			if not a_segno and _punti_miei(arena) == 75:
				a_segno = true
				_messi.remove_at(0)
				_posti.remove_at(0)
		if not a_segno:
			continue
		for i in fotogrammi.size():
			fotogrammi[i].save_png("%s/S14-%s-parola-%02d.png" % [CARTELLA, nome, i])
		print("parola %s: fatta" % nome)
		return
	print("parola %s: NESSUN COLPO A SEGNO" % nome)


## **I punti doppi presi da te** (tappa 14, blocco F): chi gioca passa sulla sfera dei
## punti doppi. Trenta fotogrammi, uno ogni due o tre: la parola, e poi la pillola.
func _doppio(arena: Node, giocatore: Giocatore, nome: String) -> void:
	for bot in arena.call("avversari"):
		(bot as Node3D).global_position = Vector3(30.0, 0.0, 20.0)
		(bot as Node).set_physics_process(false)
	var potenziamenti: Node = arena.get("_potenziamenti")
	for s: Dictionary in potenziamenti.get("_sfere"):
		if String(s["tipo"]) != "doppio":
			continue
		s["attesa"] = 0.0
		var dove: Vector3 = s["dove"]
		var guarda := dove + Vector3(0, 0, 4.5)
		giocatore.global_position = guarda
		giocatore.velocity = Vector3.ZERO
		giocatore.punta(0.0, PENDENZA)
		giocatore.set("_immunita", 0.0)
		await _riposa(8)
		giocatore.global_position = dove
		await physics_frame
		await physics_frame
		giocatore.global_position = guarda
		giocatore.velocity = Vector3.ZERO
		for i in 60:
			await process_frame
			if i % 2 == 0:
				await _scatta("S14-%s-doppio-%02d.png" % [nome, i / 2])
		print("doppio %s: sfera in %s" % [nome, dove])
		return
	print("doppio %s: LA SFERA NON C'È" % nome)


## **Il lampo alla canna, visto da chi gioca** (tappa 14, blocco E). Il proprio non si vede:
## coi corpi a cartone la testa di chi gioca copre il blaster dalla camera sopra la spalla
## (visto nella serie del colpo, 15/11/2026). Si vede quello degli avversari: qui il primo
## avversario dell'inquadratura si gira verso chi gioca e gli si accende il lampo dello
## sparo, senza dardo. Sei fotogrammi di fila.
func _lampo(arena: Node, giocatore: Giocatore, nome: String) -> void:
	_disarmati = true
	_disponi(arena, giocatore, INQUADRATURE[0])
	var bot := _messi[0] as Avversario
	# Fermo e girato a mano verso chi gioca: con la caccia accesa non sa dov'è, e gli
	# mostrerebbe la schiena. Il corpo si mette in posa col braccio teso.
	bot.set_physics_process(false)
	var verso := giocatore.global_position - _posti[0]
	bot.rotation.y = atan2(-verso.x, -verso.z)
	for i in 30:
		bot.corpo().aggiorna(Vector3.ZERO, true, 0.0, 1.0 / 30.0)
		await _fermi(1)
	giocatore.set("_immunita", 0.0)
	await _fermi(2)
	# Il lampo dura sei centesimi: a trenta fotogrammi al secondo è il fotogramma stesso
	# dello sparo. Si fotografa quello, senza aspettarne un altro.
	bot.corpo().spara()
	for i in 6:
		await _scatta("S14-%s-lampo-%02d.png" % [nome, i])
		await _fermi(1)
	# E quello di chi gioca, dallo stesso posto: quattro fotogrammi dal colpo.
	giocatore.set("_ricarica", 0.0)
	giocatore.spara()
	for i in 4:
		await _scatta("S14-%s-lampotuo-%02d.png" % [nome, i])
		await _fermi(1)
	print("lampo %s: fatto" % nome)


## **Quello che dondola** (tappa 14, blocco D): i palloni appesi, visti dal ballatoio
## (dieci fotogrammi, uno ogni dodici: tre secondi e mezzo, mezzo giro della loro
## oscillazione), e i festoni in cima alla tribuna, visti dal posto dello scatto (dieci
## fotogrammi, uno ogni sei). Gli avversari stanno fermi dall'altra parte dell'arena.
func _dondolio(arena: Node, giocatore: Giocatore, nome: String) -> void:
	for bot in arena.call("avversari"):
		(bot as Node3D).global_position = Vector3(30.0, 0.0, 20.0)
		(bot as Node).set_physics_process(false)
	for serie in [["palloni", Vector3(7.25, 7.0, 30.5), 0.0, 5.0, 12],
			["festoni", (INQUADRATURE[0] as Dictionary)["posto"], 62.0, 3.0, 6]]:
		for i in 10:
			for f in int(serie[4]):
				giocatore.global_position = serie[1]
				giocatore.velocity = Vector3.ZERO
				giocatore.punta(float(serie[2]), float(serie[3]))
				giocatore.set("_immunita", 0.0)
				await process_frame
			await _scatta("S14-%s-%s-%02d.png" % [nome, serie[0], i])
	print("dondolio %s: fatto" % nome)


## **La fine della partita** (tappa 14, blocco F): chi gioca primo (o secondo, con
## `secondo`), il tempo scade e si fotografa un fotogramma ogni quattro per cinque secondi
## — la festa del podio e poi il riquadro con RIGIOCA.
func _podio(arena: Node, nome: String, secondo: bool) -> void:
	var righe: Array = arena.get("_concorrenti")
	for i in righe.size():
		righe[i]["punti"] = ([300, 325, 250, 150, 100, 50] if secondo
				else [325, 300, 250, 150, 100, 50])[i]
	arena.call("_aggiorna_la_classifica")
	await _riposa(6)
	await _scatta("S14-%s-podio-00.png" % nome)
	arena.call("_finisci_la_partita")
	for i in range(1, 38):
		await _riposa(3)
		await _scatta("S14-%s-podio-%02d.png" % [nome, i])
	print("podio %s: fatto" % nome)


## **La presa di un potenziamento**, dieci fotogrammi di fila: chi gioca si mette a tre
## metri dalla prima sfera accesa e ci corre dentro. Escono come `S14-<nome>-presa-NN.png`.
func _presa(arena: Node, giocatore: Giocatore, nome: String) -> void:
	for bot in arena.call("avversari"):
		(bot as Node3D).global_position = Vector3(30.0, 0.0, 20.0)
		(bot as Node).set_physics_process(false)
	var potenziamenti: Node = arena.get("_potenziamenti")
	for s: Dictionary in potenziamenti.get("_sfere"):
		if float(s["attesa"]) > 0.0:
			continue
		var dove: Vector3 = s["dove"]
		var guarda := dove + Vector3(0, 0, 4.5)
		giocatore.global_position = guarda
		giocatore.velocity = Vector3.ZERO
		giocatore.punta(0.0, PENDENZA)
		giocatore.set("_immunita", 0.0)
		await _riposa(6)
		await _scatta("S14-%s-presa-00.png" % nome)
		# Ci passa sopra per un giro di fisica, e torna a guardare da quattro metri.
		giocatore.global_position = dove
		await physics_frame
		await physics_frame
		giocatore.global_position = guarda
		giocatore.velocity = Vector3.ZERO
		for i in range(1, 10):
			await process_frame
			await _scatta("S14-%s-presa-%02d.png" % [nome, i])
		print("presa %s: sfera %s in %s" % [nome, s["tipo"], dove])
		return


## Mette chi gioca e gli avversari al loro posto nell'inquadratura.
func _disponi(arena: Node, giocatore: Giocatore, quadro: Dictionary) -> void:
	var posto: Vector3 = quadro["posto"]
	var giro := float(quadro["giro"])
	var avanti := Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(giro))
	var destra := Vector3(1, 0, 0).rotated(Vector3.UP, deg_to_rad(giro))
	giocatore.global_position = posto
	giocatore.velocity = Vector3.ZERO
	giocatore.punta(giro, PENDENZA)
	# Mentre ci si dispone chi gioca non si può colpire: un colpo preso lo farebbe
	# ricomparire dall'altra parte dell'arena. La protezione si toglie prima dello scatto,
	# perché chi è protetto lampeggia.
	giocatore.proteggi(30.0)
	var avversari: Array = arena.call("avversari")
	var dove: Array = quadro["avversari"]
	_messi.clear()
	_posti.clear()
	for i in avversari.size():
		var bot := avversari[i] as Node3D
		if i < dove.size():
			_messi.append(bot)
			_posti.append(posto + avanti * (dove[i] as Vector2).x + destra * (dove[i] as Vector2).y)
		else:
			# Gli altri lontano, dall'altra parte dell'arena: fuori dall'inquadratura.
			bot.global_position = Vector3(30.0, 0.0, 20.0 + 3.0 * float(i))


## Lascia passare dei fotogrammi tenendo gli avversari dell'inquadratura al loro posto:
## la partita gira, e in mezzo secondo se ne andrebbero ognuno per la sua strada.
func _fermi(fotogrammi: int) -> void:
	for f in fotogrammi:
		for i in _messi.size():
			if is_instance_valid(_messi[i]):
				_messi[i].global_position = _posti[i]
				(_messi[i] as CharacterBody3D).velocity = Vector3.ZERO
				# Nelle sequenze gli avversari non tirano: chi gioca resta senza protezione
				# (protetto lampeggia), e un colpo preso lo porterebbe via.
				if _disarmati:
					_messi[i].set("_ricarica", 9.0)
		await process_frame


## Dispone tutti, tira al primo avversario e aspetta che il colpo vada a segno: lo scatto
## vale solo se i punti di chi gioca sono saliti (una stella può essere di un altro duello).
func _componi(arena: Node, giocatore: Giocatore, quadro: Dictionary) -> bool:
	_disponi(arena, giocatore, quadro)
	await _fermi(6)
	for colpo in 8:
		var prima := _punti_miei(arena)
		var mira := _posti[0] + Vector3.UP * 1.0 - (giocatore.global_position + Vector3.UP * 1.6)
		# La camera sta sopra la spalla destra, non dietro la testa: perché il mirino cada
		# sull'avversario ci si gira a sinistra di quell'angolo, e a ogni colpo mancato si
		# prova un grado e mezzo più in là, da una parte e dall'altra.
		var lontano := Vector2(mira.x, mira.z).length()
		var spalla := rad_to_deg(atan2(Giocatore.SPALLA_TERZA, lontano + Giocatore.BRACCIO_TERZA))
		var scarto := 1.5 * float((colpo + 1) / 2) * (1.0 if colpo % 2 == 0 else -1.0)
		giocatore.punta(rad_to_deg(atan2(-mira.x, -mira.z)) + spalla + scarto,
				rad_to_deg(atan2(mira.y, lontano)) - 2.0)
		await _fermi(2)
		giocatore.spara()
		for i in 16:
			await _fermi(1)
			# Solo il colpo diretto, 25 punti: un colpo di sponda che prende un altro non è
			# lo scatto che si vuole (il rimbalzo non è il soggetto, `DECISIONI.md` § 20).
			if _punti_miei(arena) == prima + 25:
				# Chi è stato colpito ricompare altrove: non lo si tiene più fermo. Il
				# pollice torna giù: la visuale di chi corre, col personaggio intero.
				_messi.remove_at(0)
				_posti.remove_at(0)
				giocatore.punta(float(quadro["giro"]), PENDENZA)
				giocatore.set("_immunita", 0.0)
				await _fermi(3)
				return true
	return false


func _punti_miei(arena: Node) -> int:
	for riga in arena.call("classifica"):
		if bool(riga["tu"]):
			return int(riga["punti"])
	return 0


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var immagine := root.get_texture().get_image()
	immagine.save_png(CARTELLA + "/" + nome)
