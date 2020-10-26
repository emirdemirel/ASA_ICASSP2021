#!/bin/bash

nj=1
stage=1
merge_endings=false

set -e # exit on error

dataset_id=
data_orig=
wavpath_orig=
wavpath_vocals=
. ./path.sh
. ./cmd.sh

. ./utils/parse_options.sh

testset=$1
model_dir=$2
lang_dir=$3

test_id=$(basename -- $testset)

island_length=5
num_iters=1

echo; echo "===== Starting at  $(date +"%D_%T") ====="; echo

echo $wavpath_orig
echo $wavpath_vocals


# Features Extraction
if [[ $stage -le 1 ]]; then

    echo "FEATURE EXTRACTION on raw data"
    utils/fix_data_dir.sh $testset
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 1 ${testset} exp/make_mfcc/${test_id} mfcc
    steps/compute_cmvn_stats.sh ${testset}
    utils/fix_data_dir.sh $testset

    echo "INITIAL VOCAL ACTIVITY BASED SEGMENTATION"
    ./steps/compute_vad_decision.sh --nj 1 --cmd run.pl ${testset} exp/make_vad mfcc
    ./local/vad_to_segments.sh --nj 1 --min_duration 3 \
      --segmentation_opts "--silence-proportion 0.7 --max-segment-length 7 --hard-max-segment-length 20 " \
      ${testset} ${testset}_vad 
    
    echo "FEATURE EXTRACTION on VAD data"   
    utils/fix_data_dir.sh ${testset}_vad
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 1 --mfcc-config conf/mfcc_hires.conf \
      ${testset}_vad exp/make_mfcc/${test_id}_vad mfcc
    steps/compute_cmvn_stats.sh ${testset}_vad
    utils/fix_data_dir.sh ${testset}_vad

    echo "I-VECTOR EXTRACTION on VAD data"
    nspk=$(wc -l <${testset}_vad/spk2utt)
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 1 \
      ${testset}_vad model/ivector/extractor \
      model/ivector/ivectors_${test_id}_vad_hires

fi

# configuration for segmentation
graph_dir=$model_dir/graph_4G
working_dir=exp/$dataset_id/${test_id}_segmentation
segment_store=$working_dir/segments_store
log_dir=$working_dir/log
mkdir -p $working_dir
mkdir -p $log_dir
mkdir -p $segment_store

data_dir=${testset}_vad
if [[ $stage -le 2 ]]; then
  echo "Iteration: 0. Decoding on VAD data"; echo

  echo "Taking backup of $data_dir to ${data_dir}.laa.bkp"
  rm -rf ${data_dir}.laa.bkp || echo "" > $log_dir/output.log 2>$log_dir/err.log || exit 1
  cp -r $data_dir ${data_dir}.laa.bkp > $log_dir/output.log 2>$log_dir/err.log || exit

  echo "Prepare WORD_TIMINGS"
  cat $testset/text 2> $log_dir/err.log | \
    cut -d' ' -f2- | sed 's/^ \+//g' | \
    sed 's/ \+$//g' | tr -s ' ' > $working_dir/text_actual 
  cat $working_dir/text_actual 2> $log_dir/err.log | \
    sed -e 's:^:<s> :' -e 's:$: </s>:' > $working_dir/lm_text
  local/alignment/sym2int.py ${lang_dir}/words.txt \
    $working_dir/text_actual 2> $log_dir/err.log | \
    tr ' ' '\n' | sed 's/$/ -1 -1/g' > $working_dir/WORD_TIMINGS

  echo "Prepare biased Language Model"
  local/alignment/build_biased_lm.sh $working_dir $working_dir/lm_text \
    $lang_dir >> $log_dir/output.log 2> $log_dir/err.log || exit 1

  # Build biased decoding graph and transcribe
  echo "Decoding Begins!"
  num_lines=`wc -l $data_dir/feats.scp | cut -d' ' -f1`
  cp $data_dir/segments $testset/segments
  local/alignment/decode_biased_ivec.sh 1 decode ${testset}_vad \
    $working_dir $lang_dir $model_dir $island_length \
    model/ivector/ivectors_${test_id}_vad_hires \
    4000 $log_dir 2> $log_dir/err.log || exit 1

  echo "Iteration: 0 finished"
fi


if [[ $stage -le 3 ]]; then
  # create a status file which specifies which segments
  # are done and pending and save timing information
  # for each aligned word
  num_text_words=`wc -w $working_dir/text_ints | cut -d' ' -f1`
  text_end_index=$((num_text_words-1))
  echo $text_end_index
  audio_duration=`(wav-to-duration --read-entire-file scp:$data_dir/wav.scp ark,t:- 2>> $log_dir/output.log) | cut -d' ' -f2`
  cp ${testset}/segments $working_dir/segments
  sed -i 's/.//;s/.$//;s/,//'  $working_dir/ref_and_hyp_match
  sed -i 's/.//;s/.$//;s/,//'  $working_dir/hyp_and_ref_match
  local/alignment/prepare_word_timings.sh $working_dir $working_dir \
      0 $text_end_index 0.00 $audio_duration \
      $log_dir 2> $log_dir/err.log || (echo "Failed at prepare_word_timings.sh" && exit 1)
fi


island_length=3
if [[ $stage -le 6 ]]; then

  segment_id=`wc -l $working_dir/segments | cut -d' ' -f1`
  for x in `seq 1 $((num_iters-1))`;do
      echo "Iteration: ${x}. Processing segment id: $segment_id"
      while read y;do
          # Prepare files for each pending segment
          echo $y >> $log_dir/output.log
	  mkdir -p $segment_store/${segment_id}
       	  echo "$test_id $test_id `echo $y | cut -d' ' -f 1,2 `" >$testset/segments
          cut -d' ' -f1<$testset/segments > $working_dir/utt 2> $log_dir/err.log
          paste $working_dir/utt $working_dir/utt | sort > $testset/utt2spk
          cp $testset/utt2spk $testset/spk2utt  
          rm $working_dir/utt
          # Feature Extraction
          (rm $testset/feats.scp $testset/cmvn.scp || echo "") >> $log_dir/output.log 2>&1
          steps/make_mfcc.sh --nj 1 --mfcc-config conf/mfcc_hires.conf $testset \
              $working_dir/tmp/logdir/ $working_dir/tmp/mfccdir || segment_id=$((segment_id-1)) \
              cat $segment_store/${segment_id}/ALIGNMENT_STATUS >> $working_dir/ALIGNMENT_STATUS.working.iter${x} || break
          steps/compute_cmvn_stats.sh $testset $working_dir/tmp/logdir/ \
              $working_dir/tmp/cmvndir >> $log_dir/output.log 2> $log_dir/err.log
          steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 1 \
      	      $testset model/ivector/extractor \
              model/ivector/ivectors_${test_id}_iter${x}_vad_hires

          if [[ $x -eq $((num_iters-1)) ]]; then
              island_length=2    # We set final
          fi  
          cp $testset/segments $segment_store/${segment_id}/segments
	  time_begin="`echo $y | cut -d' ' -f1`"
          time_end="`echo $y | cut -d' ' -f2`"
	  word_begin_index=`echo $y | cut -d' ' -f4 `
	  word_begin_index=$((word_begin_index+1))
          word_end_index=`echo $y | cut -d' ' -f5`
	  word_end_index=$((word_end_index+1))
	  word_string=`cat $working_dir/text_actual | cut -d' ' -f $word_begin_index-$word_end_index`
	  word_begin_index=$((word_begin_index-1))
	  word_end_index=$((word_end_index-1))
	  echo "<s> $word_string </s>" > $segment_store/${segment_id}/lm_text
	  echo "$word_string" > $segment_store/${segment_id}/text_actual

          time_diff=$(echo $time_end - $time_begin | bc )
          echo "Time Difference of next segment : $time_diff"
          if (( $(echo "$time_diff > 40" |bc -l) ));  then
            num_iter=5
          fi

	  if [ $x -eq $((num_iters-2)) ]; then
              local/alignment/build_transducer.sh $segment_store/${segment_id} \
                  $segment_store/${segment_id}/text_actual \
                  $lang_dir false >> $log_dir/output.log 2> $log_dir/err.log || exit 1
	  elif [ $x -eq $((num_iters-1)) ]; then
   	      local/alignment/build_transducer.sh $segment_store/${segment_id} \
                  $segment_store/${segment_id}/text_actual \
                  $lang_dir true >> $log_dir/output.log 2> $log_dir/err.log || exit 1
	  else
                                        
          # Build n-gram Language Model (biased)
          local/alignment/build_biased_lm.sh $segment_store/${segment_id} \
            $segment_store/${segment_id}/lm_text $lang_dir \
            >> $log_dir/output.log 2> $log_dir/err.log || exit 1
	  fi

          # The lines below are for robustness 
          fsttablecompose $lang_dir/L_disambig.fst $lang_dir/G.fst | fstdeterminizestar --use-log=true | \
          fstminimizeencoded | fstpushspecial > $lang_dir/tmp/LG.fst.$$ 2> $log_dir/err.log || exit 1;

          if [ "$(fstisstochastic $lang_dir/tmp/LG.fst.$$)" != "nan nan" ]; then
	      local/alignment/decode_biased_ivec.sh 1 decode_${segment_id} \
                  $testset $segment_store/${segment_id} $lang_dir $model_dir $island_length \
                  model/ivector/ivectors_${test_id}_iter${x}_vad_hires \
                  300 $log_dir 2> $log_dir/err.log || exit 1
	      sed -i 's/.//;s/.$//;s/,//'  $segment_store/${segment_id}/ref_and_hyp_match
	      sed -i 's/.//;s/.$//;s/,//'  $segment_store/${segment_id}/hyp_and_ref_match
              local/alignment/prepare_word_timings.sh $working_dir $segment_store/${segment_id} \
                  $word_begin_index $word_end_index $time_begin $time_end \
                  $log_dir 2> $log_dir/err.log  || (echo "Failed: prepare_word_timings.sh" && exit 1)
              cat $segment_store/${segment_id}/ALIGNMENT_STATUS >> $working_dir/ALIGNMENT_STATUS.working.iter${x}
	      segment_id=$((segment_id+1))
          else
	      segment_id=$((segment_id-1))
              cat $segment_store/${segment_id}/ALIGNMENT_STATUS >> $working_dir/ALIGNMENT_STATUS.working.iter${x}
              merge_endings=true
          fi
	  sed -i "s/[(),']//g" $working_dir/ALIGNMENT_STATUS.working.iter${x}
          done < <(cat $working_dir/ALIGNMENT_STATUS | grep PENDING)		
	  # Update and clean up ALIGNMENT_STATUS file
	  cp $working_dir/ALIGNMENT_STATUS $working_dir/ALIGNMENT_STATUS.iter$((x-1))
	  cat $working_dir/ALIGNMENT_STATUS | grep 'DONE' > $working_dir/ALIGNMENT_STATUS.tmp
	  cat $working_dir/ALIGNMENT_STATUS.working.iter${x} >> $working_dir/ALIGNMENT_STATUS.tmp
	  cat $working_dir/ALIGNMENT_STATUS.tmp | sort -s -k 1,1n > $working_dir/ALIGNMENT_STATUS.tmp2
	  local/alignment/cleanup_status.py $working_dir/ALIGNMENT_STATUS.tmp2 > $working_dir/ALIGNMENT_STATUS
	  sed -i "s/[(),']//g" $working_dir/ALIGNMENT_STATUS
	  #rm $working_dir/ALIGNMENT_STATUS.tmp*
	  #rm $working_dir/ALIGNMENT_STATUS.working.iter${x}
  done;
fi

new_dir=${testset}_vadseg
create_dir=true
if [ $stage -le 7 ]; then
  # We create segments with (initially) 10 words
  # but if the last word does not have timing 
  # info, we keep looking for the first word 
  # having timing info.
  utils/int2sym.pl -f 1 $lang_dir/words.txt  $working_dir/WORD_TIMINGS > $working_dir/WORD_TIMINGS.words
  if [ $create_dir == "true" ]; then
	echo "Creating $new_dir"
	mkdir -p $new_dir
	x=`echo "$data_dir" | rev | cut -d'/' -f1 | rev`
	local/alignment/format_text_and_segment.py $working_dir/WORD_TIMINGS.words \
            $x $new_dir/segments $new_dir/text `(wav-to-duration --read-entire-file \
            scp:${data_dir}/wav.scp ark,t:- 2>> $log_dir/output.log) | cut -d' ' -f2`
	echo "${x} `cat ${data_dir}/wav.scp|cut -d' ' -f2-`" > $new_dir/wav.scp
	cut -d ' ' -f1 $new_dir/segments | sed "s/$/ $x/g" > $new_dir/utt2spk
	cut -d ' ' -f1 $new_dir/segments | sed "s/^/$x /g" > $new_dir/spk2utt
        if [ $merge_endings == true ]; then
            local/alignment/postprocess_segments.py $new_dir/segments True
        else
            local/alignment/postprocess_segments.py $new_dir/segments False
        fi
  fi
  touch $new_dir/.done
  echo 'Recursive Segmentation FINISHED SUCCESSFULLY!'

fi

exit 0
