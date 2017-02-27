#!/bin/sh
#
# compile JUMAN dictionaries in the specified path
#

if [ -z "$JUMAN_PREFIX" ]; then
    JUMAN_PREFIX=/share/usr
fi

MAKEINT="$JUMAN_PREFIX/libexec/juman/makeint"
DICSORT="$JUMAN_PREFIX/libexec/juman/dicsort"
MKDARTS="$JUMAN_PREFIX/libexec/juman/mkdarts"
MAKEPAT="$JUMAN_PREFIX/libexec/juman/makepat"

usage () {
    echo "usage: $0 -d JUMAN_SOURCE_DIC_DIR"
    exit 1
}

while getopts i:d: OPT
do
  case $OPT in
      "d" ) dicdir=$OPTARG ;;
      * )usage ;;
  esac
done

if [ ! -d "$dicdir" ]; then
    usage
fi

cd $dicdir

tmpfile="tmpfile_int"
rm -f $tmpfile

for dicfile in *.dic; do
    echo $dicfile

    intfile=${dicfile%.dic}.int
    datfile=${dicfile%.dic}.dat

    $MAKEINT $dicfile
    cat $intfile >> $tmpfile
done

$DICSORT $tmpfile > jumandic.dat
if [ -x "$MKDARTS" ]; then
    $MKDARTS jumandic.dat jumandic.da jumandic.bin
else
    # older version
    $MAKEPAT
fi

rm -f $tmpfile
