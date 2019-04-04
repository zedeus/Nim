discard """
  errormsg: "{.exportSym.} not allowed for type aliases"
  line: 9
"""

type
  X* = object
    a: int
  Y* {.exportc.} = X

proc impl*(x: X) =
  echo "it works"
