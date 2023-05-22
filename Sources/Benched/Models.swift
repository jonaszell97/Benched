
import Foundation

internal struct FrameMetrics {
    /// The frame number.
    let frameCount: Int
    
    /// The start time of the frame.
    let startTime: CFAbsoluteTime
    
    /// The end time of the frame.
    let endTime: CFAbsoluteTime
    
    /// The total duration of the frame.
    var duration: CFAbsoluteTime { endTime - startTime }
    
    /// The amount of time taken up per phase during this frame.
    let timePerCategory: [String: CFAbsoluteTime]
    
    /// Custom metrics per frame.
    let metrics: [String: Double]
}

internal struct Activity {
    /// The activity category.
    let category: String
    
    /// The frame at which the activity was started.
    let startFrame: Int
    
    /// The time at which the activity was started.
    let startTime: CFAbsoluteTime
    
    /// The frame at which the activity was completed.
    var endFrame: Int? = nil
    
    /// The time at which the activity was completed.
    var endTime: CFAbsoluteTime? = nil
    
    /// The response time for this activity.
    var responseTime: CFAbsoluteTime? {
        guard let endTime = endTime else {
            return nil
        }
        
        return endTime - startTime
    }
    
    /// The number of frames until a respons for this activity.
    var responseFrames: Int? {
        guard let endFrame = endFrame else {
            return nil
        }
        
        return endFrame - startFrame
    }
}
