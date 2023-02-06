#!/usr/bin/fish

math (cat version.txt) + 1 > version.txt

butler push --userversion-file=version.txt html jcodefox/hatchetflashprototypegodot:html-universal-prototype
butler push --userversion-file=version.txt windows jcodefox/hatchetflashprototypegodot:windows-universal-prototype
butler push --userversion-file=version.txt linux jcodefox/hatchetflashprototypegodot:linux-universal-prototype
