class_name Giocattolo
extends RefCounted

## **L'arena-giocattolo** (tappa 10, blocco D): la variante «GIOCATTOLO» dell'aspetto.
##
## Il riferimento l'ha scelto Ludovico il 04/10/2026: NERF Superblast
## (`ricerca-grezza/riferimenti-2026/nerf-superblast/`). Quello che lo fa, e che qui si
## rifà: muri e barriere grossi, imbottiti, a due colori, con le grafiche bianche sopra;
## il pavimento a riquadri; il cielo di giorno con le nuvole; le rocce di un canyon fuori;
## roba in scena (pali della luce, palloni giganti appesi, dardi sparsi a terra). Le tre
## direzioni di prima cambiavano luce e cielo e
## lasciavano le scatole (`LEARNED.md` § 60): qui cambia **di che cosa è fatta** l'arena.
##
## **La pianta e le scatole di collisione restano sotto.** Ogni modulo nasce dalla
## scatola del suo muro e la copre: quello che si vede è quello che ferma il dardo, a
## meno dei bordi che sporgono di qualche centimetro (`SPORGE`). Il ciano resta delle
## sole sponde, il dardo resta l'unica cosa sopra la soglia del bagliore.
##
## **Poco lavoro per la scheda.** I moduli non sono un pezzo per muro: sono pochi
## blocchi grandi, uno per settore dell'arena, con un materiale solo e i colori sui
## vertici. La luce è un sole e il cielo, senza lampade: sui vertici costa niente.

const CIELO := "res://assets/cielo/cielo_giorno.jpg"
const TAPPETO := "res://assets/giocattolo/tappeto.png"
const DECALCHI := "res://assets/giocattolo/decalchi.png"
const DECALCO := "res://assets/giocattolo/decalco.gdshader"

## Le caselle del foglio delle decalcomanie (`tools/prepara_decalchi.py`), in frazioni.
const CASELLE := {
	"PENTAWALL": Rect2(0.0, 0.0, 1.0, 0.25),
	"OCRA": Rect2(0.0, 0.25, 0.5, 0.125), "TURBO": Rect2(0.5, 0.25, 0.5, 0.125),
	"TRIBUNA": Rect2(0.0, 0.375, 0.5, 0.125), "PORTICO": Rect2(0.5, 0.375, 0.5, 0.125),
	"stella": Rect2(0.0, 0.5, 0.25, 0.25), "cinque": Rect2(0.25, 0.5, 0.25, 0.25),
	"frecce": Rect2(0.5, 0.5, 0.25, 0.25), "fulmine": Rect2(0.75, 0.5, 0.25, 0.25),
}
## Il segno di ogni ala sui suoi muri e sui suoi blocchi; il fulmine è del TURBO.
const SEGNI := {"ocra": "stella", "mattone": "fulmine", "tribuna": "cinque", "moquette": "frecce"}
## Il nome dell'ala sul pannello di mezzo del suo perimetro, come le insegne di prima.
const NOMI_ALA := {"perimetro nord": "OCRA", "perimetro est": "TURBO",
		"perimetro ovest": "TRIBUNA", "perimetro sud": "PORTICO"}

## I pezzi nuovi: il collaudo li conta.
const GRUPPO := &"giocattolo"

## Di quanto sporgono dalla scatola del muro cappello, zoccolo e montanti, in metri.
const SPORGE := 0.04

const ARANCIO := Color(0.98, 0.50, 0.08)
const BLU := Color(0.12, 0.27, 0.82)
const ROSSO := Color(0.90, 0.19, 0.22)
const BIANCO := Color(0.93, 0.93, 0.92)
const VIOLA := Color(0.52, 0.30, 0.90)
const GIALLO := Color(1.0, 0.80, 0.15)

## Il corpo e i bordi di ogni tinta della pianta. Ogni ala ha il suo corpo, e i bordi
## sono quasi tutti blu, come in Superblast: è il blu che tiene insieme l'arena. Il
## rosso coi bordi bianchi sembrava un container (scatto del 05/10/2026).
const COPPIE := {
	"ocra": [ARANCIO, BLU],
	"tribuna": [BLU, ARANCIO],
	"mattone": [ROSSO, BLU],
	"moquette": [VIOLA, GIALLO],
}

## I pavimenti: il campo azzurro-lilla di Superblast, il catino più blu, i piani alti
## quasi bianchi (così una quota si legge dall'altra), le rampe gialle col bordo blu.
const CAMPO := Color(0.60, 0.68, 1.0)
const CATINO := Color(0.38, 0.50, 1.0)
const IN_ALTO := Color(0.90, 0.90, 1.0)
const RAMPA := Color(1.0, 0.72, 0.20)
const CORDOLO := Color(1.0, 0.86, 0.30)

## Le rocce del canyon: strati di terracotta, la cima più chiara.
const ROCCE := [Color(0.86, 0.42, 0.22), Color(0.93, 0.54, 0.28), Color(0.80, 0.34, 0.20)]
const CIMA_ROCCIA := Color(0.97, 0.68, 0.42)
const FOSCHIA := Color(0.72, 0.86, 1.0)

## I settori dei moduli: tre per tre sulla pianta, più i perimetri.
const SETTORE := 22.0


# ------------------------------------------------------------------ gli agganci

## Prima della luce per vertice: tetto, muri, pavimenti, rampe, fuori, dardi a terra.
## Quando l'arena si prepara dietro l'ingresso, un passo per fotogramma: tutta insieme,
## sul PC, era mezzo secondo di palco fermo (misurato il 05/10/2026, muri 258 ms).
static func veste(arena: Arena) -> void:
	var pianta: Dictionary = arena.pianta()
	_togli_il_tetto(arena)
	var materiale := _materiale_dei_moduli()
	await _muri(arena, pianta, materiale)
	_pavimenti(arena)
	_rampe(arena, materiale)
	await arena._respiro()
	_bordi(arena, pianta, materiale)
	_pance(arena, pianta, materiale)
	await arena._respiro()
	_fuori(arena, materiale)
	await arena._respiro()
	_dardi_a_terra(arena, pianta, materiale)
	_appesi(arena, pianta, materiale)
	_palloni(arena, materiale)


## Dopo le luci: il cielo, il sole, niente lampade.
static func illumina(arena: Node3D, ambiente: Environment) -> void:
	var pelle := PanoramaSkyMaterial.new()
	pelle.panorama = load(CIELO)
	# Le nuvole bianche restano sotto la soglia del bagliore, che è del dardo.
	pelle.energy_multiplier = 0.92
	var cielo := Sky.new()
	cielo.sky_material = pelle
	cielo.radiance_size = Sky.RADIANCE_SIZE_32
	ambiente.sky = cielo
	ambiente.background_mode = Environment.BG_SKY
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Molta luce dal cielo e poca dal sole: in Superblast l'arancio resta arancio anche
	# sul fianco in ombra. Con 0,70 di cielo e 0,62 di sole diventava marrone.
	ambiente.ambient_light_color = Color(0.90, 0.94, 1.0)
	ambiente.ambient_light_energy = 0.80
	ambiente.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# Lineare: i colori escono come sono scritti, saturi, come in Superblast. Con ACES
	# l'arancio e il blu si spegnevano verso il grigio.
	ambiente.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	ambiente.fog_enabled = false
	for figlio in arena.get_children():
		if figlio is OmniLight3D:
			arena.remove_child(figlio)
			figlio.queue_free()
		elif figlio is DirectionalLight3D:
			var sole := figlio as DirectionalLight3D
			sole.light_color = Color(1.0, 0.95, 0.86)
			sole.light_energy = 0.40
			# Alto e da sud-ovest: le cime piene di luce, i fianchi a metà.
			sole.rotation_degrees = Vector3(-56.0, -40.0, 0.0)
			sole.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY


# ------------------------------------------------------------------ il tetto

## A cielo aperto: via soffitti, fasce e lucernari, **anche dalla collisione** — o i
## dardi si fermerebbero nel vuoto a otto o dodici metri.
static func _togli_il_tetto(arena: Node3D) -> void:
	for figlio in arena.get_children():
		if figlio.is_in_group(Arena.GRUPPO_SOFFITTI) or figlio.is_in_group(Arena.GRUPPO_LUCERNARI):
			arena.remove_child(figlio)
			figlio.queue_free()


# ------------------------------------------------------------------ i muri

static func _materiale_dei_moduli() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.55
	m.metallic_specular = 0.35
	return m


## Ogni muro della pianta diventa un modulo-giocattolo, e la sua scatola smussata di
## prima se ne va (la collisione resta). I pannelli dei moduli si annotano: ci vanno
## sopra le decalcomanie.
static func _muri(arena: Arena, pianta: Dictionary, materiale: Material) -> void:
	var muri: Array = pianta["muri"]
	var per_settore := {}
	for corpo in _pareti(arena):
		for figlio in corpo.get_children():
			if figlio is MeshInstance3D:
				corpo.remove_child(figlio)
				figlio.queue_free()
		var chiave := _settore(corpo.position, String(muri[int(corpo.get_meta(&"muro"))].get("nome", "")))
		if not per_settore.has(chiave):
			per_settore[chiave] = []
		(per_settore[chiave] as Array).append(corpo)
	var pannelli: Array[Dictionary] = []
	for chiave in per_settore:
		var getto := Getto.new()
		for corpo: StaticBody3D in per_settore[chiave]:
			_modulo(getto, muri[int(corpo.get_meta(&"muro"))], corpo.transform, pannelli)
		_posa(arena, getto.mesh(), materiale, "muri %s" % chiave)
		await arena._respiro()
	_decalchi(arena, pianta, pannelli)


static func _pareti(arena: Node3D) -> Array[StaticBody3D]:
	var fuori: Array[StaticBody3D] = []
	for figlio in arena.get_children():
		if figlio is StaticBody3D and figlio.is_in_group(Arena.GRUPPO_PARETI):
			fuori.append(figlio as StaticBody3D)
	return fuori


static func _settore(dove: Vector3, nome: String) -> String:
	if nome.begins_with("perimetro"):
		return nome
	var x := clampi(int(floor((dove.x + 33.0) / SETTORE)), 0, 2)
	var z := clampi(int(floor((dove.z + 33.0) / SETTORE)), 0, 2)
	return "%d-%d" % [x, z]


## **Il modulo**: il corpo, che è la scatola stessa arrotondata, nel colore della sua
## tinta; lo zoccolo e il cappello nel colore dei bordi; le fasce alle quote dei piani
## (3,5 e 7 metri), che danno il ritmo ai muri alti; i montanti, che dividono un muro
## lungo in pannelli come una barriera fatta di pezzi; e in ogni pannello i cuscini, gonfi
## fuori dalla scatola. Un blocco (cassone, cassa, box, gradinata) ha i montanti sugli
## angoli e i cuscini sulle quattro facce. Colonne e piloni sono tondi, a anelli.
static func _modulo(getto: Getto, m: Dictionary, posto: Transform3D,
		pannelli: Array[Dictionary]) -> void:
	var nome := String(m.get("nome", ""))
	var coppia: Array = COPPIE.get(String(m.get("tinta", "")), COPPIE["ocra"])
	var corpo: Color = coppia[0]
	var bordo: Color = coppia[1]
	var lx := float(m["misura"][0])
	var lz := float(m["misura"][1])
	var alto := float(m["alto"])
	var quota := float(m["quota"])
	if Arena._e_tondo(nome) and absf(lx - lz) < 0.01:
		_pilone(getto, lx * 0.5, alto, quota, corpo, bordo, posto)
		return
	var spessore := minf(lx, lz)
	var sotto := -alto * 0.5
	var sopra := alto * 0.5
	getto.scatola(Vector3(lx, alto, lz), clampf(spessore * 0.3, 0.06, 0.3), corpo, posto, 2,
			minf(0.22, 0.05 * alto))
	var zoccolo := minf(0.40, alto * 0.2)
	getto.scatola(Vector3(lx + SPORGE * 1.5, zoccolo, lz + SPORGE * 1.5), minf(0.12, zoccolo * 0.45),
			bordo, posto * _su(sotto + zoccolo * 0.5))
	var cappello := minf(0.36, alto * 0.22)
	getto.scatola(Vector3(lx + SPORGE * 2.0, cappello, lz + SPORGE * 2.0), cappello * 0.48,
			bordo, posto * _su(sopra - cappello * 0.5))
	# Le righe dei pannelli: dallo zoccolo al cappello, spezzate dalle fasce.
	var tagli: Array[float] = [sotto + zoccolo]
	for piano in [3.5, 7.0]:
		var y: float = piano - (quota + alto * 0.5)
		if y - 0.12 > sotto + zoccolo + 0.4 and y + 0.12 < sopra - cappello - 0.4:
			getto.scatola(Vector3(lx + SPORGE * 1.2, 0.24, lz + SPORGE * 1.2), 0.1, bordo,
					posto * _su(y))
			tagli.append_array([y - 0.12, y + 0.12])
	tagli.append(sopra - cappello)
	var imbottitura := corpo.lightened(0.07)
	var dentro := -Vector3(posto.origin.x, 0.0, posto.origin.z)
	if spessore < 1.3:
		# Un muro: montanti a ogni capo e in mezzo, a pannelli larghi sui muri alti.
		var lungo := Vector3.RIGHT if lx >= lz else Vector3.BACK
		var attraverso := Vector3.BACK if lx >= lz else Vector3.RIGHT
		var lunghezza := maxf(lx, lz)
		var quanti := _pannelli(lunghezza, alto)
		var largo := 0.34
		var montanti: Array[float] = []
		for k in quanti + 1:
			var t := -lunghezza * 0.5 + largo * 0.5 + (lunghezza - largo) * float(k) / float(quanti)
			montanti.append(t)
			getto.scatola(lungo * largo + attraverso * (spessore + SPORGE * 2.0) + Vector3.UP * alto,
					0.13, bordo, posto * Transform3D(Basis(), lungo * t))
		for lato in [-1.0, 1.0]:
			var fuori: Vector3 = attraverso * lato
			# Del perimetro si vede solo la faccia di dentro.
			if nome.begins_with("perimetro") and (posto.basis * fuori).dot(dentro) <= 0.0:
				continue
			for k in quanti:
				var da := montanti[k] + largo * 0.5
				var a := montanti[k + 1] - largo * 0.5
				_cuscini(getto, pannelli, m, posto, lungo * ((da + a) * 0.5), lungo, fuori, a - da,
						spessore * 0.5, tagli, imbottitura, bordo, k)
	else:
		# Un blocco: i montanti sugli angoli, che sporgono dai due lati.
		var lato := 0.42
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var dove := Vector3(sx * (lx * 0.5 - lato * 0.5 + SPORGE),
						0.0, sz * (lz * 0.5 - lato * 0.5 + SPORGE))
				getto.scatola(Vector3(lato, alto, lato), 0.16, bordo, posto * Transform3D(Basis(), dove))
		for asse in [Vector3.RIGHT, Vector3.BACK]:
			var lungo := Vector3.BACK if asse == Vector3.RIGHT else Vector3.RIGHT
			var lunghezza := lz if asse == Vector3.RIGHT else lx
			var mezzo := (lx if asse == Vector3.RIGHT else lz) * 0.5
			for segno in [-1.0, 1.0]:
				_cuscini(getto, pannelli, m, posto, Vector3.ZERO, lungo, asse * segno,
						lunghezza - 2.0 * (lato - SPORGE), mezzo, tagli, imbottitura, bordo, 0)


## **I cuscini** di un pannello, uno per riga, gonfi di `SPORGE` fuori dalla scatola e un
## poco più chiari del corpo: è l'imbottitura, la cosa che fa «gommapiuma» invece di
## «muro». Ognuno si annota per le decalcomanie, con la riga più alta segnata come
## principale.
static func _cuscini(getto: Getto, pannelli: Array[Dictionary], m: Dictionary,
		posto: Transform3D, centro: Vector3, lungo: Vector3, fuori: Vector3, largo: float,
		mezzo: float, tagli: Array[float], colore: Color, bordo: Color, colonna: int) -> void:
	if largo < 0.6:
		return
	var righe := int(tagli.size() / 2.0)
	var principale := 0
	for r in righe:
		if tagli[2 * r + 1] - tagli[2 * r] > tagli[2 * principale + 1] - tagli[2 * principale]:
			principale = r
	var gonfio := 0.16
	for r in righe:
		var y0 := tagli[2 * r]
		var y1 := tagli[2 * r + 1]
		if y1 - y0 < 0.5:
			continue
		var mezzo_y := Vector3.UP * ((y0 + y1) * 0.5)
		getto.scatola(lungo * (largo - 0.14) + fuori.abs() * gonfio + Vector3.UP * (y1 - y0 - 0.14),
				0.07, colore, posto * Transform3D(Basis(),
						centro + fuori * (mezzo + SPORGE - gonfio * 0.5) + mezzo_y), 1, 0.1)
		pannelli.append({
			"centro": posto * (centro + fuori * (mezzo + SPORGE) + mezzo_y),
			"fuori": (posto.basis * fuori).normalized(),
			"largo": largo - 0.14, "alto": y1 - y0 - 0.14,
			"riga": r, "principale": r == principale, "colonna": colonna,
			"muro": m, "bordo": bordo,
		})


## Un pilone, una colonna, un pilastro: il fusto tondo coi bordi morbidi, l'anello in
## basso e quello in cima nel colore dei bordi, e le fasce alle quote dei piani.
static func _pilone(getto: Getto, raggio: float, alto: float, quota: float, corpo: Color,
		bordo: Color, posto: Transform3D) -> void:
	var base := posto * _su(-alto * 0.5)
	getto.tondo(raggio, alto, 0.16, corpo, base)
	getto.tondo(raggio + SPORGE, 0.40, 0.12, bordo, base)
	getto.tondo(raggio + SPORGE * 1.2, 0.36, 0.15, bordo, base * _su(alto - 0.36))
	for piano in [3.5, 7.0]:
		var y: float = piano - quota
		if y > 0.9 and y < alto - 0.9:
			getto.tondo(raggio + SPORGE * 0.8, 0.24, 0.1, bordo, base * _su(y - 0.12))


static func _su(y: float) -> Transform3D:
	return Transform3D(Basis(), Vector3(0, y, 0))


## In quanti pannelli i montanti dividono un muro. Sui muri alti i pannelli sono larghi
## quasi dieci metri, abbastanza per una scritta; i muri bassi sono a pezzi più corti,
## come le barriere di Superblast.
static func _pannelli(lunghezza: float, alto: float) -> int:
	return maxi(1, int(round(lunghezza / (9.5 if alto >= 6.0 else 4.5))))


## **Le decalcomanie** (`tools/prepara_decalchi.py`): grafiche bianche col contorno del
## colore dei bordi, sui cuscini. Sui perimetri, nella riga di mezzo, il nome del gioco e
## quello dell'ala alternati al cinque; sul catino, da fuori, il nome del gioco; sugli
## altri muri e sui blocchi il segno della loro ala, nella riga più alta. Dove c'è una
## sponda niente: il ciano resta l'unica cosa accesa sul muro. Tutte insieme sono una
## mesh sola, una chiamata di disegno.
static func _decalchi(arena: Node3D, pianta: Dictionary, pannelli: Array[Dictionary]) -> void:
	var foglio := Foglio.new()
	for p in pannelli:
		var m: Dictionary = p["muro"]
		var nome := String(m.get("nome", ""))
		var centro: Vector3 = p["centro"]
		var fuori: Vector3 = p["fuori"]
		var cosa := ""
		if nome.begins_with("perimetro"):
			if int(p["riga"]) != 1:
				continue
			match int(p["colonna"]):
				3: cosa = NOMI_ALA.get(nome, "PENTAWALL")
				1, 5: cosa = "PENTAWALL"
				_: cosa = "cinque"
		elif nome.begins_with("catino, faccia"):
			if int(p["riga"]) != 1 or fuori.dot(-Vector3(centro.x, 0.0, centro.z)) > 0.0:
				continue
			cosa = "PENTAWALL"
		elif bool(p["principale"]) and minf(float(p["largo"]), float(p["alto"])) >= 1.2:
			cosa = SEGNI.get(String(m.get("tinta", "")), "stella")
		else:
			continue
		var casella: Rect2 = CASELLE[cosa]
		var aspetto := casella.size.x / casella.size.y
		var largo := minf(float(p["largo"]) * 0.86, float(p["alto"]) * 0.8 * aspetto)
		if _sponda_vicina(pianta, centro, fuori, largo * 0.5 + 0.4):
			continue
		foglio.quadro(centro + fuori * 0.012, fuori, Vector2(largo, largo / aspetto), casella,
				p["bordo"])
	var materiale := ShaderMaterial.new()
	materiale.shader = load(DECALCO)
	materiale.set_shader_parameter("foglio", load(DECALCHI))
	_posa(arena, foglio.mesh(), materiale, "decalcomanie")


## Se sulla stessa faccia, vicino a dove andrebbe la scritta, c'è una sponda. Una sponda
## sull'altra faccia del muro sta mezzo metro dietro, e non conta.
static func _sponda_vicina(pianta: Dictionary, dove: Vector3, fuori: Vector3, raggio: float) -> bool:
	for s in pianta["sponde"]:
		var centro := Vector3(float(s["centro"][0]), float(s["quota"]) + float(s["faccia"][1]) * 0.5,
				float(s["centro"][1]))
		if (centro - dove).dot(fuori) < -0.3:
			continue
		var meta := float(s["faccia"][0]) * 0.5
		if Vector2(centro.x - dove.x, centro.z - dove.z).length() < raggio + meta \
				and absf(centro.y - dove.y) < 2.0 + float(s["faccia"][1]) * 0.5:
			return true
	return false


# ------------------------------------------------------------------ pavimenti e rampe

## I tappetini a incastro (`tools/prepara_tappeti.py`): un'immagine in grigi, il colore
## lo mette la quota. Le coordinate dei pavimenti sono già prese dal mondo, quattro
## metri per giro, quindi i tappetini di due zone vicine combaciano.
static func _pavimenti(arena: Node3D) -> void:
	var pronti := {}
	var tessuto: Texture2D = load(TAPPETO)
	var zone: Array = (arena.call("pianta") as Dictionary)["zone"]
	for figlio in arena.get_children():
		if not (figlio is StaticBody3D and figlio.has_meta(&"zona")):
			continue
		var quota := float(zone[int(figlio.get_meta(&"zona"))]["quota"])
		var colore := CATINO if quota < -1.0 else (IN_ALTO if quota > 1.0 else CAMPO)
		if not pronti.has(colore):
			var m := StandardMaterial3D.new()
			m.albedo_texture = tessuto
			m.albedo_color = colore
			m.roughness = 0.85
			m.metallic_specular = 0.2
			pronti[colore] = m
		for pezzo in figlio.get_children():
			if pezzo is MeshInstance3D:
				(pezzo as MeshInstance3D).material_override = pronti[colore]


## Le rampe: uno scivolo giallo coi bordi blu, come quelli di Superblast. La lastra di
## prima e i suoi cordoli se ne vanno; la collisione resta.
static func _rampe(arena: Node3D, materiale: Material) -> void:
	var getto := Getto.new()
	for figlio in arena.get_children():
		if not (figlio is StaticBody3D and figlio.is_in_group(Arena.GRUPPO_RAMPE)):
			continue
		var corpo := figlio as StaticBody3D
		var misura := Vector3.ZERO
		for pezzo in corpo.get_children():
			if pezzo is CollisionShape3D and (pezzo as CollisionShape3D).shape is BoxShape3D:
				misura = ((pezzo as CollisionShape3D).shape as BoxShape3D).size
			elif pezzo is MeshInstance3D:
				corpo.remove_child(pezzo)
				pezzo.queue_free()
		getto.scatola(misura, 0.1, RAMPA, corpo.transform)
		for lato in [-1.0, 1.0]:
			getto.scatola(Vector3(0.26, misura.y + 0.08, misura.z + 0.02), 0.1, BLU,
					corpo.transform * Transform3D(Basis(),
							Vector3(lato * (misura.x * 0.5 - 0.11), 0.04, 0.0)))
		# Le frecce in salita: una V bianca a terra ogni due metri. La rampa va da `da` ad
		# `a`, che è il suo -Z, e non sempre `a` sta più in alto: se scende, la V si gira.
		var salita := Basis() if (-corpo.transform.basis.z).y > 0.0 else Basis(Vector3.UP, PI)
		var passi := int(floor(misura.z / 2.2))
		for k in passi:
			var z := misura.z * 0.5 - 1.4 - 2.2 * float(k)
			for verso in [-1.0, 1.0]:
				var braccio := Transform3D(Basis(Vector3.UP, verso * deg_to_rad(52.0)),
						Vector3(verso * misura.x * 0.13, misura.y * 0.5 + 0.005, z + 0.5))
				getto.scatola(Vector3(0.22, 0.02, misura.x * 0.36), 0.008, BIANCO,
						corpo.transform * Transform3D(salita, Vector3.ZERO) * braccio, 1)
	_posa(arena, getto.mesh(), materiale, "rampe")


## **I bordi dei piani alti**: un paraurti blu che copre il fianco della lastra, con la
## riga gialla sopra, come il bordo di sicurezza di un tappeto da palestra per bambini.
## Senza, le terrazze erano lastre grigie spoglie (scatto del 05/10/2026), mentre le
## piattaforme di Superblast hanno il bordo imbottito. Il bordo si decide a passi di
## mezzo metro, anche dove arriva una rampa: i cordoli di `Arena._cordoli` lasciavano
## scoperto tutto il lato su cui una rampa arriva nel mezzo, e qui prendono il loro
## posto. Quello della gradinata, che non è un piano, diventa giallo e resta.
static func _bordi(arena: Node3D, pianta: Dictionary, materiale: Material) -> void:
	for figlio in arena.get_children():
		if not (figlio is MeshInstance3D):
			continue
		var pezzo := figlio as MeshInstance3D
		var m := pezzo.material_override as StandardMaterial3D
		if m == null or not m.albedo_color.is_equal_approx(Muratura.CORDOLO):
			continue
		var piano := pezzo.position.y - Muratura.CORDOLO_ALTEZZA * 0.5
		if absf(piano - 3.5) < 0.01 or absf(piano - 7.0) < 0.01:
			arena.remove_child(pezzo)
			pezzo.queue_free()
		else:
			pezzo.material_override = Muratura.acceso(CORDOLO, 0.2)
	var getto := Getto.new()
	var zone: Array = pianta["zone"]
	var pezzi: Array = []
	for z in zone.size():
		pezzi.append(arena.call("pezzi_della_zona", z))
	for z in zone.size():
		var quota := float(zone[z]["quota"])
		if quota <= 0.0:
			continue
		for contorno: PackedVector2Array in pezzi[z]:
			for i in contorno.size():
				var da := contorno[i]
				var a := contorno[(i + 1) % contorno.size()]
				var verso := (a - da).normalized()
				var fuori := Vector2(verso.y, -verso.x)
				if Geometry2D.is_point_in_polygon((da + a) * 0.5 + fuori * 0.01, contorno):
					fuori = -fuori
				var passi := maxi(1, roundi(da.distance_to(a) / 0.5))
				var inizio := -1
				for k in passi + 1:
					var qui := da.lerp(a, (float(k) + 0.5) / float(passi))
					var bordo := k < passi and not _piano_a(zone, pezzi, qui + fuori * 0.8, quota) \
							and not _rampa_in(pianta, qui, quota)
					if bordo and inizio < 0:
						inizio = k
					elif not bordo and inizio >= 0:
						_paraurti(getto, da.lerp(a, float(inizio) / float(passi)),
								da.lerp(a, float(k) / float(passi)), quota)
						inizio = -1
	_posa(arena, getto.mesh(), materiale, "paraurti")


## **La pancia dei piani alti**: terrazze, passerella e ballatoio sono lastre sospese, e
## da sotto si vedeva il tappetino bianco a rovescio (scatto della tribuna, 05/10/2026).
## Una copertura blu, appena sotto la lastra: da sotto il piano si legge pieno.
static func _pance(arena: Node3D, pianta: Dictionary, materiale: Material) -> void:
	var getto := Getto.new()
	var zone: Array = pianta["zone"]
	for z in zone.size():
		var quota := float(zone[z]["quota"])
		if quota <= 0.0:
			continue
		for contorno: PackedVector2Array in arena.call("pezzi_della_zona", z):
			getto.piatto(contorno, quota - Arena.SPESSORE_PIANO - 0.006, Vector3.DOWN,
					BLU.darkened(0.1))
	_posa(arena, getto.mesh(), materiale, "pance")


static func _paraurti(getto: Getto, da: Vector2, a: Vector2, quota: float) -> void:
	var lungo := da.distance_to(a)
	if lungo < 0.6:
		return
	var mezzo := (da + a) * 0.5
	var giro := Basis(Vector3.UP, atan2(-(a - da).y, (a - da).x))
	getto.scatola(Vector3(lungo, 0.66, 0.24), 0.1, BLU,
			Transform3D(giro, Vector3(mezzo.x, quota - 0.30, mezzo.y)))
	getto.scatola(Vector3(lungo, 0.06, 0.2), 0.02, CORDOLO,
			Transform3D(giro, Vector3(mezzo.x, quota + 0.03, mezzo.y)), 1)


## C'è un pavimento a quella quota, in quel punto? Sulla pianta già ritagliata dalle
## rampe, come in `Arena._piano_alla_quota`.
static func _piano_a(zone: Array, pezzi: Array, dove: Vector2, quota: float) -> bool:
	for z in zone.size():
		if absf(float(zone[z]["quota"]) - quota) > 0.2:
			continue
		for pezzo: PackedVector2Array in pezzi[z]:
			if Geometry2D.is_point_in_polygon(dove, pezzo):
				return true
	return false


## Arriva una rampa, a quella quota, in quel punto del bordo? Lì il bordo è l'ingresso.
static func _rampa_in(pianta: Dictionary, dove: Vector2, quota: float) -> bool:
	for r in pianta["rampe"]:
		var mezza := float(r["larghezza"]) * 0.5 + 0.3
		for capo in [[r["da"], r["quota_da"]], [r["a"], r["quota_a"]]]:
			var punto := Vector2(float(capo[0][0]), float(capo[0][1]))
			if absf(float(capo[1]) - quota) < 0.2 and punto.distance_to(dove) < mezza:
				return true
	return false


# ------------------------------------------------------------------ fuori

## **Fuori dai perimetri**: il canyon e i pali della luce. Sta tutto oltre i muri, più
## alto di loro: da dentro se ne vede la parte che spunta sopra i dodici metri, ed è
## lì che va l'orizzonte. Niente collisione e niente camera che ci arrivi.
static func _fuori(arena: Node3D, materiale: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var getti: Array[Getto] = [Getto.new(), Getto.new(), Getto.new(), Getto.new()]
	# Le rocce: un anello di formazioni larghe e stratificate fra 54 e 72 metri dal
	# centro, che si toccano e fanno la parete del canyon; alte abbastanza da spuntare
	# sopra il perimetro anche guardando dall'altra parte dell'arena.
	var quante := 14
	for k in quante:
		var angolo := TAU * float(k) / float(quante) + rng.randf_range(-0.08, 0.08)
		var distanza := rng.randf_range(56.0, 72.0)
		var centro := Vector2(cos(angolo), sin(angolo)) * distanza
		var lontano := clampf((distanza - 56.0) / 30.0, 0.0, 1.0) * 0.2
		_roccia(getti[_quadrante(centro)], centro, rng.randf_range(12.0, 17.0),
				rng.randf_range(22.0, 34.0), lontano, rng)
	# Un secondo anello, più lontano e più chiaro: la profondità.
	for k in 12:
		var angolo := TAU * (float(k) + 0.5) / 12.0 + rng.randf_range(-0.1, 0.1)
		var distanza := rng.randf_range(105.0, 135.0)
		var centro := Vector2(cos(angolo), sin(angolo)) * distanza
		_roccia(getti[_quadrante(centro)], centro, rng.randf_range(18.0, 26.0),
				rng.randf_range(30.0, 46.0), 0.45, rng)
	# I pali della luce: sugli angoli e a metà dei lati, appena fuori dal perimetro.
	for dove in [Vector2(-39, -39), Vector2(39, -39), Vector2(39, 39), Vector2(-39, 39),
			Vector2(0, -40), Vector2(40, 0), Vector2(0, 40), Vector2(-40, 0)]:
		_palo(getti[_quadrante(dove)], dove)
	for k in getti.size():
		_posa(arena, getti[k].mesh(), materiale, "fuori %d" % k)


static func _quadrante(dove: Vector2) -> int:
	return (1 if dove.x > 0.0 else 0) + (2 if dove.y > 0.0 else 0)


## Una formazione del canyon: strati di roccia uno sull'altro, ognuno più stretto in
## cima che alla base e un po' rientrato rispetto a quello sotto, a fasce di colore,
## su un contorno morbido e allungato. È la stratificazione che fa «canyon»: i prismi
## dritti del primo scatto (05/10/2026) sembravano una città di scatoloni marroni.
## `lontano` la sbianca verso il cielo.
static func _roccia(getto: Getto, centro: Vector2, raggio: float, alto: float, lontano: float,
		rng: RandomNumberGenerator) -> void:
	var lati := 14
	var grezzi: Array[float] = []
	for k in lati:
		grezzi.append(rng.randf_range(0.68, 1.14))
	var forma := PackedVector2Array()
	var giro := rng.randf() * TAU
	var allungo := rng.randf_range(1.1, 1.5)
	for k in lati:
		# Ogni raggio fa la media coi vicini: il contorno ondeggia invece di spezzarsi.
		var r := (grezzi[k] * 2.0 + grezzi[(k + 1) % lati] + grezzi[(k + lati - 1) % lati]) * 0.25
		var a := TAU * float(k) / float(lati)
		forma.append(Vector2(cos(a) * allungo, sin(a)).rotated(giro) * r)
	var strati := rng.randi_range(4, 7)
	var y := -2.0
	var scala := raggio
	var spostato := centro
	for s in strati:
		var h := (alto + 2.0) / float(strati) * rng.randf_range(0.75, 1.25)
		var stringe := rng.randf_range(0.84, 0.95)
		var sotto := PackedVector2Array()
		var sopra := PackedVector2Array()
		for punto in forma:
			sotto.append(spostato + punto * scala)
			sopra.append(spostato + punto * scala * stringe)
		# Gli strati bassi più scuri: il piede della roccia sta nella sua ombra.
		var fianco: Color = (ROCCE[s % ROCCE.size()] as Color).darkened(
				0.16 * (1.0 - float(s) / float(strati)))
		getto.tronco(sotto, sopra, y, y + h, fianco.lerp(FOSCHIA, lontano),
				CIMA_ROCCIA.lerp(FOSCHIA, lontano))
		y += h
		scala *= stringe * rng.randf_range(0.9, 1.0)
		spostato += Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * raggio * 0.04


## Un palo della luce da stadio-giocattolo: fusto arancio su una base blu, e in cima la
## batteria dei fari, bianca, girata verso il centro.
static func _palo(getto: Getto, dove: Vector2) -> void:
	var base := Transform3D(Basis(), Vector3(dove.x, -0.5, dove.y))
	getto.tondo(0.9, 1.6, 0.3, BLU, base)
	getto.tondo(0.36, 25.0, 0.12, ARANCIO, base)
	var verso := -dove.normalized()
	var testa := Transform3D(Basis(Vector3.UP, atan2(verso.x, verso.y)), Vector3(dove.x, 24.0, dove.y))
	getto.scatola(Vector3(4.2, 0.5, 0.5), 0.2, ARANCIO, testa * _su(-1.6))
	getto.scatola(Vector3(3.8, 2.4, 0.6), 0.22, BIANCO, testa)
	for i in 3:
		for j in 2:
			getto.scatola(Vector3(0.9, 0.8, 0.16), 0.08, Color(1.0, 0.96, 0.78),
					testa * Transform3D(Basis(), Vector3(-1.2 + 1.2 * float(i), -0.5 + 1.0 * float(j), 0.32)))


# ------------------------------------------------------------------ in scena

## **I dardi a terra**, come dopo una partita vera: blu con la punta arancio, a mucchietti
## lungo i muri. Stanno sul pavimento e non hanno collisione: un dardo vivo ci passa
## sopra, e sono troppo bassi per nascondere qualcuno.
static func _dardi_a_terra(arena: Node3D, pianta: Dictionary, materiale: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var getto := Getto.new()
	var dardo := _profilo_del_dardo()
	for zona in pianta["zone"]:
		var contorno := PackedVector2Array()
		for p in zona["poligono"]:
			contorno.append(Vector2(float(p[0]), float(p[1])))
		var quota := float(zona["quota"])
		for k in 2:
			var centro := _punto_libero(contorno, pianta, rng)
			if centro == Vector2.INF:
				continue
			for d in rng.randi_range(3, 6):
				var dove := centro + Vector2(rng.randf_range(-1.1, 1.1), rng.randf_range(-1.1, 1.1))
				if not Geometry2D.is_point_in_polygon(dove, contorno) or _dentro_un_muro(dove, pianta, 0.4):
					continue
				# Disteso a terra: l'asse del dardo (che nasce in piedi) va in orizzontale.
				var giro := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.5)
				getto.tornio(dardo[0], dardo[1], BLU, Transform3D(giro,
						Vector3(dove.x, quota + 0.07, dove.y)), 6, ARANCIO, 4)
	_posa(arena, getto.mesh(), materiale, "dardi a terra")


## Il profilo di un dardo di gommapiuma lungo mezzo metro, dalla coda alla punta: più
## grande del vero, perché da tre metri si legga.
static func _profilo_del_dardo() -> Array:
	var punti := PackedVector2Array([Vector2(0.0, -0.24), Vector2(0.065, -0.24),
			Vector2(0.07, -0.235), Vector2(0.07, 0.17), Vector2(0.074, 0.18),
			Vector2(0.074, 0.22), Vector2(0.05, 0.255), Vector2(0.0, 0.265)])
	var normali := PackedVector2Array([Vector2(0, -1), Vector2(0, -1), Vector2(1, 0),
			Vector2(1, 0), Vector2(1, 0), Vector2(0.8, 0.6), Vector2(0.5, 0.86), Vector2(0, 1)])
	return [punti, normali]


## Un punto dentro il contorno, lontano dai muri e dalle rampe: dove un mucchietto di
## dardi non entra in niente.
static func _punto_libero(contorno: PackedVector2Array, pianta: Dictionary,
		rng: RandomNumberGenerator) -> Vector2:
	var minimo := contorno[0]
	var massimo := contorno[0]
	for p in contorno:
		minimo = minimo.min(p)
		massimo = massimo.max(p)
	for tentativo in 40:
		var p := Vector2(rng.randf_range(minimo.x, massimo.x), rng.randf_range(minimo.y, massimo.y))
		if Geometry2D.is_point_in_polygon(p, contorno) and not _dentro_un_muro(p, pianta, 1.4) \
				and not _sopra_una_rampa(p, pianta):
			return p
	return Vector2.INF


static func _dentro_un_muro(p: Vector2, pianta: Dictionary, margine: float) -> bool:
	for m in pianta["muri"]:
		var c := Vector2(float(m["centro"][0]), float(m["centro"][1]))
		var locale := (p - c).rotated(deg_to_rad(float(m.get("giro", 0.0))))
		if absf(locale.x) < float(m["misura"][0]) * 0.5 + margine \
				and absf(locale.y) < float(m["misura"][1]) * 0.5 + margine:
			return true
	return false


static func _sopra_una_rampa(p: Vector2, pianta: Dictionary) -> bool:
	for r in pianta["rampe"]:
		var da := Vector2(float(r["da"][0]), float(r["da"][1]))
		var a := Vector2(float(r["a"][0]), float(r["a"][1]))
		var lungo := (a - da).normalized()
		var t := (p - da).dot(lungo)
		var lato := absf((p - da).dot(Vector2(-lungo.y, lungo.x)))
		if t > -1.5 and t < da.distance_to(a) + 1.5 and lato < float(r["larghezza"]) * 0.5 + 1.0:
			return true
	return false


## **I palloni giganti** a spicchi, appesi sopra le ali come quello della schermata di
## Superblast: arancio, bianco e blu, alti più dei muri, fuori dallo spazio in cui si
## tira. Non hanno collisione, e un dardo lassù non ci arriva quasi mai.
static func _palloni(arena: Node3D, materiale: Material) -> void:
	var getto := Getto.new()
	var profilo := PackedVector2Array()
	var normali := PackedVector2Array()
	for k in 13:
		var t := -PI * 0.5 + PI * float(k) / 12.0
		profilo.append(Vector2(cos(t), sin(t)))
		normali.append(Vector2(cos(t), sin(t)))
	var spicchi := [ARANCIO, BIANCO, BLU, ARANCIO, BIANCO, BLU]
	for posto in [Vector3(-15.0, 19.0, -16.0), Vector3(22.0, 18.0, 4.0), Vector3(-21.0, 20.5, 20.0)]:
		var raggio := 3.2
		var palla := Transform3D(Basis.from_scale(Vector3.ONE * raggio), posto)
		for k in spicchi.size():
			getto.tornio(profilo, normali, spicchi[k], palla, 4, Color.BLACK, 0,
					TAU * float(k) / float(spicchi.size()), TAU / float(spicchi.size()))
		for k in 3:
			var a := TAU * float(k) / 3.0
			getto.tondo(0.05, 60.0, 0.02, Color(0.20, 0.22, 0.34), Transform3D(Basis(),
					posto + Vector3(cos(a) * 1.2, raggio * 0.85, sin(a) * 1.2)), 6)
	_posa(arena, getto.mesh(), materiale, "palloni")


## **La sponda sopra la buca** (`sdraiata: soffitto`, a 11,9 metri sul catino) è gioco,
## non tetto: resta, e a cielo aperto la reggono quattro cavi che salgono fuori
## dall'inquadratura, come la palla gigante di Superblast. Il tabellone, che era appeso
## al soffitto coi suoi cavi corti, adesso è appeso a lei.
static func _appesi(arena: Node3D, pianta: Dictionary, materiale: Material) -> void:
	var getto := Getto.new()
	for s in pianta["sponde"]:
		if String(s.get("sdraiata", "")) != "soffitto":
			continue
		var meta := Vector2(float(s["faccia"][0]), float(s["faccia"][1])) * 0.5 - Vector2(0.3, 0.3)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				getto.tondo(0.05, 70.0, 0.02, Color(0.20, 0.22, 0.34), Transform3D(Basis(),
						Vector3(float(s["centro"][0]) + sx * meta.x, float(s["quota"]),
								float(s["centro"][1]) + sz * meta.y)), 6)
	_posa(arena, getto.mesh(), materiale, "cavi")


# ------------------------------------------------------------------ attrezzi

static func _posa(arena: Node3D, mesh: ArrayMesh, materiale: Material, nome: String) -> void:
	if mesh == null:
		return
	var pezzo := MeshInstance3D.new()
	pezzo.name = nome.replace(" ", "_")
	pezzo.mesh = mesh
	pezzo.material_override = materiale
	pezzo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pezzo.add_to_group(GRUPPO)
	arena.add_child(pezzo)


## **Il getto**: vertici, normali e colori di tanti pezzi messi insieme, che diventano
## una mesh sola. Ogni pezzo arriva già al suo posto e col suo colore: per la scheda,
## un settore intero di muri è una chiamata di disegno.
class Getto:
	var vertici := PackedVector3Array()
	var normali := PackedVector3Array()
	var colori := PackedColorArray()
	var indici := PackedInt32Array()

	func mesh() -> ArrayMesh:
		if indici.is_empty():
			return null
		var dati := []
		dati.resize(Mesh.ARRAY_MAX)
		dati[Mesh.ARRAY_VERTEX] = vertici
		dati[Mesh.ARRAY_NORMAL] = normali
		dati[Mesh.ARRAY_COLOR] = colori
		dati[Mesh.ARRAY_INDEX] = indici
		var fuori := ArrayMesh.new()
		fuori.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, dati)
		return fuori

	## Una scatola con gli spigoli arrotondati: ogni faccia è una griglia fitta sugli
	## spigoli, e ogni vertice si proietta sulla scatola più piccola gonfiata del raggio
	## (come `Muratura.scatola_smussata`). Il piano in mezzo è un quadrilatero solo: la
	## luce è un sole e il cielo, uguale su tutta la faccia, e non c'è nebbia. Con
	## `sfuma` il colore scurisce verso il basso, di quella frazione al piede: un'ombra
	## finta che costa niente, perché sta già nei colori dei vertici.
	func scatola(misura: Vector3, raggio: float, colore: Color, posto: Transform3D,
			segmenti := 2, sfuma := 0.0) -> void:
		var meta := misura * 0.5
		var r := minf(raggio, minf(meta.x, minf(meta.y, meta.z)) * 0.98)
		var interno := meta - Vector3.ONE * r
		var campioni := [Giocattolo._campioni(meta.x, r, segmenti),
				Giocattolo._campioni(meta.y, r, segmenti), Giocattolo._campioni(meta.z, r, segmenti)]
		var giro := posto.basis.orthonormalized()
		for asse in 3:
			for segno in [-1.0, 1.0]:
				var asse_u := (asse + 1) % 3
				var asse_v := (asse + 2) % 3
				var us: PackedFloat32Array = campioni[asse_u]
				var vs: PackedFloat32Array = campioni[asse_v]
				var fuori := Vector3.ZERO
				fuori[asse] = segno
				var primo := vertici.size()
				for i in us.size():
					for j in vs.size():
						var p := Vector3.ZERO
						p[asse] = meta[asse] * segno
						p[asse_u] = us[i]
						p[asse_v] = vs[j]
						var dentro := p.clamp(-interno, interno)
						var d := p - dentro
						var n := d.normalized() if d.length_squared() > 0.0000001 else fuori
						var punto := dentro + n * r
						vertici.append(posto * punto)
						normali.append(giro * n)
						colori.append(colore.darkened(sfuma * (0.5 - punto.y / misura.y))
								if sfuma > 0.0 else colore)
				# Godot disegna il senso orario visto da fuori: la griglia va da u a v,
				# e u × v è l'asse della faccia, quindi il verso dipende solo dal segno.
				var righe := vs.size()
				for i in us.size() - 1:
					for j in righe - 1:
						var a := primo + i * righe + j
						var b := a + righe
						var c := b + 1
						var e := a + 1
						if segno > 0.0:
							indici.append_array(PackedInt32Array([a, c, b, a, e, c]))
						else:
							indici.append_array(PackedInt32Array([a, b, c, a, c, e]))

	## Un cilindro coi bordi arrotondati, in piedi sulla base di `posto`.
	func tondo(raggio: float, alto: float, bordo: float, colore: Color, posto: Transform3D,
			lati := 20) -> void:
		var e := minf(bordo, minf(raggio, alto * 0.5) * 0.98)
		var punti := PackedVector2Array([Vector2(0.0, 0.0)])
		var normali_profilo := PackedVector2Array([Vector2(0.0, -1.0)])
		for k in 4:
			var t := -PI * 0.5 + PI * 0.5 * float(k) / 3.0
			punti.append(Vector2(raggio - e + e * cos(t), e + e * sin(t)))
			normali_profilo.append(Vector2(cos(t), sin(t)))
		for k in 4:
			var t := PI * 0.5 * float(k) / 3.0
			punti.append(Vector2(raggio - e + e * cos(t), alto - e + e * sin(t)))
			normali_profilo.append(Vector2(cos(t), sin(t)))
		punti.append(Vector2(0.0, alto))
		normali_profilo.append(Vector2(0.0, 1.0))
		tornio(punti, normali_profilo, colore, posto, lati)

	## Un solido di rotazione attorno all'asse verticale di `posto`: `profilo` va dal
	## basso in alto, in (distanza dall'asse, quota), con la normale di ogni punto. Gli
	## `ultimi` punti del profilo prendono `colore_cima` (la punta di un dardo).
	func tornio(profilo: PackedVector2Array, normali_profilo: PackedVector2Array, colore: Color,
			posto: Transform3D, lati := 20, colore_cima := Color.BLACK, ultimi := 0,
			da_angolo := 0.0, ampiezza := TAU) -> void:
		var giro := posto.basis.orthonormalized()
		var primo := vertici.size()
		for i in lati + 1:
			var a := da_angolo + ampiezza * float(i) / float(lati)
			var verso := Vector3(cos(a), 0.0, sin(a))
			for k in profilo.size():
				vertici.append(posto * (verso * profilo[k].x + Vector3(0.0, profilo[k].y, 0.0)))
				normali.append(giro * (verso * normali_profilo[k].x
						+ Vector3(0.0, normali_profilo[k].y, 0.0)).normalized())
				colori.append(colore_cima if k >= profilo.size() - ultimi else colore)
		var righe := profilo.size()
		for i in lati:
			for k in righe - 1:
				var a := primo + i * righe + k
				var b := a + righe
				# L'angolo cresce da x verso z e il profilo sale: visto da fuori, il
				# senso orario è a, b+1, a+1 (il prodotto dei lati punta dentro).
				indici.append_array(PackedInt32Array([a, b + 1, a + 1, a, b, b + 1]))

	## Un tronco di prisma in coordinate del mondo: il contorno `sotto` alla quota
	## `basso`, il contorno `sopra` (gli stessi punti, stretti attorno allo stesso
	## centro) alla quota `alto`. Fianchi piatti col loro colore, la cima del suo.
	func tronco(sotto: PackedVector2Array, sopra: PackedVector2Array, basso: float,
			alto: float, fianco: Color, cima: Color) -> void:
		var n := sotto.size()
		var mezzo := Vector2.ZERO
		for p in sotto:
			mezzo += p
		mezzo /= float(n)
		for k in n:
			var a := Vector3(sotto[k].x, basso, sotto[k].y)
			var b := Vector3(sotto[(k + 1) % n].x, basso, sotto[(k + 1) % n].y)
			var c := Vector3(sopra[(k + 1) % n].x, alto, sopra[(k + 1) % n].y)
			var d := Vector3(sopra[k].x, alto, sopra[k].y)
			var fuori := (b - a).cross(d - a).normalized()
			var dal_mezzo := (sotto[k] + sotto[(k + 1) % n]) * 0.5 - mezzo
			if fuori.dot(Vector3(dal_mezzo.x, 0.0, dal_mezzo.y)) < 0.0:
				fuori = -fuori
			var primo := vertici.size()
			for v in [a, b, c, d]:
				vertici.append(v)
				normali.append(fuori)
				colori.append(fianco)
			_quadro(primo, fuori)
		var triangoli := Geometry2D.triangulate_polygon(sopra)
		var primo := vertici.size()
		for p in sopra:
			vertici.append(Vector3(p.x, alto, p.y))
			normali.append(Vector3.UP)
			colori.append(cima)
		var i := 0
		while i < triangoli.size():
			var a := vertici[primo + triangoli[i]]
			var b := vertici[primo + triangoli[i + 1]]
			var c := vertici[primo + triangoli[i + 2]]
			var tre := PackedInt32Array([primo + triangoli[i], primo + triangoli[i + 1],
					primo + triangoli[i + 2]])
			if (b - a).cross(c - a).dot(Vector3.UP) > 0.0:
				tre = PackedInt32Array([tre[0], tre[2], tre[1]])
			indici.append_array(tre)
			i += 3

	## Un poligono piano orizzontale alla quota `y`, che guarda verso `verso` (su o giù).
	func piatto(poligono: PackedVector2Array, y: float, verso: Vector3, colore: Color) -> void:
		var triangoli := Geometry2D.triangulate_polygon(poligono)
		var primo := vertici.size()
		for p in poligono:
			vertici.append(Vector3(p.x, y, p.y))
			normali.append(verso)
			colori.append(colore)
		var i := 0
		while i < triangoli.size():
			var tre := PackedInt32Array([primo + triangoli[i], primo + triangoli[i + 1],
					primo + triangoli[i + 2]])
			var a := vertici[tre[0]]
			if (vertici[tre[1]] - a).cross(vertici[tre[2]] - a).dot(verso) > 0.0:
				tre = PackedInt32Array([tre[0], tre[2], tre[1]])
			indici.append_array(tre)
			i += 3

	## Un quadrilatero piano già nei vertici, da `primo`, girato verso `fuori`.
	func _quadro(primo: int, fuori: Vector3) -> void:
		var a := vertici[primo]
		var b := vertici[primo + 1]
		var c := vertici[primo + 2]
		if (b - a).cross(c - a).dot(fuori) > 0.0:
			indici.append_array(PackedInt32Array([primo, primo + 2, primo + 1, primo, primo + 3, primo + 2]))
		else:
			indici.append_array(PackedInt32Array([primo, primo + 1, primo + 2, primo, primo + 2, primo + 3]))


## **Il foglio**: i quadrati delle decalcomanie, ognuno con la sua casella del foglio e
## il colore del contorno sui vertici.
class Foglio:
	var vertici := PackedVector3Array()
	var normali := PackedVector3Array()
	var colori := PackedColorArray()
	var coordinate := PackedVector2Array()
	var indici := PackedInt32Array()

	## Un quadrato che guarda verso `fuori`, dritto, letto da chi lo guarda da fuori.
	func quadro(centro: Vector3, fuori: Vector3, misura: Vector2, casella: Rect2,
			colore: Color) -> void:
		var destra := Vector3.UP.cross(fuori).normalized() * misura.x * 0.5
		var su := Vector3.UP * misura.y * 0.5
		var primo := vertici.size()
		var angoli := [centro - destra + su, centro + destra + su, centro + destra - su,
				centro - destra - su]
		var uv := [casella.position, casella.position + Vector2(casella.size.x, 0.0),
				casella.end, casella.position + Vector2(0.0, casella.size.y)]
		for k in 4:
			vertici.append(angoli[k])
			normali.append(fuori)
			colori.append(colore)
			coordinate.append(uv[k])
		# In alto a sinistra, a destra, giù: il senso orario di chi guarda da fuori.
		indici.append_array(PackedInt32Array([primo, primo + 1, primo + 2, primo, primo + 2, primo + 3]))

	func mesh() -> ArrayMesh:
		if indici.is_empty():
			return null
		var dati := []
		dati.resize(Mesh.ARRAY_MAX)
		dati[Mesh.ARRAY_VERTEX] = vertici
		dati[Mesh.ARRAY_NORMAL] = normali
		dati[Mesh.ARRAY_COLOR] = colori
		dati[Mesh.ARRAY_TEX_UV] = coordinate
		dati[Mesh.ARRAY_INDEX] = indici
		var fuori := ArrayMesh.new()
		fuori.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, dati)
		return fuori


## Le coordinate lungo un lato di una scatola arrotondata: l'arco a un capo, l'arco
## all'altro capo.
static func _campioni(meta: float, raggio: float, segmenti: int) -> PackedFloat32Array:
	var fuori := PackedFloat32Array()
	for k in segmenti + 1:
		fuori.append(-meta + raggio - raggio * cos(float(k) / float(segmenti) * PI * 0.5))
	for k in range(segmenti, -1, -1):
		fuori.append(meta - raggio + raggio * cos(float(k) / float(segmenti) * PI * 0.5))
	return fuori
