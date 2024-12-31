import TaskProgress

if #available(macOS 13.0, *) {
  ProgressIndicators.global.show()
  ProgressIndicators.global.setFormat(ProgressFormat(autoClose: false))

  let main = SpinnerProgressTask("Building module Main")
  main.setMessage("waiting on Logging")
  ProgressIndicators.global.addTask(main)


  Task {
    try await Task.sleep(for: .seconds(1))
    let loggingTask = ProgressBarTask("Building module Logging", total: 100)
    ProgressIndicators.global.addTask(loggingTask)
    for i in 0..<100 {
      loggingTask.progress()
      if i == 75 {
        loggingTask.setMessage("Almost done...")
      } else if i == 50 {
        ProgressIndicators.global.globalMessage("We're halfway there")
      }
      try await Task.sleep(for: .seconds(0.1))
    }
    let newTask = ProgressBarTask("Building module Printing", total: 3)
    ProgressIndicators.global.addTask(newTask)
    for _ in 0..<3 {
      try await Task.sleep(for: .seconds(2))
      newTask.progress()
    }
    main.finish()
    ProgressIndicators.global.setCanClose() // required when autoClose if off
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
