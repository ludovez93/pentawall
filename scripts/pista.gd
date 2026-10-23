class_name Pista
extends RefCounted

## **B, PISTA GIOCATTOLO** (tappa 11, blocco C2, 11/10/2026): l'arena aperta come un
## circuito giocattolo con le tribune (Fable, `ricerca-grezza/stato-2026-10-11/fable-c2.md`).
## Di GIOCATTOLO restano tappetini, rampe, cielo, canyon e dardi a terra; i muri imbottiti
## diventano roba da pista:
## - il perimetro (e le facce del catino) è il muretto dei box: bianco, cordolo rosso e
##   bianco al piede, cartelloni colorati sopra;
## - i muri alti dell'arena aperta (2,4 m) sono muri di gomme, una colonna rossa e una bianca;
## - i muretti bassi sono cordoli a blocchi rossi e bianchi;
## - le quattro torri sono portali col fregio a scacchi, colonne a strisce e bandiere;
## - pilastri e colonne a strisce, con la bandierina in cima;
## - i blocchi sono cassoni nel colore dell'ala, col fregio a scacchi;
## - fuori dal perimetro, le tribune col pubblico;
## - in campo macchinine, pile di gomme, cartelloni, coni, bandiere e pali della luce.
## Tutto in codice, nel getto di GIOCATTOLO: un materiale solo, colori sui vertici.

const ROSSO := Color(0.90, 0.16, 0.18)
const BIANCO := Color(0.95, 0.95, 0.96)
const NERO := Color(0.10, 0.10, 0.13)
const BLU := Color(0.14, 0.32, 0.88)
const GIALLO := Color(1.0, 0.80, 0.14)
const VIOLA := Color(0.52, 0.30, 0.90)
const VERDE := Color(0.16, 0.62, 0.36)
const GOMMA := Color(0.17, 0.17, 0.20)
const CARTELLONI := [ROSSO, GIALLO, BLU, VIOLA]
const MACCHINE := [ROSSO, BLU, GIALLO, VIOLA, VERDE]
const PELLI := [Color(1.0, 0.80, 0.62), Color(0.86, 0.62, 0.44), Color(0.60, 0.40, 0.26),
		Color(0.98, 0.86, 0.72)]

## Il colore dei cassoni, dall'ala come in GIOCATTOLO.
const CASSONI := {"ocra": GIALLO, "tribuna": BLU, "mattone": ROSSO, "moquette": VIOLA}

const OGGETTI := 70
const SEME := 2211

## La gomma: diametro 92 centimetri, alta 48.
const GOMMA_RAGGIO := 0.46
const GOMMA_ALTA := 0.48


static func veste(arena: Arena) -> void:
	var materiale := Giocattolo._materiale_dei_moduli()
	Apertura.veste(arena, materiale)
	await _muri(arena, materiale)
	_tribune(arena, materiale)
	await arena._respiro()
	_oggetti(arena, materiale)


# ------------------------------------------------------------------ i muri

static func _muri(arena: Arena, materiale: Material) -> void:
	var pianta := arena.pianta()
	var muri: Array = pianta["muri"]
	var getto := Giocattolo.Getto.new()
	var gomme := Giocattolo.Getto.new()
	var k := 0
	for corpo in Giocattolo._pareti(arena):
		for figlio in corpo.get_children():
			if figlio is MeshInstance3D:
				corpo.remove_child(figlio)
				figlio.queue_free()
		var m: Dictionary = muri[int(corpo.get_meta(&"muro"))]
		var nome := String(m.get("nome", ""))
		var lx := float(m["misura"][0])
		var lz := float(m["misura"][1])
		var alto := float(m["alto"])
		var posto := corpo.transform
		var coperto := Giocattolo._sotto_un_piano(arena, pianta, m, posto)
		var cima := alto - (Giocattolo.SOTTO_IL_PIANO if coperto else 0.0)
		if Arena._e_tondo(nome) and absf(lx - lz) < 0.01:
			_colonna(getto, lx * 0.5, alto, cima, posto, not coperto and alto >= 5.0)
		elif nome in Apertura.TORRI:
			_portale(getto, lx, lz, alto, posto)
		elif nome.begins_with("perimetro") or nome.begins_with("parapetto sul perimetro") \
				or nome.begins_with("catino, faccia"):
			_muretto(getto, pianta, lx, lz, cima, posto)
		elif minf(lx, lz) >= 1.3:
			_cassone(getto, lx, lz, cima, posto, CASSONI.get(String(m.get("tinta", "")), BLU),
					coperto or _porta_una_sponda(pianta, posto, lx, lz))
		elif alto >= 2.0 and not coperto:
			_muro_di_gomme(gomme, lx, lz, alto, posto)
		else:
			_cordolo(getto, lx, lz, cima, posto)
		k += 1
		if k % 12 == 0:
			await arena._respiro()
	Giocattolo._posa(arena, getto.mesh(), materiale, "muri della pista")
	Giocattolo._posa(arena, gomme.mesh(), materiale, "muri di gomme")


static func _lungo(lx: float, lz: float) -> Vector3:
	return Vector3.RIGHT if lx >= lz else Vector3.BACK


## Il muretto dei box: corpo bianco, cordolo a blocchi rossi e bianchi al piede, fascia
## blu in cima, e sulle due facce cartelloni colorati con la riga bianca, dove non c'è una
## sponda (il ciano resta l'unica cosa accesa sul muro).
static func _muretto(getto: Giocattolo.Getto, pianta: Dictionary, lx: float, lz: float,
		alto: float, posto: Transform3D) -> void:
	var lungo := _lungo(lx, lz)
	var attraverso := Vector3.BACK if lungo == Vector3.RIGHT else Vector3.RIGHT
	var lunghezza := maxf(lx, lz)
	var spessore := minf(lx, lz)
	var sotto := -alto * 0.5
	# Agli angoli due muretti si incrociano: quello che corre da nord a sud cede di due
	# centimetri, in cima e al piede, o le facce in pari lampeggerebbero.
	var cede := 0.02 if lungo == Vector3.BACK else 0.0
	getto.scatola(Vector3(lx, alto - 0.02 - 2.0 * cede, lz), 0.05, BIANCO, posto * Giocattolo._su(0.0), 1, 0.15)
	# Il cordolo si stacca di tre centimetri dal pavimento: col fondo in pari col fondo del
	# muretto, le due facce di sotto stavano nello stesso piano.
	_a_blocchi(getto, lunghezza, lungo, attraverso, spessore + 0.08 - cede, 0.52, sotto + 0.30 + cede, posto, 1.2)
	getto.scatola(lungo * (lunghezza + 0.04) + attraverso * (spessore + 0.06 - cede) + Vector3.UP * 0.26,
			0.05, BLU, posto * Giocattolo._su(alto * 0.5 - 0.13 - cede), 1)
	if alto < 3.4:
		return
	var passo := 6.5
	var quanti := int(floor(lunghezza / passo))
	for lato in [-1.0, 1.0]:
		var fuori: Vector3 = attraverso * lato
		for i in quanti:
			var t := -lunghezza * 0.5 + passo * (float(i) + 0.5) + (lunghezza - passo * quanti) * 0.5
			# Il cartellone sporge cinque centimetri, la riga bianca mezzo di più: oltre i sei la
			# vista starebbe davanti alla collisione (`prova_aspetto`).
			var centro := lungo * t + fuori * (spessore * 0.5 + 0.02) + Vector3.UP * (sotto + 2.35)
			var mondo := posto * centro
			if Giocattolo._sponda_vicina(pianta, mondo, (posto.basis * fuori).normalized(), 3.2):
				continue
			var tinta: Color = CARTELLONI[(i + (1 if lato > 0.0 else 0)) % CARTELLONI.size()]
			getto.scatola(lungo * 4.6 + fuori.abs() * 0.06 + Vector3.UP * 1.5, 0.02, tinta,
					posto * Transform3D(Basis(), centro), 1)
			getto.scatola(lungo * 4.0 + fuori.abs() * 0.07 + Vector3.UP * 0.2, 0.01, BIANCO,
					posto * Transform3D(Basis(), centro + Vector3.UP * 0.25), 1)


## Blocchi alternati rossi e bianchi lungo un muro, alti `alto`, centrati a `y`.
static func _a_blocchi(getto: Giocattolo.Getto, lunghezza: float, lungo: Vector3,
		attraverso: Vector3, spessore: float, alto: float, y: float, posto: Transform3D,
		passo: float) -> void:
	# Dispari: in mezzo al muro c'è un blocco e non una fessura.
	var quanti := maxi(1, roundi(lunghezza / passo))
	if quanti % 2 == 0:
		quanti += 1
	var pezzo := lunghezza / float(quanti)
	for i in quanti:
		var t := -lunghezza * 0.5 + pezzo * (float(i) + 0.5)
		getto.scatola(lungo * (pezzo - 0.03) + attraverso * spessore + Vector3.UP * alto, 0.08,
				ROSSO if i % 2 == 0 else BIANCO, posto * Transform3D(Basis(), lungo * t + Vector3.UP * y), 2)


## Un cordolo: tutto a blocchi rossi e bianchi.
static func _cordolo(getto: Giocattolo.Getto, lx: float, lz: float, alto: float,
		posto: Transform3D) -> void:
	var lungo := _lungo(lx, lz)
	var attraverso := Vector3.BACK if lungo == Vector3.RIGHT else Vector3.RIGHT
	# Un'anima scura tre centimetri dentro: fra un blocco e l'altro ci sono tre centimetri, e
	# senza anima ci passava un raggio.
	getto.scatola(Vector3(lx, alto, lz) - (lungo + attraverso) * 0.06 - Vector3.UP * 0.06, 0.02, GOMMA,
			posto * Giocattolo._su(0.0), 1)
	_a_blocchi(getto, maxf(lx, lz), lungo, attraverso, minf(lx, lz), alto - 0.035, -0.0075, posto, 1.0)


## Un muro di gomme: colonne di gomme, una rossa e una bianca, su un'anima scura che non
## lascia vedere attraverso.
static func _muro_di_gomme(gomme: Giocattolo.Getto, lx: float, lz: float, alto: float,
		posto: Transform3D) -> void:
	var lungo := _lungo(lx, lz)
	var lunghezza := maxf(lx, lz)
	var spessore := minf(lx, lz)
	gomme.scatola(Vector3(lx, alto, lz) - (lungo * 0.1 + (Vector3.ONE - lungo - Vector3.UP) * 0.3) * 2.0
			+ Vector3.DOWN * 0.04, 0.05, GOMMA, posto * Giocattolo._su(-0.02), 1)
	var colonne := maxi(1, int(floor(lunghezza / (GOMMA_RAGGIO * 2.0))))
	var passo := lunghezza / float(colonne)
	var piani := maxi(1, int(floor(alto / GOMMA_ALTA)))
	var raggio := minf(GOMMA_RAGGIO, spessore * 0.5 + 0.02)
	for c in colonne:
		var t := -lunghezza * 0.5 + passo * (float(c) + 0.5)
		for p in piani:
			_gomma(gomme, raggio, ROSSO if c % 2 == 0 else BIANCO,
					posto * Transform3D(Basis(), lungo * t + Vector3.UP * (-alto * 0.5 + GOMMA_ALTA * float(p) + 0.01)))


## Una gomma in piedi: il battistrada nel colore della colonna, i fianchi scuri.
static func _gomma(getto: Giocattolo.Getto, raggio: float, tinta: Color, posto: Transform3D) -> void:
	var dentro := raggio * 0.45
	var a := GOMMA_ALTA - 0.02
	var profilo := PackedVector2Array([Vector2(dentro, 0.0), Vector2(raggio - 0.06, 0.0),
			Vector2(raggio, 0.06), Vector2(raggio, a - 0.06), Vector2(raggio - 0.06, a),
			Vector2(dentro, a), Vector2(dentro, 0.0)])
	var normali := PackedVector2Array([Vector2(0, -1), Vector2(0, -1), Vector2(1, 0), Vector2(1, 0),
			Vector2(0, 1), Vector2(0, 1), Vector2(-1, 0)])
	getto.tornio(profilo, normali, tinta, posto, 10)


## Se una sponda in piedi sta su questo blocco: allora niente fregio a scacchi, come le
## decalcomanie di GIOCATTOLO — il ciano resta l'unica cosa accesa, e i quadrati finivano
## per caso nello stesso piano della cornice della sponda (`prova_aspetto`).
static func _porta_una_sponda(pianta: Dictionary, posto: Transform3D, lx: float, lz: float) -> bool:
	for s: Dictionary in pianta["sponde"]:
		if s.has("sdraiata"):
			continue
		var locale := posto.affine_inverse() * Vector3(float(s["centro"][0]), posto.origin.y,
				float(s["centro"][1]))
		if absf(locale.x) < lx * 0.5 + 0.8 and absf(locale.z) < lz * 0.5 + 0.8:
			return true
	return false


## Un cassone del box nel colore dell'ala: corpo, base bianca, fregio a scacchi in cima.
static func _cassone(getto: Giocattolo.Getto, lx: float, lz: float, alto: float, posto: Transform3D,
		tinta: Color, senza_fregio: bool) -> void:
	getto.scatola(Vector3(lx, alto - 0.02, lz), 0.18, tinta, posto * Giocattolo._su(-0.01), 2, 0.2)
	getto.scatola(Vector3(lx + 0.06, 0.3, lz + 0.06), 0.06, BIANCO,
			posto * Giocattolo._su(-alto * 0.5 + 0.17), 1)
	if senza_fregio or alto < 1.6:
		return
	_scacchi_intorno(getto, lx, lz, alto * 0.5 - 0.55, posto, 0.5)


## Il fregio a scacchi: due file di quadrati bianchi e neri tutto intorno, a quota `y`.
## Ogni fila è una fetta che attraversa il blocco e sporge tre centimetri dalle due facce;
## le file finiscono quattro centimetri prima dei capi, dentro il blocco: fino al capo, la
## faccia dell'ultimo quadrato stava a due millimetri e mezzo da quella del blocco.
static func _scacchi_intorno(getto: Giocattolo.Getto, lx: float, lz: float, y: float,
		posto: Transform3D, lato: float) -> void:
	for asse in [Vector3.RIGHT, Vector3.BACK]:
		var lunghezza := (lx if asse == Vector3.RIGHT else lz) - 0.08
		var attraverso := (lz if asse == Vector3.RIGHT else lx) + 0.06
		var quanti := maxi(1, int(floor(lunghezza / lato)))
		var pezzo := lunghezza / float(quanti)
		for riga in 2:
			for i in quanti:
				var t := -lunghezza * 0.5 + pezzo * (float(i) + 0.5)
				var traverso: Vector3 = Vector3.BACK if asse == Vector3.RIGHT else Vector3.RIGHT
				getto.scatola(asse * (pezzo - 0.005) + traverso * (attraverso - 0.01 * float(riga))
						+ Vector3.UP * (lato - 0.005), 0.01,
						BIANCO if (i + riga) % 2 == 0 else NERO,
						posto * Transform3D(Basis(), asse * t + Vector3.UP * (y + lato * (float(riga) - 0.5))), 1)


## Una torre diventa il portale del traguardo: corpo bianco, fregio a scacchi largo in cima,
## colonne a strisce sui due capi e una bandiera su ognuna.
static func _portale(getto: Giocattolo.Getto, lx: float, lz: float, alto: float, posto: Transform3D) -> void:
	var lungo := _lungo(lx, lz)
	var lunghezza := maxf(lx, lz)
	var spessore := minf(lx, lz)
	getto.scatola(Vector3(lx, alto - 0.02, lz), 0.08, BIANCO, posto * Giocattolo._su(-0.01), 1, 0.2)
	_scacchi_intorno(getto, lx - 1.8, lz, alto * 0.5 - 0.75, posto, 0.6)
	for lato in [-1.0, 1.0]:
		var capo := posto * Transform3D(Basis(), lungo * lato * (lunghezza * 0.5 - 0.5) + Vector3.UP * (-alto * 0.5))
		var fasce := maxi(2, roundi((alto + 0.6) / 0.6))
		# I giunti fuori dai multipli di cinque centimetri: a 1,205 stavano in pari con la
		# cornice di una sponda.
		for f in fasce:
			getto.scatola(Vector3(spessore + 0.24, 0.6 - 0.01, spessore + 0.24), 0.06,
					ROSSO if f % 2 == 0 else BIANCO, capo * Giocattolo._su(0.6 * float(f) + 0.313), 1)
		_bandiera(getto, capo * Giocattolo._su(0.6 * float(fasce)), 2.2, ROSSO)


## Una colonna o un pilastro a strisce rosse e bianche; i piloni alti, con la bandierina.
static func _colonna(getto: Giocattolo.Getto, raggio: float, alto: float, cima: float,
		posto: Transform3D, bandiera: bool) -> void:
	var base := posto * Giocattolo._su(-alto * 0.5)
	# L'anima bianca è piena e larga quanto la collisione; le fasce rosse le stanno sopra,
	# tre centimetri fuori. A fasce staccate, fra l'una e l'altra passava un raggio.
	getto.tondo(raggio, cima - 0.01, 0.06, BIANCO, base * Giocattolo._su(0.005), 18)
	var fasce := maxi(2, roundi(cima / 0.8))
	var fascia := cima / float(fasce)
	for f in range(0, fasce, 2):
		getto.tondo(raggio + 0.03, fascia - 0.04, 0.04, ROSSO,
				base * Giocattolo._su(fascia * float(f) + 0.02), 18)
	if bandiera:
		_bandiera(getto, base * Giocattolo._su(cima), 2.4, GIALLO)


## Un'asta con la bandiera a scacchi o a tinta piena.
static func _bandiera(getto: Giocattolo.Getto, piede: Transform3D, alta: float, tinta: Color) -> void:
	getto.tondo(0.06, alta, 0.02, BIANCO, piede, 8)
	var drappo := piede * Transform3D(Basis(), Vector3(0.62, alta - 0.42, 0))
	getto.scatola(Vector3(1.1, 0.7, 0.04), 0.01, tinta, drappo, 1)


# ------------------------------------------------------------------ le tribune

## Le tribune fuori dal perimetro, sui quattro lati: sei gradoni che salgono da sopra il
## muretto, i sedili blu e bianchi, e il pubblico seduto — figurine a due scatole nei colori
## a caso, che costano ventiquattro triangoli l'una.
static func _tribune(arena: Arena, materiale: Material) -> void:
	var getto := Giocattolo.Getto.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEME
	var bordo := float(arena.pianta()["misura"]["larghezza"]) * 0.5 + 0.8
	for k in 4:
		var giro := Basis(Vector3.UP, PI * 0.5 * float(k))
		for fila in 6:
			var dentro := bordo + 0.4 + 1.2 * float(fila)
			var quota := 4.3 + 0.75 * float(fila)
			var centro := giro * Vector3(0, quota * 0.5, -(dentro + 0.6))
			getto.scatola(Vector3(74.0, quota, 1.2), 0.04, BLU if fila % 2 == 0 else BIANCO,
					Transform3D(giro, centro), 1, 0.4)
			var x := -36.0 + rng.randf_range(0.0, 0.8)
			while x < 36.0:
				if rng.randf() < 0.82:
					var piede := giro * Vector3(x, quota, -(dentro + 0.75))
					_spettatore(getto, Transform3D(giro, piede), rng)
				x += rng.randf_range(1.0, 1.6)
	Giocattolo._posa(arena, getto.mesh(), materiale, "tribune")


static func _spettatore(getto: Giocattolo.Getto, posto: Transform3D, rng: RandomNumberGenerator) -> void:
	var maglia := Color.from_hsv(rng.randf(), rng.randf_range(0.5, 0.85), rng.randf_range(0.65, 0.95))
	_cubo(getto, Vector3(0.52, 0.62, 0.36), maglia, posto * Giocattolo._su(0.31))
	_cubo(getto, Vector3(0.40, 0.40, 0.38), PELLI[rng.randi() % PELLI.size()], posto * Giocattolo._su(0.84))


## Una scatola a spigoli vivi, dodici triangoli: per le cose piccole e lontane.
static func _cubo(getto: Giocattolo.Getto, misura: Vector3, tinta: Color, posto: Transform3D) -> void:
	var m := misura * 0.5
	var giro := posto.basis.orthonormalized()
	for asse in 3:
		for segno in [-1.0, 1.0]:
			var u := (asse + 1) % 3
			var v := (asse + 2) % 3
			var fuori := Vector3.ZERO
			fuori[asse] = segno
			var primo := getto.vertici.size()
			for angolo in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var p := Vector3.ZERO
				p[asse] = m[asse] * segno
				p[u] = m[u] * angolo.x
				p[v] = m[v] * angolo.y
				getto.vertici.append(posto * p)
				getto.normali.append(giro * fuori)
				getto.colori.append(tinta)
			getto._quadro(primo, giro * fuori)


# ------------------------------------------------------------------ gli oggetti

## Una settantina di oggetti nei posti liberi (`Apertura.posti_liberi`), ognuno col suo
## solido: macchinine, pile di gomme, cartelloni, coni, bandiere, pali della luce.
static func _oggetti(arena: Arena, materiale: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEME + 1
	var getto := Giocattolo.Getto.new()
	var posti := Apertura.posti_liberi(arena, OGGETTI, 4.0, 1.3, 1.2, SEME)
	for i in posti.size():
		var p := posti[i]
		var posto := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, 0.0, p.y))
		var nome := "oggetto %d" % i
		var dado := rng.randf()
		var quale := 0
		if dado >= 0.28 and dado < 0.52:
			quale = rng.randi() % MACCHINE.size()
		elif dado >= 0.52 and dado < 0.68:
			quale = rng.randi() % CARTELLONI.size()
		# Lontano da porte e cannoni della PALLA: si salta dopo aver tirato i suoi numeri, così
		# tutti gli altri oggetti restano quelli di prima.
		if Palle.ingombra(p, 1.3):
			continue
		if dado < 0.28:
			_pila(arena, getto, posto, nome)
		elif dado < 0.52:
			_macchinina(arena, getto, posto, MACCHINE[quale], nome)
		elif dado < 0.68:
			_cartellone(arena, getto, posto, CARTELLONI[quale], nome)
		elif dado < 0.84:
			_coni(arena, getto, posto, nome)
		elif dado < 0.95:
			_asta(arena, getto, posto, nome)
		else:
			_lampione(arena, getto, posto, nome)
	Giocattolo._posa(arena, getto.mesh(), materiale, "oggetti della pista")


## Tre colonne di gomme, tre per colonna, rosse e bianche.
static func _pila(arena: Arena, getto: Giocattolo.Getto, posto: Transform3D, nome: String) -> void:
	for k in 3:
		var dove := Vector3(0.55, 0, 0).rotated(Vector3.UP, TAU * float(k) / 3.0)
		for p in 3:
			_gomma(getto, GOMMA_RAGGIO, ROSSO if (k + p) % 2 == 0 else BIANCO,
					posto * Transform3D(Basis(), dove + Vector3.UP * (GOMMA_ALTA * float(p) + 0.01)))
	Apertura.solido(arena, posto, [[Apertura.cilindro(1.0, GOMMA_ALTA * 3.0),
			Giocattolo._su(GOMMA_ALTA * 1.5)]], nome)


## Una macchinina giocattolo: scocca, abitacolo, quattro ruote, il numero sul fianco no.
static func _macchinina(arena: Arena, getto: Giocattolo.Getto, posto: Transform3D, tinta: Color,
		nome: String) -> void:
	getto.scatola(Vector3(2.5, 0.62, 1.3), 0.22, tinta, posto * Giocattolo._su(0.62), 2)
	getto.scatola(Vector3(1.2, 0.55, 1.1), 0.2, BIANCO, posto * Transform3D(Basis(), Vector3(-0.2, 1.15, 0)), 2)
	getto.scatola(Vector3(0.9, 0.12, 1.36), 0.04, NERO, posto * Transform3D(Basis(), Vector3(0.75, 0.94, 0)), 1)
	for sx in [-0.82, 0.82]:
		for sz in [-0.62, 0.62]:
			# La ruota cresce verso +Z dal suo piede: a destra parte da dentro, a sinistra da fuori.
			var ruota := posto * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx, 0.36, 0.44 if sz > 0.0 else -0.72))
			getto.tondo(0.36, 0.28, 0.08, GOMMA, ruota, 12)
	Apertura.solido(arena, posto, [[Apertura.scatola(Vector3(2.5, 1.45, 1.4)), Giocattolo._su(0.73)]], nome)


## Un cartellone su due pali, col fregio bianco: riparo e segnale.
static func _cartellone(arena: Arena, getto: Giocattolo.Getto, posto: Transform3D, tinta: Color,
		nome: String) -> void:
	for lato in [-1.6, 1.6]:
		getto.tondo(0.1, 3.3, 0.03, BIANCO, posto * Transform3D(Basis(), Vector3(lato, 0.01, -0.1)), 8)
	getto.scatola(Vector3(4.2, 2.0, 0.2), 0.06, tinta, posto * Giocattolo._su(2.2), 2)
	getto.scatola(Vector3(3.6, 0.28, 0.24), 0.02, BIANCO, posto * Giocattolo._su(2.55), 1)
	Apertura.solido(arena, posto, [
		[Apertura.scatola(Vector3(4.2, 2.0, 0.2)), Giocattolo._su(2.2)],
		[Apertura.cilindro(0.12, 1.2), Transform3D(Basis(), Vector3(-1.6, 0.6, -0.1))],
		[Apertura.cilindro(0.12, 1.2), Transform3D(Basis(), Vector3(1.6, 0.6, -0.1))],
	], nome)


## Tre coni rossi e bianchi in fila.
static func _coni(arena: Arena, getto: Giocattolo.Getto, posto: Transform3D, nome: String) -> void:
	var forme := []
	for k in 3:
		var dove := Vector3(-1.1 + 1.1 * float(k), 0, 0)
		var piede := posto * Transform3D(Basis(), dove)
		getto.scatola(Vector3(0.7, 0.08, 0.7), 0.03, ROSSO, piede * Giocattolo._su(0.05), 1)
		var profilo := PackedVector2Array([Vector2(0.3, 0.0), Vector2(0.22, 0.32), Vector2(0.17, 0.5),
				Vector2(0.06, 0.95), Vector2(0.0, 0.96)])
		var normali := PackedVector2Array([Vector2(0.97, 0.25), Vector2(0.97, 0.25), Vector2(0.97, 0.25),
				Vector2(0.97, 0.25), Vector2(0, 1)])
		getto.tornio(profilo, normali, ROSSO, piede * Giocattolo._su(0.09), 12)
		getto.tondo(0.205, 0.14, 0.02, BIANCO, piede * Giocattolo._su(0.45), 12)
		forme.append([Apertura.cilindro(0.3, 1.0), Transform3D(Basis(), dove + Vector3.UP * 0.5)])
	Apertura.solido(arena, posto, forme, nome)


## Un'asta con la bandiera a scacchi.
static func _asta(arena: Arena, getto: Giocattolo.Getto, posto: Transform3D, nome: String) -> void:
	getto.tondo(0.08, 4.0, 0.03, BIANCO, posto * Giocattolo._su(0.01), 8)
	for r in 3:
		for c in 4:
			getto.scatola(Vector3(0.4, 0.4, 0.05), 0.01, BIANCO if (r + c) % 2 == 0 else NERO,
					posto * Transform3D(Basis(), Vector3(0.3 + 0.4 * float(c), 3.7 - 0.4 * float(r), 0)), 1)
	Apertura.solido(arena, posto, [[Apertura.cilindro(0.1, 4.0), Giocattolo._su(2.0)]], nome)


## Un palo della luce alto, coi fari: orientamento da lontano.
static func _lampione(arena: Arena, getto: Giocattolo.Getto, posto: Transform3D, nome: String) -> void:
	getto.tondo(0.16, 7.0, 0.04, BIANCO, posto * Giocattolo._su(0.01), 10)
	getto.scatola(Vector3(1.8, 0.7, 0.4), 0.08, NERO, posto * Giocattolo._su(7.2), 1)
	for k in 3:
		getto.scatola(Vector3(0.42, 0.42, 0.06), 0.03, Color(1.0, 0.96, 0.82),
				posto * Transform3D(Basis(), Vector3(-0.55 + 0.55 * float(k), 7.2, 0.21)), 1)
	Apertura.solido(arena, posto, [[Apertura.cilindro(0.18, 7.0), Giocattolo._su(3.5)]], nome)
