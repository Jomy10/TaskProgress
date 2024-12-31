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
      //case .curses:
      //  self.useCurses()
      case .ansi:
        self.useAnsi()
      case .raw:
        self.usePrint()
    }
  }

  func printAll() {
    self.lock.withLock {
      let finishedTasks = self.tasks.filter { $0.finished }
      let tasks = self.tasks.filter { !$0.finished }

      let done = self.format.useColor ? "\u{001B}[32mDONE\u{001B}[0m" : "DONE"
      if self.format.showFinishedTasks {
        for finishedTask in finishedTasks {
          print("[\(done)] \(finishedTask.description)")
        }
      }

      for task in tasks {
        let indicator: String
        if let progress = task.progress {
          indicator = String(progress).padding(toLength: 3, withPad: " ", startingAt: 0)
        } else if task.spinner != nil {
          indicator = (task.spinnerIterator.current ?? "...") as! String
        } else {
          indicator = "..."
        }
        print("[\(indicator)] \(task.description)\(AnsiCodes.clearToEndOfLine())")
      }
    }
  }

  //private func useCurses() {
  //    let greyPair: ColorPairId = 1
  //    let greenPair: ColorPairId = 2
  //
  //  self.lock.withLock {
  //    self.screenTask = Task.detached(priority: .background) {
  //      try! await initScreenAsync { scr in
  //        try? ColorPair.define(greyPair, fg: 8, bg: Color.black)
  //        try? ColorPair.define(greenPair, fg: Color.green, bg: Color.black)
  //        var taskCount = 0
  //        var finishedTaskCount = 0
  //        var windowSize = scr.maxYX
  //        var redraw = true
  //        var tasks: [ProgressTask] = Array()
  //        self.lock.withLock { tasks = self.tasks }
  //        var finishedTasks: [ProgressTask] = []
  //        var time: TimeInterval = ProcessInfo.processInfo.systemUptime
  //        while true {
  //          finishedTasks = self.tasks.filter { $0.finished }
  //          let newFinishedTaskCount = finishedTasks.count
  //          if windowSize != scr.maxYX {
  //            windowSize = scr.maxYX
  //            redraw = true
  //          } else if self.tasks.count != taskCount {
  //            //do {
  //            //  try scr.move(row: scr.maxYX.row - Int32(taskCount), col: 0)
  //            //  try scr.clear(until: .endOfScreen)
  //            //} catch {
  //            //  scr.clear()
  //            //}
  //            self.lock.withLock {
  //              taskCount = self.tasks.count
  //              self.lock.withLock { tasks = self.tasks.filter { !$0.finished } }
  //            }
  //            redraw = true
  //          } else if self.forceRefresh {
  //            self.lock.withLock {
  //              self.forceRefresh = false
  //            }
  //            redraw = true
  //          } else if newFinishedTaskCount != finishedTaskCount {
  //            finishedTaskCount = newFinishedTaskCount
  //            self.lock.withLock { tasks = self.tasks.filter { !$0.finished } }
  //            redraw = true
  //          }

  //          let mul = self.format.showIntermediateMessages ? 2 : 1
  //          // Redraw all
  //          if redraw {
  //            scr.clear()
  //            for (i, task) in tasks.enumerated() {
  //              let y = windowSize.row - Int32((tasks.count - i) * mul)
  //              if y < 0 { continue }
  //              try scr.move(row: y, col: 0)
  //              try? scr.print("[...] \(task.description)")
  //            }

  //            if self.format.showFinishedTasks {
  //              var count = tasks.count
  //              if self.format.showIntermediateMessages {
  //                count *= 2
  //              }
  //              let base = windowSize.row - Int32(count)
  //              if base > 0 {
  //                for (i, task) in finishedTasks.reversed().enumerated() {
  //                  let y = base - Int32(finishedTaskCount - i)
  //                  if y < 0 { continue }
  //                  try scr.move(row: y, col: 0)
  //                  try scr.print("[")
  //                  try scr.withAttrs(.colorPair(Int32(greenPair))) {
  //                    try scr.print("DONE")
  //                  }
  //                  try scr.print("] \(task.description)")
  //                }
  //              }
  //            }

  //            redraw = false
  //          }

  //          // Redraw spinners
  //          let newTime = ProcessInfo.processInfo.systemUptime
  //          let update = newTime - time >= 0.5 // next animation frame every half second
  //          if update {
  //            time = newTime
  //          }
  //          for (i, task) in tasks.enumerated() {
  //            let y = windowSize.row - Int32((tasks.count - i) * mul)
  //            if y < 0 { continue }
  //            let indicator: String
  //            if let progress = task.progress {
  //              indicator = String(progress).padding(toLength: 3, withPad: " ", startingAt: 0)
  //            } else if task.spinner != nil {
  //              if update {
  //                indicator = task.spinnerIterator.next()! as! String
  //              } else {
  //                indicator = (task.spinnerIterator.current ?? task.spinnerIterator.next()) as! String
  //              }
  //            } else {
  //              indicator = "..."
  //            }
  //            try scr.move(row: y, col: 1)
  //            try scr.print(indicator)
  //          }

  //          // Redraw intermediate messages
  //          if self.format.showIntermediateMessages {
  //            for (i, task) in tasks.enumerated() {
  //              let y = windowSize.row - Int32((tasks.count - i) * mul)
  //              if y < 0 { continue }
  //              if let intermediateMessage = task.intermediateMessage {
  //                try scr.withAttrs(.colorPair(Int32(greyPair))) {
  //                  try scr.move(row: y + 1, col: 0)
  //                  try scr.clear(until: .endOfLine)
  //                  try scr.move(row: y + 1, col: 0)
  //                  try? scr.print("\(intermediateMessage)")
  //                }
  //              }
  //            }
  //          }

  //          scr.refresh()
  //          if taskCount == finishedTaskCount {
  //            self.finished = true
  //            break
  //          }
  //          await Task.yield()
  //        }
  //      }
  //      self.printAll()
  //    }
  //  }
  //}

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
        print("[\(AnsiCodes.green)DONE\(AnsiCodes.reset)] \(task.description)\(AnsiCodes.clearToEndOfLine())")
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
      print("[\(AnsiCodes.green)DONE\(AnsiCodes.reset)] \(task.description)")
    } else {
      print("[DONE] \(task.description)")
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

  public init() {
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
}

public final class SpinnerProgressTask: ProgressTask, @unchecked Sendable {
  public override var description: String { self._description }
  public override var intermediateMessage: String? { self._intermediateMessage }
  //public override var finished: Bool { self._finished }

  private let _description: String
  private var _intermediateMessage: String?
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
    self._intermediateMessage = intermediateMessage
    self._spinner = spinner
    super.init()
  }
}

public final class ProgressBarTask: ProgressTask, @unchecked Sendable {
  public override var description: String { self._description }
  public override var intermediateMessage: String? { self._intermediateMessage }
  public override var progress: Int? { min(Int((Double(self._progress) / Double(self.total)) * 100.0), 100) }
  public override var finished: Bool { self._progress >= self.total }

  private let _description: String
  private var _intermediateMessage: String?

  private var total: Int
  private var _progress: Int

  public init(
    _ description: String,
    intermediateMessage: String? = nil,
    total: Int = 100,
    start: Int = 0
  ) {
    self._description = description
    self._intermediateMessage = intermediateMessage
    self.total = total
    self._progress = start
    super.init()
  }

  public func progress(count: Int = 1) {
    self._progress += count
  }

  public override func finish() {
    self._progress = self.total
    super.finish()
  }
}
