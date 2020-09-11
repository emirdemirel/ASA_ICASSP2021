# Submission for Mirex2020 - Audio-to-Lyrics-Alignment Challenge

# Requirements

Python3.6

Anaconda

Kaldi (see below for installation)

## Setup

### 1) Kaldi  installation
This framework is built as a [Kaldi](http://kaldi-asr.org/)[1] recipe 
For instructions on Kaldi installation, please visit https://github.com/kaldi-asr/kaldi


### 2) Set up virtual environment and install dependencies

```
cd a2l
conda env update -f environment.yml
conda activate mirex2020_ED
```

### 3) Setup Kaldi environment

Modify ```KALDI_ROOT``` in  ```a2l/path.sh``` according to where your Kaldi installation is.
```
sed -i -- 's/path-to-your-kaldi-installation/${PATH_TO_YOUR_KALDI_INSTALLATION}/g' a2l/path.sh
```

## How to run

* Navigate to working directory and activate the environment.
```
cd 'dir-of-this-repository'/a2l
conda activate mirex2020_ED
```

* Set variables:
```
wavpath='full-path-to-audio'        # i.e. /home/emir/ALTA/LyricsTranscription/wav/Bohemian_Rhapsody.mp3
lyricspath='full-path-to-lyrics'    # i.e /home/emir/ALTA/LyricsTranscription/lyrics/Bohemian_Rhapsody.raw.txt
savepath='output-folder-name'       # This will be saved at 'dir-of-this-repository'/a2l/$savepath
```
* Run the pipeline:
```
./run_mirex2020.sh $wavpath $lyricspath $savepath
```
* (OPTIONAL) Align with Grapheme based model:
```
./run_mirex2020.sh --align_with_grapheme true $wavpath $lyricspath $savepath
```

Note : If you have any problems during the pipeline, look up for the relevant process in ```run_a2l.sh```
