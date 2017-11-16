#!/bin/bash
#####################################################
# Sup brah.                                         #
# This is my quick and dirty kernel compile script. #
# I might add auto Xen kernel naming later.         #
# Maybe make the compile part a function and        #
# make --xen a flag.                                #
# Idk.                                              #
# Cant sleep, 5:11 AM on Mon Mar 11, 2013 .         #
# I'll probably be tired at work.                   #
# Whatever.                                         #
#####################################################
# Added xen by default
# Cuz this system will always need it
# And my first priority is to finish this build

custom_tag="-ALL_FEATURES"
sources=$(eselect kernel show | sed -ne '2s/^.*\(linux.*\)/\1/p')
timestamp=$(date +%Y-%m-%d.%H:%M)
kernel_info="${timestamp}-${sources}${custom_tag}"
echo "Building the following kernel:"
eselect kernel list
cd /usr/src/linux
# Below necessary to make grub2 acknowledge a xen configuration
cp /usr/src/linux/.config /etc/kernels/kernel-config-${kernel_info}-xen
echo ""
echo "Cleaning."
make clean >/dev/null
echo ""
echo "Compiling."
time make -j8 &> kernel-compile.log
make modules_install &>> kernel-compile.log
cp /usr/src/linux/arch/x86_64/boot/bzImage /boot/kernel-${kernel_info}-xen
grub-mkconfig -o /boot/grub2/grub.cfg
echo "Build complete: kernel-${kernel_info}-xen"
echo "Compile log saved to kernel-compile.log"
# "Remember that if you want this kernel to work in Xen, you must follow"
# "the kernel name with "-xen" and copy it's configuration"
# "from /usr/src/linux/.config or /proc/config.gz to /etc/kernels directory."
# "For example:"
# "Kernel: /boot/kernel-03-08-2013-r3-xen"
# "Configuration for grub2-xen: /etc/kernels/kernel-config-03-08-2013-r3-xen"
echo ""
echo "Enabled compiler optimizations:"
# readelf -p .GCC.command.line /usr/src/linux/vmlinux # Disabled because it works with individual binaries but not a whole kernel
GEN_OPTS=`cat kernel-compile.log | awk '{ printf "%s", $0 }' | awk -Fpassed: '{print $2}' | awk -Fexecutable '{print $1}'`
# The above is horribly sloppy and needs to be refined
# If you want to compile your kernel with optimizations,
# find the "-O2" flag on the HOSTCFLAGS and HOSTCXXFLAGS lines in the kernel's Makefile,
# and replace them with "-Ofast -march=native".
# If you want to see the optimizations that the kernel used, you must put "-v -Q" at the beginning of the HOSTCFLAGS section
# in that kernel's Makefile. This does not work in the HOSTCXXFLAGS section.
# -v -Q -Ofast -march=native
echo CFLAGS="$GEN_OPTS"
