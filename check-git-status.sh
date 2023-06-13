#!/usr/bin/env bash
set -Eeuo pipefail

status="$(git status --short)"
[ -z "$status" ]
