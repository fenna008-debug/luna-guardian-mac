#!/usr/bin/env python3
"""Build only. Does not install, start the pet, or change permissions."""
from pathlib import Path
import subprocess,shutil,plistlib,os,zipfile
ROOT=Path(__file__).resolve().parent
assets=ROOT/'assets'
if not (assets/'spritesheet.webp').exists() and (ROOT/'assets.zip').exists():
 with zipfile.ZipFile(ROOT/'assets.zip') as z:z.extractall(ROOT)
app=Path(os.environ.get('LUNA_BUILD_DIR',str(Path.home()/'Library/Caches/LunaGuardianBuild')))/'露娜电脑管家.app';contents=app/'Contents';resources=contents/'Resources';binary=contents/'MacOS'
resources.mkdir(parents=True,exist_ok=True);binary.mkdir(exist_ok=True)
swift=['main','Bubble','Glass','Guard','Fortune','Center','Life','Scene','Notebook','Daily']
command=['nice','-n','15','swiftc']+[str(ROOT/'src'/f'{f}.swift') for f in swift]+['-o',str(binary/'LunaGuardian')]
for framework in ['AppKit','QuartzCore','ImageIO','CoreLocation','Vision','AVFoundation','PDFKit','UniformTypeIdentifiers','ScreenCaptureKit']:command+=['-framework',framework]
subprocess.run(command,check=True)
for name in ['backend.py','speech.py','synthesize_once.py','handoff.py','delegation.py','reading.py','notebook.py','web_tools.py','maintenance.py','github_watch.py','persona_luna.txt','index.html']:shutil.copy2(ROOT/'src'/name,resources/name)
for name in ['spritesheet.webp','fortunes.json']:shutil.copy2(assets/name,resources/name)
for name in ['actions','voices']:shutil.copytree(assets/name,resources/name,dirs_exist_ok=True)
info={'CFBundleDisplayName':'露娜电脑管家','CFBundleName':'露娜电脑管家','CFBundleExecutable':'LunaGuardian','CFBundleIdentifier':os.environ.get('LUNA_BUNDLE_ID','local.luna.LunaGuardian'),'CFBundlePackageType':'APPL','CFBundleShortVersionString':'1.9.1','CFBundleVersion':'19','LSMinimumSystemVersion':'14.0','LSUIElement':True,'NSHighResolutionCapable':True,'NSLocationUsageDescription':'根据城市更新天气，不记录移动轨迹。','NSLocationWhenInUseUsageDescription':'根据城市更新天气，不记录移动轨迹。','NSScreenCaptureUsageDescription':'识别当前窗口可见文字，用于生成语音陪伴。'}
(contents/'Info.plist').write_bytes(plistlib.dumps(info))
subprocess.run(['xattr','-cr',str(app)],check=True)
subprocess.run(['codesign','--force','--deep','--sign','-',str(app)],check=True)
subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
print(app)
