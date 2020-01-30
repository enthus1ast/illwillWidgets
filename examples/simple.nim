import illwill
import illwillWidgets
import os


# default illwill boilerplate
proc exitProc() {.noconv.} =
  illwillDeinit()
  showCursor()
  quit(0)

illwillInit(fullscreen=true, mouse=true) # <- enable mouse support
setControlCHook(exitProc)
hideCursor()

var tb = newTerminalBuffer(terminalWidth(), terminalHeight())

# Create widgets
var infoBox = newInfoBox("",0 ,0, terminalWidth())
var btnFill = newButton("fill", 38, 3, 15, 2)
var btnClear = newButton("clear", 38, 6, 15, 2)

while true:

  var key = getKey()

  # Test if the key signals a mouse event.
  if key == Key.Mouse:

    # get the mouse information from illwill
    var mi: MouseInfo = getMouse()

    # to catch the widgets events
    var ev: Events

    # we must call dispatch on every widget.
    # dispatch returns events that the widget fires.
    ev = tb.dispatch(btnFill, mi)
    if ev.contains MouseUp:
      # do stuff when mouse button releases
      tb.clear("A")
    if ev.contains MouseHover:
      # do stuff when mouse hover over element
      infoBox.text = "Fills the screen!!"

    # Another button to clear the screen again
    ev = tb.dispatch(btnClear, mi)
    if ev.contains MouseUp:
      # do stuff when mouse button releases
      tb.clear()
    if ev.contains MouseHover:
      # do stuff when mouse hover over element
      infoBox.text = "clear the screen"


    # After dispatching we need to actually render the element
    # into the terminal buffer
    tb.render(btnFill)
    tb.render(btnClear)
    tb.render(infoBox)

  # Draw the terminal buffer to screen.
  tb.display()

  sleep(25)