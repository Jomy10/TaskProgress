import TaskProgress
import SwiftCurses

if #available(macOS 13.0, *) {
  ProgressIndicators.global.show()

  let main = SpinnerProgressTask("Building module Main")
  main.setMessage("waiting on Logging")
  ProgressIndicators.global.addTask(main)

  Task {
    try await Task.sleep(for: .seconds(3))
    let loggingTask = ProgressBarTask("Building module Logging", total: 100)
    ProgressIndicators.global.addTask(loggingTask)
    for _ in 0..<100 {
      loggingTask.progress()
      try await Task.sleep(for: .seconds(0.1))
    }
    main.finish()
  }

  while true {
    await Task.yield()
    if ProgressIndicators.global.finished {
      break
    }
  }
} else {
  fatalError("Example requires macOS 13")
}
