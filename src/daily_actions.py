"""Bounded local filename lookup, never follows links or opens file contents."""
import os,re,time
from pathlib import Path

def find_files(query,roots=None,limit=12):
    roots=roots or [Path.home()/n for n in ('Desktop','Documents','Downloads')]
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
        if not hits:return '在桌面、文稿和下载的本次查找范围内，没有找到文件名包含“'+query+'”的文件。可以换一个关键词。'
        return '找到这些文件（只查文件名，尚未打开）：\n'+'\n'.join(hits)+('\n结果或查找范围已截断，可以加关键词缩小范围。' if partial else '')
    if re.fullmatch(r'(?:请|帮我)?(?:播放音乐|放首歌|放点音乐|听歌|播放网易云音乐)',m):
        result=runner(['/usr/bin/open','-a','NeteaseMusic'],capture_output=True,text=True,timeout=15)
        return '已请求打开网易云音乐。目前还无法确认播放器已经开始播放，请先在播放器选歌。' if result.returncode==0 else '网易云音乐没有打开成功，尚未播放。'
    if m in ('暂停音乐','下一首','上一首','继续播放音乐'):
        return '网易云音乐的播放控制还未接通，这次没有执行。请暂时在播放器操作。'
    return None
