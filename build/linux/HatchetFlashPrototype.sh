#!/bin/sh
echo -ne '\033c\033]0;HatchetflashPrototype\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/HatchetFlashPrototype.x86_64" "$@"
