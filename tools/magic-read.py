#!/usr/bin/python3
import os
import sys
import selectors

sys.stdout.flush()
selector = selectors.DefaultSelector()

fifo_fd = os.open(sys.argv[1], os.O_RDONLY | os.O_NONBLOCK)

selector.register(sys.stdin, selectors.EVENT_READ)
selector.register(fifo_fd, selectors.EVENT_READ)

for key, events in selector.select():
    if key.fileobj == sys.stdin:
        print(sys.stdin.readline())
    elif key.fileobj == fifo_fd:
        print(os.read(fifo_fd, 4096).decode())

sys.stdout.flush()

