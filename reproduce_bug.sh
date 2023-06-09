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
#export GST_DEBUG=shmsink:5
#export GST_DEBUG=shmsrc:5

# space for 3 buffers (NOTE: because shm requires additional allignment it will
# be able allocate only 2 buffers)
width=640
height=480
fps=1
pixel_size=4
shm_size=$(echo "3 * $width * $height * $pixel_size" | bc)

caps="video/x-raw, format=BGRx, width=$width, height=$height, framerate=$fps/1"

echo "start producer"
gst-launch-1.0 videotestsrc ! $caps ! shmsink socket-path=$sock shm-size=$shm_size wait-for-connection=false &
producer_pid=$!

sleep 1

echo "start consumer"
# hanging happens when shared memory allocator can't allocate more blocks in
# shared memory, so for bug reproducing I just add delay (0.5s)
gst-launch-1.0 shmsrc socket-path=$sock ! identity sleep-time=50000 ! $caps ! ximagesink
consumer_pid=$!
