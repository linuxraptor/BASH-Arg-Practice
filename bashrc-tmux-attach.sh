#!/bin/bash

if [ ! -n "${TMUX_PANE}" ];
then
   if [[ ! `tmux attach >/dev/null 2>&1` ]];
   then
      tmux;
   fi;
fi;
