# PENTAWALL

Sparatutto in arena **a punti, non a morti**: il proiettile rimbalza senza perdere energia
**fino a cinque muri** — da lì il nome. Rifacimento moderno di *Nerf Arena Blast* (1999),
per iPhone e Android. Motore **Godot 4.7.2**, modalità **Compatibility**.

Progetto di casa, un autore solo. La documentazione (ricerca sull'originale, decisioni, piano)
sta nella cartella superiore e non è pubblicata qui.

## Stato

**Tappa 8 — da prototipo a gioco.** Si apre sul tuo personaggio in piedi su una pedana al neon, con
la musica; da **GIOCA** si entra in una **partita a sei da tre minuti** nell'arena intera: fischio
d'inizio con l'annunciatore (3 · 2 · 1 · GO), classifica viva, palle colorate, ultimo minuto con la
musica che cambia, e alla fine il **podio con RIGIOCA**.

I sei concorrenti hanno **corpi veri**: divisa con inserti, guanti e scarpe, capelli, il blaster in
mano, e animazioni vere — corrono avanti, di lato e all'indietro con il busto sulla mira, saltano,
sparano e accusano i colpi. L'arena ha superfici vere (parquet, moquette, intonaco, mattoni,
lamiera), spigoli smussati e piloni tondi, insegne al neon, le linee del campo nel catino, il
tabellone sospeso, e **il pubblico sulle tribune**. Suoni registrati e musica, tutti liberi
(`assets/LICENZE.md`).

Gli avversari **cercano, non sanno**: ti attaccano quando ti vedono, vanno dove ti hanno visto
l'ultima volta o dove ti hanno sentito sparare, se non hanno notizie girano per l'arena — e se
passano vicino a una palla colorata la vanno a prendere.

I banchi di prova — poligono, angolo, arena senza partita — sono ancora tutti lì, dietro **cinque
tocchi sulla riga della versione** in basso a destra nella schermata d'ingresso.

### I banchi di prova

C'è una stanza sola, con due mestieri.

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

**Dall'iPhone conviene metterlo sulla schermata Home**: menù di condivisione di Safari, *Aggiungi
alla schermata Home*. Da lì si apre **a schermo intero**, senza le barre di Safari sopra e sotto —
che su un gioco sono arena rubata — e con la sua icona.

**E resta sempre aggiornato.** Dentro c'è un operaio di servizio (`tools/pwa_service_worker.js`)
che a ogni avvio chiede al server «è cambiato?» invece di fidarsi della copia che ha in tasca:
quello che genera Godot fa il contrario, e una pubblicazione nuova arriverebbe solo al secondo
avvio — cioè si finirebbe a discutere di difetti già chiusi. Se non è cambiato niente non si
scarica niente, quindi l'avvio resta svelto anche con i 38 MB di `index.wasm`; e senza campo il
gioco parte lo stesso, con l'ultima versione scaricata.

Quale versione stai guardando lo dice <https://ludovez93.github.io/pentawall/versione.txt>: la
firma della pubblicazione e l'ora.

## Come si gioca

| | Sul telefono | Sul PC |
|---|---|---|
| Muoversi | pollice sulla metà sinistra | W A S D |
| Mirare | pollice sulla metà destra | mouse |
| Sparare | tocco secco a destra, o il pulsante rosso col dardo | clic sinistro |
| Saltare | il pulsante blu con le due frecce | barra spaziatrice |
| Cambiare visuale | **VISUALE** | V |
| Cambiare il colore del dardo | **COLORE** | C |
| Accendere o chiudere la sfida | **SFIDA** | B |
| Cambiare livello dell'avversario | **LIVELLO** | L |
| Dardo a 19 o a 24 m/s (si parte a 24) | **DARDO**, nei banchi di prova | R |
| Uscire dalla partita | il pulsante con la porta, in alto a sinistra | — |

In partita i pulsanti di prova non ci sono: restano il mirino, la leva, fuoco, salto e l'uscita.

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
Godot --path . -s tools/prova_ingresso.gd        # 26 controlli sulla schermata d'ingresso
Godot --path . -s tools/prova_arena.gd           # 117 controlli: pianta, cammino, partita, caccia
Godot --path . -s tools/prova_vivo.gd            # 67 controlli: corpi, forme, pavimenti, camera, suoni, palle colorate, resa
Godot --path . -s tools/prova_ritmo.gd           # una partita intera: si arriva nei primi tre?
Godot --path . -s tools/prova_poligono.gd        # il giro completo: sponda, colpo, punteggio
Godot --path . -s tools/prova_avversario.gd      # 18 controlli: anticipo, schivata, livelli, partita
Godot --path . -s tools/prova_comandi.gd         # 15 controlli: muovere e mirare con due pollici
Godot --path . -s tools/scatti_poligono.gd       # scatti del poligono, in scatti/ (non versionata)
Godot --path . -s tools/scatti_avversario.gd     # scatti della sfida
Godot --path . -s tools/misura_prestazioni.gd    # prestazioni; con `-- senza-sfida` per il paragone
Godot --path . --resolution 854x390 -s tools/scatti_corpi.gd   # i sei corpi in arena
Godot --path . --resolution 1280x560 -s tools/scatti_pose.gd   # le pose da vicino: corsa, lato, indietro
Godot --path . --resolution 854x390 -s tools/scatti_pavimento.gd  # il pavimento fotogramma per fotogramma
Godot --path . --resolution 854x390 -s tools/scatti_bordo.gd      # la camera addossata ai muri
Godot --path . --resolution 854x390 -s tools/prova_banco_scheda.gd  # il banco della scheda video, sul PC
node tools/banco_web.js 8765                     # lo stesso banco nel browser (`?scheda` sulla pagina)
PW_SPEDISCI=1 node tools/banco_web.js https://ludovez93.github.io/pentawall/index.html  # quello pubblicato, con le righe al Server 2
python tools/prepara_suoni.py                    # i suoni, dal materiale libero ad assets/audio
python tools/genera_maschere_divisa.py           # le maschere di scarpe, guanti e inserti
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
