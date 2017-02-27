#!/bin/bash
JUMAN_SOURCE_PATH="../juman-7.01"
JUMANPP_SOURCE_PATH="../jumanpp-1.01"
function import_dic {
	DIC_NAME=$1
	INDIR=$2
	OUTDIR=$3
	mkdir -p $OUTDIR/$DIC_NAME
	perl -Ilib -I$JUMAN_SOURCE_PATH/perl/blib/lib unknown/makedic.pl --inputdir $INDIR/$DIC_NAME --outputdir $OUTDIR/$DIC_NAME
}

function import_jumanppdic {
	DIC_NAME=$1
	INDIR=$JUMANPP_SOURCE_PATH/dict-build
	OUTDIR="./data/jumanppdic"
	import_dic $DIC_NAME $INDIR $OUTDIR
}

function import_jumandic {
	DIC_NAME=$1
	INDIR=$JUMAN_SOURCE_PATH
	OUTDIR="./data/jumandic"
	import_dic $DIC_NAME $INDIR $OUTDIR
}

#import_jumandic dic
import_jumanppdic dic
import_jumanppdic onomatopedic
import_jumanppdic webdic
import_jumanppdic wikipediadic
import_jumanppdic wiktionarydic
