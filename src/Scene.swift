import AppKit
import QuartzCore
import ImageIO
import AVFoundation
extension PetView {
    // Decode once into small, bounded frames. No full-resolution sheet retained.
    func loadActions(){
        func row(_ name:String,_ y:Int,_ height:Int)->[CGImage]{
            guard let src=CGImageSourceCreateWithURL(resources.appendingPathComponent("actions/"+name+".png") as CFURL,nil),let sheet=CGImageSourceCreateImageAtIndex(src,0,nil) else{return []}
            let width=sheet.width/6
            return (0..<6).compactMap { col in
                guard let crop=sheet.cropping(to:CGRect(x:col*width+(name=="fortune" ? 18:0),y:y,width:width-(name=="fortune" ? 36:0),height:height)),let ctx=CGContext(data:nil,width:384,height:416,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return nil}
                let scale=min(368.0/Double(crop.width),404.0/Double(height));let w=Double(crop.width)*scale,h=Double(height)*scale
                ctx.interpolationQuality = .high;ctx.draw(crop,in:CGRect(x:(384-w)/2,y:6,width:w,height:h));return ctx.makeImage()
            }
        }
        states["tea"]=row("daily",0,512);states["book"]=row("daily",512,512)
        states["draw"]=row("fortune",0,480);states["result"]=row("fortune",480,420)
        if let src=CGImageSourceCreateWithURL(resources.appendingPathComponent("actions/meal.png") as CFURL,nil),let sheet=CGImageSourceCreateImageAtIndex(src,0,nil){
            // Atlas trim boxes measured from the generated alpha; align body centers and soles.
            states["eat"]=(0..<6).compactMap { i in
                let x=[141,600,1057,142,600,1058][i],y=i<3 ? 5:516
                guard let crop=sheet.cropping(to:CGRect(x:x,y:y,width:342,height:506)),let ctx=CGContext(data:nil,width:384,height:416,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return nil}
                ctx.interpolationQuality = .high;ctx.draw(crop,in:CGRect(x:55.5,y:6,width:273,height:404));return ctx.makeImage()
            }
        }
        // The original walk/look cycle stays consistent with the original mouse interaction.
    }
    func refreshScene(){
        scene.isHidden=true;scene.sublayers?.forEach{$0.removeFromSuperlayer()};scene.removeAllAnimations()
        guard !sceneKind.isEmpty,owner?.life?.enabled != false,owner?.fortuneBusy != true,!dragged,owner?.life?.walking != true,owner?.criticalMode != true else{return}
        playAction(sceneKind,duration:sceneKind=="eat" ? 6.6:sceneKind=="tea" ? 5.4:4.8)
    }
    func playAction(_ key:String,duration:Double,indices:[Int]?=nil){
        guard let all=states[key],!all.isEmpty else{return}
        let frames=(indices ?? Array(all.indices)).compactMap{all.indices.contains($0) ? all[$0]:nil};guard let last=frames.last else{return}
        lookIndex = -1;character.removeAllAnimations();prop.string="";character.contents=last
        guard owner?.criticalMode != true else{return}
        let a=CAKeyframeAnimation(keyPath:"contents");a.values=frames;a.duration=duration;a.calculationMode = .discrete;a.repeatCount=1;character.add(a,forKey:"dailyAction")
    }
}
extension Guardian {
    func maybeSpeak(_ text:String,ja:String?=nil,force:Bool=false,readingHash:String?=nil){
        // Every dialogue category shares this one admission gate; no synthesis backlog.
        guard !muted,!criticalMode,!speechBusy,!isLocked(),(force || Date().timeIntervalSince(lastSpeech)>180),(force || Int.random(in:0..<100)<45),audio?.isPlaying != true else{return}
        if ja==nil && !llmConfigured(){return}
        lastSpeech=Date();speechBusy=true;let token=speechGeneration
        func synth(_ line:[String:Any]){
            guard self.speechGeneration==token,!self.muted,!self.criticalMode,!self.isLocked() else{self.speechBusy=false;return}
            self.run("speak",line){[weak self] r in
                guard let self=self else{return};self.speechBusy=false
                if r["ok"] as? Bool != true{let error=r["error"] as? String ?? "语音未完成";writeJSON(["kind":"dialogue","started":false,"error":error,"at":Date().timeIntervalSince1970],"voice-playback.json");if force{self.petView.say(error,seconds:12)}}
                guard self.speechGeneration==token,!self.muted,!self.criticalMode,!self.isLocked(),!self.fortuneBusy,let d=r["data"] as? [String:Any],let path=d["path"] as? String,let a=try? AVAudioPlayer(contentsOf:URL(fileURLWithPath:path)) else{return}
                self.audio?.stop();self.audio=a;a.delegate=self;a.volume=0.65
                self.petView.say(d["zh"] as? String ?? text,seconds:readingHash==nil ? a.duration+1:max(24,a.duration+1),readingHash:readingHash)
                writeJSON(["kind":"dialogue","started":a.play(),"at":Date().timeIntervalSince1970,"duration":a.duration],"voice-playback.json")
            }
        }
        if let ja=ja{synth(["ja":ja,"zh":text])}
        else{run("voiceLine",["text":text]){[weak self] r in guard let self=self else{return};if let d=r["data"] as? [String:Any]{synth(d)}else{self.speechBusy=false}}}
    }
}
