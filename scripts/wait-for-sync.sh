#!/usr/bin/env bash

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# wait-for-sync.sh
#
#   Wait for an ogmios / cardano-node to be synchronized with the network, up to a given threshold.
#
# Usage: ./wait-for-sync.sh OGMIOS_PORT THRESHOLD
#
# Examples:
#   ./wait-for-sync.sh 1337 1
#   ./wait-for-sync.sh 1338 0.95


set -eo pipefail

exitWithUsage () {
  echo -e "Error: missing argument(s)!\n"
  echo -e "Usage: $0 OGMIOS_PORT THRESHOLD TIMEOUT"
  echo -e "    Wait until a running Ogmios server at OGMIOS_PORT reaches THRESHOLD network synchronization.\n"
  echo -e "    Or it reaches the TIMEOUT in seconds to 18000 (5 hours)"
  echo -e "Example: \n    $0 1338 0.95"
  echo -e "         \n    $0 1337 0.99 3600"
  exit 1
}

OGMIOS_PORT=$1
if [ -z "$OGMIOS_PORT" ]; then
  exitWithUsage
fi

THRESHOLD=$2
if [ -z "$THRESHOLD" ]; then
  exitWithUsage
fi

# GitHUb actions have a limit of 6 hours so we will limit this script to 5 hours
readonly TIMEOUT=${3:-$(( 5*60*60 ))}

URL=http://localhost:$OGMIOS_PORT/health

showProgress () {
  N="$1"
  PER=$(printf "%.3f\n" "$(bc <<< "$N * 100")")
  LEN=$(printf "%.0f\n" "$(bc <<< "$N * 50")")

  BAR=""
  for ((i=1; i<=$LEN; i++))
  do
    BAR="$BAR▣"
  done
  for ((i=$LEN; i<=50; i++))
  do
    BAR="$BAR "
  done

  echo -en "Network synchronization: [$BAR] $PER%\r"
}

for (( ;; ))
do
  HEALTH=$(curl -sS $URL)
  NETWORK_SYNCHRONIZATION=$(sed 's/.*"networkSynchronization":\([0-9]\+\.\?[0-9]*\).*/\1/' <<< $HEALTH)

  RE='^[0-9]+\.?[0-9]*$'
  if ! [[ $NETWORK_SYNCHRONIZATION =~ $RE ]] ; then
     echo "error: unexpected response from /health endpoint: $HEALTH"
     exit 1
  fi

  showProgress $NETWORK_SYNCHRONIZATION
  PREDICATE=$(bc <<< "$NETWORK_SYNCHRONIZATION >= $THRESHOLD")

  if [ "$PREDICATE" -eq 1 ]; then
    exit 0
  elif [ $SECONDS -gt $TIMEOUT ]; then
    echo "WARNING: Reached the timeout limit without sync. But that's OK, we will continue on the next scheduled run."
    exit 0
  else
    sleep 5
  fi
done
