# fmdl
FloMarching downloader script. No account needed.

## Requirements
- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [ffmpeg](https://ffmpeg.org/)

## Usage
```
./fmdl.sh [OPTIONS] URL

Options:
-o, --output <file>          Filename to output. Must end with .mp4
                             or .mkv (use -u to bypass this
                             requirement). Default is "[title].mp4"
-u, --unrestricted-format    Disable .mp4/.mkv requirement for output
-a, --ffmpeg-args            Arguments passed to ffmpeg when combining
                             video and audio. Default is "-c copy".
                             Also sets "-u"
-c, --color                  Whether to color output. Can be "auto",
                             "always", or "never". Default is "auto"
-n, --no-prefix              Disables log prefix
-h, --help                   Show this help message
```

### Note:
This script only works with relatively recent FloMarching videos. Older videos can usually be downloaded directly with `yt-dlp`, and the script will prompt you to do that if it detects you tried to download an older video.
