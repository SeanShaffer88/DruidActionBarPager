"""Run the DruidActionBarPager logic tests against a simulated WoW Forever API.

Requires the `lupa` package (pip install lupa). These tests exercise the addon's
Lua logic, restricted-snippet constraints, and Bindings.xml schema with stubbed
WoW frames; they do NOT replace testing in the game client.

    python3 tests/run.py
"""
import os
import sys
import xml.etree.ElementTree as ET

from lupa.lua51 import LuaRuntime  # Lua 5.1: the dialect WoW uses

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ADDON_DIR = os.path.join(ROOT, "DruidActionBarPager")

# Valid <Binding> attributes in WoW Forever (Interface 16001).
BINDING_ATTRS = {
    "name", "category", "header", "runOnUp",
    "default", "hidden", "debug", "customBindingID",
}
EXPECTED_BINDINGS = [
    "DABP_TOGGLE_EXTRA1",
    "DABP_TOGGLE_EXTRA2",
    "DABP_TOGGLE_EXTRA3",
    "DABP_TOGGLE_ALL_EXTRAS",
]
FAMILIES = ["blizzard", "bartender4", "azerite", "unnamed", "dominos", "neuron", "ellesmere"]
EDGE_CASES = [
    "restricted",
    "multibars",
    "reorder",
    "override_and_wrap",
    "showgrid_and_reload",
    "reload_shifted_unknown",
    "orphans_and_filtering",
    "late_bar_and_perf",
    "keybindings_and_guards",
    "non_druid",
    "forms_sv_combat",
    "combat_login_and_misc",
]


def toc_entries():
    """All file entries listed in the .toc, normalized to forward slashes."""
    with open(os.path.join(ADDON_DIR, "DruidActionBarPager.toc"), encoding="utf-8") as fh:
        lines = [ln.strip() for ln in fh]
    return [ln.replace("\\", "/") for ln in lines if ln and not ln.startswith("#")]


def toc_files():
    """Lua files listed in the .toc, in load order."""
    return [name for name in toc_entries() if name.endswith(".lua")]


def run(script, extra):
    lua = LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.TESTDIR = HERE
    g.ADDON_DIR = ADDON_DIR
    g.ADDON_FILES = lua.table_from(toc_files())
    for k, v in extra.items():
        setattr(g, k, v)
    return lua.execute(open(os.path.join(HERE, script), encoding="utf-8").read())


def check_bindings():
    """Validate Bindings.xml schema, duplicate headers/names, Lua bodies, and globals."""
    results = []

    def record(name, ok, detail=None):
        line = ("PASS " if ok else "FAIL ") + name
        if detail is not None:
            line += f" [{detail}]"
        print(line)
        results.append(line)

    in_toc = any(os.path.basename(entry).lower() == "bindings.xml" for entry in toc_entries())
    record("Bindings.xml omitted from .toc (auto-loaded by client)", not in_toc)

    bindings_path = os.path.join(ADDON_DIR, "Bindings.xml")
    try:
        root = ET.parse(bindings_path).getroot()
    except (OSError, ET.ParseError) as exc:
        record("Bindings.xml well-formed with <Bindings> root", False, str(exc))
        return results

    bad_tags = [child.tag for child in root if child.tag not in ("Binding", "ModifiedClick")]
    bindings = [child for child in root if child.tag == "Binding"]
    bad_attrs = sorted({
        attr for elem in bindings for attr in elem.attrib if attr not in BINDING_ATTRS
    })
    schema_ok = (
        root.tag == "Bindings"
        and not root.attrib
        and not bad_tags
        and not bad_attrs
        and len(bindings) > 0
    )
    schema_detail = (
        None if schema_ok
        else f"root={root.tag} root_attrs={sorted(root.attrib)} tags={bad_tags} attrs={bad_attrs}"
    )
    record("Bindings.xml well-formed with valid Forever schema", schema_ok, schema_detail)

    names = [elem.attrib.get("name", "") for elem in bindings]
    seen_names, dup_names = set(), []
    for name in names:
        if name in seen_names and name not in dup_names:
            dup_names.append(name)
        seen_names.add(name)
    record(
        "Bindings.xml declares expected actions once each",
        names == EXPECTED_BINDINGS and not dup_names,
        ",".join(names),
    )

    seen_headers, dup_headers = set(), []
    for elem in bindings:
        header = elem.attrib.get("header")
        if header is not None:
            if header in seen_headers and header not in dup_headers:
                dup_headers.append(header)
            seen_headers.add(header)
    record(
        "Bindings.xml loads no binding header more than once",
        not dup_headers,
        ",".join(dup_headers) if dup_headers else None,
    )

    lua = LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.TESTDIR = HERE
    g.ADDON_DIR = ADDON_DIR
    g.ADDON_FILES = lua.table_from(toc_files())
    lua.execute('local H = dofile(TESTDIR .. "/harness.lua"); H.load(ADDON_FILES, nil)')

    check_chunk = lua.eval("function(src, name) local fn, err = loadstring(src, name); return fn ~= nil, err end")
    compile_errors = []
    for elem in bindings:
        name = elem.attrib.get("name", "<unnamed>")
        body = elem.text or ""
        ok, err = check_chunk(f"return function(keystate) {body} end", f"@{name}")
        if not ok:
            compile_errors.append(f"{name}: {err}")
    record(
        "Bindings.xml chunks compile as Lua 5.1",
        not compile_errors,
        "; ".join(compile_errors) if compile_errors else None,
    )

    label_errors = []
    for elem in bindings:
        name = elem.attrib.get("name", "")
        label = g[f"BINDING_NAME_{name}"]
        if not isinstance(label, str) or not label:
            label_errors.append(f"missing BINDING_NAME_{name}")
        cat = elem.attrib.get("category")
        if not cat:
            label_errors.append(f"{name}: missing category")
        else:
            cat_label = g[cat]
            if cat_label != "Druid Action Bar Pager":
                label_errors.append(f"{name}: {cat}={cat_label!r}")
        header = elem.attrib.get("header")
        if header is not None:
            hdr_label = g[f"BINDING_HEADER_{header}"]
            if not isinstance(hdr_label, str) or not hdr_label:
                label_errors.append(f"missing BINDING_HEADER_{header}")
    record(
        "Bindings.xml category and action labels resolve",
        not label_errors,
        "; ".join(label_errors) if label_errors else None,
    )

    return results


def main():
    failures = 0
    total = 0

    def tally(report):
        nonlocal total, failures
        for line in str(report).splitlines():
            if not line.strip():
                continue
            total += 1
            if not (line.startswith("PASS ") or ": PASS " in line):
                failures += 1

    print("== key binding XML checks")
    for line in check_bindings():
        total += 1
        failures += line.startswith("FAIL")
    print("== reload and form-change scenarios")
    tally(run("scenarios.lua", {}))
    print("== action bar family scenarios")
    for fam in FAMILIES:
        tally(run("families.lua", {"FAMILY": fam}))
    print("== regression and edge-case scenarios")
    for case in EDGE_CASES:
        tally(run("edge_cases.lua", {"CASE": case}))

    print(f"\n{total - failures}/{total} checks passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
