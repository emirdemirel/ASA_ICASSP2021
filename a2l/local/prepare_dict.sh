#!/bin/bash

#adapted from ami and chime5 dict preparation script
#Author: Gerardo Roa

# Begin configuration section.
words=5000
# End configuration section

echo "$0 $@"  # Print the command line for logging

if [ -f path.sh ]; then . ./path.sh; fi
. utils/parse_options.sh || exit 1;

# The parts of the output of this that will be needed are
# [in data/local/dict/ ]
# lexicon.txt
# extra_questions.txt
# nonsilence_phones.txt
# optional_silence.txt
# silence_phones.txt

mkdir -p data



dir=data/local/dict
mkdir -p $dir

dict_files=data/dict

echo "$0: Preparing files in $dir"
# Silence phones
for w in SIL SPN; do echo $w; done > $dir/silence_phones.txt
echo SIL > $dir/optional_silence.txt


# For this setup we're discarding stress.
cat $dict_files/symbols | \
  perl -ne 's:[0-9]::g; s:\r::; print lc($_)' | \
  tr a-z A-Z | \
  sort -u > $dir/nonsilence_phones.txt

# An extra question will be added by including the silence phones in one class.
paste -d ' ' -s $dir/silence_phones.txt > $dir/extra_questions.txt


grep -v ';;;' $dict_files/lexicon.txt |\
  uconv -f latin1 -t utf-8 -x Any-Lower |\
  perl -ne 's:(\S+)\(\d+\) :$1 :; s:  : :; print;' |\
  perl -ne '@F = split " ",$_,2; $F[1] =~ s/[0-9]//g; print "$F[0] $F[1]";' \
  > $dir/lexicon1_raw_nosil.txt || exit 1;


# Add prons for laughter, noise, oov
for w in `grep -v sil $dir/silence_phones.txt`; do
  echo "[$w] $w"
done | cat - $dir/lexicon1_raw_nosil.txt > $dir/lexicon2_raw.txt || exit 1;





echo "*Highest-count OOVs (including fragments) are:"
head -n 10 $dir/oov_counts.txt
echo "*Highest-count OOVs (excluding fragments) are:"
grep -v -E '^-|-$' $dir/oov_counts.txt | head -n 10 || true


## We join pronunciation with the selected words to create lexicon.txt
cat $dir/oov_lexicon.txt $dir/iv_lexicon.txt | sort -u > $dir/lexicon1_plus_g2p.txt
join $dir/lexicon1_plus_g2p.txt $dir/word_list_sorted > $dir/lexicon.txt

echo "<UNK> SPN" >> $dir/lexicon.txt

## The next section is again just for debug purposes
## to show words for which the G2P failed
rm -f $dir/lexiconp.txt 2>null; # can confuse later script if this exists.
awk '{print $1}' $dir/lexicon.txt | \
  perl -e '($word_counts)=@ARGV;
   open(W, "<$word_counts")||die "opening word-counts $word_counts";
   while(<STDIN>) { chop; $seen{$_}=1; }
   while(<W>) {
     ($c,$w) = split;
     if (!defined $seen{$w}) { print; }
   } ' $dir/word_counts > $dir/oov_counts.g2p.txt

echo "*Highest-count OOVs (including fragments) after G2P are:"
head -n 10 $dir/oov_counts.g2p.txt

utils/validate_dict_dir.pl $dir
exit 0;
