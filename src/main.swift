// A native local companion. All actions have explicit, bounded entry points.
import AppKit
import QuartzCore
import ImageIO
import CoreLocation
import Vision
import ScreenCaptureKit
import AVFoundation

let fm = FileManager.default
let support = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/LunaGuardian")
let resources = Bundle.main.resourceURL!
func writeJSON(_ value: Any, _ name: String) {
    guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]) else { return }
    try? fm.createDirectory(at: support, withIntermediateDirectories: true)
    let path = support.appendingPathComponent(name)
    try? data.write(to: path, options: .atomic)
    try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
}
func readJSON(_ name: String) -> [String:Any] {
    guard let d = try? Data(contentsOf: support.appendingPathComponent(name)), let obj = try? JSONSerialization.jsonObject(with:d) as? [String:Any] else {return [:]};return obj
}
final class PetPanel: NSPanel { override var canBecomeKey: Bool { true } }
final class PetView: NSView {
    weak var owner: Guardian?
    let character = CALayer(), prop = CATextLayer(), bubble = CATextLayer(),scene=CALayer()
    let readingSubtitle=NSButton(title:"",target:nil,action:nil)
    var readingHash:String?
    let unreadBadge=NSButton(title:"📖 !",target:nil,action:nil)
    var unreadReadingHash:String?
    var sceneKind=""
    var states:[String:[CGImage]] = [:]
    var lookFrames:[CGImage]=[],lookIndex = -1,dragDirection="",previousDragX:CGFloat=0
    var startMouse = NSPoint.zero, startWindow = NSPoint.zero, dragged = false
    var pointerGlobal:Any?,pointerLocal:Any?,lastPointerTick:Double=0,lastGreeting:Double=0,nearPointer=false
    override init(frame:NSRect) {
        super.init(frame:frame);wantsLayer=true;layer?.backgroundColor=NSColor.clear.cgColor
        character.frame=CGRect(x:55,y:3,width:130,height:141);character.contentsGravity = .resizeAspect
        character.shadowColor=NSColor(calibratedRed:0.22,green:0.16,blue:0.32,alpha:1).cgColor;character.shadowOpacity=0.18;character.shadowRadius=5;character.shadowOffset=CGSize(width:0,height:-3)
        prop.frame=CGRect(x:139,y:39,width:65,height:70);prop.fontSize=45;prop.contentsScale=2;prop.alignmentMode = .center
        bubble.frame=CGRect(x:2,y:157,width:236,height:78);bubble.fontSize=12;bubble.contentsScale=2;bubble.alignmentMode = .center;bubble.isWrapped=true;bubble.foregroundColor=NSColor(calibratedRed:0.28,green:0.24,blue:0.36,alpha:1).cgColor;bubble.backgroundColor=NSColor(calibratedWhite:1,alpha:0.94).cgColor;bubble.cornerRadius=14;bubble.opacity=0
        layer?.addSublayer(character);layer?.addSublayer(scene);layer?.addSublayer(prop);layer?.addSublayer(bubble)
        if let source=CGImageSourceCreateWithURL(resources.appendingPathComponent("spritesheet.webp") as CFURL,nil),let sheet=CGImageSourceCreateImageAtIndex(source,0,nil) {
            let rows:[String:(Int,Int)]=["idle":(0,7),"walk":(1,8),"walkLeft":(2,8),"wave":(3,4),"happy":(4,5),"sleep":(5,8),"surprise":(6,6),"think":(7,6),"tap":(8,6)]
            for (name,(row,count)) in rows { states[name]=(0..<count).compactMap{col in sheet.cropping(to:CGRect(x:col*192,y:row*208,width:192,height:208))} }
            for i in 0..<16 {let x=CGFloat((i % 8)*192);let y=CGFloat((9+i/8)*208);if let image=sheet.cropping(to:CGRect(x:x,y:y,width:192,height:208)){lookFrames.append(image)}}
        }
        readingSubtitle.isBordered=false;readingSubtitle.isTransparent=true;readingSubtitle.isHidden=true;readingSubtitle.target=self;readingSubtitle.action=#selector(openNotebook);addSubview(readingSubtitle)
        unreadBadge.isBordered=false;unreadBadge.font = .boldSystemFont(ofSize:19);unreadBadge.contentTintColor = .systemOrange;unreadBadge.target=self;unreadBadge.action=#selector(openUnread);unreadBadge.toolTip="有未读的读书感想，点击查看";unreadBadge.setAccessibilityLabel("未读读书感想，点击后清除提醒");addSubview(unreadBadge)
        unreadReadingHash=readJSON("reading-unread.json")["hash"] as? String;unreadBadge.isHidden=unreadReadingHash==nil
        loadActions();setState("idle")
        setAccessibilityElement(true);setAccessibilityLabel("露娜桌宠，点击聊天，拖动移动")
    }
    @objc func openNotebook(){guard let key=readingHash else{return};dismissReadingCaption();owner?.showNotebook(0);if let n=owner?.notebook,let i=n.rows.firstIndex(where:{($0["evidenceHash"] as? String)==key}){n.picker.selectItem(at:i);n.select()}}
    @objc func openUnread(){guard let key=unreadReadingHash else{return};readingHash=key;openNotebook()}
    func markReadingUnread(_ key:String){
        guard !key.isEmpty else{return};unreadReadingHash=key;unreadBadge.isHidden=true;writeJSON(["hash":key,"at":Date().timeIntervalSince1970],"reading-unread.json")
        DispatchQueue.main.asyncAfter(deadline:.now()+120){[weak self] in guard let self=self,self.unreadReadingHash==key else{return};self.unreadBadge.isHidden=false}
    }
    func dismissReadingCaption(){bubbleToken=UUID();bubble.opacity=0;readingSubtitle.isHidden=true;readingHash=nil}
    func clearReadingUnread(){dismissReadingCaption();unreadReadingHash=nil;unreadBadge.isHidden=true;writeJSON([:],"reading-unread.json")}
    required init?(coder:NSCoder){fatalError()}
    func setState(_ state:String) {
        let map=["scan":"think","clean":"walk","fortune":"happy","rain":"tap","storm":"surprise","snow":"surprise","cold":"tap","hot":"sleep","sunny":"happy","night":"idle","cloudy":"idle","chat":"think","focus":"think"]
        let key=map[state] ?? state
        lookIndex = -1;character.removeAllAnimations();prop.removeAllAnimations()
        if let frames=states[key],let first=frames.first {character.contents=first;if owner?.criticalMode==true{return};let a=CAKeyframeAnimation(keyPath:"contents");a.values=frames;a.duration=Double(frames.count)*(owner?.resourceLimited==true ? 0.65:(key=="walk" || key=="walkLeft" ? 0.13:0.23));a.calculationMode = .discrete;a.repeatCount = .infinity;character.add(a,forKey:"frames")}
        if key=="idle" && owner?.criticalMode != true {let breath=CABasicAnimation(keyPath:"transform.scale.y");breath.fromValue=1;breath.toValue=1.012;breath.duration=2.4;breath.autoreverses=true;breath.repeatCount = .infinity;character.add(breath,forKey:"breathing")}
        let props=["scan":"🔎","clean":"🧹","fortune":"🎋","rain":"☂️","storm":"☂️","snow":"❄️","cold":"🧣","hot":"🪭","sunny":"☀️","night":"☾","chat":"✒️","focus":"📖"]
        prop.string=props[state] ?? ""
        scene.isHidden=owner?.fortuneBusy==true || owner?.life?.enabled==false || dragged || sceneKind.isEmpty
        if state=="clean" || state=="fortune" {let a=CABasicAnimation(keyPath:"transform.rotation.z");a.fromValue = -0.25;a.toValue=0.25;a.duration=0.35;a.autoreverses=true;a.repeatCount = .infinity;prop.add(a,forKey:"sweep")}
        if state=="hot" || state=="cold" {let a=CABasicAnimation(keyPath:"transform.translation.x");a.fromValue = -2;a.toValue=2;a.duration=state=="cold" ? 0.1:0.7;a.autoreverses=true;a.repeatCount = .infinity;character.add(a,forKey:"reaction")}
    }
    var bubbleToken=UUID()
    func say(_ text:String,seconds:Double=10,readingHash:String?=nil){self.readingHash=readingHash;readingSubtitle.isHidden=readingHash==nil;readingSubtitle.frame=bubble.frame;readingSubtitle.setAccessibilityLabel(text+"，点击查看读书感想");readingSubtitle.toolTip=readingHash==nil ? nil:"点击这段字幕，查看感想并留言";let token=UUID();bubbleToken=token;bubble.string="\n"+text;bubble.opacity=1;DispatchQueue.main.asyncAfter(deadline:.now()+seconds){[weak self] in if self?.bubbleToken==token{self?.bubble.opacity=0;self?.readingSubtitle.isHidden=true;self?.readingHash=nil}}}
    override func mouseDown(with event:NSEvent){owner?.life?.stopWalking();owner?.life?.lastTouch=Date();startMouse=window?.convertPoint(toScreen:event.locationInWindow) ?? NSEvent.mouseLocation;previousDragX=startMouse.x;startWindow=window?.frame.origin ?? .zero;dragged=false;dragDirection=""}
    override func mouseDragged(with event:NSEvent){
        let now=window?.convertPoint(toScreen:event.locationInWindow) ?? NSEvent.mouseLocation
        if hypot(now.x-startMouse.x,now.y-startMouse.y)>4{
            dragged=true;scene.isHidden=true;owner?.popover.close()
            if owner?.criticalMode != true && owner?.fortuneBusy != true {
                let direction=now.x>=previousDragX ? "walk":"walkLeft"
                if direction != dragDirection{dragDirection=direction;owner?.stateToken=UUID();setState(direction);writeJSON(["action":direction,"at":Date().timeIntervalSince1970],"interaction.json")}
            }
            previousDragX=now.x
            window?.setFrameOrigin(NSPoint(x:startWindow.x+now.x-startMouse.x,y:startWindow.y+now.y-startMouse.y))
        }
    }
    override func mouseUp(with event:NSEvent){
        if dragged{
            if let p=window?.frame.origin{UserDefaults.standard.set(p.x,forKey:"petX");UserDefaults.standard.set(p.y,forKey:"petY")}
            if owner?.criticalMode != true && owner?.fortuneBusy != true{owner?.animate("happy",seconds:1.2);writeJSON(["action":"landing","at":Date().timeIntervalSince1970],"interaction.json")}
        }else{owner?.showDashboard()}
        dragged=false;refreshScene()
    }
    func startPointerInteraction(){
        guard pointerGlobal==nil else{return}
        pointerGlobal=NSEvent.addGlobalMonitorForEvents(matching:.mouseMoved){[weak self]_ in self?.followPointer()}
        pointerLocal=NSEvent.addLocalMonitorForEvents(matching:.mouseMoved){[weak self] event in self?.followPointer();return event}
        window?.acceptsMouseMovedEvents=true
    }
    func followPointer(){
        let now=CACurrentMediaTime();guard now-lastPointerTick>0.08,let owner=owner,let window=window,!dragged,!owner.fortuneBusy,!owner.criticalMode else{return};lastPointerTick=now
        let point=convert(window.convertPoint(fromScreen:NSEvent.mouseLocation),from:nil)
        let dx=point.x-bounds.midX,dy=point.y-owner.petSize*0.55
        let near=hypot(dx,dy)<owner.petSize*0.8
        if near && owner.currentState=="idle" {
            if !nearPointer && now-lastGreeting>10{lastGreeting=now;owner.animate("wave",seconds:1.0)}
            else if lookFrames.count==16 {
                let index=(Int((atan2(dx,dy)/(2 * .pi)*16).rounded())+16)%16
                if index != lookIndex {
                    character.removeAllAnimations();prop.string="";lookIndex=index
                    CATransaction.begin();CATransaction.setDisableActions(true);character.contents=lookFrames[index];CATransaction.commit()
                }
            }
        }else if !near && nearPointer && lookIndex>=0 {setState("idle")}
        nearPointer=near
    }
    override func rightMouseDown(with event:NSEvent){if let m=owner?.makeMenu(){NSMenu.popUpContextMenu(m,with:event,for:self)}}
}
final class Guardian:NSObject,NSApplicationDelegate,CLLocationManagerDelegate,AVAudioPlayerDelegate {
    var notebook:LunaNotebook?
    func showNotebook(_ section:Int=0){if notebook==nil{notebook=LunaNotebook(self)};notebook?.show(section);if section==0{petView.clearReadingUnread()}}
    var pet:PetPanel!,petView:PetView!,status:NSStatusItem!
    let popover=GlassBubble(),companion=CompanionBubble()
    var callbacks:[String:([String:Any])->Void]=[:]
    var petSize:CGFloat=220
    let workerQueue=OperationQueue(),interactionQueue=OperationQueue(),voiceQueue=OperationQueue()
    var pressureSource:DispatchSourceMemoryPressure?,resourceLimited=false,criticalMode=false,fortuneBusy=false
    var fortuneAnimation:FortuneAnimation?
    var dailyPending=false,dailyBusy=false
    var pendingFortuneAnimation=""
    var turnGeneration=UUID(),observationGeneration=UUID()
    var observationSpeech=false
    var observedWindow:CGWindowID?,observedPID:pid_t?
    var scopedProcesses:[UUID:(Process,String)]=[:]
    var readingDay=""
    var visibleTaskID=""
    var studyDebounce:DispatchWorkItem?
    var lastAutoStudy=Date.distantPast,lastScreenReply=Date.distantPast
    var lastPetNear=Date()
    var fadeTimer:Timer?
    var dailyTimer:Timer?
    var center:CareCenter?,life:LunaLife?
    lazy var idleAppCare=IdleAppCare(self)
    lazy var routines=CareRoutines(self)
    var speechBusy=false,lastSpeech=Date.distantPast,speechGeneration=UUID()
    let monitorQueue=OperationQueue()
    func openCenter(_ tab:Int=0){popover.close();if center==nil{center=CareCenter(self)};center?.show(tab)}

    var repoTimer:Timer?,repoBusy=false
    var metricsTimer:Timer?,weatherTimer:Timer?,focusTimer:Timer?,studyTimer:Timer?
    var watching=true,metricBusy=false,weatherBusy=false,webReady=false,muted=false,studyEnabled=false,studyBusy=false,jobBusy=false
    var lastMetrics:[String:Any]=[:],lastWeather:[String:Any]=[:],lastWarning:Date = .distantPast,focusEnd:Date?
    var audio:AVAudioPlayer?,audioTask:Process?
    let locationManager=CLLocationManager()
    var studyApp:NSRunningApplication?,lastApp:NSRunningApplication?,lastOCR="",locationEnabled=false,lastLocation:Date = .distantPast
    var currentState="idle",stateToken=UUID(),highLoadSamples=0
    func applicationDidFinishLaunching(_ notification:Notification){
        if NSRunningApplication.runningApplications(withBundleIdentifier:Bundle.main.bundleIdentifier ?? "local.luna.LunaGuardian").contains(where:{$0.processIdentifier != ProcessInfo.processInfo.processIdentifier}){NSApp.terminate(nil);return}
        NSApp.setActivationPolicy(.accessory)
        try? fm.createDirectory(at:support,withIntermediateDirectories:true)
        writeJSON(["screenCaptureGranted":CGPreflightScreenCaptureAccess(),"checkedAt":Date().timeIntervalSince1970],"capabilities.json")
        muted=UserDefaults.standard.bool(forKey:"muted");studyEnabled = UserDefaults.standard.object(forKey:"studyPaused") != nil && !UserDefaults.standard.bool(forKey:"studyPaused")
        let opacity=UserDefaults.standard.double(forKey:"glassAlpha");popover.alphaValue=opacity>0 ? opacity:0.90
        monitorQueue.maxConcurrentOperationCount=1;monitorQueue.qualityOfService = .utility
        workerQueue.maxConcurrentOperationCount=1
        workerQueue.qualityOfService = .utility
        interactionQueue.maxConcurrentOperationCount=1;interactionQueue.qualityOfService = .userInitiated
        voiceQueue.maxConcurrentOperationCount=1;voiceQueue.qualityOfService = .utility
        pressureSource=DispatchSource.makeMemoryPressureSource(eventMask:[.warning,.critical,.normal],queue:.main)
        pressureSource?.setEventHandler{[weak self] in
            guard let self=self,let pressure=self.pressureSource else{return}
            self.criticalMode=pressure.data.contains(.critical);if pressure.data.contains(.critical){self.enterLightMode()}else if pressure.data.contains(.warning),!self.idleAppCare.attempt(){self.enterLightMode()};self.refreshMetrics()
        }
        pressureSource?.resume()
        companion.owner=self;popover.contentViewController=companion
        popover.contentSize=NSSize(width:340,height:380)
        let screen=NSScreen.main?.visibleFrame ?? NSRect(x:0,y:0,width:1200,height:800)
        var origin=NSPoint(x:screen.maxX-285,y:screen.minY+40)
        if UserDefaults.standard.object(forKey:"petX") != nil {origin=NSPoint(x:UserDefaults.standard.double(forKey:"petX"),y:UserDefaults.standard.double(forKey:"petY"));if !screen.intersects(NSRect(origin:origin,size:NSSize(width:240,height:240))){origin=NSPoint(x:screen.maxX-285,y:screen.minY+40)}}
        pet=PetPanel(contentRect:NSRect(origin:origin,size:NSSize(width:240,height:240)),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false);pet.isOpaque=false;pet.backgroundColor = .clear;pet.hasShadow=false;pet.level = .floating;pet.hidesOnDeactivate=false;pet.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.stationary]
        petView=PetView(frame:NSRect(x:0,y:0,width:240,height:240));petView.owner=self;pet.contentView=petView;pet.orderFrontRegardless();petView.startPointerInteraction()
        status=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength);status.button?.title="☾";status.button?.toolTip="露娜 · 电脑管家";status.menu=makeMenu()
        locationManager.delegate=self;locationManager.desiredAccuracy=kCLLocationAccuracyThreeKilometers;locationManager.distanceFilter=5000
        NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.didActivateApplicationNotification,object:nil,queue:.main){[weak self] note in guard let app=note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,app.bundleIdentifier != Bundle.main.bundleIdentifier else{return};self?.lastApp=app;self?.idleAppCare.used(app);self?.scheduleAutomaticStudy()}
        lastApp=NSWorkspace.shared.frontmostApplication
        repoTimer=Timer.scheduledTimer(withTimeInterval:90,repeats:true){[weak self]_ in self?.checkRepository()}
        metricsTimer=Timer.scheduledTimer(withTimeInterval:90,repeats:true){[weak self]_ in self?.refreshMetrics()}
        weatherTimer=Timer.scheduledTimer(withTimeInterval:900,repeats:true){[weak self]_ in self?.refreshWeather()}
        studyTimer=Timer.scheduledTimer(withTimeInterval:30,repeats:true){[weak self]_ in if self?.studyEnabled==true{self?.study(manual:false)}}
        focusTimer=Timer.scheduledTimer(withTimeInterval:1,repeats:true){[weak self]_ in self?.tickFocus()}
        let saved=UserDefaults.standard.double(forKey:"petSize")
        resizePet(saved>0 ? CGFloat(saved):220)
        petView.say("我在这里。点我说话，右键还有更多。",seconds:7)
        life=LunaLife(self);_ = idleAppCare
        refreshMetrics();checkRepository()
        for name in [NSWorkspace.didWakeNotification,NSWorkspace.screensDidWakeNotification,NSWorkspace.sessionDidBecomeActiveNotification]{
            NSWorkspace.shared.notificationCenter.addObserver(forName:name,object:nil,queue:.main){[weak self] _ in self?.requestDailyGreeting()}
        }
        dailyTimer=Timer.scheduledTimer(withTimeInterval:15,repeats:true){[weak self] _ in self?.tickDailyPresentation()}
        var priorCards=readJSON("task-cards.json")["items"] as? [[String:Any]] ?? []
        for i in priorCards.indices where priorCards[i]["outcome"] as? String=="进行中"{priorCards[i]["outcome"]="应用重启，未确认完成"}
        writeJSON(["items":priorCards],"task-cards.json")
        tickDailyPresentation()
        requestDailyGreeting()
        scheduleAutomaticStudy()
        fadeTimer=Timer.scheduledTimer(withTimeInterval:2,repeats:true){[weak self] _ in
            guard let self=self else{return}
            self.checkObservationWindow()
            let near=self.pet.frame.insetBy(dx:-20,dy:-20).contains(NSEvent.mouseLocation)
            if near || self.popover.isShown || self.fortuneBusy || self.audio?.isPlaying==true || self.currentState != "idle" {self.lastPetNear=Date()}
            let opacity:Float=Date().timeIntervalSince(self.lastPetNear)>10 ? 0.65:1
            CATransaction.begin();CATransaction.setAnimationDuration(0.22);self.petView.character.opacity=opacity;CATransaction.commit()
        }
    }
    func showDashboard(){
        if popover.isShown {popover.close();return}
        pet.orderFrontRegardless();NSApp.activate(ignoringOtherApps:true)
        popover.show(relativeTo:petView.character.frame,of:petView,preferredEdge:.minX)
    }
    func resizePet(_ requested:CGFloat){
        petSize=min(360,max(140,requested));UserDefaults.standard.set(Double(petSize),forKey:"petSize")
        let w=max(260,petSize+60),h=petSize*208/192+92
        var frame=NSRect(origin:pet.frame.origin,size:NSSize(width:w,height:h))
        let screen=pet.screen?.visibleFrame ?? NSScreen.main!.visibleFrame
        frame.origin.x=min(max(screen.minX,frame.minX),screen.maxX-w)
        frame.origin.y=min(max(screen.minY,frame.minY),screen.maxY-h)
        pet.setFrame(frame,display:true);petView.frame=NSRect(origin:.zero,size:frame.size)
        CATransaction.begin();CATransaction.setDisableActions(true)
        petView.character.frame=CGRect(x:(w-petSize)/2,y:4,width:petSize,height:petSize*208/192)
        petView.bubble.frame=CGRect(x:8,y:h-82,width:w-16,height:76)
        petView.readingSubtitle.frame=petView.bubble.frame
        petView.unreadBadge.frame=NSRect(x:w-56,y:petSize*0.35,width:50,height:32)
        petView.prop.frame=CGRect(x:w/2+petSize*0.17,y:petSize*0.22,width:65,height:70)
        CATransaction.commit();petView.refreshScene()
        if companion.isViewLoaded{companion.slider.doubleValue=Double(petSize)}
    }
    func nativeCall(_ action:String,_ payload:[String:Any]=[:],completion:@escaping([String:Any])->Void){
        let id=UUID().uuidString;callbacks[id]=completion;performAction(id,action,payload)
    }
    @objc func showPanel(){showDashboard()}
    @objc func openCodex(){routeCodex("")}
    @objc func wave(){animate("wave",text:"在这里。有什么需要我帮忙的？",seconds:4)}
    @objc func hidePet(){pet.isVisible ? pet.orderOut(nil):pet.orderFrontRegardless()}
    @objc func quit(){center?.coffee?.terminate();audio?.stop();audioTask?.terminate();NSApp.terminate(nil)}
    func makeMenu()->NSMenu {
        let m=NSMenu()
        func add(_ title:String,_ action:String,to menu:NSMenu){let i=NSMenuItem(title:title,action:#selector(menuAction(_:)),keyEquivalent:"");i.target=self;i.representedObject=action;menu.addItem(i)}
        add("☾ 和露娜说话","chat",to:m)
        for (title,items) in [
            ("日常陪伴",[("看看天气","weather"),("抽一支签","fortune"),("一起吃点东西","eat"),("专注 25 分钟","focusStart"),("结束专注","focusStop"),("自主生活","world")]),
            ("读书与任务",[("读书手记与留言","readingNotebook"),("长期记忆","memoryNotebook"),("任务清单","taskNotebook"),("文字与学习工具","tools")]),
            ("电脑照看",[("电脑状态","care"),("照看红线","guardSettings")]),
            ("模型与联网",[("LLM 服务与模型","openModelSettings"),("交代一件事","codex"),("打开 Tailscale","openTailscale")]),
            ("外观与语音",[("放大一点","larger"),("标准大小","standard"),("缩小一点","smaller"),("气泡更通透","glassLight"),("气泡更清晰","glassClear"),(muted ? "打开语音":"静音","toggleMute")]),
            ("系统设置",[(studyEnabled ? "暂停屏幕陪伴":"开启屏幕陪伴","toggleStudy"),("跟随当前窗口","followStudy"),("只看刚才的应用","bindStudy"),("日常提醒设置","routineSettings"),("使用系统定位","startLocation"),("暂停定位","stopLocation"),("固定大阪东淀川区","fixedLocation"),("切换开机启动","toggleLogin")])
        ] {let sub=NSMenu();for pair in items{add(pair.0,pair.1,to:sub)};let item=NSMenuItem(title:title,action:nil,keyEquivalent:"");item.submenu=sub;m.addItem(item)}
        m.addItem(.separator());add("显示 / 隐藏露娜","togglePet",to:m);add("退出露娜","quit",to:m);return m
    }
    @objc func menuAction(_ sender:NSMenuItem){
        guard let action=sender.representedObject as? String else{return}
        switch action {
        case "care":openCenter()
        case "tools":openCenter(1)
        case "world":openCenter(2)
        case "glassLight":UserDefaults.standard.set(0.78,forKey:"glassAlpha");companion.updateSurface()
        case "glassClear":UserDefaults.standard.set(0.96,forKey:"glassAlpha");companion.updateSurface()
        case "guardSettings":guardSettings()
        case "readingNotebook":showNotebook(0)
        case "memoryNotebook":showNotebook(1)
        case "taskNotebook":showNotebook(2)
        case "larger":resizePet(petSize+20)
        case "smaller":resizePet(petSize-20)
        case "standard":resizePet(220)
        case "eat":life?.stopWalking();animate("idle",seconds:12);petView.sceneKind="eat";petView.refreshScene();petView.say("嗯……先好好吃一口。",seconds:8)
        case "routineSettings":routines.settings()
        case "reminderDone":routines.respond("done")
        case "reminderLater":routines.respond("later")
        case "reminderSkip":routines.respond("skip")
        case "wave":wave()
        case "chat":if !popover.isShown{showDashboard()};companion.showChat()
        default:
            if ["guardReports","weather","fortune","metrics","scan","restore","security","focusStart","focusStop","bindStudy","toggleStudy"].contains(action),!popover.isShown{showDashboard()}
            companion.perform(action)
        }
        status.menu=makeMenu()
    }
    func event(_ kind:String,_ data:[String:Any]){if kind=="study"{var d=data;d.removeValue(forKey:"preview");d["at"]=Date().timeIntervalSince1970;writeJSON(d,"screen-observation.json")};companion.receive(kind,data);if kind=="metrics"{center?.refreshMetrics()}}
    func reply(_ id:String,_ value:Any,ok:Bool=true){
        let obj:[String:Any]=ok ? ["ok":true,"data":value]:["ok":false,"error":value]
        callbacks.removeValue(forKey:id)?(obj)
    }
    func foregroundWindow(_ pid:pid_t)->CGWindowID?{
        let rows=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] ?? []
        return rows.first{($0[kCGWindowOwnerPID as String] as? Int)==Int(pid) && ($0[kCGWindowLayer as String] as? Int)==0 && (($0[kCGWindowBounds as String] as? [String:Any])?["Width"] as? Double ?? 0)>120}?[kCGWindowNumber as String] as? CGWindowID
    }
    func checkObservationWindow(){
        guard let pid=observedPID,let window=observedWindow,NSWorkspace.shared.frontmostApplication?.processIdentifier==pid else{return}
        if foregroundWindow(pid) != window{cancelObservation();event("study",["status":"已切换窗口，旧回应已取消"])}
    }
    func cancelObservation(){
        observationGeneration=UUID();observedWindow=nil;observedPID=nil
        for (_,entry) in scopedProcesses where entry.1=="study" {if entry.0.isRunning{entry.0.terminate()}}
        if observationSpeech{speechGeneration=UUID();audio?.stop();observationSpeech=false}
    }
    func cancelCurrentTurn(){
        turnGeneration=UUID();cancelObservation();speechGeneration=UUID();audio?.stop()
        for (_,entry) in scopedProcesses where ["chat","voiceLine","speak"].contains(entry.1){if entry.0.isRunning{entry.0.terminate()}}
    }
    func taskCard(_ id:String,_ title:String,_ state:String,_ seconds:Double=0){
        var rows=readJSON("task-cards.json")["items"] as? [[String:Any]] ?? []
        rows.removeAll{($0["id"] as? String)==id}
        let card:[String:Any]=["id":id,"tool":title,"outcome":state,"seconds":Int(seconds),"at":Date().timeIntervalSince1970]
        rows.insert(card,at:0);writeJSON(["items":Array(rows.prefix(100))],"task-cards.json")
        if state=="进行中"{visibleTaskID=id}
        if visibleTaskID==id{companion.receive("task",card)}
    }
    func run(_ action:String,_ payload:[String:Any]=[:],completion:@escaping([String:Any])->Void){
        let queue=["metrics","codexCancel"].contains(action) ? monitorQueue:action=="speak" ? voiceQueue:["chat","assist","study","codexSubmit"].contains(action) ? interactionQueue:workerQueue
        guard queue.operationCount<4 else{completion(["ok":false,"error":"我正忙着处理前面的事，请稍等一下。"]);return}
        if action=="notebook",let op=payload["op"] as? String,op != "list"{cancelCurrentTurn()}
        let token=turnGeneration,observation=observationGeneration,ident=UUID(),started=Date()
        let scoped=["chat","study","voiceLine","speak","codexSubmit"].contains(action)
        let titles=["chat":"回应你的消息","assist":"学习工具处理","scan":"扫描旧缓存","clean":"移入恢复区","restore":"恢复文件","security":"检查系统保护","notebook":"读取或保存手记","weather":"查询天气"]
        let title=titles[action]
        if let title=title{taskCard(ident.uuidString,title,"进行中")}
        func valid()->Bool{!scoped || (self.turnGeneration==token && (action != "study" || self.observationGeneration==observation))}
        let operation=BlockOperation {
            let p=Process();p.executableURL=URL(fileURLWithPath:"/usr/bin/python3");p.arguments=[resources.appendingPathComponent("backend.py").path]
            let input=Pipe(),output=Pipe();p.standardInput=input;p.standardOutput=output;p.standardError=FileHandle.nullDevice
            var result:[String:Any]=["ok":false,"cancelled":true,"error":"本次回应已取消。"]
            do {
                var admitted=false
                try DispatchQueue.main.sync{if valid(){try p.run();if scoped{self.scopedProcesses[ident]=(p,action)};admitted=true}}
                if admitted {
                    let timeout=DispatchWorkItem{if p.isRunning{p.terminate()}};DispatchQueue.global(qos:.utility).asyncAfter(deadline:.now()+105,execute:timeout);defer{timeout.cancel()}
                    if let d=try? JSONSerialization.data(withJSONObject:["action":action,"payload":payload]){try? input.fileHandleForWriting.write(contentsOf:d)}
                    try? input.fileHandleForWriting.close();let d=output.fileHandleForReading.readDataToEndOfFile();p.waitUntilExit()
                    result=(try? JSONSerialization.jsonObject(with:d) as? [String:Any]) ?? ["ok":false,"error":"本地功能未返回结果。"]
                }
            }catch{result=["ok":false,"error":error.localizedDescription]}
            DispatchQueue.main.async{
                self.scopedProcesses.removeValue(forKey:ident)
                if !valid(){
                    if action=="codexSubmit",let data=result["data"] as? [String:Any],let handoff=data["handoff"] as? [String:Any],let job=handoff["id"] as? String,job.range(of:"^[a-f0-9]{32}$",options:.regularExpression) != nil{writeJSON(["requested":Date().timeIntervalSince1970],"codex-jobs/"+job+"/cancel.json")}
                    result=["ok":false,"cancelled":true,"error":"本次回应已取消，旧内容不会继续播放。"]
                }
                if let title=title{self.taskCard(ident.uuidString,title,result["cancelled"] as? Bool==true ? "已取消":result["ok"] as? Bool==true ? "已完成":"未完成："+(result["error"] as? String ?? "未知原因"),Date().timeIntervalSince(started))}
                completion(result)
            }
        }
        operation.queuePriority = ["chat","assist","voiceLine"].contains(action) ? .veryHigh:.normal;queue.addOperation(operation)
    }
    func animate(_ state:String,text:String?=nil,seconds:Double=0){guard !fortuneBusy else{return};currentState=state;if !criticalMode{petView.setState(state)};let token=UUID();stateToken=token;if let text=text{petView.say(text);event("quote",["text":text]);maybeSpeak(text)};if seconds>0{DispatchQueue.main.asyncAfter(deadline:.now()+seconds){[weak self] in guard let self=self,self.stateToken==token else{return};if !self.criticalMode && !self.fortuneBusy{self.petView.setState("idle")};self.currentState="idle"}}}
    func checkRepository(){
        guard !repoBusy else{return};repoBusy=true
        run("repoWatch"){[weak self] r in
            guard let self=self else{return};self.repoBusy=false
            guard !self.isLocked(),!self.jobBusy,!self.popover.isShown,!self.fortuneBusy,
                  let d=r["data"] as? [String:Any],let rows=d["pending"] as? [[String:Any]],!rows.isEmpty else{return}
            let text=rows.count==1 ? (rows[0]["text"] as? String ?? "仓库有新动态。") : "仓库有 \(rows.count) 条新动态，Star 或留言更新了。到 GitHub 看看吧。"
            self.animate("happy",seconds:6);self.petView.say(text,seconds:24);self.life?.note(text)
            writeJSON(["at":Date().timeIntervalSince1970,"count":rows.count,"text":text],"github-notification-shown.json")
            self.run("repoAck",["ids":rows.compactMap{$0["id"] as? String}]){_ in}
        }
    }
    func refreshMetrics(){guard watching,!metricBusy else{return};metricBusy=true;run("metrics"){[weak self] r in guard let self=self else{return};self.metricBusy=false;guard let d=r["data"] as? [String:Any] else{return};self.lastMetrics=d;self.handleHealth(d["health"] as? [String:Any] ?? [:]);self.event("metrics",d);writeJSON(d,"last-metrics.json")}}
    func refreshWeather(){guard !resourceLimited,!weatherBusy else{return};weatherBusy=true;run("weather"){[weak self] r in guard let self=self else{return};self.weatherBusy=false;if let d=r["data"] as? [String:Any]{self.handleWeather(d)}else{self.event("toast",["text":r["error"] ?? "天气未更新"])}}}
    func handleWeather(_ d:[String:Any]){lastWeather=d;event("weather",d);let rawState=d["state"] as? String ?? "idle";let night=(d["current"] as? [String:Any])?["is_day"] as? Int == 0;let state=rawState=="sunny" && night ? "night":rawState;if !jobBusy{animate(state,seconds:12)};if ["storm","snow","hot","cold"].contains(state){let key="weatherVoice-"+state;let last=UserDefaults.standard.double(forKey:key);if Date().timeIntervalSince1970-last>21600,!muted,!isLocked(){if playVoice(state){UserDefaults.standard.set(Date().timeIntervalSince1970,forKey:key)}}}}
    func isLocked()->Bool{let info=CGSessionCopyCurrentDictionary() as? [String:Any];return info?["CGSSessionScreenIsLocked"] as? Bool ?? false}
    @discardableResult func playVoice(_ kind:String,animateCharacter:Bool=true)->Bool{guard !isLocked() else{return false};let url=resources.appendingPathComponent("voices/\(kind).wav");guard fm.fileExists(atPath:url.path),let a=try? AVAudioPlayer(contentsOf:url) else{event("toast",["text":"这段语音尚未准备好。"]);return false};audio?.stop();audio=a;a.delegate=self;a.volume=0.65;let captions=(try? Data(contentsOf:resources.appendingPathComponent("voices/captions.json"))).flatMap{try? JSONSerialization.jsonObject(with:$0) as? [String:[String:String]]};if let zh=captions?[kind]?["zh"]{if animateCharacter{animate(kind,text:zh,seconds:a.duration+2)}else{petView.say(zh,seconds:a.duration+1)}};let success=a.play();writeJSON(["kind":kind,"started":success,"at":Date().timeIntervalSince1970,"duration":a.duration],"voice-playback.json");return success}
    func audioPlayerDidFinishPlaying(_ player:AVAudioPlayer,successfully flag:Bool){var d=readJSON("voice-playback.json");d["finished"]=flag;d["finishedAt"]=Date().timeIntervalSince1970;writeJSON(d,"voice-playback.json")}
    var lastHandoffPoll=Date.distantPast,lastHandoffToken=""
    func pollHandoff(){
        guard Date().timeIntervalSince(lastHandoffPoll)>5 else{return};lastHandoffPoll=Date()
        let d=readJSON("codex-status.json"),id=d["id"] as? String ?? "",state=d["state"] as? String ?? ""
        guard !id.isEmpty else{return};let token=id+state+(d["summary"] as? String ?? "");guard token != lastHandoffToken else{return};lastHandoffToken=token
        let title="你交代的事",seconds=Date().timeIntervalSince1970-(d["started"] as? Double ?? d["created"] as? Double ?? Date().timeIntervalSince1970)
        if ["queued","running"].contains(state){taskCard("codex-"+id,title,"进行中",seconds);companion.hint.stringValue="我正在跟进这件事 · 你可以继续和我聊"}
        else{visibleTaskID="codex-"+id;taskCard("codex-"+id,title,state=="completed" ? "已完成":state=="cancelled" ? "已取消":"未完成",seconds)}
        if ["completed","failed","cancelled"].contains(state),UserDefaults.standard.string(forKey:"lastHandoffDelivered") != id+state{
            UserDefaults.standard.set(id+state,forKey:"lastHandoffDelivered")
            let summary=d["summary"] as? String ?? "没有收到结果"
            if !companion.messages.contains(summary){companion.messages+="露娜\n\(state=="completed" ? "你交代的事有结果了":"这件事还没有完成")：\n\(summary)\n\n"}
            if companion.isViewLoaded && !companion.chatBusy{companion.showChat()}
            petView.say(state=="completed" ? "你交代的事有结果了，点我看看。":"这件事暂时没办成，点我看看原因。",seconds:14)
        }
    }
    func routeCodex(_ prompt:String){if !popover.isShown{showDashboard()};companion.showChat();if prompt.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty{companion.input.placeholderString="直接告诉我想做什么…"}else{companion.input.stringValue="交给Codex："+prompt;companion.submit()}}

    func tickFocus(){pollHandoff();guard let end=focusEnd else{return};let n=max(0,Int(end.timeIntervalSinceNow));event("focus",["time":String(format:"%02d:%02d",n/60,n%60),"text":n>0 ? "露娜正在陪你专心。":"这一轮完成了，休息一下吧。"]);if n==0{focusEnd=nil;animate("happy",text:"这一轮完成了。做得不错，起来活动一下吧。",seconds:10)}}
    func settings(){event("settings",["muted":muted,"watch":watching,"login":fm.fileExists(atPath:loginPath.path)])}
    var loginPath:URL{fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/local.luna.lunaguardian.plist")}
    func toggleLogin(){do{if fm.fileExists(atPath:loginPath.path){try fm.removeItem(at:loginPath)}else{try fm.createDirectory(at:loginPath.deletingLastPathComponent(),withIntermediateDirectories:true);let plist:[String:Any]=["Label":"local.luna.lunaguardian","ProgramArguments":[Bundle.main.executableURL!.path,"--background"],"RunAtLoad":true,"ProcessType":"Interactive"];let d=try PropertyListSerialization.data(fromPropertyList:plist,format:.xml,options:0);try d.write(to:loginPath,options:.atomic)};settings()}catch{event("toast",["text":error.localizedDescription])}}
    func startLocation(){locationEnabled=true;locationManager.requestWhenInUseAuthorization();locationManager.startUpdatingLocation();event("location",["text":"正在请求系统定位；如弹出权限提示，请选择允许。"])}
    func locationManager(_ manager:CLLocationManager,didChangeAuthorization status:CLAuthorizationStatus){if locationEnabled && (status == .authorizedAlways || status == .authorized){manager.startUpdatingLocation()}else if status == .denied || status == .restricted{event("location",["text":"定位未获许可。仍使用指定城市，可在系统设置中开启定位。"])} }
    func locationManager(_ manager:CLLocationManager,didFailWithError error:Error){event("location",["text":"定位暂不可用，继续使用指定城市。"])}
    func locationManager(_ manager:CLLocationManager,didUpdateLocations locations:[CLLocation]){guard locationEnabled,let loc=locations.last,loc.horizontalAccuracy>=0,abs(loc.timestamp.timeIntervalSinceNow)<300,Date().timeIntervalSince(lastLocation)>600 else{return};lastLocation=Date();let lat=(loc.coordinate.latitude*10).rounded()/10,lon=(loc.coordinate.longitude*10).rounded()/10
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude:lat,longitude:lon)){[weak self] places,error in guard let self=self else{return};let city=places?.first?.locality ?? places?.first?.administrativeArea ?? "当前位置";self.run("location",["latitude":lat,"longitude":lon,"city":city]){_ in self.event("location",["text":"系统定位：\(city) · "+DateFormatter.localizedString(from:Date(),dateStyle:.none,timeStyle:.short)]);self.refreshWeather()}}
    }
    func scheduleAutomaticStudy(){
        cancelObservation()
        studyDebounce?.cancel()
        guard studyEnabled else{return}
        let task=DispatchWorkItem{[weak self] in guard let self=self,self.studyEnabled else{return};self.study(manual:false)}
        studyDebounce=task;DispatchQueue.main.asyncAfter(deadline:.now()+8,execute:task)
    }
    var captureSessionBlocked=false
    func study(manual:Bool){
        if captureSessionBlocked && !manual{return}
        if manual{captureSessionBlocked=false}
        if !manual && !studyEnabled{return}
        if !manual && (Date().timeIntervalSince(lastAutoStudy)<15 || Date().timeIntervalSince(lastScreenReply)<45){event("study",["status":"等待下一次检查 · 发言间隔至少45秒"]);return}
        guard !criticalMode,!studyBusy,!companion.chatBusy,!fortuneBusy,!isLocked() else{event("study",["status":isLocked() ? "锁屏中，暂停观察":companion.chatBusy ? "正在和你聊天，暂停观察":studyBusy ? "上一轮观察处理中":criticalMode ? "内存压力较高，观察暂缓":fortuneBusy ? "抽签动画进行中，稍后观察":"后台任务处理中（\(workerQueue.operationCount)项），稍后观察"]);return}
        let active=NSWorkspace.shared.frontmostApplication
        guard let app=studyApp ?? (manual ? lastApp:active),!app.isTerminated,app.bundleIdentifier != Bundle.main.bundleIdentifier else{return}
        if !manual && active?.processIdentifier != app.processIdentifier{return}
        // Avoid password managers and settings, even when automatic foreground following is enabled.
        let id=(app.bundleIdentifier ?? "").lowercased()
        if ["1password","bitwarden","keychain","systempreferences","keepass"].contains(where:id.contains){event("study",["status":"隐私窗口，跳过观察"]);return}
        guard llmConfigured() else{event("study",["status":"LLM 尚未连接，暂不观察"]);return}
        guard CGPreflightScreenCaptureAccess() else{
            if manual && !UserDefaults.standard.bool(forKey:"captureAsked"){UserDefaults.standard.set(true,forKey:"captureAsked");CGRequestScreenCaptureAccess()}
            event("study",["status":"屏幕录制许可不可用，观察暂停"]);return
        }

        if !manual{lastAutoStudy=Date()}
        let observation=observationGeneration
        observedPID=app.processIdentifier;observedWindow=foregroundWindow(app.processIdentifier)
        let windowID=observedWindow
        studyBusy=true;if manual{animate("think",seconds:8)}
        event("study",["status":"正在读取当前窗口","app":app.localizedName ?? "应用","manual":manual])
        SCShareableContent.getExcludingDesktopWindows(true,onScreenWindowsOnly:true){[weak self] content,error in
            guard let self=self else{return}
            guard let windows=content?.windows,let window=windows.first(where:{$0.owningApplication?.processID==app.processIdentifier && $0.windowID==windowID}) else{DispatchQueue.main.async{self.studyBusy=false;if error != nil{self.captureSessionBlocked=true};self.event("study",["status":"观察已暂停，可手动重试。没有取得可读窗口："+(error?.localizedDescription ?? "窗口不可见"),"app":app.localizedName ?? ""])};return}
            let config=SCStreamConfiguration();let scale=min(1.5,1600/window.frame.width);config.width=Int(window.frame.width*scale);config.height=Int(window.frame.height*scale);config.showsCursor=false
            SCScreenshotManager.captureImage(contentFilter:SCContentFilter(desktopIndependentWindow:window),configuration:config){[weak self] image,error in
                guard let self=self else{return};guard let image=image else{DispatchQueue.main.async{self.studyBusy=false;self.captureSessionBlocked=true;self.event("study",["status":"观察已暂停，可手动重试。截图未成功："+(error?.localizedDescription ?? "未知原因")])};return}
                self.recognizeScreen(image,app:app,manual:manual,observation:observation)
            }
        }
    }
    func recognizeScreen(_ image:CGImage,app:NSRunningApplication,manual:Bool,observation:UUID){
        DispatchQueue.global(qos:.utility).async{[weak self] in
            guard let self=self else{return};let req=VNRecognizeTextRequest();req.recognitionLanguages=["ja-JP","zh-Hans","en-US"];req.recognitionLevel = .accurate
            do{try VNImageRequestHandler(cgImage:image).perform([req])}catch{DispatchQueue.main.async{self.studyBusy=false;self.event("study",["status":"文字识别失败："+error.localizedDescription])};return}
            let excerpt=String((req.results ?? []).compactMap{$0.topCandidates(1).first?.string}.joined(separator:"\n").prefix(1200))
            DispatchQueue.main.async{
                guard self.observationGeneration==observation else{self.studyBusy=false;self.event("study",["status":"窗口或对话已变化，旧观察已取消"]);return}
                if excerpt.count<10 || (!manual && self.similarScreen(excerpt,self.lastOCR)){self.studyBusy=false;self.event("study",["status":"陪伴中 · 没有新内容，安静等你。","characters":excerpt.count,"app":app.localizedName ?? ""]);return}
                self.event("study",["status":"已识别窗口 · LLM正在想一句话","characters":excerpt.count,"app":app.localizedName ?? ""])
                self.run("study",["text":excerpt,"app":app.localizedName ?? "当前应用"]){r in
                    self.studyBusy=false
                    guard self.observationGeneration==observation else{self.event("study",["status":"窗口或对话已变化，旧回应已取消"]);return}
                    let stillHere=NSWorkspace.shared.frontmostApplication?.processIdentifier==app.processIdentifier || (manual && NSWorkspace.shared.frontmostApplication?.bundleIdentifier==Bundle.main.bundleIdentifier)
                    if !self.isLocked(),!self.criticalMode,!self.companion.chatBusy,stillHere,let d=r["data"] as? [String:Any],let text=d["answer"] as? String{
                        self.lastOCR=excerpt;self.lastScreenReply=Date();self.animate("tap",seconds:12);self.petView.say(text,seconds:15);self.observationSpeech=true;self.maybeSpeak(text,force:true);self.life?.lastLine=Date();self.life?.note("看了当前窗口，陪你聊了一句。")
                        self.event("study",["status":"陪伴中 · 自动检查30秒，发言至少间隔45秒","text":text,"app":app.localizedName ?? "","characters":excerpt.count,"manual":manual])
                    }else{self.event("study",["status":r["error"] ?? "窗口已经切换，本句不打扰你","app":app.localizedName ?? ""])}
                }
            }
        }
    }
    func similarScreen(_ a:String,_ b:String)->Bool{
        if a==b{return true};guard !b.isEmpty else{return false}
        let x=Set(a.split(separator:"\n").map(String.init)),y=Set(b.split(separator:"\n").map(String.init))
        return Double(x.intersection(y).count)/Double(max(1,x.union(y).count))>0.8
    }
    func modelSettings(){
        let old=readJSON("model.json"), alert=NSAlert()
        alert.messageText="LLM 连接设置"
        alert.informativeText="支持 OpenAI Chat Completions 兼容接口。可切换服务和模型；同一地址留空保留密钥，改变地址会清除旧密钥。无需密钥的本地服务也可连接。"
        alert.addButton(withTitle:"保存");alert.addButton(withTitle:"取消")
        let stack=NSStackView();stack.orientation = .vertical;stack.spacing=9;stack.frame=NSRect(x:0,y:0,width:440,height:160)
        let url=NSTextField(string:old["url"] as? String ?? "http://127.0.0.1:8000/v1")
        let model=NSTextField(string:old["model"] as? String ?? "")
        let key=NSSecureTextField(string:"")
        let clear=NSButton(checkboxWithTitle:"清除已保存的密钥（无密钥本地服务）",target:nil,action:nil)
        url.placeholderString="Base URL（包含 /v1）或完整 /chat/completions 地址";model.placeholderString="模型 ID";key.placeholderString="API Key（不会显示已有值）"
        [url,model,key].forEach{stack.addArrangedSubview($0);$0.widthAnchor.constraint(equalToConstant:440).isActive=true};stack.addArrangedSubview(clear)
        alert.accessoryView=stack
        if alert.runModal() == .alertFirstButtonReturn {
            let address=url.stringValue.trimmingCharacters(in:.whitespacesAndNewlines).trimmingCharacters(in:CharacterSet(charactersIn:"/"))
            guard let parsed=URLComponents(string:address),["http","https"].contains(parsed.scheme ?? ""),parsed.host != nil,parsed.user == nil,parsed.password == nil,!model.stringValue.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{event("toast",["text":"请填写有效 HTTP(S) 地址及模型 ID"]);return}
            var cfg=old
            if address != (old["url"] as? String ?? "").trimmingCharacters(in:CharacterSet(charactersIn:"/")) {cfg.removeValue(forKey:"api_key");cfg.removeValue(forKey:"extra_body")}
            cfg["url"]=address;cfg["model"]=model.stringValue.trimmingCharacters(in:.whitespacesAndNewlines)
            if clear.state == .on {cfg.removeValue(forKey:"api_key")} else if !key.stringValue.isEmpty {cfg["api_key"]=key.stringValue}
            writeJSON(cfg,"model.json");event("toast",["text":"LLM 配置已保存，下次请求立即生效。"])
        }
    }
    func performAction(_ id:String,_ action:String,_ payload:[String:Any]){var p=payload
        if action=="chat",let message=p["message"] as? String,message.range(of:"抽.{0,3}签|求签|今日签|今天.{0,3}签",options:.regularExpression) != nil,!message.contains("不要"),!message.contains("别抽") {
            let other=message.range(of:"(?:替|给|帮)(?!我|自己|本人).{1,12}(?:抽|求)",options:.regularExpression) != nil
            let row=dailyFortune(forOther:other)
            let answer=(other ? "这支是替别人抽的，不会改动你的今日签。":"你的今日签保留到凌晨 4 点，今天再问也是这一支。")+"\n"+(row["title"] ?? "签文暂不可用")+"："+(row["text"] ?? "")
            guard !fortuneBusy else{reply(id,"这支签还没收好，稍等一下。",ok:false);return}
            companion.refreshFortuneBanner()
            let animation=FortuneAnimation(owner:self,row:row){[weak self] _ in self?.reply(id,["answer":answer])};fortuneAnimation=animation;animation.start();return
        }
        switch action {
        case "ready":webReady=true;if !lastMetrics.isEmpty{event("metrics",lastMetrics)};if !lastWeather.isEmpty{event("weather",lastWeather)};settings();reply(id,[:])
        case "codex":routeCodex(p["prompt"] as? String ?? "");reply(id,[:])
        case "petAction":let s=p["state"] as? String ?? "wave";animate(s,text:s=="sleep" ? "我休息一会儿，看护还在。":"嗯，知道你在这里了。",seconds:6);reply(id,[:])
        case "fortune":drawFortune(id)
        case "focusStart":focusEnd=Date().addingTimeInterval(1500);animate("focus",text:"二十五分钟。先把这件事认真做好。",seconds:7);reply(id,[:])
        case "focusStop":focusEnd=nil;event("focus",["time":"25:00","text":"专注已结束。"]);reply(id,[:])
        case "toggleWatch":watching.toggle();settings();if watching{refreshMetrics()};reply(id,[:])
        case "togglePet":hidePet();reply(id,[:])
        case "toggleMute":speechGeneration=UUID();muted.toggle();UserDefaults.standard.set(muted,forKey:"muted");if muted{audio?.stop()};settings();reply(id,[:])
        case "toggleLogin":toggleLogin();reply(id,[:])
        case "voiceTest":maybeSpeak("不会让你勉强的。我就在你身边。",ja:"無理はさせない。ちゃんとそばにいる。",force:true);reply(id,[:])
        case "voiceDemo":_ = playVoice(p["kind"] as? String ?? "rain");reply(id,[:])
        case "startLocation":startLocation();reply(id,[:])
        case "stopLocation":locationEnabled=false;locationManager.stopUpdatingLocation();event("location",["text":"定位已暂停，保留上次城市。"]);reply(id,[:])
        case "fixedLocation":locationEnabled=false;locationManager.stopUpdatingLocation();writeJSON(["city":"大阪市东淀川区","latitude":34.7413,"longitude":135.5293,"source":"指定城市"],"weather.json");event("location",["text":"固定城市：大阪市东淀川区"]);refreshWeather();reply(id,[:])
        case "followStudy":studyApp=nil;studyEnabled=true;UserDefaults.standard.set(false,forKey:"studyPaused");study(manual:true);reply(id,[:])
        case "bindStudy":if let a=lastApp,a.bundleIdentifier != Bundle.main.bundleIdentifier{studyApp=a;event("study",["status":"已绑定：\(a.localizedName ?? "应用")。点击开启陪伴，或看一眼。"])}else{event("study",["status":"请先切换到当前应用，再回到这里绑定。"])};reply(id,[:])
        case "toggleStudy":cancelObservation();studyEnabled.toggle();UserDefaults.standard.set(!studyEnabled,forKey:"studyPaused");event("study",["status":studyEnabled ? "桌面陪伴已开启 · 切换窗口8秒后检查，定时30秒":"桌面陪伴已暂停"]);reply(id,[:])
        case "studyOnce":study(manual:true);reply(id,[:])
        case "openRecovery":let u=support.appendingPathComponent("Recovery");try? fm.createDirectory(at:u,withIntermediateDirectories:true);NSWorkspace.shared.open(u);reply(id,[:])
        case "openTailscale":let app=URL(fileURLWithPath:"/Applications/Tailscale.app");if fm.fileExists(atPath:app.path){NSWorkspace.shared.openApplication(at:app,configuration:NSWorkspace.OpenConfiguration(),completionHandler:nil)}else{NSWorkspace.shared.open(URL(string:"https://tailscale.com/download/mac")!)};reply(id,[:])
        case "openModelSettings":modelSettings();reply(id,[:])
        case "quit":reply(id,[:]);quit()
        case "codexSubmit","codexCancel","scan","clean","restore","security","chat","history","chatHistory","modelConfig","guardReports","guardConfig","weather":
            if action=="scan" && resourceLimited{reply(id,"电脑正在轻量照看模式，暂不启动扫描。",ok:false);return};if ["scan","clean","restore"].contains(action){guard !jobBusy else{reply(id,"另一个整理任务还在进行。",ok:false);return};jobBusy=true;p["active"]=NSWorkspace.shared.runningApplications.compactMap{$0.bundleIdentifier};let text=action=="scan" ? "又积了些灰？我先检查一下，别急着全扔。":action=="clean" ? "好吧，我来扫。重要的东西可别混进去。":"把东西放回原处，也是一门功夫。";animate(action=="scan" ? "scan":"clean",text:text)}
            if action=="chat"{cancelCurrentTurn();life?.lastTouch=Date();life?.stopWalking();animate("chat");petView.say("嗯，我在听。")}
            run(action,p){[weak self] r in guard let self=self else{return};if ["scan","clean","restore"].contains(action){self.jobBusy=false;self.animate(r["ok"] as? Bool==true ? "happy":"surprise",text:r["ok"] as? Bool==true ? "这一步完成了，结果在清单里。":"这一步没有完成，先看看提示。",seconds:5)};if action=="chat",r["cancelled"] as? Bool != true{if self.notebook?.window?.isVisible==true,self.notebook?.tabs.selectedSegment==1{self.notebook?.reload()};self.animate("wave",seconds:4);if let d=r["data"] as? [String:Any],let answer=d["answer"] as? String{self.maybeSpeak(answer)}};if action=="weather",let d=r["data"] as? [String:Any]{self.handleWeather(d)};self.reply(id,r["data"] ?? r["error"] ?? "未知结果",ok:r["ok"] as? Bool ?? false)}
        default:reply(id,"不支持的操作",ok:false)
        }
    }

}
let app=NSApplication.shared
let delegate=Guardian();app.delegate=delegate
app.run()

func llmConfigured()->Bool {let cfg=readJSON("model.json");return !(cfg["url"] as? String ?? "").isEmpty && !(cfg["model"] as? String ?? "").isEmpty}
