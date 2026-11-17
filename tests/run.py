"""Run the DruidActionBarPager logic tests against a simulated WoW API.

Requires the `lupa` package (pip install lupa). These tests exercise the addon's
Lua logic with stubbed WoW frames; they do NOT replace testing in the game client.

    python3 tests/run.py
"""
import os
import sys

from lupa import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ADDON = os.path.join(ROOT, "DruidActionBarPager", "DruidActionBarPager.lua")
FAMILIES = ["blizzard", "bartender4", "azerite", "unnamed", "dominos", "neuron", "ellesmere"]


def run(script, extra):
    lua = LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.TESTDIR = HERE
    g.ADDON_SRC = open(ADDON, encoding="utf-8").read()
    for k, v in extra.items():
        setattr(g, k, v)
    return lua.execute(open(os.path.join(HERE, script), encoding="utf-8").read())


def main():
    failures = 0
    total = 0
    print("== reload and form-change scenarios")
    report = run("scenarios.lua", {})
    for line in str(report).splitlines():
        total += 1
        failures += line.startswith("FAIL")
    print("== action bar family scenarios")
    for fam in FAMILIES:
        report = run("families.lua", {"FAMILY": fam})
        for line in str(report).splitlines():
            total += 1
            failures += line.startswith("FAIL")
    print(f"\n{total - failures}/{total} checks passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
