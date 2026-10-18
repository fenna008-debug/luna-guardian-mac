import AppKit
import ApplicationServices
import UniformTypeIdentifiers

func axValue(_ element:AXUIElement,_ name:String)->CFTypeRef?{var value:CFTypeRef?;guard AXUIElementCopyAttributeValue(element,name as CFString,&value) == .success else{return nil};return value}
func axChildren(_ element:AXUIElement)->[AXUIElement]{axValue(element,kAXChildrenAttribute) as? [AXUIElement] ?? []}
func axTitle(_ element:AXUIElement)->String{axValue(element,kAXTitleAttribute) as? String ?? ""}
extension Guardian {
    func musicControl(_ action:String)->String {
        guard ["play","pause","next","previous"].contains(action) else{return "不支持这项音乐操作。"}
        guard AXIsProcessTrusted() else{return "尚未控制网易云音乐。请在系统设置的辅助功能中允许露娜电脑管家控制应用；这是播放、暂停和切歌所需的权限。"}
        guard let app=NSRunningApplication.runningApplications(withBundleIdentifier:"com.netease.163music").first else{
            NSWorkspace.shared.openApplication(at:URL(fileURLWithPath:"/Applications/NeteaseMusic.app"),configuration:NSWorkspace.OpenConfiguration())
            return "已请求打开网易云音乐，尚未播放。等播放器打开后，再告诉我继续播放。"
        }
        let root=AXUIElementCreateApplication(app.processIdentifier);AXUIElementSetMessagingTimeout(root,1)
        guard let raw=axValue(root,kAXMenuBarAttribute) else{return "没有读到网易云音乐的控制菜单，尚未操作。"}
        let bar=unsafeBitCast(raw,to:AXUIElement.self)
        guard let control=axChildren(bar).first(where:{["控制","Controls"].contains(axTitle($0))}),let menu=axChildren(control).first else{return "当前网易云版本没有提供可用的控制菜单，尚未操作。"}
        let items=axChildren(menu)
        let playing=items.contains{["暂停","Pause"].contains(axTitle($0))}
        let paused=items.contains{["播放","Play"].contains(axTitle($0))}
        if action=="play" && playing{return "网易云音乐已经处于播放状态。"}
        if action=="pause" && paused{return "网易云音乐已经处于暂停状态。"}
        let names:[String:[String]]=["play":["播放","Play"],"pause":["暂停","Pause"],"next":["下一个","Next"],"previous":["上一个","Previous"]]
        guard let item=items.first(where:{names[action]!.contains(axTitle($0))}),(axValue(item,kAXEnabledAttribute) as? Bool)==true else{return "网易云音乐的这项控制当前不可用，请先选择歌曲。"}
        guard AXUIElementPerformAction(item,kAXPressAction as CFString) == .success else{return "网易云音乐没有接受操作，这次没有确认成功。"}
        return ["play":"已向网易云音乐发送播放指令。","pause":"已向网易云音乐发送暂停指令。","next":"已向网易云音乐发送下一首指令。","previous":"已向网易云音乐发送上一首指令。"][action]!
    }
    func pollAppActions(){
        let folder=support.appendingPathComponent("app-requests")
        guard !musicSearchBusy else{return}
        guard let files=try? fm.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil) else{return}
        for file in files.filter({$0.pathExtension=="json" && !$0.lastPathComponent.hasSuffix(".result.json")}).prefix(1){
            guard let data=try? Data(contentsOf:file),data.count<4096,let request=try? JSONSerialization.jsonObject(with:data) as? [String:Any] else{try? fm.removeItem(at:file);continue}
            let expires=request["expires"] as? Double ?? 0
            let action=request["action"] as? String ?? ""
            // Claim before execution: a cancelled/stale request must never run later.
            try? fm.removeItem(at:file)
            let output=folder.appendingPathComponent(file.deletingPathExtension().lastPathComponent+".result.json")
            let finish:(String)->Void={answer in if let d=try? JSONSerialization.data(withJSONObject:["answer":answer]){try? d.write(to:output,options:.atomic)}}
            if expires<=Date().timeIntervalSince1970{finish("音乐请求已过期，没有执行。")}
            else if action=="search_play"{searchMusic(request["query"] as? String ?? "",artist:request["artist"] as? String ?? "",expires:expires,finish:finish)}
            else{finish(musicControl(action))}
        }
    }
    func selectedMaterial(_ pasteboard:NSPasteboard,deep:Bool,error:AutoreleasingUnsafeMutablePointer<NSString?>){
        guard let text=pasteboard.string(forType:.string)?.trimmingCharacters(in:.whitespacesAndNewlines),!text.isEmpty else{error.pointee="没有取得选中文字。扫描版论文请先识别文字。";return}
        guard text.count<=6000 else{error.pointee="选区超过六千字，请按段处理，或从露娜菜单选择整篇论文精读。";return}
        cancelCurrentTurn();let token=turnGeneration;companion.chatBusy=true
        if !popover.isShown{showDashboard()}
        companion.text("已取得选中文字，正在"+(deep ? "交给 Codex 精读。":"翻译。"),title:"论文选区")
        run(deep ? "paperRead":"assist",deep ? ["text":text]:["kind":"translate_zh","text":text]){[weak self] r in
            guard let self=self,self.turnGeneration==token else{return}
            self.companion.chatBusy=false
            let answer=(r["data"] as? [String:Any])?["answer"] as? String ?? r["error"] as? String ?? "没有取得结果。"
            self.companion.text(answer,title:deep ? "论文精读任务":"中文翻译 · 请对照原文")
        }
    }
    @objc func translateSelection(_ pasteboard:NSPasteboard,userData:String?,error:AutoreleasingUnsafeMutablePointer<NSString?>){selectedMaterial(pasteboard,deep:false,error:error)}
    @objc func readSelection(_ pasteboard:NSPasteboard,userData:String?,error:AutoreleasingUnsafeMutablePointer<NSString?>){selectedMaterial(pasteboard,deep:true,error:error)}
    func choosePaper(){
        let panel=NSOpenPanel();panel.allowedContentTypes=[.pdf];panel.allowsMultipleSelection=false;panel.message="选择要交给 Codex 总结与精读的论文"
        guard panel.runModal() == .OK,let url=panel.url else{return}
        run("paperRead",["path":url.path]){[weak self] r in
            guard let self=self else{return};if !self.popover.isShown{self.showDashboard()}
            self.companion.text((r["data"] as? [String:Any])?["answer"] as? String ?? r["error"] as? String ?? "没有提交成功。",title:"论文精读任务")
        }
    }
}
