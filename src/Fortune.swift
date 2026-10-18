import AppKit
import QuartzCore

// A small, bounded Core Animation sequence: shake -> one stick -> fortune card.
final class FortuneAnimation {
    weak var owner:Guardian?
    let rig=CALayer(),cup=CALayer(),stick=CALayer(),card=CALayer()
    let row:[String:String]
    let completion:([String:Any])->Void
    init(owner:Guardian,row:[String:String],completion:@escaping([String:Any])->Void){self.owner=owner;self.row=row;self.completion=completion}
    func label(_ text:String,frame:CGRect,size:CGFloat,color:NSColor)->CATextLayer{
        let l=CATextLayer();l.frame=frame;l.string=text;l.font=NSFont.systemFont(ofSize:size,weight:.semibold);l.fontSize=size;l.contentsScale=2;l.alignmentMode = .center;l.foregroundColor=color.cgColor;return l
    }
    func start(){
        guard let owner=owner else{return};owner.life?.stopWalking();owner.speechGeneration=UUID();let pet=owner.petView!
        pet.scene.isHidden=true;owner.fortuneBusy=true;owner.stateToken=UUID();pet.prop.string="";pet.character.removeAllAnimations()
        rig.frame=pet.bounds;pet.layer?.addSublayer(rig);pet.character.opacity=1
        writeJSON(["phase":"shaking","title":row["title"] ?? "","at":Date().timeIntervalSince1970],"fortune-playback.json")
        pet.say("让我把这支签展开给你看。今天的签，不会偷偷换掉。",seconds:4)
        if owner.criticalMode{reveal();return}
        pet.playAction("draw",duration:3.8,indices:[0,1,2,3,2,3,4,5])
        DispatchQueue.main.asyncAfter(deadline:.now()+3.8){[weak self] in self?.reveal()}
    }
    func reveal(){
        guard let owner=owner else{return};stick.isHidden=true;cup.isHidden=true
        let title=row["title"] ?? "吉";let expression=row["expression"] ?? "wave"
        owner.petView.character.removeAllAnimations();owner.petView.character.transform=CATransform3DIdentity
        let resultIndex=["大吉":0,"中吉":1,"小吉":2,"吉":3,"凶":4][title] ?? 5;let frames=owner.petView.states["result"] ?? [];owner.petView.character.contents=frames.indices.contains(resultIndex) ? frames[resultIndex]:owner.petView.states[expression]?.first
        let colors:[String:NSColor]=["大吉":NSColor(calibratedRed:0.78,green:0.53,blue:0.18,alpha:1),"中吉":NSColor(calibratedRed:0.53,green:0.37,blue:0.72,alpha:1),"小吉":NSColor(calibratedRed:0.76,green:0.46,blue:0.56,alpha:1),"吉":NSColor(calibratedRed:0.31,green:0.58,blue:0.53,alpha:1)]
        let color=colors[title] ?? .systemPurple
        let frame=owner.petView.character.frame;card.frame=CGRect(x:frame.maxX-30,y:frame.minY+frame.height*0.32,width:52,height:91);card.backgroundColor=NSColor(calibratedRed:1,green:0.98,blue:0.92,alpha:0.98).cgColor;card.cornerRadius=6;card.borderWidth=1;card.borderColor=color.cgColor;card.shadowOpacity=0.12;card.shadowRadius=4
        card.addSublayer(label(title.map{String($0)}.joined(separator:"\n"),frame:CGRect(x:8,y:20,width:36,height:59),size:19,color:color))
        card.addSublayer(label("☾",frame:CGRect(x:12,y:4,width:28,height:18),size:12,color:color));rig.addSublayer(card)
        if !owner.criticalMode {let appear=CABasicAnimation(keyPath:"opacity");appear.fromValue=0;appear.toValue=1;appear.duration=0.3;card.add(appear,forKey:"reveal")}
        let voice=row["id"] ?? "";var spoken=false
        if !owner.muted{spoken=owner.playVoice(voice,animateCharacter:false)}
        if !spoken{owner.petView.say(row["zh"] ?? title,seconds:9)}
        writeJSON(["phase":"revealed","title":title,"expression":expression,"voice":voice,"playbackStarted":spoken,"at":Date().timeIntervalSince1970],"fortune-playback.json")
        completion(["title":title,"text":row["text"] ?? "","caption":row["zh"] ?? "","voice":voice])
        let wait=max(7,(owner.audio?.duration ?? 0)+1)
        DispatchQueue.main.asyncAfter(deadline:.now()+wait){[weak self] in self?.finish()}
    }
    func finish(){guard let owner=owner else{return};rig.removeFromSuperlayer();owner.fortuneBusy=false;owner.fortuneAnimation=nil;owner.petView.setState("idle");owner.petView.refreshScene()}
}
extension Guardian {
    static func weightedFortune(_ rows:[[String:String]],roll:Int)->[String:String]{
        let weights=["大吉":15,"中吉":30,"小吉":30,"吉":20,"凶":5];var cumulative=0
        for row in rows{cumulative += weights[row["title"] ?? ""] ?? 0;if roll<cumulative{return row}}
        return rows.last ?? [:]
    }

    func drawFortune(_ requestID:String,preview:String?=nil){
        guard !fortuneBusy else{reply(requestID,"这支签还没收好，稍等一下。",ok:false);return}
        guard let data=try? Data(contentsOf:resources.appendingPathComponent("fortunes.json")),let rows=try? JSONSerialization.jsonObject(with:data) as? [[String:String]],!rows.isEmpty else{reply(requestID,"签文资源未准备好。",ok:false);return}
        let selected=dailyFortune();companion.refreshFortuneBanner()
        let animation=FortuneAnimation(owner:self,row:selected){[weak self] result in self?.reply(requestID,result)};fortuneAnimation=animation;animation.start()
    }
}
