import Foundation

public struct ProgressFormat {
  let showIntermediateMessages: Bool
  let showFinishedTasks: Bool
  let outputWith: Output
  let useColor: Bool
  let autoClose: Bool

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
    outputWith: Output = .ansi,
    autoClose: Bool = false
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
    self.autoClose = autoClose
  }
}
