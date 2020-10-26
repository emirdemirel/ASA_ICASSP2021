# Submission for Mirex2020 - Audio-to-Lyrics-Alignment Challenge

# Requirements

Docker

Python3.6

Anaconda

Demucs

Kaldi

## Setup

### 1) Kaldi  installation
This framework is built as a [Kaldi](http://kaldi-asr.org/)[1] recipe 
For instructions on Kaldi installation, please visit https://github.com/kaldi-asr/kaldi


### 2) Set up virtual environment and install dependencies

```
cd a2l
git clone https://github.com/facebookresearch/demucs
cp local/demucs/separate.py demucs/demucs/separate.py
conda env update -f environment.yml
conda activate mirex2020_ED
```

### 3) Setup Kaldi environment

Modify ```KALDI_ROOT``` in  ```a2l/path.sh``` according to where your Kaldi installation is.
```
PATH_TO_YOUR_KALDI_INSTALLATION=
sed -i -- 's/path-to-your-kaldi-installation/${PATH_TO_YOUR_KALDI_INSTALLATION}/g' a2l/path.sh
```

## How to run


* Navigate to working directory and activate the environment.
```
cd 'dir-of-this-repository'/a2l
conda activate mirex2020_ED
```
## A) Audio-to-lyrics Alignment

* Set variables:
```
wavpath='full-path-to-audio'        # i.e. /home/emir/ALTA/LyricsTranscription/wav/Bohemian_Rhapsody.mp3
lyricspath='full-path-to-lyrics'    # i.e /home/emir/ALTA/LyricsTranscription/lyrics/Bohemian_Rhapsody.raw.txt
savepath='output-folder-name'       # This will be saved at 'dir-of-this-repository'/a2l/$savepath
```
* Run the pipeline / align with phoneme based model(default):
```
./run_mirex2020_alignment.sh --decoding_model model/ctdnnsa_ivec --alignment_model model/ctdnnsa_ivec $wavpath $lyricspath $savepath
```
* Run the pipeline for accapella recordings:
```
./run_mirex2020_alignment.sh --polyphonic false $wavpath $lyricspath $savepath
```

Note : If you have any problems during the pipeline, look up for the relevant process in ```run_mirex2020_alignment.sh```

## B) Automatic Lyrics Transcription

* First, you need to obtain the trained decoding graph from me. Once you have ``` graph_4G_ALT```, relocate it to ```a2l/model/ctdnn/```. 

* Set variables:
```
wavpath='full-path-to-audio'        # i.e. /home/emir/ALTA/LyricsTranscription/wav/Bohemian_Rhapsody.mp3
savepath='output-folder-name'       # This will be saved at 'dir-of-this-repository'/a2l/$savepath
```
* Run the pipeline:
```
./run_mirex2020_transcription.sh --decoding_model model/ctdnnsa_ivec $wavpath $savepath
```
* (OPTIONAL) Run the pipeline on accapella recordings:
```
./run_mirex2020_transcription.sh --polyphonic false $wavpath $savepath
```
* (OPTIONAL) Decode with 4-gram MaxEnt LM model:
```
./run_mirex2020_transcription.sh --decode_with_rnnlm false $wavpath $savepath
```
