"""Download only free Standard/CC0 assets through publishers' public links."""
from pathlib import Path
import requests, json, hashlib, zipfile, concurrent.futures
from bs4 import BeautifulSoup

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '.work' / 'assets'
OUT.mkdir(parents=True, exist_ok=True)

def get_quaternius(slug, name):
    target = OUT / (name + '.zip')
    if target.exists(): return str(target)
    sess = requests.Session()
    base = 'https://quaternius.itch.io/' + slug
    page = sess.get(base+'/purchase', timeout=60)
    soup = BeautifulSoup(page.text, 'html.parser')
    csrf = soup.find('meta', {'name':'csrf_token'})['value']
    r = sess.post(base+'/download_url',data={'csrf_token':csrf},headers={'Referer':base+'/purchase'},timeout=60)
    dl = sess.get(r.json()['url'], timeout=60)
    soup = BeautifulSoup(dl.text, 'html.parser')
    csrf = soup.find('meta', {'name':'csrf_token'})['value']
    btn = soup.select_one('.download_btn[data-upload_id]')
    r = sess.post(base+'/file/'+btn['data-upload_id'],data={'csrf_token':csrf},headers={'Referer':dl.url},timeout=60)
    data = r.json()
    if 'url' not in data: raise RuntimeError(str(data))
    with sess.get(data['url'], stream=True, timeout=180) as stream:
        stream.raise_for_status()
        with target.open('wb') as f:
            for chunk in stream.iter_content(1024*1024): f.write(chunk)
    return str(target)

def furniture():
    target = OUT/'furniture.zip'
    if target.exists(): return str(target)
    page=requests.get('https://kenney.nl/assets/furniture-kit',timeout=60)
    soup=BeautifulSoup(page.text,'html.parser')
    link=soup.select_one('#donate-text')['href']
    target.write_bytes(requests.get(link,timeout=180).content)
    return str(target)

if __name__=='__main__':
    jobs=[('universal-base-characters','base'),('modular-character-outfits-fantasy','outfits'),('universal-animation-library','animations'),('universal-animation-library-2','animations2')]
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        tasks=[pool.submit(get_quaternius,*j) for j in jobs]+[pool.submit(furniture)]
        for task in concurrent.futures.as_completed(tasks):
            try:
                p=Path(task.result())
                with zipfile.ZipFile(p) as z:
                    z.extractall(OUT/p.stem)
                    names=z.namelist()
                print(p.name,p.stat().st_size,'files',len(names),flush=True)
            except Exception as exc: print('ERROR',repr(exc),flush=True)
