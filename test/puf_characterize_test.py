#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from tempfile import TemporaryDirectory
from puf_characterize import hd,main,N,T,parse_boots

def run(max_error):
    with TemporaryDirectory() as tmp:
        path=Path(tmp)
        (path/"dieA.txt").write_text(
            format(0,f"0{N}b")+"\n"+
            (format((1<<max_error)-1,f"0{N}b")+"\n")*499,
            encoding="ascii")
        (path/"dieB.txt").write_text(
            (format((1<<328)-1,f"0{N}b")+"\n")*500,
            encoding="ascii")
        (path/"short.txt").write_text(
            (format(0,f"0{N}b")+"\n")*499,
            encoding="ascii")
        stdout=StringIO()
        with redirect_stdout(stdout):
            result=main(path)
        return result,stdout.getvalue()

assert hd(0,(1<<2046)|(1<<2047))==1
assert hd(0b1010,0b0101,n=3)==3
success,output=run(T)
assert success
assert f"observed max {T}" in output
assert "headroom 0 bits (WITHIN OBSERVED BOUND)" in output
assert "short: INSUFFICIENT 499 boots" in output
assert "inter-die enrolled reference mean HD" in output
assert "min-entropy assessment: NOT RUN" in output
failure,output=run(T+1)
assert not failure
assert "headroom -1 bits (FAIL)" in output
assert "OBSERVED RECONSTRUCTION BOUND: FAIL" in output
with TemporaryDirectory() as tmp:
    bad=Path(tmp)/"bad.txt"
    bad.write_text("1010\n",encoding="ascii")
    try: parse_boots(bad)
    except ValueError: pass
    else: raise AssertionError("malformed input accepted")
print("PUF characterization boundary and input checks PASS")
