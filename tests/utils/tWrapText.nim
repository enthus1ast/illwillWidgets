from ../../src/illwillWidgets import wrapText, WrapMode

const
  tst1 = "123456789"
  tst2 = "foo baa baz"

doAssert tst1.wrapText(3, WrapMode.None) == tst1

doAssert tst1.wrapText(3, WrapMode.Char) == "123\n456\n789\n"

# doAssert tst1.wrapText(3, WrapMode.Word) == "foo\nbaa\nbaz\n"
# doAssert tst1.wrapText(4, WrapMode.Word) == "foo\nbaa\nbaz"
# doAssert tst1.wrapText(6, WrapMode.Word) == "foo baa\nbaz"
