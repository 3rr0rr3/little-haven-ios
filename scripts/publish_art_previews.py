"""Publish native visual review evidence, never an untested IPA."""
import base64,hashlib,json,os,subprocess,urllib.request,urllib.error
from pathlib import Path
repo=os.environ['GITHUB_REPOSITORY'];source=os.environ['GITHUB_SHA'];token=os.environ['GH_TOKEN']
def api(path,data=None):
    request=urllib.request.Request('https://api.github.com/repos/'+repo+path,None if data is None else json.dumps(data).encode(),headers={'Authorization':'Bearer '+token,'Accept':'application/vnd.github+json','Content-Type':'application/json'})
    with urllib.request.urlopen(request,timeout=90) as response:return json.load(response)
branch='codex/art-preview-'+('prior-' if os.environ.get('ART_SOURCE_SHA') else '')+source[:8]
try:
    existing=api('/git/ref/heads/'+branch)
    commit=api('/git/commits/'+existing['object']['sha'])
    assert commit['parents'][0]['sha']==source
    print(json.dumps({'source':source,'preview_commit':commit['sha'],'branch':branch,'reused':True}))
    raise SystemExit(0)
except urllib.error.HTTPError as error:
    if error.code!=404:raise
entries=[]
images=list(Path('.').glob('LittleHaven-npc-gallery.png'))+list(Path('.').glob('LittleHaven-response-painted-*.png'))+list(Path('.').glob('LittleHaven-character-turns.png'))+list(Path('.').glob('LittleHaven-app-icon.png'))+list(Path('/tmp/art-ui-diagnostics').rglob('*.png'))
priority=[Path('LittleHaven-response-painted-'+mode+'.png') for mode in ['needs-animation-eat','needs-animation-toilet','needs-animation-shower','needs-dirty','needs-bathroom','needs-panel','needs-npc','night-sky','neglect','seasonal','menu-emergency']]
images=[p for p in priority if p.exists()]+[p for p in images if p not in priority]
for index,image in enumerate(images[:30]):
    target=Path('/tmp')/('art-review-'+str(index)+'.jpg')
    subprocess.run(['sips','-s','format','jpeg','-s','formatOptions','90','-Z','1100',str(image),'--out',str(target)],check=True,stdout=subprocess.DEVNULL)
    data=target.read_bytes();blob=api('/git/blobs',{'content':base64.b64encode(data).decode(),'encoding':'base64'})
    assert blob['sha']==hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
    name=image.stem+'.jpg' if image.name.startswith('LittleHaven') else 'diagnostic-'+str(index)+'.jpg'
    entries.append({'path':'previews/art-review/'+name,'mode':'100644','type':'blob','sha':blob['sha']})
assert entries,'No native screenshots to review'
for motion in sorted(Path('.').glob('LittleHaven-*-motion.mp4')):
    data=motion.read_bytes()
    result=api('/git/blobs',{'content':base64.b64encode(data).decode(),'encoding':'base64'})
    assert result['sha']==hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
    entries.append({'path':'previews/art-review/'+motion.name,'mode':'100644','type':'blob','sha':result['sha']})

tree=api('/git/trees',{'base_tree':api('/git/commits/'+source)['tree']['sha'],'tree':entries})
commit=api('/git/commits',{'message':'Native painted art review evidence [skip ci]','tree':tree['sha'],'parents':[source]})
print(json.dumps({'source':source,'captured_source':os.environ.get('ART_SOURCE_SHA',source),'preview_commit':commit['sha'],'branch':branch,'images':len(entries)}),flush=True)
api('/git/refs',{'ref':'refs/heads/'+branch,'sha':commit['sha']})
print(json.dumps({'source':source,'preview_commit':commit['sha'],'branch':branch,'images':len(entries)}))
