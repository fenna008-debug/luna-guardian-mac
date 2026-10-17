import AppKit

final class LunaNotebook:NSWindowController {
    weak var guardian:Guardian?
    let tabs=NSSegmentedControl(labels:["读书手记","记忆","任务清单"],trackingMode:.selectOne,target:nil,action:nil)
    let picker=NSPopUpButton(),body=NSTextView(),edit=NSTextField(),status=NSPopUpButton(),hint=NSTextField(labelWithString:"")
    let add=NSButton(title:"添加",target:nil,action:nil),change=NSButton(title:"保存修改",target:nil,action:nil),remove=NSButton(title:"删除",target:nil,action:nil),source=NSButton(title:"打开原文",target:nil,action:nil)
    var rows:[[String:Any]]=[]
    var kind:String {tabs.selectedSegment==1 ? "memory":"task"}
    init(_ guardian:Guardian){
        self.guardian=guardian
        let w=NSPanel(contentRect:NSRect(x:0,y:0,width:600,height:580),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        w.title="露娜的手记";w.isReleasedWhenClosed=false;w.backgroundColor=NSColor(calibratedRed:0.97,green:0.95,blue:0.91,alpha:1);w.appearance=NSAppearance(named:.aqua)
        super.init(window:w);let root=w.contentView!
        tabs.frame=NSRect(x:24,y:526,width:552,height:30);tabs.target=self;tabs.action=#selector(reload);root.addSubview(tabs)
        picker.frame=NSRect(x:24,y:478,width:552,height:30);picker.target=self;picker.action=#selector(select);root.addSubview(picker)
        let scroll=NSScrollView(frame:NSRect(x:24,y:164,width:552,height:298));scroll.hasVerticalScroller=true;scroll.borderType = .noBorder;scroll.drawsBackground=false
        body.isEditable=false;body.isSelectable=true;body.isRichText=false;body.font = .systemFont(ofSize:15);body.textColor=NSColor(calibratedWhite:0.20,alpha:1);body.backgroundColor=w.backgroundColor;body.textContainerInset=NSSize(width:16,height:18);body.isVerticallyResizable=true;body.isHorizontallyResizable=false;body.autoresizingMask = [.width];body.textContainer?.widthTracksTextView=true;body.frame=NSRect(x:0,y:0,width:552,height:298);scroll.documentView=body;root.addSubview(scroll)
        edit.frame=NSRect(x:24,y:116,width:552,height:32);edit.placeholderString="写下想记住的事，或添加待办任务";root.addSubview(edit)
        status.frame=NSRect(x:24,y:70,width:124,height:28);status.addItems(withTitles:["待办","进行中","完成"]);root.addSubview(status)
        for (i,b) in [add,change,remove,source].enumerated(){b.frame=NSRect(x:CGFloat(158+i*104),y:70,width:100,height:30);b.bezelStyle = .rounded;b.target=self;root.addSubview(b)}
        add.action=#selector(addItem);change.action=#selector(updateItem);remove.action=#selector(deleteItem);source.action=#selector(openSource)
        hint.frame=NSRect(x:24,y:20,width:552,height:36);hint.font = .systemFont(ofSize:11);hint.textColor = .secondaryLabelColor;hint.maximumNumberOfLines=2;root.addSubview(hint);w.center()
    }
    required init?(coder:NSCoder){fatalError()}
    func show(_ section:Int=0){tabs.selectedSegment=section;reload();window?.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)}
    @objc func reload(){
        let section=tabs.selectedSegment
        edit.isHidden=section==0 || section==3;status.isHidden=section != 2;add.isHidden=section==0 || section==3;change.isHidden=section==0 || section==3;remove.isHidden=section==0;source.isHidden=section != 0
        remove.title=section==3 ? "清空记录":"删除"
        if section==0 {
            let data=try? Data(contentsOf:support.appendingPathComponent("reading-log.json"));rows=(data.flatMap{try? JSONSerialization.jsonObject(with:$0)} as? [[String:Any]]) ?? []
            hint.stringValue="只记录实际取得的节选；感想与原文分开显示。点击标题可查看此前的阅读。";fill()
        } else if section==3 {
            let d=readJSON("tool-events.json");rows=d["items"] as? [[String:Any]] ?? [];hint.stringValue="仅记录工具名称、结果和耗时，不显示参数。保留 7 天，最多 100 条。";fill()
        } else {
            hint.stringValue=section==1 ? "明确保存的记忆才进入长期记忆；可以修改或删除。":"待办不代表已执行。仅按实际结果或你的确认标为完成。"
            guardian?.run("notebook",["op":"list","kind":kind]){[weak self] r in guard let self=self,self.tabs.selectedSegment==section else{return};self.rows=(r["data"] as? [String:Any])?["items"] as? [[String:Any]] ?? [];self.fill()}
        }
    }
    func fill(){picker.removeAllItems();for (i,r) in rows.enumerated(){let title=(r["title"] as? String) ?? (r["text"] as? String) ?? (r["tool"] as? String) ?? "记录";picker.addItem(withTitle:"\(i+1). "+String(title.prefix(52)))};select()}
    @objc func select(){
        guard rows.indices.contains(picker.indexOfSelectedItem) else{body.string=tabs.selectedSegment==0 ? "她还没有留下阅读手记。取得正文后，这里会出现出处和感想。":"暂时没有记录。";edit.stringValue="";return}
        let r=rows[picker.indexOfSelectedItem]
        if tabs.selectedSegment==0 {body.string=(r["title"] as? String ?? "")+"\n"+(r["scope"] as? String ?? "")+"\n\n露娜的感想\n"+(r["reflection"] as? String ?? "未生成")+"\n\n原文节选\n"+(r["quote"] as? String ?? "")+"\n\n来源\n"+(r["url"] as? String ?? "")}
        else if tabs.selectedSegment==3 {body.string=(r["tool"] as? String ?? "工具")+"\n结果："+(r["outcome"] as? String ?? "未知")+"\n耗时：\(r["seconds"] ?? 0) 秒\n时间："+DateFormatter.localizedString(from:Date(timeIntervalSince1970:r["at"] as? Double ?? 0),dateStyle:.medium,timeStyle:.medium)}
        else {edit.stringValue=r["text"] as? String ?? "";body.string=edit.stringValue;let values=["pending","in_progress","done"];status.selectItem(at:values.firstIndex(of:r["status"] as? String ?? "pending") ?? 0)}
    }
    func mutate(_ op:String){var p:[String:Any]=["op":op,"kind":kind,"text":edit.stringValue];if op != "add" {guard rows.indices.contains(picker.indexOfSelectedItem) else{return};p["id"]=rows[picker.indexOfSelectedItem]["id"]};p["status"]=kind=="memory" ? "saved":["pending","in_progress","done"][max(0,status.indexOfSelectedItem)];guardian?.run("notebook",p){[weak self] r in if r["ok"] as? Bool==true{self?.reload()}else{self?.hint.stringValue=r["error"] as? String ?? "未保存"}}}
    @objc func addItem(){mutate("add")}
    @objc func updateItem(){mutate("update")}
    @objc func deleteItem(){if tabs.selectedSegment==3{writeJSON(["items":[]],"tool-events.json");reload()}else{mutate("delete")}}
    @objc func openSource(){guard rows.indices.contains(picker.indexOfSelectedItem),let raw=rows[picker.indexOfSelectedItem]["url"] as? String,let url=URL(string:raw),["http","https"].contains(url.scheme ?? "") else{return};NSWorkspace.shared.open(url)}
}
