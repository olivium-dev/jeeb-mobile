#!/usr/bin/env bash
set -euo pipefail
helper_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 -B "$helper_dir/helpers.py" teardown "$@"
