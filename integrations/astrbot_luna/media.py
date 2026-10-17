"""Bounded QQ attachments; never resolve a user-supplied local filename."""

import asyncio
import shutil
from pathlib import Path
from urllib.parse import unquote, urlsplit

import aiohttp

MAX_BYTES = 20 * 1024 * 1024
EXTENSIONS = {
    ".pdf",
    ".docx",
    ".txt",
    ".md",
    ".csv",
    ".json",
    ".wav",
    ".mp3",
    ".m4a",
    ".ogg",
    ".amr",
    ".silk",
}


def allowed_url(url):
    parsed = urlsplit(url)
    host = (parsed.hostname or "").lower()
    return (
        parsed.scheme == "https"
        and not parsed.username
        and not parsed.password
        and parsed.port in (None, 443)
        and any(
            host == d or host.endswith("." + d)
            for d in ("qq.com", "qpic.cn", "gtimg.cn", "myqcloud.com")
        )
    )


async def receive(source, name, job, temporary_root):
    suffix = Path(name).suffix.lower()
    if suffix not in EXTENSIONS:
        raise ValueError("支持 PDF、DOCX、文本和常见音频文件，单份最多 20 MB。")
    target = job / ("input" + suffix)
    parsed = urlsplit(source)
    if parsed.scheme in ("http", "https"):
        if not allowed_url(source):
            raise ValueError("附件下载地址不是受支持的 QQ 官方地址。")
        async with aiohttp.ClientSession(
            timeout=aiohttp.ClientTimeout(total=40)
        ) as session:
            async with session.get(source, allow_redirects=False) as response:
                if response.status != 200:
                    raise ValueError("QQ 附件下载失败，请重新发送文件。")
                size = 0
                with target.open("wb") as out:
                    async for chunk in response.content.iter_chunked(65536):
                        size += len(chunk)
                        if size > MAX_BYTES:
                            raise ValueError("附件超过 20 MB，请拆分后发送。")
                        out.write(chunk)
    else:
        local = Path(
            unquote(parsed.path) if parsed.scheme == "file" else source
        ).resolve()
        root = temporary_root.resolve()
        if (
            not local.is_relative_to(root)
            or not local.is_file()
            or local.stat().st_size > MAX_BYTES
        ):
            raise ValueError("只处理 QQ 实际收到的附件，不能通过消息读取本机任意文件。")
        await asyncio.to_thread(shutil.copyfile, local, target)
    target.chmod(0o600)
    return target
