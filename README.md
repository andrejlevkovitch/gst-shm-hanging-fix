# gst-shm-hanging-fix

## setup

0. install gstreamer

```bash
sudo apt-get install -y libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad
```

1. install gtk-doc

```bash
sudo apt-get install -y gtk-doc-tools
```

2. checkout gst-plugins-bad to your gstreamer version

```bash
cd gst-plugins-bad
git checkout $(gst-launch-1.0 --version | head -n 1 | awk '{print $3;}')
```

3. apply patch for [gstshmsink.c](gst-plugins-bad/sys/shm/gstshmsink.c)

```bash
patch gst-plugins-bad/sys/shm/gstshmsink.c gstshmsink.c.patch
```

4. build shm plugin

```bash
cd gst-plugins-bad
./autogen.sh
cd sys/shm
make
```

## Why hanging happens

Problem in handling situation when all shared memory, that we allocated by
shmsink at start, is already in use and no more memory for allocate new buffer.
In this case shmsink waits for freeing some block that previously was allocated,
but blocks frees only at exit. So it just hanging.

That happens in situation when we have minimum one consumer, that properly
connected to shmsink, but not pull frames with less rate then shmsink produce
new frames, or if shmsrc just sleeping. In this case shmsink allocks all blocks
in previously allocated shared memory and start waiting for free blocks
(hanging).


> Why shmsink can't just allocate more shared memory?

It is very problematic. At first, it can be unwanted behavior, because shmsink
can allocate all acceptable memory. At second, current allocator architecture
assumes that shared memory space is continuous, so for allocation new shared
memory we need relocate memory with saving current address (in other way all
buffers, that was previously allocated, will have pointers to invalid memory).
But it is very difficult if you have big part of memory (actually I'm not sure
that it is passible to relocate big part of memory at all)


> But why buffers freing only at exit?

I'm not sure, but I think it just gstreamer optimization: why we need allocate
memory for buffer each time if we jsut can allocate it ones and reuse it after
unreference. Imagine 1600x1300,RGB,20fps video stream - you need allocate ~ 120M
each second!


> What is your solution?

I just skip buffers if shm memory have no free memory blocks for allocating
buffer in shared memory space
