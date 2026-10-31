#!/usr/bin/env python3
"""Stage 2 (compose, read-only): check HW driver recipes against an app before development.

Usage (normally through recipe.sh, which sets the SDK paths from the board profile):
  python recipe.py list
  python recipe.py check <app-dir> <recipe> [<recipe> ...] [--show]
  python recipe.py derive <recipe> [--write]      (maintainer: values from the recipe's SDK project)

A recipe (<skill>/recipes/drivers/<name>.json) is Kconfig level: the values it sets on top of the
app's .config, plus what must already be true for them to build and run - the FSP instances in the
app's ra_gen/*.h (made by the FSP configurator, never by the recipe), board port and package folders, pins and
peripherals it takes, and what msh must show on the board afterwards.
Each recipe names ONE SDK example project whose README is about that hardware ("project") and the
symbols that name the driver ("anchors"); derive takes every related Kconfig value from that project
(its .config on its own board/Kconfig) instead of picking values by hand: related = what changes in
the base project (vision_board_blink_led, base of every app) when the anchors are set, plus the
anchors' sub-options. Values the base's Kconfig cannot reach become "expect", and a hash of the
anchors' definitions ("kconfig_defs") shows when an app's board/Kconfig defines them differently.
check resolves the recipes with kconfiglib on the app's Kconfig tree (selects, depends, defaults -
as menuconfig would), then reports. Nothing is written: not .config, not rtconfig.h.
Gate: "RECIPE: READY" (exit 0) | "RECIPE: ACTION n" (exit 10, with one "ACTION: ..." line per missing
precondition) | "RECIPE: FAIL" (exit 1: unknown recipe or symbol, pin/peripheral clash).
"""
import argparse
import json
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve()
SKILL_DIR = HERE.parent.parent
RECIPES = SKILL_DIR / "recipes" / "drivers"
BASE_PROJECT = "vision_board_blink_led"        # new_app.sh copies this SDK project for every app


def load(name, seen=None):
    """recipe + its requires, requires first"""
    seen = [] if seen is None else seen
    f = RECIPES / f"{name}.json"
    if not f.is_file():
        print(f"RECIPE: FAIL (unknown recipe '{name}' - see recipe.py list)")
        sys.exit(1)
    r = json.loads(f.read_text(encoding="utf-8"))
    for dep in r.get("requires", []):
        if dep not in [x["recipe"] for x in seen]:
            load(dep, seen)
    if r["recipe"] not in [x["recipe"] for x in seen]:
        seen.append(r)
    return seen


def cmd_list():
    for f in sorted(RECIPES.glob("*.json")):
        r = json.loads(f.read_text(encoding="utf-8"))
        req = f" (requires {', '.join(r['requires'])})" if r.get("requires") else ""
        print(f"{r['recipe']:<10} {r['status']:<9} {r['summary']}{req}")


def kconfig_tree(app):
    """kconfiglib on the app's Kconfig. new_app.sh drops rt-thread/examples, which rt-thread/Kconfig
    sources, so the RT-Thread Kconfig tree comes from the SDK (same RT-Thread version) when needed."""
    app = Path(app)
    rtt = app / "rt-thread"
    if not (rtt / "examples" / "utest" / "testcases" / "Kconfig").is_file():
        rtt = Path(os.environ.get("RTT_SDK_BSP_DIR", "")) / "rt-thread"
    pkgs = Path(os.environ.get("RTT_ENV_NEW", "")) / "packages"
    if not (rtt / "Kconfig").is_file() or not (pkgs / "Kconfig").is_file():
        print(f"ACTION: SETUP RT-Thread Kconfig tree or package index not found (rt-thread: {rtt}, "
              f"packages: {pkgs}) - run recipe.sh (it sets the paths), check_tools.sh first")
        sys.exit(10)
    sys.path.insert(0, str(rtt / "tools"))
    import kconfiglib  # RT-Thread's own copy (tools/kconfiglib.py)
    os.environ.update(BSP_ROOT=".", RTT_ROOT=str(rtt), PKGS_ROOT=str(pkgs),
                      ENV_ROOT=os.environ.get("RTT_ENV_NEW", ""))
    cwd = os.getcwd()
    os.chdir(app)
    try:
        k = kconfiglib.Kconfig("Kconfig", warn=False)
        k.load_config(".config")
    finally:
        os.chdir(cwd)
    return k


def sdk_dir():
    d = Path(os.environ.get("RTT_SDK_BSP_DIR", ""))
    if not (d / "projects").is_dir():
        print(f"ACTION: SETUP SDK folder not found ({d}) - run recipe.sh (it sets the paths), check_tools.sh first")
        sys.exit(10)
    return d


def project_tree(project, tmp):
    """kconfiglib on an SDK example project. Its rt-thread/ and libraries/ are links made by mklinks,
    so its Kconfig files go to a temporary folder with the SDK's libraries Kconfig files."""
    import shutil
    sdk = sdk_dir()
    src = sdk / "projects" / project
    if not (src / ".config").is_file():
        print(f"RECIPE: FAIL (SDK project '{project}' not found in {sdk / 'projects'})")
        sys.exit(1)
    dst = Path(tmp) / project.replace("/", "_")
    for root, base in ((src, dst), (sdk / "libraries", dst / "libraries")):
        for f in root.rglob("Kconfig*"):
            if "packages" in f.relative_to(root).parts:
                continue
            (base / f.relative_to(root)).parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(f, base / f.relative_to(root))
    shutil.copyfile(src / ".config", dst / ".config")
    return kconfig_tree(dst)


def snapshot(k):
    return {s.name: (s.str_value, s.visibility) for s in k.unique_defined_syms}


def def_hash(k, name):
    import hashlib
    sym = k.syms.get(name)
    return hashlib.sha1(str(sym).encode()).hexdigest()[:12] if sym is not None and sym.nodes else ""


def descendants(sym):
    """names of the symbols in the menu below a symbol (menuconfig / if-blocks)"""
    out = []
    for node in sym.nodes:
        stack = [node.list] if node.list else []
        while stack:
            n = stack.pop()
            while n:
                if hasattr(n.item, "str_value") and getattr(n.item, "name", None):
                    out.append(n.item.name)
                if n.list:
                    stack.append(n.list)
                n = n.next
    return out


def ancestors(sym):
    """names of the menu symbols above a symbol, outermost first (choices skipped: their member is set)"""
    out = []
    for node in sym.nodes:
        n = node.parent
        while n is not None and n.parent is not None:
            if hasattr(n.item, "str_value") and getattr(n.item, "name", None) and n.item.name not in out:
                out.insert(0, n.item.name)
            n = n.parent
    return out


def cmd_derive(name, write):
    """kconfig / expect / kconfig_defs of a recipe from its SDK project (see the module doc)"""
    import tempfile
    f = RECIPES / f"{name}.json"
    r = json.loads(f.read_text(encoding="utf-8"))
    if not r.get("project") or not r.get("anchors"):
        print(f"RECIPE: FAIL ({name}: no project/anchors to derive from)")
        sys.exit(1)
    with tempfile.TemporaryDirectory() as tmp:
        p = project_tree(r["project"], tmp)
        b = project_tree(BASE_PROJECT, tmp)
        pv = {s.name: s.str_value for s in p.unique_defined_syms}
        v0 = snapshot(b)
        related = set(r["anchors"])
        for a in r["anchors"]:
            chain = ancestors(p.syms[a]) + [a]   # menus first: a symbol is settable once its menu is on
            related.update(chain)
            related.update(descendants(p.syms[a]))
            for n in chain:
                b.syms[n].set_value(pv[n])
        for _ in range(10):                      # sub-options appear once their parent is set
            related.update(n for n, v in snapshot(b).items() if v != v0.get(n))
            changed = False
            for n in sorted(related):
                s = b.syms.get(n)
                if s is None or not s.nodes or n not in pv or not s.visibility:
                    continue
                if s.str_value != pv[n] and s.user_value != pv[n] and s.set_value(pv[n]):
                    changed = True
            if not changed:
                break
        order = [s.name for s in p.unique_defined_syms]
        kconf, expect = {}, {}
        for n in list(r["anchors"]) + [x for x in order if x in related and x not in r["anchors"]]:
            s = b.syms.get(n)
            if n not in pv or s is None or not s.nodes:
                continue
            if s.str_value == pv[n]:
                if s.user_value is not None and pv[n] != v0[n][0]:
                    kconf[n] = pv[n] or "n"
            elif pv[n] or v0[n][0] not in ("", "n"):
                expect[n] = pv[n] or "n"
        defs = {a: def_hash(p, a) for a in r["anchors"]}
    print(f"{name}: project {r['project']}, anchors {' '.join(r['anchors'])}")
    print(f"  kconfig ({len(kconf)}): " + " ".join(f"{k2}={v}" for k2, v in kconf.items()))
    print(f"  expect ({len(expect)}): " + (" ".join(f"{k2}={v}" for k2, v in expect.items()) or "-"))
    proj = sdk_dir() / "projects" / r["project"]
    gen = "".join(h.read_text(encoding="utf-8", errors="replace") for h in sorted((proj / "ra_gen").glob("*.h")))
    xml = (proj / "configuration.xml").read_text(encoding="utf-8", errors="replace") if (proj / "configuration.xml").is_file() else ""
    def has_inst(i):
        return re.search(r"\b" + re.escape(i) + r"\b", gen) is not None

    def pin_func(pin):     # pincfg altId "p410.spi1.miso1" = peripheral function, "p504.input" = plain GPIO
        m = re.search(r'altId="' + pin.lower() + r'\.([a-z0-9_]+)\.', xml)
        return m.group(1) if m and not m.group(1).startswith("gpio") else "gpio"
    have = [f"{i}={'yes' if has_inst(i) else 'NO'}" for i in r.get("fsp", [])]
    have += [f"{x['dir']}={'yes' if (proj / x['dir']).is_dir() else 'NO'}" for x in r.get("ports", []) + r.get("packages", [])]
    have += [f"{pin}={pin_func(pin)}" for pin in r.get("pins", {})]
    print("  project has: " + (" ".join(have) or "-"))
    print(f"  base Kconfig defines the anchors like the project: "
          + " ".join(f"{a}={'same' if def_hash(b, a) == h else 'DIFFERENT'}" for a, h in defs.items()))
    if write:
        out = {}
        for k2, v in r.items():
            if k2 in ("kconfig", "expect", "kconfig_defs"):
                continue
            out[k2] = v
            if k2 == "anchors":
                out["kconfig"], out["expect"], out["kconfig_defs"] = kconf, expect, defs
        f.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
        print(f"  written: {f.name}")


def cmd_check(app, names, show):
    app = Path(app).resolve()
    if not (app / "Kconfig").is_file() or not (app / ".config").is_file():
        print(f"RECIPE: FAIL ({app} is not an RT-Thread app: no Kconfig / .config)")
        sys.exit(1)
    recipes = load("base")
    for n in names:
        load(n, recipes)
    print(f"app {app.name}: recipes {' + '.join(r['recipe'] for r in recipes)}")

    # 1. pins and peripherals: each one taken once
    errors, actions = [], []
    owner = {}
    for r in recipes:
        for key in list(r.get("pins", {})) + list(r.get("peripherals", [])):
            if key in owner and owner[key] != r["recipe"]:
                errors.append(f"{key} is used by both {owner[key]} and {r['recipe']}")
            owner.setdefault(key, r["recipe"])

    # 2. Kconfig: set every value, let kconfiglib resolve selects/depends/defaults, check what holds
    k = kconfig_tree(app)
    before = {s.name: s.str_value for s in k.unique_defined_syms}
    for r in recipes:
        for name, val in r.get("kconfig", {}).items():
            sym = k.syms.get(name)
            if sym is None or not sym.nodes:
                errors.append(f"{r['recipe']}: Kconfig symbol {name} does not exist in this app's Kconfig tree")
                continue
            sym.set_value(val)
    for r in recipes:
        differ = [n for n, h in r.get("kconfig_defs", {}).items() if h and def_hash(k, n) != h]
        wrong = []
        for name, val in list(r.get("kconfig", {}).items()) + list(r.get("expect", {}).items()):
            sym = k.syms.get(name)
            if sym is None or not sym.nodes:
                continue
            got = sym.str_value or "n"
            if got.lower() != val.lower():
                if differ:
                    wrong.append(f"{name}={got}")
                else:
                    actions.append(f"KCONFIG {r['recipe']}: {name} resolves to {got}, recipe needs {val} - visibility "
                                   f"{sym.visibility}, depends {kconfiglib_expr(sym)}")
        if differ:
            actions.append(f"KCONFIG {r['recipe']}: {' '.join(differ)} defined differently in this app's board/Kconfig "
                           f"than in the SDK project {r['project']}{' (so ' + ' '.join(wrong) + ')' if wrong else ''} - "
                           f"take that block from projects/{r['project']}/board/Kconfig")
    added = [(s.name, s.str_value) for s in k.unique_defined_syms
             if s.str_value != before.get(s.name) and s.str_value not in ("", "n")]
    print(f"kconfig: {sum(len(r.get('kconfig', {})) for r in recipes)} recipe values -> {len(added)} symbols change after resolving")
    if show:
        for name, val in added:
            print(f"  CONFIG_{name}={val}")

    # 3. FSP instances the drivers bind to (ra_gen is the FSP configurator's output; a recipe never makes it)
    hal_text = "".join(h.read_text(encoding="utf-8", errors="replace") for h in sorted((app / "ra_gen").glob("*.h")))
    for r in recipes:
        for inst in r.get("fsp", []):
            if not re.search(rf"\b{re.escape(inst)}\b", hal_text):
                note = r.get("fsp_note", "")
                actions.append(f"FSP {r['recipe']}: instance {inst} not declared in ra_gen/*.h - add it with the "
                               f"RA FSP configurator (configuration.xml){' - ' + note if note else ''}")

    # 4. source folders the recipe needs in the app: board ports (RA glue) and packages
    for r in recipes:
        for p in r.get("ports", []):
            if not (app / p["dir"]).is_dir():
                actions.append(f"PORT {r['recipe']}: {p['dir']} not in the app ({p['what']}) - copy from the SDK {p['from']}")
        for p in r.get("packages", []):
            if not (app / p["dir"]).is_dir():
                opt = " (optional)" if p.get("optional") else ""
                line = f"PACKAGE {r['recipe']}: {p['name']} {p['version']}{opt} not in the app ({p['dir']}) - copy from the SDK {p['from']}"
                if p.get("optional"):
                    print(f"NOTE {line}")
                else:
                    actions.append(line)

    for r in recipes:
        m = r.get("msh", {})
        if m:
            parts = [f"{k2} {' '.join(v)}" for k2, v in m.items() if v]
            print(f"on the board ({r['recipe']}): msh_status.py should show {'; '.join(parts)}")
    for e in errors:
        print(f"ERROR {e}")
    for a in actions:
        print(f"ACTION: {a}")
    if errors:
        print("RECIPE: FAIL")
        sys.exit(1)
    if actions:
        print(f"RECIPE: ACTION {len(actions)}")
        sys.exit(10)
    print("RECIPE: READY")


def kconfiglib_expr(sym):
    import kconfiglib
    return kconfiglib.expr_str(sym.direct_dep)


def main():
    ap = argparse.ArgumentParser(description="HW driver recipes (Kconfig level) - read-only check")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list")
    d = sub.add_parser("derive")
    d.add_argument("recipe")
    d.add_argument("--write", action="store_true", help="store kconfig/expect/kconfig_defs in the recipe file")
    c = sub.add_parser("check")
    c.add_argument("app")
    c.add_argument("recipes", nargs="+")
    c.add_argument("--show", action="store_true", help="print every symbol that changes after resolving")
    args = ap.parse_args()
    if args.cmd == "list":
        cmd_list()
    elif args.cmd == "derive":
        cmd_derive(args.recipe, args.write)
    else:
        cmd_check(args.app, args.recipes, args.show)


if __name__ == "__main__":
    main()
