#!/bin/bash -e

echo "copy artifact."
[[ -f /mnt/artifact/isono-*.gem ]] && rm -f /mnt/artifact/isono-*.gem
cp isono-*.gem /mnt/artifact

