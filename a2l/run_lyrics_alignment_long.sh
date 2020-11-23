#!/bin/bash

# Configuration

nj=1
stage=0

polyphonic=false   #set to false for accapella

segmentation_method=single_pass    #      
               # recursive               

. ./path.sh
. ./cmd.sh

. ./utils/parse_options.sh

wavpath=$1
lyricspath=$2
savepath=$3

rec_name=$(basename -- $wavpath)
audio_format=(${wavpath##*.})
rec_id=(${rec_name//$(echo ".$audio_format")/ })
echo $rec_id
lang_dir=data/lang_${rec_id}

[[ ! -L "steps" ]] && ln -s $KALDI_ROOT/egs/wsj/s5/steps
[[ ! -L "utils" ]] && ln -s $KALDI_ROOT/egs/wsj/s5/utils

echo; echo "===== Starting at  $(date +"%D_%T") ====="; echo

outdir_ss=$savepath/audio_vocals #output directory to save the vocals separated audio files.
mkdir -p $outdir_ss
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
    ffmpeg -i $wavpath $outdir_ss/${rec_id}_vocals.wav
  fi
fi

###################################

wavpath_vocals=$outdir_ss/${rec_id}_vocals.wav
if [[ $stage -le 1 ]]; then

    echo "DATA PREPARATION"
    # Format the raw input lyrics and audio to be 
    # processed in the standard Kaldi format.
    # We prepare separate data directories
    # for the original and the source separated
    # recording.
    mkdir -p data/${rec_id}
    python3 local/data_preparation.py $lyricspath $outdir_ss/${rec_id}.wav conf/dict/lexicon_raw.txt data/${rec_id} 
    ./utils/fix_data_dir.sh data/${rec_id}
     
    mkdir -p data/${rec_id}_vocals
    python3 local/data_preparation.py $lyricspath $wavpath_vocals conf/dict/lexicon_raw.txt data/${rec_id}_vocals 
    ./utils/fix_data_dir.sh data/${rec_id}_vocals
fi

####################################


if [[ $stage -le 2 ]]; then

    echo "LEXICON & LM PREPARATION FOR ALIGNMENT"
    # At this step, we extend the standard lexicon
    # with any new words in the input lyrics.
    # This is necessary for robust alignment.
    # Pronunciations of new words may be unknown
    # and not easy to generate from scratch.
    # Thus, we employ a graphemic-based pipeline
    # to circumvent this problem.
    mkdir -p data/local
    cp -r conf/dict data/local/dict
    ./steps/dict/apply_g2p_phonetisaurus.sh --nbest 2 data/${rec_id}_vocals/oov_words.txt model/g2p data/local/${rec_id}
    cut -d$'\t' -f1,3 data/local/${rec_id}/lexicon.lex > data/local/${rec_id}/lex
    sed -e 's/\t/ /g' data/local/${rec_id}/lex > data/local/${rec_id}/oov_lexicon.txt
    cat data/local/${rec_id}/oov_lexicon.txt data/local/dict/lexicon_raw.txt | sort -u > data/local/dict/lexicon.txt
    sed -e 's/ / 1.0\t/' data/local/dict/lexicon.txt > data/local/dict/lexiconp.txt

    utils/prepare_lang.sh data/local/dict "<UNK>" data/local/lang $lang_dir

    silphonelist=$(cat $lang_dir/phones/silence.csl) || exit 1;
    nonsilphonelist=$(cat $lang_dir/phones/nonsilence.csl) || exit 1;
    steps/nnet3/chain/gen_topo.py $nonsilphonelist $silphonelist >$lang_dir/topo
    cp -r $lang_dir ${lang_dir}_original
fi

######################################

model_dir_chain=model/ctdnnsa_ivec
if [[ $stage -le 3 ]]; then
    echo "AUDIO SEGMENTATION"

    echo
    if [[ $segmentation_method == 'single_pass' ]]; then
      ./local/run_lyrics_segmentation.sh --dataset_id ${rec_id}_vocals \
        --wavpath_orig $wavpath --wavpath_vocals $wavpath_vocals \
        --data_orig data/${rec_id} data/${rec_id}_vocals \
        $model_dir_chain $lang_dir || exit 1
    elif [[ $decoding_model == 'recursive' ]]; then
      echo "- !!! This process might take a while as it is based on a recursive search algorithm."
      ./local/run_recursive_segmentation_ivec.sh --dataset_id ${rec_id}_vocals \
        --wavpath_orig $wavpath --wavpath_vocals $wavpath_vocals \
        --data_orig data/${rec_id} data/${rec_id}_vocals \
        $model_dir_chain $lang_dir || exit 1
    fi
fi

######################################

data_dir_segmented=data/${rec_id}_vocals_vadseg
data_dir_final=data/${rec_id}_vadseg
data_id=$(basename -- $data_dir_segmented)

if [[ $stage -le 4 ]]; then

    echo "WORD-LEVEL ALIGNMENT"
    echo
    echo "Feature Extraction last time for alignment."
    echo
    utils/fix_data_dir.sh $data_dir_segmented
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 1 --mfcc-config conf/mfcc_hires.conf \
      $data_dir_segmented exp/make_mfcc/${n}_vadseg mfcc
    steps/compute_cmvn_stats.sh $data_dir_segmented
    utils/fix_data_dir.sh $data_dir_segmented
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 1 \
      ${data_dir_segmented} model/ivector/extractor \
      model/ivector/ivectors_${data_id}_hires
    echo "Forced alignment using Phoneme based CTDNN_SA model"
    echo
    ali_dir=exp/${rec_id}_vocals/${rec_id}_vocals_ali
    local/align_chain.sh --cmd "$train_cmd" --nj 1 --beam 100 --retry_beam 7000 \
      --frames_per_chunk 140 --scale-opts '--transition-scale=1.0 --acoustic-scale=1.0 --self-loop-scale=1.0' \
      --online_ivector_dir model/ivector/ivectors_${data_id}_hires \
      $data_dir_segmented $lang_dir $model_dir_chain $ali_dir
    echo "Generating output files"
    ./local/generate_output_alignment.sh --frame_shift 0.03 $data_dir_segmented $rec_id ${lang_dir}_original $ali_dir $savepath/alignment


fi

#####################################

rm -r exp/${rec_id}_vocals/${rec_id}_vocals_segmentation
cp -r data/${rec_id}_vocals_vadseg $savepath/${rec_id}_vocals_vadseg
rm -r data/${rec_id}*
rm -r data/lang_${rec_id}

echo
echo "==== - ALIGNMENT ENDED SUCCESSFULLY! - ===="
echo "OUTPUTS ARE @ $savepath/alignment ."

exit 1

