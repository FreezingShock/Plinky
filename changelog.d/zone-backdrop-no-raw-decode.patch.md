Larkmoor's backdrop is no longer decoded from its raw PNG on a worker thread, which exported builds could not read. The copy now runs on the main thread during the zone swap, as before.
