#!/bin/bash

# Copy and paste in to the end of your .bashrc.
# The other suggested methods create infinite
#  nested sessions, except that tmux catches this
#  issue and halts the process. You're left with
#  these errors:
#    sessions should be nested with care, unset $TMUX to force
#  These errors exist forever until someone unsets $TMUX
#  and breaks their terminal. This is a better way.

if [ ! -n "$TMUX_PANE" ];
then
   if [[ ! `tmux attach >/dev/null 2>&1` ]];
      then
      tmux;
   fi;
fi;
