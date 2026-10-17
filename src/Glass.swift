import AppKit
final class GlassBubble: NSPanel {
    var contentSize=NSSize(width:340,height:300)
    var isShown:Bool {isVisible}
    private var outside:Any?
    override var canBecomeKey:Bool{true}
    init(){super.init(contentRect:.zero,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false);isOpaque=false;backgroundColor = .clear;hasShadow=true;level = .floating;isReleasedWhenClosed=false;hidesOnDeactivate=false;title="露娜 · 轻语";collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary];alphaValue=0.92}
    func show(relativeTo rect:NSRect,of view:NSView,preferredEdge:NSRectEdge){
        guard let host=view.window else{return}
        let screen=host.screen?.visibleFrame ?? NSScreen.main!.visibleFrame
        let x=host.frame.minX-contentSize.width-8
        let y=min(max(screen.minY+8,host.frame.midY-contentSize.height/2),screen.maxY-contentSize.height-8)
        setFrame(NSRect(x:x<screen.minX ? min(screen.maxX-contentSize.width,host.frame.maxX+8):x,y:y,width:contentSize.width,height:contentSize.height),display:true)
        host.addChildWindow(self,ordered:.above);makeKeyAndOrderFront(nil)
        if outside==nil{outside=NSEvent.addGlobalMonitorForEvents(matching:[.leftMouseDown,.rightMouseDown]){[weak self]_ in self?.close()}}
    }
    override func close(){parent?.removeChildWindow(self);orderOut(nil);if let monitor=outside{NSEvent.removeMonitor(monitor);outside=nil}}
}
final class LunaChip:NSButton {
    override func draw(_ dirtyRect:NSRect){
        if isHighlighted {NSColor.white.withAlphaComponent(0.18).setFill();NSBezierPath(roundedRect:bounds.insetBy(dx:1,dy:2),xRadius:9,yRadius:9).fill()}
        let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:11,weight:.medium),.foregroundColor:NSColor.white.withAlphaComponent(isEnabled ? 0.82:0.35)]
        let size=(title as NSString).size(withAttributes:attrs)
        (title as NSString).draw(at:NSPoint(x:(bounds.width-size.width)/2,y:(bounds.height-size.height)/2),withAttributes:attrs)
    }
}
