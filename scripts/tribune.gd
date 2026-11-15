class_name Tribune
extends RefCounted

## **Le tribune fuori dal perimetro** (tappa 14, blocco A, 14/11/2026). Dalla diagnosi
## sulla pubblicità di riferimento (`ricerca-grezza/stato-2026-11-14/fable-pubblicita.md`):
## da loro si guarda chi gioca davanti a un mondo pieno, da noi dietro ai personaggi
## c'erano rocce e cielo. Qui, sui due lati dell'arena aperta che si vedono dalla partenza
## (nord e ovest), sopra il muro del perimetro:
## - **la fascia dei cartelloni**, tre marchi inventati ripetuti (`CARTELLONI`);
## - **cinque gradoni col pubblico**, nelle maglie dei sei concorrenti;
## - **il tabellone grande** in mezzo alla tribuna, coi primi tre e i loro punti.
##
## Il pubblico sono figurine a scatole — busto, testa, capelli, e chi tifa ha le braccia
## alzate — nel getto di `Giocattolo`: colori sui vertici e il materiale dei moduli, quindi
## sul telefono niente da compilare, e tutte insieme sono **una chiamata di disegno**. Le
## persone vere di `Pubblico` (da 888 a 1.356 triangoli l'una) restano sulla gradinata di
## dentro, che si vede da vicino: qui, a venti metri e più, seicento di loro sarebbero
## settecentomila triangoli, più di tutta l'arena.
##
## Niente collisioni: sta tutto oltre il muro, dove non arriva nessuno.

## I lati con la tribuna, in quarti di giro attorno alla verticale: 0 è il nord, 1 l'ovest.
const LATI := [0, 1]
## Dove sta il tabellone lungo ogni lato, in metri dal centro (nel verso del lato).
const TABELLONE_LUNGO := {0: -19.0, 1: 19.0}

const LUNGA := 74.0
const FILE := 5
const PASSO_FILA := 1.3
const GRADINO := 0.7
## La quota del primo gradone: sopra la fascia dei cartelloni.
const PRIMA_FILA := 5.75
## Quanto sta fuori dal filo esterno del perimetro la fascia, e poi il primo gradone.
const FASCIA_FUORI := 0.45
const GRADONI_FUORI := 1.1

const CARTELLONE := Vector2(5.0, 1.45)
const PASSO_CARTELLONE := 5.2
const QUOTA_CARTELLONE := 4.2

const TABELLONE := Vector3(13.0, 5.6, 0.5)
const QUOTA_TABELLONE := 6.1

const SEME := 1411
const PASSO_POSTO := 0.95
const POSTI_VUOTI := 0.12
const PELLI := [Color(0.98, 0.80, 0.66), Color(0.86, 0.62, 0.46), Color(0.60, 0.40, 0.28),
		Color(0.95, 0.72, 0.56)]
const CAPELLI := [Color(0.14, 0.11, 0.10), Color(0.42, 0.24, 0.14), Color(0.92, 0.76, 0.38),
		Color(0.72, 0.30, 0.16), Color(0.80, 0.80, 0.84)]
## Le maglie: i colori dei sei concorrenti e il viola. Mai l'oro dei punti, il lime degli
## avversari, l'arancio del dardo o il ciano delle sponde.
const MAGLIE := [Color(0.13, 0.36, 0.95), Color(0.84, 0.12, 0.20), Color(0.98, 0.80, 0.12),
		Color(0.90, 0.30, 0.64), Color(0.92, 0.92, 0.95), Color(0.15, 0.15, 0.18),
		Color(0.62, 0.34, 0.95)]

## In quanti gruppi è diviso il pubblico, quanto dura il tifo in secondi e quanto salta.
const GRUPPI := 3
const TIFO := 1.3
const SALTO := 0.42
## I festoni: quanto pendono le bandierine e ogni quanto ce n'è una.
const BANDIERINA := Vector2(0.9, 1.3)

const GRADONE_SCURO := Color(0.13, 0.16, 0.40)
const GRADONE_CHIARO := Color(0.18, 0.22, 0.52)
const NAVY := Color(0.06, 0.08, 0.22)

## **I tre marchi dei cartelloni, inventati** (una bibita, un negozio di giocattoli, una
## gomma da masticare): la casella nel foglio delle decalcomanie e il colore del pannello.
## Nessun marchio vero, nemmeno storpiato; vanno verificati prima della pubblicazione.
const CARTELLONI := [
	{"casella": "GORGOLI", "tinta": Color(0.80, 0.14, 0.20)},
	{"casella": "TRULLALLA", "tinta": Color(0.10, 0.20, 0.62)},
	{"casella": "GNAMBOLLA", "tinta": Color(0.46, 0.22, 0.80)},
]


## Costruisce tribune, cartelloni e tabelloni. Torna il nodo che li contiene.
static func costruisci(arena: Arena, materiale: Material) -> Node3D:
	_conta = 0
	var radice := Node3D.new()
	radice.name = "tribune"
	arena.add_child(radice)
	var getto := Giocattolo.Getto.new()
	var foglio := Giocattolo.Foglio.new()
	# Il pubblico in tre gruppi mescolati: quando qualcuno fa punti saltano sfasati, e
	# sembra una folla invece di un blocco che si alza. Tre chiamate di disegno.
	var folla: Array[Giocattolo.Getto] = []
	for g in GRUPPI:
		folla.append(Giocattolo.Getto.new())
	var rng := RandomNumberGenerator.new()
	rng.seed = SEME
	# Il filo esterno del perimetro: mezza pianta più lo spessore del muro.
	var bordo := float(arena.pianta()["misura"]["larghezza"]) * 0.5 + 0.8
	for k: int in LATI:
		var giro := Basis(Vector3.UP, PI * 0.5 * float(k))
		var dove_tabellone := float(TABELLONE_LUNGO.get(k, 0.0))
		_fascia(getto, foglio, giro, bordo + FASCIA_FUORI)
		_gradoni(getto, giro, bordo + GRADONI_FUORI)
		_pubblico(folla, giro, bordo + GRADONI_FUORI, dove_tabellone, rng)
		_tabellone(radice, getto, giro, bordo + GRADONI_FUORI, dove_tabellone, k)
		_festone(radice, giro, bordo + GRADONI_FUORI, materiale, k, rng)
	_posa(radice, getto.mesh(), materiale, "gradoni")
	for g in GRUPPI:
		_posa(radice, folla[g].mesh(), materiale, "pubblico %d" % g)
	var pelle := ShaderMaterial.new()
	pelle.shader = load(Giocattolo.DECALCO)
	pelle.set_shader_parameter("foglio", load(Giocattolo.DECALCHI))
	_posa(radice, foglio.mesh(), pelle, "scritte dei cartelloni")
	radice.set_meta("pubblico", _conta)
	return radice


## Scrive i tabelloni: in testa la modalità e il tempo, sotto i primi tre coi punti.
## `righe` è la classifica dell'arena (`nome` e quello che `Comandi.valore_di` ne legge).
static func scrivi(radice: Node, testa: String, righe: Array) -> void:
	if radice == null:
		return
	for tabellone in radice.get_children():
		if not String(tabellone.name).begins_with("tabellone"):
			continue
		_scrivi_riga(tabellone, 0, testa)
		for i in 3:
			var testo := ""
			if i < righe.size():
				testo = "%d  %s  %s" % [i + 1, String(righe[i]["nome"]),
						Comandi.valore_di(righe[i])]
			_scrivi_riga(tabellone, i + 1, testo)


## Il pubblico salta: lo chiama l'arena quando la classifica cambia.
static func tifa(radice: Node) -> void:
	if radice != null:
		radice.set_meta("tifo", TIFO)


## Quello che si muove sulle tribune, a ogni fotogramma: i festoni che dondolano sempre,
## e i tre gruppi del pubblico che saltano sfasati finché dura il tifo. Sono nodi interi
## che si spostano: nessuno shader, niente da ricalcolare.
static func muovi(radice: Node, tempo: float, delta: float) -> void:
	if radice == null:
		return
	var tifo := maxf(float(radice.get_meta("tifo", 0.0)) - delta, 0.0)
	radice.set_meta("tifo", tifo)
	for figlio in radice.get_children():
		var nome := String(figlio.name)
		if nome.begins_with("festone"):
			(figlio as Node3D).rotation.x = 0.16 * sin(tempo * 1.7 + float(figlio.get_index()))
		elif nome.begins_with("pubblico"):
			var sfasa := float(nome.to_int()) * 2.1
			(figlio as Node3D).position.y = SALTO * minf(tifo / 0.3, 1.0) 					* absf(sin(tempo * 9.0 + sfasa)) if tifo > 0.0 else 0.0


## Quante figurine ci sono sulle tribune: serve al collaudo.
static func quante(radice: Node) -> int:
	return int(radice.get_meta("pubblico", 0)) if radice != null else 0


# ------------------------------------------------------------------ dentro

static func _scrivi_riga(tabellone: Node, quale: int, testo: String) -> void:
	var riga := tabellone.get_node_or_null("riga_%d" % quale) as Label3D
	if riga != null and riga.text != testo:
		riga.text = testo


## La fascia dei cartelloni: pannelli uno accanto all'altro, appena fuori dal muro e sopra
## la sua cima, coi tre marchi che si ripetono. Sotto, una trave che la regge.
static func _fascia(getto: Giocattolo.Getto, foglio: Giocattolo.Foglio, giro: Basis,
		fuori: float) -> void:
	var quanti := int(LUNGA / PASSO_CARTELLONE)
	var primo := -PASSO_CARTELLONE * float(quanti - 1) * 0.5
	var dentro := giro * Vector3(0, 0, 1)
	getto.scatola(Vector3(LUNGA, QUOTA_CARTELLONE, 0.5), 0.05, GRADONE_SCURO,
			Transform3D(giro, giro * Vector3(0, QUOTA_CARTELLONE * 0.5, -(fuori + 0.3))), 1)
	for i in quanti:
		var marchio: Dictionary = CARTELLONI[i % CARTELLONI.size()]
		var tinta: Color = marchio["tinta"]
		var centro := giro * Vector3(primo + PASSO_CARTELLONE * float(i),
				QUOTA_CARTELLONE + CARTELLONE.y * 0.5, -(fuori + 0.15))
		getto.scatola(Vector3(CARTELLONE.x, CARTELLONE.y, 0.3), 0.06, tinta,
				Transform3D(giro, centro), 1, 0.25)
		var casella: Rect2 = Giocattolo.CASELLE[String(marchio["casella"])]
		var alto := CARTELLONE.y * 0.74
		var largo := minf(alto * casella.size.x / casella.size.y, CARTELLONE.x * 0.92)
		foglio.quadro(centro + dentro * 0.165, dentro,
				Vector2(largo, largo * casella.size.y / casella.size.x), casella,
				tinta.darkened(0.6))


## I gradoni: blocchi pieni dal terreno di fuori alla quota di ogni fila, uno scuro e uno
## meno, e dietro l'ultimo un muro con la fascia arancio in cima.
static func _gradoni(getto: Giocattolo.Getto, giro: Basis, fuori: float) -> void:
	for fila in FILE:
		var quota := PRIMA_FILA + GRADINO * float(fila)
		var centro := giro * Vector3(0, quota * 0.5, -(fuori + PASSO_FILA * (float(fila) + 0.5)))
		getto.scatola(Vector3(LUNGA, quota, PASSO_FILA), 0.04,
				GRADONE_SCURO if fila % 2 == 0 else GRADONE_CHIARO, Transform3D(giro, centro), 1)
	var cima := PRIMA_FILA + GRADINO * float(FILE) + 1.9
	var dietro := -(fuori + PASSO_FILA * float(FILE) + 0.25)
	getto.scatola(Vector3(LUNGA + 1.0, cima, 0.5), 0.05, Giocattolo.BLU,
			Transform3D(giro, giro * Vector3(0, cima * 0.5, dietro)), 1)
	getto.scatola(Vector3(LUNGA + 1.2, 0.35, 0.7), 0.08, Giocattolo.ARANCIO,
			Transform3D(giro, giro * Vector3(0, cima + 0.12, dietro)), 1)


## Il pubblico: una figurina per posto, a caso ma sempre uguale. Dove sta il tabellone i
## posti restano vuoti.
static func _pubblico(folla: Array[Giocattolo.Getto], giro: Basis, fuori: float, tabellone: float,
		rng: RandomNumberGenerator) -> void:
	var conta := 0
	for fila in FILE:
		var quota := PRIMA_FILA + GRADINO * float(fila)
		var z := -(fuori + PASSO_FILA * (float(fila) + 0.55))
		var x := -LUNGA * 0.5 + 0.6 + rng.randf_range(0.0, 0.5)
		while x < LUNGA * 0.5 - 0.6:
			var libero := absf(x - tabellone) > TABELLONE.x * 0.5 + 0.5
			if libero and rng.randf() > POSTI_VUOTI:
				_spettatore(folla[rng.randi() % GRUPPI],
						Transform3D(giro * Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)),
						giro * Vector3(x, quota, z)), rng)
				conta += 1
			x += PASSO_POSTO + rng.randf_range(-0.08, 0.12)
	_conta += conta


static var _conta := 0


## Una figurina seduta che guarda il campo (+Z del suo posto): busto nella maglia, testa,
## capelli, e una su tre con le braccia alzate.
static func _spettatore(getto: Giocattolo.Getto, posto: Transform3D, rng: RandomNumberGenerator) -> void:
	# Le maglie un poco più spente dei sei in campo: il pubblico riempie, non gareggia.
	var maglia: Color = Giocattolo.calmo(MAGLIE[rng.randi() % MAGLIE.size()]).lightened(0.12)
	var pelle: Color = PELLI[rng.randi() % PELLI.size()]
	var capelli: Color = CAPELLI[rng.randi() % CAPELLI.size()]
	var alto := rng.randf_range(0.92, 1.08)
	Pista._cubo(getto, Vector3(0.62, 0.66 * alto, 0.40), maglia, posto * Giocattolo._su(0.33 * alto))
	Pista._cubo(getto, Vector3(0.50, 0.46, 0.46), pelle, posto * Giocattolo._su(0.66 * alto + 0.25))
	# I capelli sporgono dalla testa da tutte le parti: con la fronte in pari le due facce
	# lampeggiavano (`tools/facce_doppie.gd`).
	Pista._cubo(getto, Vector3(0.54, 0.18, 0.52), capelli,
			posto * Transform3D(Basis(), Vector3(0, 0.66 * alto + 0.50, -0.02)))
	if rng.randf() < 0.34:
		for lato in [-1.0, 1.0]:
			Pista._cubo(getto, Vector3(0.14, 0.52, 0.14), maglia,
					posto * Transform3D(Basis(Vector3.BACK, lato * -0.35),
					Vector3(lato * 0.26, 0.66 * alto + 0.22, 0.0)))
			# Le mani non arrivano a quelle del vicino: alla stessa quota, sovrapposte,
			# erano due facce in pari.
			Pista._cubo(getto, Vector3(0.14, 0.16, 0.16), pelle,
					posto * Transform3D(Basis(), Vector3(lato * 0.30, 0.66 * alto + 0.54, 0.0)))


## Il tabellone: uno schermo navy in piedi in mezzo alla tribuna, con la cornice chiara,
## la riga di testa e le tre righe dei primi tre.
static func _tabellone(radice: Node3D, getto: Giocattolo.Getto, giro: Basis, fuori: float,
		lungo: float, lato: int) -> void:
	var z := -(fuori + PASSO_FILA * 1.5)
	var centro := giro * Vector3(lungo, QUOTA_TABELLONE + TABELLONE.y * 0.5, z)
	getto.scatola(TABELLONE + Vector3(0.5, 0.5, -0.1), 0.12, Color(0.93, 0.94, 1.0),
			Transform3D(giro, centro + giro * Vector3(0, 0, -0.12)), 1)
	getto.scatola(TABELLONE, 0.1, NAVY, Transform3D(giro, centro), 1)
	# La testata: una fascia più chiara dietro la prima riga.
	getto.scatola(Vector3(TABELLONE.x - 0.5, 1.15, 0.3), 0.06, Color(0.16, 0.22, 0.56),
			Transform3D(giro, centro + giro * Vector3(0, TABELLONE.y * 0.5 - 0.85, 0.14)), 1)

	var nodo := Node3D.new()
	nodo.name = "tabellone_%d" % lato
	nodo.transform = Transform3D(giro, centro + giro * Vector3(0, 0, TABELLONE.z * 0.5 + 0.06))
	radice.add_child(nodo)
	var colori := [Color(0.97, 0.97, 1.0), Comandi.ORO, Comandi.ARGENTO, Color(0.92, 0.62, 0.38)]
	for k in 4:
		var riga := Label3D.new()
		riga.name = "riga_%d" % k
		riga.font = Comandi.carattere_titolo()
		riga.font_size = 128
		riga.pixel_size = 0.0072 if k == 0 else 0.0098
		riga.position = Vector3(0, TABELLONE.y * 0.5 - 0.85 if k == 0
				else TABELLONE.y * 0.5 - 0.95 - 1.28 * float(k), 0.12 if k == 0 else 0.0)
		riga.modulate = colori[k]
		riga.shaded = false
		riga.double_sided = false
		riga.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		riga.text = "PENTAWALL" if k == 0 else ""
		nodo.add_child(riga)


## Un festone di bandierine in cima al muro di fondo, da un capo all'altro: un nodo solo
## con l'origine sul filo, così dondola girando attorno al filo stesso.
static func _festone(radice: Node3D, giro: Basis, fuori: float, materiale: Material, lato: int,
		rng: RandomNumberGenerator) -> void:
	var getto := Giocattolo.Getto.new()
	var quante := int(LUNGA / (BANDIERINA.x + 0.25))
	for i in quante:
		var x := -LUNGA * 0.5 + (BANDIERINA.x + 0.25) * (float(i) + 0.5)
		var tinta: Color = MAGLIE[i % MAGLIE.size()]
		# Un triangolo a punta in giù, a due facce.
		for verso in [1.0, -1.0]:
			var primo := getto.vertici.size()
			getto.vertici.append_array(PackedVector3Array([
					Vector3(x - BANDIERINA.x * 0.5, 0, 0), Vector3(x + BANDIERINA.x * 0.5, 0, 0),
					Vector3(x, -BANDIERINA.y, 0)]))
			for v in 3:
				getto.normali.append(Vector3(0, 0, verso))
				getto.colori.append(tinta)
			getto.indici.append_array(PackedInt32Array([primo, primo + 1, primo + 2])
					if verso > 0.0 else PackedInt32Array([primo, primo + 2, primo + 1]))
	# Appeso sotto la fascia arancio in cima al muro di fondo, davanti alla sua faccia.
	var cima := PRIMA_FILA + GRADINO * float(FILE) + 1.85
	var nodo := MeshInstance3D.new()
	nodo.name = "festone_%d" % lato
	nodo.mesh = getto.mesh()
	nodo.material_override = materiale
	nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nodo.transform = Transform3D(giro, giro * Vector3(0, cima,
			-(fuori + PASSO_FILA * float(FILE) - 0.14)))
	radice.add_child(nodo)


static func _posa(radice: Node3D, mesh: ArrayMesh, materiale: Material, nome: String) -> void:
	if mesh == null:
		return
	var pezzo := MeshInstance3D.new()
	pezzo.name = nome.replace(" ", "_")
	pezzo.mesh = mesh
	pezzo.material_override = materiale
	pezzo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pezzo.add_to_group(Giocattolo.GRUPPO)
	radice.add_child(pezzo)
