# illwillWidgets
mouse enabled widget library for [illwill](https://github.com/johnnovak/illwill)!

[![asciicast](https://asciinema.org/a/GO4nhu01AItIrS1ihBoPWlMeH.svg)](https://asciinema.org/a/GO4nhu01AItIrS1ihBoPWlMeH)

OS Support
==========

linux, windows, macos

Widgets
=======

- buttons
- checkbox
- radiobox
- listview
- (simple) textbox
- "info" box (like a status bar)
- progressbar / slider
- table w/ fixed header
example
=======

```nim
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

```

more examples
=============

for a complete example see [examples/demo.nim](examples/demo.nim)


changelog
=========
- 0.1.9
  - Added `TableBox` to render a table of data w/ a fixed header
- 0.1.8
  - Elements of a radio group box are pointer now. Before they where copied into the element.
  - radio group box: `uncheckAll`
  - `positionHelper(coords: MouseInfo): string` returns the mouse position absolute and from the edges
  - progress bar does hightlight text background
    - colorText: fgColor # text color when not done
    - colorTextDone: fgColor # text color when done
