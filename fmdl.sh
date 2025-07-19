#!/bin/bash -e

ERROR="\e[1;31m"
INFO="\e[1;36m"
BOLD="\e[1;37m"
RESET="\e[0m"

PREFIX="[\e[1;35mfmdl${RESET}] "

println () {
  echo -e $3 "${PREFIX}${2}${1}${RESET}"
}

if [[ -z $1 || -z $2 || (($# > 2)) ]]; then
  println "Incorrect syntax!" $ERROR
  println "Usage: ./fm-dl.sh <FloMarching video URL> <output file>" $BOLD
  exit 1

elif [[ $1 != "https://www.flomarching.com/"* ]]; then
  println "Error: This is not a FloMarching URL!" $ERROR
  exit 1

elif [[ $2 != *".mp4" && $2 != *".mkv" ]]; then
  println "Error: Output file must end with .mp4 or .mkv" $ERROR
  exit 1
fi

if [[ -e "$2" ]]; then
  println "Overwrite \"$2\"? (y/N): " $BOLD -n
  read confirm
  if [[ "$confirm" == [yY] ]]; then
    rm -f "$2"
  else
    println "Exiting" $INFO
    exit 1
  fi
fi

println "Getting urls..." $INFO
video_download_url=$(yt-dlp -gf bv "$1")
if [[ $video_download_url != *"chunklist_vo"* ]]; then
  println "This video is not compatible with this script!" $ERROR
  println "Try with yt-dlp? (y/N): " $BOLD -n
  unset confirm
  read confirm
  if [[ "$confirm" == [yY] ]]; then
    yt-dlp -o "$2" "$1"
  else
    println "Exiting" $INFO
    exit 1
  fi
fi

rand=$RANDOM

println "Downloading video in background..." $INFO
tmp_log=$(mktemp)
yt-dlp --color always -o fmdl.$rand.video.mp4 "$video_download_url" >"$tmp_log" 2>&1 &
ytdl_pid=$!

println "Downloading audio..." $INFO
audio_download_url=$(echo $video_download_url | sed "s/chunklist_vo_/chunklist_audio_/")
yt-dlp -o fmdl.$rand.audio.m4a "$audio_download_url"

println "Waiting for video download..." $INFO
tail -f "$tmp_log" &
tail_pid=$!
wait $ytdl_pid
kill $tail_pid
rm "$tmp_log"

println "Combining video and audio..." $INFO
ffmpeg -i fmdl.$rand.video.mp4 -i fmdl.$rand.audio.m4a -c copy "$2"

println "Cleaning up..." $INFO
rm -f fmdl.$rand.*
