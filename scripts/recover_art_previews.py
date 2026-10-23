"""Recover already-rendered v40 screenshots for review while the touch fix builds."""
import io,os,subprocess,urllib.request,zipfile
from pathlib import Path
repo=os.environ['GITHUB_REPOSITORY'];token=os.environ['GH_TOKEN']
class DownloadRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,request,fp,code,message,headers,newurl):
        redirected=super().redirect_request(request,fp,code,message,headers,newurl)
        if redirected:redirected.remove_header('Authorization')
        return redirected
request=urllib.request.Request('https://api.github.com/repos/'+repo+'/actions/artifacts/12523202263/zip',headers={'Authorization':'Bearer '+token,'Accept':'application/vnd.github+json'})
with urllib.request.build_opener(DownloadRedirect()).open(request,timeout=120) as response:data=response.read()
with zipfile.ZipFile(io.BytesIO(data)) as archive:
    for name in archive.namelist():
        file=Path(name).name
        if file.startswith('LittleHaven-response-painted-') or file in ['LittleHaven-app-icon.png','LittleHaven-character-turns.png']:
            Path(file).write_bytes(archive.read(name))
env=dict(os.environ,GITHUB_SHA='aedb814619a894574eb0ed32f579598e8e1ecf21')
subprocess.run(['python3','scripts/publish_art_previews.py'],env=env,check=True)
