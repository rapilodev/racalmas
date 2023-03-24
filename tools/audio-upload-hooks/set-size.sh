#!/bin/sh
echo "calcms_audio_recordings.size = $(du -b $1 | cut -f1)"
