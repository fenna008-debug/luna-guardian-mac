"""Bounded local filename lookup, never follows links or opens file contents."""
import os,re,time,subprocess
from pathlib import Path

def find_files(query,roots=None,limit=12):
    if roots is None:
        terms=[x.casefold() for x in query.split() if x]
        if not terms:return [],False
        hits=[];partial=False
        for name in ('Downloads','Desktop','Documents'):
            root=Path.home()/name
            try:
                result=subprocess.run(['/usr/bin/mdfind','-onlyin',str(root),'-name',query],capture_output=True,text=True,timeout=2)
            except (OSError,subprocess.TimeoutExpired):partial=True;continue
            if result.returncode:partial=True;continue
            candidates=result.stdout.splitlines()
            try:
                direct=subprocess.run(['/bin/ls','-1',str(root)],capture_output=True,text=True,timeout=2)
                if direct.returncode==0:candidates.extend(str(root/n) for n in direct.stdout.splitlines())
                else:partial=True
            except (OSError,subprocess.TimeoutExpired):partial=True
            for value in candidates:
                path=Path(value)
                try:relative=path.relative_to(root)
                except ValueError:continue
                if any(p.startswith('.') or p in ('node_modules','venv','Codex','__pycache__') for p in relative.parts):continue
                if all(t in path.name.casefold() for t in terms) and value not in hits:hits.append(value)
                if len(hits)>=limit:return hits,True
        return hits,partial
    terms=[x.casefold() for x in query.split() if x]
    if not terms:return [],False
    hits=[];seen=0;deadline=time.monotonic()+4;partial=False
    for root in roots:
        if not root.is_dir():continue
        for folder,dirs,files in os.walk(root,followlinks=False):
            dirs[:]=[d for d in dirs if not d.startswith('.') and d not in ('node_modules','venv','__pycache__','Codex') and not d.endswith(('.app','.photoslibrary'))]
            for name in files:
                seen+=1
                if all(t in name.casefold() for t in terms):hits.append(str(Path(folder)/name))
                if len(hits)>=limit or seen>=30000 or time.monotonic()>deadline:
                    return hits,True
    return hits,partial

def handle(message,base,runner):
    m=message.strip().rstrip('。！!？?')
    match=re.fullmatch(r'(?:请|帮我|替我)?(?:找找文件|找文件|查找文件|搜索文件)[：:，, ]*(.*)',m)
    if not match:match=re.fullmatch(r'(?:请|帮我|替我)?(?:找找|找一下|查找|寻找)(.+?)文件',m)
    if match:
        query=match[1].strip(' “”“\"')
        if not query:return '告诉我文件名里有什么字，例如“找文件：课表”。我会查桌面、文稿和下载。'
        if len(query)>100:return '文件名关键词太长了，请给我一两个关键词。'
        hits,partial=find_files(query)
        if not hits:return '在桌面、文稿和下载的已索引文件中，没有找到文件名包含“'+query+'”的文件。未被系统索引的文件可能查不到，可以换一个关键词。'
        return '找到这些文件或文件夹（只查名称，尚未打开）：\n'+'\n'.join(hits)+('\n结果或查找范围已截断，可以加关键词缩小范围。' if partial else '')
    commands={'播放音乐':'play','放首歌':'play','放点音乐':'play','听歌':'play','播放网易云音乐':'play','继续播放音乐':'play','继续播放':'play','暂停音乐':'pause','暂停播放':'pause','下一首':'next','上一首':'previous'}
    command=re.sub(r'^(?:请|帮我|替我)','',m)
    if command in commands:
        from app_actions import music
        return music(base,commands[command])
    return None
