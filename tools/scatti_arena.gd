extends SceneTree

## Attrezzo di lavorazione: apre l'arena intera e la fotografa da sei posti.
## Non fa parte del gioco.
##
## Su questo progetto i difetti visivi sono usciti dagli scatti e mai dal codice,
## e nessuno di quelli dava un errore (LEARNED.md 14 e 15). Qui in più c'è una
## domanda nuova, che in ventisei metri per ventidue non esisteva: **da dentro si
## capisce dove si è?**
##
## Uso:  godot --path . -s tools/scatti_arena.gd

const CARTELLA := "res://scatti"

var _arena: Node
var _giocatore: Giocatore


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	DirAccess.make_dir_recursive_absolute(CARTELLA)
	_arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(_arena)
	await _riposa(3)
	_giocatore = _arena.call("giocatore")
	# La grana dei muri si genera in un thread: senza qualche fotogramma di
	# pazienza il primo scatto la coglie a metà.
	await _riposa(40)

	# 1. Dal catino, guardando su verso il ballatoio: è il punto più basso
	#    dell'arena e deve dire subito che sopra c'è qualcuno.
	_metti(Vector3(0.0, -1.4, 8.0), 0.0, 6.0)
	await _riposa(24)
	await _scatta("90-dal-catino.png")

	# 2. Dal bordo del catino verso l'ala ocra: la quota che cambia e l'insegna.
	_metti(Vector3(0.0, 0.6, 14.0), 0.0, -3.0)
	await _riposa(20)
	await _scatta("91-il-catino-da-fuori.png")

	# 3. Dal ballatoio, la vista che comanda l'arena.
	_metti(Vector3(0.0, 7.6, 20.0), 0.0, -10.0)
	await _riposa(20)
	await _scatta("92-dal-ballatoio.png")

	# 4. Il corridoio dell'ala mattone: le due sponde affacciate a otto metri.
	#    Fable l'ha dichiarato il colpo migliore della mappa: va guardato.
	_metti(Vector3(29.0, 0.6, 11.0), 355.0, -1.0)
	await _riposa(20)
	await _scatta("93-corridoio-del-mattone.png")

	# 5. L'ala ocra dal suo ingresso: è il pezzo che viene dalla tappa 3 e deve
	#    essere ancora riconoscibile dentro l'arena grande.
	_metti(Vector3(9.0, 0.6, -20.0), 200.0, -4.0)
	await _riposa(20)
	await _scatta("94-ala-ocra.png")

	# 6. Dalla terrazza nord-est, in cima alla scala: la traversata più lunga
	#    dell'arena in una sola inquadratura.
	_metti(Vector3(27.0, 4.1, -27.0), 135.0, -8.0)
	await _riposa(20)
	await _scatta("95-dalla-terrazza.png")

	# 7. Il quadratino a scacchi che compare in alto a sinistra dello scatto 95:
	#    qui l'insegna TURBO è inquadrata da sola, dalla stessa distanza e dallo
	#    stesso scorcio. Un difetto che sta in un angolo dell'inquadratura non si
	#    insegue a occhio: si isola (LEARNED.md § 15).
	_metti(Vector3(27.0, 4.1, -27.0), 186.0, -2.0)
	await _riposa(20)
	await _scatta("96-insegna-di-scorcio.png")

	print("\nfatti.")
	quit()


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
