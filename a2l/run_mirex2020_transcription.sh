#!/bin/bash

# Begin configuration section

nj=1
stage=1

polyphonic=true   #set to false for accapella

. ./path.sh
. ./cmd.sh


wavpath=$1
savepath=$2

rec_name=$(basename -- $wavpath)
audio_format=(${wavpath##*.})
rec_id=(${rec_name//$(echo ".$audio_format")/ })
echo $rec_id
lang_dir=data/lang_${rec_id}

testset=data/${rec_id}_vocals

echo; echo "===== Starting at  $(date +"%D_%T") ====="; echo

outdir_ss=$savepath/audio_vocals #output directory to save the vocals separated audio files.
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
    mv $wavpath $outdir_ss/${rec_id}_vocals.wav

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
      --segmentation_opts "--silence-proportion 0.8 --max-segment-length 5 --hard-max-segment-length 10 " \
      ${testset} ${testset}_VAD 
    
    echo "FEATURE EXTRACTION on VAD data"   
    utils/fix_data_dir.sh ${testset}_vad
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 1 --mfcc-config conf/mfcc_hires.conf \
      ${testset}_VAD exp/make_mfcc/${test_id}_VAD mfcc
    steps/compute_cmvn_stats.sh ${testset}_VAD
    utils/fix_data_dir.sh ${testset}_VAD

    echo "I-VECTOR EXTRACTION on VAD data"
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 1 \
      ${testset}_VAD model/ivector/extractor \
      exp/nnet3/ivectors_${rec_id}_VAD

fi

graph_dir=model/ctdnn/graph_4G_ALT
if [ $stage -le 3 ]; then
  nspk=$(wc -l <${testset}/spk2utt)
  steps/nnet3/decode.sh \
      --acwt 1.0 --post-decode-acwt 10.0 \
      --frames-per-chunk 140 --beam 2000 --lattice_beam 8 \
      --max_active 9000 --min_active 100 \
      --nj $nspk --cmd "$decode_cmd" --num-threads 4 \
      $graph_dir ${testset}_VAD model/ctdnn/decode_${rec_id} || exit 1
fi

if [ $stage -le 4 ]; then
  mkdir -p $savepath/transcription
  gunzip -c model/ctdnn/decode_${rec_id}/lat.1.gz > model/ctdnn/decode_${rec_id}/lat.1
  lattice-best-path ark:model/ctdnn/decode_${rec_id}/lat.1  ark,t: | int2sym.pl -f 2- model/ctdnn/graph_4G_ALT/words.txt > $savepath/transcription/${rec_id}.txt
  python local/format_output_ALT.py $savepath/transcription/${rec_id}.txt
fi

#rm -r data/${rec_id}*

echo
echo "==== - ALIGNMENT ENDED SUCCESSFULLY! - ===="
echo "OUTPUTS ARE @ $savepath/transcription ."

exit 1
