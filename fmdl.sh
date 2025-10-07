#!/bin/bash
set -o pipefail

argparse=1

color="auto"
ffmpeg_args="-c copy"

PREFIX="[fmdl] "

println() {
  echo -e "${PREFIX}${2}${1}${RESET}"
}
print() {
  echo -en "${PREFIX}${2}${1}${RESET}"
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  help="true"
  shift
  argparse=0
fi

while [[ $# -gt $argparse ]]; do
  case "$1" in

    -o|--output)
      out_file="$2"
      shift 2
      ;;

    -u|--unrestricted-format)
      unrestricted_format="true"
      shift
      ;;

    -a|--ffmpeg-args)
      ffmpeg_args="$2"
      unrestricted_format="true"
      shift 2
      ;;

    -c|--color)
      color="$2"
      shift 2
      ;;

    -n|--no-prefix)
      no_prefix="true"
      shift
      ;;

    *)
      unknown_option="$1"
      shift
      ;;

  esac
done

# make sure url is the last argument
url="$1"
shift

while true; do
  case "$color" in
    auto)
      case "$TERM" in
        xterm-color|*-256color) color="always";;
      esac
      ;;

    always)
      ERROR="\e[1;31m"
      INFO="\e[1;36m"
      BOLD="\e[1;37m"
      RESET="\e[0m"
      PREFIX="${RESET}[\e[1;35mfmdl${RESET}] "
      ytdl_color="--color always"
      break
      ;;

    never)
      ytdl_color="--color never"
      break
      ;;

    *)
      println 'Error: --color must be "auto", "always", or "never"' $ERROR
      exit -1
      ;;

  esac
done

if [[ -n $no_prefix && $color == "always" ]]; then
  PREFIX="$RESET"
elif [[ -n $no_prefix && $color == "never" ]]; then
  PREFIX=""
fi

if [[ -n $help ]]; then
  print   "Usage: " $BOLD
  echo -e "${INFO}${0##*/} [OPTIONS] URL"
  println
  println "Options:" $BOLD
  println '  -o, --output <file>          Filename to output. Must end with .mp4' $INFO
  println '                               or .mkv (use -u to bypass this' $INFO
  println '                               requirement). Default is "[title].mp4"' $INFO
  println '  -u, --unrestricted-format    Disable .mp4/.mkv requirement for output' $INFO
  println '  -a, --ffmpeg-args            Arguments passed to ffmpeg when combining' $INFO
  println '                               video and audio. Default is "-c copy".' $INFO
  println '                               Also sets "-u"' $INFO
  println '  -c, --color                  Whether to color output. Can be "auto",' $INFO
  println '                               "always", or "never". Default is "auto"' $INFO
  println '  -n, --no-prefix              Disables log prefix' $INFO
  println '  -h, --help                   Show this help message' $INFO

  exit 0
fi

if [[ -n "$unknown_option" ]]; then
  println "Unknown option: \"$unknown_option\"" $ERROR
  exit -1
fi

if [[ "$url" != "https://www.flomarching.com/"* ]]; then
  println "Error: This is not a FloMarching URL!" $ERROR
  exit -1

elif [[ -n "$out_file" && -z $unrestricted_format ]]; then
  if [[ "$out_file" != *".mp4" && "$out_file" != *".mkv" ]]; then
    println "Error: Output file must end with .mp4 or .mkv" $ERROR
    exit -1
  fi
fi

if ! hash yt-dlp 2>/dev/null; then
  println "Error: yt-dlp is not installed! Download it from here:" $ERROR
  println "https://github.com/yt-dlp/yt-dlp" $BOLD
  exit -1

elif ! hash ffmpeg 2>/dev/null; then
  println "Error: ffmpeg is not installed! Download it from here:" $ERROR
  println "https://ffmpeg.org/" $BOLD
  exit -1
fi

if [[ -z "$out_file" ]]; then
  println "Getting video title..." $INFO
  out_file="$(yt-dlp $ytdl_color -O filename -o '%(title)s' $url).mp4"
  ret=$?
  if [[ $ret != 0 ]]; then
    println "yt-dlp: error while getting video title!" $ERROR
    exit $ret
  fi
fi

if [[ -e "$out_file" ]]; then
  print "Overwrite \"$out_file\"? (y/N): " $BOLD
  read confirm
  if [[ "$confirm" == [yY] ]]; then
    rm -f "$out_file"
  else
    println "Exiting" $INFO
    exit -1
  fi
fi

println "Getting urls..." $INFO
video_download_url=$(yt-dlp $ytdl_color -gf bv "$url")
ret=$?
if [[ $ret != 0 ]]; then
  println "yt-dlp: error while getting video URL!" $ERROR
  exit $ret
fi

if [[ "$video_download_url" != *"chunklist_vo"* ]]; then
  println "This video is not compatible with this script!" $ERROR
  print "Try with yt-dlp? (y/N): " $BOLD
  unset confirm

  read confirm
  if [[ "$confirm" == [yY] ]]; then
    yt-dlp $ytdl_color -o "$out_file" "$url"
    ret=$?
    if [[ $ret != 0 ]]; then
      println "yt-dlp: error while downloading video!" $ERROR
      exit $ret
    fi
  else
    println "Exiting" $INFO
    exit -1
  fi
fi

println "Downloading video in background..." $INFO
tmp_log=$(mktemp)
yt-dlp $ytdl_color -o fmdl.$$.video.mp4 "$video_download_url" &>"$tmp_log" &
ytdl_pid=$!

println "Downloading audio..." $INFO
audio_download_url=$(echo "$video_download_url" | sed "s/chunklist_vo_/chunklist_audio_/")
yt-dlp $ytdl_color -o fmdl.$$.audio.m4a "$audio_download_url"
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
ffmpeg -hide_banner -i fmdl.$$.video.mp4 -i fmdl.$$.audio.m4a $ffmpeg_args "$out_file"
ret=$?
if [[ $ret != 0 ]]; then
  println "ffmpeg: error while muxing!" $ERROR
  exit $ret
fi

println "Cleaning up..." $INFO
rm -f fmdl.$$.*
