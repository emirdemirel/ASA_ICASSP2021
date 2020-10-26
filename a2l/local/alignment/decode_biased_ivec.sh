#!/bin/bash

set -e
. ./utils/parse_options.sh

nj=$1
decode_dir=$2
vad_dir=$3
working_dir=$4
lang_dir=$5
model_dir_chain=$6
island_length=$7
online_ivector_dir=$8
beam=$9
log_dir=${10}

graph_dir_chain=$model_dir_chain/graph_4G
test_id=$(basename -- $vad_dir)

utils/mkgraph.sh --self-loop-scale 1.0 $lang_dir $model_dir_chain \
  $graph_dir_chain >> $log_dir/output.log 2> $log_dir/err.log || exit 1

rm -rf $model_dir_chain/$decode_dir
mkdir -p $model_dir_chain/$decode_dir/scoring

steps/nnet3/decode.sh --cmd run.pl --nj $nj \
    --skip-scoring true --num-threads 4 \
    --acwt 1.0 --post-decode-acwt 10.0 --frames-per-chunk 100 --beam $beam --lattice_beam 8 \
    --max_active 9000 --min_active 100 \
    --online-ivector-dir $online_ivector_dir \
    $graph_dir_chain $vad_dir $model_dir_chain/$decode_dir >> $log_dir/output.log 2> $log_dir/err.log || exit 1

echo "Decoding done!"

(lattice-scale --inv-acoustic-scale=10 "ark:gunzip -c $model_dir_chain/$decode_dir/lat.*.gz|" ark:- 2> $log_dir/err.log || exit 1)  | \
(lattice-add-penalty --word-ins-penalty=10.0 ark:- ark:- 2> $log_dir/err.log || exit 1) | \
(lattice-best-path --word-symbol-table=$lang_dir/words.txt ark:- ark,t:$model_dir_chain/$decode_dir/scoring/10.tra 2> $log_dir/err.log || exit 1 )
cat $model_dir_chain/$decode_dir/scoring/10.tra | sed 's/segment_//g' | sort -k1n | cut -d' ' -f2- | tr '\n' ' ' | tr -s ' ' > $working_dir/hypothesis.tra

local/alignment/sym2int.py $lang_dir/words.txt $working_dir/text_actual 2> $log_dir/err.log | tr -s ' ' > $working_dir/text_ints
echo "Creating word_alignment.ctm"
(lattice-add-penalty --word-ins-penalty=10.0 ark:"gunzip -c $model_dir_chain/$decode_dir/lat.*.gz|" ark:- 2> $log_dir/err.log || exit 1)| \
(lattice-1best  --acoustic-scale=0.1 ark:- ark:- 2> $log_dir/err.log || exit 1) | \
(lattice-align-words $lang_dir/phones/word_boundary.int $model_dir_chain/final.mdl ark:- ark:- 2> $log_dir/err.log || exit 1) | \
(nbest-to-ctm --frame-shift=0.03 ark:- - 2> $log_dir/err.log || exit 1) | sed '' | sort -s -k 1,1n | sed '' > $working_dir/word_alignment.ctm

(cat $working_dir/hypothesis.tra 2> $log_dir/err.log || exit 1) | sed 's/$/ (key_1)\n/' | tr -s ' '> $working_dir/hypothesis.tra_rm
(cat $working_dir/text_ints 2> $log_dir/err.log || exit 1) | sed 's/$/ (key_1)/' | tr -s ' ' > $working_dir/text_ints_rm

# text2text alignment
$KALDI_ROOT/tools/sctk/bin/sclite -p -i 'rm' -r $working_dir/text_ints_rm -h $working_dir/hypothesis.tra_rm > $working_dir/ref_and_hyp 2> $log_dir/err.log || (echo "sclite failure" && exit 1)
$KALDI_ROOT/tools/sctk/bin/sclite -p -i 'rm' -r $working_dir/hypothesis.tra_rm -h $working_dir/text_ints_rm > $working_dir/hyp_and_ref 2> $log_dir/err.log || (echo "sclite failure" && exit 1)

(cat $working_dir/ref_and_hyp 2> $log_dir/err.log || exit 1) | sed '/[<"]/d' | sed '/^\n/d' | tr '\n' ' ' | sed 's/ //g'  \
        > $working_dir/ref_and_hyp.final
(cat $working_dir/hyp_and_ref 2> $log_dir/err.log || exit 1) | sed '/[<"]/d' | sed '/^\n/d' | tr '\n' ' ' | sed 's/ //g'  \
        > $working_dir/hyp_and_ref.final


# Obtaining aligned word indices in both reference and hypothesis
local/alignment/correct_segment.py $working_dir/ref_and_hyp.final $island_length > \
        $working_dir/ref_and_hyp_match 2> $log_dir/err.log || exit 1
local/alignment/correct_segment.py $working_dir/hyp_and_ref.final $island_length > \
        $working_dir/hyp_and_ref_match 2> $log_dir/err.log || exit 1
((`wc -l $working_dir/ref_and_hyp_match | cut -d' ' -f1` == `wc -l $working_dir/hyp_and_ref_match \
        | cut -d' ' -f1`)) || \
        (echo 'Number of correct segments not matching' && exit 1)

