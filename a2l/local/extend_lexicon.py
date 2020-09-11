import os, sys, re
import argparse
from num2words import num2words


def read_lexicon(lexicon_path):
    lex = []
    with open(lexicon_path,'r') as l:
        for line in l.readlines():
            if not '<UNK>' in line:
                lex.append(line.replace('\n',''))
    return lex                   

def write_extended_lexicon(lex_extended,save_path):
    with open(os.path.join(save_path,'lexicon.txt'),'w') as w, open(os.path.join(save_path,'lexiconp.txt'),'w') as wp:
        for i in range(len(lex_fin)-2):
            item = lex_fin[i]
            w.write(item + '\n')
            wp.write(item.split(' ')[0] + ' 1.0\t' + item.split(' ',1)[1] + '\n')
        w.write('<UNK> SPN\n')
        wp.write('<UNK> 1.0\tSPN\n')    
                       
                       
def get_unknown_words(text_path):                       
    with open(text_path,'r') as t:
        return t.readlines()[0].replace('\n','').replace('  ',' ').split(' ',1)[1].split(' ')  
                       
                       
def save_lexicon(lex,save_path):
    with open(os.path.join(save_path,'lexicon.txt'),'w') as w, open(os.path.join(save_path,'lexiconp.txt'),'w') as wp:
        for i in range(len(lex)-2):
            w.write(lex[i] + '\n')
            wp.write(lex[i].split(' ')[0] + ' 1.0\t' + lex[i].split(' ',1)[1] + '\n')
        w.write('<UNK> SPN\n')
        wp.write('<UNK> 1.0\tSPN\n')         
                       
                       
def process_alphabetic(words):   
    numbers=['1','2','3','4','5','6','7','8','9','0']; numbers=set(numbers)                   
    lex_1 = []; symbols = []; lex_words = []
    for i in range(len(words)):
        word = words[i].replace('\n','')
        if word.startswith("'"):
            word_noap = word[1:]
        else:    
            word_noap = word    
        chars = list(word); chars_string = ''
        for i in range(len(chars)):
            if i > 0:
                if chars[i-1] in numbers:
                    if chars[i] in numbers:
                        chars_string = chars_string + chars[i]
                    else:
                        chars_string = chars_string + ' ' + chars[i]                    
                else:    
                    chars_string = chars_string + ' ' + chars[i]
            else:
                chars_string = chars_string + ' ' + chars[i]        
        lex_1.append((word + chars_string))     
    return lex_1   
                       
                       
                       
def process_numeric(lex_1):   
                       
    lex_2_num = []
    for item in lex_1:
        word = item.split(' ')[0]
        grphs = item.split(' ',1)[1]
        prns = []
        num_prns=[]
        for grph in grphs.split(' '):
            if grph.isnumeric():
                prn_1 = ' '.join(num2words(grph).upper().replace(', ','')).replace('  ','').replace(' - ',' ')
                num_prns.append(prn_1)
                if len(list(grph)) > 1:
                    grphs_num = list(grph)
                    prns_2=''
                    for i in range(len(grphs_num)):
                        prns_2 = prns_2 + ' ' + ' '.join(num2words(grphs_num[i]).upper())
                    num_prns.append(prns_2)
                for i in range(len(num_prns)):
                    lex_2_num.append(word + ' ' + grphs.replace(grph,num_prns[i]).replace('  ',' '))        
                break    
    return lex_2_num              
                      
                       
def process_ordinals(lex):   
                       
    # DEFINE CORRECT ORDINALS                   
    ordinals = {'1ST': 'F I R S T','2ND': 'S E C O N D', '3RD': 'T H I R D', 
                    '5TH': 'F I F T H', '8TH':'E I G H T H','9TH':'N I N T H',
                    '20TH' : 'T W E N T I E T H', '30TH': 'T H I R T I E T H', 
                    '40TH': 'F O U R T I E T H', '50TH': 'F I F T I E T H', 
                    '60TH': 'S I X T I E T H', '70TH': 'S E V E N T I E T H', 
                    '80TH': 'E I G H T I E T H', '90TH': 'N I N E T I E T H'}
    # DEFINE WRONG ORDINALS THAT MAY HAVE OCCURRED AS A RESULT OF PREVIOUS PASSES                   
    ordinals_wrong = {'1ST': 'O N E S T','2ND': 'T W O N D', '3RD': 'T H R E E R D',
                      '5TH': 'F I V E T H', '8TH': 'E I G H T T H','9TH':'N I N E T H',
                      '20TH' : 'T W E N T Y T H', '30TH': ' T H I R T Y T H',
                      '40TH': 'F O U R T Y T H', '50TH': 'F I F T Y T H', 
                      '60TH': 'S I X T Y T H', '70TH': 'S E V E N T Y T H', 
                      '80TH': 'E I G H T Y T H', '90TH': 'N I N E T Y T H'}
    ordinals.keys()  
                       
    lex_ord = []
    for item in lex:
        word = item.split(' ')[0]
        grph = item.split(' ',1)[1]
        for key in ordinals.keys():
            if key in word:
                grph_new = grph.replace(ordinals_wrong[key],ordinals[key])
                lex_ord.append(word + ' ' + grph_new)
        if not any(i in word for i in ordinals.keys()):
            lex_ord.append(item.replace('  ',' '))                   
    return lex_ord
                       
                       
                       
def add_position_aware_graphemes(lex):      
                       
    lex_wb = []
    for i in range(len(lex)):
        if not '<UNK>' in lex[i].split(' ')[0]:
            word = lex[i].split(' ')[0]
            if lex[i].split(' ',1)[1].startswith(' '):
                grphs = lex[i].split(' ')[2:]
            else:    
                grphs = lex[i].split(' ')[1:]
    
            for j in range(len(grphs)):
                if j == 0 or j == len(grphs)-1:
                    grphs[j] = grphs[j]+'_WB'
            lex_wb.append(word + ' ' + ' '.join(grphs)) 
            
    return lex_wb                   
                       
                       
def create_graphemic_lexicon(words):
                  
    # PASS 1 : PROCESS RAW ALPHABETIC CHARACTERS
    lex_1 = process_alphabetic(words)   
    # PASS 2 : PROCESS RAW NUMBERS INTO ALPHABETIC CHARACTERS                  
    lex_2 = process_numeric(lex_1)
    # PASS 3 : ANOTHER PASS FOR NUMERIC CHARACTERS IN CASE OF MULTIPLE INSTANCES                   
    lex_3 = process_numeric(lex_2)         
    lex_4 = process_numeric(lex_3)   
    # APPEND ALL IN ONE LEXICON                                          
    lex_num = []
    for l in [lex_1,lex_2,lex_3,lex_4]:                   
        for item in l:
            word = item.split(' ')[0]
            grphs = item.split(' ',1)[1]
            if not any(g.isdigit() for g in grphs):
                lex_num.append(item)                   
    lex_num = list(sorted(set(lex_num)))
    # DEALING WITH RAW NUMBERS COMPLETE
    # PASS 4 : WE HAVE TO DEAL WITH ORDINALS                       
    lex_num2 = process_ordinals(lex_num)           

    # PASS 5 : MAKE 'POSITION-AWARE' (_WB) GRAPHEMES                 
    lex_wb = add_position_aware_graphemes(lex_num2)

    return lex_wb                   
            
               

def main(args):
    
    lexicon = read_lexicon(args.lexicon_path)
                       
    words_unk = get_unknown_words(args.text_path)
    lexicon_unk = create_graphemic_lexicon(words_unk)     

    # CONCATENATE lexicon AND lexicon_unk
    lexicon_extended = sorted(list(set(lexicon + lexicon_unk)))
                       
    # SAVE lexicon_extended                   
    save_lexicon(lexicon_extended,args.save_path)                   





if __name__ == '__main__':

    parser = argparse.ArgumentParser()
    parser.add_argument("lexicon_path", type=str, help="path to lexicon.txt", default ='conf/lexicon.txt')
    parser.add_argument("text_path", type=str, help='path to sample text file', default ='data/rec1/text')
    parser.add_argument("save_path", type=str, help="path to save the extended lexicon", default ='data/local/dict')

    args = parser.parse_args()
    main(args)
