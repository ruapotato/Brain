# This script uses the powerful librosa library to analyze an audio file
# and generate a simple text file containing the timestamp of every beat.
#
# REQUIREMENTS:
#   pip install librosa
#
# USAGE:
#   python beat_up.py path/to/your/song.wav
#
# This will create a file named "song.beats" in the same directory.

import librosa
import sys
import os

def create_beat_map(audio_path):
    """
    Analyzes an audio file to find beat timestamps and saves them to a .beats file.
    """
    if not os.path.exists(audio_path):
        print(f"Error: File not found at {audio_path}")
        return

    print(f"Loading '{audio_path}'...")
    # Load the audio file. y is the audio time series, sr is the sample rate.
    y, sr = librosa.load(audio_path)

    print("Analyzing beats...")
    # Use librosa's beat tracking function. This is highly accurate.
    # It returns the tempo (in BPM) and an array of frame indices for each beat.
    tempo, beat_frames = librosa.beat.beat_track(y=y, sr=sr)
    
    # Convert the beat frames to timestamps in seconds.
    beat_times = librosa.frames_to_time(beat_frames, sr=sr)

    print(f"Detected Tempo: {tempo} BPM")
    print(f"Found {len(beat_times)} beats.")

    # Create the output file path.
    base_name = os.path.splitext(audio_path)[0]
    output_path = f"{base_name}.beats"

    print(f"Saving beat map to '{output_path}'...")
    # Write each timestamp to the .beats file, one per line.
    with open(output_path, 'w') as f:
        for t in beat_times:
            f.write(f"{t}\n")
    
    print("Done.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python beat_mapper.py path/to/your/song.wav")
    else:
        create_beat_map(sys.argv[1])
