import wave, struct, math, os

output_path = "Sounds/win_sound.wav"
os.makedirs(os.path.dirname(output_path), exist_ok=True)

sample_rate = 44100
duration = 3.5
num_samples = int(sample_rate * duration)

# Victory fanfare chord progression
# (start_sec, dur_sec, freq, volume, is_lead)
notes = [
    # 1. Opening crisp triumphant fanfare arpeggio
    (0.00, 0.28, 523.25, 0.45, True),   # C5
    (0.18, 0.28, 659.25, 0.50, True),   # E5
    (0.36, 0.32, 783.99, 0.55, True),   # G5
    (0.54, 0.50, 1046.50, 0.65, True),  # C6

    # 2. Main celebratory chord sustained under the animation
    (0.85, 2.60, 130.81, 0.40, False),  # C3 bass
    (0.85, 2.60, 261.63, 0.45, False),  # C4
    (0.85, 2.60, 392.00, 0.40, False),  # G4
    (0.85, 2.60, 523.25, 0.50, False),  # C5
    (0.85, 2.60, 659.25, 0.45, False),  # E5
    (0.85, 2.60, 783.99, 0.45, False),  # G5
    (0.85, 2.60, 1046.50, 0.55, True),  # C6
    (0.85, 2.60, 1318.51, 0.35, False), # E6
    (0.85, 2.60, 1567.98, 0.30, False), # G6

    # 3. Climax impact hit at 2.0s (when finish visual fully reveals & shakes!)
    (2.00, 1.45, 261.63, 0.45, False),  # C4 impact punch
    (2.00, 1.45, 523.25, 0.55, False),  # C5
    (2.00, 1.45, 659.25, 0.45, False),  # E5
    (2.00, 1.45, 783.99, 0.55, False),  # G5
    (2.00, 1.45, 1046.50, 0.65, True),  # C6
    (2.00, 1.45, 1567.98, 0.45, False), # G6
    (2.00, 1.45, 2093.00, 0.35, False), # C7 sparkling chime
]

samples_left = [0.0] * num_samples
samples_right = [0.0] * num_samples

for (start_t, dur_t, freq, vol, is_lead) in notes:
    start_idx = int(start_t * sample_rate)
    end_idx = min(num_samples, int((start_t + dur_t) * sample_rate))
    note_len = end_idx - start_idx
    decay_rate = 3.0 if dur_t < 0.6 else 1.25

    for i in range(note_len):
        idx = start_idx + i
        t = i / sample_rate
        # Envelope: punchy 0.015s attack, exponential smooth tail
        attack = min(1.0, t / 0.015)
        decay = math.exp(-t * decay_rate)
        env = attack * decay * vol

        # Subtle warm vibrato on long notes
        vib = 1.0 + (0.0035 * math.sin(2.0 * math.pi * 5.2 * t) if not is_lead else 0.001 * math.sin(2.0 * math.pi * 6.0 * t))
        phase = 2.0 * math.pi * (freq * vib) * t

        # Harmonic richness: sine fundamental + subtle 2nd, 3rd, 4th harmonics + warm triangle edge
        sig = math.sin(phase) \
            + 0.35 * math.sin(phase * 2.0) \
            + 0.18 * math.sin(phase * 3.0) \
            + 0.08 * math.sin(phase * 4.0)

        sig *= env

        # Stereo spread
        pan = 0.5 + 0.15 * math.sin(freq * 0.01)
        samples_left[idx] += sig * (1.0 - pan * 0.5)
        samples_right[idx] += sig * (pan * 0.5 + 0.5)

# Find max peak across both channels
max_peak = max(
    max(abs(s) for s in samples_left),
    max(abs(s) for s in samples_right),
    0.001
)
norm = 0.90 / max_peak

wav_file = wave.open(output_path, "wb")
wav_file.setnchannels(2)
wav_file.setsampwidth(2)
wav_file.setframerate(sample_rate)

data = bytearray()
for l, r in zip(samples_left, samples_right):
    il = max(-32768, min(32767, int(l * norm * 32767.0)))
    ir = max(-32768, min(32767, int(r * norm * 32767.0)))
    data.extend(struct.pack("<hh", il, ir))

wav_file.writeframes(data)
wav_file.close()
print("Created", output_path, "size:", len(data))
