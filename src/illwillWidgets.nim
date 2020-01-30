## A small widget library for illwill,

import os, strutils
import illwill
import macros

macro preserveColor(pr: untyped) =
  result = newProc()
  result[0] = pr[0]
  let oldbody = pr.body
  result.params = pr.params
  result.body = quote do:
    let oldFg = tb.getForegroundColor
    let oldBg = tb.getBackgroundColor
    tb.setForegroundColor wid.color
    tb.setBackgroundColor wid.bgcolor
    `oldbody`
    tb.setForegroundColor oldFg
    tb.setBackgroundColor oldBg
  # echo repr result

type
  Event* = enum
    MouseHover, MouseUp, MouseDown
  Events* = set[Event]
  Widget* = object of RootObj
    x*: int
    y*: int
    color*: ForegroundColor
    bgcolor*: BackgroundColor
    highlight*: bool
  Button* = object of Widget
    text*: string
    # boxBuffer: BoxBuffer
    w*: int
    h*: int
  Checkbox* = object of Widget
    text*: string
    checked*: bool
    textChecked*: string
    textUnchecked*: string
  RadioBoxGroup* = object of Widget
    radioButtons*: seq[Checkbox]
  InfoBox* = object of Widget
    text*: string
    w*: int
  ChooseBox* = object of Widget
    bgcolorChoosen*: BackgroundColor
    choosenidx*: int
    w*: int
    h*: int
    elements*: seq[string]
  TextBox* = object of Widget
    text*: string
    placeholder*: string
    focus*: bool
    w*: int
    caretIdx*: int

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
# InfoBox
# ########################################################################################################
proc newInfoBox*(text: string, x, y: int, w = 10, color = fgBlack, bgcolor = bgWhite): InfoBox =
  result = InfoBox(
    text: text,
    x: x,
    y: y,
    w: w,
    color: color,
    bgcolor: bgcolor,
  )

proc render*(tb: var TerminalBuffer, wid: InfoBox) {.preserveColor.} =
  # TODO save old text to only overwrite the len of the old text
  tb.write(wid.x, wid.y, wid.text.alignLeft(wid.w))

proc inside(wid: InfoBox, mi: MouseInfo): bool =
  return (mi.x in wid.x .. wid.x+wid.w) and (mi.y == wid.y)

proc dispatch*(tb: var TerminalBuffer, wid: InfoBox, mi: MouseInfo): Events {.discardable.} =
  if wid.inside(mi) and mi.action == Pressed: result.incl MouseDown
  if wid.inside(mi) and mi.action == Released: result.incl MouseUp
  if wid.inside(mi) and mi.action == MouseButtonAction.None: result.incl MouseHover

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
  if wid.inside(mi) and mi.action == Pressed:
    result.incl MouseDown
  elif wid.inside(mi) and mi.action == Released:
    wid.checked = not wid.checked
    result.incl MouseUp
  elif wid.inside(mi) and mi.action == MouseButtonAction.None:
    result.incl MouseHover

# ########################################################################################################
# RadioBox
# ########################################################################################################
proc newRadioBox*(text: string, x, y: int, color = fgBlue): Checkbox =
  ## Radio box is actually a checkbox, you need to add the checkbox to a radio button group
  result = newCheckbox(text, x, y, color)
  result.textChecked = "(X) "
  result.textUnchecked = "( ) "

proc newRadioBoxGroup*(radioButtons: seq[Checkbox]): RadioBoxGroup =
  result = RadioBoxGroup(
    radioButtons: radioButtons
  )

proc render*(tb: var TerminalBuffer, wid: RadioBoxGroup) {.preserveColor.} =
  for radioButton in wid.radioButtons:
    tb.render(radioButton)

proc dispatch*(tb: var TerminalBuffer, wid: var RadioBoxGroup, mi: MouseInfo): Events {.discardable.} =
  var insideSome = false
  for radioButton in wid.radioButtons.mitems:
    if radioButton.inside(mi): insideSome = true
  if (not insideSome) or (mi.action != Released): return
  for radioButton in wid.radioButtons.mitems:
    radioButton.checked = false
  for radioButton in wid.radioButtons.mitems:
    let ev = tb.dispatch(radioButton, mi)
    result.incl ev

proc element*(wid: RadioBoxGroup): Checkbox =
  ## returns the currect selected element of the `RadioBoxGroup`
  for radioButton in wid.radioButtons:
    if radioButton.checked:
      return radioButton

# ########################################################################################################
# Button
# ########################################################################################################
proc newButton*(text: string, x, y, w, h: int, color = fgBlue): Button = #, cb = ButtonCallback): Button =
  result = Button(
    text: text,
    highlight: false,
    x: x,
    y: y,
    w: w,
    h: h,
    color: color,
  )

proc render*(tb: var TerminalBuffer, wid: Button) {.preserveColor.} =
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
    doubleStyle=wid.highlight,
  )

proc inside(wid: Button, mi: MouseInfo): bool =
  return (mi.x in wid.x .. wid.x+wid.w) and (mi.y in wid.y .. wid.y+wid.h)

proc dispatch*(tr: var TerminalBuffer, wid: var Button, mi: MouseInfo): Events {.discardable.} =
  ## if the mouse clicks this button
  result = {}
  if not wid.inside(mi):
    wid.highlight = false
    return
  case mi.action
  of Pressed:
    wid.highlight = true
    result.incl MouseDown
  of Released:
    wid.highlight = false
    result.incl MouseUp
  else:
    wid.highlight = true
    result.incl MouseHover

# ########################################################################################################
# ChooseBox
# ########################################################################################################
proc grow*(wid: var ChooseBox) =
  if wid.elements.len >= wid.h: wid.h = wid.elements.len+1 # TODO allowedToGrow

proc add*(wid: var ChooseBox, elem: string) =
  ## adds element to the list, grows the box immediately
  wid.elements.add(elem)
  wid.grow()

proc newChooseBox*(elements: seq[string], x, y, w, h: int,
      color = fgBlue, label = "", choosenidx = 0): ChooseBox =
  result = ChooseBox(
    elements: elements,
    choosenidx: choosenidx,
    x: x,
    y: y,
    w: w,
    h: h,
    color: color,
  )
  result.grow()

proc element*(wid: ChooseBox): string =
  ## returns the currently selected element text
  return wid.elements[wid.choosenidx]

proc render*(tb: var TerminalBuffer, wid: ChooseBox) {.preserveColor.} =
  tb.fill(wid.x, wid.y, wid.x+wid.w, wid.y+wid.h)
  for idx, elemRaw in wid.elements:
    let elem = elemRaw.alignLeft(wid.w)
    if idx == wid.choosenidx:
      tb.write resetStyle
      tb.write(wid.x+1, wid.y+ 1 + idx, wid.color, wid.bgcolor, styleReverse, elem)
    else:
      tb.write resetStyle
      tb.write(wid.x+1, wid.y+ 1 + idx, wid.color, wid.bgcolor, elem)
  tb.write resetStyle
  tb.drawRect(
    wid.x,
    wid.y,
    wid.x + wid.w,
    wid.y + wid.h,
  )

proc inside(wid: ChooseBox, mi: MouseInfo): bool =
  return (mi.x in wid.x .. wid.x+wid.w) and (mi.y in wid.y .. wid.y+wid.h)

proc dispatch*(tr: var TerminalBuffer, wid: var ChooseBox, mi: MouseInfo): Events {.discardable.} =
  result = {}
  wid.grow()
  if not wid.inside(mi):
    return
  case mi.action
  of Pressed:
    result.incl MouseDown
  of Released:
    wid.choosenidx = clamp( (mi.y - wid.y)-1 , 0, wid.elements.len-1)
    result.incl MouseUp
  else:
    result.incl MouseHover

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
  if wid.inside(mi) and mi.action == Pressed:
    result.incl MouseDown
  if wid.inside(mi) and mi.action == Released:
    wid.focus = true
    result.incl MouseUp
  if wid.inside(mi) and mi.action == MouseButtonAction.None:
    result.incl MouseHover
  if not wid.inside(mi) and mi.action == Released or mi.action == Pressed:
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
      wid.text.insert(ch, wid.caretIdx)
      wid.caretIdx.inc
      wid.caretIdx = clamp(wid.caretIdx, 0, wid.text.len)

template setKeyAsHandled*(key: Key) =
  ## call this on key when the key was handled by a textbox
  if key != Key.Mouse:
    key = Key.None
