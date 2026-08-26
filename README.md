# PENTAWALL

Sparatutto in arena **a punti, non a morti**: il proiettile rimbalza senza perdere energia
**fino a cinque muri** — da lì il nome. Rifacimento moderno di *Nerf Arena Blast* (1999),
per iPhone e Android. Motore **Godot 4.7.2**, modalità **Compatibility**.

Progetto di casa, un autore solo. La documentazione (ricerca sull'originale, decisioni, piano)
sta nella cartella superiore e non è pubblicata qui.

## Stato

**Tappa 1 — il poligono di tiro.** C'è una stanza sola, e dentro c'è il cuore del gioco: un dardo
che rimbalza fino a cinque muri, la linea che mostra dove batterà il colpo, cinque bersagli — due
dei quali si prendono **solo** di sponda, perché stanno dietro un angolo — le due visuali e i
comandi per il pollice. Il punteggio parte da 25 e raddoppia a ogni muro: 25, 50, 100, 200, 400, 800.

Quello che il poligono deve dimostrare è una cosa sola: **che mirare un rimbalzo col pollice sia
divertente**. La risposta arriva dal telefono, non dal PC.

La scena della tappa 0 (`scenes/test_cube.tscn`) resta: serve a riprovare la catena di
compilazione quando cambia qualcosa che non c'entra col gioco.

## Come si gioca

| | Sul telefono | Sul PC |
|---|---|---|
| Muoversi | pollice sulla metà sinistra | W A S D |
| Mirare | pollice sulla metà destra | mouse |
| Sparare | tocco secco a destra, o **FUOCO** | clic sinistro |
| Saltare | **SALTA** | barra spaziatrice |
| Cambiare visuale | **VISUALE** | V |
| Cambiare il colore del dardo | **COLORE** | C |

Sul PC il mouse si aggancia al primo clic e si libera con Esc.

## Com'è fatto dentro

Il pezzo che regge tutto è `scripts/balistica.gd`: tira un raggio, lo specchia sulla normale a
ogni muro, si ferma al quinto. Quella funzione sola serve **quattro** cose — la linea che si vede
mentre si mira, il volo del dardo vero, e (dalla tappa 2) l'allarme al bot che sta per essere
colpito e la mira del bot. Il dardo si muove a mano a ogni fotogramma, con un raggio che copre
tutto lo spostamento: a 19 m/s un corpo fisico passerebbe attraverso i muri.

I numeri vengono dall'originale del 1999, convertiti: corsa 7,62 m/s, salto 1,06 m,
gravità 18,1 m/s², dardo a 19 m/s.

## Come si prova sul PC

```
Godot --path . -s tools/prova_balistica.gd      # 20 controlli sulla riflessione, senza schermo
Godot --path . -s tools/prova_poligono.gd       # il giro completo: sponda, colpo, punteggio
Godot --path . -s tools/scatti_poligono.gd      # una serie di scatti in scatti/ (non versionata)
Godot --path . -s tools/misura_prestazioni.gd   # quanti fotogrammi al secondo, senza sincronismo
```

Il collaudo della balistica gira anche a ogni `push`, prima della compilazione: se la riflessione
si rompe, l'app non viene nemmeno costruita.

## Come arriva sull'iPhone

iOS non si compila da Windows: è una restrizione di Apple. Ogni `push` su `main` fa partire
`.github/workflows/iphone.yml`, che compila su una macchina macOS di GitHub Actions e consegna
un **`.ipa` non firmato** fra gli *Artifacts* della lavorazione. La firma la mette **Sideloadly**
sul PC di casa con un Apple ID normale: nessun account da sviluppatore, nessuna spesa.
L'app installata così dura sette giorni e si rifirma con un clic.

## Le cartelle

| Cartella | Cosa c'è |
|---|---|
| `scenes/` | le scene |
| `scripts/` | il codice |
| `arenas/` | le arene, quando ci saranno |
| `assets/` | modelli, materiali, suoni |
| `tools/` | attrezzi di lavorazione, non fanno parte del gioco |
