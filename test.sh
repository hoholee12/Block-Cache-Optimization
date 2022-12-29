#!/bin/bash
#!/bin/bash

if [[ -f /sys/kernel/debug/f2fs/status ]]; then
  cat /sys/kernel/debug/f2fs/status > hello.txt
fi
