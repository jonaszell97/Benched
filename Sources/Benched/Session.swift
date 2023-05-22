
import Foundation
import Toolbox

extension Log {
    static let benched = Logger(subsystem: "com.jonaszell.Benched", category: "BenchmarkSession")
}

public final class BenchmarkSession {
    /// The name of this benchmarking session.
    public let name: String
    
    /// Names of specific functions along with the amount of times they've been done and the total duration.
    var phases: [String: [CFAbsoluteTime]] = [:]
    
    /// The metrics for the current frame.
    var metrics: [String: Double] = [:]
    
    /// List of all activities.
    var activities: [String: Activity] = [:]
    
    /// List of completed activities.
    var completedActivities: [Activity] = []
    
    /// The captured frame metrics.
    var frames: [Int: FrameMetrics] = [:]
    
    /// The start time of the current frame.
    var currentFrameStart: CFAbsoluteTime? = nil
    
    /// The index of the current frame.
    var currentFrameCount: Int? = nil
    
    /// The start time and name of the current measurement.
    var activeMeasurements: [(String, CFAbsoluteTime)] = []
    
    /// The shared benchmarking sessions per dispatch queue.
    static var sharedSessions: [String: BenchmarkSession] = [:]
    
    /// Default initializer.
    public init(name: String) {
        self.name = name
    }
}

extension BenchmarkSession {
    /// Get the session for the current queue.
    public static var current: BenchmarkSession? {
        guard let label = DispatchQueue.currentQueueLabel else {
            return nil
        }
        
        return Self.sharedSessions[label]
    }
    
    /// Register a shared session.
    public static func registerSession(for queue: DispatchQueue) {
        Self.sharedSessions[queue.label] = BenchmarkSession(name: "\(queue.label).default")
    }
    
    /// Start a new frame.
    public func startFrame(frameCount: Int) {
        self.currentFrameStart = CFAbsoluteTimeGetCurrent()
        self.currentFrameCount = frameCount
        self.phases.removeAll()
        self.activeMeasurements.removeAll()
        self.metrics.removeAll()
    }
    
    /// End a frame.
    public func endFrame() {
        guard let startTime = currentFrameStart, let frameCount = currentFrameCount else {
            Log.benched.error("BenchmarkSession.endFrame called without an active frame")
            return
        }
        
        while let first = self.activeMeasurements.first {
            Log.benched.error("active measurement while ending frame: \(first.0)")
            self.endMeasurement()
        }
        
        let measurements = self.phases.mapValues { $0.reduce(0) { $0 + $1 } }
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let frame = FrameMetrics(frameCount: frameCount,
                                 startTime: startTime,
                                 endTime: endTime,
                                 timePerCategory: measurements,
                                 metrics: self.metrics)
        
        self.frames[frameCount] = frame
    }
    
    /// Update a metric for the current frame.
    public func setMetric(name: String, value: Double) {
        self.metrics[name] = value
    }
    
    /// Update a metric for the current frame.
    public func updateMetric(name: String, initialValue: Double, updateFunction: (Double) -> Double) {
        self.metrics[name] = updateFunction(self.metrics[name] ?? initialValue)
    }
    
    /// Start an activity.
    public func startActivity(category: String, id: String) {
        if self.activities[id] != nil {
            // If the activity was never finished, keep the existing start for responsiveness measuerements
            return
        }
        
        guard let currentFrameCount = currentFrameCount else {
            Log.benched.error("trying to start activity with no frame data")
            return
        }
        
        self.activities[id] = Activity(category: category,
                                       startFrame: currentFrameCount,
                                       startTime: CFAbsoluteTimeGetCurrent())
    }
    
    /// Complete an activity.
    public func completeActivity(id: String) {
        guard let currentFrameCount = currentFrameCount else {
            Log.benched.error("trying to end activity with no frame data")
            return
        }
        
        guard var activity = self.activities[id] else {
            Log.benched.error("missing activity: \(id)")
            return
        }
        
        activity.endFrame = currentFrameCount
        activity.endTime = CFAbsoluteTimeGetCurrent()
        
        self.activities[id] = nil
        self.completedActivities.append(activity)
    }
    
    /// Start a benchmark.
    public func benchmark(phaseName: String, _ function: () -> Void) {
        startMeasurement(phaseName: phaseName)
        function()
        endMeasurement()
    }
    
    /// Start a measurement.
    public func startMeasurement(phaseName: String) {
        activeMeasurements.append((phaseName, CFAbsoluteTimeGetCurrent()))
    }
    
    /// End a measurement.
    public func endMeasurement() {
        let endTime = CFAbsoluteTimeGetCurrent()
        guard let (phaseName, startTime) = activeMeasurements.popLast() else {
            Log.benched.error("attempting to end non-existant measurement")
            return
        }
        
        let duration = endTime - startTime
        if self.phases[phaseName] != nil {
            self.phases[phaseName]?.append(duration)
        }
        else {
            self.phases[phaseName] = [duration]
        }
    }
    
    /// Copy the results of another session.
    public func copyResults(of session: BenchmarkSession) {
        for (phaseName, data) in session.phases {
            if self.phases[phaseName] != nil {
                self.phases[phaseName]?.append(contentsOf: data)
            }
            else {
                self.phases[phaseName] = data
            }
        }
    }
}

@discardableResult public func benchmark<T>(_ name: String, code: () -> T) -> T {
    let start = CFAbsoluteTimeGetCurrent()
    let result = code()
    
    let duration = CFAbsoluteTimeGetCurrent() - start
    Log.benched.debug("[\(name)] \(FormatToolbox.format(duration*1000))ms")
    
    return result
}

public func benchmark<T>(_ name: String, iterations: Int, code: () -> T) {
    let start = CFAbsoluteTimeGetCurrent()
    
    for _ in 0..<iterations {
        _ = code()
    }
    
    let duration = (CFAbsoluteTimeGetCurrent() - start) / CFAbsoluteTime(iterations)
    Log.benched.debug("[\(name)] \(FormatToolbox.format(duration*1000))ms")
}

// MARK: DispatchQueue detection

extension DispatchQueue {
    struct QueueReference { weak var queue: DispatchQueue? }
    
    static let key: DispatchSpecificKey<QueueReference> = {
        let key = DispatchSpecificKey<QueueReference>()
        setupSystemQueuesDetection(key: key)
        return key
    }()
    
    static func _registerDetection(of queues: [DispatchQueue], key: DispatchSpecificKey<QueueReference>) {
        queues.forEach { $0.setSpecific(key: key, value: QueueReference(queue: $0)) }
        
        for queue in queues {
            BenchmarkSession.registerSession(for: queue)
        }
    }
    
    static func setupSystemQueuesDetection(key: DispatchSpecificKey<QueueReference>) {
        let queues: [DispatchQueue] = [
            .main,
            .global(qos: .background),
            .global(qos: .default),
            .global(qos: .unspecified),
            .global(qos: .userInitiated),
            .global(qos: .userInteractive),
            .global(qos: .utility)
        ]
        _registerDetection(of: queues, key: key)
    }
    
    static func registerDetection(of queue: DispatchQueue) {
        _registerDetection(of: [queue], key: key)
    }
    
    func registerDetection() {
        Self.registerDetection(of: self)
    }
    
    static var currentQueueLabel: String? { current?.label }
    static var current: DispatchQueue? { getSpecific(key: key)?.queue }
}
