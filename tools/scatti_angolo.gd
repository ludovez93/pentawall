extends SceneTree

## Attrezzo di lavorazione: apre l'angolo di arena, lo pilota da solo e salva una
## serie di scatti. Non fa parte del gioco.
##
## Serve perché di questa tappa **si giudica quasi tutto guardando**: se la
## direzione visiva regge, se una sponda si riconosce a colpo d'occhio, se il
## dardo bianco-arancio si stacca dalla parete d'ocra. Su questo progetto i
## difetti visivi sono usciti sei volte su sei dagli scatti e mai dal codice, e
## nessuno dei sei dava un errore (LEARNED.md 14 e 15).
##
## Uso:  godot --path . -s tools/scatti_angolo.gd

const CARTELLA := "res://scatti"
const RALLENTATORE := 0.1  ## a 19 m/s, a velocità normale il dardo non si becca mai

var _angolo: Node
var _giocatore: Giocatore


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	DirAccess.make_dir_recursive_absolute(CARTELLA)
	_angolo = load("res://scenes/angolo.tscn").instantiate()
	root.add_child(_angolo)
	# Prima di tutto: il dardo che scalda gli shader vive due fotogrammi davanti
	# alla camera, ed e' grande meno di un pixel. Questo scatto e' li' per
	# accorgersene se un giorno smettesse di esserlo.
	await _riposa(3)
	_giocatore = _angolo.call("giocatore")
	await _scatta("29-appena-aperta-col-riscaldamento.png")

	# La grana dei muri si genera in un thread: senza qualche fotogramma di
	# pazienza il primo scatto la coglie a meta'.
	await _riposa(40)

	# 1. Come si apre: l'angolo intero, terza persona, dal posto di partenza.
	_metti(Vector3(7.0, 0.6, 6.0), 49.0, -4.0)
	await _riposa(24)
	await _scatta("30-angolo-apertura.png")

	# 2. La parete d'ocra di faccia: è la prova del linguaggio delle sponde —
	#    o si distinguono dal muro in mezzo secondo, o la tappa non è passata.
	_metti(Vector3(0.0, 1.0, 4.0), 0.0, -2.0)
	await _riposa(20)
	await _scatta("31-sponde-di-faccia.png")

	# 3. Di scorcio, correndo: una sponda va riconosciuta anche così, non solo
	#    stando fermi davanti.
	_metti(Vector3(9.0, 1.0, 2.0), 62.0, -3.0)
	await _riposa(20)
	await _scatta("32-sponde-di-scorcio.png")

	# 4. La linea di mira **su una sponda**: si vede il secondo tratto, cioè dove
	#    ripartirà il dardo.
	_metti(Vector3(4.0, 1.0, 4.0), 26.0, -3.0)
	await _riposa(20)
	await _scatta("33-mira-su-sponda.png")

	# 5. La linea di mira **su un muro**: la linea si ferma lì e non riparte. È
	#    il quarto segnale, e non è costato niente — viene dalla regola stessa.
	_metti(Vector3(2.0, 1.0, 2.0), 40.0, -6.0)
	await _riposa(20)
	await _scatta("34-mira-su-muro.png")

	# 6. Il dardo davanti alla parete d'ocra: l'ocra è la tinta della palestra del
	#    1999 ed è la più vicina al bianco-arancio riservato al dardo. Se il dardo
	#    ci si perde dentro, cambia la parete — non il dardo.
	_metti(Vector3(1.0, 1.0, 0.0), 4.0, -1.0)
	await _riposa(14)
	Engine.time_scale = RALLENTATORE
	_giocatore.spara()
	await _riposa(10)
	_giocatore.punta(-30.0, -2.0)
	# Col rallentatore il dardo fa due metri al secondo: con trenta fotogrammi era
	# ancora dentro le spalle di chi ha sparato, e nel primo giro non si vedeva.
	await _riposa(150)
	await _scatta("35-dardo-sull-ocra.png")
	Engine.time_scale = 1.0

	# 7. Il rimbalzo su una sponda, con l'anello acceso nel punto d'urto: è il
	#    terzo segnale, e l'unico che non si vede stando fermi.
	# Contro la sponda della parete di mattoni, da vicino e di sbieco: la prima
	# volta il colpo prendeva un bersaglio e faceva punti invece di rimbalzare.
	# In prima persona e da vicino: in terza il proprio corpo copriva proprio il
	# punto d'urto, che e' l'unica cosa che questo scatto deve mostrare.
	_metti(Vector3(-9.4, 1.4, 0.0), 90.0, 0.0)
	_giocatore.cambia_camera()
	await _riposa(30)
	Engine.time_scale = RALLENTATORE
	_giocatore.spara()
	await _riposa(90)
	await _scatta("36-anello-sul-rimbalzo.png")
	await _riposa(24)
	await _scatta("36b-anello-piu-tardi.png")
	Engine.time_scale = 1.0
	_giocatore.cambia_camera()
	await _riposa(20)

	# 8. La piastra a terra: il caso che rompe l'idea «rimbalzano le pareti».
	_metti(Vector3(6.0, 1.0, 5.0), 22.0, -22.0)
	await _riposa(20)
	await _scatta("37-piastra-a-terra.png")

	# 9. Le tribune e il pubblico: l'arredo di gara che fa la palestra.
	_metti(Vector3(-4.0, 1.0, 0.0), -108.0, 6.0)
	await _riposa(20)
	await _scatta("38-tribune.png")

	# 10. Dall'alto del dislivello: sparare da lassù cambia tutti gli angoli.
	_metti(Vector3(-9.5, 1.8, 6.0), 30.0, -8.0)
	await _riposa(20)
	await _scatta("39-dal-dislivello.png")

	# 11. Prima persona, dove si converte il colpo.
	_metti(Vector3(4.0, 1.0, 4.0), 26.0, -3.0)
	_giocatore.cambia_camera()
	await _riposa(30)
	await _scatta("40-prima-persona.png")
	_giocatore.cambia_camera()
	await _riposa(20)

	# 12. Come sta l'angolo cieco: il bersaglio verde non si deve vedere.
	_metti(Vector3(7.0, 0.6, 6.0), 28.0, -4.0)
	await _riposa(20)
	await _scatta("41-angolo-cieco.png")

	print("scatti finiti in ", CARTELLA)
	quit(0)


func _metti(dove: Vector3, giro_gradi: float, pendenza_gradi: float) -> void:
	_giocatore.global_position = dove
	_giocatore.velocity = Vector3.ZERO
	_giocatore.punta(giro_gradi, pendenza_gradi)


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var immagine := root.get_texture().get_image()
	immagine.save_png(CARTELLA + "/" + nome)
	print("  ", nome, "  ", immagine.get_width(), "x", immagine.get_height())
