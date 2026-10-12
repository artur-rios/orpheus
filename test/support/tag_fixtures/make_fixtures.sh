#!/usr/bin/env bash
# Regenerates the tagged audio fixtures the tag writer is tested against.
#
# Half a second of silence each (the WAV at 8 kHz, to keep it small), so the
# files are a few kilobytes, carrying the tags the preservation tests check
# survive a write: the fields an autofill writes, and the ones it must never
# lose — a comment, a custom field, and on the M4A an album artist the
# writer's model does not hold.
#
# Needs ffmpeg. The output is committed; run this only to change it.
set -euo pipefail
cd "$(dirname "$0")"

common=(-f lavfi -i anullsrc=r=44100:cl=mono -t 0.5 -y)
tags=(
  -metadata title="Airbag"
  -metadata artist="Radiohed"
  -metadata album="OK Computer"
  -metadata track="1/12"
  -metadata date="1997"
  -metadata genre="Rock"
  -metadata comment="kept"
)

ffmpeg -hide_banner -loglevel error "${common[@]}" -c:a libmp3lame -b:a 32k \
  -id3v2_version 4 "${tags[@]}" -metadata album_artist="Radiohead" \
  -metadata disc="1/1" -metadata CUSTOM="kept" tagged.mp3

ffmpeg -hide_banner -loglevel error "${common[@]}" -c:a aac -b:a 32k \
  "${tags[@]}" -metadata album_artist="Radiohead" -metadata disc="1/1" tagged.m4a

ffmpeg -hide_banner -loglevel error "${common[@]}" -c:a pcm_s16le -ar 8000 \
  "${tags[@]}" tagged.wav

ffmpeg -hide_banner -loglevel error "${common[@]}" -c:a libvorbis \
  "${tags[@]}" tagged.ogg
