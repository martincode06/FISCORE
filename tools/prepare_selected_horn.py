"""Prepare the user-selected Official NBA Horn SFX clip for offline playback.

The downloaded MP3 is kept in build/official-nba-horn-source.mp3.
Conversion uses the temporary imageio-ffmpeg package in build/audio-tools.
"""
import array
import math
from pathlib import Path
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'build/audio-tools'))
import imageio_ffmpeg

decoded = ROOT / 'build/nba-horn-decoded.wav'
subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), '-hide_banner', '-loglevel', 'error', '-y',
    '-i', str(ROOT / 'build/official-nba-horn-source.mp3'), '-ac', '1', '-ar', '44100',
    '-c:a', 'pcm_s16le', str(decoded)], check=True)
with wave.open(str(decoded), 'rb') as source:
    rate = source.getframerate()
    original = array.array('h', source.readframes(source.getnframes()))
if sys.byteorder != 'little':
    original.byteswap()

raw = ROOT / 'android/app/src/main/res/raw'
for filename, duration in [('chicharra_cancha.wav', 5.0), ('chicharra_posesion.wav', 0.6)]:
    samples = array.array('h', original[:round(rate * duration)])
    peak = max(abs(x) for x in samples)
    gain = min(1.25, 0.84 * 32767 / peak)
    for i, value in enumerate(samples):
        attack = min(1.0, i / (rate * 0.008))
        release = min(1.0, (len(samples) - 1 - i) / (rate * 0.04))
        envelope = (0.5 - 0.5 * math.cos(math.pi * attack)) * (0.5 - 0.5 * math.cos(math.pi * release))
        samples[i] = round(value * gain * envelope)
    assert samples[0] == samples[-1] == 0
    assert max(abs(x) for x in samples) < 32767
    if sys.byteorder != 'little':
        samples.byteswap()
    with wave.open(str(raw / filename), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(rate)
        output.writeframes(samples.tobytes())
    print(f'{filename}: {duration:.2f} s, mono PCM 16-bit / {rate} Hz')
