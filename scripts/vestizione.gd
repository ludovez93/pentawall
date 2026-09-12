class_name Vestizione
extends RefCounted

## La vestizione: superfici vere al posto delle tinte piatte, insegne che sono
## oggetti, neon e striscioni, corpi veri al posto delle capsule.
##
## Nasce con la tappa 7, blocco A, per **la prima immagine** (`PLAN.md`). Si
## applica a un'arena già costruita e non tocca né la fisica né le regole: i
## muri restano muri, le sponde restano sponde, cambia solo di che cosa sembrano
## fatti. Tutto il materiale è libero (`assets/LICENZE.md`): Kenney per corpi e
## blaster (CC0), ambientCG per le superfici (CC0), Google Fonts per i caratteri.

const MATERIALI := "res://assets/materials/ambientcg/"
const MODELLI := "res://assets/models/kenney/"
const CARATTERE_INSEGNE := "res://assets/font/RussoOne-Regular.ttf"
const MODELLI_UMANI := "res://assets/models/quaternius/base/"
const ANIMAZIONI_UMANE := "res://assets/models/quaternius/UAL1_Standard.glb"
const TUTA := "res://assets/materials/tuta.gdshader"
const CAPELLI := "res://assets/models/quaternius/capelli/"

## Il neon decorativo: viola. Non arancio (il dardo), non ciano (le sponde), non
## lime (gli avversari): i tre colori che parlano restano soltanto loro.
const NEON := Color(0.78, 0.36, 1.0)
const LISTELLO := 0.07

## Quale superficie veste quale tinta della pianta, e con che colore. La tinta
## moltiplica la texture, che è chiara: qui è più accesa di come si vedrà.
const VESTITI := {
	"moquette": {"cartella": "Carpet016", "passo": 2.2, "tinta": Color(0.50, 0.28, 0.88),
			"normale": 0.6, "metallo": 0.0},
	"ocra": {"cartella": "PaintedPlaster017", "passo": 2.0, "tinta": Color(0.96, 0.64, 0.22),
			"normale": 0.9, "metallo": 0.0},
	"mattone": {"cartella": "Bricks075A", "passo": 2.6, "tinta": Color(1.0, 0.40, 0.40),
			"normale": 0.8, "metallo": 0.0},
	"tribuna": {"cartella": "MetalPlates006", "passo": 2.4, "tinta": Color(0.50, 0.44, 0.96),
			"normale": 0.7, "metallo": 0.35},
	"soffitto": {"cartella": "MetalPlates006", "passo": 3.2, "tinta": Color(0.28, 0.28, 0.58),
			"normale": 0.5, "metallo": 0.35},
}

## L'altezza dei personaggi nei loro file: si scalano a quella del corpo.
const ALTEZZA_BLOCCHETTI := 0.67
const ALTEZZA_UMANI := 1.8

static var _pronti: Dictionary = {}
static var _carattere: Font = null


# ------------------------------------------------------------------ superfici

## Veste tutti i muri, i piani e le rampe dell'arena: chi ha addosso una tinta
## della pianta riceve la superficie corrispondente, con lo stesso colore.
static func vesti(arena: Node3D) -> void:
	var per_colore := {}
	for nome in Arena.TINTE:
		per_colore[Arena.TINTE[nome]] = nome
	var grana := Muratura.grana()
	for nodo in tutti(arena):
		if not (nodo is MeshInstance3D):
			continue
		var pezzo := nodo as MeshInstance3D
		var vecchio := pezzo.material_override as StandardMaterial3D
		if vecchio == null or vecchio.albedo_texture != grana:
			continue
		var nome: Variant = per_colore.get(vecchio.albedo_color)
		if nome == null:
			continue
		pezzo.material_override = materiale_di(String(nome))


## La superficie di una tinta, costruita una volta e prestata a tutti i pezzi:
## un materiale solo per tinta è anche meno lavoro per la scheda video.
static func materiale_di(nome: String) -> StandardMaterial3D:
	if _pronti.has(nome):
		return _pronti[nome]
	var v: Dictionary = VESTITI[nome]
	var cartella: String = MATERIALI + String(v["cartella"]) + "/"
	var m := StandardMaterial3D.new()
	m.albedo_color = v["tinta"]
	m.albedo_texture = load(cartella + "Color.jpg")
	m.normal_enabled = true
	m.normal_texture = load(cartella + "Normal.jpg")
	m.normal_scale = float(v["normale"])
	m.roughness = 1.0
	m.roughness_texture = load(cartella + "Roughness.jpg")
	m.metallic = float(v["metallo"])
	# Proiezione dal mondo, uguale su scatole e su piani di forma qualunque: la
	# grana ha lo stesso passo dappertutto, e un muro lungo non la stira.
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / float(v["passo"])
	# Il filo di luce propria dei muri di prima, ma **attraverso la texture**: gli
	# angoli in ombra restano saturi senza che la superficie si appiattisca.
	m.emission_enabled = true
	m.emission = v["tinta"]
	m.emission_texture = m.albedo_texture
	m.emission_energy_multiplier = 0.05
	_pronti[nome] = m
	return m


# ------------------------------------------------------------------ arredo

## L'arredo dell'angolo nord-ovest, quello che si vede dalla sua partenza
## guardando verso il cuore: zoccoli e fasce al neon, le insegne come oggetti,
## due striscioni, l'anello della partenza. Coordinate dalla pianta
## (`arene/palestra.json`), scritte a mano perché è un angolo solo.
static func arreda_angolo(arena: Node3D) -> void:
	# La lampada di zona del nord-ovest era lime, che è il colore degli avversari
	# (decisione 15): qui diventa del neon, e con lei l'angolo.
	for nodo in tutti(arena):
		if nodo is OmniLight3D and (nodo as OmniLight3D).light_color.is_equal_approx(
				Color(0.62, 1.0, 0.45)):
			(nodo as OmniLight3D).light_color = NEON
			(nodo as OmniLight3D).light_energy = 2.2

	# Gli zoccoli: una riga di neon alla base dei muri dell'angolo.
	_striscia(arena, Vector3(-23.0, 0.10, -32.95), Vector3(20.0, LISTELLO, LISTELLO))   # perimetro nord
	_striscia(arena, Vector3(-32.95, 0.10, -23.0), Vector3(LISTELLO, LISTELLO, 20.0))   # perimetro ovest
	_striscia(arena, Vector3(-13.45, 0.10, -28.0), Vector3(LISTELLO, LISTELLO, 10.0))   # chiude verso l'angolo
	_striscia(arena, Vector3(-27.0, 0.10, -18.4), Vector3(10.0, LISTELLO, LISTELLO))    # il muro corto
	# La fascia a tre metri sui due perimetri: il segno da palestra.
	_striscia(arena, Vector3(-23.0, 3.2, -32.95), Vector3(20.0, LISTELLO, LISTELLO))
	_striscia(arena, Vector3(-32.95, 3.2, -23.0), Vector3(LISTELLO, LISTELLO, 20.0))

	# I tre cassoni: il bordo alto acceso, così si leggono come volumi anche da lontano.
	for cassone in [
		{"centro": Vector2(-22, -28), "misura": Vector2(5, 4), "alto": 2.6},
		{"centro": Vector2(-27, -24), "misura": Vector2(4, 4), "alto": 3.2},
		{"centro": Vector2(-18, -25), "misura": Vector2(3, 5), "alto": 2.2},
	]:
		_bordo(arena, cassone["centro"], cassone["misura"], float(cassone["alto"]) + 0.02)

	# L'insegna dell'angolo: sul muro che chiude verso l'angolo, faccia a ovest,
	# dove la si vede appena partiti. Dice la regola del gioco in due parole.
	_insegna(arena, "5 MURI", Vector3(-13.45, 5.0, -28.0), -90.0, Vector2(6.0, 1.9), 1.5)

	# L'insegna grande del cuore diventa un oggetto: pannello scuro, cornice al
	# neon, e la scritta che c'era già davanti.
	_pannello(arena, Vector3(0.0, 9.0, -11.55), 0.0, Vector2(15.5, 2.7))

	# Due striscioni appesi al soffitto dell'ala, rivolti verso la partenza.
	_striscione(arena, Vector3(-20.0, 7.9, -30.5), 225.0, Color(0.16, 0.30, 0.95))
	_striscione(arena, Vector3(-30.5, 7.9, -20.0), 225.0, Color(0.92, 0.22, 0.30))

	# L'anello della partenza, a terra.
	var anello := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 1.15
	toro.outer_radius = 1.32
	toro.rings = 48
	toro.ring_segments = 6
	anello.mesh = toro
	anello.position = Vector3(-29.0, 0.03, -29.0)
	anello.scale = Vector3(1.0, 0.18, 1.0)
	anello.material_override = Muratura.acceso(NEON, 0.7)
	anello.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(anello)

	# La luce del neon: le strisce fanno luce da sé ma non ne danno al pavimento,
	# quindi due lampade viola fanno il lavoro che nel mondo vero farebbero loro.
	_lampada(arena, Vector3(-23.0, 2.6, -30.5), NEON, 1.6, 13.0)
	_lampada(arena, Vector3(-16.0, 5.0, -28.0), NEON, 2.2, 10.0)


static func _striscia(arena: Node3D, centro: Vector3, misura: Vector3) -> void:
	var pezzo := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = misura
	pezzo.mesh = mesh
	pezzo.position = centro
	pezzo.material_override = Muratura.acceso(NEON, 0.85)
	pezzo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(pezzo)


## Il bordo acceso sul perimetro alto di un cassone.
static func _bordo(arena: Node3D, centro: Vector2, misura: Vector2, quota: float) -> void:
	var mx := misura.x * 0.5
	var mz := misura.y * 0.5
	_striscia(arena, Vector3(centro.x, quota, centro.y - mz), Vector3(misura.x + LISTELLO, LISTELLO, LISTELLO))
	_striscia(arena, Vector3(centro.x, quota, centro.y + mz), Vector3(misura.x + LISTELLO, LISTELLO, LISTELLO))
	_striscia(arena, Vector3(centro.x - mx, quota, centro.y), Vector3(LISTELLO, LISTELLO, misura.y + LISTELLO))
	_striscia(arena, Vector3(centro.x + mx, quota, centro.y), Vector3(LISTELLO, LISTELLO, misura.y + LISTELLO))


## Un pannello scuro con la cornice al neon: il corpo di ogni insegna. `giro` è
## la rotazione attorno all'asse verticale; la faccia guarda verso **+Z** prima del
## giro, perché è da lì che una `Label3D` si legge dritta.
static func _pannello(arena: Node3D, dove: Vector3, giro: float, misura: Vector2) -> Node3D:
	var radice := Node3D.new()
	radice.position = dove
	radice.rotation_degrees.y = giro
	arena.add_child(radice)

	var fondo := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(misura.x, misura.y, 0.16)
	fondo.mesh = mesh
	var scuro := materiale_di("soffitto").duplicate() as StandardMaterial3D
	scuro.albedo_color = Color(0.13, 0.12, 0.22)
	scuro.emission_energy_multiplier = 0.0
	scuro.uv1_scale = Vector3.ONE / 1.4
	fondo.material_override = scuro
	radice.add_child(fondo)

	var s := LISTELLO * 1.4
	var mx := misura.x * 0.5
	var my := misura.y * 0.5
	for lato in [
		{"pos": Vector3(0, my, 0.06), "mis": Vector3(misura.x + s, s, s)},
		{"pos": Vector3(0, -my, 0.06), "mis": Vector3(misura.x + s, s, s)},
		{"pos": Vector3(-mx, 0, 0.06), "mis": Vector3(s, misura.y + s, s)},
		{"pos": Vector3(mx, 0, 0.06), "mis": Vector3(s, misura.y + s, s)},
	]:
		var pezzo := MeshInstance3D.new()
		var tubo := BoxMesh.new()
		tubo.size = lato["mis"]
		pezzo.mesh = tubo
		pezzo.position = lato["pos"]
		pezzo.material_override = Muratura.acceso(NEON, 0.9)
		pezzo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		radice.add_child(pezzo)
	return radice


## Un'insegna intera: pannello, cornice e scritta.
static func _insegna(arena: Node3D, testo: String, dove: Vector3, giro: float,
		misura: Vector2, altezza_testo: float) -> void:
	var pannello := _pannello(arena, dove, giro, misura)
	var etichetta := Label3D.new()
	etichetta.text = testo
	etichetta.font = carattere_insegne()
	etichetta.font_size = 160
	etichetta.pixel_size = altezza_testo * 0.0062
	etichetta.position = Vector3(0, 0, 0.14)
	etichetta.modulate = Color(0.98, 0.90, 1.0)
	etichetta.outline_size = 22
	etichetta.outline_modulate = Color(NEON.r * 0.6, NEON.g * 0.4, NEON.b * 0.7, 1.0)
	etichetta.shaded = false
	etichetta.double_sided = false
	etichetta.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	pannello.add_child(etichetta)


## Uno striscione: un telo che pende dal soffitto, con una riga chiara in fondo
## e il nome del gioco. `dove` è il punto in cui è appeso.
static func _striscione(arena: Node3D, dove: Vector3, giro: float, colore: Color) -> void:
	var radice := Node3D.new()
	radice.position = dove
	radice.rotation_degrees.y = giro
	arena.add_child(radice)

	var telo := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.5, 3.4, 0.05)
	telo.mesh = mesh
	telo.position = Vector3(0, -1.7, 0)
	var stoffa := materiale_di("moquette").duplicate() as StandardMaterial3D
	stoffa.albedo_color = colore
	stoffa.emission = colore
	stoffa.emission_energy_multiplier = 0.12
	stoffa.uv1_scale = Vector3.ONE / 0.9
	telo.material_override = stoffa
	radice.add_child(telo)

	var riga := MeshInstance3D.new()
	var mesh_riga := BoxMesh.new()
	mesh_riga.size = Vector3(1.5, 0.16, 0.06)
	riga.mesh = mesh_riga
	riga.position = Vector3(0, -3.2, 0)
	riga.material_override = Muratura.acceso(Color(0.98, 0.96, 1.0), 0.55)
	riga.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	radice.add_child(riga)

	var etichetta := Label3D.new()
	etichetta.text = "PENTAWALL"
	etichetta.font = carattere_insegne()
	etichetta.font_size = 160
	etichetta.pixel_size = 0.0019
	etichetta.position = Vector3(0, -2.85, 0.04)
	etichetta.modulate = Color(0.98, 0.96, 1.0)
	etichetta.shaded = false
	etichetta.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	radice.add_child(etichetta)


static func _lampada(arena: Node3D, dove: Vector3, colore: Color, forza: float, portata: float) -> void:
	var luce := OmniLight3D.new()
	luce.position = dove
	luce.light_color = colore
	luce.light_energy = forza
	luce.omni_range = portata
	luce.shadow_enabled = false
	arena.add_child(luce)


# ------------------------------------------------------------------ corpi

## Un corpo a blocchetti (Kenney, «Mini Characters»), scalato all'altezza data,
## con il blaster nella mano destra e la posa di chi lo tiene. `personaggio` è
## il suffisso del file: `male-a` … `male-f`, `female-a` … `female-f`.
static func corpo_blocchetti(personaggio: String, altezza: float, con_blaster := true) -> Node3D:
	var radice := Node3D.new()
	var scena: PackedScene = load(MODELLI + "mini/character-" + personaggio + ".glb")
	var corpo: Node3D = scena.instantiate()
	var scala := altezza / ALTEZZA_BLOCCHETTI
	corpo.scale = Vector3.ONE * scala
	# Il contorno cresce nello spazio del modello: chi lo costruisce deve sapere
	# di quanto il modello è ingrandito, o il filo diventa una fascia.
	radice.set_meta("scala", scala)
	# Nel file guarda verso +Z; da noi avanti è -Z.
	corpo.rotation_degrees.y = 180.0
	radice.add_child(corpo)

	var animatore := corpo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animatore != null:
		var posa := "holding-right" if con_blaster else "idle"
		if animatore.has_animation(posa):
			animatore.play(posa)

	if con_blaster:
		var scheletro := trova(corpo, "Skeleton3D") as Skeleton3D
		if scheletro != null:
			var attacco := BoneAttachment3D.new()
			attacco.bone_name = "arm-right"
			scheletro.add_child(attacco)
			var blaster: Node3D = (load(MODELLI + "blaster/blaster-a.glb") as PackedScene).instantiate()
			blaster.position = Vector3(0.0, 0.19, 0.0)
			blaster.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			blaster.scale = Vector3.ONE * 0.36
			attacco.add_child(blaster)
	return radice


## Un corpo umano (Quaternius, «Universal Base Characters», CC0), con le
## animazioni della libreria gemella (CC0): condividono lo stesso scheletro a
## sessantacinque ossa, quindi le animazioni si prestano al corpo così come sono.
## `personaggio` inizia per `male` o `female`.
static func corpo_umano(personaggio: String, altezza: float, colore: Color,
		con_blaster := true) -> Node3D:
	var radice := Node3D.new()
	var file := "Superhero_Female_FullBody" if personaggio.begins_with("female") 			else "Superhero_Male_FullBody"
	var scena: PackedScene = load(MODELLI_UMANI + file + ".gltf")
	var corpo: Node3D = scena.instantiate()
	var scala := altezza / ALTEZZA_UMANI
	corpo.scale = Vector3.ONE * scala
	corpo.rotation_degrees.y = 180.0
	radice.set_meta("scala", scala)
	radice.add_child(corpo)
	_vesti_di_tuta(corpo, file, colore)
	_pettina(corpo, "Hair_Long" if file.contains("Female") else "Hair_SimpleParted")

	var libreria: Node = (load(ANIMAZIONI_UMANE) as PackedScene).instantiate()
	var origine := libreria.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if origine != null:
		var animatore := AnimationPlayer.new()
		animatore.name = "AnimationPlayer"
		for nome in origine.get_animation_library_list():
			animatore.add_animation_library(nome, origine.get_animation_library(nome))
		corpo.add_child(animatore)
		var posa := "Pistol_Idle" if con_blaster else "Idle"
		if animatore.has_animation(posa):
			animatore.play(posa)
	libreria.free()

	if con_blaster:
		var scheletro := trova(corpo, "Skeleton3D") as Skeleton3D
		if scheletro != null:
			var attacco := BoneAttachment3D.new()
			attacco.bone_name = "hand_r"
			scheletro.add_child(attacco)
			var blaster: Node3D = (load(MODELLI + "blaster/blaster-a.glb") as PackedScene).instantiate()
			blaster.scale = Vector3.ONE * 0.7
			attacco.add_child(blaster)
	return radice


## La tuta da gara addosso al corpo base: il corpo nel pacchetto libero è nudo,
## e la tuta gliela mette uno shader — pelle dove la maschera è bianca (la
## testa), colore della squadra dappertutto altrove, con le pieghe e la
## lucentezza del corpo. Un colore per concorrente, senza una texture in più.
static func _vesti_di_tuta(corpo: Node3D, file: String, colore: Color) -> void:
	var sesso := "Female" if file.contains("Female") else "Male"
	var grande: MeshInstance3D = null
	var quanti := 0
	for nodo in tutti(corpo):
		if nodo is MeshInstance3D and (nodo as MeshInstance3D).mesh != null:
			var facce := (nodo as MeshInstance3D).mesh.get_faces().size()
			if facce > quanti:
				quanti = facce
				grande = nodo
	if grande == null:
		return
	var vecchio := grande.get_active_material(0) as BaseMaterial3D
	var materiale := ShaderMaterial.new()
	materiale.shader = load(TUTA)
	if vecchio != null:
		materiale.set_shader_parameter("base", vecchio.albedo_texture)
		materiale.set_shader_parameter("normale", vecchio.normal_texture)
		materiale.set_shader_parameter("rugosita", vecchio.roughness_texture)
	materiale.set_shader_parameter("maschera", load(MODELLI_UMANI + "Maschera_Testa_" + sesso + ".png"))
	materiale.set_shader_parameter("tuta", colore)
	grande.material_override = materiale


## I capelli: nel pacchetto stanno a parte, fermi nella posa di riposo del
## corpo. Si appendono all'osso della testa, spostati all'indietro di quanto la
## testa sta avanti a riposo: così seguono la testa da qualunque posa.
static func _pettina(corpo: Node3D, taglio: String) -> void:
	var scheletro := trova(corpo, "Skeleton3D") as Skeleton3D
	if scheletro == null:
		return
	var testa := scheletro.find_bone("Head")
	if testa < 0:
		return
	var scena: PackedScene = load(CAPELLI + taglio + ".gltf")
	if scena == null:
		return
	var attacco := BoneAttachment3D.new()
	attacco.bone_name = "Head"
	scheletro.add_child(attacco)
	var pettinatura: Node3D = scena.instantiate()
	pettinatura.transform = scheletro.get_bone_global_rest(testa).affine_inverse()
	attacco.add_child(pettinatura)


## I due gusci del contorno attorno a un corpo vero: lo stesso meccanismo della
## capsula dell'avversario (filo scuro attaccato, contorno acceso fuori), fatto
## per ogni pezzo di pelle del modello. Torna l'elenco che l'avversario tiene
## aggiornato fotogramma per fotogramma.
static func con_contorno(corpo: Node3D, scuro: Color, acceso: Color) -> Array:
	var contorni := []
	var scala: float = float(corpo.get_meta("scala", 1.0))
	for nodo in tutti(corpo):
		if not (nodo is MeshInstance3D):
			continue
		var pezzo := nodo as MeshInstance3D
		for guscio in [
			{"colore": scuro, "quota": Avversario.SPESSORE_FILO / scala},
			{"colore": acceso, "quota": 1.0 / scala},
		]:
			var copia := pezzo.duplicate() as MeshInstance3D
			var pelle := Avversario._pelle_alone(guscio["colore"])
			copia.material_override = pelle
			copia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pezzo.add_sibling(copia)
			contorni.append({"materiale": pelle, "quota": guscio["quota"]})
	return contorni


## La targhetta col nome sopra la testa: risponde a «chi mi ha preso?».
static func targhetta(chi: Node3D, nome: String, altezza: float, colore: Color) -> Label3D:
	var etichetta := Label3D.new()
	etichetta.text = nome
	etichetta.font = carattere_insegne()
	etichetta.font_size = 96
	etichetta.pixel_size = 0.0034
	etichetta.position = Vector3(0, altezza + 0.42, 0)
	etichetta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etichetta.modulate = colore
	etichetta.outline_size = 18
	etichetta.outline_modulate = Color(0.02, 0.02, 0.06, 0.9)
	etichetta.shaded = false
	etichetta.no_depth_test = false
	etichetta.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	chi.add_child(etichetta)
	return etichetta


# ------------------------------------------------------------------ attrezzi

static func carattere_insegne() -> Font:
	if _carattere != null:
		return _carattere
	var base: Font = load(CARATTERE_INSEGNE)
	if base is FontFile:
		var copia: FontFile = (base as FontFile).duplicate()
		copia.generate_mipmaps = true
		_carattere = copia
	else:
		_carattere = Muratura.carattere()
	return _carattere


## Tutti i discendenti di un nodo, in un elenco.
static func tutti(nodo: Node) -> Array:
	var elenco := []
	for figlio in nodo.get_children():
		elenco.append(figlio)
		elenco.append_array(tutti(figlio))
	return elenco


## Il primo discendente di una classe data.
static func trova(nodo: Node, classe: String) -> Node:
	for figlio in nodo.get_children():
		if figlio.is_class(classe):
			return figlio
		var dentro := trova(figlio, classe)
		if dentro != null:
			return dentro
	return null
