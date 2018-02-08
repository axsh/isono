#!/bin/bash -e

echo "show current environment"
env | sort

PATH=/opt/axsh/wakame-vdc/ruby/bin:$PATH
export PATH

echo "build gem"
rake gem

