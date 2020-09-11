# Submission for Mirex2020 - Audio-to-Lyrics-Alignment Challenge

## Setup

### 1) Kaldi  installation
This framework is built as a [Kaldi](http://kaldi-asr.org/)[1] recipe 
For instructions on Kaldi installation, please visit https://github.com/kaldi-asr/kaldi

### 2) Create a Conda environment
Python dependencies such as ```spleeter``` will be installed in this environment.
```
conda create --name mirex2020_ED 
```
### 3) Install Python dependencies
**Spleeter**: This is an open-source source separation module that we use in the begining of our pipeline.
**Num2words**: Python package for easy numeric-to-alphabetic translation.
```
conda install -c conda-forge spleeter        ### Open-source library for music source separation.
pip install num2words                        ### This package is required only if you'd like to test the grapheme-based acoustic model for alignment.
```

## How to run

* Modify ```KALDI_ROOT``` in  ```a2l/path.sh``` according to where your Kaldi installation is.

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
./run_a2l.sh $wavpath $lyricspath $savepath
```
* (OPTIONAL) Align with Grapheme based model:
```
./run_a2l.sh --align_with_grapheme true $wavpath $lyricspath $savepath
```

Note : If you have any problems during the pipeline, look up for the relevant process in ```run_a2l.sh```
