# ASA - (A)udio-to-(S)ong (A)lignment

#### An Audio-to-lyrics alignment with low memory footprint: 

A Kaldi-based framework for audio-to-lyrics alignment and transcription with low RAM memory consumption.

**Future work:** There will be new scripts provided for aligning lyrics in shorter auio clips in a less-time consuming way.



# Requirements

Ubuntu >= 14.04 

Docker

~35GB empty space on harddisk

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
conda activate ASA
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
conda activate ALA
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

## REFERENCES

If you use this code in your work, please cite:
```
@INPROCEEDINGS{demirel2021_asa,
  author={Demirel, Emir and Ahlbäck, Sven and Dixon, Simon},
  booktitle={ICASSP 2021 - 2021 IEEE International Conference on Acoustics, Speech and Signal Processing (ICASSP)}, 
  title={Low Resource Audio-To-Lyrics Alignment from Polyphonic Music Recordings}, 
  year={2021},
  pages={586-590},
  doi={10.1109/ICASSP39728.2021.9414395}}
```

If you use the pretrained models under ```a2l/models``` directory, please cite:

```
@INPROCEEDINGS{demirel2020_alta,
  author={Demirel, Emir and Ahlbäck, Sven and Dixon, Simon},
  booktitle={2020 International Joint Conference on Neural Networks (IJCNN)}, 
  title={Automatic Lyrics Transcription using Dilated Convolutional Neural Networks with Self-Attention}, 
  year={2020},
  pages={1-8},
  doi={10.1109/IJCNN48605.2020.9207052}}
```
