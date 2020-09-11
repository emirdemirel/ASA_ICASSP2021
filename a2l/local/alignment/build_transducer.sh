#!/bin/bash

. ./path.sh

working_dir=$1
input_file=$2
lang_dir=$3
include_skip=$4
if [ $include_skip == "false" ]; then
	echo "doing linear transducer"
	local/alignment/gen_transducer.py $input_file > $working_dir/G.txt
else
	echo "doing linear transducer with skip connection"
	local/alignment/gen_transducer.py $input_file --include-skip > $working_dir/G.txt
fi
fstcompile --isymbols=$lang_dir/words.txt --osymbols=$lang_dir/words.txt $working_dir/G.txt | fstarcsort --sort_type=ilabel | fstdeterminizestar | fstminimize > $lang_dir/G.fst
