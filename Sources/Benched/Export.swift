
import Foundation
import Toolbox

extension BenchmarkSession {
    /// Print the measurement statistics.
    public func dumpResults() {
        print("--- BENCHMARKS ---")
        
        let phases = phases.map { ($0.key, $0.value) }.sorted {
            $0.1.count > $1.1.count
        }
        
        let maxPhaseLength = phases.max {
            $0.0.count < $1.0.count
        }!.0.count
        
        let maxTimes = FormatToolbox.format(phases.max {
            $0.1.count < $1.1.count
        }!.1.count).count
        
        for (phase, data) in phases {
            let times = data.count
            let total = data.reduce(0) { $0 + $1 }
            let avg = total / Double(times)
            let max = data.max() ?? 0
            
            let lastHundred = data.suffix(100)
            let lastHundredTotal = lastHundred.reduce(0) { $0 + $1 }
            let lastHundredAvg = lastHundredTotal / Double(lastHundred.count)
            
            let col1 = "\(phase)".padding(toLength: maxPhaseLength, withPad: " ", startingAt: 0)
            let col2 = FormatToolbox.format(times).padding(toLength: maxTimes, withPad: " ", startingAt: 0)
            let col3 = FormatToolbox.format(total, decimalPlaces: 3, minDecimalPlaces: 3)
            let col4 = FormatToolbox.format(avg*1000, decimalPlaces: 3, minDecimalPlaces: 3)
            let col5 = FormatToolbox.format(max*1000, decimalPlaces: 3, minDecimalPlaces: 3)
            let col6 = FormatToolbox.format(lastHundredAvg*1000, decimalPlaces: 3, minDecimalPlaces: 3)
            
            print("[\(col1)] \(col2) times, \(col3)s total, \(col4)ms avg, \(col5)ms max, last 100: \(col6)ms avg")
        }
        
        print("------------------")
    }
    
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "de_DE")
        formatter.maximumFractionDigits = 3
        formatter.minimumFractionDigits = 3
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        
        return formatter
    }()
    
    static func format(_ fp: Double) -> String {
        numberFormatter.string(from: NSNumber(value: fp)) ?? String(fp)
    }
    
    /// Export a CSV file with the benchmark results.
    public func exportToCsv(destinationPath url: URL) {
        let fullUrl = url.appendingPathComponent("BenchmarkSession \(name) \(Date())")
        try? FileManager.default.createDirectory(at: fullUrl, withIntermediateDirectories: false)
        
        self.exportActivitiesCsv(url: fullUrl.appendingPathComponent("activities.csv"))
        self.exportGroupedActivitiesCsv(baseUrl: fullUrl, groupSize: 100)
        self.exportFrameStatsCsv(url: fullUrl.appendingPathComponent("frameTime.csv"))
        self.exportGroupedFramesCsv(url: fullUrl.appendingPathComponent("frameTime_100.csv"), groupSize: 100)
        self.exportRawFramesCsv(url: fullUrl.appendingPathComponent("raw.csv"))
    }
    
    private func exportActivitiesCsv(url: URL) {
        var categoriesSet = Set<String>()
        for activity in completedActivities {
            categoriesSet.insert(activity.category)
        }
        
        let categories = categoriesSet.sorted()
        
        var csv = "Category;Count;Max Response Time;Avg. Response Time (ms);5% Response Time (ms);1% Response Time (ms);"
        csv += "Max Frame Count;Avg. Frame Count;5% Frame Count;1% Frame Count"
        
        for category in categories {
            let activities = self.completedActivities.filter { $0.category == category }
            csv += "\n\(category);\(activities.count)"
            
            let onePercentCount = max(1, Int(Double(activities.count) * 0.01))
            let fivePercentCount = max(1, Int(Double(activities.count) * 0.05))
            
            let responseTimes = activities.compactMap { $0.responseTime }.sorted { $0 > $1 }
            let onePercentResponseTimes = responseTimes.prefix(onePercentCount)
            let fivePercentResponseTimes = responseTimes.prefix(fivePercentCount)
            
            let maxResponseTime = responseTimes.max() ?? 0
            csv += ";\(Self.format(maxResponseTime*1000))"
            
            let avgResponseTime = responseTimes.reduce(0) { $0 + $1 } / CFAbsoluteTime(responseTimes.count)
            csv += ";\(Self.format(avgResponseTime*1000))"
            
            let fivePercentResponseTime = fivePercentResponseTimes.reduce(0) { $0 + $1 } / CFAbsoluteTime(fivePercentResponseTimes.count)
            csv += ";\(Self.format(fivePercentResponseTime*1000))"
            
            let onePercentResponseTime = onePercentResponseTimes.reduce(0) { $0 + $1 } / CFAbsoluteTime(onePercentResponseTimes.count)
            csv += ";\(Self.format(onePercentResponseTime*1000))"
            
            let responseFrames = activities.compactMap { $0.responseFrames }.sorted { $0 > $1 }
            let onePercentResponseFrames = responseFrames.prefix(onePercentCount)
            let fivePercentResponseFrames = responseFrames.prefix(fivePercentCount)
            
            let maxResponseFrames = Double(responseFrames.max() ?? 0)
            csv += ";\(Self.format(maxResponseFrames))"
            
            let avgResponseFrameCount = Double(responseFrames.reduce(0) { $0 + $1 }) / Double(responseFrames.count)
            csv += ";\(Self.format(avgResponseFrameCount))"
            
            let fivePercentResponseFrameCount = Double(fivePercentResponseFrames.reduce(0) { $0 + $1 }) / Double(fivePercentResponseFrames.count)
            csv += ";\(Self.format(fivePercentResponseFrameCount))"
            
            let onePercentResponseFrameCount = Double(onePercentResponseFrames.reduce(0) { $0 + $1 }) / Double(onePercentResponseFrames.count)
            csv += ";\(Self.format(onePercentResponseFrameCount))"
        }
        
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
        }
        catch {
            Log.benched.error("exporting benchmarks failed: \(error.localizedDescription)")
        }
    }
    
    private func exportGroupedActivitiesCsv(baseUrl: URL, groupSize: Int) {
        var categoriesSet = Set<String>()
        for activity in completedActivities {
            categoriesSet.insert(activity.category)
        }
        
        let categories = categoriesSet.sorted()
        for category in categories {
            var csv = "Frame Range;Count;Max Response Time;Avg. Response Time (ms);5% Response Time (ms);1% Response Time (ms);"
            csv += "Max Frame Count;Avg. Frame Count;5% Frame Count;1% Frame Count"
            
            var frameRanges = [Int: [Activity]]()
            let allActivities = self.completedActivities.filter { $0.category == category }
            
            for activity in allActivities {
                let groupIndex = activity.startFrame / groupSize
                if frameRanges[groupIndex] == nil {
                    frameRanges[groupIndex] = []
                }
                
                frameRanges[groupIndex]?.append(activity)
            }
            
            let activitiesPerGroup = frameRanges.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
            for (groupIndex, activities) in activitiesPerGroup {
                let start = groupIndex * groupSize
                let end = start + groupSize
                
                csv += "\n\(start)-\(end);\(activities.count)"
                
                let onePercentCount = max(1, Int(Double(activities.count) * 0.01))
                let fivePercentCount = max(1, Int(Double(activities.count) * 0.05))
                
                let responseTimes = activities.compactMap { $0.responseTime }.sorted { $0 > $1 }
                let onePercentResponseTimes = responseTimes.prefix(onePercentCount)
                let fivePercentResponseTimes = responseTimes.prefix(fivePercentCount)
                
                let maxResponseTime = responseTimes.max() ?? 0
                csv += ";\(Self.format(maxResponseTime*1000))"
                
                let avgResponseTime = responseTimes.reduce(0) { $0 + $1 } / CFAbsoluteTime(responseTimes.count)
                csv += ";\(Self.format(avgResponseTime*1000))"
                
                let fivePercentResponseTime = fivePercentResponseTimes.reduce(0) { $0 + $1 } / CFAbsoluteTime(fivePercentResponseTimes.count)
                csv += ";\(Self.format(fivePercentResponseTime*1000))"
                
                let onePercentResponseTime = onePercentResponseTimes.reduce(0) { $0 + $1 } / CFAbsoluteTime(onePercentResponseTimes.count)
                csv += ";\(Self.format(onePercentResponseTime*1000))"
                
                let responseFrames = activities.compactMap { $0.responseFrames }.sorted { $0 > $1 }
                let onePercentResponseFrames = responseFrames.prefix(onePercentCount)
                let fivePercentResponseFrames = responseFrames.prefix(fivePercentCount)
                
                let maxResponseFrames = Double(responseFrames.max() ?? 0)
                csv += ";\(Self.format(maxResponseFrames))"
                
                let avgResponseFrameCount = Double(responseFrames.reduce(0) { $0 + $1 }) / Double(responseFrames.count)
                csv += ";\(Self.format(avgResponseFrameCount))"
                
                let fivePercentResponseFrameCount = Double(fivePercentResponseFrames.reduce(0) { $0 + $1 }) / Double(fivePercentResponseFrames.count)
                csv += ";\(Self.format(fivePercentResponseFrameCount))"
                
                let onePercentResponseFrameCount = Double(onePercentResponseFrames.reduce(0) { $0 + $1 }) / Double(onePercentResponseFrames.count)
                csv += ";\(Self.format(onePercentResponseFrameCount))"
            }
            
            let url = baseUrl.appendingPathComponent("activity_\(category).csv")
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
            }
            catch {
                Log.benched.error("exporting benchmarks failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func exportFrameStatsCsv(url: URL) {
        var allPhasesSet = Set<String>()
        for (_, frame) in frames {
            for (phase, _) in frame.timePerCategory {
                allPhasesSet.insert(phase)
            }
        }
        
        let allPhases = allPhasesSet.sorted()
        
        var csv = "Phase;Count;Max Time (ms);Avg. Time (ms);5% Time (ms);1% Time (ms)"
        for phase in allPhases {
            let completionTimes = self.frames.values.compactMap { $0.timePerCategory[phase] }.sorted { $0 > $1 }
            csv += "\n\(phase);\(completionTimes.count)"
            
            let maxCompletionTime = completionTimes.max() ?? 0
            csv += ";\(Self.format(maxCompletionTime*1000))"
            
            let onePercentCount = max(1, Int(Double(completionTimes.count) * 0.01))
            let fivePercentCount = max(1, Int(Double(completionTimes.count) * 0.05))
            
            let onePercentResponseTimes = completionTimes.prefix(onePercentCount)
            let fivePercentResponseTimes = completionTimes.prefix(fivePercentCount)
            
            let avgResponseTime = completionTimes.reduce(0) { $0 + $1 } / CFAbsoluteTime(completionTimes.count)
            csv += ";\(Self.format(avgResponseTime*1000))"
            
            let fivePercentResponseTime = fivePercentResponseTimes.reduce(0) { $0 + $1 } / CFAbsoluteTime(fivePercentResponseTimes.count)
            csv += ";\(Self.format(fivePercentResponseTime*1000))"
            
            let onePercentResponseTime = onePercentResponseTimes.reduce(0) { $0 + $1 } / CFAbsoluteTime(onePercentResponseTimes.count)
            csv += ";\(Self.format(onePercentResponseTime*1000))"
        }
        
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
        }
        catch {
            Log.benched.error("exporting benchmarks failed: \(error.localizedDescription)")
        }
    }
    
    private func exportGroupedFramesCsv(url: URL, groupSize: Int) {
        var allPhasesSet = Set<String>()
        var allMetricsSet = Set<String>()
        for (_, frame) in frames {
            for (phase, _) in frame.timePerCategory {
                allPhasesSet.insert(phase)
            }
            for (metric, _) in frame.metrics {
                allMetricsSet.insert(metric)
            }
        }
        
        let allPhases = allPhasesSet.sorted()
        let allMetrics = allMetricsSet.sorted()
        
        var csv = "Frame Range;OK;Max. Frame Time (ms);Avg. Frame Time (ms);5% Frame Time (ms);1% Frame Time (ms)"
        
        for phase in allPhases {
            csv += ";\(phase) (Max);\(phase) (Avg);\(phase) (5%);\(phase) (1%)"
        }
        
        for metric in allMetrics {
            csv += ";\(metric) (Avg); \(metric) (Max); \(metric) (Total)"
        }
        
        let allFrames = frames.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
        let groupCount = Int((Double(allFrames.count) / Double(groupSize)).rounded(.up))
        
        let fivePercentCount = max(1, Int(Double(groupSize) * 0.05))
        let onePercentCount = max(1, Int(Double(groupSize) * 0.01))
        
        for i in 0..<groupCount {
            let start = i * groupSize
            let end = min(allFrames.count, start + groupSize)
            
            let framesInGroup = allFrames[start..<end]
            
            // Frame time
            let frameTimes = framesInGroup.map { $0.1.duration }.sorted { $0 > $1 }
            let fivePercentFrameTimes = frameTimes.prefix(fivePercentCount)
            let onePercentFrameTimes = frameTimes.prefix(onePercentCount)
            
            let maxFrameTime = frameTimes.max() ?? 0
            let avgFrameTime = frameTimes.reduce(0) { $0 + $1 } / CFAbsoluteTime(frameTimes.count)
            let fivePercentAverageFrameTime = fivePercentFrameTimes.reduce(0) { $0 + $1 } / CFAbsoluteTime(fivePercentFrameTimes.count)
            let onePercentAverageFrameTime = onePercentFrameTimes.reduce(0) { $0 + $1 } / CFAbsoluteTime(onePercentFrameTimes.count)
            let isOkay = fivePercentAverageFrameTime < 0.05
            
            csv += "\n\(start)-\(end);\(isOkay ? "1" : "0");\(Self.format(maxFrameTime*1000));\(Self.format(avgFrameTime*1000))"
            csv += ";\(Self.format(fivePercentAverageFrameTime*1000));\(Self.format(onePercentAverageFrameTime*1000))"
            
            // Phases
            var timesPerPhase = [(String, [CFAbsoluteTime])]()
            for phase in allPhases {
                var times = [CFAbsoluteTime]()
                for frame in framesInGroup {
                    times.append(frame.1.timePerCategory[phase] ?? 0)
                }
                
                timesPerPhase.append((phase, times.sorted { $0 > $1 }))
            }
            
            for (_, times) in timesPerPhase {
                guard !times.isEmpty else {
                    csv += ";0;0;0;0"
                    continue
                }
                
                let fivePercentCount = max(1, Int(Double(times.count) * 0.05))
                let onePercentCount = max(1, Int(Double(times.count) * 0.01))
                let fivePercentTimes = times.prefix(fivePercentCount)
                let onePercentTimes = times.prefix(onePercentCount)
                
                let max = times.max() ?? 0
                let avg = times.reduce(0) { $0 + $1 } / CFAbsoluteTime(times.count)
                let fivePercent = fivePercentTimes.reduce(0) { $0 + $1 } / CFAbsoluteTime(fivePercentTimes.count)
                let onePercent = onePercentTimes.reduce(0) { $0 + $1 } / CFAbsoluteTime(onePercentTimes.count)
                
                csv += ";\(Self.format(max*1000));\(Self.format(avg*1000));\(Self.format(fivePercent*1000));\(Self.format(onePercent*1000))"
            }
            
            // Metrics
            var metrics = [(String, [Double])]()
            for metric in allMetrics {
                var values = [Double]()
                for frame in framesInGroup {
                    values.append(frame.1.metrics[metric] ?? 0)
                }
                
                metrics.append((metric, values.sorted { $0 > $1 }))
            }
            
            for (_, values) in metrics {
                guard !values.isEmpty else {
                    csv += ";0;0;0"
                    continue
                }
                
                let max = values.max() ?? 0
                let sum = values.reduce(0) { $0 + $1 }
                let avg = sum / CFAbsoluteTime(values.count)
                
                csv += ";\(Self.format(avg));\(Self.format(max));\(Self.format(sum))"
            }
        }
        
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
        }
        catch {
            Log.benched.error("exporting benchmarks failed: \(error.localizedDescription)")
        }
    }
    
    private func exportRawFramesCsv(url: URL) {
        var allPhasesSet = Set<String>()
        var allMetricsSet = Set<String>()
        for (_, frame) in frames {
            for (phase, _) in frame.timePerCategory {
                allPhasesSet.insert(phase)
            }
            for (metric, _) in frame.metrics {
                allMetricsSet.insert(metric)
            }
        }
        
        let allPhases = allPhasesSet.sorted()
        let allMetrics = allMetricsSet.sorted()
        
        var csv = "Frame;OK;Start;End;Duration (ms)"
        
        for phase in allPhases {
            csv += ";\(phase)"
        }
        
        for metric in allMetrics {
            csv += ";\(metric)"
        }
        
        let allFrames = frames.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
        for (frame, data) in allFrames {
            let isOkay = data.duration < 0.005
            csv += "\n\(frame);\(isOkay ? "1" : "0");\(data.startTime);\(data.endTime);\(data.duration*1000)"
            
            for phase in allPhases {
                if let value = data.timePerCategory[phase] {
                    csv += ";\(Self.format(value*1000))"
                }
                else {
                    csv += ";0"
                }
            }
            
            for metric in allMetrics {
                if let value = data.metrics[metric] {
                    csv += ";\(Self.format(value))"
                }
                else {
                    csv += ";-"
                }
            }
        }
        
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
        }
        catch {
            Log.benched.error("exporting benchmarks failed: \(error.localizedDescription)")
        }
    }
}
