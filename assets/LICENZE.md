# Materiale di terzi dentro `assets/`

Tutto libero, verificato all'origine il 12/09/2026 e il 03/10/2026 (i suoni). Niente qui dentro viene dal gioco del 1999. Nessun file chiede il credito; gli autori sono nominati per correttezza.

| Cartella | Cosa | Autore | Licenza | Origine |
|---|---|---|---|---|
| `models/kenney/character-*.glb` | i corpi a blocchetti, con rig e animazioni | Kenney | CC0 1.0 | kenney.nl/assets/mini-characters |
| `models/kenney/blaster-*.glb`, `bullet-foam-tip.glb` | blaster giocattolo e dardo | Kenney | CC0 1.0 | kenney.nl/assets/blaster-kit |
| `materials/ambientcg/*` | superfici PBR a 1K (colore, normale, rugosità) | ambientCG | CC0 1.0 | ambientcg.com |
| `font/RussoOne-Regular.ttf` | carattere dei titoli e delle insegne | Jovanny Lemonad | SIL OFL 1.1 | fonts.google.com/specimen/Russo+One |
| `font/Exo2.ttf` | carattere dei testi (variabile in peso) | Natanael Gama | SIL OFL 1.1 | fonts.google.com/specimen/Exo+2 |
| `models/quaternius/base/*` | i due corpi umani base, con rig a 65 ossa, occhi e sopracciglia | Quaternius | CC0 1.0 | quaternius.itch.io/universal-base-characters |
| `models/quaternius/UAL1_Standard.glb` | la libreria di animazioni per lo stesso scheletro | Quaternius | CC0 1.0 | quaternius.itch.io/universal-animation-library |
| `models/quaternius/capelli/*` | le pettinature, ferme all'origine | Quaternius | CC0 1.0 | (stesso pacchetto dei corpi) |
| `models/quaternius/base/Maschera_Testa_*.png` | maschera della testa ricavata dalle UV dei corpi | nostre | — | generate il 12/09/2026 |
| `models/quaternius/pubblico/*.fbx` | il pubblico: persone sedute e che esultano, più quattro pettinature | Quaternius «Background Posed Humans» | CC0 1.0 | quaternius.com/packs/backgroundposedhumans.html |
| `materials/ambientcg/WoodFloor051/*` | il parquet dei pavimenti delle ali | ambientCG | CC0 1.0 | ambientcg.com/view?id=WoodFloor051 |
| `materials/pubblico.gdshader` | colori e tifo del pubblico | nostro | — | — |
| `ui/*.svg` | le icone dei pulsanti (fuoco, salto, uscita) | nostre | — | disegnate il 03/10/2026 |
| `models/quaternius/base/Maschera_Divisa_*.png` | scarpe, guanti e inserti della divisa, ricavati dalle ossa dei corpi | nostre | — | `tools/genera_maschere_divisa.py`, 03/10/2026 |
| `audio/sparo.ogg` | scatto di un blaster giocattolo vero + scoppio + tonfo, sommati | qubodup (OpenGameArt «Toy Double Barrel Shotgun Sounds»), «Pop Effect Sounds» (OpenGameArt), Kenney «Impact Sounds» | CC0 1.0 | opengameart.org/content/toy-double-barrel-shotgun-sounds · opengameart.org/content/pop-effect-sounds · kenney.nl/assets/impact-sounds |
| `audio/rimbalzo.ogg`, `incassato.ogg`, `passo_0…4.ogg` | «tock» di legno, tonfo sordo, passi su parquet | Kenney «Impact Sounds» | CC0 1.0 | kenney.nl/assets/impact-sounds |
| `audio/colpo.ogg` | pugno pieno + «ding» di vetro | Kenney «Impact Sounds» e «Interface Sounds» | CC0 1.0 | kenney.nl/assets/impact-sounds · kenney.nl/assets/interface-sounds |
| `audio/ricomparsa.ogg`, `salto.ogg`, `potenziamento.ogg`, `potenziamento_fine.ogg` | effetti digitali | Kenney «Digital Audio» | CC0 1.0 | kenney.nl/assets/digital-audio |
| `audio/atterraggio.ogg` | atterraggio da salto | MentalSanityOff, ripubblicato da qubodup (OpenGameArt «Jump Landing Sound») | CC0 1.0 | opengameart.org/content/jump-landing-sound |
| `audio/conto_*.ogg`, `via.ogg`, `voce_*.ogg` | la voce dell'annunciatore (in inglese) | Kenney «Voiceover Pack» | CC0 1.0 | kenney.nl/assets/voiceover-pack |
| `audio/tocco.ogg`, `podio.ogg` | interfaccia | Kenney «UI Audio» e «Interface Sounds» | CC0 1.0 | kenney.nl/assets/ui-audio · kenney.nl/assets/interface-sounds |
| `audio/vittoria.ogg`, `sconfitta.ogg` | jingle di fine partita | Kenney «Music Jingles» | CC0 1.0 | kenney.nl/assets/music-jingles |
| `audio/folla.ogg` | brusio di una folla grande, in loop | eguobyte (Freesound 360703, ripubblicato su Wikimedia Commons) | CC0 1.0 | commons.wikimedia.org/wiki/File:360703_eguobyte_large-crowd-medium-distance-stereo.wav |
| `audio/esultanza.ogg` | battimani e urla, i primi tre secondi e mezzo | PDSounds.org (Wikimedia Commons «Clapping hurray») | pubblico dominio | commons.wikimedia.org/wiki/File:Clapping_hurray.ogg |
| `audio/musica_*.ogg` | ingresso, partita, ultimo minuto: «Shooting Synth Hero» | (OpenGameArt «6 tracks — Shooting Synth Hero») | CC0 1.0 | opengameart.org/content/6-tracksshooting-synth-hero |
| `materials/tuta.gdshader` | la tuta da gara sopra il corpo base | nostro | — | — |
| `pwa/` | icone del gioco | nostre | — | — |
| `cielo/cielo_giorno.jpg` | il cielo dell'arena-giocattolo: dal cielo vero si prende dove stanno le nuvole, i colori sono ridipinti | Greg Zaal e Jarod Guest (Poly Haven, «Kloofendal 48d Partly Cloudy (Pure Sky)»), ridipinto da noi | CC0 1.0 | polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky · `tools/prepara_cielo.py`, 05/10/2026 |
| `giocattolo/tappeto.png`, `giocattolo/decalchi.png`, `giocattolo/decalco.gdshader` | i tappetini a incastro, le grafiche dei muri e lo shader che le incolla | nostri | — | `tools/prepara_tappeti.py`, `tools/prepara_decalchi.py` (col carattere Russo One), 05/10/2026 |

CC0 non chiede nemmeno il credito: Kenney e ambientCG restano nominati qui per correttezza.
L'OFL chiede che i caratteri restino sotto la stessa licenza se ridistribuiti da soli: dentro
un gioco si usano senza altri obblighi.
