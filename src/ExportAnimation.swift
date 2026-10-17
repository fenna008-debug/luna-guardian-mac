import AppKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers
let out=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
let res=URL(fileURLWithPath:"/Applications/露娜电脑管家.app/Contents/Resources")
let src=CGImageSourceCreateWithURL(res.appendingPathComponent("spritesheet.webp") as CFURL,nil)!
let sheet=CGImageSourceCreateImageAtIndex(src,0,nil)!
func sprite(_ row:Int,_ col:Int)->NSImage{let cg=sheet.cropping(to:CGRect(x:col*192,y:row*208,width:192,height:208))!;return NSImage(cgImage:cg,size:NSSize(width:192,height:208))}
let thinking=sprite(7,1),surprised=sprite(6,0),happy=sprite(4,2)
let width=480,height=600,fps=15,count=150
let gifURL=out.appendingPathComponent("露娜摇签_大吉.gif")
let gif=CGImageDestinationCreateWithURL(gifURL as CFURL,UTType.gif.identifier as CFString,count,nil)!
CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
let silent=out.appendingPathComponent(".silent.mp4")
try? FileManager.default.removeItem(at:silent)
let writer=try AVAssetWriter(outputURL:silent,fileType:.mp4)
let input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:width,AVVideoHeightKey:height,AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:1400000]])
let adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32ARGB,kCVPixelBufferWidthKey as String:width,kCVPixelBufferHeightKey as String:height,kCVPixelBufferCGImageCompatibilityKey as String:true,kCVPixelBufferCGBitmapContextCompatibilityKey as String:true])
writer.add(input);writer.startWriting();writer.startSession(atSourceTime:.zero)
func text(_ value:String,_ rect:NSRect,_ size:CGFloat,_ color:NSColor){let para=NSMutableParagraphStyle();para.alignment = .center;para.lineSpacing=5;(value as NSString).draw(in:rect,withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:.medium),.foregroundColor:color,.paragraphStyle:para])}
func round(_ rect:NSRect,_ radius:CGFloat,_ color:NSColor){color.setFill();NSBezierPath(roundedRect:rect,xRadius:radius,yRadius:radius).fill()}
let brown=NSColor(calibratedRed:0.45,green:0.25,blue:0.19,alpha:1),gold=NSColor(calibratedRed:0.78,green:0.53,blue:0.18,alpha:1)
for i in 0..<count {autoreleasepool {
 let t=Double(i)/Double(fps)
 let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 let graphics=NSGraphicsContext(bitmapImageRep:bitmap)!;NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=graphics
 round(NSRect(x:0,y:0,width:width,height:height),0,NSColor(calibratedRed:0.98,green:0.97,blue:0.99,alpha:1))
 text("☾  L U N A",NSRect(x:0,y:555,width:width,height:24),18,NSColor(calibratedRed:0.42,green:0.35,blue:0.51,alpha:1))
 let caption=t<2.05 ? "让我替你摇一支。\n别把作业全交给运气。":"大吉呢。不错。\n今天稍微多一点自信，向前走吧。"
 text(caption,NSRect(x:35,y:465,width:410,height:65),18,.darkGray)
 let figure=NSRect(x:65,y:35,width:330,height:357.5)
 NSGraphicsContext.saveGraphicsState()
 if t<1.55 {let tr=AffineTransform(translationByX:figure.midX,byY:figure.midY);var r=tr;r.rotate(byRadians:CGFloat(sin(t*15)*0.025));r.translate(x:-figure.midX,y:-figure.midY);(r as NSAffineTransform).concat()}
 (t<1.55 ? thinking:t<2.05 ? surprised:happy).draw(in:figure)
 NSGraphicsContext.restoreGraphicsState()
 if t<2.05 {
  let cup=NSRect(x:250,y:125,width:78,height:128)
  if t>=1.55 {let y=CGFloat((t-1.55)/0.5)*90;round(NSRect(x:286,y:220+y,width:8,height:85),2,NSColor(calibratedRed:0.98,green:0.88,blue:0.66,alpha:1))}
  NSGraphicsContext.saveGraphicsState();let tr=NSAffineTransform();tr.translateX(by:cup.midX,yBy:cup.midY);tr.rotate(byRadians:CGFloat(t<1.55 ? sin(t*15)*0.25:0));tr.translateX(by:-cup.midX,yBy:-cup.midY);tr.concat()
  for j in 0..<5 {round(NSRect(x:cup.minX+11+CGFloat(j)*11,y:cup.minY+86,width:5,height:34+CGFloat(j%2)*8),1,NSColor(calibratedRed:0.91,green:0.80,blue:0.57,alpha:1))}
  let wood=NSBezierPath(roundedRect:NSRect(x:cup.minX,y:cup.minY,width:78,height:104),xRadius:12,yRadius:12)
  NSGradient(colors:[brown,NSColor(calibratedRed:0.69,green:0.42,blue:0.27,alpha:1),brown])!.draw(in:wood,angle:0)
  for y in [11.0,85.0]{round(NSRect(x:cup.minX,y:cup.minY+y,width:78,height:5),0,NSColor(calibratedRed:0.87,green:0.71,blue:0.37,alpha:1))}
  text("御\n籤",NSRect(x:cup.minX+15,y:cup.minY+23,width:48,height:60),23,.white);NSGraphicsContext.restoreGraphicsState()
 }else{
  let card=NSRect(x:285,y:145,width:72,height:126);round(card,8,NSColor(calibratedRed:1,green:0.98,blue:0.92,alpha:1));gold.setStroke();let border=NSBezierPath(roundedRect:card,xRadius:8,yRadius:8);border.lineWidth=1.5;border.stroke();text("大\n吉",NSRect(x:296,y:176,width:50,height:80),27,gold);text("☾",NSRect(x:298,y:150,width:46,height:25),20,gold)
 }
 NSGraphicsContext.restoreGraphicsState();let cg=bitmap.cgImage!
 CGImageDestinationAddImage(gif,cg,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/Double(fps)]] as CFDictionary)
 while !input.isReadyForMoreMediaData{Thread.sleep(forTimeInterval:0.005)}
 var pb:CVPixelBuffer?;CVPixelBufferPoolCreatePixelBuffer(nil,adaptor.pixelBufferPool!,&pb);let pixel=pb!;CVPixelBufferLockBaseAddress(pixel,[])
 let ctx=CGContext(data:CVPixelBufferGetBaseAddress(pixel),width:width,height:height,bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(pixel),space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipFirst.rawValue)!
 ctx.draw(cg,in:CGRect(x:0,y:0,width:width,height:height));CVPixelBufferUnlockBaseAddress(pixel,[])
 precondition(adaptor.append(pixel,withPresentationTime:CMTime(value:Int64(i),timescale:Int32(fps))))
 if i==45 {let png=NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:])!;try! png.write(to:out.appendingPathComponent("预览.png"))}
}}
precondition(CGImageDestinationFinalize(gif));input.markAsFinished();let sem=DispatchSemaphore(value:0);writer.finishWriting{sem.signal()};sem.wait();precondition(writer.status == .completed)
let composition=AVMutableComposition();let videoAsset=AVURLAsset(url:silent);let video=composition.addMutableTrack(withMediaType:.video,preferredTrackID:kCMPersistentTrackID_Invalid)!
try video.insertTimeRange(CMTimeRange(start:.zero,duration:CMTime(seconds:10,preferredTimescale:600)),of:videoAsset.tracks(withMediaType:.video)[0],at:.zero)
let audioAsset=AVURLAsset(url:res.appendingPathComponent("voices/fortune_great.wav"));let audio=composition.addMutableTrack(withMediaType:.audio,preferredTrackID:kCMPersistentTrackID_Invalid)!
try audio.insertTimeRange(CMTimeRange(start:.zero,duration:audioAsset.duration),of:audioAsset.tracks(withMediaType:.audio)[0],at:CMTime(seconds:2.05,preferredTimescale:600))
let exporter=AVAssetExportSession(asset:composition,presetName:AVAssetExportPresetHighestQuality)!;let mp4=out.appendingPathComponent("露娜摇签_大吉_日语配音.mp4");try? FileManager.default.removeItem(at:mp4);exporter.outputURL=mp4;exporter.outputFileType = .mp4
let done=DispatchSemaphore(value:0);exporter.exportAsynchronously{done.signal()};done.wait();precondition(exporter.status == .completed);try? FileManager.default.removeItem(at:silent)
print("GIF and voiced MP4 exported: \(out.path)")
