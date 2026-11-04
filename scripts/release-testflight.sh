#!/bin/bash
# Starts a Drawspeak TestFlight release in its own session, with the built-in keys.
# Run through Apassy with items "drawspeak elevenlabs api key" (104) and
# "Drawspeak Anthropic API key" (105). Output: /tmp/ds-release-run.log.
set -euo pipefail
export DRAWSPEAK_ELEVENLABS_API_KEY="$APASSY_ITEM_104"
export DRAWSPEAK_ANTHROPIC_API_KEY="$APASSY_ITEM_105"
cd "$(dirname "$0")/.."
# Detach (double fork + setsid) so the release outlives the Apassy call.
/usr/bin/python3 -I -c '
import os, sys
if os.fork() > 0: sys.exit(0)
os.setsid()
if os.fork() > 0: sys.exit(0)
log = os.open("/tmp/ds-release-run.log", os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
os.dup2(log, 1); os.dup2(log, 2)
devnull = os.open("/dev/null", os.O_RDONLY); os.dup2(devnull, 0)
os.execv("/bin/bash", ["/bin/bash", "scripts/testflight.sh"])
'
sleep 2
pgrep -f "scripts/testflight.sh" | head -1
