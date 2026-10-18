import AppKit
import PDFKit
import Vision
import ImageIO
import UniformTypeIdentifiers

final class CareCenter:NSWindowController {
    weak var guardian:Guardian?
    let tabs=NSSegmentedControl(labels:["电脑一览","学习工具","露娜的小世界","照看记录","后台管理"],trackingMode:.selectOne,target:nil,action:nil)
    let page=NSView(),summary=NSTextField(labelWithString:"正在读取电脑状态…"),subtitle=NSTextField(labelWithString:""),details=NSTextView(),input=NSTextView(),output=NSTextView(),task=NSPopUpButton(),toolStatus=NSTextField(labelWithString:""),lifeTitle=NSTextField(labelWithString:"")
    let taskKinds=["translate_zh","translate_ja","polish_ja","summary","research","plan","explain"]
    var taskBusy=false,coffee:Process?,resultText="",cards:[NSTextField]=[]
    var connection="连接尚未检查",connectionBusy=false,lastConnection=Date.distantPast
    init(_ guardian:Guardian){self.guardian=guardian
        let w=NSPanel(contentRect:NSRect(x:0,y:0,width:700,height:640),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        w.title="露娜 · 小世界与电脑照看";w.isReleasedWhenClosed=false;w.appearance=NSAppearance(named:.darkAqua);w.backgroundColor=NSColor(calibratedRed:0.095,green:0.10,blue:0.13,alpha:1)
        super.init(window:w);let root=w.contentView!;tabs.frame=NSRect(x:24,y:588,width:652,height:30);tabs.target=self;tabs.action=#selector(changeTab);tabs.selectedSegment=0;root.addSubview(tabs)
        page.frame=NSRect(x:24,y:20,width:652,height:550);root.addSubview(page);w.center();render()
    }
    required init?(coder:NSCoder){fatalError()}
    func show(_ tab:Int=0){tabs.selectedSegment=tab;render();window?.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true);if tab==0{guardian?.refreshMetrics();checkConnection()}}
    @objc func changeTab(){render();if tabs.selectedSegment==0{checkConnection()}}
    @discardableResult func label(_ text:String,_ rect:NSRect,size:CGFloat=13,color:NSColor = .secondaryLabelColor)->NSTextField{let l=NSTextField(wrappingLabelWithString:text);l.font = .systemFont(ofSize:size);l.textColor=color;l.frame=rect;page.addSubview(l);return l}
    @discardableResult func button(_ title:String,_ key:String,_ rect:NSRect)->NSButton{let b=NSButton(title:title,target:self,action:#selector(action(_:)));b.identifier=NSUserInterfaceItemIdentifier(key);b.frame=rect;b.bezelStyle = .rounded;page.addSubview(b);return b}
    func textArea(_ text:NSTextView,_ rect:NSRect,editable:Bool=false){let scroll=NSScrollView(frame:rect);scroll.hasVerticalScroller=true;scroll.borderType = .bezelBorder;text.isEditable=editable;text.isSelectable=true;text.isRichText=false;text.font = .systemFont(ofSize:13);text.textColor = .labelColor;text.backgroundColor=NSColor(calibratedWhite:0.13,alpha:1);text.textContainerInset=NSSize(width:12,height:12);text.isVerticallyResizable=true;text.isHorizontallyResizable=false;text.autoresizingMask = [.width];text.textContainer?.widthTracksTextView=true;text.frame=NSRect(x:0,y:0,width:rect.width-16,height:rect.height);scroll.documentView=text;page.addSubview(scroll)}
    func render(){page.subviews.forEach{$0.removeFromSuperview()};cards=[]
        switch tabs.selectedSegment {
        case 0:
            summary.frame=NSRect(x:0,y:490,width:652,height:42);summary.font = .systemFont(ofSize:27,weight:.semibold);page.addSubview(summary)
            subtitle.frame=NSRect(x:0,y:449,width:652,height:38);subtitle.font = .systemFont(ofSize:12);subtitle.textColor = .secondaryLabelColor;subtitle.maximumNumberOfLines=2;page.addSubview(subtitle)
            for i in 0..<3{let box=NSView(frame:NSRect(x:i*222,y:329,width:208,height:104));box.wantsLayer=true;box.layer?.backgroundColor=NSColor(calibratedRed:0.15,green:0.16,blue:0.21,alpha:1).cgColor;box.layer?.cornerRadius=14;let l=NSTextField(wrappingLabelWithString:"");l.frame=NSRect(x:15,y:12,width:178,height:80);l.font = .systemFont(ofSize:16,weight:.medium);box.addSubview(l);cards.append(l);page.addSubview(box)}
            label("谁在占用内存",NSRect(x:0,y:298,width:652,height:24),size:16,color:.labelColor)
            textArea(details,NSRect(x:0,y:138,width:652,height:150))
            button("请露娜解释","explain",NSRect(x:0,y:94,width:130,height:32));button("活动监视器","activity",NSRect(x:138,y:94,width:130,height:32));button("空间整理","scan",NSRect(x:276,y:94,width:114,height:32));button("红线设置","threshold",NSRect(x:398,y:94,width:114,height:32));button("刷新","refresh",NSRect(x:520,y:94,width:132,height:32))
            button("LLM 连接设置","model",NSRect(x:0,y:48,width:150,height:30));button("连接诊断","connection",NSRect(x:158,y:48,width:112,height:30));label(connection,NSRect(x:282,y:43,width:370,height:40),size:11)
            label("自动巡检每 90 秒 · 系统内存告警即时响应 · 异常处理后自动复检",NSRect(x:0,y:6,width:652,height:28),size:12)
            refreshMetrics()
        case 1:
            label("把眼前的材料交给露娜",NSRect(x:0,y:510,width:652,height:30),size:22,color:.labelColor)
            label("先放入文字或文件，再交给配置的 LLM。图片取字、PDF 提取在本机完成。",NSRect(x:0,y:479,width:652,height:25))
            task.frame=NSRect(x:0,y:440,width:220,height:30);if task.numberOfItems==0{task.addItems(withTitles:["日文 → 中文","中文 → 日文","日语学术润色","中日双语摘要","唐话先行研究笔记","拆解今天的任务","解释电脑状态"])};page.addSubview(task)
            button("粘贴文字","paste",NSRect(x:232,y:440,width:112,height:30));button("打开 PDF / 图片","import",NSRect(x:352,y:440,width:160,height:30));button("开始处理","assist",NSRect(x:520,y:440,width:132,height:30)).isEnabled = !taskBusy
            textArea(input,NSRect(x:0,y:257,width:652,height:171),editable:true)
            toolStatus.frame=NSRect(x:0,y:224,width:652,height:26);toolStatus.maximumNumberOfLines=2;toolStatus.font = .systemFont(ofSize:12);toolStatus.textColor = .secondaryLabelColor;page.addSubview(toolStatus)
            textArea(output,NSRect(x:0,y:61,width:652,height:158))
            button("复制结果","copy",NSRect(x:0,y:15,width:112,height:32));button("保存笔记","save",NSRect(x:120,y:15,width:112,height:32));button("打开 Zotero","zotero",NSRect(x:240,y:15,width:120,height:32));button(coffee?.isRunning==true ? "停止防休眠":"防休眠 30 分钟","coffee",NSRect(x:368,y:15,width:158,height:32));button("连接设置","model",NSRect(x:534,y:15,width:118,height:32))
        case 2:
            lifeTitle.frame=NSRect(x:0,y:470,width:652,height:70);lifeTitle.font = .systemFont(ofSize:24,weight:.medium);lifeTitle.maximumNumberOfLines=2;page.addSubview(lifeTitle)
            label("她会散步、喝茶、翻书，也会联网读一小段公开资料。\n屏幕陪伴开启后，每 30 秒检查当前窗口，切换窗口后约 8 秒检查；锁屏或内存紧张时暂停。",NSRect(x:0,y:410,width:652,height:50));button("打开独立读书手记","readingSource",NSRect(x:0,y:375,width:210,height:28))
            textArea(details,NSRect(x:0,y:132,width:652,height:237))
            button(guardian?.life?.enabled==true ? "暂停自主日常":"恢复自主日常","lifeToggle",NSRect(x:0,y:80,width:150,height:32));button("一起专注","focus",NSRect(x:164,y:80,width:140,height:32));button("聊一会儿","chat",NSRect(x:318,y:80,width:140,height:32));button("摸摸头","pat",NSRect(x:472,y:80,width:180,height:32))
            label("本地反应每 15 秒观察一次 · LLM 最多每 2 分钟规划一次 · 主动气泡至少间隔 4 分钟",NSRect(x:0,y:20,width:652,height:44),size:12);refreshLife()
        case 4:
            label("露娜正在做什么",NSRect(x:0,y:510,width:652,height:30),size:22,color:.labelColor)
            let o=guardian
            let speech=o?.voicePaused==true ? "暂停十五分钟内" : o?.muted==true ? "已静音" : "可用"
            let observation=readJSON("screen-observation.json")["status"] as? String ?? "尚无观察回执"
            textArea(details,NSRect(x:0,y:180,width:652,height:300))
            details.font = .systemFont(ofSize:16)
            details.string="语音："+speech+"\n\n窗口观察："+observation+"\n\n电脑巡检："+(o?.watching==true ? "开启":"暂停")+"\n\n聊天："+(o?.companion.chatBusy==true ? "正在回应":"空闲")+"\n\n课程提醒：露娜运行且电脑未锁屏时检查。具体任务结果可在任务记录查看。"
            button(o?.voicePaused==true ? "恢复语音":"暂停语音 15 分钟","pauseVoice",NSRect(x:0,y:124,width:180,height:32))
            button("开始新话题","newTopic",NSRect(x:194,y:124,width:140,height:32))
            button("任务记录","taskNotebook",NSRect(x:348,y:124,width:140,height:32))
            button("刷新状态","background",NSRect(x:502,y:124,width:150,height:32))
            button(o?.studyEnabled==true ? "暂停窗口观察":"开启窗口观察","observe",NSRect(x:0,y:74,width:180,height:32))
            label("开始新话题会归档当前聊天；保留长期记忆、运势和正在执行的任务。",NSRect(x:0,y:16,width:652,height:40))
        default:
            label("异常发生后，她做了什么",NSRect(x:0,y:510,width:652,height:30),size:22,color:.labelColor)
            label("待复检 → 仍需处理 / 已缓解。保留观察证据，不把尝试处理写成修复成功。",NSRect(x:0,y:469,width:652,height:30))
            textArea(details,NSRect(x:0,y:76,width:652,height:380));details.string="正在读取记录…"
            button("更新记录","reports",NSRect(x:0,y:20,width:130,height:32));button("恢复上次整理","restore",NSRect(x:144,y:20,width:150,height:32));button("系统保护检查","security",NSRect(x:308,y:20,width:150,height:32));button(guardian?.watching==true ? "暂停巡检":"恢复巡检","watch",NSRect(x:472,y:20,width:180,height:32));loadReports()
        }
    }
    func refreshMetrics(){guard tabs.selectedSegment==0,let o=guardian else{return};let d=o.lastMetrics
        let pressure=d["memoryPressure"] as? Int;let cpu=d["cpu"] as? Double;let free=d["diskFree"] as? Double;let health=d["health"] as? [String:Any] ?? [:];let active=health["active"] as? [[String:Any]] ?? []
        let age=Date().timeIntervalSince1970-(d["sampledAt"] as? Double ?? 0);let stale=age>200
        let thermal=ProcessInfo.processInfo.thermalState;let danger=pressure==4 || active.contains{($0["level"] as? Int ?? 0)>1} || thermal == .critical
        let warning=pressure==2 || !active.isEmpty || thermal == .serious
        let settings=health["settings"] as? [String:Any] ?? [:]
        let recovered = !active.isEmpty && pressure==1 && (cpu ?? 100)<(settings["cpuPercent"] as? Double ?? 90) && (free ?? 0)/1073741824 >= (settings["diskWarningGB"] as? Double ?? 10) && thermal != .serious && thermal != .critical
        summary.stringValue=stale ? "○ 状态待更新":danger ? "● 电脑压力很大，先保存工作":recovered ? "● 指标已回落，等待复检":warning ? "● 有点吃力，露娜正在照看":"● 状态平稳，可以安心做事"
        summary.textColor=stale ? .secondaryLabelColor:danger ? .systemRed:warning ? .systemOrange:.systemGreen
        subtitle.stringValue="\(d["chip"] ?? "Apple Silicon") · \(Int((d["memoryTotal"] as? Double ?? 0)/1073741824)) GB 内存  |  \(o.watching ? "自动巡检中":"巡检已暂停")  |  更新 \(d["time"] ?? "等待中")\n\(o.resourceLimited ? "露娜已减轻自身负担，保留必要检查和鼠标互动。":"没有待处理的持续负载告警。")"
        if cards.count==3{cards[0].stringValue="运算负载\n"+(cpu.map{String(format:"%.1f%%",$0)} ?? "未取得")+"\n短时采样";cards[1].stringValue="内存压力\n"+([1:"轻松",2:"偏高",4:"严重"][pressure ?? 0] ?? "未取得")+"\n以 macOS 压力为准";cards[2].stringValue="磁盘剩余\n"+(free.map{String(format:"%.1f GiB",$0/1073741824)} ?? "未取得")+"\n"+(d["battery"] as? String ?? "电源未知")}
        let rows=d["memoryProcesses"] as? [[String:Any]] ?? []
        details.string=rows.prefix(5).enumerated().map{index,r in String(format:"%d  %@     %.0f MiB   ·   CPU %.1f%%",index+1,r["name"] as? String ?? "未知",(r["memory"] as? Double ?? 0)/1048576,r["cpu"] as? Double ?? 0)}.joined(separator:"\n\n")+"\n\n按进程驻留内存排序；同一应用可能有多个进程。"
    }
    func refreshLife(){guard tabs.selectedSegment==2,let life=guardian?.life else{return};lifeTitle.stringValue=(life.enabled ? "☾  ":"暂停 · ")+life.activity;details.string=life.source+"\n\n"+life.day.joined(separator:"\n\n")}

    func loadReports(){guardian?.run("guardReports"){[weak self] r in guard let self=self,self.tabs.selectedSegment==3 else{return};let rows=r["data"] as? [[String:Any]] ?? [];self.details.string=rows.isEmpty ? "暂无异常。露娜已经在后台巡检，无需手动开始。":rows.prefix(12).map{d in let stamp=DateFormatter.localizedString(from:Date(timeIntervalSince1970:d["time"] as? Double ?? 0),dateStyle:.short,timeStyle:.short);return "\(stamp)  ·  \(d["title"] ?? "")  ·  \(d["status"] ?? "")\n\(d["before"] ?? "")\n"+(d["actions"] as? [String] ?? []).joined(separator:"\n")+"\n\(d["after"] ?? "")"}.joined(separator:"\n\n────────────\n\n")}}
    func checkConnection(){guard !connectionBusy,Date().timeIntervalSince(lastConnection)>10 else{return};connectionBusy=true;guardian?.run("connection"){[weak self] r in guard let self=self else{return};self.connectionBusy=false;self.lastConnection=Date();self.connection=(r["data"] as? [String:Any])?["message"] as? String ?? "连接诊断暂不可用";if self.tabs.selectedSegment==0{self.render()}}}
    func explain(){guard let d=guardian?.lastMetrics,!d.isEmpty else{return};let safe:[String:Any]=["cpu":d["cpu"] ?? "未知","memoryPressure":d["memoryPressure"] ?? "未知","diskFree":d["diskFree"] ?? "未知","battery":d["battery"] ?? "未知","time":d["time"] ?? "未知","chip":d["chip"] ?? "未知"];input.string=String(data:(try? JSONSerialization.data(withJSONObject:safe,options:.prettyPrinted)) ?? Data(),encoding:.utf8) ?? "";show(1);task.selectItem(at:6);toolStatus.stringValue="已放入数值快照。点击开始处理，交给 LLM 解释。"}
    @objc func action(_ sender:NSButton){switch sender.identifier?.rawValue ?? "" {
        case "pauseVoice":guardian?.setVoicePause(guardian?.voicePaused != true);render()
        case "newTopic":guardian?.startNewTopic();window?.orderOut(nil)
        case "taskNotebook":guardian?.showNotebook(2)
        case "background":render()
        case "observe":guardian?.nativeCall("toggleStudy"){[weak self] _ in self?.render()}
        case "refresh":guardian?.refreshMetrics();refreshMetrics()
        case "threshold":guardian?.guardSettings()
        case "activity":NSWorkspace.shared.openApplication(at:URL(fileURLWithPath:"/System/Applications/Utilities/Activity Monitor.app"),configuration:NSWorkspace.OpenConfiguration())
        case "model":guardian?.modelSettings()
        case "connection":lastConnection = .distantPast;checkConnection()
        case "explain":explain()
        case "reports":loadReports()
        case "watch":guardian?.watching.toggle();if guardian?.watching==true{guardian?.refreshMetrics()};render()
        case "scan","restore","security":window?.orderOut(nil);if guardian?.popover.isShown != true{guardian?.showDashboard()};guardian?.companion.perform(sender.identifier!.rawValue)
        case "paste":input.string=String((NSPasteboard.general.string(forType:.string) ?? "").prefix(12000));toolStatus.stringValue="已粘贴，尚未发送给模型。"
        case "import":importFile()
        case "assist":assist()
        case "copy":NSPasteboard.general.clearContents();NSPasteboard.general.setString(output.string,forType:.string);toolStatus.stringValue="结果已复制。"
        case "save":let panel=NSSavePanel();panel.nameFieldStringValue="露娜笔记.txt";panel.allowedContentTypes=[.plainText];if panel.runModal() == .OK,let url=panel.url{do{try output.string.write(to:url,atomically:true,encoding:.utf8);toolStatus.stringValue="笔记已保存。"}catch{toolStatus.stringValue="保存失败："+error.localizedDescription}}
        case "zotero":NSWorkspace.shared.openApplication(at:URL(fileURLWithPath:"/Applications/Zotero.app"),configuration:NSWorkspace.OpenConfiguration())
        case "coffee":if coffee?.isRunning==true{coffee?.terminate();coffee=nil}else{let p=Process();p.executableURL=URL(fileURLWithPath:"/usr/bin/caffeinate");p.arguments=["-i","-t","1800"];do{try p.run();coffee=p}catch{toolStatus.stringValue=error.localizedDescription}};render()
        case "readingSource":guardian?.showNotebook(0)
        case "lifeToggle":UserDefaults.standard.set(guardian?.life?.enabled==true,forKey:"lifePaused");guardian?.life?.tick();guardian?.petView.refreshScene();render()
        case "focus":guardian?.nativeCall("focusStart"){_ in};guardian?.life?.tick();refreshLife()
        case "chat":window?.orderOut(nil);if guardian?.popover.isShown != true{guardian?.showDashboard()};guardian?.companion.showChat()
        case "pat":guardian?.animate("tap",text:"嗯？手上的事做完了吗。",seconds:4);guardian?.life?.note("你摸了摸露娜的头，她稍稍偏过脸。");refreshLife()
        default:break
    }}
    func assist(){guard !taskBusy else{return};let text=input.string.trimmingCharacters(in:.whitespacesAndNewlines);guard !text.isEmpty,text.count<=12000 else{toolStatus.stringValue="请输入 1–12000 字。";return};taskBusy=true;toolStatus.stringValue="LLM 正在处理…";let kind=taskKinds[max(0,task.indexOfSelectedItem)];guardian?.run("assist",["kind":kind,"text":text]){[weak self] r in guard let self=self else{return};self.taskBusy=false;if let d=r["data"] as? [String:Any]{self.output.string=d["answer"] as? String ?? "";self.toolStatus.stringValue="处理完成 · 请核对原文，尤其是引用与页码。"}else{self.toolStatus.stringValue=r["error"] as? String ?? "未完成"};if self.tabs.selectedSegment==1{self.render()}}}
    func importFile(){guard !taskBusy else{return};let panel=NSOpenPanel();panel.allowedContentTypes=[.pdf,.png,.jpeg,.heic,.plainText];panel.allowsMultipleSelection=false;guard panel.runModal() == .OK,let url=panel.url else{return};toolStatus.stringValue="正在本机提取文字…";taskBusy=true
        DispatchQueue.global(qos:.utility).async{var text="";var note="";do{
            let size=(try url.resourceValues(forKeys:[.fileSizeKey])).fileSize ?? 0;guard size<30_000_000 else{throw NSError(domain:"文件超过 30 MB，请拆分后读取",code:1)}
            if url.pathExtension.lowercased()=="pdf",let pdf=PDFDocument(url:url){for i in 0..<min(12,pdf.pageCount){text+="[页 \(i+1)]\n"+(pdf.page(at:i)?.string ?? "")+"\n";if text.count>11000{break}};note="已提取 PDF 开头最多 12 页；扫描页需先转图片取字。"}
            else if ["txt","md"].contains(url.pathExtension.lowercased()){text=try String(contentsOf:url,encoding:.utf8);note="已读入文本。"}
            else {guard let src=CGImageSourceCreateWithURL(url as CFURL,nil),let image=CGImageSourceCreateThumbnailAtIndex(src,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:1800] as CFDictionary) else{throw NSError(domain:"图片无法读取",code:2)};let req=VNRecognizeTextRequest();req.recognitionLevel = .accurate;req.recognitionLanguages=["ja-JP","zh-Hans","en-US"];try VNImageRequestHandler(cgImage:image).perform([req]);text=(req.results ?? []).compactMap{$0.topCandidates(1).first?.string}.joined(separator:"\n");note="图片取字完成，请核对识别错误。"}
            if text.count>12000{note+=" 已截取前 12000 字。"};if text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty{note="未提取到可读文字。"}
        }catch{note="提取未完成："+error.localizedDescription}
        DispatchQueue.main.async{self.taskBusy=false;self.input.string=String(text.prefix(12000));self.toolStatus.stringValue=note+" 尚未发送给模型。"}}
    }
}
