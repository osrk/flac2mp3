#! /usr/bin/sh
#! /bin/zsh

find . -name '*.cue' -exec flac2mp3.pl {} \;
