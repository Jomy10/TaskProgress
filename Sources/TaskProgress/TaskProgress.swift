import Foundation
//import SwiftCurses

public enum ProgressIndicatorsError: Error {
  case noTask(NoTaskData)
  /// `ProgressTask.progress()` can't be used on spinners
  case spinnerCantProgress

  public enum NoTaskData: Sendable, CustomStringConvertible {
    case named(String)
    case withId(Int)

    public var description: String {
      switch (self) {
        case .named(let name): return "named: \(name)"
        case .withId(let id): return "id: \(id)"
      }
    }
  }
}

public struct ProgressFormat {
  let showIntermediateMessages: Bool
  let showFinishedTasks: Bool
  let outputWith: Output
  let useColor: Bool

  public enum Output {
    /// Print in the current terminal
    case ansi
    /// Print in an ncurses session
    //case curses
    /// Print messages directly to the terminal
    case raw
  }

  public init(
    showIntermediateMessages: Bool = true,
    showFinishedTasks: Bool = true,
    outputWith: Output = .ansi
  ) {
    self.showIntermediateMessages = showIntermediateMessages
    self.showFinishedTasks = true
    if isatty(STDOUT_FILENO) == 1 {
      self.outputWith = outputWith
      self.useColor = true
    } else {
      self.outputWith = .raw
      self.useColor = false
    }
  }
}

public final class ProgressIndicators: @unchecked Sendable {
  public nonisolated(unsafe) static var global = ProgressIndicators()

  let lock: NSLock
  var tasks: [ProgressTask] = []
  var screenTask: Task<Void, any Error>?
  var format: ProgressFormat
  public private(set) var finished: Bool {
    get {
      if self.rawOutput {
        self.allFinished
      } else {
        self._finished
      }
    }
    set {
      self._finished = newValue
    }
  }
  private var _finished: Bool = false

  var _globalMessages: [String] = []

  private var forceRefresh: Bool
  private var rawOutput: Bool

  public init(format: ProgressFormat = ProgressFormat()) {
    self.screenTask = nil
    self.lock = NSLock()
    self.format = format
    self.forceRefresh = false
    self.rawOutput = false
  }

  public func setFormat(_ format: ProgressFormat) {
    self.lock.withLock {
      self.format = format
      self.forceRefresh = true
    }
  }

  public func finishAll() {
    self.tasks.forEach { task in
      task.finish()
    }
  }

  var allFinished: Bool {
    self.lock.withLock {
      self.tasks.first(where: { !$0.finished }) == nil
    }
  }

  /// start showing the indicators
  public func show() {
    switch(self.format.outputWith) {
      case .ansi:
        self.useAnsi()
      case .raw:
        self.usePrint()
    }
  }

  private func useAnsi() {
    self.lock.withLock {
      self.screenTask = Task.detached(priority: .background) {
        Ansi.hideCursor()
        var prevLineCount = self.printAnsi(updateSpinners: false)
        var time: TimeInterval = ProcessInfo.processInfo.systemUptime
        while true {
          await Task.yield()
          Ansi.cursorUp(lines: prevLineCount)

          self.lock.withLock {
            for message in self._globalMessages {
              print(message + AnsiCodes.clearToEndOfLine())
            }
            self._globalMessages.removeAll(keepingCapacity: true)
          }

          let newTime = ProcessInfo.processInfo.systemUptime
          let update = newTime - time >= 0.5 // next animation frame every half second
          if update {
            time = newTime
          }
          let newLineCount = self.printAnsi(updateSpinners: update)
          let linesToClear = prevLineCount - newLineCount

          if linesToClear > 0 {
            print(String(repeating: AnsiCodes.clearToEndOfLine() + "\n", count: linesToClear), terminator: "")
            //for _ in 0..<linesToClear {
            //  print(AnsiCodes.clearToEndOfLine(), terminator: "\n")
            //}
            Ansi.cursorUp(lines: linesToClear)
          }
          prevLineCount = newLineCount
          if self.allFinished {
            Ansi.cursorUp(lines: prevLineCount)
            _ = self.printAnsi(updateSpinners: false)
            self.finished = true
            Ansi.showCursor()
            break
          }
        }
      }
    }
  }

  private func printAnsi(updateSpinners: Bool) -> Int {
    var linesPrinted = 0
    if self.format.showFinishedTasks {
      var finishedTasks: [ProgressTask] = Array()
      self.lock.withLock {
        finishedTasks = self.tasks.filter({ $0.finished })
      }
      linesPrinted += finishedTasks.count
      for task in finishedTasks {
        //print("[\(AnsiCodes.green)DONE\(AnsiCodes.reset)] \(task.description)\(AnsiCodes.clearToEndOfLine())")
        self.rawPrintEnd(task: task)
      }
    }

    var tasks: [ProgressTask] = Array()
    self.lock.withLock {
      tasks = self.tasks.filter({ !$0.finished })
    }
    linesPrinted += tasks.count
    for task in tasks {
      let indicator: String
      if let progress = task.progress {
        indicator = String(progress).padding(toLength: 3, withPad: " ", startingAt: 0)
      } else if task.spinner != nil {
        if updateSpinners {
          indicator = task.spinnerIterator.next()! as! String
        } else {
          indicator = (task.spinnerIterator.current ?? task.spinnerIterator.next()) as! String
        }
      } else {
        indicator = "..."
      }
      print("[\(indicator)] \(task.description)\(AnsiCodes.clearToEndOfLine())")
      if self.format.showIntermediateMessages {
        if let intermediateMessage = task.intermediateMessage {
          print("\(AnsiCodes.darkGray)\(intermediateMessage)\(AnsiCodes.reset)\(AnsiCodes.clearToEndOfLine())")
          linesPrinted += 1
        }
      }
    }

    return linesPrinted
  }

  private func usePrint() {
    self.lock.withLock {
      self.rawOutput = true
    }
  }

  func rawPrintStart(task: borrowing ProgressTask) {
    print("[starting] \(task.description)")
  }

  func rawPrint(task: borrowing ProgressTask, message: borrowing String) {
    print("[\(task.shortDescription)] \(message)")
  }

  func rawPrintEnd(task: borrowing ProgressTask) {
    if self.format.useColor {
      if task.isError {
        print("[\(AnsiCodes.red)ERR\(AnsiCodes.reset)] \(task.description)")
      } else {
        print("[\(AnsiCodes.green)DONE\(AnsiCodes.reset)] \(task.description)")
      }
    } else {
      if task.isError {
        print("[ERR] \(task.description)")
      } else {
        print("[DONE] \(task.description)")
      }
    }
  }

  public func addTask(_ task: ProgressTask) {
    self.lock.withLock {
      self.tasks.append(task)
    }
  }

  public func globalMessage(_ msg: String) {
    switch (self.format.outputWith) {
      case .ansi:
        self.lock.withLock {
          self._globalMessages.append(msg)
        }
        break
      case .raw:
        print(msg)
    }
  }
}

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

  open var isError: Bool { self._isErr }
  private var _isErr: Bool = false
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
    self._isErr = true
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
