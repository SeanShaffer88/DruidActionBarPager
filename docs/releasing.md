# Canonical package and release workflow

The packager uses Python's standard library. From the repository root:

    python -B tools/package_release.py --tag v1.2.1 --output <outside-addon-directory>
    python -B tools/package_release.py --tag v1.2.1 --check <archive.zip>
    python -B -m unittest discover -s tests -p "test_*.py"

The TOC version must match the explicit tag. Inventory must equal the TOC's Lua files plus declared bindings, metadata and media. Symlinks, unsafe paths and case aliases are refused. Archives contain one DruidActionBarPager directory, sorted entries, stored bytes, fixed timestamps and permissions. Known UTF-8 text uses LF in the package; CRLF checkouts normalize to the same bytes. Binary images are unchanged. The .gitattributes file records the same contract for future checkouts. Verification compares every archive entry with this canonical source representation.

Pull requests run addon and packaging regressions and build the same archive on Linux and Windows. A version-tag push, or manual dispatch naming an existing version tag, verifies the exact tag commit before packaging. Publishing waits for both regression/package verification and byte-identical Windows parity. The release job consumes the verified artifact without re-zipping it, verifies its checksum, and creates the release with both assets together.

An existing release is never clobbered. A rerun downloads its existing assets and matches their checksum manifest and ZIP bytes against the verified artifact. A mismatch fails for explicit investigation. Newly hosted assets receive the same readback comparison. Publication has not been exercised by local mock tests; CI and hosted-asset verification supply that evidence when a future tag is authorized.
