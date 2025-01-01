public struct Spinner {
  let animation: [String]
  let spinnerType: SpinnerType

  public enum SpinnerType {
    case looping
    case bouncing
  }

  public init(animation: [String], _ spinnerType: SpinnerType = .looping) {
    self.animation = animation
    self.spinnerType = spinnerType
  }

  func makeIterator() -> any SpinnerIteratorProtocol {
    switch (self.spinnerType) {
      case .looping:
        return LoopingSpinnerIterator(self.animation)
      case .bouncing:
        return BouncingSpinnerIterator(self.animation)
    }
  }
}

protocol SpinnerIteratorProtocol: IteratorProtocol {
  associatedtype Element = String

  var current: Element? { get }
}

struct LoopingSpinnerIterator: IteratorProtocol, SpinnerIteratorProtocol {
  typealias Element = String

  let animation: [String]
  var i = 0

  init(_ animation: [String]) {
    self.animation = animation
  }

  var current: Element? = nil

  mutating func next() -> Element? {
    if self.i >= self.animation.count {
      self.i = 0
    }
    defer { self.i += 1 }
    self.current = self.animation[i]
    return self.current
  }
}

struct BouncingSpinnerIterator: IteratorProtocol, SpinnerIteratorProtocol {
  typealias Element = String

  let animation: [String]
  var i = 0
  var direction: Direction = .right

  enum Direction {
    case right
    case left
  }

  init(_ animation: [String]) {
    self.animation = animation
  }

  var current: String? = nil

  mutating func next() -> String? {
    if self.i == self.animation.count {
      self.i -= 2
      self.direction = .left
    } else if self.i == -1 {
      self.i = 1
      self.direction = .right
    }

    defer {
      switch (self.direction) {
        case .right: self.i += 1
        case .left: self.i -= 1
      }
    }

    self.current = self.animation[i]
    return self.current
  }
}

open class ProgressTask: Identifiable {
  /// Description of the task should not change
  open var description: String { "" }
  open var shortDescription: String { self.description }
  /// Intermediate messages can change while the task is executing
  open var intermediateMessage: String? { self._intermediateMessage }
  private var _intermediateMessage: String? = nil

  open var finished: Bool { self._finished }
  private var _finished: Bool = false

  public private(set) var isError: Bool = false
  public private(set) var isCancelled: Bool = false
  /// Progress percentage (from 0 to 100) or nil for a generic loading animation
  open var progress: Int? { nil }
  open var spinner: Spinner? { nil }
  /// Should only be accessed when spinner is not nil
  lazy var spinnerIterator: (any SpinnerIteratorProtocol) = self.spinner!.makeIterator()

  public private(set) var useRaw: Bool

  open func finish() {
    self._finished = true
    if self.useRaw {
      ProgressIndicators.global.rawPrintEnd(task: self)
    }
  }

  public init(
    intermediateMessage: String? = nil
  ) {
    self._intermediateMessage = intermediateMessage
    self.useRaw = ProgressIndicators.global.format.outputWith == .raw
    if self.useRaw {
      ProgressIndicators.global.rawPrintStart(task: self)
    }
  }

  public func setMessage(_ msg: String) {
     if self.useRaw {
       ProgressIndicators.global.rawPrint(task: self, message: msg)
     } else {
       self._intermediateMessage = msg
     }
  }

  public func setError() {
    self.isError = true
    self.finish()
  }

  public func cancel() {
    self.isCancelled = true
    self.finish()
  }
}

public final class SpinnerProgressTask: ProgressTask, @unchecked Sendable {
  public override var description: String { self._description }

  private let _description: String
  private let _spinner: Spinner

  public override var spinner: Spinner? { self._spinner }

  public init(
    _ description: String,
    intermediateMessage: String? = nil,
    spinner: Spinner = Spinner(animation: [
      "*--",
      "-*-",
      "--*"
    ])
  ) {
    self._description = description
    self._spinner = spinner
    super.init(intermediateMessage: intermediateMessage)
  }
}

public final class ProgressBarTask: ProgressTask, @unchecked Sendable {
  public override var description: String { self._description }
  public override var progress: Int? { min(Int((Double(self._progress) / Double(self.total)) * 100.0), 100) }
  public override var finished: Bool { self._progress >= self.total }

  private let _description: String

  private var total: Int
  private var _progress: Int

  public init(
    _ description: String,
    intermediateMessage: String? = nil,
    total: Int = 100,
    start: Int = 0
  ) {
    self._description = description
    self.total = total
    self._progress = start
    super.init(intermediateMessage: intermediateMessage)
  }

  public func progress(count: Int = 1) {
    self._progress += count
  }

  public override func finish() {
    self._progress = self.total
    super.finish()
  }
}

extension ProgressTask: CustomDebugStringConvertible {
  public var debugDescription: String {
    let status: String
    if self.isError {
      status = "error"
    } else if self.isCancelled {
      status = "cancelled"
    } else if self.finished {
      status = "finished"
    } else {
      status = "running"
    }
    return "ProgressTask(\(self.description), status: \(status))"
  }
}
