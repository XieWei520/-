# asr-api

## Repository Snapshot

- Local GitHub source: `C:\Users\COLORFUL\Desktop\WuKong\.codex_tmp\wildfirechat\asr-api`
- Branch: `main`
- Commit inspected: `8334d9b`
- Main GitHub contents:
  - `README.md` only.

## Responsibility

The GitHub `asr-api` repository is an index/placeholder for WildfireChat speech-to-text API service code.

The README states that the model files are large and cannot be uploaded to GitHub, and asks readers to view the Gitee repository:

```text
https://gitee.com/wfchat/asr-api
```

This means the GitHub organization repository itself does not contain the ASR API service implementation.

## Relationship to minutes-server

`minutes-server` uses an ASR WebSocket URL:

```text
asr.ws.url
```

and streams resampled conference audio to that endpoint. The actual ASR service is intended to be supplied by this `asr-api` project or a compatible ASR implementation.

Confirmed boundary:

- `minutes-server` is the meeting robot and ASR client.
- `asr-api` is the speech-to-text service side, but its source was not present in GitHub.

## Source Access Status

Attempted local clone target:

```text
C:\Users\COLORFUL\Desktop\WuKong\.codex_tmp\wildfirechat\asr-api-gitee
```

The Gitee clone attempt timed out after creating only an empty `.git` directory in this environment, and `git ls-remote https://gitee.com/wfchat/asr-api.git HEAD` also timed out.

Do not infer ASR implementation details from this GitHub placeholder. A future pass should retry Gitee access or obtain a source archive manually.

## Source-Confirmed Risks

- The public GitHub repository does not contain runnable ASR service code.
- Deployment analysis is incomplete until the Gitee source or a release package is available.
- `minutes-server` sends meeting audio/transcript data to the configured ASR service, so ASR deployment has privacy and data-retention implications even though this placeholder repo does not show the implementation.
