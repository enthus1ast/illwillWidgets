# import ../src/widgets
import illwill
import strformat, strutils
import asyncdispatch, httpclient# for async demonstration
import os

proc exitProc() {.noconv.} =
  illwillDeinit()
  showCursor()
  quit(0)

illwillInit(fullscreen=true, mouse=true)
setControlCHook(exitProc)
hideCursor()

var tb = newTerminalBuffer(terminalWidth(), terminalHeight())
while true:
  var key = getKey()
  sleep(50)