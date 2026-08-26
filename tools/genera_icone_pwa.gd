extends SceneTree

## Disegna le icone dell'app installata sulla schermata Home, partendo da `icon.svg`.
##
## **Perché non le fa Godot da solo.** In fase di esportazione Godot sa generarle,
## ma prende l'icona del progetto **già importata** — cioè 128 pixel di lato — e la
## ingrandisce fino a 512. Il risultato è un'icona morbida, e l'icona è la prima
## cosa che si vede del gioco. Qui invece l'SVG viene ridisegnato alla misura vera,
## una volta per misura.
##
## Si rilancia solo se cambia `icon.svg`: i tre file stanno nel repository.
##
## Uso:  godot --headless --path . -s tools/genera_icone_pwa.gd

const SORGENTE := "res://icon.svg"
const CARTELLA := "res://assets/pwa"

## Le tre misure che chiede il manifesto: 144 e 512 per Android e per il negozio,
## **180 è quella dell'iPhone** — ed è l'unica che conta per noi, oggi.
const MISURE := [144, 180, 512]

## Il lato del disegno originale, che è il numero da cui si calcola l'ingrandimento.
const LATO_SORGENTE := 128.0


func _initialize() -> void:
	var svg := FileAccess.get_file_as_string(SORGENTE)
	if svg.is_empty():
		push_error("Non trovo %s" % SORGENTE)
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARTELLA))

	for misura: int in MISURE:
		var immagine := Image.new()
		var esito := immagine.load_svg_from_string(svg, float(misura) / LATO_SORGENTE)
		if esito != OK:
			push_error("L'SVG non si disegna a %d pixel (errore %d)" % [misura, esito])
			quit(1)
			return
		var destinazione := "%s/icona_%d.png" % [CARTELLA, misura]
		esito = immagine.save_png(destinazione)
		if esito != OK:
			push_error("Non riesco a scrivere %s (errore %d)" % [destinazione, esito])
			quit(1)
			return
		print("  ok   %s  (%d x %d)" % [destinazione, immagine.get_width(), immagine.get_height()])

	quit()
