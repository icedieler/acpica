#!/bin/bash
#
# Script to find the divergences between these sets of source code:
#    1) The current ACPICA source from the ACPICA git tree
#    2) The version of ACPICA that is integrated into Linux
#
# The goal is to eliminate as many differences as possible between
# these two sets of code.
#
# Usage: ./divergence.sh <Path to root of linux source code>
#
if [ -z $1 ] ; then
	echo "Usage: $0 <Linux>"
	echo "  Linux: Path of Linux source"
	exit 1
fi
if [ ! -e $1 ] ; then
	echo "$1, Linux source directory does not exist"
	exit 1
fi
if [ ! -d $1 ] ; then
	echo "$1, Not a directory"
	exit 1
fi

LINUX=$1
ACPICA_TMP=acpica_tmp
LINUX_ACPICA=linux-acpica
ACPICA_LINUXIZED=acpica-linuxized

# Get the root of the ACPICA source tree
ACPICA=`readlink -f ../..`

LINDENT=$ACPICA/generate/linux/patches/lindent.sh
if [ ! -e $LINDENT ] ; then
	echo "Could not find lindent.sh script"
	exit 1
fi

#
# Build the AcpiSrc utility if necessary
#
echo "Ensure the 32-bit AcpiSrc utility is up-to-date"
make -C $ACPICA BITS=32 acpisrc
ACPISRC=${ACPICA}/generate/unix/acpisrc/obj32/acpisrc

#
# Copy the actual Linux ACPICA files locally
#
echo "Creating local Linux ACPICA files subdirectory"
rm -rf $ACPICA_TMP $LINUX_ACPICA $ACPICA_LINUXIZED
mkdir $ACPICA_TMP $LINUX_ACPICA

cp $LINUX/drivers/acpi/acpica/* $LINUX_ACPICA/
cp $LINUX/include/acpi/*.h $LINUX_ACPICA/
cp $LINUX/include/acpi/platform/*.h $LINUX_ACPICA/

#
# Ensure that the files in the two directories match
#
cd $LINUX_ACPICA
ALL_FILES=`ls`

for f in $ALL_FILES ; do
	tmp_f=`find $ACPICA/source -name $f`
	if [ ! -z $tmp_f ] ; then
		cp $tmp_f ../$ACPICA_TMP
	else
		rm $f
	fi
done

#
# Linuxize the ACPICA source
#
cd ..
$ACPISRC -ldqy $ACPICA_TMP $ACPICA_LINUXIZED

#
# Enable cross platform generation
#
dos2unix -q $LINDENT
dos2unix -q $ACPICA_LINUXIZED/*
dos2unix -q $LINUX_ACPICA/*

#
# Lindent both sets of files
#
echo "Building lindented linuxized ACPICA files"
cd $ACPICA_LINUXIZED
find . -name "*.[ch]" | xargs $LINDENT
rm -f *~
cd ..

echo "Building lindented actual linux ACPICA files"
cd $LINUX_ACPICA
find . -name "*.[ch]" | xargs $LINDENT
rm -f *~
cd ..

#
# Now we can finally do the big diff
#
echo "Creating ACPICA/Linux diff"
diff -E -b -w -B -rpuN $LINUX_ACPICA $ACPICA_LINUXIZED > divergence.diff
ls -l divergence.diff

#
# Cleanup
#
rm -r $LINUX_ACPICA
rm -r $ACPICA_TMP
rm -r $ACPICA_LINUXIZED
