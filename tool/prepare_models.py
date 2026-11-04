import json, hashlib, os
from pathlib import Path
os.environ['HF_HUB_DISABLE_XET']='1'
os.environ['USE_TF']='0'
os.environ['HF_HOME']=str(Path(__file__).resolve().parents[1]/'.tools/huggingface')
import torch, numpy as np, onnx, onnxruntime as ort
from transformers import CLIPModel, CLIPProcessor
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'assets/models'
MODEL='wkcn/TinyCLIP-ViT-8M-16-Text-3M-YFCC15M'; REV='a2a8c6eaa2549ad66eb7c31b85022bf58273a26c'
PROMPTS={
'Selfie':['a selfie taken with a phone camera','a close up selfie of a person'],
'People':['a photograph of people together','a portrait photograph of a person','a family photograph'],
'Food':['a photograph of food on a plate','a photograph of a cup of coffee','a photograph of a meal'],
'Pet':['a photograph of a pet dog','a photograph of a pet cat','a photograph of a domestic animal'],
'Travel':['a travel photograph of a city street','a photograph of a famous landmark or building','a photograph taken on a vacation in a city'],
'Nature':['a photograph of a mountain landscape','a photograph of a forest','a photograph of the sea or a lake','a photograph of flowers'],
'Document':['a photograph of a printed document with text','a photograph of handwritten notes on paper','a scanned page of a document'],
'Receipt':['a photograph of a shopping receipt','a photograph of a restaurant receipt','a photograph of a printed bill'],
'Meme':['an internet meme with text and an image','a funny meme or cartoon with a caption'],
'Product':['a product photograph on a plain background','a photograph of a consumer product for sale','a product listing photograph']}
prompt_file=OUT/'category_prompts.json'
if prompt_file.exists(): PROMPTS=json.loads(prompt_file.read_text(encoding='utf-8'))
else: prompt_file.write_text(json.dumps(PROMPTS,indent=2),encoding='utf-8')
print('Loading pinned TinyCLIP checkpoint',flush=True)
model=CLIPModel.from_pretrained(MODEL,revision=REV).eval()
processor=CLIPProcessor.from_pretrained(MODEL,revision=REV)
class Encoder(torch.nn.Module):
 def __init__(self,model): super().__init__(); self.model=model
 def forward(self,pixel_values): return self.model.get_image_features(pixel_values=pixel_values)
path=OUT/'tinyclip-image.onnx'
if not path.exists():
 with torch.no_grad():
  torch.onnx.export(Encoder(model),torch.zeros(1,3,224,224),str(path),opset_version=17,
   input_names=['pixel_values'],output_names=['image_embeds'],dynamo=False,external_data=False)
 onnx.checker.check_model(str(path))
print('Image encoder exported',flush=True)
with torch.no_grad():
 vectors={}
 for label,texts in PROMPTS.items():
  inp=processor(text=texts,return_tensors='pt',padding=True,truncation=True)
  e=model.get_text_features(input_ids=inp['input_ids'],attention_mask=inp['attention_mask'])
  e=e/e.norm(dim=-1,keepdim=True);mean=e.mean(0);mean=mean/mean.norm()
  vectors[label]=mean.tolist()
(OUT/'categories.json').write_text(json.dumps({'model':'tinyclip-vit8m-v1','revision':REV,'prompts':PROMPTS,'vectors':vectors}),encoding='utf-8')
session=ort.InferenceSession(str(path),providers=['CPUExecutionProvider'])
checks=[]
for p in sorted((ROOT/'assets/demo').glob('*.jpg')):
 image=Image.open(p).convert('RGB');x=processor(images=image,return_tensors='pt')['pixel_values']
 with torch.no_grad(): ref=model.get_image_features(pixel_values=x).numpy()[0]
 actual=session.run(None,{'pixel_values':x.numpy()})[0][0]
 cosine=float(np.dot(ref,actual)/(np.linalg.norm(ref)*np.linalg.norm(actual)))
 assert cosine>0.9999,(p.name,cosine)
 unit=actual/np.linalg.norm(actual);scores={k:float(np.dot(unit,v)) for k,v in vectors.items()}
 checks.append({'image':p.name,'torch_onnx_cosine':cosine,'category':max(scores,key=scores.get),'scores':scores})
print(json.dumps(checks,indent=2),flush=True)
for name in ['yunet.onnx','sface.onnx']:
 m=onnx.load(str(OUT/name));print(name, 'preparing graph metadata',flush=True)
 if name=='yunet.onnx':
  # Fully convolutional upstream YuNet: export fixed 320x320 metadata for ORT.
  m.graph.input[0].type.tensor_type.shape.dim[2].dim_value=320
  m.graph.input[0].type.tensor_type.shape.dim[3].dim_value=320
  for v in m.graph.output:
   for d in v.type.tensor_type.shape.dim: d.ClearField('dim_value')
  del m.graph.value_info[:]
  m=onnx.shape_inference.infer_shapes(m)
 initializers={v.name for v in m.graph.initializer}
 inputs=[v for v in m.graph.input if v.name not in initializers]
 del m.graph.input[:];m.graph.input.extend(inputs)
 onnx.save(m,str(OUT/name))
report={'tinyclip':checks,'artifacts':{p.name:{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in OUT.glob('*.onnx')}}
(ROOT/'docs/model-validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('Validated and recorded hashes.',flush=True)
