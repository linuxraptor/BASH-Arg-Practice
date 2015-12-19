The idea of this repo is to get some good practice on challenging aspects of BASH scripts.

I hope to cover difficult regular expressions, error handling, intuitive usability, and portibility.

The idea is that my future scripts can always handle strange things like filenames with spaces in them and to properly escape command line arguments that contain otherwise tricky characters.


mount-img-with-offset.sh

The need for this script came about when making raw images of physical hard drives with several partitions.  Recently it is valuable to mount raspberry pi distributions that come as prepackaged and partitioned images.  This is most useful for simple filesystem changes, but can also be used for virtualization purposes.  The script searches for the first Linux partition and builds the appropriate mount command to make that image accessible.  It accepts only the source image filename and the target folder as arguments.  The script's purpose is not to pass in other mount options or command line arguments, it is simply to make mounting of meaningful partitions painless.

This script begins the habit of using strings as if they are arrays to ensure all parts of the variable are correctly passed along, and appropriately wrapping each variable in quotes.  Similarly, this script also uses "exec" to ensure that command arguments are correctly formatted.

Possible future options:
 -o --option to append custom option arguments to the mount command.
 Arguemnts beyond $2 could be collected and appended to the mount command with "$@".
