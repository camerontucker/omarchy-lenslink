import QtQuick
import Quickshell.Io

Process {
  id: process
  property int outputLimit: 16384
  property bool streaming: false
  property string output: ""
  property string errorOutput: ""
  property bool rejected: false
  signal lineReady(string line)
  signal completed(string output, string error, int code)
  clearEnvironment: true
  environment: ({ HOME: null, XDG_CONFIG_HOME: null, XDG_CACHE_HOME: null,
                  PATH: "/usr/bin", LANG: "C", LC_ALL: "C" })

  function reject() {
    rejected = true
    output = ""
    errorOutput = "Camera helper safety limit exceeded"
    running = false // Stop this helper; protocol readers also enforce deadlines.
  }
  stdout: SplitParser {
    splitMarker: "" // raw chunks: never buffer an unbounded unterminated line
    onRead: function(chunk) {
      if (process.rejected) return
      if (chunk.length > process.outputLimit || process.output.length + chunk.length > process.outputLimit) {
        process.reject()
        return
      }
      process.output += chunk
      if (process.streaming) {
        const newline = process.output.indexOf("\n")
        if (newline >= 0) {
          if (newline !== process.output.length - 1) { process.reject(); return }
          const line = process.output.slice(0, newline)
          process.output = ""
          process.lineReady(line)
        }
      }
    }
  }
  stderr: SplitParser {
    splitMarker: ""
    onRead: function(chunk) {
      if (process.rejected) return
      if (chunk.length > 4096 || process.errorOutput.length + chunk.length > 4096) {
        process.reject()
        return
      }
      process.errorOutput += chunk
    }
  }
  onStarted: {
    output = ""
    errorOutput = ""
    rejected = false
  }
  onExited: function(code, status) {
    completed(output, errorOutput, rejected ? 1 : code)
    output = ""
    errorOutput = ""
  }
  Component.onDestruction: running = false
}
