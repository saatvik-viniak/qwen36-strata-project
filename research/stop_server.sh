#!/bin/bash
# stop_server.sh — kill the server + engine, then WAIT until port 30000 is free
# (max 60 s). Fixes the "port already in use" race: SIGTERM needs several seconds
# to drain and release the socket before the next server may bind.
PORT=30000
pkill -f serve.server 2>/dev/null
pkill -f out/strata 2>/dev/null
for i in $(seq 1 60); do
  if (echo > /dev/tcp/127.0.0.1/$PORT) 2>/dev/null; then
    sleep 1
  else
    sleep 1
    if ! (echo > /dev/tcp/127.0.0.1/$PORT) 2>/dev/null; then
      echo "port free after ${i}s"
      exit 0
    fi
  fi
done
echo "port still busy after 60 s"
exit 1
