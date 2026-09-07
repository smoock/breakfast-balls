"""Generate the original, loopable Magnolia Morning golf-broadcast cue."""
from pathlib import Path
import wave
import numpy as np

RATE = 22050
TEMPO = 72.0
BEAT = 60.0 / TEMPO
BARS = 8
DURATION = BARS * 4 * BEAT
COUNT = int(DURATION * RATE)
rng = np.random.default_rng(87021)
mix = np.zeros(COUNT, dtype=np.float64)


def hz(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def add_tone(start, duration, midi, volume, kind="piano"):
    begin = int(start * RATE)
    length = min(int(duration * RATE), COUNT - begin)
    if length <= 0:
        return
    t = np.arange(length) / RATE
    frequency = hz(midi)
    if kind == "piano":
        body = (np.sin(2*np.pi*frequency*t)
                + 0.30*np.sin(2*np.pi*frequency*2*t + 0.2)
                + 0.10*np.sin(2*np.pi*frequency*3*t + 0.4))
        env = (1.0 - np.exp(-t*40.0)) * np.exp(-t*2.15)
    elif kind == "bass":
        body = np.sin(2*np.pi*frequency*t) + 0.18*np.sin(2*np.pi*frequency*2*t)
        env = (1.0 - np.exp(-t*24.0)) * np.exp(-t*2.8)
    else:
        body = np.sin(2*np.pi*frequency*t) + 0.12*np.sin(2*np.pi*frequency*2*t)
        attack = np.minimum(1.0, t/0.8)
        release = np.minimum(1.0, (duration-t)/0.9)
        env = np.clip(attack*release, 0, 1)
    mix[begin:begin+length] += body * env * volume


# Dmaj7 – Gmaj7 – Bm7 – Aadd9, voiced gently and repeated with a new top line.
chords = [
    ([50, 54, 57, 61], 38), ([43, 47, 50, 54], 31),
    ([47, 50, 54, 57], 35), ([45, 49, 52, 59], 33),
    ([50, 54, 57, 61], 38), ([43, 47, 50, 54], 31),
    ([47, 50, 54, 57], 35), ([45, 49, 52, 59], 33),
]
melody = [
    [(0.5, 66), (1.5, 69), (2.75, 73)],
    [(0.25, 71), (1.75, 69), (3.0, 66)],
    [(0.5, 69), (1.5, 71), (2.5, 74)],
    [(0.25, 73), (2.0, 71), (3.25, 69)],
    [(0.5, 66), (1.25, 69), (2.0, 73), (3.25, 76)],
    [(0.25, 74), (1.5, 71), (2.75, 69)],
    [(0.5, 69), (1.75, 74), (3.0, 71)],
    [(0.25, 73), (1.5, 71), (2.75, 66)],
]

for bar, (notes, bass) in enumerate(chords):
    start = bar * 4 * BEAT
    for note in notes:
        add_tone(start, 4.1*BEAT, note, 0.032, "strings")
    add_tone(start, 1.5*BEAT, bass, 0.095, "bass")
    add_tone(start + 2*BEAT, 1.35*BEAT, bass + 7, 0.055, "bass")
    # Broken chord comping leaves breathing room for UI and shot sounds.
    for beat, chord_index in [(0, 0), (1, 2), (2, 1), (3, 3)]:
        add_tone(start + beat*BEAT, 1.3*BEAT, notes[chord_index], 0.085, "piano")
    for beat, note in melody[bar]:
        add_tone(start + beat*BEAT, 1.15*BEAT, note, 0.065, "piano")

# Quiet brushes: filtered noise swells on beats two and four.
for bar in range(BARS):
    for beat in (1, 3):
        begin = int((bar*4 + beat)*BEAT*RATE)
        length = int(0.23*RATE)
        noise = rng.normal(0, 1, length)
        smooth = np.convolve(noise, np.ones(11)/11, mode="same")
        env = np.sin(np.linspace(0, np.pi, length))**1.7
        mix[begin:begin+length] += smooth * env * 0.030

# Gentle room reflections and a transparent master fade at the loop seam.
for delay, gain in [(0.16, 0.12), (0.31, 0.07)]:
    offset = int(delay*RATE)
    mix[offset:] += mix[:-offset] * gain
fade = int(0.045*RATE)
mix[:fade] *= np.linspace(0, 1, fade)
mix[-fade:] *= np.linspace(1, 0, fade)
mix *= 0.82 / max(1e-6, np.max(np.abs(mix)))
pcm = np.int16(np.clip(mix, -1, 1) * 32767)

output = Path(__file__).resolve().parents[1] / "game/assets/audio/magnolia_morning.wav"
output.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(output), "wb") as wav:
    wav.setnchannels(1)
    wav.setsampwidth(2)
    wav.setframerate(RATE)
    wav.writeframes(pcm.tobytes())
print(f"Wrote {output} ({DURATION:.2f}s)")
