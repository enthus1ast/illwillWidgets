import os, strutils
import illwill

proc exitProc() {.noconv.} =
  illwillDeinit()
  showCursor()
  quit(0)

illwillInit(fullscreen=true, mouse=true)
setControlCHook(exitProc)
hideCursor()

var tb = newTerminalBuffer(terminalWidth(), terminalHeight())


type
  Event = enum
    Hover, MouseUp, MouseDown
  Events = set[Event]
  Widget = object of RootObj
  # ButtonCallback = proc (tr: var TerminalBuffer)
    x: int
    y: int
  Button = object of Widget
    text: string
    pressed: bool
    boxBuffer: BoxBuffer
    color: ForegroundColor
    w: int
    h: int
    # cb: ButtonCallback 
  Checkbox = object of Widget
    text: string
    checked: bool
    color: ForegroundColor
  InfoBox = object of Widget
    text: string
    color: ForegroundColor
    bgcolor: BackgroundColor
    w: int
  # RadioButtonGroup = object
  # RadioButton = object of Widget
  #   text: string
  #   checked: bool
  
  # ComboBox[Key] = object of Widget
  #   open: bool
  #   current: Key
  #   elements: Table[Key, string]
  #   w: int
  #   color: ForegroundColor

# proc newComboBox[Key](x,y: int, w = 10): ComboBox =
#   result = ComboBox[Key](
#     open: false,

#   )

proc newInfoBox(text: string, x, y: int, w = 10, color = fgBlack, bgcolor = bgWhite): InfoBox =
  result = InfoBox(
    text: text,
    x: x,
    y: y,
    w: w,
    color: color,
    bgcolor: bgcolor,
  )


proc render(tb: var TerminalBuffer, wid: InfoBox) =
  let oldFg = tb.getForegroundColor
  let oldBg = tb.getBackgroundColor
  tb.setForegroundColor wid.color
  tb.setBackgroundColor wid.bgcolor
  tb.write(wid.x, wid.y, wid.text.alignLeft(wid.w))
  tb.setForegroundColor oldFg
  tb.setBackgroundColor oldBg

proc inside(wid: InfoBox, mi: MouseInfo): bool =
  return (mi.x in wid.x .. wid.x+wid.w) and (mi.y == wid.y)

proc dispatch(tb: var TerminalBuffer, wid: InfoBox, mi: MouseInfo): Events {.discardable.} = 
  if wid.inside(mi) and mi.action == Pressed: result.incl MouseDown
  if wid.inside(mi) and mi.action == Released: result.incl MouseUp

proc newCheckbox(text: string, x, y: int, color = fgBlue): Checkbox =
  result = Checkbox(
    text: text,
    x: x,
    y: y,
    color: color
  )

proc render(tb: var TerminalBuffer, wid: Checkbox) =
  let oldFg = tb.getForegroundColor
  tb.setForegroundColor wid.color
  let check = if wid.checked: "[X] " else: "[ ] "
  tb.write(wid.x, wid.y, check & wid.text)
  tb.setForegroundColor oldFg

proc newButton(text: string, x, y, w, h: int, color = fgBlue): Button = #, cb = ButtonCallback): Button = 
  result = Button(
    text: text,
    pressed: false,
    x: x,
    y: y,
    w: w,
    h: h,
    color: color,
    # cb: cb
  )

proc render(tb: var TerminalBuffer, wid: Button) =
  let oldFg = tb.getForegroundColor
  tb.setForegroundColor wid.color
  tb.fill(wid.x, wid.y, wid.x+wid.w, wid.y+wid.h)
  tb.write(
    wid.x+1 + wid.w div 2 - wid.text.len div 2 , 
    wid.y+1, 
    wid.text
  )
  tb.drawRect(
    wid.x, 
    wid.y,
    wid.x + wid.w, 
    wid.y + wid.h, 
    doubleStyle=wid.pressed, 
  )
  tb.setForegroundColor oldFg

proc inside(wid: Checkbox, mi: MouseInfo): bool =
  return (mi.x in wid.x .. wid.x+wid.text.len + 3) and (mi.y == wid.y)

proc dispatch(tr: var TerminalBuffer, wid: var Checkbox, mi: MouseInfo): Events {.discardable.} = 
  ## if the mouse clicks this button 
  # result = false
  if wid.inside(mi) and mi.action == Pressed:
    result.incl MouseDown
  if wid.inside(mi) and mi.action == Released:
    wid.checked = not wid.checked
    result.incl MouseUp
  # result = wid.checked

proc inside(wid: Button, mi: MouseInfo): bool =
  return (mi.x in wid.x .. wid.x+wid.w) and (mi.y in wid.y .. wid.y+wid.h)

proc dispatch(tr: var TerminalBuffer, wid: var Button, mi: MouseInfo): Events {.discardable.} = 
  ## if the mouse clicks this button 
  # if mi.action == Released: wid.pressed = false
  result = {}
  if not wid.inside(mi): 
    wid.pressed = false
    return
  case mi.action
  of Pressed:
    wid.pressed = true
    result.incl MouseDown
  of Released:
    wid.pressed = false
    result.incl MouseUp


proc doClear(tb: var TerminalBuffer): proc() =
  result = proc() {.gcsafe.} =
    tb.clear()

proc cl(tb: var TerminalBuffer) =
    tb.clear()

var btnTest = newButton("test", 38, 3, 15, 2) #, cb = proc () = echo "FOO")
# var btnTest = newButton("test", 38, 3, 15, 2, cb = proc (tr: TerminalBuffer) = discard )
var btnClear = newButton("clear", 38, 6, 15, 2) #, cb = cl)
var chkTest = newCheckbox("Some content", 38, 9) #, cb = cl)
var chkTest2 = newCheckbox("Some more content", 38, 10) #, cb = cl)
var infoBox = newInfoBox("",0 ,0, terminalWidth())

# var widgets = @[
#   btnTest,
#   btnClear,
#   # chkTest
  
# ]
# echo button
# if true: quit()
# tb.write("foo")
while true:
  # tb.drawRect(38, 3, 50, 5, doubleStyle=false)
  # tb.write(bb)
  var key = getKey()
  case key
  of Key.None: discard
  of Key.Escape, Key.Q: exitProc()
  of Key.Mouse:
    let coords = getMouse()
    # echo coords
    var ev: Events

    ev = tb.dispatch(btnClear, coords)
    if ev.contains MouseUp:
      tb.clear()
    if ev.contains MouseDown:
      infoBox.text = "CLEARS THE SCREEN!"
    
    ev = tb.dispatch(btnTest, coords)
    if ev.contains MouseUp:
      tb.clear("#")
    if ev.contains MouseDown:
      infoBox.text = "Fills the screen!!"

    if tb.dispatch(chkTest, coords).contains MouseUp:
      infoBox.text = "chk test is: " & $chkTest.checked
    
    if tb.dispatch(chkTest2, coords).contains MouseUp:
      if chkTest2.checked:
        echo "red"
        tb.setForegroundColor fgRed
      else:
        echo "green"
        tb.setForegroundColor fgGreen

    ev = tb.dispatch(infoBox, coords)
    if ev.contains MouseDown:
      infoBox.text &= "#"
    if ev.contains MouseUp:
      infoBox.text &= "^"
            
    
    # if coords.action == MouseButtonAction.Pressed:
    #   tb.write coords.x, coords.y, fgRed, "♥"
    # else:
    #   tb.write coords.x, coords.y, fgGreen, "⌀"
  else:
    echo key
    discard
  
  tb.render(btnClear)
  tb.render(btnTest)
  tb.render(chkTest)
  tb.render(chkTest2)

  infoBox.w = terminalWidth()
  infoBox.y = terminalHeight()-1
  tb.render(infoBox)

  tb.display()
  sleep(20)
