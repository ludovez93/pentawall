"""Genera gli effetti sonori del gioco, sintetizzati: nessun file preso in giro.

Tappa 7, blocco B («il colpo che si sente»). Sei suoni corti, in `assets/audio/`,
WAV mono 16 bit a 44,1 kHz — il formato che Godot carica come `AudioStreamWAV` e che
la pagina web suona anche senza thread.

Il rimbalzo e' **uno solo**: il tono che sale a ogni muro lo fa il gioco con
`pitch_scale`, cosi' i cinque si contano a orecchio senza cinque file.

Uso:  python tools/genera_suoni.py
"""

import math
import wave
from pathlib import Path

import numpy as np

FREQUENZA = 44100
CARTELLA = Path(__file__).resolve().parent.parent / "assets" / "audio"

rng = np.random.default_rng(20260912)


def tempo(durata):
    return np.arange(int(FREQUENZA * durata)) / FREQUENZA


def decadimento(t, costante, attacco=0.0015):
    """Inviluppo: attacco brevissimo, poi coda esponenziale."""
    inv = np.exp(-t / costante)
    if attacco > 0:
        inv *= np.minimum(t / attacco, 1.0)
    return inv


def seno_scivolato(t, da, a, curva=3.0):
    """Sinusoide la cui frequenza scivola da `da` ad `a` con una curva esponenziale."""
    quota = 1.0 - np.exp(-t * curva / max(t[-1], 1e-6))
    quota /= quota[-1] if quota[-1] > 0 else 1.0
    freq = da + (a - da) * quota
    fase = 2.0 * np.pi * np.cumsum(freq) / FREQUENZA
    return np.sin(fase)


def rumore(n):
    return rng.standard_normal(n)


def passa_banda(segnale, basso, alto, morbidezza=0.35):
    """Filtro a banda nel dominio delle frequenze, con bordi dolci."""
    spettro = np.fft.rfft(segnale)
    f = np.fft.rfftfreq(len(segnale), 1.0 / FREQUENZA)
    maschera = np.ones_like(f)
    if basso > 0:
        maschera *= 1.0 / (1.0 + (basso / np.maximum(f, 1.0)) ** (2.0 / morbidezza))
    if alto > 0:
        maschera *= 1.0 / (1.0 + (f / alto) ** (2.0 / morbidezza))
    return np.fft.irfft(spettro * maschera, n=len(segnale))


def satura(segnale, quanto=1.6):
    return np.tanh(segnale * quanto) / math.tanh(quanto)


def normalizza(segnale, picco=0.9):
    massimo = np.max(np.abs(segnale))
    return segnale * (picco / massimo) if massimo > 0 else segnale


def sfuma_coda(segnale, millesimi=6):
    n = int(FREQUENZA * millesimi / 1000)
    if n > 0 and n < len(segnale):
        segnale[-n:] *= np.linspace(1.0, 0.0, n)
    return segnale


def salva(nome, segnale):
    CARTELLA.mkdir(parents=True, exist_ok=True)
    dati = np.clip(segnale, -1.0, 1.0)
    pcm = (dati * 32767.0).astype("<i2")
    with wave.open(str(CARTELLA / nome), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(FREQUENZA)
        f.writeframes(pcm.tobytes())
    print(f"  {nome:16s} {len(segnale) / FREQUENZA * 1000:5.0f} ms")


# ------------------------------------------------------------------- i suoni

def sparo():
    """Il blaster a molla: «pfft» d'aria, un corpo che scende, e un filo di molla."""
    t = tempo(0.26)
    aria = passa_banda(rumore(len(t)), 1800, 7000) * decadimento(t, 0.045, 0.001)
    corpo = seno_scivolato(t, 560, 150, 5.0) * decadimento(t, 0.05)
    molla = seno_scivolato(t, 900, 1500, 2.0) * decadimento(t, 0.018) * 0.35
    schiocco = passa_banda(rumore(len(t)), 3000, 9000) * decadimento(t, 0.004, 0.0005) * 1.4
    suono = 1.0 * aria + 0.85 * corpo + molla + schiocco
    return sfuma_coda(normalizza(satura(suono, 1.8), 0.92))


def rimbalzo():
    """Il «toc» di plastica sulla sponda: un tono netto con un lieve calo, un click
    d'impatto sopra. E' il suono che il gioco alza di tono a ogni muro."""
    t = tempo(0.2)
    tono = (np.sin(2 * np.pi * 440 * t * (1.0 - 0.03 * t / t[-1]))
            + 0.45 * np.sin(2 * np.pi * 880 * t)
            + 0.18 * np.sin(2 * np.pi * 1320 * t))
    tono *= decadimento(t, 0.055, 0.0008)
    click = passa_banda(rumore(len(t)), 2500, 8000) * decadimento(t, 0.003, 0.0004) * 1.1
    suono = tono + click
    return sfuma_coda(normalizza(satura(suono, 1.3), 0.85))


def colpo():
    """Il colpo a segno, pieno: un «thock» di corpo e un accordo breve e chiaro
    sopra, che dice «punti»."""
    t = tempo(0.42)
    thock = seno_scivolato(t, 210, 95, 6.0) * decadimento(t, 0.07, 0.001)
    battito = passa_banda(rumore(len(t)), 400, 2500) * decadimento(t, 0.012, 0.0005) * 0.9
    campana = np.zeros_like(t)
    for freq, peso, coda in ((880.0, 1.0, 0.16), (1320.0, 0.6, 0.12), (1760.0, 0.35, 0.09)):
        campana += peso * np.sin(2 * np.pi * freq * t) * decadimento(t, coda, 0.002)
    suono = 1.1 * thock + battito + 0.55 * campana
    return sfuma_coda(normalizza(satura(suono, 1.5), 0.92))


def incassato():
    """Il colpo incassato, sordo: un tonfo basso e un soffio ovattato, niente di
    brillante — e' il suono che non vuoi sentire."""
    t = tempo(0.34)
    tonfo = seno_scivolato(t, 130, 52, 5.0) * decadimento(t, 0.11, 0.001)
    soffio = passa_banda(rumore(len(t)), 80, 650) * decadimento(t, 0.06, 0.001) * 0.8
    urto = passa_banda(rumore(len(t)), 300, 1400) * decadimento(t, 0.008, 0.0005) * 0.7
    suono = 1.2 * tonfo + soffio + urto
    return sfuma_coda(normalizza(satura(suono, 2.4), 0.95))


def ricomparsa():
    """Si ricompare: un soffio che sale e un luccichio, breve e morbido."""
    t = tempo(0.5)
    soffio = passa_banda(rumore(len(t)), 300, 3500)
    soffio *= np.sin(np.pi * np.minimum(t / t[-1], 1.0)) ** 1.5
    gliss = seno_scivolato(t, 320, 960, 2.5) * decadimento(t, 0.22, 0.02) * 0.55
    luccichio = np.sin(2 * np.pi * 1920 * t) * decadimento(t, 0.09, 0.15) * 0.25
    suono = 0.9 * soffio + gliss + luccichio
    return sfuma_coda(normalizza(suono, 0.8), 20)


def passo():
    """Un passo sul pavimento della palestra: corto, di gomma, niente tacco."""
    t = tempo(0.13)
    suola = passa_banda(rumore(len(t)), 140, 900) * decadimento(t, 0.03, 0.001)
    tocco = passa_banda(rumore(len(t)), 900, 2600) * decadimento(t, 0.006, 0.0005) * 0.5
    suono = suola + tocco
    return sfuma_coda(normalizza(satura(suono, 1.4), 0.7))


if __name__ == "__main__":
    print("genero in", CARTELLA)
    salva("sparo.wav", sparo())
    salva("rimbalzo.wav", rimbalzo())
    salva("colpo.wav", colpo())
    salva("incassato.wav", incassato())
    salva("ricomparsa.wav", ricomparsa())
    salva("passo.wav", passo())
    print("fatto.")
