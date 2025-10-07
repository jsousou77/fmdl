#!/bin/bash

ERROR="\e[1;31m"
INFO="\e[1;36m"
BOLD="\e[1;37m"
RESET="\e[0m"

PREFIX="${RESET}[\e[1;35mfmdl${RESET}] "

println() {
  echo -e $3 "${PREFIX}${2}${1}${RESET}"
}

if ! hash yt-dlp 2>/dev/null; then
  println "Error: yt-dlp is not installed! Download it from here:" $ERROR
  println "https://github.com/yt-dlp/yt-dlp" $BOLD
  exit 1

elif ! hash ffmpeg 2>/dev/null; then
  println "Error: ffmpeg is not installed! Download it from here:" $ERROR
  println "https://ffmpeg.org/" $BOLD
  exit 1

elif [[ -z "$1" || -z "$2" || (($# > 2)) ]]; then
  println "Incorrect syntax!" $ERROR
  println "Usage: ${0##*/} <FloMarching video URL> <output file>" $BOLD
  exit 1

elif [[ "$1" != "https://www.flomarching.com/"* ]]; then
  println "Error: This is not a FloMarching URL!" $ERROR
  exit 1

elif [[ "$2" != *".mp4" && "$2" != *".mkv" ]]; then
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
ret=$?
if [[ $ret != 0 ]]; then
  println "yt-dlp: error while getting video URL!" $ERROR
  exit $ret
fi

if [[ "$video_download_url" != *"chunklist_vo"* ]]; then
  println "This video is not compatible with this script!" $ERROR
  println "Try with yt-dlp? (y/N): " $BOLD -n
  unset confirm

  read confirm
  if [[ "$confirm" == [yY] ]]; then
    yt-dlp -o "$2" "$1"
    ret=$?
    if [[ $ret != 0 ]]; then
      println "yt-dlp: error while downloading video!" $ERROR
      exit $ret
    fi
  else
    println "Exiting" $INFO
    exit 1
  fi
fi

println "Downloading video in background..." $INFO
tmp_log=$(mktemp)
yt-dlp --color always -o fmdl.$$.video.mp4 "$video_download_url" &>"$tmp_log" &
ytdl_pid=$!

println "Downloading audio..." $INFO
audio_download_url=$(echo "$video_download_url" | sed "s/chunklist_vo_/chunklist_audio_/")
yt-dlp -o fmdl.$$.audio.m4a "$audio_download_url"
ret=$?
if [[ $ret != 0 ]]; then
  println "yt-dlp: error while downloading audio!" $ERROR
  exit $ret
fi

println "Waiting for video download..." $INFO
tail -fn 999 "$tmp_log" &
tail_pid=$!
wait $ytdl_pid
ret=$?
if [[ $ret != 0 ]]; then
  println "yt-dlp: error while downloading video!" $ERROR
  exit $ret
fi

kill $tail_pid
rm "$tmp_log"

println "Combining video and audio..." $INFO
ffmpeg -hide_banner -i fmdl.$$.video.mp4 -i fmdl.$$.audio.m4a -c copy "$2"
ret=$?
if [[ $ret != 0 ]]; then
  println "ffmpeg: error while muxing!" $ERROR
  exit $ret
fi

println "Cleaning up..." $INFO
rm -f fmdl.$$.*
