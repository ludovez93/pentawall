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

## Il gruppo dei pavimenti: la vestizione ci mette sopra il parquet, non la
## superficie dei muri della stessa tinta (tappa 8, blocco E).
const GRUPPO_PAVIMENTI := &"pavimenti"

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

## Il carattere delle insegne, preparato una volta sola.
static var _carattere: Font = null


## Un muro: si vede, ci si cammina contro, e **ferma il dardo**.
##
## `smusso` arrotonda gli spigoli di quel raggio, in metri (tappa 8, blocco E: la
## regola delle forme del 12/09/2026, *«le forme sono tutte quadrate e linee
## perfette, troppo no?»*). **La collisione resta la scatola**: si cambia l'aspetto,
## non il gioco — un dardo che si ferma su un muro si ferma dove si fermava.
static func muro(genitore: Node, centro: Vector3, misura: Vector3, colore: Color,
		giro := Vector3.ZERO, smusso := 0.0) -> StaticBody3D:
	var corpo := _corpo(genitore, centro, misura, giro, Strati.OSTACOLO)
	corpo.add_to_group(GRUPPO_MURI)
	if smusso > 0.0:
		var pezzo := MeshInstance3D.new()
		pezzo.mesh = scatola_smussata(misura, smusso)
		pezzo.material_override = opaco(colore, misura)
		corpo.add_child(pezzo)
	else:
		_pelle(corpo, misura, opaco(colore, misura))
	return corpo


## Un pilone tondo: lo stesso muro, ma cilindrico, e questa volta **anche la
## collisione è tonda**. Un pilone non è una sponda — ferma il dardo, non lo rimbalza
## — quindi la sua forma non cambia nessuna traiettoria prevista; una scatola dentro
## un cilindro invece fermerebbe i colpi nell'aria accanto agli spigoli che non si
## vedono.
static func pilone(genitore: Node, centro: Vector3, raggio: float, alto: float,
		colore: Color) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.collision_layer = Strati.OSTACOLO
	corpo.collision_mask = 0
	corpo.position = centro
	corpo.add_to_group(GRUPPO_MURI)
	genitore.add_child(corpo)
	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = raggio
	cilindro.height = alto
	forma.shape = cilindro
	corpo.add_child(forma)
	var pezzo := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = raggio
	mesh.bottom_radius = raggio
	mesh.height = alto
	mesh.radial_segments = 28
	mesh.rings = 1
	pezzo.mesh = mesh
	pezzo.material_override = opaco(colore, Vector3(raggio * 2.0, alto, raggio * 2.0))
	corpo.add_child(pezzo)
	return corpo


## Le scatole smussate già costruite, per misura: cinque colonne uguali sono una
## forma sola.
static var _smussate := {}


## Una scatola con gli spigoli arrotondati: ogni faccia è una griglia fitta solo
## vicino ai bordi, e ogni vertice si proietta sulla superficie di una scatola più
## piccola gonfiata del raggio. Le facce piane restano piane (due triangoli per
## campo), gli spigoli e gli angoli diventano quarti di cilindro e ottavi di sfera.
static func scatola_smussata(misura: Vector3, raggio: float, segmenti := 3) -> ArrayMesh:
	var chiave := "%.3f|%.3f|%.3f|%.3f|%d" % [misura.x, misura.y, misura.z, raggio, segmenti]
	if _smussate.has(chiave):
		return _smussate[chiave]
	var meta := misura * 0.5
	var r := minf(raggio, minf(meta.x, minf(meta.y, meta.z)) * 0.98)
	var interno := meta - Vector3.ONE * r
	var campioni := [_campioni(meta.x, r, segmenti), _campioni(meta.y, r, segmenti),
			_campioni(meta.z, r, segmenti)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for asse in 3:
		for segno in [-1.0, 1.0]:
			var asse_u := (asse + 1) % 3
			var asse_v := (asse + 2) % 3
			var us: PackedFloat32Array = campioni[asse_u]
			var vs: PackedFloat32Array = campioni[asse_v]
			var fuori := Vector3.ZERO
			fuori[asse] = segno
			var punti: Array[Vector3] = []
			var normali: Array[Vector3] = []
			for i in us.size():
				for j in vs.size():
					var p := Vector3.ZERO
					p[asse] = meta[asse] * segno
					p[asse_u] = us[i]
					p[asse_v] = vs[j]
					var dentro := p.clamp(-interno, interno)
					var d := p - dentro
					var n := d.normalized() if d.length_squared() > 0.0000001 else fuori
					punti.append(dentro + n * r)
					normali.append(n)
			var righe := vs.size()
			for i in us.size() - 1:
				for j in righe - 1:
					var a := i * righe + j
					var b := (i + 1) * righe + j
					var c := (i + 1) * righe + j + 1
					var e := i * righe + j + 1
					for triangolo in [[a, b, c], [a, c, e]]:
						var t: Array = triangolo
						# Godot vuole il senso orario visto da fuori: se il triangolo
						# guarda dentro, si legge al contrario.
						var croce := (punti[t[1]] - punti[t[0]]).cross(punti[t[2]] - punti[t[0]])
						if croce.dot(fuori) > 0.0:
							t = [t[0], t[2], t[1]]
						for k in t:
							st.set_normal(normali[k])
							st.set_uv(Vector2(punti[k][asse_u], punti[k][asse_v]) * 0.25)
							st.add_vertex(punti[k])
	st.generate_tangents()
	var mesh := st.commit()
	_smussate[chiave] = mesh
	return mesh


## Le coordinate lungo un lato: i campioni dell'arco a un capo, i due bordi del
## piano, i campioni dell'arco all'altro capo.
static func _campioni(meta: float, raggio: float, segmenti: int) -> PackedFloat32Array:
	var fuori := PackedFloat32Array()
	for k in segmenti + 1:
		fuori.append(-meta + raggio - raggio * cos(float(k) / float(segmenti) * PI * 0.5))
	for k in range(segmenti, -1, -1):
		fuori.append(meta - raggio + raggio * cos(float(k) / float(segmenti) * PI * 0.5))
	return fuori


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
	etichetta.font = carattere()
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
## Un colore pieno, senza texture e senza luce propria. **Ha l'emissione accesa, e
## nera**: così usa lo stesso shader di `acceso` invece di farne compilare uno suo.
## Sul telefono ogni shader diverso sono cinque compilazioni (tappa 9, `Scorta`).
static func tinta_unita(colore: Color, ruvidita: float) -> StandardMaterial3D:
	var materiale := StandardMaterial3D.new()
	materiale.albedo_color = colore
	materiale.roughness = ruvidita
	materiale.emission_enabled = true
	materiale.emission = Color.BLACK
	return materiale


static func acceso(colore: Color, luce: float) -> StandardMaterial3D:
	var materiale := StandardMaterial3D.new()
	materiale.albedo_color = colore
	materiale.roughness = 0.5
	materiale.metallic = 0.05
	materiale.emission_enabled = true
	materiale.emission = colore
	materiale.emission_energy_multiplier = luce
	return materiale


## Il carattere delle insegne, **con le mipmap accese**.
##
## Senza, un'insegna guardata da lontano e di scorcio si riduce a pochi pixel e il
## ritaglio della trasparenza li alterna bianco e nero: da dentro l'arena si vede
## un quadratino a scacchi, identico a quello con cui Godot dice «qui manca una
## texture». Non manca niente: è il testo, sottocampionato. Trovato il 26/08/2026
## sull'insegna TURBO a ventisette metri, isolandola in uno scatto suo
## (`scatti/96-insegna-di-scorcio.png`) invece di indovinare.
static func carattere() -> Font:
	if _carattere != null:
		return _carattere
	var base := ThemeDB.fallback_font
	if base is FontFile:
		var copia: FontFile = (base as FontFile).duplicate()
		copia.generate_mipmaps = true
		_carattere = copia
	else:
		_carattere = base
	return _carattere


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


## Un pavimento di forma qualunque, dato il suo contorno visto dall'alto.
##
## Serve dalla tappa 5: il catino dell'arena è un ottagono, e un ottagono non si
## fa con una scatola. Il contorno si dà in metri sul piano orizzontale, la quota
## è quella del **piano calpestabile** — sotto ci va lo spessore, così camminare
## a quota zero vuol dire davvero stare a zero.
##
## Come i muri: ferma il dardo e non lo rimbalza. Quello che rimbalza si dichiara
## con `sponda()`, sempre e solo.
##
## `parti` sono i pezzi del contorno **da disegnare**, quando un altro pavimento alla
## stessa quota ne copre una parte (`Arena._parti_scoperte`): vuoto vuol dire tutto.
## `solidi` sono i pezzi **che reggono il peso**, quando una rampa ha ritagliato il
## pavimento (`Arena._ritaglia_le_rampe`): vuoto vuol dire il contorno intero. Un
## pezzo ritagliato può essere concavo, e la collisione di un prisma deve essere
## convessa: lo si spezza in parti convesse, una forma per parte.
static func piano(genitore: Node, contorno: PackedVector2Array, quota: float,
		spessore: float, colore: Color,
		parti: Array[PackedVector2Array] = [],
		solidi: Array[PackedVector2Array] = []) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.collision_layer = Strati.OSTACOLO
	corpo.collision_mask = 0
	corpo.add_to_group(GRUPPO_MURI)
	corpo.add_to_group(GRUPPO_PAVIMENTI)
	genitore.add_child(corpo)

	var alto := quota
	var basso := quota - spessore
	var convessi: Array[PackedVector2Array] = [contorno]
	if not solidi.is_empty():
		convessi.clear()
		for pezzo in solidi:
			convessi.append_array(Geometry2D.decompose_polygon_in_convex(pezzo))
	for convesso in convessi:
		var punti := PackedVector3Array()
		for p in convesso:
			punti.append(Vector3(p.x, alto, p.y))
		for p in convesso:
			punti.append(Vector3(p.x, basso, p.y))
		var forma := CollisionShape3D.new()
		var scatola := ConvexPolygonShape3D.new()
		scatola.points = punti
		forma.shape = scatola
		corpo.add_child(forma)

	var materiale := opaco(colore, Vector3(_larghezza(contorno), spessore, _larghezza(contorno)))
	var da_disegnare := parti
	if da_disegnare.is_empty():
		da_disegnare = [contorno]
	for parte in da_disegnare:
		var pezzo := MeshInstance3D.new()
		pezzo.mesh = _prisma(parte, alto, basso)
		pezzo.material_override = materiale
		corpo.add_child(pezzo)
	return corpo


## Una rampa: un piano inclinato che porta da una quota all'altra.
##
## Si dà come la si racconta — da dove a dove, e fra che quote — invece che con
## un centro e due rotazioni: una rampa descritta con gli angoli di Eulero è una
## rampa che prima o poi guarda dalla parte sbagliata.
static func rampa(genitore: Node, da: Vector2, a: Vector2, larghezza: float,
		quota_da: float, quota_a: float, spessore: float, colore: Color) -> StaticBody3D:
	var piatto := a - da
	var dislivello := quota_a - quota_da
	var lunghezza := sqrt(piatto.length_squared() + dislivello * dislivello)
	var avanti := Vector3(piatto.x, dislivello, piatto.y).normalized()
	var destra := avanti.cross(Vector3.UP).normalized()
	if destra.length_squared() < 0.5:
		destra = Vector3.RIGHT
	var su := destra.cross(avanti)

	var corpo := StaticBody3D.new()
	corpo.collision_layer = Strati.OSTACOLO
	corpo.collision_mask = 0
	corpo.add_to_group(GRUPPO_MURI)
	# Il centro scende di mezzo spessore **lungo la normale** della rampa, non in
	# verticale: così la faccia di sopra va esattamente da (da, quota_da) ad
	# (a, quota_a). In verticale le cime restavano fino a 13 cm indietro e 4 cm
	# sotto il piano d'arrivo (misurato il 04/10/2026).
	corpo.transform = Transform3D(Basis(destra, su, -avanti),
			Vector3((da.x + a.x) * 0.5, (quota_da + quota_a) * 0.5, (da.y + a.y) * 0.5)
					- su * spessore * 0.5)
	genitore.add_child(corpo)

	var misura := Vector3(larghezza, spessore, lunghezza)
	var forma := CollisionShape3D.new()
	var scatola := BoxShape3D.new()
	scatola.size = misura
	forma.shape = scatola
	corpo.add_child(forma)
	_pelle(corpo, misura, opaco(colore, misura))

	# **I cordoli sui due bordi lunghi.** È la stessa riga chiara che i piani alti
	# hanno sui lati che danno sul vuoto (LEARNED.md § 31), e per lo stesso motivo:
	# dal telefono, il 12/09/2026, «sono salito su una rampa e sono nel vuoto». Una
	# rampa è un piano inclinato con il vuoto su tutti e due i fianchi, e senza un
	# bordo che la stacchi è una fascia di colore che finisce chissà dove.
	for lato in [-1.0, 1.0]:
		var cordolo := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(CORDOLO_LARGHEZZA, CORDOLO_ALTEZZA, lunghezza)
		cordolo.mesh = mesh
		cordolo.position = Vector3(lato * (larghezza * 0.5 - CORDOLO_LARGHEZZA * 0.5),
				spessore * 0.5 + CORDOLO_ALTEZZA * 0.5, 0.0)
		cordolo.material_override = acceso(CORDOLO, 0.55)
		cordolo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		corpo.add_child(cordolo)
	return corpo


## Il cordolo: la riga chiara che dice dove finisce un piano. La tinta è quella
## dell'arena (`Arena._cordoli`), scritta qui una volta perché rampe e piani
## dicano la stessa cosa con lo stesso segno.
const CORDOLO := Color(0.78, 0.72, 0.95)
const CORDOLO_LARGHEZZA := 0.18
const CORDOLO_ALTEZZA := 0.06


## Il prisma di un contorno: la faccia di sopra, quella di sotto e i fianchi.
##
## **Il verso dei triangoli si decide guardandolo, non si dà per scontato.** Fino al
## 03/10/2026 la faccia di sopra era girata dalla parte sbagliata: Godot vuole il
## senso orario visto da fuori, e un pavimento visto dall'alto con il senso
## contrario **non si disegna**. Dalla tappa 5 in poi tutti i pavimenti dell'arena
## sono stati invisibili dall'alto — si camminava sopra lo sfondo blu notte, ed è
## con ogni probabilità il «cammino nel vuoto» arrivato dal telefono il 12/09/2026.
## La fisica non c'entrava (la collisione è un'altra forma, ed era giusta), e
## nessun collaudo poteva accorgersene: lo ha trovato il parquet, che non si vedeva.
## Adesso ogni triangolo si controlla contro la normale che deve avere, e se
## guarda dentro si legge al contrario.
##
## **E la faccia di sotto.** Il prisma non l'aveva mai avuta: da sotto, a fare da
## soffitto alle terrazze, al ballatoio e alla passerella era proprio la faccia di
## sopra girata al contrario. Raddrizzata quella, il 03/10/2026 i piani alti sono
## spariti visti da sotto, e dal telefono: *«vedo la gente camminare sui soffitti
## da sotto»* (`LEARNED.md` § 45).
static func _prisma(contorno: PackedVector2Array, alto: float, basso: float) -> ArrayMesh:
	var triangoli := Geometry2D.triangulate_polygon(contorno)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Luce piatta: senza, `generate_normals` mescola le normali dei vertici che
	# stanno nello stesso punto, e sugli spigoli quella del pavimento si piega
	# verso i fianchi fino a 66 gradi (misurato sul ballatoio, 03/10/2026) — il
	# parquet si illumina a chiazze.
	st.set_smooth_group(-1)

	for faccia in [[alto, Vector3.UP], [basso, Vector3.DOWN]]:
		var i := 0
		while i < triangoli.size():
			var tre: Array[Vector3] = []
			for k in 3:
				var p: Vector2 = contorno[triangoli[i + k]]
				tre.append(Vector3(p.x, faccia[0], p.y))
			_triangolo_verso(st, tre, faccia[1], func(v: Vector3) -> Vector2:
					return Vector2(v.x, v.z) * 0.25)
			i += 3

	var n := contorno.size()
	for j in n:
		var p1: Vector2 = contorno[j]
		var p2: Vector2 = contorno[(j + 1) % n]
		if p1.distance_to(p2) < 0.0001:
			continue
		# Il fuori di questo lato: la perpendicolare che esce dal poligono. Si prova
		# un passo dal centro del lato — vale anche per i contorni concavi.
		var lato := (p2 - p1).normalized()
		var perpendicolare := Vector2(lato.y, -lato.x)
		if Geometry2D.is_point_in_polygon((p1 + p2) * 0.5 + perpendicolare * 0.01, contorno):
			perpendicolare = -perpendicolare
		var fuori := Vector3(perpendicolare.x, 0.0, perpendicolare.y)
		var quadro := [
			Vector3(p1.x, alto, p1.y), Vector3(p2.x, alto, p2.y),
			Vector3(p2.x, basso, p2.y), Vector3(p1.x, basso, p1.y),
		]
		var uv := func(v: Vector3) -> Vector2:
			return Vector2(v.x + v.z, v.y) * 0.25
		_triangolo_verso(st, [quadro[0], quadro[1], quadro[2]] as Array[Vector3], fuori, uv)
		_triangolo_verso(st, [quadro[0], quadro[2], quadro[3]] as Array[Vector3], fuori, uv)

	st.generate_normals()
	return st.commit()


## Un triangolo girato in modo che la sua faccia guardi verso `fuori`: Godot disegna
## il senso orario visto da fuori, cioè il prodotto dei lati che punta lontano da chi
## guarda.
static func _triangolo_verso(st: SurfaceTool, tre: Array[Vector3], fuori: Vector3,
		uv: Callable) -> void:
	var croce := (tre[1] - tre[0]).cross(tre[2] - tre[0])
	var ordine := [0, 1, 2] if croce.dot(fuori) < 0.0 else [0, 2, 1]
	for k in ordine:
		st.set_uv(uv.call(tre[k]))
		st.add_vertex(tre[k])


static func _larghezza(contorno: PackedVector2Array) -> float:
	var minimo := contorno[0]
	var massimo := contorno[0]
	for p in contorno:
		minimo = minimo.min(p)
		massimo = massimo.max(p)
	return maxf(massimo.x - minimo.x, massimo.y - minimo.y)
