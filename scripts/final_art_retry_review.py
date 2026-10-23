"""Validate the sole simulator lifecycle retry, review real test images, publish the unchanged tested IPA."""
import base64,hashlib,io,json,os,plistlib,re,subprocess,time,urllib.request,zipfile
from pathlib import Path
from PIL import Image,ImageDraw
repo=os.environ['GITHUB_REPOSITORY'];token=os.environ['GH_TOKEN'];head=os.environ['GITHUB_SHA']
source='9e007d52cdcb16aeb9f5489a41929b62a1339e18';run=40014871888;test='testCreativeEditorOpensAndMovesWasher'
class Redirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,request,fp,code,message,headers,newurl):
        result=super().redirect_request(request,fp,code,message,headers,newurl)
        if result:result.remove_header('Authorization')
        return result
def request_bytes(url):
    request=urllib.request.Request(url,headers={'Authorization':'Bearer '+token,'Accept':'application/vnd.github+json'})
    with urllib.request.build_opener(Redirect()).open(request,timeout=180) as response:return response.read()
def api(path,data=None):
    request=urllib.request.Request('https://api.github.com/repos/'+repo+path,None if data is None else json.dumps(data).encode(),headers={'Authorization':'Bearer '+token,'Accept':'application/vnd.github+json','Content-Type':'application/json'})
    with urllib.request.urlopen(request,timeout=180) as response:return json.load(response)
log=request_bytes('https://api.github.com/repos/'+repo+'/actions/jobs/120624239055/logs').decode('utf-8')
errors=[line for line in log.splitlines() if '.swift:' in line and 'error:' in line]
assert len(errors)==1 and test in errors[0] and 'Failed to terminate' in errors[0],errors
passed=set(re.findall(r"Test Case '-\[LittleHavenUITests\.LittleHavenUITests (\w+)\]' passed",log))
assert len(passed)==52 and test not in passed
retry=Path('art-retry.log').read_text()
retry_passed=test+"]' passed" in retry and re.search(r'Executed 1 tests?, with 0 failures',retry) is not None and '** TEST SUCCEEDED **' in retry
artifacts=api('/actions/runs/'+str(run)+'/artifacts')['artifacts']
def artifact_zip(name):
    item=next(a for a in artifacts if a['name']==name)
    assert item['workflow_run']['head_sha']==source and not item['expired']
    data=request_bytes(item['archive_download_url'])
    if item.get('digest'):assert hashlib.sha256(data).hexdigest()==item['digest'].split(':')[-1]
    return zipfile.ZipFile(io.BytesIO(data))
root=Path('native-test-art');root.mkdir(exist_ok=True)
with artifact_zip('Simulator-test-results') as archive:
    for name in archive.namelist():assert (root/name).resolve().is_relative_to(root.resolve())
    archive.extractall(root)
export=Path('exported-test-art');export.mkdir(exist_ok=True)
for label,result in [('retry',Path('RetryResults.xcresult')),('original',next(root.rglob('TestResults.xcresult')))]:
    if result.exists():subprocess.run(['xcrun','xcresulttool','export','attachments','--path',str(result),'--output-path',str(export/label)],check=True)
entries=[];records=[];rejected=[];images=[]
def blob(path,content):
    value=api('/git/blobs',{'content':base64.b64encode(content).decode(),'encoding':'base64'})
    assert value['sha']==hashlib.sha1(b'blob '+str(len(content)).encode()+b'\0'+content).hexdigest()
    entries.append({'path':path,'mode':'100644','type':'blob','sha':value['sha']})
files=sorted((export/'retry').rglob('*.png'))+sorted((export/'original').rglob('*.png'))
for file in files[:120]:
    image=Image.open(file).convert('RGB');sample=image.resize((64,64));white=sum(1 for pixel in sample.getdata() if min(pixel)>245)/4096
    if white>0.9:rejected.append(file.relative_to(export).as_posix());continue
    image.thumbnail((1100,1100));content=io.BytesIO();image.save(content,format='JPEG',quality=90)
    index=len(records);name=f'frame-{index:03d}.jpg';blob('previews/ui-attachments/'+name,content.getvalue())
    records.append({'index':index,'file':file.relative_to(export).as_posix(),'preview':name});images.append(image.copy())
assert records
for offset in range(0,len(images),16):
    sheet=Image.new('RGB',(1000,2320),(30,43,37));draw=ImageDraw.Draw(sheet)
    for index,image in enumerate(images[offset:offset+16]):
        thumb=image.copy();thumb.thumbnail((245,550));x=index%4*250;y=index//4*580
        sheet.paste(thumb,(x+(250-thumb.width)//2,y+22));draw.text((x+8,y+4),str(offset+index),fill='white')
    content=io.BytesIO();sheet.save(content,format='JPEG',quality=84);blob(f'previews/ui-attachments/contact-{offset//16:02d}.jpg',content.getvalue())
manifests={file.relative_to(export).as_posix():json.loads(file.read_text()) for file in export.rglob('*.json')}
blob('previews/ui-attachments/index.json',json.dumps({'captured_source':source,'run':run,'retry_run':os.environ['GITHUB_RUN_ID'],'retry_passed':bool(retry_passed),'screenshots':records,'rejected_blank_captures':rejected,'export_manifests':manifests},indent=2).encode())
verification=None
if retry_passed:
    with artifact_zip('LittleHaven-iPhone-IPA') as archive:
        ipa=archive.read(next(name for name in archive.namelist() if name.endswith('.ipa')))
        checksum=archive.read(next(name for name in archive.namelist() if name.endswith('.sha256'))).decode()
    digest=hashlib.sha256(ipa).hexdigest();assert digest in checksum
    with zipfile.ZipFile(io.BytesIO(ipa)) as archive:
        assert archive.testzip() is None
        info=plistlib.loads(archive.read('Payload/LittleHaven.app/Info.plist'))
        binary=Path('verified-device-binary');binary.write_bytes(archive.read('Payload/LittleHaven.app/LittleHaven'))
    assert info['CFBundleDisplayName']=='Brainstorm Haven' and info['CFBundleShortVersionString']=='40.0' and info['CFBundleVersion']=='45' and info['CFBundleSupportedPlatforms']==['iPhoneOS']
    subprocess.run(['xcrun','lipo',str(binary),'-verify_arch','arm64'],check=True)
    platform=subprocess.check_output(['xcrun','vtool','-show-build',str(binary)],text=True);assert re.search(r'platform\s+IOS\b',platform)
    verification={'source':source,'tooling_commit':head,'version':'40.0','build':'45','size':len(ipa),'sha256':digest,'primary_run':run,'primary_ui_passed':52,'retried_test':test,'retry_run':os.environ['GITHUB_RUN_ID'],'retry_passed':1,'unique_ui_tests_passed':53,'zip_verified':True,'platform':'iPhoneOS','architecture':'arm64'}
    blob('downloads/BrainstormHaven-40.ipa',ipa);blob('downloads/BrainstormHaven-40-verification.json',json.dumps(verification,indent=2).encode())
tree=api('/git/trees',{'base_tree':api('/git/commits/'+head)['tree']['sha'],'tree':entries})
commit=api('/git/commits',{'message':'Verified native art and simulator lifecycle retry [skip ci]','tree':tree['sha'],'parents':[head]})
print(json.dumps({'captured_source':source,'review_commit':commit['sha'],'screenshots':len(records),'retry_passed':bool(retry_passed)}),flush=True)
api('/git/refs',{'ref':'refs/heads/codex/art-attachments-9e007d52','sha':commit['sha']})
if verification:
    api('/git/refs',{'ref':'refs/heads/codex/download-v40-9e007d52','sha':commit['sha']})
    url='https://raw.githubusercontent.com/'+repo+'/'+commit['sha']+'/downloads/BrainstormHaven-40.ipa'
    with urllib.request.urlopen(url,timeout=180) as response:downloaded=response.read();assert response.status==200
    assert len(downloaded)==verification['size'] and hashlib.sha256(downloaded).hexdigest()==verification['sha256']
    verification.update(binary_commit=commit['sha'],url=url,public_http_status=200)
    Path('candidate-verification.json').write_text(json.dumps(verification,indent=2));print(json.dumps(verification),flush=True)
