"""Run Luna GPT-SoVITS only for the requested fresh utterance; exit to free RAM."""
import os,sys,json
from pathlib import Path
root=(Path.home()/'Library/Application Support/LunaCompanionMac/runtime')
engine=root/'engine';os.chdir(engine)
os.environ['HF_HUB_OFFLINE']='1';os.environ['HF_HOME']=str(engine/'cache');os.environ['NUMBA_CACHE_DIR']=str(engine/'cache/numba');os.environ['MPLCONFIGDIR']=str(engine/'cache/matplotlib')
sys.path.insert(0,str(engine));sys.path.insert(0,str(engine/'gsv'))
import torch
import gsv.service as service
from gsv.text.cleaner import clean_text
from gsv.text import cleaned_text_to_sequence
service.load_bert=lambda *args:(None,None)
def japanese(self,text,language,version,final=False):
 phones,_,norm=clean_text(text,'ja',version);phones=cleaned_text_to_sequence(phones,version)
 return phones,torch.zeros((1024,len(phones)),device=self.device),norm
service.TextFrontend.get_phones_and_bert=japanese
torch.set_num_threads(1);torch.manual_seed(42)
request=json.load(sys.stdin);text=request['ja'];output=Path(request['output'])
assert 1<=len(text)<=100
svc=service.TTSService('cpu',False,str(engine/'gsv/pretrained_models/chinese-hubert-base'),'',str(engine/'gsv/weights/xxx-gpt-e50.ckpt'),str(engine/'gsv/weights/xxx_sovits_e24_s456.pth'))
sr,wav=svc.synth(str(engine/'gsv/extracted_ogg/v_lun0022.ogg'),'ただまあ、正直に言ってしまえば、私の身の回りの世話を最低限できそうな人なら誰でも良かったんだ。','all_ja',text,'all_ja',speed=1.0)
import soundfile as sf,numpy as np
assert 0.5<len(wav)/sr<24 and np.isfinite(wav).all() and np.max(np.abs(wav))>0.01
output.parent.mkdir(parents=True,exist_ok=True)
tmp=output.with_suffix('.part.wav');sf.write(tmp,wav,sr);tmp.replace(output)
print(json.dumps({'ok':True,'duration':len(wav)/sr,'output':str(output)}))
