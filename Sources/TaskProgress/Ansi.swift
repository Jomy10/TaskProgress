struct Ansi {
  static func setCursorPos(y: Int, x: Int) {
    print(AnsiCodes.setCursorPos(y: y, x: x), terminator: "")
  }

  static func cursorUp(lines: Int = 1) {
    print(AnsiCodes.cursurUp(lines: lines), terminator: "")
  }

  static func cursorDown(lines: Int = 1) {
    print(AnsiCodes.cursorDown(lines: lines), terminator: "")
  }

  static func cursorForward(lines: Int = 1) {
    print(AnsiCodes.cursorForward(lines: lines), terminator: "")
  }

  static func cursorBackward(lines: Int = 1) {
    print(AnsiCodes.cursorBackward(lines: lines), terminator: "")
  }

  static func clear() {
    print(AnsiCodes.clear(), terminator: "")
  }

  static func clearToEndOfLine() {
    print(AnsiCodes.clearToEndOfLine(), terminator: "")
  }

  static func hideCursor() {
    print(AnsiCodes.hideCursor(), terminator: "")
  }

  static func showCursor() {
    print(AnsiCodes.showCursor(), terminator: "")
  }
}

struct AnsiCodes {
  static func setCursorPos(y: Int, x: Int) -> String {
    "\u{001B}[\(y);\(x)H"
  }

  static func cursurUp(lines: Int = 1) -> String {
    "\u{001B}[\(lines)A"
  }

  static func cursorDown(lines: Int = 1) -> String {
    "\u{001B}[\(lines)B"
  }

  static func cursorForward(lines: Int = 1) -> String {
    "\u{001B}[\(lines)C"
  }

  static func cursorBackward(lines: Int = 1) -> String {
    "\u{001B}[\(lines)D"
  }

  /// Clear screen and move to 0, 0
  static func clear() -> String {
    "\u{001B}[2J"
  }

  static func clearToEndOfLine() -> String {
    "\u{001B}[K"
  }

  static func saveCursorPos() -> String {
    "\u{001B}[s"
  }

  static func restoreCursorPos() -> String {
    "\u{001B}[u"
  }

  static func hideCursor() -> String {
    "\u{001B}[?25l"
  }

  static func showCursor() -> String {
    "\u{001B}[?25h"
  }

  public static let black: String           = "\u{001B}[30m"
  public static let red: String             = "\u{001B}[31m"
  public static let green: String           = "\u{001B}[32m"
  public static let yellow: String          = "\u{001B}[33m"
  public static let blue: String            = "\u{001B}[34m"
  public static let magenta: String         = "\u{001B}[35m"
  public static let cyan: String            = "\u{001B}[36m"
  public static let lightGray: String       = "\u{001B}[37m"
  public static let darkGray: String        = "\u{001B}[90m"
  public static let lightRed: String        = "\u{001B}[91m"
  public static let lightGreen: String      = "\u{001B}[92m"
  public static let lightYellow: String     = "\u{001B}[93m"
  public static let lightBlue: String       = "\u{001B}[94m"
  public static let lightMagenta: String    = "\u{001B}[95m"
  public static let lightCyan: String       = "\u{001B}[96m"
  public static let white: String           = "\u{001B}[97m"
  public static let reset: String           = "\u{001B}[0m"
}
