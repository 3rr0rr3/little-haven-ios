"""Pack generated artwork into deterministic game atlases; no semantic redraws.

Input: retained prompts/source sheets, or --source-list JSON. Uses Pillow/numpy only for
alpha cleanup, atlas slicing, fixed scale/baseline alignment and catalog output.
Generated originals and exact prompts are retained outside the app resources.
"""
from pathlib import Path
import json, shutil, hashlib, sys
import numpy as np
from PIL import Image, ImageFilter, ImageChops, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
CATALOG=ROOT/'LittleHaven/Assets.xcassets/Painted'
ORIGINALS=ROOT/'ArtSources/CartoonV46'
source_list=Path(sys.argv[sys.argv.index('--source-list')+1]) if '--source-list' in sys.argv else None
if source_list is not None:
    SOURCES=json.loads(source_list.read_text(encoding='utf-8'))
else:
    SOURCES=json.loads((ORIGINALS/'prompts.json').read_text(encoding='utf-8'))
    for source in SOURCES:source['path']=str(ORIGINALS/source['file'])
CATALOG.mkdir(parents=True,exist_ok=True);ORIGINALS.mkdir(parents=True,exist_ok=True)
(CATALOG/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}}),encoding='utf-8')
legacy=json.loads((ROOT/'ArtSources/CelV41/manifest.json').read_text())
legacy_actors=[a for a in legacy['assets'] if a['size']==[576,896]]
assert len(legacy_actors)==27
manifest={'version':46,'cell':[192,224],'directions':['front','left','right','back'],'frames':['idle','leftStep','rightStep'],'assets':legacy_actors.copy(),'sources':[],'legacy_actor_assets_not_rendered':True}

def save_asset(name,image):
    folder=CATALOG/(name+'.imageset');folder.mkdir(exist_ok=True)
    file=folder/(name+'.png');image.save(file,optimize=True)
    (folder/'Contents.json').write_text(json.dumps({'images':[{'filename':file.name,'idiom':'universal'}],'info':{'author':'xcode','version':1}}),encoding='utf-8')
    manifest['assets'].append({'name':name,'path':str(file.relative_to(ROOT)).replace('\\','/'),'size':list(image.size),'sha256':hashlib.sha256(file.read_bytes()).hexdigest()})

def clean_alpha(image):
    alpha=image.getchannel('A')
    solid=alpha.point(lambda a:255 if a>56 else 0).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(5))
    result=image.copy();result.putalpha(ImageChops.multiply(alpha,solid));return result

def components(image):
    """Row-run connected components, to separate the slightly uneven prop sheets."""
    mask=np.asarray(image.getchannel('A'))>64
    parent=[];runs=[];previous=[]
    def find(i):
        while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
        return i
    for y,row in enumerate(mask):
        edges=np.flatnonzero(np.diff(np.r_[False,row,False]));current=[];j=0
        for start,end in zip(edges[::2],edges[1::2]):
            start=int(start);end=int(end);label=len(parent);parent.append(label)
            while j<len(previous) and previous[j][1]<start-1:j+=1
            k=j
            while k<len(previous) and previous[k][0]<=end:
                a=find(label);b=find(previous[k][2]);parent[a]=b;k+=1
            current.append((start,end,label));runs.append((y,start,end,label))
        previous=current
    groups={}
    for y,x0,x1,label in runs:
        root=find(label);g=groups.setdefault(root,{'area':0,'box':[x0,y,x1,y+1],'runs':[]})
        g['area']+=x1-x0;g['box']=[min(g['box'][0],x0),min(g['box'][1],y),max(g['box'][2],x1),max(g['box'][3],y+1)];g['runs'].append((y,x0,x1))
    return sorted([g for g in groups.values() if g['area']>500],key=lambda g:g['area'],reverse=True)

materials=['stone-a','stone-b','stone-c','stone-d','grass','sand','water','earth','oak','walnut','plaster','roof','road','moss','straw','timber']
props=['fence-h','fence-v','post','nameplate','lantern','water-bowl','feed-bowl','bedding','fern','wildflowers','tree','palm','stairs','banner','spellbook','dumbbell']
furniture=['sofa-front','sofa-back','desk','bed','nightstand','vending','washer','linen','dining-table','bar-counter','bookshelf','workbench','stove','rug','lounger','door']
fixtures=['tv-frame','save-journal','tool-rack','paint-supplies','coffee-set','bath-sink','toilet','travel-chest','trash-bin','mop-bucket','suitcase','small-lamp','glazed-window','breakfast-counter','coffee-table','tv-console']
equipment=['watch','camera','extinguisher','clothes-rack','fish-display','folded-clothes']
facades=['house-warm','house-blue','house-green','store-furniture','store-clothing','store-pawn','store-bar','store-fish','office-facade','motel-facade','laundry-shelter','park-bench']
contact=Image.new('RGB',(1200,1200),(56,64,53));pen=ImageDraw.Draw(contact);preview_index=0
for source in SOURCES:
    original=Path(source['path']);name=source.get('asset_name',source['name'].replace('-fixed','').replace('-painted',''))
    target=ORIGINALS/(source['name']+'.png')
    if original.resolve()!=target.resolve():shutil.copy2(original,target)
    source_record={k:v for k,v in source.items() if k!='path'};source_record['file']=source['name']+'.png';manifest['sources'].append(source_record)
    image=Image.open(original).convert('RGBA');w,h=image.size
    if source['kind']=='materials':
        for i,label in enumerate(materials):
            # Source sheets can contain a thin divider between material cells.
            # Exclude that atlas border when slicing; it must not become a
            # repeated black grid through sand, grass or water in the game.
            tile=image.crop((round(i%4*w/4)+2,round(i//4*h/4)+2,round((i%4+1)*w/4)-2,round((i//4+1)*h/4)-2)).resize((256,256),Image.Resampling.LANCZOS)
            save_asset('bh-'+label,tile)
    elif source['kind'] in ['props','furniture','fixtures','equipment','facades']:
        labels=props if source['kind']=='props' else fixtures if source['kind']=='fixtures' else equipment if source['kind']=='equipment' else facades if source['kind']=='facades' else furniture
        columns,rows=(3,2) if source['kind']=='equipment' else (4,3) if source['kind']=='facades' else (4,4)
        groups=components(clean_alpha(image));assert len(groups)>=len(labels),(name,len(groups))
        chosen=[]
        for i,label in enumerate(labels):
            cx=(i%columns+.5)*w/columns;cy=(i//columns+.5)*h/rows
            candidates=[g for g in groups if id(g) not in chosen and abs((g['box'][0]+g['box'][2])/2-cx)<w/(columns+1) and abs((g['box'][1]+g['box'][3])/2-cy)<h/(rows+1)]
            assert candidates,(name,label)
            g=min(candidates,key=lambda g:(((g['box'][0]+g['box'][2])/2-cx)/w)**2+(((g['box'][1]+g['box'][3])/2-cy)/h)**2)
            chosen.append(id(g));mask=Image.new('L',(w,h));draw=ImageDraw.Draw(mask)
            for y,x0,x1 in g['runs']:draw.line((x0,y,x1-1,y),fill=255)
            mask=mask.filter(ImageFilter.MaxFilter(5));isolated=image.copy();isolated.putalpha(ImageChops.multiply(image.getchannel('A'),mask))
            box=isolated.getbbox();assert box;isolated=isolated.crop(box);isolated.thumbnail((320,320),Image.Resampling.LANCZOS)
            save_asset('bh-'+label,isolated)
    else:
        cells=[];bounds=[]
        groups=components(clean_alpha(image));used=set()
        for row in range(4):
            for col in range(3):
                if name=='guest-d-beach' and source['name']=='guest-d-beach':
                    source_row=3-row if row in [1,2] else row
                    cell=clean_alpha(image.crop((round(col*w/3),round(source_row*h/4),round((col+1)*w/3),round((source_row+1)*h/4))))
                    g=components(cell)[0];mask=Image.new('L',cell.size);draw=ImageDraw.Draw(mask)
                    for yy,x0,x1 in g['runs']:draw.line((x0,yy,x1-1,yy),fill=255)
                    cell.putalpha(ImageChops.multiply(cell.getchannel('A'),mask.filter(ImageFilter.MaxFilter(5))))
                    box=cell.getbbox();cells.append(cell.crop(box));bounds.append(list(box));continue
                cx=(col+.5)*w/3;cy=(row+.5)*h/4
                candidates=[g for g in groups if id(g) not in used and abs((g['box'][0]+g['box'][2])/2-cx)<w/5 and abs((g['box'][1]+g['box'][3])/2-cy)<h/6]
                assert candidates,(name,row,col)
                g=max(candidates,key=lambda g:g['area']);used.add(id(g))
                mask=Image.new('L',(w,h));draw=ImageDraw.Draw(mask)
                for yy,x0,x1 in g['runs']:draw.line((x0,yy,x1-1,yy),fill=255)
                mask=mask.filter(ImageFilter.MaxFilter(5));cell=image.copy();cell.putalpha(ImageChops.multiply(image.getchannel('A'),mask))
                box=cell.getbbox();assert box
                cells.append(cell.crop(box));bounds.append(list(box))
        factor=min(176/max(c.width for c in cells),208/max(c.height for c in cells))
        if name=='samhil':factor*=.88
        sheet=Image.new('RGBA',(192*3,224*4))
        for index,cell in enumerate(cells):
            cell=cell.resize((max(1,round(cell.width*factor)),max(1,round(cell.height*factor))),Image.Resampling.LANCZOS)
            row,col=divmod(index,3);sheet.alpha_composite(cell,(col*192+(192-cell.width)//2,row*224+218-cell.height))
        save_asset('bh-'+name,sheet)
        manifest['assets'][-1]['source_bounds']=bounds
        # Masks only select pale fabric; hair, skin, eyes and markings are preserved.
        if name in ['player','guest-a','guest-b','guest-c','guest-d']:
            array=np.asarray(sheet);red=array[:,:,0].astype(float);green=array[:,:,1].astype(float);blue=array[:,:,2].astype(float)
            yy=np.indices(red.shape)[0]%224
            fabric=(yy>(140 if name=='player' else 126))&(yy<201)&(red>105)&(green>95)&(blue>65)&((red-blue)<65)&(abs(red-green)<30)&(abs(green-blue)<40)
            # Keep the mask inside the central outfit; hands remain skin colored.
            xx=np.indices(red.shape)[1]%192;fabric &= (xx>52)&(xx<142)
            mask=Image.fromarray(np.where(fabric,array[:,:,3],0).astype('uint8'),'L').filter(ImageFilter.GaussianBlur(1))
            masked=Image.new('RGBA',sheet.size,(255,255,255,0));masked.putalpha(mask);save_asset('bh-'+name+'-cloth',masked)
        sample=sheet.crop((0,0,192,224));sample.thumbnail((95,110))
        x=(preview_index%12)*100;y=(preview_index//12)*145;contact.paste(sample,(x+(95-sample.width)//2,y),sample);pen.text((x,y+112),name[:16],fill=(243,225,180));preview_index+=1

(ORIGINALS/'prompts.json').write_text(json.dumps(manifest['sources'],indent=2),encoding='utf-8')
(ORIGINALS/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
contact.crop((0,0,1200,max(145,((preview_index+11)//12)*145))).save(ORIGINALS/'actor-contact-sheet.png')
print(json.dumps({'assets':len(manifest['assets']),'sources':len(SOURCES),'packed_bytes':sum((ROOT/a['path']).stat().st_size for a in manifest['assets'])}))
