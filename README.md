# ALA - (A)udio-to-(L)yrics (A)lignment

#### Low Resource Audio-to-lyrics alignment: 

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
docker build --tag asa:latest -f Dockerfile . 
```
### SETUP the environment

Set path to where you store the test data: 
```
DATASET='path-to-testset'
```
which should contain both the audio and lyrics text files at  "$DATASET/wav" and "$DATASET/lyrics"

```
docker run -v $DATASET:/a2l/dataset -it asa:latest
```
then, once you are inside the Docker container run:


```
source /root/miniconda3/etc/profile.d/conda.sh
conda activate ALTA
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
conda activate ASA
```

# HOW TO RUN

This pipeline was designed for retrieving word alignments from long music recordings using low computational resources. There is no limit for the length of the input music recording.

* Set variables:
```
wavpath='full-path-to-audio'        # i.e. /home/emir/ALTA/LyricsTranscription/wav/Bohemian_Rhapsody.mp3
lyricspath='full-path-to-lyrics'    # i.e /home/emir/ALTA/LyricsTranscription/lyrics/Bohemian_Rhapsody.raw.txt
savepath='output-folder-name'       # This will be saved at 'dir-of-this-repository'/a2l/$savepath
```
* Run the pipeline:
```
./run_lyrics_alignment_long.sh $wavpath $lyricspath $savepath
```
* Run the pipeline for accapella recordings:
```
./run_lyrics_alignment_long.sh --polyphonic false $wavpath $lyricspath $savepath
```

Note : If you have any problems during the pipeline, look up for the relevant process in ```run_lyrics_alignment_long.sh```


