#!/bin/sh
printf '\033c\033]0;%s\a' StudyBuddy
base_path="$(dirname "$(realpath "$0")")"
"$base_path/StuddyBuddy.x86_64" "$@"
