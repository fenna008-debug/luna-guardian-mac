import Foundation
import Vision
import AppKit
if CommandLine.arguments.count != 2 {exit(2)}
let url=URL(fileURLWithPath:CommandLine.arguments[1])
guard let source=CGImageSourceCreateWithURL(url as CFURL,nil) else{exit(3)}
let options:[CFString:Any]=[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:2400,kCGImageSourceCreateThumbnailWithTransform:true]
guard let image=CGImageSourceCreateThumbnailAtIndex(source,0,options as CFDictionary) else{exit(4)}
let request=VNRecognizeTextRequest();request.recognitionLanguages=["ja-JP","zh-Hans","en-US"];request.recognitionLevel = .accurate
try VNImageRequestHandler(cgImage:image).perform([request])
print((request.results ?? []).compactMap{$0.topCandidates(1).first?.string}.joined(separator:"\n").prefix(12000))
