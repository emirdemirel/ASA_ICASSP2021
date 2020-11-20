# Low Resource Audio-to-lyrics alignment and transcription

A Kaldi-based framework for audio-to-lyrics alignment and transcription with low RAM memory consumption.

# Requirements

Ubuntu >= 14.04 

Docker

~35GB empty space on harddisk

Uninterrupted Internet connection

## Setup

## OPTION a) INSTALL and RUN using Docker

For easy setup, we create a Docker container and install
everything inside. All the libraries, dependencies, scripts
and models will be downloaded automatically.

Run below from the same directory with this README.md file.
This process may take around an hour.

```
docker build --tag ALTA:latest -f Dockerfile . 
```
### SETUP the environment

Set path to where you store the test data: 
```
DATASET='path-to-testset'
```
which should contain both the audio and lyrics text files at  "$DATASET/wav" and "$DATASET/lyrics"

```
docker run -v $DATASET:/a2l/dataset -it ALTA:latest
```
then, once you are inside the Docker container run:


```
source /root/miniconda3/etc/profile.d/conda.sh
conda activate mirex2020_ED
cd a2l
```
(You need to run the lines above every time you (re)start the Docker container.)


## OPTION b) INSTALL and RUN locally

### 1) Kaldi  installation
This framework is built as a [Kaldi](http://kaldi-asr.org/)[1] recipe 
For instructions on Kaldi installation, please visit https://github.com/kaldi-asr/kaldi


### 2) Set up virtual environment and install dependencies

```
cd a2l
git clone https://github.com/facebookresearch/demucs
cp local/demucs/separate.py demucs/demucs/separate.py
conda env update -f environment.yml
```

### 3) Setup Kaldi environment

Modify ```KALDI_ROOT``` in  ```a2l/path.sh``` according to where your Kaldi installation is.
```
PATH_TO_YOUR_KALDI_INSTALLATION=
sed -i -- 's/path-to-your-kaldi-installation/${PATH_TO_YOUR_KALDI_INSTALLATION}/g' a2l/path.sh
```

### 4) Setup the conda environment


* Navigate to the working directory and activate the environment.
```
cd 'dir-of-this-repository'/a2l
conda activate ALTA
```

# HOW TO RUN

## A) Low Resource Audio-to-lyrics Alignment from Long  Music Recordings

This pipeline was designed for retrieving word alignments from long music recordings using low computational resources. There is no limit for the length of the input music recording.

* Set variables:
```
wavpath='full-path-to-audio'        # i.e. /home/emir/ALTA/LyricsTranscription/wav/Bohemian_Rhapsody.mp3
lyricspath='full-path-to-lyrics'    # i.e /home/emir/ALTA/LyricsTranscription/lyrics/Bohemian_Rhapsody.raw.txt
savepath='output-folder-name'       # This will be saved at 'dir-of-this-repository'/a2l/$savepath
```
* Run the pipeline:
```
./run_mirex2020_alignment.sh --decoding_model model/ctdnnsa_ivec --alignment_model model/ctdnnsa_ivec $wavpath $lyricspath $savepath
```
* Run the pipeline for accapella recordings:
```
./run_lyrics_alignment_long.sh --polyphonic false $wavpath $lyricspath $savepath
```

Note : If you have any problems during the pipeline, look up for the relevant process in ```run_mirex2020_alignment.sh```

## B) Audio-to-lyrics Alignment for Long recordings

This pipeline was designed for retrieving word and phoneme alignments from short audio recordings.

* Set variables:
```
wavpath='full-path-to-audio'        # i.e. /home/emir/ALTA/LyricsTranscription/wav/Bohemian_Rhapsody.mp3
lyricspath='full-path-to-lyrics'    # i.e /home/emir/ALTA/LyricsTranscription/lyrics/Bohemian_Rhapsody.raw.txt
savepath='output-folder-name'       # This will be saved at 'dir-of-this-repository'/a2l/$savepath
```
* Run the pipeline:
```
./run_mirex2020_alignment.sh --decoding_model model/ctdnnsa_ivec --alignment_model model/ctdnnsa_ivec $wavpath $lyricspath $savepath
```
* Run the pipeline for accapella recordings:
```
./run_lyrics_alignment_short.sh --polyphonic false $wavpath $lyricspath $savepath
```

## C) Automatic Lyrics Transcription

This pipeline is designed for transcribing the lyrics from singing voice performances.

* First, you need to obtain the trained decoding graph from the author / creator of this repository : Emir Demirel. Once you have ``` graph_4G_ALT```, move it to ```a2l/model/ctdnn/```. 

* Set variables:
```
wavpath='full-path-to-audio'        # i.e. /home/emir/ALTA/LyricsTranscription/wav/Bohemian_Rhapsody.mp3
savepath='output-folder-name'       # This will be saved at 'dir-of-this-repository'/a2l/$savepath
```
* Run the pipeline:
```
./run_lyrics_transcription.sh --decoding_model model/ctdnnsa_ivec $wavpath $savepath
```
* (OPTIONAL) Run the pipeline on accapella recordings:
```
./run_lyrics_transcription.sh --polyphonic false $wavpath $savepath
```
* (OPTIONAL) Decode with 4-gram MaxEnt LM model:
```
./run_mirex2020_transcription.sh --decode_with_rnnlm false $wavpath $savepath
```
## D) Extract frame-level Phoneme posteriorgrams:

This pipeline is designed for extracting the frame-level phoneme posteriorgrams from a capella recordings.

```
audio_path='absolute-path-to-the-input-audio-file'
save_path='path-to-save-the-output
./extract_phn_posteriorgram.sh $audio_path $save_path
```

The output posteriorgrams are saved as numpy arrays (.npy).

Note that we have used 16kHz for the sample rate and 10ms of hop size.

