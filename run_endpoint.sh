#!/usr/bin/env bash
set -euo pipefail

# Set up the routing needed for the simulation
/setup.sh

# Vegvisir injects these
ROLE="${ROLE:-server}"
QLOGDIR="${QLOGDIR:-}"
ORIGIN="${ORIGIN:-}"
ORIGIN_PORT="${ORIGIN_PORT:-443}"
REQUESTS="${REQUESTS:-/index.txt}"
DOWNLOAD_PATH_CLIENT="${DOWNLOAD_PATH_CLIENT:-}"
CC_ALGO="${CONGESTION:-westwood_owd}"

ORIGIN_DIR="/qw/server"
mkdir -p "$ORIGIN_DIR"
fallocate -l 100M "$ORIGIN_DIR/largefile"

OWD_DIR="${QLOGDIR:-$ORIGIN_DIR}"
mkdir -p "$OWD_DIR"
TS="$(date +"%Y%m%d-%H%M%S")"
OWD_FILE="${OWD_DIR%/}/${TS}.owd"

RAW_LOG="${OWD_DIR%/}/${TS}.raw.log"
NUM_RE='^[[:space:]]*[+-]?[0-9]+([[:space:]]+[+-]?[0-9]+)*[[:space:]]*$'

if [ "$ROLE" == "server" ]; then
  echo "Starting QUIC ${CC_ALGO} server..."
  echo "$@"
  echo "Writing owd logs to: ${OWD_FILE}"
  stdbuf -oL -eL hq --mode=server \
    --host 0.0.0.0 \
    -port="$ORIGIN_PORT" \
    --static_root="$ORIGIN_DIR" \
    -qlogger_path="$QLOGDIR" \
    -congestion="$CC_ALGO" \
    -pacing=true \
    -stream_flow_control=2147483647 \
	  --use_ack_receive_timestamps=true \
    2>&1 | awk '/^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+-?[0-9]+[[:space:]]+[0-9]+[[:space:]]*$/' >> "$OWD_FILE"

    #2>&1 | tee -a "$OWD_DIR/raw.out" 
    

elif [ "$ROLE" == "client" ]; then
  echo "Starting QUIC client..."
  echo "$@"
 	# Wait for the simulator to start up.
  /wait-for-it.sh sim:57832 -s -t 30
  hq --mode=client \
    --host "$ORIGIN" \
    --port "$ORIGIN_PORT" \
    --path "$REQUESTS" \
    --outdir /downloads \
    -congestion="$CC_ALGO" \
    -stream_flow_control=2147483647 \
  	-local_address=0.0.0.0:50000 \
    --use_ack_receive_timestamps=true
fi
