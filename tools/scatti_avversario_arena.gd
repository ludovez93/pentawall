extends SceneTree

## Attrezzo di lavorazione della tappa 4: mette l'avversario davanti a **ogni**
## fondo che l'arena gli sa mettere dietro, e lo fotografa da vicino e da lontano.
##
## Serve a rispondere alla domanda della tappa prima di scegliere qualunque
## colore: **oggi, dove si perde?** Una scelta visiva si fa su una schermata vera
## con i materiali veri, mai su un campionario.
##
## Uso:  godot --path . -s tools/scatti_avversario_arena.gd

const CARTELLA := "res://scatti"

var _angolo: Node
var _giocatore: Giocatore
var _bot: Avversario


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	DirAccess.make_dir_recursive_absolute(CARTELLA)
	_angolo = load("res://scenes/angolo.tscn").instantiate()
	root.add_child(_angolo)
	await _riposa(40)
	_giocatore = _angolo.call("giocatore")
	_angolo.call("commuta_avversario")
	await _riposa(10)
	_bot = _angolo.call("avversario")
	# Fermo: qui non deve giocare, deve farsi guardare.
	_bot.bersaglio = null
	# In prima persona: in terza il proprio corpo copre proprio il punto dove sta
	# l'avversario, ed e' anche la visuale in cui si mira.
	_giocatore.cambia_camera()
	await _riposa(20)

	# Ogni voce: dove sta lui, dove sta chi guarda, come e' girato chi guarda.
	for posa in [
		{"nome": "50-contro-il-mattone", "lui": Vector3(-11.5, 0.4, -4.0),
			"io": Vector3(-3.0, 1.0, -4.0), "giro": 90.0, "pendenza": -3.0},
		{"nome": "51-contro-l-ocra", "lui": Vector3(-2.0, 0.4, -9.0),
			"io": Vector3(-2.0, 1.0, -1.0), "giro": 0.0, "pendenza": -2.0},
		{"nome": "52-contro-la-tribuna", "lui": Vector3(10.0, 0.4, 4.0),
			"io": Vector3(2.0, 1.0, 4.0), "giro": -90.0, "pendenza": -2.0},
		{"nome": "53-contro-la-moquette", "lui": Vector3(-2.0, 0.4, -2.0),
			"io": Vector3(-2.0, 4.6, 4.0), "giro": 0.0, "pendenza": -30.0},
		{"nome": "54-davanti-a-una-sponda", "lui": Vector3(-10.5, 0.4, -1.5),
			"io": Vector3(-1.0, 1.2, -1.5), "giro": 90.0, "pendenza": -1.0},
		{"nome": "55-da-venti-metri", "lui": Vector3(-10.0, 0.4, -9.0),
			"io": Vector3(8.0, 1.0, 8.0), "giro": 44.0, "pendenza": -4.0},
		{"nome": "56-in-mezzo-alla-stanza", "lui": Vector3(3.0, 0.4, -6.0),
			"io": Vector3(6.0, 1.0, 5.0), "giro": 15.0, "pendenza": -3.0},
	]:
		_bot.global_position = posa["lui"]
		_bot.velocity = Vector3.ZERO
		_giocatore.global_position = posa["io"]
		_giocatore.velocity = Vector3.ZERO
		_giocatore.punta(posa["giro"], posa["pendenza"])
		await _riposa(22)
		await _scatta("%s.png" % posa["nome"])

	# I candidati per l'alone, tutti sullo **stesso** fondo che oggi lo fa
	# sparire: e' li' che si sceglie, non su un campionario.
	for indice in Avversario.ALONI.size() + 1:
		var spento := indice == 0
		Avversario.ALONE_ACCESO = not spento
		Avversario.alone_scelto = maxi(indice - 1, 0)
		_angolo.call("commuta_avversario")
		await _riposa(4)
		_angolo.call("commuta_avversario")
		await _riposa(6)
		_bot = _angolo.call("avversario")
		_bot.bersaglio = null
		# **Corpo interamente sul mattone**, davanti al divisorio: e' il caso che
		# ha generato tutta la tappa. La posa di prima teneva mezza figura davanti
		# a una sponda accesa, che la salvava da sola — il banco di prova era piu'
		# facile del problema.
		_bot.global_position = Vector3(-4.0, 0.4, -1.7)
		_bot.velocity = Vector3.ZERO
		_giocatore.global_position = Vector3(-4.0, 1.0, 3.4)
		_giocatore.velocity = Vector3.ZERO
		_giocatore.punta(0.0, -2.0)
		await _riposa(20)
		var nome := "senza-alone" if spento else String(Avversario.ALONI[indice - 1]["nome"]).replace(" ", "-")
		await _scatta("6%d-alone-%s.png" % [indice, nome])

		# Lo stesso candidato sul fondo **chiaro**: davanti a una sponda accesa e
		# alla parete d'ocra. Un contorno chiaro puo' reggere benissimo sul buio e
		# sparire qui, ed e' meta' dell'arena.
		_bot.global_position = Vector3(-10.6, 0.4, -1.5)
		_giocatore.global_position = Vector3(-2.0, 1.2, -1.5)
		_giocatore.punta(90.0, -1.0)
		await _riposa(18)
		await _scatta("7%d-chiaro-%s.png" % [indice, nome])

	# Lo spessore del contorno si misura sullo schermo, non nel mondo: a due metri
	# non deve essere un tubo, a quattordici non un filo, e a diciotto deve essere
	# spento — un contorno che ti trova l'avversario in fondo all'arena e' il
	# marcatore da sparatutto moderno.
	Avversario.ALONE_ACCESO = true
	Avversario.alone_scelto = 0
	_angolo.call("commuta_avversario")
	await _riposa(4)
	_angolo.call("commuta_avversario")
	await _riposa(6)
	_bot = _angolo.call("avversario")
	_bot.bersaglio = null
	# Lungo il lato est, che e' libero: la prima volta a quattordici e diciotto
	# metri il giocatore finiva **dentro il muro** della tribuna, e gli scatti
	# mostravano il nero di dentro invece dell'avversario.
	for distanza in [2.0, 8.0, 14.0, 18.0]:
		_bot.global_position = Vector3(11.0, 0.4, -8.0)
		_bot.velocity = Vector3.ZERO
		_giocatore.global_position = Vector3(11.0, 1.0, -8.0 + distanza)
		_giocatore.velocity = Vector3.ZERO
		_giocatore.punta(0.0, -1.0)
		await _riposa(20)
		await _scatta("8%d-contorno-a-%d-metri.png" % [int(distanza / 4.0), int(distanza)])

	print("scatti finiti in ", CARTELLA)
	quit(0)


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var immagine := root.get_texture().get_image()
	immagine.save_png(CARTELLA + "/" + nome)
	print("  ", nome)
