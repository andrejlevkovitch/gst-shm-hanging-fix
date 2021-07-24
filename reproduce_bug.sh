#!/bin/bash
# reproduces bug (hangind) with shmsrc/shmsink

sock=/tmp/shm-sock

set -e

producer_pid=
consumer_pid=
at_exit() {
  set +e

  kill -2 $producer_pid &> /dev/null
  kill -2 $consumer_pid &> /dev/null

  if [ -n "$producer_pid" ]; then
    wait $producer_pid
  fi
  if [ -n "$consumer_pid" ]; then
    wait $consumer_pid
  fi
}

trap at_exit EXIT


if [ -f $sock ]; then
  rm $sock
fi

export GST_PLUGIN_PATH=$(pwd)/gst-plugins-bad/sys/shm
export GST_DEBUG=2
#export GST_DEBUG=shmsrc:7,shmsink:7

# space for 10 buffers (12Mb)
shm_size=$(echo "12 * 1024 * 1024" | bc)

echo "start producer"
gst-launch-1.0 videotestsrc ! video/x-raw, format=BGRx, width=640, height=480, framerate=30/1 ! shmsink socket-path=$sock shm-size=$shm_size wait-for-connection=false &
producer_pid=$!

sleep 1

echo "start consumer"
# hanging happens when shared memory allocator can't allocate more blocks in
# shared memory, so for bug reproducing I just add delay (0.5s)
gst-launch-1.0 shmsrc socket-path=$sock ! identity sleep-time=50000 ! video/x-raw, format=BGRx, width=640, height=480, framerate=30/1 ! ximagesink
consumer_pid=$!
