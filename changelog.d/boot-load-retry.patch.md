Boot retries a threaded load that fails (up to two re-requests) before it reports the failure, so a one-off worker race no longer fails the boot.
