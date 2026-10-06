class_name Aspetto
extends RefCounted

## **Le varianti dell'aspetto** (tappa 10, blocco C).
##
## Le direzioni visive si scelgono sulla scena vera, non su un campionario (`PLAN.md`,
## tappa 10): stessa arena, stesse inquadrature, e un interruttore nel banco di prova
## (cinque tocchi sulla versione) che passa dall'una all'altra. La scelta resta salvata
## sul telefono, così GIOCA dall'icona sulla Home apre l'arena nella variante scelta, e
## la sonda dice quale (`aspetto=`). La variante zero è l'arena di oggi, intatta: è il
## riferimento di ogni confronto, e di ogni misura sul telefono.
##
## Le tre direzioni sono di Fable (`DIREZIONI-VISIVE.md`, 04/10/2026). Qui c'è di
## ognuna **quello che la distingue dalle altre** — tetto, cielo, luce, strisce — più
## due mosse comuni che costano niente: l'ombra di contatto sotto i corpi e la nebbia
## di profondità. Le mosse comuni care (la luce cotta, le superfici nuove) servono a
## qualunque direzione, e si fanno una volta sola, su quella scelta.

const FILE := "user://aspetto.cfg"
const NOMI: Array[String] = ["OGGI", "PALAZZETTO", "ORA BLU", "SALA LASER", "GIOCATTOLO"]
const OGGI := 0
const PALAZZETTO := 1
const ORA_BLU := 2
const SALA_LASER := 3
## L'arena-giocattolo come NERF Superblast (tappa 10, blocco D): non è una luce nuova,
## è un'arena fatta d'altro. Sta in `Giocattolo`.
const GIOCATTOLO := 4

static var _scelta := -1
static var _ombra: StandardMaterial3D = null


## La variante in uso: letta una volta dal telefono, poi tenuta in memoria.
static func scelta() -> int:
	if _scelta < 0:
		var cfg := ConfigFile.new()
		_scelta = int(cfg.get_value("aspetto", "variante", 0)) if cfg.load(FILE) == OK else 0
		_scelta = clampi(_scelta, 0, NOMI.size() - 1)
	return _scelta


static func scegli(variante: int) -> void:
	_scelta = clampi(variante, 0, NOMI.size() - 1)
	var cfg := ConfigFile.new()
	cfg.set_value("aspetto", "variante", _scelta)
	cfg.save(FILE)


static func nome() -> String:
	return NOMI[scelta()]


## La variante seguente, in giro: è quello che fa il pulsante del banco di prova.
static func avanti() -> void:
	scegli((scelta() + 1) % NOMI.size())


# ------------------------------------------------------------------ gli agganci

## Prima della luce per vertice: pezzi e superfici, che così la calcolano sui vertici
## come tutto il resto dell'arena.
static func veste(arena: Node3D) -> void:
	match scelta():
		PALAZZETTO:
			_palazzetto(arena)
		ORA_BLU:
			_ora_blu(arena)
		SALA_LASER:
			_sala_laser(arena)
		GIOCATTOLO:
			await Giocattolo.veste(arena as Arena)


## L'arredo da palazzetto di `Vestizione.arreda_arena` — neon sui perimetri, cinghie dei
## cassoni, striscioni appesi al soffitto, insegne al neon — sta in tutte le varianti
## tranne l'arena-giocattolo, che è a cielo aperto e ha i suoi.
static func arredo_palestra() -> bool:
	return scelta() != GIOCATTOLO


## Dopo le luci: cielo, nebbia, lampade.
static func illumina(arena: Node3D) -> void:
	var ambiente := _ambiente(arena)
	match scelta():
		GIOCATTOLO:
			Giocattolo.illumina(arena, ambiente)
		PALAZZETTO:
			ambiente.ambient_light_color = Color(0.56, 0.53, 0.60)
			ambiente.ambient_light_energy = 0.95
			_nebbia(ambiente, Color(0.36, 0.40, 0.55), 0.005)
			for luce in _lampade_dei_lucernari(arena):
				luce.light_color = Color(1.0, 0.95, 0.86)
				luce.light_energy = 4.2
		ORA_BLU:
			_cielo(ambiente)
			ambiente.ambient_light_color = Color(0.42, 0.42, 0.68)
			ambiente.ambient_light_energy = 0.95
			_nebbia(ambiente, Color(0.32, 0.26, 0.52), 0.006)
			for luce in _lampade_dei_lucernari(arena):
				luce.visible = false
			for figlio in arena.get_children():
				if figlio is DirectionalLight3D:
					var sole := figlio as DirectionalLight3D
					sole.light_color = Color(0.86, 0.90, 1.0)
					sole.light_energy = 1.15
					sole.rotation_degrees = Vector3(-34.0, 45.0, 0.0)
					sole.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
		SALA_LASER:
			ambiente.ambient_light_color = Color(0.28, 0.28, 0.48)
			ambiente.ambient_light_energy = 0.75
			_nebbia(ambiente, Color(0.05, 0.06, 0.15), 0.011)
			for luce in _lampade_dei_lucernari(arena):
				luce.light_color = Color(0.78, 0.72, 1.0)
				luce.light_energy = 3.8


## **L'ombra di contatto** (mossa comune): un cerchio sfumato sotto i piedi, senza luce.
## Senza, chi corre sembra incollato sullo schermo (Fable, sullo scatto 63). Costa un
## quadrato per corpo. Nella variante di oggi non c'è.
static func ombra(corpo: Node3D) -> void:
	if scelta() == OGGI:
		return
	if _ombra == null:
		var sfumatura := Gradient.new()
		sfumatura.set_color(0, Color(0, 0, 0, 0.68))
		sfumatura.set_color(1, Color(0, 0, 0, 0.0))
		var tondo := GradientTexture2D.new()
		tondo.gradient = sfumatura
		tondo.fill = GradientTexture2D.FILL_RADIAL
		tondo.fill_from = Vector2(0.5, 0.5)
		tondo.fill_to = Vector2(0.5, 0.0)
		tondo.width = 64
		tondo.height = 64
		_ombra = StandardMaterial3D.new()
		_ombra.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ombra.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ombra.albedo_texture = tondo
		_ombra.disable_receive_shadows = true
	var pezzo := MeshInstance3D.new()
	var quadro := QuadMesh.new()
	quadro.size = Vector2(1.5, 1.5)
	quadro.orientation = PlaneMesh.FACE_Y
	pezzo.mesh = quadro
	pezzo.material_override = _ombra
	pezzo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pezzo.position = Vector3(0, 0.03, 0)
	corpo.add_child(pezzo)


# ------------------------------------------------------------------ A. palazzetto

## Un palazzetto dello sport di notte: tetto a capriate illuminato, plafoniere vere al
## posto dei rettangoli lilla, pareti imbottite di gommapiuma colorata. Spugna contro
## spugna.
static func _palazzetto(arena: Node3D) -> void:
	var pianta: Dictionary = arena.call("pianta")
	# Il tetto: lamiera grecata blu-grigia, chiara e accesa quanto basta per leggersi.
	# Con la luce per vertice un soffitto di trenta metri prende luce solo dai suoi
	# quattro spigoli, ed era nero: si accende da sé, sotto la soglia del bagliore.
	var lamiera := Vestizione.materiale_di("soffitto").duplicate() as StandardMaterial3D
	lamiera.albedo_color = Color(0.44, 0.49, 0.62)
	lamiera.emission = Color(0.40, 0.45, 0.58)
	lamiera.emission_energy_multiplier = 0.32
	_vesti_soffitti(arena, lamiera)
	# Le capriate: travi bianche scatolate sotto ogni soffitto, ogni tre metri e mezzo
	# in un verso e ogni sette nell'altro.
	var travi: Array[Transform3D] = []
	var traversi: Array[Transform3D] = []
	for c in pianta["soffitti"]:
		var centro := Vector2(float(c["centro"][0]), float(c["centro"][1]))
		var misura := Vector2(float(c["misura"][0]), float(c["misura"][1]))
		var sotto := float(c["quota"]) - 0.3
		var z := centro.y - misura.y * 0.5 + 1.75
		while z < centro.y + misura.y * 0.5:
			travi.append(Transform3D(Basis.from_scale(Vector3(misura.x, 0.45, 0.28)),
					Vector3(centro.x, sotto, z)))
			z += 3.5
		var x := centro.x - misura.x * 0.5 + 3.5
		while x < centro.x + misura.x * 0.5:
			traversi.append(Transform3D(Basis.from_scale(Vector3(0.28, 0.7, misura.y)),
					Vector3(x, sotto - 0.12, centro.y)))
			x += 7.0
	var bianco := _illuminato(Color(0.90, 0.92, 0.96), 0.18)
	_in_serie(arena, BoxMesh.new(), travi, bianco)
	_in_serie(arena, BoxMesh.new(), traversi, bianco)
	# Le plafoniere: i lucernari diventano scatole di luce bianca calda, con un alone
	# dipinto sulla lamiera intorno.
	var plafoniera := _acceso(Color(1.0, 0.96, 0.88), 0.95)
	for pezzo in _lucernari(arena):
		pezzo.material_override = plafoniera
		pezzo.scale = Vector3(1.0, 2.0, 1.0)
		var alone := _quadro_additivo(Vector2(pezzo.mesh.size.x, pezzo.mesh.size.z) * 2.2,
				Color(1.0, 0.92, 0.78), 0.35)
		# Appena sotto la lamiera, che sta un decimo sopra il lucernario.
		alone.position = pezzo.position + Vector3(0, 0.07, 0)
		arena.add_child(alone)
	# Le pareti imbottite: materassini alti due metri lungo i quattro perimetri, nel
	# colore dell'ala, con un dito d'aria fra l'uno e l'altro. Dove sul perimetro c'è
	# una sponda non si mettono: il ciano deve restare l'unica cosa che rimbalza.
	# Le facce interne dei perimetri stanno a ±40 dal 06/10/2026 (blocco E).
	var lati := [
		{"asse": "x", "fisso": -39.94, "colore": Color(0.86, 0.58, 0.16)},
		{"asse": "x", "fisso": 39.94, "colore": Color(0.48, 0.30, 0.82)},
		{"asse": "z", "fisso": 39.94, "colore": Color(0.82, 0.24, 0.26)},
		{"asse": "z", "fisso": -39.94, "colore": Color(0.30, 0.34, 0.80)},
	]
	for lato in lati:
		var posti: Array[Transform3D] = []
		var lungo := -39.0
		while lungo < 39.0:
			if not _sponda_sul_perimetro(pianta, String(lato["asse"]), float(lato["fisso"]), lungo):
				var dove := Vector3(lungo + 0.95, 1.0, float(lato["fisso"])) \
						if lato["asse"] == "x" else Vector3(float(lato["fisso"]), 1.0, lungo + 0.95)
				var misura := Vector3(1.86, 2.0, 0.14) if lato["asse"] == "x" \
						else Vector3(0.14, 2.0, 1.86)
				posti.append(Transform3D(Basis.from_scale(misura), dove))
			lungo += 2.0
		_in_serie(arena, _scatola_tonda(), posti, _illuminato(lato["colore"], 0.08, 0.55))


# ------------------------------------------------------------------ B. ora blu

## A cielo aperto, uno stadio al crepuscolo: il tetto non c'è, il cielo è blu-viola con
## l'orizzonte magenta, quattro torri faro agli angoli con i fasci che spazzano piano.
static func _ora_blu(arena: Node3D) -> void:
	for corpo in _soffitti(arena):
		for figlio in corpo.get_children():
			if figlio is MeshInstance3D:
				(figlio as MeshInstance3D).visible = false
	for pezzo in _lucernari(arena):
		pezzo.visible = false
	var grigio := _illuminato(Color(0.34, 0.36, 0.46), 0.05)
	var nero := _illuminato(Color(0.10, 0.10, 0.14), 0.0)
	var faro := _acceso(Color(0.94, 0.96, 1.0), 0.95)
	var fascio := _materiale_additivo(Color(0.62, 0.72, 1.0), 0.16, true)
	var i := 0
	# Fuori dai perimetri, come in uno stadio: spuntano sopra i muri di dodici metri.
	# Dentro gli angoli la camera di chi parte da lì finiva nel palo (scatto del
	# 04/10/2026, partenza nord-ovest: mezzo schermo blu).
	for angolo in [Vector2(-43.0, -43.0), Vector2(43.0, -43.0), Vector2(43.0, 43.0),
			Vector2(-43.0, 43.0)]:
		var testa := Vector3(angolo.x, 19.0, angolo.y)
		var palo := MeshInstance3D.new()
		var forma := BoxMesh.new()
		forma.size = Vector3(0.8, 19.0, 0.8)
		palo.mesh = forma
		palo.material_override = grigio
		palo.position = Vector3(angolo.x, 9.5, angolo.y)
		arena.add_child(palo)
		var verso_il_centro := Vector3(-angolo.x, 0.0, -angolo.y).normalized()
		var batteria := MeshInstance3D.new()
		var cassa := BoxMesh.new()
		cassa.size = Vector3(4.0, 2.0, 0.6)
		batteria.mesh = cassa
		batteria.material_override = nero
		batteria.position = testa
		arena.add_child(batteria)
		batteria.look_at(testa + verso_il_centro, Vector3.UP)
		var luci := MeshInstance3D.new()
		var vetro := BoxMesh.new()
		vetro.size = Vector3(3.6, 1.6, 0.08)
		luci.mesh = vetro
		luci.material_override = faro
		batteria.add_child(luci)
		luci.position = Vector3(0, 0, -0.32)
		var lampada := OmniLight3D.new()
		lampada.light_color = Color(0.92, 0.95, 1.0)
		lampada.light_energy = 2.2
		lampada.omni_range = 85.0
		lampada.position = testa + verso_il_centro * 1.5
		arena.add_child(lampada)
		# Il fascio: un cono additivo appeso alla testa, che spazza avanti e indietro.
		var perno := Node3D.new()
		perno.position = testa
		arena.add_child(perno)
		perno.look_at(testa + verso_il_centro + Vector3(0, -0.55, 0), Vector3.UP)
		var cono := MeshInstance3D.new()
		var cilindro := CylinderMesh.new()
		cilindro.top_radius = 0.6
		cilindro.bottom_radius = 5.5
		cilindro.height = 44.0
		cilindro.radial_segments = 14
		cilindro.cap_top = false
		cilindro.cap_bottom = false
		cono.mesh = cilindro
		cono.material_override = fascio
		cono.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Il cilindro sta lungo +Y, col lato stretto in cima: girato così la cima guarda
		# la torre e il lato largo va verso il campo.
		cono.rotation_degrees = Vector3(90, 0, 0)
		cono.position = Vector3(0, 0, -22.0)
		perno.add_child(cono)
		var giro := arena.create_tween().set_loops()
		var base := perno.rotation_degrees.y
		giro.tween_property(perno, "rotation_degrees:y", base + 16.0, 6.0 + i) \
				.set_trans(Tween.TRANS_SINE)
		giro.tween_property(perno, "rotation_degrees:y", base - 16.0, 6.0 + i) \
				.set_trans(Tween.TRANS_SINE)
		i += 1


# ------------------------------------------------------------------ C. sala laser

## Il buio tenuto ma riempito: soffitto industriale blu notte con condotti e fari col
## cono di luce, strisce di luce lungo la cima dei muri nei colori di zona, che
## respirano piano; le superfici più scure, perché le strisce si leggano.
static func _sala_laser(arena: Node3D) -> void:
	var pianta: Dictionary = arena.call("pianta")
	var notte := Vestizione.materiale_di("soffitto").duplicate() as StandardMaterial3D
	notte.albedo_color = Color(0.12, 0.14, 0.30)
	notte.emission = Color(0.10, 0.12, 0.30)
	notte.emission_energy_multiplier = 0.6
	_vesti_soffitti(arena, notte)
	# Le superfici più scure: ogni materiale dei muri e dei pavimenti, al sessanta per
	# cento. Il ciano delle sponde e i neon restano come sono.
	var scuri := {}
	for nome in Vestizione.VESTITI.keys():
		if String(nome) == "soffitto":
			continue
		var vecchio := Vestizione.materiale_di(String(nome))
		var nuovo := vecchio.duplicate() as StandardMaterial3D
		nuovo.albedo_color = vecchio.albedo_color * Color(0.6, 0.6, 0.66, 1.0)
		nuovo.emission_energy_multiplier = vecchio.emission_energy_multiplier * 0.5
		scuri[vecchio] = nuovo
	_rimappa(arena, scuri)
	# I condotti sotto i soffitti, e i fari al posto dei lucernari, col cono di luce.
	var tubi: Array[Transform3D] = []
	for c in pianta["soffitti"]:
		var centro := Vector2(float(c["centro"][0]), float(c["centro"][1]))
		var misura := Vector2(float(c["misura"][0]), float(c["misura"][1]))
		var z := centro.y - misura.y * 0.5 + 3.0
		while z < centro.y + misura.y * 0.5:
			tubi.append(Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5)
					* Basis.from_scale(Vector3(0.36, misura.x, 0.36)),
					Vector3(centro.x, float(c["quota"]) - 0.7, z)))
			z += 6.0
	var tubo := CylinderMesh.new()
	tubo.top_radius = 0.5
	tubo.bottom_radius = 0.5
	tubo.height = 1.0
	tubo.radial_segments = 10
	_in_serie(arena, tubo, tubi, _illuminato(Color(0.24, 0.26, 0.38), 0.05))
	var luce_del_faro := _materiale_additivo(Color(0.72, 0.62, 1.0), 0.08, true)
	for pezzo in _lucernari(arena):
		pezzo.visible = false
		var cono := MeshInstance3D.new()
		var cilindro := CylinderMesh.new()
		var alto := pezzo.position.y
		cilindro.top_radius = 0.35
		cilindro.bottom_radius = 3.4
		cilindro.height = alto - 0.5
		cilindro.radial_segments = 14
		cilindro.cap_top = false
		cilindro.cap_bottom = false
		cono.mesh = cilindro
		cono.material_override = luce_del_faro
		cono.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cono.position = Vector3(pezzo.position.x, alto * 0.5 + 0.25, pezzo.position.z)
		arena.add_child(cono)
	# Le strisce: lungo la cima di ogni muro basso e medio, nel colore della sua ala.
	var colori := {
		"ocra": Color(1.0, 0.82, 0.25), "mattone": Color(1.0, 0.30, 0.38),
		"tribuna": Color(0.56, 0.46, 1.0),
	}
	var per_colore := {}
	for m in pianta["muri"]:
		var nome := String(m.get("nome", ""))
		var alto := float(m["alto"])
		if alto < 0.8 or alto > 9.0 or nome.contains("pilone") or nome.contains("colonna") \
				or nome.contains("gradinata"):
			continue
		var tinta := String(m.get("tinta", ""))
		var colore: Color = colori.get(tinta, Color(0.80, 0.60, 1.0))
		if not per_colore.has(colore):
			per_colore[colore] = [] as Array[Transform3D]
		var giro := deg_to_rad(float(m.get("giro", 0.0)))
		(per_colore[colore] as Array[Transform3D]).append(Transform3D(
				Basis(Vector3.UP, giro) * Basis.from_scale(Vector3(float(m["misura"][0]), 0.13,
						float(m["misura"][1]) + 0.06)),
				Vector3(float(m["centro"][0]), float(m["quota"]) + alto + 0.05,
						float(m["centro"][1]))))
	# E l'orlo del catino: otto strisce viola, lì dove il campo scende di due metri.
	var viola := Color(0.72, 0.40, 1.0)
	if not per_colore.has(viola):
		per_colore[viola] = [] as Array[Transform3D]
	for zona in pianta["zone"]:
		if String(zona["nome"]) != "catino":
			continue
		var punti: Array = zona["poligono"]
		for k in punti.size():
			var a := Vector2(float(punti[k][0]), float(punti[k][1]))
			var b := Vector2(float(punti[(k + 1) % punti.size()][0]),
					float(punti[(k + 1) % punti.size()][1]))
			var mezzo := (a + b) * 0.5
			(per_colore[viola] as Array[Transform3D]).append(Transform3D(
					Basis(Vector3.UP, atan2(-(b - a).y, (b - a).x))
					* Basis.from_scale(Vector3(a.distance_to(b), 0.08, 0.16)),
					Vector3(mezzo.x, 0.04, mezzo.y)))
	for colore: Color in per_colore.keys():
		var striscia := _acceso(colore, 0.92)
		_in_serie(arena, BoxMesh.new(), per_colore[colore], striscia)
		# Senza luce propria si accende col colore: il respiro gira quello.
		var respiro := arena.create_tween().set_loops()
		respiro.tween_property(striscia, "albedo_color", colore * Color(0.55, 0.55, 0.55, 1.0),
				1.6).set_trans(Tween.TRANS_SINE)
		respiro.tween_property(striscia, "albedo_color", colore * Color(0.92, 0.92, 0.92, 1.0),
				1.6).set_trans(Tween.TRANS_SINE)


# ------------------------------------------------------------------ attrezzi

static func _ambiente(arena: Node3D) -> Environment:
	for figlio in arena.get_children():
		if figlio is WorldEnvironment:
			return (figlio as WorldEnvironment).environment
	return Environment.new()


static func _nebbia(ambiente: Environment, colore: Color, densita: float) -> void:
	ambiente.fog_enabled = true
	ambiente.fog_light_color = colore
	ambiente.fog_density = densita
	ambiente.fog_sky_affect = 0.0


static func _cielo(ambiente: Environment) -> void:
	var materiale := ProceduralSkyMaterial.new()
	materiale.sky_top_color = Color(0.05, 0.08, 0.27)
	materiale.sky_horizon_color = Color(0.46, 0.22, 0.54)
	materiale.sky_curve = 0.12
	materiale.ground_horizon_color = Color(0.20, 0.10, 0.28)
	materiale.ground_bottom_color = Color(0.04, 0.03, 0.08)
	var cielo := Sky.new()
	cielo.sky_material = materiale
	ambiente.sky = cielo
	ambiente.background_mode = Environment.BG_SKY


static func _soffitti(arena: Node3D) -> Array[Node]:
	var fuori: Array[Node] = []
	for figlio in arena.get_children():
		if figlio.is_in_group(Arena.GRUPPO_SOFFITTI):
			fuori.append(figlio)
	return fuori


static func _vesti_soffitti(arena: Node3D, materiale: StandardMaterial3D) -> void:
	for corpo in _soffitti(arena):
		for figlio in corpo.get_children():
			if figlio is MeshInstance3D:
				(figlio as MeshInstance3D).material_override = materiale


static func _lucernari(arena: Node3D) -> Array[MeshInstance3D]:
	var fuori: Array[MeshInstance3D] = []
	for figlio in arena.get_children():
		if figlio is MeshInstance3D and figlio.is_in_group(Arena.GRUPPO_LUCERNARI):
			fuori.append(figlio as MeshInstance3D)
	return fuori


static func _lampade_dei_lucernari(arena: Node3D) -> Array[OmniLight3D]:
	var fuori: Array[OmniLight3D] = []
	for figlio in arena.get_children():
		if figlio is OmniLight3D and figlio.is_in_group(Arena.GRUPPO_LUCERNARI):
			fuori.append(figlio as OmniLight3D)
	return fuori


## Dove sul perimetro c'è una sponda, a questa altezza del lato.
static func _sponda_sul_perimetro(pianta: Dictionary, asse: String, fisso: float,
		da: float) -> bool:
	for s in pianta["sponde"]:
		var c := Vector2(float(s["centro"][0]), float(s["centro"][1]))
		var largo := float(s["faccia"][0]) * 0.5 + 0.3
		var giro := int(round(float(s.get("giro", 0.0)))) % 180
		if asse == "x" and giro == 0 and absf(c.y - fisso) < 1.5 \
				and da + 2.0 > c.x - largo and da < c.x + largo:
			return true
		if asse == "z" and absf(giro) == 90 and absf(c.x - fisso) < 1.5 \
				and da + 2.0 > c.y - largo and da < c.y + largo:
			return true
	return false


## Tanti pezzi uguali in una chiamata di disegno sola.
static func _in_serie(arena: Node3D, mesh: Mesh, posti: Array[Transform3D],
		materiale: Material) -> void:
	if posti.is_empty():
		return
	var serie := MultiMesh.new()
	serie.transform_format = MultiMesh.TRANSFORM_3D
	serie.mesh = mesh
	serie.instance_count = posti.size()
	for i in posti.size():
		serie.set_instance_transform(i, posti[i])
	var pezzo := MultiMeshInstance3D.new()
	pezzo.multimesh = serie
	pezzo.material_override = materiale
	pezzo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(pezzo)


## Una superficie che prende la luce sui vertici, come tutta l'arena, con un filo di
## luce propria.
static func _illuminato(colore: Color, luce: float, ruvido := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colore
	m.roughness = ruvido
	m.metallic_specular = 0.25
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	if luce > 0.0:
		m.emission_enabled = true
		m.emission = colore
		m.emission_energy_multiplier = luce
	return m


## Una cosa accesa: luce propria, sotto la soglia del bagliore (che è del dardo).
static func _acceso(colore: Color, forza: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = colore * Color(forza, forza, forza, 1.0)
	return m


## Luce dipinta: si somma a quello che sta dietro, e sfuma verso i bordi (o verso la
## base, per i coni).
static func _materiale_additivo(colore: Color, forza: float, lungo := false) -> StandardMaterial3D:
	var sfumatura := Gradient.new()
	sfumatura.set_color(0, Color(1, 1, 1, 1))
	sfumatura.set_color(1, Color(1, 1, 1, 0))
	var tessuto := GradientTexture2D.new()
	tessuto.gradient = sfumatura
	tessuto.width = 64
	tessuto.height = 64
	if lungo:
		tessuto.fill_from = Vector2(0.5, 0.0)
		tessuto.fill_to = Vector2(0.5, 1.0)
	else:
		tessuto.fill = GradientTexture2D.FILL_RADIAL
		tessuto.fill_from = Vector2(0.5, 0.5)
		tessuto.fill_to = Vector2(0.5, 0.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.albedo_color = Color(colore.r, colore.g, colore.b, forza)
	m.albedo_texture = tessuto
	return m


static func _quadro_additivo(misura: Vector2, colore: Color, forza: float) -> MeshInstance3D:
	var pezzo := MeshInstance3D.new()
	var quadro := QuadMesh.new()
	quadro.size = misura
	quadro.orientation = PlaneMesh.FACE_Y
	pezzo.mesh = quadro
	pezzo.material_override = _materiale_additivo(colore, forza)
	pezzo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return pezzo


## Un materassino: una scatola con gli spigoli smussati, presa dalla muratura.
static func _scatola_tonda() -> Mesh:
	return Muratura.scatola_smussata(Vector3.ONE, 0.12)


## Cambia i materiali dell'arena secondo la tabella `vecchio → nuovo`.
static func _rimappa(arena: Node3D, mappa: Dictionary) -> void:
	for nodo in arena.find_children("*", "MeshInstance3D", true, false):
		var pezzo := nodo as MeshInstance3D
		if pezzo.material_override != null and mappa.has(pezzo.material_override):
			pezzo.material_override = mappa[pezzo.material_override]
