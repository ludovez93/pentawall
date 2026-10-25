class_name Gonfiabile
extends RefCounted

## **A, PARCO GONFIABILE** (tappa 11, blocco C2, 11/10/2026): l'arena aperta fatta di
## gonfiabili (Fable, `ricerca-grezza/stato-2026-10-11/fable-c2.md`). L'imbottito di
## GIOCATTOLO era giusto, l'errore era metterlo su pareti di dodici metri: qui i muri sono
## quelli di GIOCATTOLO sulle altezze dell'arena aperta, i piloni diventano colonne
## gonfiabili a rocchi, il catino una vasca di palline, e in campo ci sono una novantina
## di oggetti di misura media — blocchi tondi, pouf, ciambelle in piedi, archi, palloni —
## che fanno da riparo e da arredo.
##
## Tutto fatto in codice, nel getto di GIOCATTOLO (colori sui vertici, un materiale solo):
## sul telefono niente da compilare, e pochi pezzi per la scheda.

const ROSSO := Color(0.92, 0.20, 0.24)
const GIALLO := Color(1.0, 0.80, 0.16)
const BLU := Color(0.16, 0.36, 0.92)
const VIOLA := Color(0.56, 0.32, 0.92)
const BIANCO := Color(0.95, 0.95, 0.96)
const TINTE := [ROSSO, GIALLO, BLU, VIOLA]

const OGGETTI := 90
const SEME := 1105

## **La pelle del gonfiabile** (tappa 11, blocco C3b, passo 1). Un gonfiabile si riconosce
## da tre cose: le cuciture fra un rocchio e l'altro, la sfumatura che scurisce verso le
## pieghe, il punto di luce sul colmo. Qui sono tutte e tre nei **colori dei vertici**:
## sul telefono niente shader da compilare e niente texture da caricare, e il disegno
## costa quanto prima.
##
## `QUOTE` sono le quote del profilo di un rocchio, da una cucitura all'altra: fitte agli
## estremi, perché lì ci stanno il nastro e la piega, larghe in mezzo, dove la superficie
## è liscia.
const QUOTE := [0.0, 0.03, 0.07, 0.16, 0.34, 0.5, 0.66, 0.84, 0.93, 0.97, 1.0]
## Quanto è largo il nastro della cucitura, in frazione di rocchio, e fin dove arriva la
## piega scura che gli sta sotto.
const NASTRO := 0.035
const FIN_DOVE := 0.22
## Quanto schiarisce il nastro, e quanto scurisce la piega.
const CHIARO := 0.42
const PIEGA := 0.3
## Quanto il colmo prende di bianco quando guarda il sole.
const LUCIDO := 0.3
## Verso il sole: la rotazione della luce in `Giocattolo.illumina` (-56, -40 gradi) presa
## al contrario, dalla superficie alla luce. Il sole dell'arena aperta non si muove, e
## cosi il punto di luce si puo cuocere nei vertici una volta per tutte.
const VERSO_IL_SOLE := Vector3(-0.359, 0.829, 0.428)


static func veste(arena: Arena) -> void:
	var materiale := Giocattolo._materiale_dei_moduli()
	Apertura.veste(arena, materiale)
	_vasca(arena, materiale)
	await arena._respiro()
	_oggetti(arena, materiale)


# ------------------------------------------------------------------ le colonne

## Un pilone gonfiabile: rocchi gonfi uno sull'altro nei due colori dell'ala, una
## fascia stretta fra l'uno e l'altro, e in cima una palla. Lo chiama `Giocattolo._modulo`
## al posto del pilone imbottito, sui piloni alti dell'arena aperta.
static func pilone(getto: Giocattolo.Getto, raggio: float, alto: float, corpo: Color,
		bordo: Color, posto: Transform3D, abbassa: float) -> void:
	var base := posto * Giocattolo._su(-alto * 0.5)
	var cima := alto - abbassa
	var rocchi := maxi(2, roundi(cima / 1.6))
	var rocchio := cima / float(rocchi)
	for k in rocchi:
		var profilo := PackedVector2Array()
		var normali := PackedVector2Array()
		# Il rocchio si gonfia solo verso fuori: dove due rocchi si toccano le facce piatte
		# fra uno spigolo e l'altro (venti lati) stanno ancora sulla collisione, e un dardo
		# non si ferma mai nel vuoto davanti a lui (`prova_aspetto`).
		for t: float in QUOTE:
			var gonfio := sin(t * PI)
			profilo.append(Vector2(raggio * (1.013 + 0.022 * gonfio), rocchio * t))
			normali.append(Vector2(1.0, -cos(t * PI) * 0.25).normalized())
		var tinta: Color = corpo if k % 2 == 0 else bordo
		var primo := getto.vertici.size()
		getto.tornio(profilo, normali, tinta, base * Giocattolo._su(rocchio * float(k)), 20)
		_pelle(getto, primo, QUOTE.size(), tinta)
	var palla := raggio * 0.75
	var sopra := getto.vertici.size()
	getto.tornio(_cerchio(palla, 9), _normali_cerchio(9), BIANCO,
			base * Giocattolo._su(cima + palla * 0.85), 14)
	_lucido(getto, sopra)


## I colori dei vertici di un rocchio appena messo nel getto, riga per riga del profilo
## (`QUOTE`, `righe` punti per ogni lato del tornio): il **nastro** chiaro della cucitura
## dove due rocchi si toccano, la **piega** scura appena sotto di lui, il colore pieno sul
## gonfio. Poi il punto di luce.
static func _pelle(getto: Giocattolo.Getto, primo: int, righe: int, tinta: Color) -> void:
	for v in range(primo, getto.vertici.size()):
		var t: float = QUOTE[(v - primo) % righe]
		var dal_bordo := minf(t, 1.0 - t)
		getto.colori[v] = tinta.lightened(CHIARO) if dal_bordo <= NASTRO \
				else tinta.darkened(PIEGA * clampf(1.0 - (dal_bordo - NASTRO) / FIN_DOVE, 0.0, 1.0))
	_lucido(getto, primo)


## **Il punto di luce**: sui vertici dal `primo` in poi, la faccia che guarda il sole
## prende del bianco. E il lucido del telone, e costa solo i colori dei vertici.
static func _lucido(getto: Giocattolo.Getto, primo: int, quanto := LUCIDO) -> void:
	for v in range(primo, getto.vertici.size()):
		var luce := maxf(0.0, getto.normali[v].dot(VERSO_IL_SOLE))
		getto.colori[v] = getto.colori[v].lerp(BIANCO, quanto * pow(luce, 5.0))


# ------------------------------------------------------------------ lo scivolo

## **Lo scivolo gonfiabile** al posto della rampa liscia (tappa 11, blocco C3b): un
## materasso ad aria sta su a cuscini trasversali, e fra un cuscino e l'altro si vede il
## fondo, che e la cucitura. Il fondo sta sei centimetri sotto la cima dei cuscini: in
## pari lampeggerebbero (`LEARNED.md` § 63). La cima dei cuscini resta quella della
## collisione — chi sale non deve affondare — e i due tubi dei bordi sono quelli di
## sempre. Le frecce bianche della salita le mette chi chiama, dopo.
static func scivolo(getto: Giocattolo.Getto, misura: Vector3, posto: Transform3D,
		corpo: Color, bordo: Color) -> void:
	var primo := getto.vertici.size()
	getto.scatola(Vector3(misura.x - 0.02, misura.y - 0.06, misura.z - 0.02), 0.1,
			corpo.darkened(0.42), posto)
	var quanti := maxi(3, roundi(misura.z / 1.15))
	var passo := misura.z / float(quanti)
	var giu := posto.affine_inverse()
	for k in quanti:
		var z := misura.z * 0.5 - passo * (float(k) + 0.5)
		var suo := getto.vertici.size()
		getto.scatola(Vector3(misura.x - 0.06, misura.y, passo - 0.07),
				minf(misura.y * 0.46, 0.2), corpo,
				posto * Transform3D(Basis(), Vector3(0.0, 0.0, z)), 1, 0.22)
		# La stessa piega del rocchio, girata: il cuscino scurisce verso le sue due cuciture,
		# ed è quello che lo fa vedere gonfio anche con la cima piatta.
		for v in range(suo, getto.vertici.size()):
			var quanto := clampf(absf((giu * getto.vertici[v]).z - z) / (passo * 0.5), 0.0, 1.0)
			getto.colori[v] = getto.colori[v].darkened(PIEGA * quanto * quanto)
	for lato in [-1.0, 1.0]:
		getto.scatola(Vector3(0.26, misura.y + 0.06, misura.z + 0.04), 0.1, bordo,
				posto * Transform3D(Basis(), Vector3(lato * (misura.x * 0.5 - 0.11), 0.05, 0.0)))
	_lucido(getto, primo)


# ------------------------------------------------------------------ la vasca

## **La vasca di palline** nel catino: palle colorate sul fondo, su una griglia smossa a
## caso (così non si compenetrano), più fitte contro le facce, lontane dal box in mezzo e
## dalle rampe. Ognuna girata a caso: girate uguali, due palle vicine avevano facce
## parallele, e qualcuna nello stesso piano lampeggiava (`prova_aspetto`). Senza
## collisione: ci si cammina dentro come in una vasca vera, e il dardo le attraversa.
static func _vasca(arena: Arena, materiale: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEME
	var pianta := arena.pianta()
	var contorno := PackedVector2Array()
	for zona: Dictionary in pianta["zone"]:
		if float(zona["quota"]) < -1.0:
			contorno = Apertura._contorno(zona["poligono"])
	if contorno.is_empty():
		return
	var getto := Giocattolo.Getto.new()
	var profilo := _cerchio(1.0, 5)
	var normali := _normali_cerchio(5)
	var passo := 0.62
	var x := -14.5
	while x < 14.5:
		var z := -14.5
		while z < 14.5:
			var p := Vector2(x, z) + Vector2(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03))
			z += passo
			if not Geometry2D.is_point_in_polygon(p, contorno) or (absf(p.x) < 3.9 and absf(p.y) < 3.9) \
					or Giocattolo._sopra_una_rampa(p, pianta):
				continue
			# Più fitte verso le facce: dentro, due su tre si scartano.
			if rng.randf() < (0.66 if maxf(absf(p.x), absf(p.y)) < 10.0 else 0.2):
				continue
			var raggio := rng.randf_range(0.24, 0.29)
			var su := rng.randf_range(0.0, 0.18)
			var tinta: Color = [ROSSO, GIALLO, BLU, VIOLA, BIANCO][rng.randi() % 5]
			var giro := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
			getto.tornio(profilo, normali, tinta, Transform3D(giro.scaled(Vector3.ONE * raggio),
					Vector3(p.x, -2.0 + su, p.y)), 7)
		x += passo
	# Il punto di luce su tutte insieme: una vasca di palline opache sembra ghiaia.
	_lucido(getto, 0, 0.5)
	Giocattolo._posa(arena, getto.mesh(), materiale, "vasca di palline")


# ------------------------------------------------------------------ gli oggetti

## Una novantina di oggetti nei posti liberi (`Apertura.posti_liberi`), ognuno col suo
## solido. Quale oggetto e di che colore lo decide il caso, sempre lo stesso.
static func _oggetti(arena: Arena, materiale: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEME + 1
	var getto := Giocattolo.Getto.new()
	var posti := Apertura.posti_liberi(arena, OGGETTI, 4.0, 1.3, 1.2, SEME)
	for i in posti.size():
		var p := posti[i]
		var giro := Basis(Vector3.UP, rng.randf() * TAU)
		var posto := Transform3D(giro, Vector3(p.x, 0.0, p.y))
		var tinta: Color = TINTE[rng.randi() % TINTE.size()]
		var altra: Color = TINTE[(TINTE.find(tinta) + 1 + rng.randi() % 3) % TINTE.size()]
		var nome := "oggetto %d" % i
		var tipo := rng.randi() % 6
		# Lontano da porte e cannoni della PALLA: si salta dopo aver tirato i suoi numeri, così
		# tutti gli altri oggetti restano quelli di prima.
		if Palle.ingombra(p, 1.3):
			continue
		match tipo:
			0, 1:
				_blocco(arena, getto, posto, tinta, nome)
			2:
				_pouf(arena, getto, posto, tinta, altra, nome)
			3:
				_ciambella(arena, getto, posto, tinta, nome)
			4:
				_arco(arena, getto, posto, tinta, altra, nome)
			5:
				_palla(arena, getto, posto, nome)
	Giocattolo._posa(arena, getto.mesh(), materiale, "oggetti gonfiabili")


## Un cuscino lungo coricato, con la fascia bianca in mezzo: riparo da accovacciati.
static func _blocco(arena: Arena, getto: Giocattolo.Getto, posto: Transform3D, tinta: Color,
		nome: String) -> void:
	var misura := Vector3(2.4, 1.2, 1.2)
	getto.scatola(misura, 0.45, tinta, posto * Giocattolo._su(0.6 + 0.01), 3, 0.25)
	# La fascia si arrotonda a due passi e il cuscino a tre: con gli stessi passi le facce
	# degli spigoli venivano parallele, e qualcuna nello stesso piano (`prova_aspetto`).
	getto.scatola(Vector3(0.5, 1.24, 1.24), 0.45, BIANCO, posto * Giocattolo._su(0.6 + 0.01), 2)
	Apertura.solido(arena, posto, [[Apertura.scatola(misura), Giocattolo._su(0.6)]], nome)


## Un pouf tondo col cuscino in cima.
static func _pouf(arena: Arena, getto: Giocattolo.Getto, posto: Transform3D, tinta: Color,
		altra: Color, nome: String) -> void:
	getto.tondo(1.0, 1.0, 0.3, tinta, posto * Giocattolo._su(0.01))
	getto.tondo(0.86, 0.22, 0.1, altra, posto * Giocattolo._su(0.95))
	Apertura.solido(arena, posto, [[Apertura.cilindro(1.0, 1.15), Giocattolo._su(0.575)]], nome)


## Una ciambella gonfiabile in piedi: si tira nel buco.
static func _ciambella(arena: Arena, getto: Giocattolo.Getto, posto: Transform3D, tinta: Color,
		nome: String) -> void:
	var grande := 0.95
	var piccolo := 0.38
	var centro := grande + piccolo + 0.01
	var in_piedi := posto * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, centro, 0))
	getto.tornio(_anello(grande, piccolo, 8), _normali_anello(8), tinta, in_piedi, 22)
	var lato := piccolo * 2.0
	Apertura.solido(arena, posto, [
		[Apertura.scatola(Vector3(lato, 2.0 * grande, lato)), Giocattolo._su(centro) * Transform3D(Basis(), Vector3(-grande, 0, 0))],
		[Apertura.scatola(Vector3(lato, 2.0 * grande, lato)), Giocattolo._su(centro) * Transform3D(Basis(), Vector3(grande, 0, 0))],
		[Apertura.scatola(Vector3(2.0 * grande, lato, lato)), Giocattolo._su(centro + grande)],
		[Apertura.scatola(Vector3(2.0 * grande, lato, lato)), Giocattolo._su(centro - grande)],
	], nome)


## Un arco gonfiabile da attraversare, a mezzo anello, coi piedi di un altro colore.
static func _arco(arena: Arena, getto: Giocattolo.Getto, posto: Transform3D, tinta: Color,
		altra: Color, nome: String) -> void:
	var grande := 1.5
	var piccolo := 0.4
	# L'asse del giro va in orizzontale e il mezzo anello resta sopra il pavimento.
	var arco := posto * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
	getto.tornio(_anello(grande, piccolo, 8), _normali_anello(8), tinta, arco, 20, Color.BLACK, 0,
			0.0, PI)
	for lato in [-1.0, 1.0]:
		getto.tondo(piccolo + 0.08, 0.5, 0.12, altra, posto * Transform3D(Basis(), Vector3(lato * grande, 0.01, 0)))
	var gamba := Vector3(piccolo * 2.0, 1.6, piccolo * 2.0)
	Apertura.solido(arena, posto, [
		[Apertura.scatola(gamba), Transform3D(Basis(), Vector3(-grande, 0.8, 0))],
		[Apertura.scatola(gamba), Transform3D(Basis(), Vector3(grande, 0.8, 0))],
		[Apertura.scatola(Vector3(2.0, 0.8, piccolo * 2.0)), Giocattolo._su(grande + 0.02)],
	], nome)


## Un pallone da spiaggia a spicchi, appoggiato a terra.
static func _palla(arena: Arena, getto: Giocattolo.Getto, posto: Transform3D, nome: String) -> void:
	var raggio := 0.85
	var spicchi := [ROSSO, BIANCO, BLU, GIALLO, BIANCO, VIOLA]
	var palla := posto * Transform3D(Basis.from_scale(Vector3.ONE * raggio), Vector3(0, raggio + 0.01, 0))
	for k in spicchi.size():
		getto.tornio(_cerchio(1.0, 9), _normali_cerchio(9), spicchi[k], palla, 4, Color.BLACK, 0,
				TAU * float(k) / float(spicchi.size()), TAU / float(spicchi.size()))
	var forma := SphereShape3D.new()
	forma.radius = raggio
	Apertura.solido(arena, posto, [[forma, Giocattolo._su(raggio)]], nome)


# ------------------------------------------------------------------ profili

## Il profilo di una sfera di raggio `r` per il tornio: dal polo sotto a quello sopra.
static func _cerchio(r: float, passi: int) -> PackedVector2Array:
	var fuori := PackedVector2Array()
	for k in passi + 1:
		var t := -PI * 0.5 + PI * float(k) / float(passi)
		fuori.append(Vector2(cos(t), sin(t)) * r)
	return fuori


static func _normali_cerchio(passi: int) -> PackedVector2Array:
	var fuori := PackedVector2Array()
	for k in passi + 1:
		var t := -PI * 0.5 + PI * float(k) / float(passi)
		fuori.append(Vector2(cos(t), sin(t)))
	return fuori


## Il profilo di un anello (una ciambella): il cerchio piccolo intero, a distanza
## `grande` dall'asse — la metà di fuori in salita, quella di dentro in discesa.
static func _anello(grande: float, piccolo: float, passi: int) -> PackedVector2Array:
	var fuori := PackedVector2Array()
	for k in 2 * passi + 1:
		var t := -PI * 0.5 + PI * float(k) / float(passi)
		fuori.append(Vector2(grande + piccolo * cos(t), piccolo * sin(t)))
	return fuori


static func _normali_anello(passi: int) -> PackedVector2Array:
	var fuori := PackedVector2Array()
	for k in 2 * passi + 1:
		var t := -PI * 0.5 + PI * float(k) / float(passi)
		fuori.append(Vector2(cos(t), sin(t)))
	return fuori
