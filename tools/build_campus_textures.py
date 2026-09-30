"""Fetch six exact 1K CC0 Poly Haven maps; retain provenance and hashes."""
from pathlib import Path
from urllib.request import Request, urlopen
import hashlib, json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Assets/Textures'
OUT.mkdir(parents=True, exist_ok=True)
records = []
for slug, author in [('concrete_floor', 'eye-candy.xyz'), ('painted_plaster_wall', 'Amal Kumar')]:
    for dest, channel in [('diff', 'diff'), ('normal', 'nor_gl'), ('rough', 'rough')]:
        url = f'https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/{slug}/{slug}_{channel}_1k.jpg'
        path = OUT / f'{slug}_{dest}.jpg'
        request = Request(url, headers={'User-Agent': 'CampusGameAssetBuild/1.0 (individual asset download)'})
        data = urlopen(request, timeout=90).read()
        if not data.startswith(b'\xff\xd8'):
            raise ValueError(f'Not a JPEG: {url}')
        path.write_bytes(data)
        records.append({'path': path.relative_to(ROOT).as_posix(), 'author': author, 'source': f'https://polyhaven.com/a/{slug}', 'download_url': url, 'license': 'CC0-1.0', 'license_url': 'https://polyhaven.com/license', 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data), 'resolution': '1K', 'channel': channel})
        print(path.name, len(data), flush=True)
(OUT / 'texture_receipt.json').write_text(json.dumps({'download_date': '2026-10-01', 'assets': records}, indent=2), encoding='utf8')
license_path = ROOT / 'Assets/Licenses/polyhaven_cc0.txt'
license_path.write_text('Poly Haven textures: Concrete Floor by eye-candy.xyz and Painted Plaster Wall by Amal Kumar.\nLicense: CC0 1.0 Universal\nhttps://creativecommons.org/publicdomain/zero/1.0/\nhttps://polyhaven.com/license\nVerified 2026-10-01: all Poly Haven assets are CC0; use, modification, commercial use, and redistribution are permitted; attribution is not required. Website preview images and other website content are not included.\nExact source/download URLs and SHA-256 values: Assets/Textures/texture_receipt.json\n', encoding='utf8')
