import Foundation

//public enum ProgressIndicatorsError: Error {
//  case noTask(NoTaskData)

//  public enum NoTaskData: Sendable, CustomStringConvertible {
//    case named(String)
//    case withId(Int)

//    public var description: String {
//      switch (self) {
//        case .named(let name): return "named: \(name)"
//        case .withId(let id): return "id: \(id)"
//      }
//    }
//  }
//}

public final class ProgressIndicators: @unchecked Sendable {
  public nonisolated(unsafe) static var global = ProgressIndicators()

  let lock: NSLock
  public private(set) var tasks: [ProgressTask] = []
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
  private var canClose: Bool = false

  var _globalMessages: [String] = []

  private var forceRefresh: Bool
  private var rawOutput: Bool

  private init(format: ProgressFormat = ProgressFormat()) {
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

  /// When `format.autoClose` is false, this has to be called before the ProgressIndicators will terminate.
  /// Note that this will not immediately close the indicators. All tasks need to either be done, cancelled
  /// have an error
  public func setCanClose() {
    self.canClose = true
  }

  private func useAnsi() {
    self.lock.withLock {
      self.screenTask = Task.detached(priority: .background) {
        Ansi.hideCursor()
        var prevLineCount = self.printAnsi(updateSpinners: false)
        var time: TimeInterval = ProcessInfo.processInfo.systemUptime
        var prevWasFinished = false
        while true {
          await Task.yield()

          if self.allFinished {
            if prevWasFinished && !self.format.autoClose && !self.canClose {
              continue
            }
            Ansi.cursorUp(lines: prevLineCount)
            prevLineCount = self.printAnsi(updateSpinners: false)
            Ansi.showCursor()
            prevWasFinished = true
            if !self.format.autoClose && !self.canClose {
              continue
            }
            self.finished = true
            break
          } else {
            prevWasFinished = false
          }

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
      } else if task.isCancelled {
        print("[\(AnsiCodes.yellow)CANCELLED\(AnsiCodes.reset)] \(task.description)")
      } else {
        print("[\(AnsiCodes.green)DONE\(AnsiCodes.reset)] \(task.description)")
      }
    } else {
      if task.isError {
        print("[ERR] \(task.description)")
      } else if task.isCancelled {
        print("[CANCELLED] \(task.description)")
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
