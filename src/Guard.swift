import AppKit
extension Guardian {
    func enterLightMode(){
        let changed = !resourceLimited
        resourceLimited=true;if criticalMode{life?.stopWalking();speechGeneration=UUID()}
        if criticalMode{petView?.character.removeAllAnimations();petView?.prop.removeAllAnimations();petView?.scene.sublayers?.forEach{$0.removeAllAnimations()}}
        else if changed && !fortuneBusy{petView?.setState("idle");petView?.refreshScene()}
    }
    func handleHealth(_ health:[String:Any]){
        let limited=health["limited"] as? Bool ?? false
        let pressure=lastMetrics["memoryPressure"] as? Int ?? 1
        let wasLimited=resourceLimited;let wasCritical=criticalMode;criticalMode=pressure==4
        if wasCritical && !criticalMode && !fortuneBusy{petView.setState("idle")}
        if pressure==2 && idleAppCare.attempt(){}else if limited || pressure==2 || pressure==4{enterLightMode()}else{resourceLimited=false;if wasLimited{petView.setState("idle")}}
        let active=health["active"] as? [[String:Any]] ?? []
        let severe=active.contains{($0["level"] as? Int ?? 0)>=2}
        status.button?.title=active.isEmpty ? "☾":severe ? "☾ ‼":"☾ !"
        for event in health["events"] as? [[String:Any]] ?? [] {
            let title=event["title"] as? String ?? "电脑状态"
            let result=event["status"] as? String ?? "待复检"
            if result=="已缓解"{
                if active.isEmpty{animate("happy",text:"复检通过，\(title)已缓解。详细记录在照看报告。",seconds:8)}else{petView.say("\(title)已缓解，其他异常仍在观察。",seconds:10)}
            }else{
                if !fortuneBusy{petView.setState("surprise")}
                if criticalMode{petView.character.removeAllAnimations();petView.prop.removeAllAnimations()}
                petView.prop.string=severe ? "‼":"!";petView.prop.foregroundColor=(severe ? NSColor.systemRed:NSColor.systemOrange).cgColor
                let action=limited ? "我已切换轻量模式。":"请看看照看报告。"
                petView.say("\(title)。\(action)\(result=="仍需处理" ? "复检还没恢复。":"稍后复检。")",seconds:12)
            }
            companion.receive("toast",["text":"\(title) · \(result) · 照看 → 照看记录"])
        }
    }
    func guardSettings(){
        let c=readJSON("guard-settings.json")
        let alert=NSAlert();alert.messageText="照看红线";alert.informativeText="每 90 秒采样。持续高负载才提醒；内存采用 macOS 压力告警。普通内存告警先请 LLM 判断可退出的无窗口闲置应用；保护学习、文档、通信和连接服务，不强制结束。";alert.addButton(withTitle:"保存");alert.addButton(withTitle:"取消")
        let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=8;stack.frame=NSRect(x:0,y:0,width:340,height:175)
        var fields:[String:NSTextField]=[:]
        for (key,title,value) in [("cpuPercent","CPU 提醒阈值（%）",90.0),("cpuMinutes","持续时间（分钟）",3.0),("diskWarningGB","空间提醒线（GiB）",10.0),("diskCriticalGB","空间严重线（GiB）",3.0)]{
            let row=NSStackView();row.orientation = .horizontal;row.spacing=12
            let label=NSTextField(labelWithString:title);label.widthAnchor.constraint(equalToConstant:225).isActive=true
            let field=NSTextField(string:String(c[key] as? Double ?? value));field.widthAnchor.constraint(equalToConstant:85).isActive=true
            row.addArrangedSubview(label);row.addArrangedSubview(field);stack.addArrangedSubview(row);fields[key]=field
        }
        let auto=NSButton(checkboxWithTitle:"自动降载并复检",target:nil,action:nil);auto.state=(c["autoRepair"] as? Bool ?? true) ? .on:.off;stack.addArrangedSubview(auto);alert.accessoryView=stack
        if alert.runModal() == .alertFirstButtonReturn {
            var config:[String:Any]=["autoRepair":auto.state == .on]
            let bounds:[String:ClosedRange<Double>]=["cpuPercent":50...99,"cpuMinutes":1...30,"diskWarningGB":2...100,"diskCriticalGB":1...50]
            for (key,field) in fields{guard let n=Double(field.stringValue),n.isFinite,let range=bounds[key],range.contains(n) else{petView.say("数值超出范围，设置未保存。CPU 50–99%，时间 1–30 分钟。",seconds:10);return};config[key]=n}
            guard (config["diskCriticalGB"] as! Double)<=(config["diskWarningGB"] as! Double) else{petView.say("严重线不能高于提醒线，设置未保存。",seconds:8);return}
            writeJSON(config,"guard-settings.json");petView.say("红线记好了。我会先提醒、处理，再认真复检。",seconds:8);refreshMetrics()
        }
    }
}

// The model may select a candidate, but never invent a process or a shell command.
final class IdleAppCare {
    weak var owner:Guardian?
    var seen:[Int32:Date]=[:],lastAttempt=Date.distantPast,busy=false
    init(_ owner:Guardian){self.owner=owner;for app in NSWorkspace.shared.runningApplications{seen[app.processIdentifier]=Date()}}
    func used(_ app:NSRunningApplication){seen[app.processIdentifier]=Date()}
    func eligible(_ app:NSRunningApplication)->Bool{
        guard app.activationPolicy == .regular,!app.isTerminated,!app.isActive,let launched=app.launchDate,Date().timeIntervalSince(launched)>1200,let id=app.bundleIdentifier?.lowercased(),let first=seen[app.processIdentifier],Date().timeIntervalSince(first)>1200 else{return false}
        let protected=["luna","codex","chatgpt","zotero","safari","chrome","firefox","edge","orion","arc","brave","preview","acrobat","word","excel","powerpoint","pages","numbers","keynote","notes","obsidian","notion","textedit","code","terminal","iterm","xcode","jetbrains","python","soffice","libreoffice","photoshop","affinity","figma","blender","finalcut","davinci","obsproject","screenflow","music","spotify","vlc","iina","zoom","teams","discord","wechat","weixin","telegram","slack","whatsapp","facetime","messages","tailscale","vpn","finder","systempreferences","password","keychain","dropbox","onedrive","backup","timemachine","steam","epicgames","parallels","vmware","docker"]
        guard !protected.contains(where:id.contains) else{return false}
        let windows=CGWindowListCopyWindowInfo([.optionAll],kCGNullWindowID) as? [[String:Any]] ?? []
        guard !windows.isEmpty else{return false}
        return !windows.contains{($0[kCGWindowOwnerPID as String] as? Int32)==app.processIdentifier && ($0[kCGWindowLayer as String] as? Int)==0}
    }
    // True means a bounded decision is in flight; defer ordinary light mode until it returns.
    func attempt()->Bool{
        if busy{return true}
        guard let o=owner,!o.criticalMode,!o.isLocked(),Date().timeIntervalSince(lastAttempt)>600,!o.speechBusy,o.workerQueue.operationCount==0,llmConfigured() else{return false}
        for app in NSWorkspace.shared.runningApplications where seen[app.processIdentifier]==nil{seen[app.processIdentifier]=Date()}
        let apps=NSWorkspace.shared.runningApplications.filter{eligible($0)}
        guard !apps.isEmpty else{return false}
        lastAttempt=Date();busy=true
        let candidates=apps.map{["pid":$0.processIdentifier,"bundle":$0.bundleIdentifier ?? "","name":$0.localizedName ?? "","unusedMinutes":Int(Date().timeIntervalSince(seen[$0.processIdentifier]!)/60),"openWindows":0] as [String:Any]}
        o.run("idleAppDecision",["candidates":candidates]){[weak self] r in
            guard let self=self,let o=self.owner else{return};self.busy=false
            let selected=(r["data"] as? [String:Any])?["pid"] as? Int32
            guard !o.isLocked(),let pid=selected,let target=apps.first(where:{$0.processIdentifier==pid}),self.eligible(target) else{o.enterLightMode();o.refreshMetrics();return}
            let name=target.localizedName ?? "闲置应用",requested=target.terminate()
            self.record(["app":name,"pid":pid,"status":requested ? "已请求正常退出，等待检查":"退出请求未获接受","time":Date().timeIntervalSince1970])
            DispatchQueue.main.asyncAfter(deadline:.now()+8){[weak self] in
                guard let self=self,let o=self.owner else{return}
                let ended=target.isTerminated
                self.record(["app":name,"pid":pid,"status":ended ? "已退出；等待内存复检":"仍在运行；可能有保存提示，不强制结束","time":Date().timeIntervalSince1970])
                o.petView.say(ended ? "已退出闲置的\(name)，现在复检内存。":"\(name)没有退出，我不会强制关掉它。",seconds:9)
                o.refreshMetrics()
            }
        };return true
    }
    func record(_ d:[String:Any]){
        var rows=readJSON("idle-app-care.json")["entries"] as? [[String:Any]] ?? [];rows.insert(d,at:0);writeJSON(["entries":Array(rows.prefix(30))],"idle-app-care.json")
        owner?.life?.note((d["app"] as? String ?? "")+"："+(d["status"] as? String ?? ""))
    }
}
