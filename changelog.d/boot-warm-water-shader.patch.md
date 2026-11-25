Boot warms the water night shader on the main thread before the threaded loads start, to avoid a worker-thread preload race that logged "Could not preload resource" on PC boots.
