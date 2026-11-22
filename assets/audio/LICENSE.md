# Audio licence

Every sound in this folder is synthesised from scratch by `tools/audio/gen_audio.py` (numpy sines,
filtered noise, a generated reverb impulse response). No samples, recordings, or third-party audio are used,
so there is nothing to attribute. The generated files are original to this project; Nathan owns them.

Regenerate: `python3 tools/audio/gen_audio.py` (needs numpy and ffmpeg with libvorbis). Output is deterministic.
