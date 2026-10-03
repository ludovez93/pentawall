"""I suoni del gioco, dal materiale libero alla cartella `assets/audio/` (tappa 8, blocco F).

Fino al 03/10/2026 i suoni erano otto WAV sintetizzati da `tools/genera_suoni.py` e mai
ascoltati da nessuno. Qui si prendono registrazioni vere, tutte CC0 o pubblico dominio
(Kenney, OpenGameArt, Wikimedia Commons: l'origine di ognuna è in `assets/LICENZE.md`), e
si preparano tutte allo stesso modo:
- si toglie il silenzio in testa (un colpo che parte in ritardo sembra lento);
- si porta il picco a −1 dB, così i volumi li decide il gioco e non il file;
- gli effetti diventano mono (il gioco li mette nello spazio da sé), la musica resta stereo;
- tutto in Ogg Vorbis: la pagina web si scarica dal telefono, e un WAV pesa dieci volte tanto.

Lo sparo è l'unico suono **composto**: lo scatto di un blaster giocattolo vero, più uno
scoppio di bolla e un tonfo morbido — da solo lo scatto è rumore, insieme è un «pop».

Il materiale di partenza sta fuori dal repository, in `../materiale-audio/` (scaricato il
03/10/2026, con il suo `INDICE.md`). Uso:  python tools/prepara_suoni.py
"""
import os
import re
import subprocess

import imageio_ffmpeg

FF = imageio_ffmpeg.get_ffmpeg_exe()
QUI = os.path.dirname(os.path.abspath(__file__))
SORGENTE = os.path.normpath(os.path.join(QUI, "..", "..", "materiale-audio"))
DESTINAZIONE = os.path.normpath(os.path.join(QUI, "..", "assets", "audio"))

K = "kenney/"
SYNTH = "musica/shooting-synth-hero/ogg_Shooting Synth Hero/"

# nome nel gioco -> (file sorgente, opzioni)
EFFETTI = {
    "rimbalzo": K + "impact-sounds/Audio/impactWood_light_003.ogg",
    "incassato": K + "impact-sounds/Audio/impactSoft_heavy_001.ogg",
    "ricomparsa": K + "digital-audio/Audio/phaseJump3.ogg",
    "salto": K + "digital-audio/Audio/phaserUp6.ogg",
    "atterraggio": "effetti-extra/jump-landing/jumpland.wav",
    "conto_3": K + "voiceover-pack/Male/3.ogg",
    "conto_2": K + "voiceover-pack/Male/2.ogg",
    "conto_1": K + "voiceover-pack/Male/1.ogg",
    "via": K + "voiceover-pack/Male/go.ogg",
    "voce_ultimo_minuto": K + "voiceover-pack/Male/hurry_up.ogg",
    "voce_tempo_scaduto": K + "voiceover-pack/Male/time_over.ogg",
    "voce_vinto": K + "voiceover-pack/Male/you_win.ogg",
    "voce_perso": K + "voiceover-pack/Male/you_lose.ogg",
    "voce_potenziamento": K + "voiceover-pack/Male/power_up.ogg",
    "potenziamento": K + "digital-audio/Audio/powerUp9.ogg",
    "potenziamento_fine": K + "digital-audio/Audio/highDown.ogg",
    "tocco": K + "ui-audio/Audio/click1.ogg",
    "podio": K + "interface-sounds/Audio/confirmation_002.ogg",
    "vittoria": K + "music-jingles/Audio/Steel jingles/jingles_STEEL02.ogg",
    "sconfitta": K + "music-jingles/Audio/Steel jingles/jingles_STEEL01.ogg",
}
for i in range(5):
    EFFETTI["passo_%d" % i] = K + "impact-sounds/Audio/footstep_wood_%03d.ogg" % i

# La folla: il brusio in loop, e l'esultanza tagliata ai primi tre secondi e mezzo.
FOLLA = {
    "folla": ("folla/commons/360703_eguobyte_large-crowd-medium-distance-stereo.wav", None),
    "esultanza": ("folla/commons/Clapping_hurray.ogg", 3.6),
}

MUSICA = {
    "musica_ingresso": SYNTH + "Title_Hero is awakening.ogg",
    "musica_partita": SYNTH + "Stage_Hero is marching.ogg",
    "musica_finale": SYNTH + "Boss_Hero is fighting.ogg",
}


def picco(percorso, filtro=None):
    """Il picco del file in dB (dopo il filtro, se c'è)."""
    comando = [FF, "-hide_banner", "-i", percorso]
    catena = (filtro + "," if filtro else "") + "volumedetect"
    comando += ["-af", catena, "-f", "null", "-"]
    uscita = subprocess.run(comando, capture_output=True, text=True).stderr
    trovato = re.search(r"max_volume:\s*(-?[\d.]+) dB", uscita)
    return float(trovato.group(1)) if trovato else 0.0


def scrivi(entrate, catena, uscita, mono, qualita):
    comando = [FF, "-hide_banner", "-v", "error", "-y"]
    for e in entrate:
        comando += ["-i", e]
    comando += ["-filter_complex", catena, "-map", "[fine]"]
    if mono:
        comando += ["-ac", "1"]
    comando += ["-ar", "44100", "-c:a", "libvorbis", "-q:a", str(qualita), uscita]
    subprocess.run(comando, check=True)


def effetto(nome, sorgente, taglio=None, mono=True, qualita=4):
    entrata = os.path.join(SORGENTE, sorgente)
    pulizia = "silenceremove=start_periods=1:start_threshold=-48dB"
    if taglio:
        pulizia += ",atrim=0:%.2f,afade=t=out:st=%.2f:d=0.6" % (taglio, max(taglio - 0.6, 0.0))
    alza = -1.0 - picco(entrata, pulizia)
    uscita = os.path.join(DESTINAZIONE, nome + ".ogg")
    scrivi([entrata], "[0]%s,volume=%.2fdB[fine]" % (pulizia, alza), uscita, mono, qualita)
    return uscita


def sparo():
    """Scatto vero + scoppio + tonfo, sommati e riportati a −1 dB."""
    pezzi = [
        ("effetti-extra/toy-foam-shotgun/toy-double-barrel-shotgun-left-trigger.wav", 0.0, 0),
        ("effetti-extra/pop-effect-sounds/p_2.ogg", -4.0, 0),
        (K + "impact-sounds/Audio/impactSoft_medium_000.ogg", -7.0, 8),
    ]
    entrate = [os.path.join(SORGENTE, p[0]) for p in pezzi]
    rami = []
    for i, (_, livello, ritardo) in enumerate(pezzi):
        # Ognuno a −1 dB prima della somma, poi al suo livello: così il conto non dipende
        # da quanto forte era stato registrato il file.
        alza = -1.0 - picco(entrate[i], "silenceremove=start_periods=1:start_threshold=-48dB") + livello
        rami.append("[%d]silenceremove=start_periods=1:start_threshold=-48dB,adelay=%d|%d,"
                    "volume=%.2fdB,aformat=channel_layouts=mono[s%d]" % (i, ritardo, ritardo, alza, i))
    somma = ";".join(rami) + ";" + "".join("[s%d]" % i for i in range(len(pezzi))) + \
        "amix=inputs=%d:normalize=0[mix]" % len(pezzi)
    provvisorio = os.path.join(DESTINAZIONE, "_sparo_provvisorio.ogg")
    scrivi(entrate, somma + ";[mix]anull[fine]", provvisorio, True, 5)
    alza = -1.0 - picco(provvisorio)
    uscita = os.path.join(DESTINAZIONE, "sparo.ogg")
    scrivi([provvisorio], "[0]volume=%.2fdB[fine]" % alza, uscita, True, 4)
    os.remove(provvisorio)
    return uscita


def colpo():
    """Il colpo a segno: l'impatto pieno e, un attimo dopo, il «ding» dei punti."""
    pezzi = [
        (K + "impact-sounds/Audio/impactPunch_medium_000.ogg", 0.0, 0),
        (K + "interface-sounds/Audio/glass_001.ogg", -5.0, 25),
    ]
    entrate = [os.path.join(SORGENTE, p[0]) for p in pezzi]
    rami = []
    for i, (_, livello, ritardo) in enumerate(pezzi):
        alza = -1.0 - picco(entrate[i]) + livello
        rami.append("[%d]adelay=%d|%d,volume=%.2fdB,aformat=channel_layouts=mono[s%d]"
                    % (i, ritardo, ritardo, alza, i))
    somma = ";".join(rami) + ";[s0][s1]amix=inputs=2:normalize=0[mix]"
    provvisorio = os.path.join(DESTINAZIONE, "_colpo_provvisorio.ogg")
    scrivi(entrate, somma + ";[mix]anull[fine]", provvisorio, True, 5)
    alza = -1.0 - picco(provvisorio)
    uscita = os.path.join(DESTINAZIONE, "colpo.ogg")
    scrivi([provvisorio], "[0]volume=%.2fdB[fine]" % alza, uscita, True, 4)
    os.remove(provvisorio)
    return uscita


def durata(percorso):
    uscita = subprocess.run([FF, "-hide_banner", "-i", percorso], capture_output=True, text=True).stderr
    trovato = re.search(r"Duration: (\d+):(\d+):([\d.]+)", uscita)
    if not trovato:
        return 0.0
    h, m, s = trovato.groups()
    return int(h) * 3600 + int(m) * 60 + float(s)


if __name__ == "__main__":
    os.makedirs(DESTINAZIONE, exist_ok=True)
    fatti = [sparo(), colpo()]
    for nome, sorgente in EFFETTI.items():
        fatti.append(effetto(nome, sorgente))
    for nome, (sorgente, taglio) in FOLLA.items():
        fatti.append(effetto(nome, sorgente, taglio=taglio, mono=(nome != "folla"), qualita=3))
    for nome, sorgente in MUSICA.items():
        fatti.append(effetto(nome, sorgente, mono=False, qualita=2))
    totale = 0
    for f in fatti:
        peso = os.path.getsize(f)
        totale += peso
        print("%-28s %6.2f s  %7.1f KB  picco %.1f dB" % (os.path.basename(f), durata(f),
                                                         peso / 1024, picco(f)))
    print("in tutto %.1f MB" % (totale / 1024 / 1024))
