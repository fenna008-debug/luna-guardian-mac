// All everyday interactions live beside the pet, in a native speech bubble.
import AppKit
final class LunaCard:NSVisualEffectView {
    override init(frame:NSRect){super.init(frame:frame);material = .hudWindow;blendingMode = .behindWindow;state = .active;appearance=NSAppearance(named:.darkAqua);wantsLayer=true;layer?.cornerRadius=20;layer?.masksToBounds=true;layer?.borderWidth=0.7;layer?.borderColor=NSColor.white.withAlphaComponent(0.18).cgColor}
    required init?(coder:NSCoder){fatalError()}
    var solid=false
    override func draw(_ rect:NSRect){super.draw(rect);if solid{NSColor(calibratedRed:0.12,green:0.12,blue:0.16,alpha:1).setFill();bounds.fill();return};NSColor(calibratedRed:0.44,green:0.38,blue:0.56,alpha:0.08).setFill();bounds.fill()}
}
final class CompanionBubble:NSViewController {
    weak var owner:Guardian?
    let transcript=NSTextView(),scroll=NSScrollView(),input=NSTextField(),hint=NSTextField(labelWithString:"日常 LLM · 复杂任务按需交接 Codex")
    let observationStatus=NSButton(title:"观察：等待检查",target:nil,action:nil),taskStatus=NSButton(title:"任务：暂无执行",target:nil,action:nil)
    var chatRequest=UUID()
    let fortuneBanner=NSTextField(wrappingLabelWithString:"")
    let send=NSButton(title:"发送",target:nil,action:nil)
    var mode="chat",messages="露娜\n我在这里。直接和我说就好。\n\n也可以输入：天气、抽签、扫描、专注。\n",chatBusy=false,choices:[NSButton]=[]
    var slider:NSSlider!
    var requestStarted=Date(),waitTimer:Timer?
    override func loadView(){
        if let data=try? Data(contentsOf:support.appendingPathComponent("chat.json")),let rows=(try? JSONSerialization.jsonObject(with:data)) as? [[String:String]],!rows.isEmpty{messages=rows.suffix(20).map{($0["role"]=="user" ? "你":"露娜")+"\n"+($0["text"] ?? "")+"\n\n"}.joined()}
        let handoff=readJSON("codex-status.json")
        if let state=handoff["state"] as? String,["completed","failed"].contains(state),let summary=handoff["summary"] as? String,!messages.contains(summary){messages+="露娜\nCodex \(state=="completed" ? "已返回结果":"未完成")：\n\(summary)\n\n"}
        let root=LunaCard(frame:NSRect(x:0,y:0,width:340,height:380));view=root
        let title=NSTextField(labelWithString:"☾  L U N A");title.font = .systemFont(ofSize:12,weight:.medium);title.textColor=NSColor.white.withAlphaComponent(0.85);title.frame=NSRect(x:18,y:350,width:200,height:18);root.addSubview(title)
        let close=LunaChip(title:"×",target:self,action:#selector(collapse));close.isBordered=false;close.frame=NSRect(x:302,y:346,width:24,height:26);root.addSubview(close)
        hint.font = .systemFont(ofSize:10);hint.textColor=NSColor.white.withAlphaComponent(0.5);hint.frame=NSRect(x:18,y:330,width:305,height:16);root.addSubview(hint)
        fortuneBanner.font = .systemFont(ofSize:11,weight:.medium);fortuneBanner.textColor=NSColor(calibratedRed:0.93,green:0.83,blue:0.61,alpha:1);fortuneBanner.frame=NSRect(x:18,y:281,width:304,height:44);fortuneBanner.maximumNumberOfLines=2;root.addSubview(fortuneBanner);refreshFortuneBanner()
        scroll.frame=NSRect(x:12,y:163,width:316,height:112);scroll.hasVerticalScroller=true;scroll.scrollerStyle = .overlay;scroll.borderType = .noBorder;scroll.drawsBackground=false;root.addSubview(scroll)
        transcript.isEditable=false;transcript.isSelectable=true;transcript.isRichText=false;transcript.font = .systemFont(ofSize:13);transcript.textColor=NSColor.white.withAlphaComponent(0.9);transcript.drawsBackground=false;transcript.textContainerInset=NSSize(width:6,height:8);transcript.autoresizingMask = [.width];transcript.isVerticallyResizable=true;transcript.isHorizontallyResizable=false;transcript.textContainer?.widthTracksTextView=true;transcript.frame=NSRect(x:0,y:0,width:300,height:160);scroll.documentView=transcript;render(messages)
        let line=NSBox(frame:NSRect(x:18,y:76,width:304,height:1));line.boxType = .separator;line.alphaValue=0.25;root.addSubview(line)
        input.frame=NSRect(x:18,y:40,width:262,height:27);input.placeholderString="和我说说…";input.isBordered=false;input.drawsBackground=false;input.focusRingType = .none;input.textColor = .white;input.font = .systemFont(ofSize:13);input.target=self;input.action=#selector(submit);root.addSubview(input)
        send.title="↑";send.frame=NSRect(x:290,y:39,width:32,height:28);send.isBordered=false;send.contentTintColor=NSColor(calibratedRed:0.82,green:0.75,blue:0.96,alpha:1);send.target=self;send.action=#selector(submit);root.addSubview(send)
        for (i,pair) in [("对话","chat"),("手记","notebook"),("抽签","fortune"),("Codex ↗","codex")].enumerated(){let b=LunaChip(title:pair.0,target:self,action:#selector(shortcut(_:)));b.identifier=NSUserInterfaceItemIdentifier(pair.1);b.isBordered=false;b.frame=NSRect(x:12+i*64,y:7,width:62,height:25);root.addSubview(b)}
        observationStatus.frame=NSRect(x:18,y:139,width:304,height:22);observationStatus.font = .systemFont(ofSize:10);observationStatus.isBordered=false;observationStatus.alignment = .left;observationStatus.target=self;observationStatus.action=#selector(showObservation);root.addSubview(observationStatus)
        taskStatus.frame=NSRect(x:18,y:91,width:304,height:43);taskStatus.font = .systemFont(ofSize:11);taskStatus.title="任务：暂无执行\n点击查看执行记录";taskStatus.cell?.wraps=true;taskStatus.target=self;taskStatus.action=#selector(showTasks);root.addSubview(taskStatus)
        let stop=NSButton(title:"停止",target:self,action:#selector(cancelReply));stop.frame=NSRect(x:244,y:345,width:50,height:24);stop.isBordered=false;root.addSubview(stop)
        let prior=readJSON("screen-observation.json");observationStatus.title="观察："+(prior["status"] as? String ?? "等待检查")
        slider=NSSlider(value:Double(owner?.petSize ?? 220),minValue:140,maxValue:360,target:self,action:#selector(resize(_:)));slider.isContinuous=true
        let tools=LunaChip(title:"更多",target:self,action:#selector(more(_:)));tools.isBordered=false;tools.frame=NSRect(x:286,y:7,width:40,height:25);root.addSubview(tools)
    }
    @objc func showObservation(){let d=readJSON("screen-observation.json");let stamp=DateFormatter.localizedString(from:Date(timeIntervalSince1970:d["at"] as? Double ?? 0),dateStyle:.none,timeStyle:.short);text("最近检查："+stamp+"\n"+(d["app"] as? String ?? "")+"\n"+(d["status"] as? String ?? "等待检查")+"\n\n"+(d["text"] as? String ?? ""),title:"窗口观察状态")}
    @objc func showTasks(){owner?.showNotebook(3)}
    @objc func cancelReply(){chatRequest=UUID();owner?.cancelCurrentTurn();chatBusy=false;waitTimer?.invalidate();send.isEnabled=true;hint.stringValue="已停止当前回应"}
    func refreshFortuneBanner(){
        let saved=readJSON("fortune.json")
        if saved["date"] as? String==lunaDay(),let title=saved["title"] as? String {
            fortuneBanner.stringValue="🎋 今日运势 · \(title) · 凌晨4点更新\n"+(saved["text"] as? String ?? "")
            fortuneBanner.toolTip=fortuneBanner.stringValue
        }else{fortuneBanner.stringValue="🎋 今日签尚未抽取 · 每日凌晨4点换日";fortuneBanner.toolTip=nil}
    }
    override func viewDidAppear(){super.viewDidAppear();view.window?.makeFirstResponder(input)}
    @objc func collapse(){owner?.popover.close()}
    @objc func resize(_ sender:NSSlider){owner?.resizePet(CGFloat(sender.doubleValue))}
    @objc func more(_ sender:NSButton){owner?.makeMenu().popUp(positioning:nil,at:NSPoint(x:sender.frame.minX,y:sender.frame.minY),in:view)}
    func updateSurface(){
        guard isViewLoaded,let card=view as? LunaCard else{return}
        let chat=mode=="chat" || mode.hasPrefix("日常 LLM")
        card.solid = !chat;card.state = chat ? .active:.inactive;card.needsDisplay=true
        let saved=UserDefaults.standard.double(forKey:"glassAlpha")
        owner?.popover.alphaValue=chat ? (saved>0 ? saved:0.90):1
    }
    func text(_ value:String,title:String="露娜"){refreshFortuneBanner();mode=title;updateSurface();scroll.documentView=transcript;render(value);transcript.scrollRangeToVisible(NSRange(location:0,length:0));hint.stringValue=title;send.title="↑";input.isHidden=false;send.isHidden=false}
    func render(_ value:String){
        let paragraph=NSMutableParagraphStyle();paragraph.lineSpacing=5;paragraph.paragraphSpacing=7
        let a=NSMutableAttributedString(string:value,attributes:[.font:NSFont.systemFont(ofSize:13),.foregroundColor:NSColor.white.withAlphaComponent(0.9),.paragraphStyle:paragraph])
        let ns=value as NSString
        for name in ["露娜", "你", "连接提示"] {let pattern="(?m)^"+name+"$";if let regex=try? NSRegularExpression(pattern:pattern){for match in regex.matches(in:value,range:NSRange(location:0,length:ns.length)){a.addAttributes([.font:NSFont.systemFont(ofSize:11,weight:.semibold),.foregroundColor:NSColor(calibratedRed:0.81,green:0.73,blue:0.95,alpha:1)],range:match.range)}}}
        transcript.textStorage?.setAttributedString(a)
    }
    func showChat(){text(messages,title:"日常 LLM · 回车发送");mode="chat";transcript.scrollToEndOfDocument(nil)}
    @objc func shortcut(_ sender:NSButton){let action=sender.identifier?.rawValue ?? "chat";if action=="chat"{showChat()}else{perform(action)}}
    @objc func submit(){let s=input.stringValue.trimmingCharacters(in:.whitespacesAndNewlines);guard !s.isEmpty else{return};input.stringValue="";let commands=["天气":"weather","抽签":"fortune","扫描":"scan","清理":"scan","专注":"focusStart","停止专注":"focusStop","系统状态":"metrics","保护状态":"security","恢复":"restore","codex":"codex","语音测试":"voiceTest"]
        if let command=commands[s.lowercased()]{perform(command);return};chatBusy=true;chatRequest=UUID();let request=chatRequest;send.isEnabled=true;messages+="你\n\(s)\n\n";showChat();hint.stringValue="露娜正在想…";requestStarted=Date();waitTimer?.invalidate();waitTimer=Timer.scheduledTimer(withTimeInterval:1,repeats:true){[weak self]_ in guard let self=self,self.chatBusy else{return};let seconds=Int(Date().timeIntervalSince(self.requestStarted));self.hint.stringValue=seconds<15 ? "露娜正在想 · \(seconds)秒":"等待服务回复 · \(seconds)秒 · 超时会提示"}
        owner?.nativeCall("chat",["message":s]){[weak self] r in guard let self=self,self.chatRequest==request else{return};self.chatBusy=false;self.waitTimer?.invalidate();self.send.isEnabled=true;if let d=r["data"] as? [String:Any],let answer=d["answer"] as? String{self.messages+="露娜\n\(answer)\n\n"}else{self.messages+="连接提示\n\(r["error"] as? String ?? "未收到回复")\n\n";self.input.stringValue=s};if self.messages.count>24000{self.messages=String(self.messages.suffix(18000))};self.showChat()}
    }
    func perform(_ action:String,_ payload:[String:Any]=[:]){
        if action=="notebook"{owner?.showNotebook();return}
        if ["care","metrics","tools","world","guardReports"].contains(action){owner?.openCenter(action=="tools" ? 1:action=="world" ? 2:action=="guardReports" ? 3:0);return}
        if action=="guardReports"{showGuard();return}
        if action=="metrics"{if let d=owner?.lastMetrics{showMetrics(d)};return}
        if action=="fortune"{text("露娜正在摇签…",title:"摇签 · 稍等一下")}
        if action=="scan"{text("让我拿放大镜检查一下。\n只扫描旧缓存与日志，不动论文和照片。",title:"正在扫描…")}
        if action=="weather"{text("我看看东淀川区的天气…",title:"天气")}
        if action=="security"{text("正在读取系统保护状态…",title:"系统保护")}
        owner?.nativeCall(action,payload){[weak self] r in guard let self=self else{return};guard r["ok"] as? Bool==true else{self.text(r["error"] as? String ?? "操作没有完成",title:"提示");return};let d=r["data"] as? [String:Any] ?? [:]
            switch action {
            case "weather":self.showWeather(d)
            case "fortune":let t=(d["title"] as? String ?? "今日一签")+"\n\n"+(d["text"] as? String ?? "")+"\n\n"+(d["caption"] as? String ?? "");self.text(t,title:"今日抽签 · 娱乐小游戏")
            case "scan":self.showFiles(d)
            case "restore":self.text("已恢复 \(d["restored"] ?? 0) 项。\n同名冲突 \((d["conflicts"] as? [String])?.count ?? 0) 项，未覆盖。",title:"恢复结果")
            case "security":self.text(d.sorted{$0.key<$1.key}.map{"\($0.key)\n\($0.value)"}.joined(separator:"\n\n"),title:"系统保护状态")
            case "history":if let rows=r["data"] as? [[String:Any]]{self.text(rows.prefix(12).map{"\($0["time"] ?? "") · \($0["action"] ?? "")\n\($0["detail"] ?? "")"}.joined(separator:"\n\n"),title:"最近操作记录")}
            case "focusStart":self.text("25:00\n\n这一轮，我陪你。先把眼前的一件事做好。",title:"专注计时");self.mode="focus"
            case "focusStop":self.text("这一轮已经结束。",title:"专注计时")
            case "clean":self.text("已移入恢复区 \(d["moved"] ?? 0) 项。\n\n\(d["note"] ?? "")",title:"整理结果")
            default:break
            }
        }
    }
    func showGuard(){owner?.nativeCall("guardReports"){[weak self] r in
        let rows=r["data"] as? [[String:Any]] ?? []
        let output=rows.prefix(10).map{d -> String in
            let stamp=DateFormatter.localizedString(from:Date(timeIntervalSince1970:d["time"] as? Double ?? 0),dateStyle:.none,timeStyle:.short)
            return "\(stamp) · \(d["title"] ?? "照看") · \(d["status"] ?? "")\n\(d["before"] ?? "")\n"+(d["actions"] as? [String] ?? []).joined(separator:"\n")+"\n\(d["after"] ?? "")\n\(d["advice"] ?? "")"
        }.joined(separator:"\n\n")
        self?.text(output.isEmpty ? "目前还没有红线事件。指标异常时会记录处理和复检结果。":output,title:"照看报告")
    }}
    func showMetrics(_ d:[String:Any]){let cpu=d["cpu"] as? Double ?? 0;let free=d["diskFree"] as? Double ?? 0;let used=d["memoryUsed"] as? Double ?? 0;let total=d["memoryTotal"] as? Double ?? 1;text(String(format:"CPU %.1f%%\n活跃内存 %.1f / %.0f GiB\n磁盘可用 %.2f GB\n\n",cpu,used/1073741824,total/1073741824,free/1e9)+(d["battery"] as? String ?? ""),title:"电脑状态")}
    func showWeather(_ d:[String:Any]){guard let c=d["current"] as? [String:Any] else{return};let names=["rain":"下雨 ☂","snow":"降雪 ❄","storm":"雷雨 ⚡","hot":"高温","cold":"寒冷","sunny":(c["is_day"] as? Int==0 ? "晴夜 ☾":"晴天 ☀"),"cloudy":"多云 ☁"];let state=d["state"] as? String ?? "cloudy";text("\(d["city"] ?? "当前位置")\n\n\(c["temperature_2m"] ?? "—")°C · \(names[state] ?? state)\n体感 \(c["apparent_temperature"] ?? "—")°C\n风速 \(c["wind_speed_10m"] ?? "—") km/h\n\n\(c["time"] ?? "")\nOpen-Meteo 模型估计，非官方预警。",title:"天气")}
    func showFiles(_ d:[String:Any]){mode="files";updateSurface();let files=d["files"] as? [[String:Any]] ?? [];let bytes=d["bytes"] as? Double ?? 0;hint.stringValue=String(format:"旧缓存候选 %d 项 · %.1f MB · 先勾选",files.count,bytes/1e6);choices=[];let height=max(198,files.prefix(80).count*44+65);let list=NSView(frame:NSRect(x:0,y:0,width:315,height:height));for (i,f) in files.prefix(80).enumerated(){let path=f["path"] as? String ?? "";let title=URL(fileURLWithPath:path).lastPathComponent;let b=NSButton(checkboxWithTitle:String(title.prefix(30)),target:nil,action:nil);b.frame=NSRect(x:5,y:height-45-i*44,width:300,height:24);b.identifier=NSUserInterfaceItemIdentifier(f["id"] as? String ?? "");b.toolTip=path;b.font = .systemFont(ofSize:11);list.addSubview(b);choices.append(b)};let move=NSButton(title:"将选中项移入恢复区",target:self,action:#selector(moveFiles));move.frame=NSRect(x:30,y:12,width:250,height:30);move.bezelStyle = .rounded;list.addSubview(move);scroll.documentView=list;scroll.contentView.scroll(to:NSPoint(x:0,y:CGFloat(height)-scroll.contentSize.height));input.isHidden=true;send.isHidden=true;if files.isEmpty{text("没有找到符合条件的旧文件。\n不为了清理而随便删除。",title:"扫描完成")}}
    @objc func moveFiles(){let ids=choices.filter{$0.state == .on}.compactMap{$0.identifier?.rawValue};guard !ids.isEmpty else{hint.stringValue="先勾选要整理的项目，悬停可查看完整路径。";return};perform("clean",["ids":ids])}
    func receive(_ kind:String,_ d:[String:Any]){guard isViewLoaded else{return};if kind=="focus",mode=="focus"{text((d["time"] as? String ?? "")+"\n\n"+(d["text"] as? String ?? ""),title:"专注计时");mode="focus"};if kind=="study"{observationStatus.title="观察："+(d["status"] as? String ?? "");observationStatus.toolTip=observationStatus.title};if kind=="task"{taskStatus.title=(d["tool"] as? String ?? "任务")+" · "+(d["outcome"] as? String ?? "")+"\n点击查看执行记录";taskStatus.toolTip=taskStatus.title};if kind=="location"{text(d["text"] as? String ?? "",title:"定位")};if kind=="toast"{hint.stringValue=d["text"] as? String ?? ""}}
}
