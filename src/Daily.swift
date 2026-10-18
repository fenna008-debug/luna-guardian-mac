import AppKit

func lunaDay(_ date:Date=Date())->String {
    let f=DateFormatter();f.locale=Locale(identifier:"en_US_POSIX");f.timeZone=TimeZone(identifier:"Asia/Tokyo");f.dateFormat="yyyy-MM-dd"
    return f.string(from:date.addingTimeInterval(-4*3600))
}
extension Guardian {
    func dailyFortune(forOther:Bool=false)->[String:String] {
        guard let data=try? Data(contentsOf:resources.appendingPathComponent("fortunes.json")),let rows=try? JSONSerialization.jsonObject(with:data) as? [[String:String]],!rows.isEmpty else{return [:]}
        let today=lunaDay(),saved=readJSON("fortune.json")
        if !forOther,saved["date"] as? String==today,let row=rows.first(where:{$0["id"]==saved["id"] as? String || $0["title"]==saved["title"] as? String}){return row}
        let row=Self.weightedFortune(rows,roll:Int.random(in:0..<100))
        if !forOther{var record:[String:Any]=row;record["date"]=today;record["dayBoundary"]="Asia/Tokyo 04:00";writeJSON(record,"fortune.json");companion.refreshFortuneBanner()}
        return row
    }
    func tickDailyPresentation(){
        if readingDay != lunaDay(){
            let day=lunaDay();readingDay=day
            run("pruneReading"){[weak self] r in
                guard let self=self else{return}
                if r["ok"] as? Bool != true{self.readingDay="";return}
                self.life?.loadReading()
                if self.notebook?.window?.isVisible==true,self.notebook?.tabs.selectedSegment==0{self.notebook?.reload()}
            }
        }
        companion.refreshFortuneBanner()
        if pendingFortuneAnimation==lunaDay(),!speechBusy,audio?.isPlaying != true,!fortuneBusy,!isLocked(),!companion.chatBusy {
            pendingFortuneAnimation=""
            nativeCall("fortune"){_ in}
        }
        checkDailyGreeting()
    }
    func requestDailyGreeting(){
        dailyPending=true
        checkDailyGreeting()
    }
    func checkDailyGreeting(){
        guard dailyPending,!dailyBusy,!isLocked(),!companion.chatBusy,!fortuneBusy,!criticalMode else{return}
        if readJSON("daily-greeting.json")["date"] as? String==lunaDay(){dailyPending=false;return}
        dailyBusy=true
        run("weather"){[weak self] result in
            guard let self=self else{return};self.dailyBusy=false
            guard !self.isLocked(),!self.companion.chatBusy,!self.fortuneBusy else{return}
            let day=lunaDay()
            if readJSON("daily-greeting.json")["date"] as? String==day{self.dailyPending=false;return}
            var weather="天气暂时没取到，我不会拿旧天气冒充今天的。"
            if let d=result["data"] as? [String:Any],let current=d["current"] as? [String:Any],let daily=d["daily"] as? [String:Any]{
                self.lastWeather=d
                let code=current["weather_code"] as? Int ?? -1
                let sky=code==0 ? "晴":code<=3 && code>=0 ? "多云":code==45 || code==48 ? "雾":code>=95 ? "雷雨":[71,73,75,77,85,86].contains(code) ? "雪":"有降水"
                let temp=current["temperature_2m"] ?? "未知"
                let low=(daily["temperature_2m_min"] as? [Double])?.first
                let high=(daily["temperature_2m_max"] as? [Double])?.first
                let rain=(daily["precipitation_probability_max"] as? [Int])?.first
                weather="\(d["city"] as? String ?? "当地")：\(sky)，当前 \(temp)°C。"
                if let low=low,let high=high{weather+="今天 \(low)～\(high)°C。"}
                if let rain=rain{weather+="降水概率 \(rain)%。"}
                weather+="\n天气日期：\((daily["time"] as? [String])?.first ?? "未知") · Open-Meteo"
            }
            let row=self.dailyFortune()
            let greeting="你来了。今天第一次见面，先让我陪你把这一天慢慢展开吧。"
            let text=greeting+"\n\n"+weather+"\n\n今日签："+(row["title"] ?? "暂不可用")+"\n"+(row["text"] ?? "签文未准备好。")+"\n\n你的今日签保留到凌晨 4 点；替别人抽签可直接告诉我。"
            self.dailyPending=false
            writeJSON(["date":day,"at":Date().timeIntervalSince1970,"text":text,"fortune":row],"daily-greeting.json")
            self.companion.messages+="露娜 · 今日初见\n"+text+"\n\n"
            self.pet.orderFrontRegardless();self.animate("wave",seconds:10);self.petView.say(text,seconds:30)
            if !self.popover.isShown{self.showDashboard()};self.companion.text(text,title:"今日初见 · "+day)
            self.life?.lastLine=Date()
            self.pendingFortuneAnimation=day
            self.maybeSpeak(greeting,ja:"来たな。今日初めての挨拶だ。まずは私と一緒に、ゆっくり一日を始めよう。",force:true)
        }
    }
}
