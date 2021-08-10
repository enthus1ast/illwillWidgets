## A small widget library for illwill,

import illwill, macros, strutils
import strformat, os, math

macro preserveColor(pr: untyped) =
  ## this pragma saves the style before a render proc,
  ## and resets the style after a render proc
  result = newProc()
  result[0] = pr[0]
  let oldbody = pr.body
  result.params = pr.params
  result.body = quote do:
    let oldFg = tb.getForegroundColor()
    let oldBg = tb.getBackgroundColor()
    let oldStyle = tb.getStyle()
    tb.setForegroundColor(wid.color)
    tb.setBackgroundColor(wid.bgcolor)
    `oldbody`
    tb.setForegroundColor oldFg
    tb.setBackgroundColor oldBg
    tb.setStyle oldStyle

type
  WrapMode* {.pure.} = enum
    None, Char #, Word
  Percent* = range[0.0..100.0]
  Event* = enum
    MouseHover, MouseUp, MouseDown
  Orientation* = enum
    Horizontal, Vertical
  Events* = set[Event]
  Widget* = object of RootObj
    x*: int
    y*: int
    color*: ForegroundColor
    bgcolor*: BackgroundColor
    style*: Style
    highlight*: bool
    autoClear*: bool
    shouldBeCleared: bool
  Button* = object of Widget
    text*: string
    w*: int
    h*: int
    border*: bool
  Checkbox* = object of Widget
    text*: string
    checked*: bool
    textChecked*: string
    textUnchecked*: string
  RadioBoxGroup* = object of Widget
    radioButtons*: seq[ptr Checkbox]
  InfoBox* = object of Widget
    text*: string
    w*: int
    h*: int
    wrapMode*: WrapMode
  ChooseBox* = object of Widget
    bgcolorChoosen*: BackgroundColor
    choosenidx*: int
    w*: int
    h*: int
    elements*: seq[string]
    highlightIdx*: int
    chooseEnabled*: bool
    title*: string
    shouldGrow*: bool
    filter*: string
  TextBox* = object of Widget
    text*: string
    placeholder*: string
    focus*: bool
    w*: int
    caretIdx*: int
  ProgressBar* = object of Widget
    text*: string
    l*: int ## the length (length instead of width for vertical)
    maxValue*: float
    value*: float
    orientation*: Orientation
    bgTodo*: BackgroundColor
    bgDone*: BackgroundColor
    colorText*: ForegroundColor
    colorTextDone*: ForegroundColor
  TableBox* = object of Widget
    headers*: seq[(int, string)]
    rows*: seq[seq[string]]
    highlightIdx*: int
    w*: int
    h*: int
    bdColor: ForegroundColor
    colorHighlight: ForegroundColor
    bgHighlight: BackgroundColor

# Cannot do this atm because of layering!
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

# ########################################################################################################
# Utils
# ########################################################################################################
proc wrapText*(str: string, maxLen: int, wrapMode: WrapMode): string =
  case wrapMode
  of WrapMode.None: return str
  of Char:
    var num = 0
    for ch in str:
      result.add ch
      num.inc
      if ch == '\c': ## cannot check for "\n" when iterating chars, guess '\c' is enough for our usecase...
        num = 0
      if num == maxLen:
        result.add "\n"
        num = 0
  # of WrapMode.Word:
  #   discard

proc positionHelper*(coords: MouseInfo): string =
  result = fmt"x:{coords.x} y:{coords.y} bot:{coords.y - terminalHeight()} right:{coords.x - terminalWidth()}"

# ########################################################################################################
# Widget
# ########################################################################################################
proc clear*(wid: var Widget) {.inline.} =
  wid.shouldBeCleared = true

# ########################################################################################################
# InfoBox
# ########################################################################################################
proc newInfoBox*(text: string, x, y: int, w = 10, h = 1, color = fgBlack, bgcolor = bgWhite): InfoBox =
  result = InfoBox(
    text: text,
    x: x,
    y: y,
    w: w,
    h: h,
    color: color,
    bgcolor: bgcolor,
    wrapMode: WrapMode.None
  )

proc render*(tb: var TerminalBuffer, wid: InfoBox) {.preserveColor.} =
  # TODO save old text to only overwrite the len of the old text
  let  lines = wid.text.wrapText(wid.w, wid.wrapMode).splitLines()
  for idx in 0..lines.len-1:
    tb.write(wid.x, wid.y+idx, lines[idx].alignLeft(wid.w))

proc inside(wid: InfoBox, mi: MouseInfo): bool =
  return (mi.x in wid.x .. wid.x+wid.w) and (mi.y == wid.y)

proc dispatch*(tb: var TerminalBuffer, wid: InfoBox, mi: MouseInfo): Events {.discardable.} =
  if not wid.inside(mi): return
  case mi.action
  of mbaPressed: result.incl MouseDown
  of mbaReleased: result.incl MouseUp
  of mbaNone: result.incl MouseHover

# ########################################################################################################
# Checkbox
# ########################################################################################################
proc newCheckbox*(text: string, x, y: int, color = fgBlue): Checkbox =
  result = Checkbox(
    text: text,
    x: x,
    y: y,
    color: color,
    textChecked: "[X] ",
    textUnchecked: "[ ] "
  )

proc render*(tb: var TerminalBuffer, wid: Checkbox) {.preserveColor.} =
  let check = if wid.checked: wid.textChecked else: wid.textUnchecked
  tb.write(wid.x, wid.y, check & wid.text)

proc inside(wid: Checkbox, mi: MouseInfo): bool =
  return (mi.x in wid.x .. wid.x+wid.text.len + 3) and (mi.y == wid.y)

proc dispatch*(tr: var TerminalBuffer, wid: var Checkbox, mi: MouseInfo): Events {.discardable.} =
  if not wid.inside(mi): return
  result.incl MouseHover
  case mi.action
  of mbaPressed:
    result.incl MouseDown
  of mbaReleased:
    wid.checked = not wid.checked
    result.incl MouseUp
  of mbaNone: discard

# ########################################################################################################
# RadioBox
# ########################################################################################################
proc newRadioBox*(text: string, x, y: int, color = fgBlue): Checkbox =
  ## Radio box is actually a checkbox, you need to add the checkbox to a radio button group
  result = newCheckbox(text, x, y, color)
  result.textChecked = "(X) "
  result.textUnchecked = "( ) "

proc newRadioBoxGroup*(radioButtons: seq[ptr Checkbox]): RadioBoxGroup =
  ## Create a new radio box, add radio boxes to the group,
  ## then call the *groups* `render` and `dispatch` proc.
  result = RadioBoxGroup(
    radioButtons: radioButtons
  )

proc render*(tb: var TerminalBuffer, wid: RadioBoxGroup) {.preserveColor.} =
  for radioButton in wid.radioButtons:
    tb.render(radioButton[])

proc uncheckAll*(wid: var RadioBoxGroup) =
  for radioButton in wid.radioButtons.mitems:
    radioButton[].checked = false

proc dispatch*(tb: var TerminalBuffer, wid: var RadioBoxGroup, mi: MouseInfo): Events {.discardable.} =
  var insideSome = false
  for radioButton in wid.radioButtons.mitems:
    if radioButton[].inside(mi): insideSome = true
  if (not insideSome) or (mi.action != mbaReleased): return
  wid.uncheckAll()
  for radioButton in wid.radioButtons.mitems:
    let ev = tb.dispatch(radioButton[], mi)
    result.incl ev

proc element*(wid: RadioBoxGroup): Checkbox =
  ## returns the currect selected element of the `RadioBoxGroup`
  for radioButton in wid.radioButtons:
    if radioButton.checked:
      return radioButton[]

# ########################################################################################################
# Button
# ########################################################################################################
proc newButton*(text: string, x, y, w, h: int, border = true, color = fgBlue): Button =
  result = Button(
    text: text,
    highlight: false,
    x: x,
    y: y,
    w: w,
    h: h,
    border: border,
    color: color,
  )


proc render*(tb: var TerminalBuffer, wid: Button) {.preserveColor.} =
  if wid.border:
    if wid.autoClear or wid.shouldBeCleared: tb.fill(wid.x, wid.y, wid.x+wid.w, wid.y+wid.h)
    tb.drawRect(
      wid.x,
      wid.y,
      wid.x + wid.w,
      wid.y + wid.h,
      doubleStyle=wid.highlight,
    )
    tb.write(
      wid.x+1 + wid.w div 2 - wid.text.len div 2 ,
      wid.y+1,
      wid.text
    )
  else:
    var style = if wid.highlight: styleBright else: styleDim
    tb.write(
      wid.x + wid.w div 2 - wid.text.len div 2 ,
      wid.y,
      style, wid.text
    )

proc inside(wid: Button, mi: MouseInfo): bool =
  return (mi.x in wid.x .. wid.x+wid.w) and (mi.y in wid.y .. wid.y+wid.h)

proc dispatch*(tr: var TerminalBuffer, wid: var Button, mi: MouseInfo): Events {.discardable.} =
  ## if the mouse clicks this button
  if not wid.inside(mi):
    wid.highlight = false
    return
  result.incl MouseHover
  case mi.action
  of mbaPressed:
    wid.highlight = true
    result.incl MouseDown
  of mbaReleased:
    wid.highlight = false
    result.incl MouseUp
  of mbaNone:
    wid.highlight = true

# ########################################################################################################
# ChooseBox
# ########################################################################################################
proc grow*(wid: var ChooseBox) =
  ## call this to grow the box if you've added or removed a element
  ## from the `wid.elements` seq.
  if wid.elements.len >= wid.h: wid.h = wid.elements.len+1 # TODO allowedToGrow

proc add*(wid: var ChooseBox, elem: string) =
  ## adds element to the list, grows the box immediately
  wid.elements.add(elem)
  wid.grow()

proc newChooseBox*(elements: seq[string], x, y, w, h: int,
      color = fgBlue, label = "", choosenidx = 0, shouldGrow = true): ChooseBox =
  ## a list of text items to choose from, sometimes also called listbox
  ## if `shouldGrow == true` the chooseBox grows automatically when elements added
  result = ChooseBox(
    elements: elements,
    choosenidx: choosenidx,
    x: x,
    y: y,
    w: w,
    h: h,
    color: color,
  )
  result.highlightIdx = -1
  result.chooseEnabled = true
  if shouldGrow: result.grow()

proc setChoosenIdx*(wid: var ChooseBox, idx: int) =
  ## sets the choosen idex to a valid value
  wid.choosenidx = idx.clamp(0, wid.elements.high)

proc nextChoosenidx*(wid: var ChooseBox, num = 1) =
  wid.setChoosenIdx(wid.choosenidx + num)

proc prevChoosenidx*(wid: var ChooseBox, num = 1) =
  wid.setChoosenIdx(wid.choosenidx - num)

proc filter*(query: string, elems: seq[string]): seq[int] =
  ## TODO filter must be somewhere else, maybe needet for other widgets
  if query.len <= 2: return @[]
  let queryClean = query.toLower()
  for idx, elem in elems:
    let elemClean = elem.toLower().strip()
    if elemClean.contains(queryClean): result.add idx

proc filterElements(wid: var ChooseBox): seq[string] =
  if wid.filter.len == 0: return wid.elements
  for idx in filter(wid.filter, wid.elements):
    result.add wid.elements[idx]

proc element*(wid: var ChooseBox): string =
  if wid.filter.len == 0:
    try:
      return wid.elements[wid.choosenidx]
    except:
      return ""
  else:
    try:
      return wid.filterElements()[wid.choosenidx]
    except:
      return ""

proc clear(tb: var TerminalBuffer, wid: var ChooseBox) {.inline.} =
  tb.fill(wid.x, wid.y, wid.x+wid.w, wid.y+wid.h) # maybe not needet?
  wid.shouldBeCleared = false

proc clampAndFillStr(str: string, upto: int): string =
  ## if str is smaller than upto, fill the rest
  ## if str is bigger than upto clamp
  if str.len >= upto: return str[0 .. min(upto, str.len - 1)]
  else: return str.alignLeft(upto, ' ')

proc render*(tb: var TerminalBuffer, wid: var ChooseBox) {.preserveColor.} =
  tb.clear(wid)
  let filteredElements = wid.filterElements()
  var fromIdx: int = 0
  if wid.choosenIdx > wid.h - 4:
    fromIdx = wid.choosenIdx - wid.h + 2
  var drawIdx = -1
  # for elemIdx, elemRaw in wid.elements: #.view():
  for elemIdx, elemRaw in filteredElements: #.view():
    if fromIdx > elemIdx:
      continue
    if drawIdx >= wid.h - 2:
      break # TODO: Break out of for loop
    drawIdx.inc
    # if not wid.shouldGrow:
    #   if elemIdx >= wid.h: continue # do not draw additional elements but render scrollbar
    let elem = elemRaw.clampAndFillStr(wid.w)
    if wid.chooseEnabled and  elemIdx == wid.choosenIdx:  #wid.mustBeHighlighted(idx):
      ## Draw selected
      tb.write resetStyle
      tb.write(wid.x+1, wid.y + 1 + drawIdx, wid.color, wid.bgcolor, styleReverse, elem)
    else:
      tb.write resetStyle
      if elemIdx == wid.highlightIdx:
        ## Draw "bright"
        tb.write(wid.x + 1, wid.y + 1 + drawIdx, wid.color, wid.bgcolor, styleBright, elem)
      else:
        ## Draw "normal"
        tb.write(wid.x + 1, wid.y + 1 + drawIdx, wid.color, wid.bgcolor, elem)
  tb.write resetStyle
  tb.drawRect(
    wid.x,
    wid.y,
    wid.x + wid.w,
    wid.y + wid.h,
    wid.highlight
  )
  if wid.title.len > 0:
    tb.write(wid.x + 2, wid.y, "| " & wid.title & " |")

proc inside(wid: ChooseBox, mi: MouseInfo): bool =
  return (mi.x in wid.x .. wid.x+wid.w) and (mi.y in wid.y .. wid.y+wid.h)

proc dispatch*(tr: var TerminalBuffer, wid: var ChooseBox, mi: MouseInfo): Events {.discardable.} =
  result = {}
  if wid.shouldGrow: wid.grow()
  if not wid.inside(mi): return
  result.incl MouseHover
  case mi.action
  of mbaPressed:
    wid.choosenidx = clamp( (mi.y - wid.y)-1 , 0, wid.elements.len-1) # Moved up TEST if everything works
    result.incl MouseDown
  of mbaReleased:
    # wid.choosenidx = clamp( (mi.y - wid.y)-1 , 0, wid.elements.len-1) # Moved up TEST if everything works
    result.incl MouseUp
  of mbaNone: discard

# ########################################################################################################
# TextBox
# ########################################################################################################
proc newTextBox*(text: string, x, y: int, w = 10,
      color = fgBlack, bgcolor = bgCyan, placeholder = ""): TextBox =
  ## TODO a good textbox is COMPLICATED, this is a VERY basic one!! PR's welcome ;)
  result = TextBox(
    text: text,
    x: x,
    y: y,
    w: w,
    color: color,
    bgcolor: bgcolor,
    placeholder: placeholder
  )

proc render*(tb: var TerminalBuffer, wid: TextBox) {.preserveColor.} =
  # TODO save old text to only overwrite the len of the old text
  tb.write(wid.x, wid.y, repeat(" ", wid.w))
  if wid.caretIdx == wid.text.len():
    tb.write(wid.x, wid.y, wid.text)
    if wid.text.len < wid.w:
      tb.write(wid.x + wid.caretIdx, wid.y, styleReverse, " ", resetStyle)
  else:
    tb.write(wid.x, wid.y,
      wid.text[0..wid.caretIdx-1],
      styleReverse, $wid.text[wid.caretIdx],

      resetStyle,
      wid.color, wid.bgcolor,
      wid.text[wid.caretIdx+1..^1],
      resetStyle
      )

proc inside(wid: TextBox, mi: MouseInfo): bool =
  return (mi.x in wid.x .. wid.x+wid.w) and (mi.y == wid.y)

proc dispatch*(tb: var TerminalBuffer, wid: var TextBox, mi: MouseInfo): Events {.discardable.} =
  if wid.inside(mi):
    result.incl MouseHover
    case mi.action
    of mbaPressed:
      result.incl MouseDown
    of mbaReleased:
      wid.focus = true
      result.incl MouseUp
    of mbaNone: discard
  elif not wid.inside(mi) and (mi.action == mbaReleased or mi.action == mbaPressed):
    wid.focus = false

proc handleKey*(tb: var TerminalBuffer, wid: var TextBox, key: Key): bool {.discardable.} =
  ## if this function return "true" the textbox lost focus by enter
  result = false

  template incCaret() =
    wid.caretIdx.inc
    wid.caretIdx = clamp(wid.caretIdx, 0, wid.text.len)
  template decCaret() =
    wid.caretIdx.dec
    wid.caretIdx = clamp(wid.caretIdx, 0, wid.text.len)

  if key == Key.Mouse: return false
  if key == Key.None: return false

  case key
  of Enter:
    return true
  of Escape:
    wid.focus = false
    return
  of End:
    wid.caretIdx = wid.text.len
  of Home:
    wid.caretIdx = 0
  of Backspace:
    try:
      delete(wid.text, wid.caretIdx-1, wid.caretIdx-1)
      decCaret
    except:
      discard
  of Right:
    incCaret
  of Left:
    decCaret
  else:
    # Add ascii representation
    var ch = $key.char
    if wid.text.len < wid.w:
      try: # TODO this try catch should not be needet!!
        wid.text.insert(ch, wid.caretIdx)
        wid.caretIdx.inc
        wid.caretIdx = clamp(wid.caretIdx, 0, wid.text.len)
      except:
        discard

template setKeyAsHandled*(key: Key) =
  ## call this on key when the key was handled by a textbox
  if key != Key.Mouse:
    key = Key.None

# ########################################################################################################
# ProgressBar
# ########################################################################################################
proc newProgressBar*(text: string, x, y: int, l = 10, value = 0.0, maxValue = 100.0,
    orientation = Horizontal, bgDone = bgGreen , bgTodo = bgRed): ProgressBar =
  result = ProgressBar(
    text: text,
    x: x,
    y: y,
    l: l,
    value: value,
    maxValue: maxValue,
    orientation: orientation,
    bgDone: bgDone,
    bgTodo: bgTodo,
    colorText: fgYellow,
    colorTextDone: fgBlack
  )

proc percent*(wid: ProgressBar): float =
  ## Gets the percentage the progress bar is filled
  return (wid.value / wid.maxValue) * 100

proc `percent=`*(wid: var ProgressBar, val: float) =
  ## sets the percentage the progress bar should be filled
  wid.value = (val * wid.maxValue / 100.0).clamp(0.0, wid.maxValue)

proc render*(tb: var TerminalBuffer, wid: ProgressBar) {.preserveColor.} =
  let num = (wid.l.float / 100.0).float * wid.percent
  if wid.orientation == Horizontal:
    # write progress idicator
    let doneRange =  wid.x .. wid.x + num.int - 1
    let todoRange = wid.x + num.int .. (wid.x + wid.l) - 1
    for idxx in doneRange:
      tb.write(idxx, wid.y, wid.color, wid.bgDone, "=")
    for idxx in todoRange:
      tb.write(idxx, wid.y, wid.color, wid.bgTodo, "-")

    if wid.text.len > 0:
      let textRange = (wid.x + (wid.l div 2) ) - wid.text.len div 2 .. ((wid.x + (wid.l div 2) ) - wid.text.len div 2) + (wid.text.len - 1)
      var idx = 0
      for idxx in textRange:
        let ch = $wid.text[idx]  # txt[] # get the char at this idxx position
        idx.inc
        if doneRange.contains idxx:
          tb.write(idxx, wid.y, wid.colorTextDone, wid.bgDone, ch) # TODO
        elif todoRange.contains idxx:
          tb.write(idxx, wid.y, wid.colorText, wid.bgTodo, ch) # TODO
        else:
          tb.write(idxx, wid.y, wid.colorText, ch) # TODO

  elif wid.orientation == Vertical: # TODO Vertical is not fully supported yet. It might work for you, though.
    discard
    # raise
    # DUMMY
    for idx in 0..wid.l:
      tb.write(wid.x-1, wid.y + idx, "O")
    # IMPL
    for todoIdx in 0..(wid.l - num.int):
      tb.write(wid.x, wid.y + num.int + todoIdx, bgRed, "-")
    for doneIdx in 0..num.int:
      let rest = wid.l - num.int
      tb.write(wid.x, wid.y + rest + doneIdx, bgGreen, "=")

proc inside(wid: ProgressBar, mi: MouseInfo): bool =
  return (mi.x in wid.x .. wid.x+wid.l) and (mi.y == wid.y)

# proc percentOnPos*(wid: ProgressBar, mi: MouseInfo): float =
#   let cell = ((mi.x - wid.x))
#   return (cell / wid.w)

proc valueOnPos*(wid: ProgressBar, mi: MouseInfo): float =
  if not wid.inside(mi): return 0.0
  let cell = ((mi.x - wid.x))
  return (cell / wid.l) * wid.maxValue

proc dispatch*(tb: var TerminalBuffer, wid: var ProgressBar, mi: MouseInfo): Events {.discardable.} =
  if not wid.inside(mi): return
  result.incl MouseHover
  case mi.action
  of mbaPressed:
    result.incl MouseDown
  of mbaReleased:
    result.incl MouseUp
  of mbaNone: discard

# ########################################################################################################
# TableBox
# ########################################################################################################
proc newTableBox*(x, y, w, h: int, borderColor = fgCyan, color = fgWhite, bgColor = bgBlack, colorHighlight = fgRed, bgHighlight = bgYellow): TableBox =
  result = TableBox(
    x: x,
    y: y,
    w: w,
    h: h,
    color: color,
    bdColor: borderColor,
    bgColor: bgColor,
    colorHighlight: colorHighlight,
    bgHighlight: bgHighlight
  )
  result.highlightIdx = -1

proc addCol*(wid: var TableBox, header: string, width: int) =
  wid.headers.add((width, header))

#TODO make it scrollable
#proc clear*(wid: var TableBox) =
#  wid.rows = @[]

proc addRow*(wid: var TableBox, row: seq[string]) =
  wid.rows.add(row)

proc inside(wid: TableBox, mi: MouseInfo): bool =
  result = wid.x < mi.x and mi.x < wid.x + wid.w and wid.y < mi.y and mi.y < wid.y + wid.h

proc dispatch*(tb: var TerminalBuffer, wid: var TableBox, mi: MouseInfo): Events {.discardable.} =
  tb.setForegroundColor(fgRed)
  if not wid.inside(mi):
    wid.highlightIdx = -1
    return

  result.incl MouseHover
  case mi.action
  of mbaPressed:
    result.incl MouseDown
    wid.highlightIdx = mi.y - (wid.y + 3)
  of mbaReleased:
    result.incl MouseUp
  of mbaNone: discard

proc render*(tb: var TerminalBuffer, wid: var TableBox) {.preserveColor.} =
  let
    x1 = wid.x
    y1 = wid.y
    x2 = x1 + wid.w - 1
    y2 = y1 + wid.h - 1

  var bb = newBoxBuffer(tb.width, tb.height)
  # Draw border
  bb.drawVertLine(x1, y1, y2)
  bb.drawVertLine(x2, y1, y2)
  bb.drawHorizLine(x1, x2, y1)
  bb.drawHorizLine(x1, x2, y2)

  # Draw headers
  tb.setForegroundColor(wid.color)
  var y = y1 + 1
  bb.drawHorizLine(x1, x2, y+1)
  tb.setForegroundColor(wid.color)
  var
    x = x1
    i = 0
  for (w, t) in wid.headers:
    tb.write(x + 1, y, t)
    inc(x, w)
    inc(i)
    if i < wid.headers.len:
      bb.drawVertLine(x, y1, y2)

  # Draw contents
  i = 0
  for row in wid.rows:
    y = y1 + 2
    x = x1
    var j = 0

    if i == wid.highlightIdx:
      tb.setBackgroundColor(wid.bgHighlight)
      tb.setForegroundColor(wid.colorHighlight)
    else:
      tb.setBackgroundColor(wid.bgColor)
      tb.setForegroundColor(wid.color)

    for t in row:
      if j >= wid.headers.len:
        break
      tb.write(x + 1, y + i + 1, t)
      inc(x, wid.headers[j][0])
      inc(j)
    inc(i)

  tb.setBackgroundColor(wid.bgColor)
  tb.setForegroundColor(wid.bdColor)
  tb.write(bb)

  if wid.color != wid.colorHighlight and wid.bgColor != wid.bgHighlight:
    if getKey() == Key.Mouse:
      discard tb.dispatch(wid, getMouse())