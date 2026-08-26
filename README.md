# PENTAWALL

Sparatutto in arena **a punti, non a morti**: il proiettile rimbalza senza perdere energia
**fino a cinque muri** — da lì il nome. Rifacimento moderno di *Nerf Arena Blast* (1999),
per iPhone e Android. Motore **Godot 4.7.2**, modalità **Compatibility**.

Progetto di casa, un autore solo. La documentazione (ricerca sull'originale, decisioni, piano)
sta nella cartella superiore e non è pubblicata qui.

## Stato

**Tappa 2 — lo sparring partner.** C'è una stanza sola, con due mestieri.

Da **poligono**: un dardo che rimbalza fino a cinque muri, la linea che mostra dove batterà il
colpo, cinque bersagli — due dei quali si prendono **solo** di sponda, perché stanno dietro un
angolo — le due visuali e i comandi per il pollice. Il punteggio parte da 25 e raddoppia a ogni
muro: 25, 50, 100, 200, 400, 800.

Da **sfida** (pulsante SFIDA): entra un avversario e i bersagli si fanno da parte. Lui anticipa,
schiva, e **schiva anche i rimbalzi** — legge le traiettorie con la stessa funzione che disegna a
te la linea di mira. Si vince a 500 punti: tu raddoppi a ogni muro, lui spara dritto e vale sempre
25. Giocando dritto siete pari, e si vince di sponda. Tre livelli, che cambiano solo reazione,
precisione e cadenza: **nessuno spegne mai una capacità**.

Quello che questa stanza deve dimostrare sono due cose: **che mirare un rimbalzo col pollice sia
divertente**, e **che perdere contro di lui sembri giusto**. La risposta arriva dal telefono, non
dal PC.

La scena della tappa 0 (`scenes/test_cube.tscn`) resta: serve a riprovare la catena di
compilazione quando cambia qualcosa che non c'entra col gioco.

## Si prova qui

### <https://ludovez93.github.io/pentawall/>

Si apre nel browser, anche da telefono, e si gioca col pollice: nessuna installazione, nessun cavo.
La pagina si rifà a ogni `push`. Per il giudizio sulle prestazioni vale l'app nativa, non questa.

## Come si gioca

| | Sul telefono | Sul PC |
|---|---|---|
| Muoversi | pollice sulla metà sinistra | W A S D |
| Mirare | pollice sulla metà destra | mouse |
| Sparare | tocco secco a destra, o **FUOCO** | clic sinistro |
| Saltare | **SALTA** | barra spaziatrice |
| Cambiare visuale | **VISUALE** | V |
| Cambiare il colore del dardo | **COLORE** | C |
| Accendere o chiudere la sfida | **SFIDA** | B |
| Cambiare livello dell'avversario | **LIVELLO** | L |

Sul PC il mouse si aggancia al primo clic e si libera con Esc.

## Com'è fatto dentro

Il pezzo che regge tutto è `scripts/balistica.gd`: tira un raggio, lo specchia sulla normale a
ogni muro, si ferma al quinto. Quella funzione sola serve **quattro** cose — la linea che si vede
mentre si mira, il volo del dardo vero, l'allarme all'avversario che sta per essere colpito e la
sua mira. Le ultime due sono la ragione per cui un avversario schiva un colpo di sponda che gli
arriva dietro l'angolo: non è un'intelligenza in più, è lo stesso conto letto dall'altra parte.

Il dardo si muove a mano a ogni fotogramma, con un raggio che copre tutto lo spostamento: a 19 m/s
un corpo fisico passerebbe attraverso i muri.

I numeri vengono dall'originale del 1999, convertiti: corsa 7,62 m/s, salto 1,06 m,
gravità 18,1 m/s², dardo a 19 m/s.

## Come si prova sul PC

```
Godot --path . -s tools/prova_balistica.gd       # 20 controlli sulla riflessione, senza schermo
Godot --path . -s tools/prova_poligono.gd        # il giro completo: sponda, colpo, punteggio
Godot --path . -s tools/prova_avversario.gd      # 18 controlli: anticipo, schivata, livelli, partita
Godot --path . -s tools/prova_comandi.gd         # 15 controlli: muovere e mirare con due pollici
Godot --path . -s tools/scatti_poligono.gd       # scatti del poligono, in scatti/ (non versionata)
Godot --path . -s tools/scatti_avversario.gd     # scatti della sfida
Godot --path . -s tools/misura_prestazioni.gd    # prestazioni; con `-- senza-sfida` per il paragone
```

Il collaudo della balistica gira anche a ogni `push`, prima della compilazione: se la riflessione
si rompe, l'app non viene nemmeno costruita. Quello dei comandi gira sulla lavorazione **Web**, che
è la pagina che si tocca col dito: se muovere e mirare insieme torna a far saltare la visuale, la
pagina non viene pubblicata.

## Come arriva sull'iPhone

iOS non si compila da Windows: è una restrizione di Apple. Ci pensa
`.github/workflows/iphone.yml`, che compila su una macchina macOS di GitHub Actions e consegna
un **`.ipa` non firmato** fra gli *Artifacts* della lavorazione.

**L'app si chiede, non esce da sola.** Finché si prova dal browser non ha senso costruire 27 MB a
ogni modifica: si lancia con un clic dalla pagina delle lavorazioni (voce **iPhone**, *Run
workflow*). Riparte da sola soltanto quando cambia la catena — `project.godot`,
`export_presets.cfg` o la lavorazione stessa — perché è lì che stanno le sue trappole, non nel
codice del gioco. La firma la mette **Sideloadly**
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
