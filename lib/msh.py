"""RT-Thread msh console helpers: talk to the shell and parse what its built-in commands print.

RT-Thread's strength for these tools: the shell is always there (no debug probe needed), and every
command the code exports with MSH_CMD_EXPORT(_ALIAS) is listed by `help` with its description - the
running image reports its own command surface. Formats follow RT-Thread 5.0.2
(components/finsh/msh.c, cmd.c; non-SMP, FINSH_USING_DESCRIPTION + FINSH_USING_SYMTAB):

  help         "RT-Thread shell commands:" then "<name padded to 16> - <description>"
  free         "total    : N" / "used     : N" / "maximum  : N" / "available: N"
  ps           list thread: "<tcb> <name> <pri> <status> 0x<sp> 0x<stack size> <max used>%
               0x<left tick> <error>"
  list device  "<name> <type, may contain spaces> <ref count>" under a "----" rule
  version      " / | \\     5.0.2 build <date> <time>"

The prompt ("msh >", or "msh /dir>" with a file system) ends without a newline, so a command's
output is complete when the prompt comes back. Typed characters are echoed after the prompt.

Used by lib/fwtest.py when a skill sets cfg["command_list"] = "msh" (the test checks that every command
its spec sends is in `help` before running the steps).
"""
import re
import time

PROMPT_RE = re.compile(rb"msh [^\r\n]*>\s*$")
ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")


def clean(text):
    """one received line without ANSI codes, CR or trailing blanks"""
    return ANSI_RE.sub("", text).replace("\r", "").rstrip()


class Console:
    """A pyserial port with an msh on the other side. note(msg) logs RX/TX lines (optional)."""

    def __init__(self, ser, note=None):
        self.s, self.note = ser, note or (lambda msg: None)

    def _read_until_prompt(self, timeout):
        buf, end = b"", time.monotonic() + timeout
        while time.monotonic() < end:
            buf += self.s.read(256)
            if PROMPT_RE.search(buf):
                return buf, True
        return buf, False

    def sync(self, timeout=10.0):
        """send an empty line every second until the prompt shows; True when the shell answers"""
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            self.s.reset_input_buffer()
            self.s.write(b"\r")
            _, ok = self._read_until_prompt(1.0)
            if ok:
                return True
        return False

    def run(self, cmd, timeout=3.0):
        """send one command; return (output lines without echo and prompt, prompt came back)"""
        self.s.reset_input_buffer()
        self.note(f"TX {cmd!r}")
        self.s.write((cmd + "\r").encode())
        raw, ok = self._read_until_prompt(timeout)
        lines = [clean(t) for t in raw.decode("utf-8", "replace").split("\n")]
        if lines and PROMPT_RE.search(lines[-1].encode()):
            lines.pop()                        # the prompt that ends the output
        out = []
        for t in lines:
            self.note("RX " + t)
            if not out and (t.strip() == cmd or t.endswith(">" + cmd) or t.endswith("> " + cmd)):
                continue                       # echo of the command (may follow an old prompt)
            out.append(t)
        while out and not out[-1].strip():
            out.pop()
        return out, ok


def parse_help(lines):
    """{command: description} from `help`; {} when the header is missing"""
    cmds, seen = {}, False
    for t in lines:
        if t.startswith("RT-Thread shell commands:"):
            seen = True
            continue
        m = re.match(r"^(\S+)\s+- (.*)$", t)
        if seen and m:
            cmds[m.group(1)] = m.group(2).strip()
    return cmds


def parse_free(lines):
    """{total, used, maximum, available} in bytes from `free`.
    Small heap: "total : n" lines. RT_USING_MEMHEAP_AS_HEAP: a table "memheap pool size max used size
    available size", one row per pool -> also "pools" [{name, size, max_used, available}], totals summed
    (used = size - available)."""
    out, pools = {}, []
    for t in lines:
        m = re.match(r"^(total|used|maximum|available)\s*:\s*(\d+)", t.strip())
        if m:
            out[m.group(1)] = int(m.group(2))
            continue
        m = re.match(r"^(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s*$", t.strip())
        if m:
            pools.append({"name": m.group(1), "size": int(m.group(2)),
                          "max_used": int(m.group(3)), "available": int(m.group(4))})
    if pools and not out:
        out = {"total": sum(p["size"] for p in pools),
               "used": sum(p["size"] - p["available"] for p in pools),
               "maximum": sum(p["max_used"] for p in pools),
               "available": sum(p["available"] for p in pools),
               "pools": pools}
    return out


# RT-Thread 5.0.x: "<tcb hex> <name> pri status 0xsp 0xstack nn% 0xtick error"
_PS_ROW = re.compile(r"^(?:0x)?[0-9a-fA-F]+\s+(\S+)\s+(\d+)\s+(ready|suspend|init|close|running)\s+"
                     r"0x([0-9a-fA-F]+)\s+0x([0-9a-fA-F]+)\s+(\d+)%\s+0x([0-9a-fA-F]+)\s+(\S.*)$")
# RT-Thread 5.1.x: "<name> pri status 0xsp 0xstack nn% 0xtick error 0xtcb" (the name may hold a space)
_PS_ROW_51 = re.compile(r"^(\S.*?)\s+(\d+)\s+(ready|suspend|init|close|running)\s+"
                        r"0x([0-9a-fA-F]+)\s+0x([0-9a-fA-F]+)\s+(\d+)%\s+0x([0-9a-fA-F]+)\s+(\S+)\s+0x[0-9a-fA-F]+$")


def parse_ps(lines):
    """threads from `ps` / `list thread`: name, pri, status, sp, stack, max_used_pct, left_tick, error"""
    rows = []
    for t in lines:
        m = _PS_ROW_51.match(t.strip()) or _PS_ROW.match(t.strip())
        if m:
            rows.append({"name": m.group(1), "pri": int(m.group(2)), "status": m.group(3),
                         "sp": int(m.group(4), 16), "stack": int(m.group(5), 16),
                         "max_used_pct": int(m.group(6)), "left_tick": int(m.group(7), 16),
                         "error": m.group(8).strip()})
    return rows


def parse_devices(lines):
    """devices from `list device`: name, type, ref"""
    rows, body = [], False
    for t in lines:
        if re.match(r"^-+\s+-+", t.strip()):
            body = True
            continue
        m = re.match(r"^(\S+)\s+(\S.*?)\s+(\d+)\s*$", t)
        if body and m:
            rows.append({"name": m.group(1), "type": m.group(2), "ref": int(m.group(3))})
    return rows


def parse_version(lines):
    """'5.0.2 build Oct 31 2026 11:51:20' from `version`, or ''"""
    for t in lines:
        m = re.search(r"(\d+\.\d+\.\d+) build (.+)$", t)
        if m:
            return f"{m.group(1)} build {m.group(2).strip()}"
    return ""


def first_word(line):
    """the command a spec line sends ('led 1 on' -> 'led')"""
    return line.strip().split()[0] if line.strip() else ""
