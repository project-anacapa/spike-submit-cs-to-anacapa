#!/usr/bin/env bash

python $1 2>&1 | sed -e 's/Ran \([0-9]*\) \(test[s]*\) in [0-9]*.[0-9]*s/Ran \1 \2 (timing removed)/g' 

