import AppKit
final class LunaLife {
    weak var owner:Guardian?
    var timer:Timer?,nextPlan=Date.distantPast,lastLine=Date.distantPast,lastChange=Date.distantPast
    var activity="在小书桌旁安顿下来",source="本地日常",lastApp="",busy=false,day:[String]=[]
    var walkTimer:Timer?,walking=false,lastWalk=Date.distantPast,lastTouch=Date.distantPast
    var nextRead=Date().addingTimeInterval(20),readingBusy=false,reading:[String:Any]=[:]
    var enabled:Bool { !UserDefaults.standard.bool(forKey:"lifePaused") }
    init(_ owner:Guardian){self.owner=owner;day=readJSON("life-day.json")["entries"] as? [String] ?? [];timer=Timer.scheduledTimer(withTimeInterval:15,repeats:true){[weak self]_ in self?.tick()};DispatchQueue.main.asyncAfter(deadline:.now()+8){[weak self] in self?.tick()};loadReading()}
    func note(_ value:String){if day.first?.hasSuffix("  "+value)==true{return};let stamp=DateFormatter.localizedString(from:Date(),dateStyle:.none,timeStyle:.short);day.insert(stamp+"  "+value,at:0);day=Array(day.prefix(30));writeJSON(["entries":day],"life-day.json")}
    func apply(_ title:String,_ action:String,prop:String="",line:String="",model:Bool=false){
        guard let o=owner else{return};activity=title;source=model ? "LLM 的日常计划":"本地日常";lastChange=Date();note(title)
        o.animate(action,seconds:12)
        o.petView.sceneKind=title.contains("茶") ? "tea":title.contains("书") || title.contains("笔记") || title.contains("画册") ? "book":""
        o.petView.refreshScene();if !prop.isEmpty && o.petView.sceneKind.isEmpty{o.petView.prop.string=prop}
        if !line.isEmpty,Date().timeIntervalSince(lastLine)>240,!o.popover.isShown{lastLine=Date();o.petView.say(line,seconds:9);o.maybeSpeak(line)}
        o.center?.refreshLife()
    }
    func tick(){
        owner?.routines.tick()
        if let o=owner,o.isLocked(){stopWalking();o.petView.scene.isHidden=true;return}
        guard enabled,let o=owner,!o.isLocked(),!o.criticalMode,!o.fortuneBusy,!o.jobBusy,!o.companion.chatBusy,!o.petView.dragged,!walking else{return}
        let app=NSWorkspace.shared.frontmostApplication?.localizedName ?? "桌面"
        let changed=app != lastApp;lastApp=app
        if !o.criticalMode,!readingBusy,Date()>nextRead,o.workerQueue.operationCount==0{
            fetchReading();return
        }
        if !o.criticalMode,!o.popover.isShown,Date().timeIntervalSince(lastWalk)>180,Date().timeIntervalSince(lastTouch)>45,Int.random(in:0..<100)<25{
            stroll(affection:Date().timeIntervalSince(lastLine)>300 && Int.random(in:0..<100)<40);return
        }
        if Date().timeIntervalSince(lastChange)>90 || (changed && Date().timeIntervalSince(lastChange)>20){
            if o.resourceLimited{apply("放慢动作，喝茶守着电脑","idle")}
            else if o.focusEnd != nil{apply("在小书桌读书，陪你专注","think",prop:"📖")}
            else if ["Zotero","Preview","预览","Word","Pages"].contains(where:app.contains){apply("翻开自己的笔记，陪你读资料","think",prop:"📖")}
            else if app.contains("Music") || app.contains("Spotify"){apply("随着音乐轻轻晃动","happy",prop:"♪")}
            else if ["rain","storm"].contains(o.lastWeather["state"] as? String ?? ""){apply("撑着小伞，听窗外的雨","tap",prop:"☂️")}
            else{let hour=Calendar.current.component(.hour,from:Date());if hour<6 || hour>=23{apply("在小书桌边安静喝茶","idle",prop:"☕")}
                else{let choices=[("整理自己的小书桌","think","✒️"),("翻一页画册","think","📖"),("伸个懒腰","happy",""),("停下来喝一口茶","idle","☕")];let x=choices.randomElement()!;apply(x.0,x.1,prop:x.2)}}
        }
        guard !busy,!o.companion.chatBusy,Date()>nextPlan,o.workerQueue.operationCount==0 else{return}
        guard llmConfigured() else{source="本地日常 · 等待 LLM 连接";o.center?.refreshLife();return}
        nextPlan=Date().addingTimeInterval(120);busy=true;let activityAtRequest=lastChange;let turn=o.turnGeneration
        let context:[String:Any]=["app":app,"time":DateFormatter.localizedString(from:Date(),dateStyle:.short,timeStyle:.short),"weather":o.lastWeather["state"] ?? "未取得","health":o.resourceLimited ? "露娜轻量模式":"无已知资源警告","activity":activity,"reading":(reading["title"] as? String ?? "尚未阅读")+" "+(reading["quote"] as? String ?? "")]
        o.run("life",context){[weak self] r in guard let self=self,let o=self.owner else{return};self.busy=false
            guard self.enabled,!o.isLocked(),!o.fortuneBusy,!o.companion.chatBusy,self.lastChange==activityAtRequest,o.turnGeneration==turn else{return}
            if let d=r["data"] as? [String:Any]{self.apply(d["activity"] as? String ?? "安静陪伴",d["action"] as? String ?? "idle",line:d["line"] as? String ?? "",model:true)}else{self.source="本地日常 · LLM 暂未连通";self.nextPlan=Date().addingTimeInterval(300);o.center?.refreshLife()}
        }
    }
    func loadReading(){
        if let d=try? Data(contentsOf:support.appendingPathComponent("reading-log.json")),let rows=try? JSONSerialization.jsonObject(with:d) as? [[String:Any]]{reading=rows.first(where:{lunaDay(Date(timeIntervalSince1970:$0["time"] as? Double ?? 0))==lunaDay()}) ?? [:]}
    }
    func fetchReading(){
        guard let o=owner else{return};let turn=o.turnGeneration;readingBusy=true;nextRead=Date().addingTimeInterval(600)
        o.run("readOnline"){[weak self] r in
            guard let self=self,let o=self.owner else{return};self.readingBusy=false
            guard let d=r["data"] as? [String:Any] else{self.note("联网阅读暂未成功，未增加已读记录。");return}
            self.reading=d
            o.petView.markReadingUnread(d["evidenceHash"] as? String ?? "")
            o.notebook?.reload()
            guard self.enabled,o.turnGeneration==turn,!o.isLocked(),!o.fortuneBusy,!o.companion.chatBusy,!self.walking else{return}
            
            self.activity="刚读完一段，想与你分享";self.lastChange=Date();o.animate("happy",seconds:2)
            o.petView.say("刚读到有趣的一段。点这段字幕，听听我的感想吧。",seconds:120,readingHash:d["evidenceHash"] as? String)
            o.petView.sceneKind=d["kind"] as? String == "tea" ? "tea":"book";o.petView.refreshScene()
            let readingToken=o.stateToken
            DispatchQueue.main.asyncAfter(deadline:.now()+5){[weak o] in guard let o=o,o.stateToken==readingToken,!o.companion.chatBusy,!o.fortuneBusy else{return};o.animate("happy",seconds:2)}
            if Date().timeIntervalSince(self.lastLine)>240,!o.popover.isShown{
                self.lastLine=Date()
                o.maybeSpeak("刚读到有趣的一段。点这段字幕，看看我的读书感想吧。",readingHash:d["evidenceHash"] as? String)
            };o.center?.refreshLife()
        }
    }
    func stopWalking(){walkTimer?.invalidate();walkTimer=nil;if walking{walking=false;owner?.currentState="idle";owner?.petView.setState("idle")};lastWalk=Date()}
    func stroll(affection:Bool){
        guard let o=owner,!o.criticalMode,o.pet.isVisible,!o.popover.isShown else{return}
        let origin=o.pet.frame.origin,frame=o.pet.screen?.visibleFrame ?? NSScreen.main!.visibleFrame
        let pointer=NSEvent.mouseLocation
        let toward=affection ? (pointer.x<o.pet.frame.midX ? -1.0:1.0):(Bool.random() ? -1.0:1.0)
        let x=min(max(origin.x+CGFloat(toward)*CGFloat.random(in:80...150),frame.minX),max(frame.minX,frame.maxX-o.pet.frame.width))
        guard abs(x-origin.x)>15 else{lastWalk=Date();return}
        walking=true;lastWalk=Date();let start=Date();o.stateToken=UUID();o.currentState=x<origin.x ? "walkLeft":"walk";o.petView.setState(o.currentState)
        activity=affection ? "走过来，想和你分享一点小事":"在桌面上散一小段步";o.center?.refreshLife()
        walkTimer=Timer.scheduledTimer(withTimeInterval:1.0/24,repeats:true){[weak self] timer in
            guard let self=self,let o=self.owner else{timer.invalidate();return}
            guard self.enabled,!o.isLocked(),!o.criticalMode,!o.fortuneBusy,!o.companion.chatBusy,!o.petView.dragged,!o.popover.isShown else{self.stopWalking();return}
            let t=min(1,Date().timeIntervalSince(start)/3.2)
            o.pet.setFrameOrigin(NSPoint(x:origin.x+(x-origin.x)*t,y:min(max(origin.y,frame.minY),max(frame.minY,frame.maxY-o.pet.frame.height))))
            if t>=1{
                self.stopWalking();UserDefaults.standard.set(o.pet.frame.origin.x,forKey:"petX");UserDefaults.standard.set(o.pet.frame.origin.y,forKey:"petY")
                self.note(affection ? "散步过来，轻轻叫了你一声。":"在桌面走了一小段，又停下来了。")
                writeJSON(["action":"autonomousWalk","finished":true,"affection":affection,"x":x,"at":Date().timeIntervalSince1970],"life-motion.json")
                if affection{
                    self.lastLine=Date();o.animate("tap",seconds:6)
                    let zh="陪我待一小会儿？……等你忙完也可以。"
                    o.petView.say(zh,seconds:9);o.maybeSpeak(zh,ja:"少しだけ、そばにいてくれないか。……手が空いてからで構わない。")
                };o.center?.refreshLife()
            }
        }
    }

}

final class CareRoutines {
    weak var owner:Guardian?
    var lastTick=Date(),activeSeconds:Double=0,pending="",snoozeUntil=Date.distantPast,lastNotice=Date.distantPast
    let defaults=UserDefaults.standard
    init(_ owner:Guardian){self.owner=owner;defaults.register(defaults:["lunchMinute":720,"dinnerMinute":1140,"breakMinutes":50])}
    static func mealDue(minute:Int,target:Int,alreadyShown:Bool)->Bool{return !alreadyShown && minute>=target && minute<target+45}
    func tick(){
        let now=Date(),elapsed=min(30,max(0,now.timeIntervalSince(lastTick)));lastTick=now
        if owner?.isLocked()==true{activeSeconds=0;return}
        guard let o=owner,!defaults.bool(forKey:"careRemindersPaused"),o.life?.enabled != false,!o.isLocked(),!o.criticalMode,o.pet.isVisible else{return}
        let idle=min(CGEventSource.secondsSinceLastEventType(.combinedSessionState,eventType:.mouseMoved),CGEventSource.secondsSinceLastEventType(.combinedSessionState,eventType:.keyDown))
        if idle>300{activeSeconds=0};guard idle<90 else{return};activeSeconds+=elapsed
        var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(identifier:"Asia/Tokyo")!
        let c=calendar.dateComponents([.year,.month,.day,.hour,.minute],from:now),minute=(c.hour ?? 0)*60+(c.minute ?? 0)
        guard minute>=480,minute<1380,!o.fortuneBusy,!o.companion.chatBusy,!o.popover.isShown,o.focusEnd==nil,now.timeIntervalSince(lastNotice)>300 else{return}
        let day="\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
        if defaults.string(forKey:"reminderSkipDay")==day{return}
        if !pending.isEmpty{if now>=snoozeUntil{show(pending)};return}
        for key in ["lunch","dinner"]{
            let target=defaults.integer(forKey:key+"Minute"),shown=defaults.string(forKey:key+"ReminderDay")==day
            if Self.mealDue(minute:minute,target:target,alreadyShown:shown){defaults.set(day,forKey:key+"ReminderDay");show(key);return}
        }
        if activeSeconds>=Double(defaults.integer(forKey:"breakMinutes")*60){activeSeconds=0;show("break")}
    }
    func show(_ kind:String){
        guard let o=owner else{return};pending="";lastNotice=Date();defaults.set(kind,forKey:"lastReminderKind");o.life?.stopWalking();o.stateToken=UUID()
        let meal=kind != "break"
        if meal{o.currentState="eat";o.petView.sceneKind="eat";o.petView.refreshScene()}else{o.animate("happy",seconds:5)}
        let zh=meal ? "到饭点了。先把手上的进度保存好，陪我吃点东西吧。":"忙了一阵了。把目光从屏幕移开，起身活动一下如何？"
        o.petView.say(zh+"\n右键可选稍后提醒。",seconds:14)
        o.maybeSpeak(zh,ja:meal ? "食事の時間だ。まず作業を保存して、私と少し食べないか。":"しばらく頑張ったな。画面から目を離して、少し体を動かしたらどうだ。")
        o.life?.note(meal ? "饭点到了，端起饭碗陪你休息。":"提醒你休息一下眼睛、活动身体。")
        writeJSON(["kind":kind,"shownAt":Date().timeIntervalSince1970,"timezone":"Asia/Tokyo"],"reminder-last.json")
        o.status.menu=o.makeMenu()
        DispatchQueue.main.asyncAfter(deadline:.now()+12){[weak o] in guard let o=o,o.currentState=="eat" else{return};o.currentState="idle";o.petView.sceneKind="";o.petView.setState("idle")}
    }
    func respond(_ action:String){
        guard let o=owner else{return}
        if action=="later"{pending=defaults.string(forKey:"lastReminderKind") ?? "break";snoozeUntil=Date().addingTimeInterval(600);o.petView.say("知道了，十分钟后再提醒你。",seconds:6)}
        else if action=="skip"{var c=Calendar(identifier:.gregorian);c.timeZone=TimeZone(identifier:"Asia/Tokyo")!;let d=c.dateComponents([.year,.month,.day],from:Date());defaults.set("\(d.year!)-\(d.month!)-\(d.day!)",forKey:"reminderSkipDay");pending="";o.petView.say("今天的饭点和休息提醒先收起来。",seconds:6)}
        else{pending="";activeSeconds=0;o.petView.say("嗯，照顾好自己。手上的事一会儿再继续。",seconds:7)}
    }
    func settings(){
        let alert=NSAlert();alert.messageText="露娜的日常提醒";alert.informativeText="大阪时间；只在你使用电脑时提醒。23:00–08:00 安静，锁屏和专注计时期间延后。离开电脑五分钟会重新计算连续使用时间。";alert.addButton(withTitle:"保存");alert.addButton(withTitle:"取消")
        let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=10;stack.frame=NSRect(x:0,y:0,width:360,height:145)
        var fields:[String:NSTextField]=[:]
        for (key,label) in [("lunchMinute","午饭 HH:mm"),("dinnerMinute","晚饭 HH:mm"),("breakMinutes","连续使用多少分钟后休息")]{
            let n=defaults.integer(forKey:key),value=key=="breakMinutes" ? String(n):String(format:"%02d:%02d",n/60,n%60)
            let row=NSStackView();row.spacing=10;let title=NSTextField(labelWithString:label);title.widthAnchor.constraint(equalToConstant:225).isActive=true;let field=NSTextField(string:value);field.widthAnchor.constraint(equalToConstant:90).isActive=true;row.addArrangedSubview(title);row.addArrangedSubview(field);stack.addArrangedSubview(row);fields[key]=field
        }
        let enabled=NSButton(checkboxWithTitle:"开启饭点和休息提醒",target:nil,action:nil);enabled.state=defaults.bool(forKey:"careRemindersPaused") ? .off:.on;stack.addArrangedSubview(enabled);alert.accessoryView=stack
        if alert.runModal() == .alertFirstButtonReturn{
            var values:[String:Int]=[:]
            for key in ["lunchMinute","dinnerMinute"]{let parts=fields[key]!.stringValue.split(separator:":");guard parts.count==2,let h=Int(parts[0]),let m=Int(parts[1]),(0...23).contains(h),(0...59).contains(m) else{owner?.petView.say("时间请用 HH:mm，设置未保存。",seconds:7);return};values[key]=h*60+m}
            guard let n=Int(fields["breakMinutes"]!.stringValue),(20...180).contains(n) else{owner?.petView.say("休息间隔请填 20–180 分钟。",seconds:7);return}
            for (key,value) in values{defaults.set(value,forKey:key)};defaults.set(n,forKey:"breakMinutes");defaults.set(enabled.state != .on,forKey:"careRemindersPaused");activeSeconds=0;owner?.petView.say("饭点和休息时间记好了。",seconds:6)
        }
    }
}
