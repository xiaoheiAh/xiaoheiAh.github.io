#!/bin/bash
./hugo -d ~/hugo-theme-pure --config pure.yml -t pure --gc
cd ~/hugo-theme-pure
git add . && git commit -m "update gh-pages" && git push -f

