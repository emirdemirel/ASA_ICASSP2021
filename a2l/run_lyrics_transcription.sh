#!/bin/bash

# Begin configuration section

nj=1
stage=1

polyphonic=true   #set to false for accapella

decoding_model=ctdnnsa_ivec    # FOR phoneme based NN model with ivectors
               # ctdnnsa         FOR phoneme based NN model without ivectors
decode_with_rnnlm=true        # Set 'true' for decoding with RNNLM

. ./path.sh
. ./cmd.sh

. ./utils/parse_options.sh

wavpath=$1
savepath=$2

rec_name=$(basename -- $wavpath)
audio_format=(${wavpath##*.})
rec_id=(${rec_name//$(echo ".$audio_format")/ })
echo $rec_id
lang_dir=data/lang_${rec_id}

testset=data/${rec_id}_vocals

[[ ! -L "steps" ]] && ln -s $KALDI_ROOT/egs/wsj/s5/steps
[[ ! -L "utils" ]] && ln -s $KALDI_ROOT/egs/wsj/s5/utils
[[ ! -L "rnnlm" ]] && ln -s $KALDI_ROOT/egs/wsj/s5/rnnlm

echo; echo "===== Starting at  $(date +"%D_%T") ====="; echo

outdir_ss=$savepath/audio_vocals #output directory to save the vocals separated audio files.
if [[ $stage -le 0 ]]; then
  if [[ $polyphonic == true ]]; then
    echo "SOURCE SEPARATION"
    # At this step, we separate vocals. This is required
    # for Vocal-Activity-Detection based initial audio 
    # segmentation (See stage 2 for details).
    cd demucs
    python3 -m demucs.separate --dl -n demucs -d cpu -o ../$outdir_ss $wavpath
    cd ..
    mv $outdir_ss/demucs/${rec_id}/vocals.wav $outdir_ss/${rec_id}_vocals.wav
    rm -r $outdir_ss/demucs/${rec_id}/  # remove accompiment output as we won't need it.
  else
    cp $wavpath $outdir_ss/${rec_id}_vocals.wav

  fi
fi
wavpath_vocals=$outdir_ss/${rec_id}_vocals.wav
if [[ $stage -le 1 ]]; then

    echo "DATA PREPARATION"
    # Format the raw input lyrics and audio to be 
    # processed in the standard Kaldi format.
    # We prepare separate data directories
    # for the original and the source separated
    # recording.
    mkdir -p data/${rec_id}
    python3 local/data_preparation_ALT.py $outdir_ss/${rec_id}.wav data/${rec_id} 
    ./utils/fix_data_dir.sh data/${rec_id}
     
    mkdir -p data/${rec_id}_vocals
    python3 local/data_preparation_ALT.py $wavpath_vocals data/${rec_id}_vocals 
    ./utils/fix_data_dir.sh data/${rec_id}_vocals
fi


if [[ $stage -le 2 ]]; then

    echo "FEATURE EXTRACTION on raw data"
    utils/fix_data_dir.sh $testset
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 1 ${testset} exp/make_mfcc/${test_id} mfcc
    steps/compute_cmvn_stats.sh ${testset}
    utils/fix_data_dir.sh $testset

    echo "INITIAL VOCAL ACTIVITY BASED SEGMENTATION"
    ./steps/compute_vad_decision.sh --nj 1 --cmd run.pl ${testset} exp/make_vad mfcc
    ./local/vad_to_segments.sh --nj 1 --min_duration 3 \
      --segmentation_opts "--silence-proportion 0.7 --max-segment-length 5 --hard-max-segment-length 10 " \
      ${testset} ${testset}_VAD 
    
    echo "FEATURE EXTRACTION on VAD data"   
    utils/fix_data_dir.sh ${testset}_vad
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 1 --mfcc-config conf/mfcc_hires.conf \
      ${testset}_VAD exp/make_mfcc/${test_id}_VAD mfcc
    steps/compute_cmvn_stats.sh ${testset}_VAD
    utils/fix_data_dir.sh ${testset}_VAD

fi

graph_dir=model/$decoding_model/graph_4G_ALT
if [ $stage -le 3 ]; then
    if [[ $decoding_model == 'ctdnnsa_ivec' ]]; then

      echo "I-VECTOR EXTRACTION on VAD data"
      steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 1 \
        ${testset}_VAD model/ivector/extractor \
        model/ivector/ivectors_${rec_id}_VAD
        
      steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
        --frames-per-chunk 140 --beam 2000 --lattice_beam 8 \
        --max_active 9000 --min_active 100 \
        --nj 1 --cmd "$decode_cmd" --num-threads 4 \
        --online-ivector-dir model/ivector/ivectors_${rec_id}_VAD \
        $graph_dir ${testset}_VAD model/$decoding_model/decode_${rec_id} || exit 1
    elif [[ $decoding_model == 'ctdnnsa' ]]; then

      steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
        --frames-per-chunk 140 --beam 2000 --lattice_beam 8 \
        --max_active 9000 --min_active 100 \
        --nj 1 --cmd "$decode_cmd" --num-threads 4 \
        $graph_dir ${testset}_VAD model/$decoding_model/decode_${rec_id} || exit 1
    fi
fi


if [[ $stage -le 4 ]]; then
  mkdir -p $savepath/transcription
  if [[ $decode_with_rnnlm == true ]]; then
    # Here we rescore the lattices generated at stage 3
    # with RNNLM.
    lang_dir=model/rnnlm/language
    rnnlm/lmrescore_pruned.sh --cmd "$decode_cmd --mem 4G" \
      --weight 0.5 --max-ngram-order 4 --skip_scoring true $lang_dir \
      model/rnnlm ${testset}_VAD model/$decoding_model/decode_${rec_id} \
      model/$decoding_model/decode_${rec_id}_rnnlm
    lat_dir=model/$decoding_model/decode_${rec_id}_rnnlm
  else
    lat_dir=model/$decoding_model/decode_${rec_id}
  fi
  gunzip -c $lat_dir/lat.1.gz > $lat_dir/lat.1
  lattice-best-path ark:$lat_dir/lat.1  ark,t:- | int2sym.pl -f 2- model/$decoding_model/graph_4G_ALT/words.txt > $savepath/transcription/${rec_id}.txt || exit 1
  python local/format_output_ALT.py $savepath/transcription/${rec_id}.txt
fi

rm -r data/${rec_id}*

echo
echo "==== - TRANSCRIPTION ENDED SUCCESSFULLY! - ===="
echo "OUTPUTS ARE @ $savepath/transcription ."

exit 1
