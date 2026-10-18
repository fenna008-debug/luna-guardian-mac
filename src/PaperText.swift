import AppKit
import PDFKit
import Vision

func paperPageText(_ page:PDFPage,index:Int)throws->String{
    let raw=page.string ?? ""
    let bad=raw.unicodeScalars.filter{($0.value<32 && ![9,10,13].contains($0.value)) || $0.value==0xfffd}.count
    let needsOCR=raw.trimmingCharacters(in:.whitespacesAndNewlines).count<40 || bad>max(2,raw.count/100)
    if !needsOCR{return "[PDF页 \(index+1) · 文本层，引用前对照原页]\n"+raw}
    let bounds=page.bounds(for:.mediaBox);let scale=min(3,2400/max(bounds.width,bounds.height))
    let image=page.thumbnail(of:NSSize(width:bounds.width*scale,height:bounds.height*scale),for:.mediaBox)
    var rect=CGRect(origin:.zero,size:image.size)
    guard let cg=image.cgImage(forProposedRect:&rect,context:nil,hints:nil) else{return "[PDF页 \(index+1) · 无法提取，待核]"}
    let req=VNRecognizeTextRequest();req.recognitionLevel = .accurate;req.recognitionLanguages=["ja-JP","en-US","zh-Hans"];req.usesLanguageCorrection=false
    try VNImageRequestHandler(cgImage:cg).perform([req])
    let lines=(req.results ?? []).compactMap{observation->String? in guard let t=observation.topCandidates(1).first else{return nil};return t.string+(t.confidence<0.6 ? " [低置信OCR，待核]":"")}
    return "[PDF页 \(index+1) · OCR识别，旧字、专名及阅读顺序须对照原页]\n"+(lines.isEmpty ? "此页未识别到可靠文字。":lines.joined(separator:"\n"))
}
