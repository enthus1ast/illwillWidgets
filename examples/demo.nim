import ../src/illwillWidgets
import illwill
import strformat, strutils
import asyncdispatch, httpclient # for async demonstration

proc exitProc() {.noconv.} =
  illwillDeinit()
  showCursor()
  quit(0)

illwillInit(fullscreen=true, mouse=true)
setControlCHook(exitProc)
hideCursor()

# Button
var btnAsyncHttp = newButton("async http", 21, 3, 15, 2)
var btnTest = newButton("fill", 38, 3, 15, 2)
var btnClear = newButton("clear", 38, 6, 15, 2)
var btnNoBorder = newButton("no border", 21, 7, 15, 1, border = false)

# Checkbox
var chkTest = newCheckbox("Some content", 38, 9)
var chkTest2 = newCheckbox("Fill Color", 38, 10)
chkTest2.textUnchecked = ":)  "
chkTest2.textChecked =   ":(  "

var chkDraw = newCheckbox("Draw?", 38, 11)

# Info box
var infoBox = newInfoBox("", 0 ,0, terminalWidth())
var infoBoxMouse = newInfoBox("", 0 ,0, terminalWidth())
var infoBoxAsync = newInfoBox("", 0 ,1, terminalWidth())
var infoBoxMulti = newInfoBox("", 93 ,3, 25, 10)
infoBoxMulti.bgcolor = bgYellow

# Radio buttons
var chkRadA = newRadioBox("Radio Box Option A", 56, 4)
chkRadA.checked = true
var chkRadB = newRadioBox("Radio Box Option B", 56, 5)
var chkRadC = newRadioBox("Radio Box Option C", 56, 6)
var radioBoxGroup = newRadioBoxGroup(@[
  addr chkRadA, addr chkRadB, addr chkRadC
])

var chooseBox = newChooseBox(@[" ", "#", "@", "§"], 81, 3, 10, 5, choosenidx=2)

var textBox = newTextBox("foo", 38, 13, 42, placeholder = "Some placeholder")

var progressBarAsync = newProgressBar("some text", 18, 15, 100, 0.0, 50.0)
var infoProgressBarAsync = newInfoBox("", 18, 16, 100)
var progressBarInteract = newProgressBar("some text", 18, 18, 50, 0.0, 50.0, bgDone = bgBlue, bgTodo = bgWhite)

# TODO not working properly yet
var progressBarVertical = newProgressBar("some text", 2, 5, 10, 0.0, 50.0, Vertical)
progressBarVertical.value = 50.0

var infoProgressBarInteract = newInfoBox("", 18, 19, 50)
var labelProgressBarInteract = newInfoBox("<-- interact with me! (left, right click, scroll)", 70, 18, 50, bgcolor = bgBlack, color = fgWhite)

var table = newTableBox(1, 20, 40, 6)
table.addCol("#", 2)
table.addCol("Name", 10)
table.addCol("Age", 4)
table.addCol("Notes", 40)
table.addRow(@["1", "John Doe", "40", "Most Wanted"])
table.addRow(@["2", "Jane Doe", "38", "Missing"])

proc asyncDemo(): Future[void] {.async.} =
  var idx = 0
  while true:
    idx.inc
    infoBoxAsync.text = "Async Demo: " & $idx
    progressBarAsync.value = (idx mod progressBarAsync.maxValue.int).float
    progressBarVertical.value = (idx mod progressBarAsync.maxValue.int).float
    infoProgressBarAsync.text =
      fmt"{progressBarAsync.value}/{progressBarAsync.maxValue}  percent: {progressBarAsync.percent}"
    # echo progressBar.value
    await sleepAsync(1000)
asyncCheck asyncDemo()

proc httpCall(tb: ptr TerminalBuffer): Future[void] {.async.} =
  var client = newHttpClient()
  tb[].write(22, 6, $client.getContent("http://ip.code0.xyz").strip())

proc dumpMi(tb: var TerminalBuffer, mi: MouseInfo) =
  infoBoxMulti.text = (repr mi) #.split("\n")
  # var idx = 0
  # for line in (repr mi).split("\n"):
  #   tb.write 93, 3 + idx, bgYellow, fgBlack, $line.alignLeft(25), resetStyle
  #   idx.inc

proc funDraw(tb: var TerminalBuffer, mi: MouseInfo) =
  tb.write resetStyle
  if mi.action == mbaPressed:
    case mi.button
    of mbLeft:
      tb.write mi.x, mi.y, fgRed, "♥"
    of mbMiddle:
      tb.write mi.x, mi.y, fgBlue, "◉"
    of mbRight:
      tb.write mi.x, mi.y, fgCyan, "#"
    else: discard
  elif mi.action == mbaReleased:
    tb.write mi.x, mi.y,  fgGreen, "⌀"

var tb = newTerminalBuffer(terminalWidth(), terminalHeight())

while true:
  ## When terminal size change create new buffer to reflect size change
  if tb.width != terminalWidth() or tb.height != terminalHeight():
    tb = newTerminalBuffer(terminalWidth(), terminalHeight())

  var key = getKey()

  # Must be done for every textbox
  if textBox.focus:
    if tb.handleKey(textBox, key):
      tb.write(0,2, bgYellow, fgBlue, textBox.text)
      chooseBox.add(textBox.text)
    key.setKeyAsHandled() # If the key input was handled by the textbox

  case key
  of Key.None: discard
  of Key.Escape, Key.Q: exitProc()
  of Key.Mouse: #, Key.None: # TODO Key.None here does not work with checkbox
    let coords = getMouse()
    infoBoxMouse.text = $coords
    var ev: Events

    ev = tb.dispatch(btnAsyncHttp, coords)
    if ev.contains MouseUp:
      asyncCheck httpCall(addr tb) # the `addr` here is just for demo purpose, not recommend
    if ev.contains MouseHover:
      infoBox.text = "http call to http://ip.code0.xyz to get your public ip!"

    ev = tb.dispatch(btnNoBorder, coords)
    # if ev.contains MouseUp:
    #   asyncCheck httpCall(addr tb) # the `addr` here is just for demo purpose, not recommend
    # if ev.contains MouseHover:
    #   infoBox.text = "http call to http://ip.code0.xyz to get your public ip!"


    ev = tb.dispatch(btnClear, coords)
    if ev.contains MouseUp:
      tb.clear()
      tb.write resetStyle
    if ev.contains MouseHover:
      infoBox.text = "CLEARS THE SCREEN!"

    ev = tb.dispatch(btnTest, coords)
    if ev.contains MouseUp:
      tb.clear(chooseBox.element)
      tb.write resetStyle
    if ev.contains MouseHover:
      infoBox.text = "Fills the screen!!"

    ev = tb.dispatch(chkTest, coords)
    if ev.contains MouseUp:
      infoBox.text = "chk test is: " & $chkTest.checked

    ev = tb.dispatch(chkTest2, coords)
    if ev.contains MouseUp:
      if chkTest2.checked:
        infoBox.text = "red"
        tb.setForegroundColor fgRed
        chkTest2.color = fgRed
      else:
        infoBox.text = "green"
        chkTest2.color = fgGreen
        tb.setForegroundColor fgGreen

    ev = tb.dispatch(chkDraw, coords)
    if ev.contains MouseHover:
      infoBox.text = "Enables/Disables drawing"
    # We enable / disable drawing based on checkbox value
    if chkDraw.checked:
      tb.funDraw(coords)

    ev = tb.dispatch(infoBox, coords)
    if ev.contains MouseDown:
      infoBox.text &= "#"
    if ev.contains MouseUp:
      infoBox.text &= "^"

    ev = tb.dispatch(chooseBox, coords)
    if ev.contains MouseUp:
      infoBox.text = fmt"Choose box choosenidx: {chooseBox.choosenidx} -> {chooseBox.element()}"

    # Textbox is special! (see above for `handleKey`)
    ev = tb.dispatch(textBox, coords)

    # RadioBoxGroup dispatches to all group members
    ev = tb.dispatch(radioBoxGroup, coords)
    if ev.contains MouseUp:
      infoBox.text = fmt"Radio button with content '{radioBoxGroup.element().text}' selected."

    ev = tb.dispatch(progressBarAsync, coords)
    if ev.contains MouseHover:
      infoBox.text = "i get filled by the async code!"

    ev = tb.dispatch(progressBarVertical, coords) # does nothing; is stupid
    if ev.contains MouseDown:
      if coords.button == mbLeft:
        progressBarVertical.value = progressBarVertical.valueOnPos(coords)
        infoBox.text = $progressBarVertical.value


    ev = tb.dispatch(progressBarInteract, coords)
    if ev.contains MouseHover:
      infoBox.text = "Interactive progress bar! (left, right click or scroll)"
      if coords.scroll:
        if coords.scrollDir == sdUp:
          progressBarInteract.percent = progressBarInteract.percent - 5.0
        if coords.scrollDir == sdDown:
          progressBarInteract.percent = progressBarInteract.percent + 5.0
    if ev.contains MouseDown:
      if coords.button == mbLeft:
        progressBarInteract.value = progressBarInteract.valueOnPos(coords)
      if coords.button == mbRight:
        progressBarInteract.percent = 50.0
    infoProgressBarInteract.text =
      fmt"{progressBarInteract.value}/{progressBarInteract.maxValue}  percent: {progressBarInteract.percent}"
    # tb.write(70, 17, "<-- interact with me! (left, right click, scroll)")
    tb.dumpMi(coords) # to print mouse debug infos

  else:
    infoBox.text = $key
    discard

  tb.render(btnAsyncHttp)
  tb.render(btnNoBorder)
  tb.render(btnClear)
  tb.render(btnTest)

  tb.render(chkTest)
  tb.render(chkTest2)
  tb.render(chkDraw)

  # RadioBoxGroup renders all its members
  tb.render(radioBoxGroup)

  # Update the info box position to always be on the bottom
  infoBox.w = terminalWidth()
  infoBox.y = terminalHeight()-1
  tb.render(infoBox)

  tb.render(infoBoxMouse) # No need to update position (is at the top)
  tb.render(infoBoxMulti)
  tb.render(infoBoxAsync)
  tb.render(chooseBox)
  tb.render(textBox)

  tb.render(progressBarAsync)
  tb.render(progressBarVertical) # TODO not working properly yet
  tb.render(infoProgressBarAsync)

  tb.render(progressBarInteract)
  tb.render(infoProgressBarInteract)
  tb.render(labelProgressBarInteract)

  tb.render(table)

  tb.display()

  # poll(100) # for the async demo code (keep poll low), use sleep below for non async.
  poll(25) # for the async demo code (keep poll low), use sleep below for non async.
  # sleep(50) # when no async code used, just call sleep(50)