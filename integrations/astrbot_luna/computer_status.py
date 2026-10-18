"""Read-only local health snapshot for the already paired private owner."""
import re
import shutil
import subprocess
from datetime import datetime
from pathlib import Path


def requested(message):
    return bool(re.search(r'电脑|计算机|Mac|系统|CPU|内存|磁盘|电池|卡顿', message, re.I) and re.search(r'看|查|状况|状态|情况|检测|诊断|占用|健康|卡|慢|多少|怎么样|如何', message))


def command(args, timeout=8):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return result.stdout.strip() if result.returncode == 0 else ''
    except (OSError, subprocess.TimeoutExpired):
        return ''


def report():
    lines = ['我是露娜，已读取这台 Mac 的实时状态。', '检查时间：' + datetime.now().astimezone().strftime('%Y-%m-%d %H:%M:%S %Z')]
    cpu = re.findall(r'CPU usage: ([\d.]+)% user, ([\d.]+)% sys', command(['/usr/bin/top', '-l', '2', '-s', '1', '-n', '0'], 12))
    cpu_value = round(sum(map(float, cpu[-1])), 1) if cpu else None
    lines.append('CPU：' + (str(cpu_value) + '%' if cpu_value is not None else '未取得读数'))
    pressure = command(['/usr/sbin/sysctl', '-n', 'kern.memorystatus_vm_pressure_level'])
    lines.append('内存压力：' + {'1':'正常', '2':'偏高', '4':'严重'}.get(pressure, '未取得读数'))
    total = command(['/usr/sbin/sysctl', '-n', 'hw.memsize'])
    if total.isdigit():lines.append(f'物理内存：{int(total)/1073741824:.1f} GB')
    try:
        disk = shutil.disk_usage(Path.home())
        lines.append(f'磁盘可用：{disk.free/1073741824:.1f} / {disk.total/1073741824:.1f} GB')
    except OSError:
        disk = None;lines.append('磁盘：未取得读数')
    battery = command(['/usr/bin/pmset', '-g', 'batt'])
    charge = re.search(r'\d+%', battery)
    lines.append('电池：' + (charge.group() if charge else '无电池或未取得读数') + (' · 接通电源' if 'AC Power' in battery else ' · 使用电池' if 'Battery Power' in battery else ''))
    rows=[]
    for line in command(['/bin/ps','-A','-o','pcpu=,rss=,comm=']).splitlines():
        parts=line.strip().split(None,2)
        if len(parts)==3:
            try:rows.append((float(parts[0]),int(parts[1]),Path(parts[2]).name))
            except ValueError:pass
    if rows:
        lines.append('当前占用较高的程序（进程 CPU 可能超过100%）：')
        for cpu_pct,rss,name in sorted(rows,reverse=True)[:3]:lines.append(f'• {name}：CPU {cpu_pct:.1f}%，内存 {rss/1024:.0f} MB')
    issues=[]
    if cpu_value is not None and cpu_value>=85:issues.append('这次采样 CPU 偏高')
    if pressure in ('2','4'):issues.append('内存压力偏高')
    if disk and disk.free<10*1073741824:issues.append('剩余磁盘空间较少')
    lines.append('本次发现：'+'；'.join(issues) if issues else '本次采样未触发 CPU、内存压力或磁盘阈值；缺失读数不算正常，单次检查也不能排除间歇卡顿。')
    lines.append('已执行状态检查，没有关闭程序、清理文件或修改设置。')
    return '\n'.join(lines)
