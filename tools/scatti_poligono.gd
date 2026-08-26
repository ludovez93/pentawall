extends SceneTree

## Attrezzo di lavorazione: apre il poligono, lo pilota da solo e salva una serie
## di scatti. Non fa parte del gioco.
##
## Serve perché di questa tappa metà delle cose si giudicano solo guardandole —
## se il dardo si stacca dal fondo, se la linea di mira si legge, se l'angolo
## cieco nasconde davvero i bersagli — e una scena può essere valida, importare
## senza un errore e inquadrare il vuoto (LEARNED.md 14).
##
## Uso:  godot --path . -s tools/scatti_poligono.gd
## Gli scatti finiscono in `scatti/`, che non entra nel repository.

const CARTELLA := "res://scatti"

## Il dardo vola a 19 m/s: a velocità normale, fra un fotogramma e l'altro fa
## mezzo metro e negli scatti non si becca mai. Rallentando il tempo si fotografa
## in volo senza cambiare una riga del gioco.
const RALLENTATORE := 0.1

var _poligono: Node
var _giocatore: Giocatore


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	DirAccess.make_dir_recursive_absolute(CARTELLA)
	_poligono = load("res://scenes/poligono.tscn").instantiate()
	root.add_child(_poligono)
	await process_frame
	await process_frame
	_giocatore = _poligono.call("giocatore")

	# 1. Come si apre il gioco: terza persona, la stanza intera, la linea di mira.
	_metti(Vector3(-9.0, 1.0, 6.5), 18.0, -6.0)
	await _riposa(24)
	await _scatta("01-apertura-terza-persona.png")

	# 2. La linea di mira puntata su una parete lontana: è la contromossa al
	#    rischio numero uno, e o si legge a colpo d'occhio o non serve a niente.
	_metti(Vector3(12.0, 1.0, 8.0), 35.0, -1.0)
	await _riposa(16)
	await _scatta("02-linea-di-mira-sulla-parete.png")

	# 3-4. Un dardo in volo e lo stesso dardo dopo il rimbalzo. Il dardo corre
	#      lungo la linea di vista, quindi di faccia resta nascosto dietro il
	#      mirino: dopo il colpo si gira la testa e lo si guarda passare di lato.
	Engine.time_scale = RALLENTATORE
	_giocatore.spara()
	await _riposa(10)
	_giocatore.punta(-18.0, -4.0)
	await _riposa(30)
	await _scatta("03-dardo-in-volo.png")
	await _riposa(90)
	await _scatta("04-dardo-dopo-il-rimbalzo.png")
	Engine.time_scale = 1.0

	# 5. Prima persona: il mirino, il campo più stretto, l'arma in mano.
	_giocatore.cambia_camera()
	await _riposa(30)
	await _scatta("05-prima-persona.png")

	# 6. L'angolo cieco: da qui i due bersagli verdi non si devono vedere.
	_giocatore.cambia_camera()
	_metti(Vector3(-8.0, 1.0, 2.0), 74.0, -2.0)
	await _riposa(24)
	await _scatta("06-angolo-cieco.png")

	# 7. Dietro il divisorio: ecco cosa c'è, e che di là non si vedeva.
	_metti(Vector3(8.0, 1.0, -2.5), 176.0, -4.0)
	await _riposa(24)
	await _scatta("07-dietro-il-divisorio.png")

	# 8-10. I tre candidati al colore riservato, sulla scena vera con la luce
	#       vera e il dardo in volo: è qui che si sceglie, non su un campionario
	#       (DECISIONI.md § B).
	for indice in 3:
		_metti(Vector3(12.0, 1.0, 8.0), 35.0, -1.0)
		await _riposa(14)
		Engine.time_scale = RALLENTATORE
		_giocatore.spara()
		await _riposa(10)
		_giocatore.punta(-30.0, -5.0)
		await _riposa(26)
		await _scatta("%02d-colore-%s.png" % [8 + indice, _poligono.call("nome_colore")])
		Engine.time_scale = 1.0
		_poligono.call("passa_al_colore_seguente")
		await _riposa(8)

	print("scatti finiti in ", CARTELLA)
	quit(0)


func _metti(dove: Vector3, giro_gradi: float, pendenza_gradi: float) -> void:
	_giocatore.global_position = dove
	_giocatore.punta(giro_gradi, pendenza_gradi)


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var immagine := root.get_texture().get_image()
	immagine.save_png(CARTELLA + "/" + nome)
	print("  ", nome, "  ", immagine.get_width(), "x", immagine.get_height())
