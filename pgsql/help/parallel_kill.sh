#!/bin/bash

# Find the PID of the parallel command (replace pattern as needed)
PARENT_PID=$(pgrep -f 'parallel.*VACUUM ANALYZE')

echo "Parallel parent PID: $PARENT_PID"

# Kill the parallel parent process
kill -TERM $PARENT_PID

# Kill all child processes of the parallel process (usually psql)
# List child PIDs of the parallel parent PID
CHILD_PIDS=$(pgrep -P $PARENT_PID)

if [ -n "$CHILD_PIDS" ]; then
  echo "Killing child PIDs: $CHILD_PIDS"
  kill -TERM $CHILD_PIDS
else
  echo "No child processes found."
fi

