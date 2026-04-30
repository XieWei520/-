# wemx.cc Domain Rollback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for inline execution in this session because subagents were not explicitly requested. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore `wemx.cc` as the active public endpoint while `infoequity.cn` is unavailable.

**Architecture:** The local Flutter code supplies default endpoint constants and test fixtures; update only domain-related literals. The production stack derives WuKongIM, TangSengDaoDao, TURN, and Nginx runtime behavior from `.env` plus render scripts; back up active config, update variables, regenerate rendered files, reload affected services, and smoke-test public endpoints.

**Tech Stack:** Flutter/Dart, PowerShell, SSH, Docker Compose, Nginx, WuKongIM, TangSengDaoDao, coturn.

---

## Files and Runtime Assets

- Modify local files containing active `infoequity.cn` endpoint defaults or tests.
- Remote modify: `/opt/wukongim-prod/src/deploy/production/.env`.
- Remote verify/edit if needed: `/opt/wukongim-prod/src/deploy/production/nginx/default.conf.template`.
- Remote regenerate: `rendered/wk.yaml`, `rendered/tsdd.yaml`, `rendered/turnserver.conf`.

## Task 1: Preflight

- [ ] Confirm `wemx.cc` resolves to `42.194.218.158` and `infoequity.cn` is currently unusable.
- [ ] Back up remote `.env`, `nginx/default.conf.template`, and rendered config files.
- [ ] Confirm `/etc/letsencrypt/live/wemx.cc/fullchain.pem` and `privkey.pem` exist.

## Task 2: Local Endpoint Replacement

- [ ] Replace active local `infoequity.cn` endpoint literals with `wemx.cc` equivalents.
- [ ] Leave unrelated modified files and non-active historical docs/logs untouched.
- [ ] Run targeted endpoint tests.

## Task 3: Remote Runtime Replacement

- [ ] Update remote `.env` domain variables to `wemx.cc`.
- [ ] Regenerate rendered configs with the existing production render script.
- [ ] Validate Docker Compose and Nginx config where available.
- [ ] Recreate/reload only affected services.

## Task 4: Verification

- [ ] Verify `https://wemx.cc/`.
- [ ] Verify `https://wemx.cc/v1/common/appconfig` or equivalent app config endpoint.
- [ ] Verify WSS route `wss://wemx.cc/ws` can complete an HTTP upgrade or at least reaches Nginx/WuKongIM.
- [ ] Verify TCP `wemx.cc:5100` is open.
- [ ] Report exact commands and results.
