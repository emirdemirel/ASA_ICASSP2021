#!/bin/bash

# Begin configuration section

nj=1
stage=0
model_dir_chain=model/ctdnn

align_with_grapheme=false
. ./path.sh
. ./cmd.sh
set -e # exit on error

[[ ! -L "steps" ]] && ln -s $KALDI_ROOT/egs/wsj/s5/steps
[[ ! -L "utils" ]] && ln -s $KALDI_ROOT/egs/wsj/s5/utils

# End configuration section
. ./utils/parse_options.sh

wavpath=$1
lyricspath=$2
savepath=$3

rec_name=$(basename -- $wavpath)
audio_format=(${wavpath##*.})
rec_id=(${rec_name//$(echo ".$audio_format")/ })
echo $rec_id
lang_dir=data/lang_${rec_id}

echo; echo "===== Starting at  $(date +"%D_%T") ====="; echo

outdir_ss=$savepath/audio_vocals #output directory to save the vocals separated audio files.
if [[ $stage -le 0 ]]; then
    echo "SOURCE SEPARATION"
    # At this step, we separate vocals. This is required
    # for Vocal-Activity-Detection based initial audio 
    # segmentation (See stage 2 for details).

    spleeter separate -i $wavpath -o $outdir_ss
    mv $outdir_ss/${rec_id}/vocals.wav $outdir_ss/${rec_id}_vocals.wav
    rm -r $outdir_ss/${rec_id}/  # remove accompiment output as we won't need it.
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
    python3 local/data_preparation.py $lyricspath $outdir_ss/${rec_id}.wav conf/dict/lexicon_raw.txt data/${rec_id} 
    ./utils/fix_data_dir.sh data/${rec_id}
     
    mkdir -p data/${rec_id}_vocals
    python3 local/data_preparation.py $lyricspath $wavpath_vocals conf/dict/lexicon_raw.txt data/${rec_id}_vocals 
    ./utils/fix_data_dir.sh data/${rec_id}_vocals
fi


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
fi

 
if [[ $stage -le 3 ]]; then

    echo "AUDIO SEGMENTATION"
    echo "- !!! This process might take a while as it is based on a recursive search algorithm."
    ./local/run_recursive_segmentation.sh --dataset_id ${rec_id}_vocals \
      --wavpath_orig $wavpath --wavpath_vocals $wavpath_vocals \
      --data_orig data/${rec_id} data/${rec_id}_vocals \
      $model_dir_chain $lang_dir
fi

if [[ $align_with_grapheme == true ]]; then
    stage=4
else
    stage=5
fi

data_dir_segmented=data/${rec_id}_vocals_vadseg
data_dir_final=data/${rec_id}_vadseg
data_id=$(basename -- $data_dir_segmented)

if [[ $stage -le 4 ]]; then

    lang_dir_grph=data/lang_${rec_id}_grph
    model_dir_chain_grph=model/ctdnn_grph
    echo "WORD-LEVEL ALIGNMENT"
    echo
    echo "Create graph for grapheme based model."
    #cp -r data/dict_grph data/local/dict_grph
    lexicon_path=conf/lexicon_grph.txt
    python3 local/extend_lexicon.py $lexicon_path data/$rec_id/text data/local/dict_grph
    utils/prepare_lang.sh data/local/dict_grph "<UNK>" data/local/lang_grph $lang_dir_grph
    echo "Feature Extraction last time for alignment."
    echo "This time we include i-Vectors"
    echo
    utils/fix_data_dir.sh $data_dir_segmented
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 1 --mfcc-config conf/mfcc_hires.conf \
      $data_dir_segmented exp/make_mfcc/${n}_vadseg mfcc
    steps/compute_cmvn_stats.sh $data_dir_segmented
    utils/fix_data_dir.sh $data_dir_segmented
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 1 \
      ${data_dir_segmented} model/ivector/extractor \
      model/ivector/ivectors_${data_id}_hires
    echo "Forced alignment using Grapheme based CTDNN_SA model"
    echo
    ali_dir=exp/${rec_id}_vocals/${rec_id}_vocals_ali
    local/align_chain.sh --cmd "$train_cmd" --nj 1 --beam 50 --retry_beam 700 \
      --frames_per_chunk 100 --scale-opts '--transition-scale=1.0 --acoustic-scale=1.0 --self-loop-scale=1.0' \
      --online_ivector_dir model/ivector/ivectors_${data_id}_hires \
      $data_dir_segmented $lang_dir_grph $model_dir_chain_grph $ali_dir
    echo "Generating output files"
    ./local/generate_output_alignment.sh --frame_shift 0.03 $data_dir_segmented $rec_id $lang_dir_grph $ali_dir $savepath/alignment


fi

if [[ $stage -le 5 ]]; then

    echo "WORD-LEVEL ALIGNMENT"
    echo
    echo "Feature Extraction last time for alignment."
    echo
    utils/fix_data_dir.sh $data_dir_segmented
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 1 --mfcc-config conf/mfcc_hires.conf \
      $data_dir_segmented exp/make_mfcc/${n}_vadseg mfcc
    steps/compute_cmvn_stats.sh $data_dir_segmented
    utils/fix_data_dir.sh $data_dir_segmented
    #steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 1 \
      #${data_dir_segmented} model/ivector/extractor \
      #model/ivector/ivectors_${data_id}_hires
    echo "Forced alignment using Phoneme based CTDNN_SA model"
    echo
    ali_dir=exp/${rec_id}_vocals/${rec_id}_vocals_ali
    local/align_chain.sh --cmd "$train_cmd" --nj 1 --beam 50 --retry_beam 700 \
      --frames_per_chunk 100 --scale-opts '--transition-scale=1.0 --acoustic-scale=1.0 --self-loop-scale=1.0' \
      $data_dir_segmented $lang_dir $model_dir_chain $ali_dir
    echo "Generating output files"
    ./local/generate_output_alignment.sh --frame_shift 0.03 $data_dir_segmented $rec_id $lang_dir $ali_dir $savepath/alignment


fi



rm -r exp/${rec_id}_vocals/${rec_id}_vocals_segmentation
cp -r data/${rec_id}_vocals_vadseg $savepath/${rec_id}_vocals_vadseg
#rm -r data/${rec_id}*
rm -r data/lang_${rec_id}

echo
echo "==== - ALIGNMENT ENDED SUCCESSFULLY! - ===="
echo "OUTPUTS ARE @ $savepath/alignment ."

exit 1
