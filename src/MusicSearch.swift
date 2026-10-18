import AppKit
import ApplicationServices

private func musicText(_ e:AXUIElement)->String {
    let text=axTitle(e).isEmpty ? (axValue(e,kAXValueAttribute) as? String ?? axValue(e,kAXDescriptionAttribute) as? String ?? "") : axTitle(e)
    if text.isEmpty,axValue(e,kAXRoleAttribute) as? String == "AXHeading" {return axChildren(e).map{musicText($0)}.joined()}
    return text
}
private func musicNodes(_ root:AXUIElement)->[AXUIElement]{
    var result:[AXUIElement]=[]
    func walk(_ e:AXUIElement,_ depth:Int){guard depth<24,result.count<2200 else{return};result.append(e);for c in axChildren(e){walk(c,depth+1)}}
    walk(root,0);return result
}
private func songKey(_ s:String)->String{s.folding(options:[.caseInsensitive,.widthInsensitive],locale:nil).filter{!$0.isWhitespace && !"《》“”\"".contains($0)}}
private func musicDoubleClick(_ e:AXUIElement,_ app:NSRunningApplication)->Bool {
    guard let p=axValue(e,kAXPositionAttribute),let s=axValue(e,kAXSizeAttribute) else{return false}
    var point=CGPoint.zero;var size=CGSize.zero
    guard AXValueGetValue(unsafeBitCast(p,to:AXValue.self),.cgPoint,&point),AXValueGetValue(unsafeBitCast(s,to:AXValue.self),.cgSize,&size),size.width>0,size.height>0 else{return false}
    point.x+=min(30,size.width/2);point.y+=size.height/2
    guard NSScreen.screens.contains(where:{$0.frame.intersects(CGRect(origin:point,size:CGSize(width:1,height:1)))}) else{return false}
    guard NSWorkspace.shared.frontmostApplication?.processIdentifier==app.processIdentifier else{return false}
    CGEvent(mouseEventSource:nil,mouseType:.mouseMoved,mouseCursorPosition:point,mouseButton:.left)?.post(tap:.cghidEventTap)
    for count in 1...2 {
        guard let down=CGEvent(mouseEventSource:nil,mouseType:.leftMouseDown,mouseCursorPosition:point,mouseButton:.left),let up=CGEvent(mouseEventSource:nil,mouseType:.leftMouseUp,mouseCursorPosition:point,mouseButton:.left) else{return false}
        down.setIntegerValueField(.mouseEventClickState,value:Int64(count));up.setIntegerValueField(.mouseEventClickState,value:Int64(count))
        down.post(tap:.cghidEventTap);up.post(tap:.cghidEventTap)
    }
    return true
}
extension Guardian {
    func searchMusic(_ query:String,artist:String,expires:Double,finish:@escaping(String)->Void){
        guard !query.isEmpty,query.count<=120,artist.count<=80 else{finish("请告诉我具体歌名，可写：播放银临的《牵丝戏》。");return}
        guard AXIsProcessTrusted() else{finish("还没有搜索播放。请先为露娜开启辅助功能权限。");return}
        musicSearchBusy=true
        let done:(String)->Void={[weak self] answer in self?.musicSearchBusy=false;finish(answer)}
        func begin(_ app:NSRunningApplication){
            let root=AXUIElementCreateApplication(app.processIdentifier);AXUIElementSetMessagingTimeout(root,0.4)
            app.activate(options:[])
            let nodes=musicNodes(root)
            guard let field=nodes.first(where:{axValue($0,kAXRoleAttribute) as? String == kAXTextFieldRole}) else{done("没有找到网易云搜索框，这次没有播放。");return}
            let keyword=artist.isEmpty ? query : artist+" "+query
            AXUIElementSetAttributeValue(field,kAXFocusedAttribute as CFString,kCFBooleanTrue)
            func key(_ code:CGKeyCode,_ flags:CGEventFlags=[]){for down in [true,false]{let e=CGEvent(keyboardEventSource:nil,virtualKey:code,keyDown:down);e?.flags=flags;e?.postToPid(app.processIdentifier)}}
            DispatchQueue.main.asyncAfter(deadline:.now()+0.3){
                guard NSWorkspace.shared.frontmostApplication?.processIdentifier==app.processIdentifier else{done("搜索已停止：你切换了应用，没有继续输入。");return}
                AXUIElementSetAttributeValue(field,kAXFocusedAttribute as CFString,kCFBooleanTrue)
                AXUIElementSetAttributeValue(field,kAXValueAttribute as CFString,"" as CFString)
                key(0,.maskCommand)
                DispatchQueue.main.asyncAfter(deadline:.now()+0.15){
                    let chars=Array(keyword.utf16)
                    for down in [true,false]{let e=CGEvent(keyboardEventSource:nil,virtualKey:0,keyDown:down);e?.keyboardSetUnicodeString(stringLength:chars.count,unicodeString:chars);e?.postToPid(app.processIdentifier)}
                    DispatchQueue.main.asyncAfter(deadline:.now()+0.15){key(36)}
                }
            }
            var attempts=0;var chose=false;var firstTime=""
            func poll(){
                guard Date().timeIntervalSince1970<expires,attempts<28 else{done(chose ? "已经尝试播放《\(query)》，但未确认播放进度。请检查版权、登录或播放器提示。":"没有找到可核对的《\(query)》单曲，未播放其他歌曲。可以补充歌手，例如：播放银临的《牵丝戏》。");return}
                attempts+=1
                let ns=musicNodes(root)
                writeJSON(["query":query,"attempt":attempts,"selected":chose],"music-last-observation.json")
                if !chose {
                    // Only act on a fresh matching search page; avoid an old result during loading.
                    let labels=ns.map{musicText($0)}
                    let correct=labels.indices.contains{ i in labels[i]==keyword && i+1<labels.count && labels[i+1].contains("相关搜索") }
                    if correct,let tab=ns.first(where:{musicText($0)=="综合" && axValue($0,kAXRoleAttribute) as? String == "AXRadioButton"}), (axValue(tab,kAXValueAttribute) as? Int ?? 0)==0 {AXUIElementPerformAction(tab,kAXPressAction as CFString)}
                    if correct,let start=ns.firstIndex(where:{musicText($0)=="单曲" && axValue($0,kAXRoleAttribute) as? String == "AXHeading"}) {
                        let end=ns[(start+1)...].firstIndex(where:{axValue($0,kAXRoleAttribute) as? String == "AXHeading"}) ?? ns.endIndex
                        for i in (start+1)..<end where songKey(musicText(ns[i]))==songKey(query) {
                            if !artist.isEmpty {
                                let tail=ns[(i+1)..<min(i+9,end)].map{musicText($0)}.joined(separator:" ")
                                if !songKey(tail).contains(songKey(artist)){continue}
                            }
                            chose=musicDoubleClick(ns[i],app);break
                        }
                    }
                } else {
                    let pause=ns.firstIndex{musicText($0)=="pause" && axValue($0,kAXRoleAttribute) as? String == kAXButtonRole}
                    if let index=pause {
                        let before=ns[..<index].map{musicText($0)}.filter{!$0.isEmpty}.suffix(20)
                        let names=Array(before)
                        let titleOK=names.indices.contains{i in songKey(names[i])==songKey(query) && i+1<names.count && names[i+1]=="-"}
                        let artistOK=artist.isEmpty || names.contains{songKey($0).contains(songKey(artist))}
                        if !titleOK || !artistOK{DispatchQueue.main.asyncAfter(deadline:.now()+1,execute:poll);return}
                        let tail=ns[(index+1)..<min(ns.count,index+8)].map{musicText($0)}
                        if let stamp=tail.first(where:{$0.range(of:"^\\d{1,2}:\\d{2}$",options:.regularExpression) != nil}) {
                            if !firstTime.isEmpty,stamp != firstTime {done("正在网易云播放《\(query)》"+(artist.isEmpty ? "。":"（\(artist)）。")+"已核对歌曲与播放进度。");return}
                            firstTime=stamp
                        }
                    }
                }
                DispatchQueue.main.asyncAfter(deadline:.now()+1,execute:poll)
            }
            DispatchQueue.main.asyncAfter(deadline:.now()+1,execute:poll)
        }
        if let app=NSRunningApplication.runningApplications(withBundleIdentifier:"com.netease.163music").first{begin(app)}
        else{NSWorkspace.shared.openApplication(at:URL(fileURLWithPath:"/Applications/NeteaseMusic.app"),configuration:NSWorkspace.OpenConfiguration()){app,error in DispatchQueue.main.async{if let app=app{DispatchQueue.main.asyncAfter(deadline:.now()+2){begin(app)}}else{done("网易云音乐没有打开，这次没有播放。")}}}}
    }
}
