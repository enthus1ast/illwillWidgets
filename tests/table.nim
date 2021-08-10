import illwill, illwillWidgets
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

var tb = newTerminalBuffer(50, 30)

var table = newTableBox(1, 1, 40, 7)
table.addCol("#", 2)
table.addCol("Name", 10)
table.addCol("Age", 4)
table.addCol("Notes", 40)

table.addRow(@["1", "John Doe", "40"])
table.addRow(@["2", "Jane Doe", "38"])
while true:
  tb.clear()
  tb.render(table)
  tb.display()
  sleep(100)