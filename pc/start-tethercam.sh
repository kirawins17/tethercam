#!/usr/bin/env sh
# Start tethercam on Linux. The first run sets up its Python environment.
cd "$(dirname "$0")" || exit 1
if [ ! -x .venv/bin/python ]; then
  python3 -m venv .venv && .venv/bin/pip install -q -r requirements.txt
fi
exec .venv/bin/python tethercam.py "$@"
