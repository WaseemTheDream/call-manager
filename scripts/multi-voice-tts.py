#!/usr/bin/env python3
"""
Multi-Voice TTS Generator
Generates audio with multiple voices/segments and stitches them together.

Usage:
    python3 multi-voice-tts.py segments.json output.mp3
    
segments.json format:
[
  {"voice": "bIHbv24MWmeRgasZH58o", "text": "This is Ren speaking."},
  {"voice": "JBFqnCBsd6RMkjVDRZzb", "text": "And this is George responding."}
]

Environment variables:
- ELEVENLABS_API_KEY (required)
- TTS_MODEL (default: eleven_turbo_v2_5)
- TTS_STABILITY (default: 0.5)
- TTS_SIMILARITY (default: 0.75)
- TTS_SPEED (default: 1.0)
- SILENCE_GAP (default: 0.8 seconds between voices)
"""

import json
import os
import sys
import subprocess
import time
import requests
import tempfile

def generate_segment(voice_id, text, segment_num):
    """Generate TTS for a single segment."""
    api_key = os.environ['ELEVENLABS_API_KEY']
    model = os.getenv('TTS_MODEL', 'eleven_turbo_v2_5')
    stability = float(os.getenv('TTS_STABILITY', '0.5'))
    similarity = float(os.getenv('TTS_SIMILARITY', '0.75'))
    speed = float(os.getenv('TTS_SPEED', '1.0'))
    
    print(f"Generating segment {segment_num}: {voice_id} - '{text[:50]}{'...' if len(text) > 50 else ''}'")
    
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
    headers = {
        "xi-api-key": api_key,
        "Content-Type": "application/json"
    }
    data = {
        "text": text,
        "model_id": model,
        "voice_settings": {
            "stability": stability,
            "similarity_boost": similarity,
            "speed": speed
        }
    }
    
    response = requests.post(url, headers=headers, json=data, stream=True)
    response.raise_for_status()
    
    segment_file = f"segment_{segment_num:03d}.mp3"
    with open(segment_file, 'wb') as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)
    
    return segment_file

def generate_silence(duration, filename):
    """Generate silence gap."""
    cmd = [
        'ffmpeg', '-y', '-f', 'lavfi', 
        '-i', f'anullsrc=r=44100:cl=mono', 
        '-t', str(duration), 
        '-q:a', '9', 
        '-acodec', 'libmp3lame', 
        filename
    ]
    subprocess.run(cmd, check=True, capture_output=True)
    return filename

def main():
    if len(sys.argv) != 3:
        print("Usage: python3 multi-voice-tts.py segments.json output.mp3")
        sys.exit(1)
        
    segments_file = sys.argv[1]
    output_file = sys.argv[2]
    
    # Check environment
    if not os.getenv('ELEVENLABS_API_KEY'):
        print("Error: ELEVENLABS_API_KEY environment variable required")
        sys.exit(1)
    
    # Load segments
    with open(segments_file, 'r') as f:
        segments = json.load(f)
    
    if not segments:
        print("Error: No segments found in input file")
        sys.exit(1)
    
    silence_gap = float(os.getenv('SILENCE_GAP', '0.8'))
    
    # Generate all segments
    files = []
    
    with tempfile.TemporaryDirectory() as tmpdir:
        os.chdir(tmpdir)
        
        for i, segment in enumerate(segments):
            voice_id = segment['voice']
            text = segment['text']
            
            # Generate the segment
            segment_file = generate_segment(voice_id, text, i + 1)
            files.append(segment_file)
            
            # Add silence gap (except after last segment)
            if i < len(segments) - 1:
                silence_file = f"silence_{i + 1:03d}.mp3"
                generate_silence(silence_gap, silence_file)
                files.append(silence_file)
            
            # Rate limiting
            time.sleep(0.3)
        
        # Create filelist for concat
        with open('filelist.txt', 'w') as f:
            for file in files:
                f.write(f"file '{file}'\n")
        
        # Concatenate all files
        print("Stitching segments together...")
        concat_cmd = [
            'ffmpeg', '-y', '-f', 'concat', '-safe', '0', 
            '-i', 'filelist.txt', '-c', 'copy', 
            'concatenated.mp3'
        ]
        subprocess.run(concat_cmd, check=True, capture_output=True)
        
        # Apply final audio processing
        print("Applying audio processing...")
        final_cmd = [
            'ffmpeg', '-y', '-i', 'concatenated.mp3',
            '-af', 'highpass=f=80,lowpass=f=12000,afftdn=nf=-25:nr=15:nt=w,loudnorm=I=-16:TP=-1.5:LRA=11',
            output_file
        ]
        subprocess.run(final_cmd, check=True, capture_output=True)
    
    print(f"✅ Multi-voice audio generated: {output_file}")
    print(f"📊 {len(segments)} segments, {len([s for s in segments if len(s['text']) > 0])} voices")

if __name__ == '__main__':
    main()