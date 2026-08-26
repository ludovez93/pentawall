extends SceneTree

## Cuoce la rete di cammino dell'arena e la salva nel repository.
##
## **Perché in anticipo e non all'apertura della scena.** La pagina web gira senza
## thread (`variant/thread_support=false`, e su GitHub Pages non si può fare
## altrimenti): lì una cottura sarebbe mezzo secondo di gioco fermo in faccia a chi
## ha appena aperto il link. Cotta qui, l'arena la carica e basta.
##
## **Accanto alla rete si scrive l'impronta della pianta da cui è nata.** È quello
## che permette al collaudo di dire «questa rete è vecchia» il giorno che si sposta
## un muro nel `.json` — altrimenti il bot cammina dentro il muro e non se ne
## accorge nessuno. La pianta è un file di testo che si corregge a mano, e questa è
## la sua guardia.
##
## Uso:  godot --path . -s tools/cuoci_percorsi.gd

const PIANTA := "res://arene/palestra.json"
const RETE := "res://arene/palestra_cammino.res"
const IMPRONTA := "res://arene/palestra_cammino.json"

## Il corpo di chi cammina: raggio 0,42 e altezza 1,8 sono quelli del giocatore e
## dell'avversario, che sono lo stesso corpo. Il raggio si arrotonda in su, così la
## rete non passa mai più vicino a un muro di quanto ci si possa passare davvero.
const RAGGIO := 0.5
const ALTEZZA := 1.8

## Quanto si scavalca camminando. Le sponde a pavimento sporgono sette centimetri
## e gli zoccoli poco più; i cassoni sono alti due metri e restano ostacoli, che è
## esattamente quello che devono essere.
const SCALINO := 0.4

## La rampa più ripida dell'arena è quella che sale in piattaforma nell'ocra: 3,5
## metri di dislivello in 3,8 di pianta, cioè 43°. Il tetto sta appena sopra.
const PENDENZA_MASSIMA := 47.0

## La griglia della cottura. Un quarto di metro su un'arena di sessantasei è la
## misura in cui una rampa larga sette metri resta larga sette metri.
const CELLA := 0.25
const CELLA_ALTA := 0.2

## Sotto questa superficie un pezzo di rete è un'isola: il tetto di un cassone, il
## box del catino. Scartarle serve a non far calcolare percorsi verso posti dove
## non si sale.
const ISOLA_MINIMA := 2.0


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	# Due fotogrammi: la scena si costruisce in `_ready`, e le forme di collisione
	# esistono per il parser solo dopo che sono entrate nell'albero.
	await process_frame
	await process_frame

	var rete := _rete_vuota()
	var sorgente := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(rete, sorgente, arena)
	if sorgente.has_data():
		NavigationServer3D.bake_from_source_geometry_data(rete, sorgente)

	var poligoni := rete.get_polygon_count()
	var vertici := rete.get_vertices().size()
	print("cotti %d poligoni su %d vertici" % [poligoni, vertici])
	if poligoni == 0:
		printerr("la cottura non ha prodotto niente: la rete non si salva")
		quit(1)
		return

	var esito := ResourceSaver.save(rete, RETE)
	if esito != OK:
		printerr("non si è potuta salvare la rete: errore %d" % esito)
		quit(1)
		return

	_scrivi_impronta(poligoni, vertici)
	print("salvata in ", RETE)
	print("impronta in ", IMPRONTA)
	quit()


func _rete_vuota() -> NavigationMesh:
	var rete := NavigationMesh.new()
	rete.cell_size = CELLA
	rete.cell_height = CELLA_ALTA
	rete.agent_radius = RAGGIO
	rete.agent_height = ALTEZZA
	rete.agent_max_climb = SCALINO
	rete.agent_max_slope = PENDENZA_MASSIMA
	rete.region_min_size = ISOLA_MINIMA
	# Si guardano **le forme di collisione**, non le mesh: nell'arena la parte che
	# si vede e la parte che ferma sono due cose diverse, e a chi cammina interessa
	# la seconda. Le insegne, i lucernari e gli anelli del rimbalzo sono decori
	# puri e qui non esistono, che è giusto.
	rete.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	rete.geometry_collision_mask = Strati.SOLIDO
	# Un pertugio alto meno di un corpo non è un passaggio: senza questo la rete
	# ne fa uno sotto le rampe.
	rete.filter_walkable_low_height_spans = true
	return rete


## L'impronta è il `sha256` della pianta: due righe, e il collaudo può dire se la
## rete racconta l'arena di oggi o quella di ieri.
func _scrivi_impronta(poligoni: int, vertici: int) -> void:
	var scheda := {
		"pianta": PIANTA,
		"impronta": FileAccess.get_sha256(PIANTA),
		"cotta_il": Time.get_date_string_from_system(),
		"poligoni": poligoni,
		"vertici": vertici,
		"cotta_per": {
			"raggio": RAGGIO,
			"altezza": ALTEZZA,
			"scalino": SCALINO,
			"pendenza_massima": PENDENZA_MASSIMA,
			"cella": CELLA,
		},
	}
	var file := FileAccess.open(IMPRONTA, FileAccess.WRITE)
	file.store_string(JSON.stringify(scheda, "  ") + "\n")
	file.close()
