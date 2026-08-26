# PENTAWALL

Sparatutto in arena **a punti, non a morti**: il proiettile rimbalza senza perdere energia
**fino a cinque muri** — da lì il nome. Rifacimento moderno di *Nerf Arena Blast* (1999),
per iPhone e Android. Motore **Godot 4.7.2**, modalità **Compatibility**.

Progetto di casa, un autore solo. La documentazione (ricerca sull'originale, decisioni, piano)
sta nella cartella superiore e non è pubblicata qui.

## Stato

**Tappa 0 — l'impianto.** Non c'è ancora gioco: c'è un cubo che gira, e serve a provare che la
catena di compilazione arriva fino al telefono. Sullo schermo si leggono fotogrammi al secondo,
scheda video e numero di tocchi; il cubo è emissivo sopra la soglia HDR per verificare che il
**bagliore** funzioni, perché è su quello che poggerà la leggibilità del proiettile.

## Come si prova sul PC

Aprire la cartella con Godot 4.7.2 e premere play. Per uno scatto senza aprire l'editor:

```
Godot --path . -s tools/scatto.gd -- res://scenes/test_cube.tscn scatto.png
```

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
