import Foundation
import PDFKit
let args=CommandLine.arguments
guard args.count==2,let pdf=PDFDocument(url:URL(fileURLWithPath:args[1])),!pdf.isLocked else{exit(2)}
var text="";var read=0
for i in 0..<min(12,pdf.pageCount){
    if let page=pdf.page(at:i){text+=try paperPageText(page,index:i)+"\n";read+=1}
    if text.count>=12000{break}
}
let body=text.components(separatedBy:"\n").filter{!$0.hasPrefix("[PDF页") && !$0.contains("此页未识别到可靠文字")}.joined().trimmingCharacters(in:.whitespacesAndNewlines)
let data:[String:Any]=["text":String(text.prefix(12000)),"scope":"仅处理前 \(read) 页，共 \(pdf.pageCount) 页；PDFKit文本层与必要的本机OCR，OCR须对照原页"+(text.count>12000 ? "；截取前12000字":""),"readable":!body.isEmpty]
let json=try JSONSerialization.data(withJSONObject:data,options:[.sortedKeys]);print(String(data:json,encoding:.utf8)!)
