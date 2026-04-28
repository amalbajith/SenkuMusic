//
//  LRCParser.swift
//  SenkuPlayer
//

import Foundation

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let time: TimeInterval
    let text: String
}

class LRCParser {
    private static let regex = try! NSRegularExpression(pattern: "\\[(\\d{2}):(\\d{2})\\.(\\d{2,3})\\](.*)")
    
    static func parse(lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        
        let stringLines = lrc.components(separatedBy: .newlines)
        for line in stringLines {
            let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
            if let match = regex.firstMatch(in: line, options: [], range: nsRange) {
                let minutesStr = (line as NSString).substring(with: match.range(at: 1))
                let secondsStr = (line as NSString).substring(with: match.range(at: 2))
                let hundredthsStr = (line as NSString).substring(with: match.range(at: 3))
                let text = (line as NSString).substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)
                
                let minutes = Double(minutesStr) ?? 0
                let seconds = Double(secondsStr) ?? 0
                let hundredths = Double(hundredthsStr) ?? 0
                
                let time = (minutes * 60) + seconds + (hundredths / (hundredthsStr.count == 3 ? 1000 : 100))
                
                lines.append(LyricLine(time: time, text: text))
            }
        }
        
        return lines.sorted { $0.time < $1.time }
    }
}
