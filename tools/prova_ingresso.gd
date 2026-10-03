extends SceneTree

## Collaudo della schermata d'ingresso (tappa 7, blocco C).
##
## È **la scena principale**: se si rompe, il gioco non si apre e non lo dice
## nessuno finché non si tocca il link dal telefono. I controlli sono pochi e
## grossi: che si apra, che ci sia GIOCA, che il gesto nascosto apra il banco di
## prova, che sul palco ci sia il personaggio e che suoni la musica.
##
## Uso:  godot --headless --path . -s tools/prova_ingresso.gd

var _errori := 0
var _prove := 0


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	_conta("la scena principale del progetto è l'ingresso",
			String(ProjectSettings.get_setting("application/run/main_scene"))
			== "res://scenes/ingresso.tscn",
			String(ProjectSettings.get_setting("application/run/main_scene")))

	var ingresso: Node = load("res://scenes/ingresso.tscn").instantiate()
	root.add_child(ingresso)
	await process_frame
	await process_frame

	var tasti := _pulsanti(ingresso)
	_conta("c'è un pulsante GIOCA", tasti.has("GIOCA"), str(tasti.keys()))
	_conta("e il gioco non parte in partita finché non lo si tocca",
			not Arena.modo_partita)

	# **Il gesto nascosto**: cinque tocchi sulla riga della versione. Prima non si
	# vede niente — i banchi di prova servono a noi, non a chi gioca.
	_conta("il banco di prova è chiuso", not bool(ingresso.call("banco_aperto")))
	for i in Ingresso.TOCCHI_PER_APRIRE - 1:
		ingresso.call("_tocco")
	_conta("quattro tocchi non bastano", not bool(ingresso.call("banco_aperto")))
	ingresso.call("_tocco")
	_conta("al quinto si apre", bool(ingresso.call("banco_aperto")))
	await process_frame
	tasti = _pulsanti(ingresso)
	for dove in ["ARENA LIBERA", "POLIGONO", "ANGOLO"]:
		_conta("e porta a «%s»" % dove, tasti.has(dove))

	# Il personaggio sul palco (tappa 8, blocco I): il tuo corpo vero, col blaster.
	var corpo: Variant = ingresso.call("personaggio")
	_conta("sul palco c'è il tuo personaggio", corpo is Corpo and (corpo as Corpo).chi == "TU")
	_conta("e c'è la musica d'ingresso", Suoni.brano() == "musica_ingresso", Suoni.brano())
	_conta("il dardo parte a 24 m/s", is_equal_approx(Proiettile.velocita, Proiettile.VELOCITA_VELOCE),
			"%.0f m/s" % Proiettile.velocita)

	print("\nINGRESSO: %d prove, %s" %
			[_prove, "tutte passate." if _errori == 0 else "%d ERRORI." % _errori])
	quit(1 if _errori > 0 else 0)


## I pulsanti della scena, per testo: è così che si chiamano da fuori senza
## dipendere da come sono impilati dentro.
func _pulsanti(nodo: Node) -> Dictionary:
	var trovati := {}
	for figlio in nodo.get_children():
		if figlio is Button:
			trovati[(figlio as Button).text] = figlio
		if figlio.get_child_count() > 0:
			trovati.merge(_pulsanti(figlio))
	return trovati


func _conta(cosa: String, esito: bool, dettaglio := "") -> void:
	_prove += 1
	if esito:
		print("  ok   ", cosa)
	else:
		_errori += 1
		print("  NO   ", cosa, ("   (%s)" % dettaglio) if dettaglio != "" else "")
