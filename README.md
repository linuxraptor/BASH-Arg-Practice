Most of the scripts that end up here are for proof of concepts and may never truly be completed.  That is the purpose of this repository.  The idea is to get some good practice on challenging aspects of BASH scripts.

I hope to cover difficult regular expressions, secure variable practices, error handling, intuitive usability, and portibility.


mount-img-with-offset.sh

The need for this script came about when making raw images of physical hard drives with several partitions.  Recently, it has become useful for mount raspberry pi distributions that come as prepackaged and partitioned images.  While this was created to help make simple filesystem changes, it can also be used for virtualization purposes.  The script searches for available partitions in the disk image and asks the user what partition should be mounted.  It accepts only the source image filename and the target folder as arguments.  The script's purpose is not to pass in other mount options or command line arguments, it is simply to make mounting of meaningful partitions painless.

This script begins the habit of using strings as if they are arrays to ensure all parts of the variable are correctly passed along, and appropriately wrapping each variable in quotes.  Similarly, this script also uses "exec" to ensure that command arguments are correctly formatted.

Possible future options:
 -o --option to append custom option arguments to the mount command.
 Arguemnts beyond $2 could be collected and appended to the mount command with "$@".


scrape-ip-address.sh

Those who have dynamic IP addresses can have a difficult time maintaining DNS records.  This helps one small piece of that problem by looking up the user's public-facing IP address.  The only easily command line queryable online services that provide this information seem to be subscription based.  The goal of this script is to be able to pull our IP address from any website that offers it on the first page of results from the Google search, "what is my IP".  It seems I have achieved that for now.  Again, this script accepts no arguments at this time.  Simply run the script and use the returned string in your automation processes.  Optionally, you can edit the queried website at the top of the script.

Possible future options:
 Put websites into an array, query several.
 Return fastest result? Or get consensus?
 Mirrorselect-style option? Find the fastest website to get our results?


bashrc-tmux-attach.sh

Attaching to tmux with a one-liner can be dangerous and result in errors or lost sessions.  The existing suggestions on the internet would create infinite nested sessions and rely on tmux's ability to see this issue and put a a halt to it after a couple nests, bringing you back to the original window.  I perpetually got these errors:
  sessions should be nested with care, unset $TMUX to force
And then of course people (including myself) try to unset $TMUX and break their terminal.
This little script is a simple solution to that problem.
