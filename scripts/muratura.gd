class_name Muratura
extends RefCounted

## Il mattone delle arene: muri, sponde, decori, insegne, materiali.
##
## Nasce con la tappa 3 e serve a dire in codice la sola regola nuova rispetto al
## 1999 (`DECISIONI.md` § B): **si rimbalza sulle sponde, non su tutto**. Un muro
## e una sponda si costruiscono con due funzioni diverse perché sono due cose
## diverse del gioco, e chi legge il codice di un'arena lo vede senza cercarlo.
##
## Il poligono della tappa 1 non passa di qui: là rimbalza tutto ed è giusto così,
## ed è la stanza su cui girano sessanta controlli. Riscriverlo per farlo passare
## di qua vorrebbe dire rimettere in gioco codice che funziona in cambio di niente.

## Il gruppo dei muri che fermano il dardo. L'arena li ritrova qui per commutare
## la regola a caldo, senza tenere elenchi in giro.
const GRUPPO_MURI := &"muri_opachi"

## Il gruppo delle sponde: le superfici su cui si rimbalza.
const GRUPPO_SPONDE := &"sponde"

## Quanto sporge un pannello-sponda dalla parete. Sottile apposta: un pannello
## grosso offre al dardo un bordo di taglio, e un rimbalzo su un bordo è
## esattamente il rimbalzo che nessuno può prevedere.
const SPESSORE_SPONDA := 0.14

## La cornice al neon attorno alla sponda: sezione del listello.
const LISTELLO := 0.085

## La grana dei muri, generata una volta e prestata a tutti: è quello che li
## rende materici, e il materico contro il liscio è il primo dei tre segnali che
## distinguono una sponda (`PLAN.md`, tappa 3).
static var _grana: NoiseTexture2D = null


## Un muro: si vede, ci si cammina contro, e **ferma il dardo**.
static func muro(genitore: Node, centro: Vector3, misura: Vector3, colore: Color,
		giro := Vector3.ZERO) -> StaticBody3D:
	var corpo := _corpo(genitore, centro, misura, giro, Strati.OSTACOLO)
	corpo.add_to_group(GRUPPO_MURI)
	_pelle(corpo, misura, opaco(colore, misura))
	return corpo


## Una sponda: un pannello liscio applicato sulla parete, con il filo di neon
## attorno. È l'unica superficie su cui il dardo rimbalza.
##
## Si dà la faccia (larghezza × altezza) e la rotazione, non tre misure: una
## sponda è un piano orientato, e dirlo in questo modo rende impossibile
## costruirne una per sbaglio spessa come un muro.
static func sponda(genitore: Node, centro: Vector3, faccia: Vector2, giro: Vector3,
		colore: Color, neon: Color) -> StaticBody3D:
	var misura := Vector3(faccia.x, faccia.y, SPESSORE_SPONDA)
	var corpo := _corpo(genitore, centro, misura, giro, Strati.MONDO)
	corpo.add_to_group(GRUPPO_SPONDE)
	_pelle(corpo, misura, lucido(colore))
	_cornice(corpo, faccia, neon)
	return corpo


## Decoro puro: si vede e basta. Niente collisione, così nessun dardo rimbalza su
## una striscia dipinta — che sarebbe la bugia peggiore in un gioco di rimbalzi.
static func decoro(genitore: Node, centro: Vector3, misura: Vector3, colore: Color,
		luce: float, giro := Vector3.ZERO) -> MeshInstance3D:
	var pezzo := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = misura
	pezzo.mesh = mesh
	pezzo.position = centro
	pezzo.rotation_degrees = giro
	pezzo.material_override = acceso(colore, luce)
	pezzo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	genitore.add_child(pezzo)
	return pezzo


## Un'insegna al neon dentro l'arena: arredo di gara e segnaletica insieme, come
## nell'originale. Resta sotto la soglia del bagliore, come tutto il mondo.
static func insegna(genitore: Node, testo: String, dove: Vector3, giro: Vector3,
		misura: float, colore: Color) -> Label3D:
	var etichetta := Label3D.new()
	etichetta.text = testo
	etichetta.font_size = 160
	etichetta.pixel_size = misura * 0.006
	etichetta.position = dove
	etichetta.rotation_degrees = giro
	etichetta.modulate = Color(colore.r * 0.92, colore.g * 0.92, colore.b * 0.92)
	etichetta.outline_size = 26
	etichetta.outline_modulate = Color(0.02, 0.02, 0.06, 0.85)
	etichetta.shaded = false
	etichetta.double_sided = false
	# Senza questo il testo esce a strisce: in Compatibility la trasparenza
	# normale lo disegna a puntini invece che pieno (LEARNED.md 14).
	etichetta.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	genitore.add_child(etichetta)
	return etichetta


## Materiale di un muro: ruvido, materico, spento. È il fondo su cui una sponda
## deve saltare all'occhio.
static func opaco(colore: Color, misura := Vector3.ONE) -> StandardMaterial3D:
	var materiale := StandardMaterial3D.new()
	materiale.albedo_color = colore
	materiale.albedo_texture = grana()
	# La grana si ripete in proporzione al blocco. Il triplanare la darebbe piu'
	# regolare, ma campiona la texture tre volte per pixel: misurato su questa
	# scheda, 77 fotogrammi al secondo contro 81 — il cinque per cento, preso
	# senza perdere niente che si veda.
	var lato := maxf(misura.x, maxf(misura.y, misura.z))
	materiale.uv1_scale = Vector3.ONE * clampf(lato * 0.22, 1.0, 7.0)
	materiale.roughness = 0.92
	materiale.metallic = 0.0
	# Un filo di luce propria: senza, gli angoli in ombra diventano buchi neri e
	# l'arena smette di essere satura dappertutto, che è l'anima del 1999.
	materiale.emission_enabled = true
	materiale.emission = colore
	materiale.emission_energy_multiplier = 0.10
	return materiale


## Materiale di una sponda: liscio, senza grana, e **con la luce dentro**.
##
## La faccia emette, non riflette soltanto. È la correzione del 26/08/2026: prima
## la sponda era una lastra scura con una cornice accesa attorno, e una superficie
## scura dice «assorbe» mentre questa deve dire «restituisce». Emettendo si vede
## anche **di taglio**, che è l'angolo da cui si guarda una sponda quando la si sta
## per usare — un filo di neon visto a ottanta gradi sparisce, un rettangolo che
## fa luce no.
static func lucido(colore: Color) -> StandardMaterial3D:
	var materiale := StandardMaterial3D.new()
	materiale.albedo_color = colore
	materiale.roughness = 0.13
	materiale.metallic = 0.42
	materiale.metallic_specular = 0.85
	materiale.emission_enabled = true
	materiale.emission = colore
	# Acceso, ma **sotto la soglia del bagliore**: sopra l'uno ci va solo il dardo,
	# ed è quello che tiene insieme «arena satura» e «dardo sempre leggibile»
	# (DECISIONI.md § B).
	materiale.emission_energy_multiplier = 0.92
	return materiale


## Una superficie che fa luce da sé: neon, zoccoli, segnatura a terra.
static func acceso(colore: Color, luce: float) -> StandardMaterial3D:
	var materiale := StandardMaterial3D.new()
	materiale.albedo_color = colore
	materiale.roughness = 0.5
	materiale.metallic = 0.05
	materiale.emission_enabled = true
	materiale.emission = colore
	materiale.emission_energy_multiplier = luce
	return materiale


## La grana, generata una volta sola per tutta la partita.
static func grana() -> NoiseTexture2D:
	if _grana != null:
		return _grana
	var rumore := FastNoiseLite.new()
	rumore.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	rumore.frequency = 0.028
	rumore.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = rumore
	# Chiara e poco contrastata: deve dare materia, non disegnare macchie che
	# sembrino segnaletica.
	var scala := Gradient.new()
	scala.set_color(0, Color(0.72, 0.72, 0.72))
	scala.set_color(1, Color(1.0, 1.0, 1.0))
	texture.color_ramp = scala
	_grana = texture
	return _grana


## Il corpo e la sua forma: la parte che si vede e la parte che ferma, sempre
## insieme, così non può succedere che il dardo rimbalzi su niente o attraversi
## una parete che c'è.
static func _corpo(genitore: Node, centro: Vector3, misura: Vector3, giro: Vector3,
		strato: int) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.collision_layer = strato
	corpo.collision_mask = 0
	corpo.position = centro
	corpo.rotation_degrees = giro
	genitore.add_child(corpo)

	var forma := CollisionShape3D.new()
	var scatola := BoxShape3D.new()
	scatola.size = misura
	forma.shape = scatola
	corpo.add_child(forma)
	return corpo


static func _pelle(corpo: Node3D, misura: Vector3, materiale: StandardMaterial3D) -> void:
	var pezzo := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = misura
	pezzo.mesh = mesh
	pezzo.material_override = materiale
	corpo.add_child(pezzo)


## Il filo di neon che avvolge il pannello sui quattro lati sottili: si vede da
## tutte e due le facce e da qualunque angolo, che è il punto — la sponda va
## riconosciuta anche di scorcio, mentre si corre.
static func _cornice(corpo: Node3D, faccia: Vector2, neon: Color) -> void:
	var s := LISTELLO
	var profondita := SPESSORE_SPONDA + s
	var meta_x := faccia.x * 0.5
	var meta_y := faccia.y * 0.5
	var materiale := acceso(neon, 0.85)
	for lato in [
		{"pos": Vector3(0, meta_y, 0), "mis": Vector3(faccia.x + s, s, profondita)},
		{"pos": Vector3(0, -meta_y, 0), "mis": Vector3(faccia.x + s, s, profondita)},
		{"pos": Vector3(-meta_x, 0, 0), "mis": Vector3(s, faccia.y + s, profondita)},
		{"pos": Vector3(meta_x, 0, 0), "mis": Vector3(s, faccia.y + s, profondita)},
	]:
		var pezzo := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = lato["mis"]
		pezzo.mesh = mesh
		pezzo.position = lato["pos"]
		pezzo.material_override = materiale
		pezzo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		corpo.add_child(pezzo)
