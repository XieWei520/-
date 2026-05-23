# wf-conference-record-player

## Repository Snapshot

- Local source: `C:\Users\COLORFUL\Desktop\WuKong\.codex_tmp\wildfirechat\wf-conference-record-player`
- Branch: `main`
- Commit inspected: `3eef847`
- Main parts:
  - Vue 2 demo player.
  - Node conversion script `cr2mp4.js`.
  - Perl ffmpeg matrix generator `creatematrix.pl`.
  - README/runbook notes for Janus conference recording post-processing.

## Responsibility

`wf-conference-record-player` is a tooling/demo repository for WildfireChat cloud conference recording output.

It converts Janus `.mjr` recording files into MP4 files and can compose participant videos into a grid-style final meeting video.

It is not the recording producer. Recording production is tied to `wf-janus`/Janus; this repo is for post-processing and simple playback.

## Requirements

README lists:

```text
Linux
janus-tools
perl
node
ffmpeg
```

On Ubuntu, README suggests:

```text
sudo apt install janus-tools
```

## Conversion Flow

`cr2mp4.js`:

- Lists video MJR files matching `videoroom*-video-1.mjr`.
- Lists audio MJR files matching `videoroom*-audio-0.mjr`.
- Uses `janus-pp-rec` to convert video MJR to MP4.
- Uses `janus-pp-rec` to convert audio MJR to Opus.
- Matches audio and video by filename prefix and nearby timestamp.
- Merges each participant audio/video pair with ffmpeg.
- Groups multiple segments by user id.
- Pads start times based on the earliest conference timestamp.
- Concatenates multiple segments for the same user.
- Chooses a matrix size based on participant count:
  - up to 4: 2x2
  - up to 9: 3x3
  - up to 16: 4x4
  - up to 25: 5x5
- Generates `merge.sh` through `creatematrix.pl`.
- Runs ffmpeg `xstack` to produce the final output MP4.

Output name is based on the first file prefix and ends in:

```text
.mp4
```

README usage:

```text
copy creatematrix.pl and cr2mp4.js into the conference recording directory
node cr2mp4.js
```

## Playback Demo

The Vue app is a very small demo:

- `src/App.vue` renders `Player`.
- `Player.vue` has hard-coded example `basePath` and sample recording file names.
- It renders `<video>` elements for MP4 files.

The playback demo is not a complete dynamic recording management UI.

## Important Filename Assumption

The conversion script expects Janus recording filenames shaped like:

```text
videoroom-<room>-user-<userId>-<timestamp>-video-1.mjr
videoroom-<room>-user-<userId>-<timestamp>-audio-0.mjr
```

It extracts:

- user id from filename segment 3.
- timestamp from filename segment 4.
- audio/video pairing from prefix segments 0 through 3.

Changing Janus recording naming will break the script.

## Source-Confirmed Risks

- Scripts interpolate filenames into shell commands without escaping. Use only trusted recording directories and trusted filenames.
- `cr2mp4.js` uses Linux shell commands such as `ls`, `rm`, `chmod`, and generated shell scripts; it is not portable to Windows.
- Matching audio/video by timestamp within `100 * 1000` units is heuristic and should be verified against actual Janus timestamp units and filenames.
- `Player.vue` contains hard-coded LAN base path and sample media filenames; it is demo-only.
- Only up to 25 participants are handled by the matrix-size selection logic even though `creatematrix.pl` can generate up to size 6.
