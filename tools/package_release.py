"""Canonical, source-verified ZIP packaging for DruidActionBarPager."""
from __future__ import annotations
import argparse
import hashlib
from pathlib import Path, PurePosixPath
import re
from zipfile import ZIP_STORED, ZipFile, ZipInfo

ADDON = 'DruidActionBarPager'
TOC = f'{ADDON}.toc'
METADATA = {TOC, 'Bindings.xml', 'LICENSE', 'README.md', 'FEATURES.md', 'DESCRIPTION.md', 'CHANGELOG.md', 'icon.tga', 'logo.png'}


def source_bytes(path):
    data = path.read_bytes()
    if path.suffix.lower() in {'.lua', '.xml', '.toc', '.md'} or path.name == 'LICENSE':
        data.decode('utf-8')
        data = data.replace(b'\r\n', b'\n')
        if b'\r' in data:
            raise ValueError(f'Unsupported bare carriage return: {path.name}')
    return data


def safe_name(name):
    if '\\' in name or ':' in name or PurePosixPath(name).is_absolute():
        raise ValueError(f'Unsafe path: {name!r}')
    for part in name.split('/'):
        if part in {'', '.', '..'} or part.endswith((' ', '.')) or any(ord(c) < 32 for c in part):
            raise ValueError(f'Ambiguous path: {name!r}')
    return name


def manifest(root, tag):
    addon = root / ADDON
    if addon.is_symlink() or not addon.is_dir():
        raise ValueError('Addon directory is missing or linked')
    files, seen = {}, set()
    for path in sorted(addon.rglob('*')):
        name = safe_name(path.relative_to(addon).as_posix())
        if path.is_symlink() or name.casefold() in seen:
            raise ValueError(f'Linked or case-aliased source: {name}')
        seen.add(name.casefold())
        if path.is_dir():
            continue
        if not path.is_file() or path.stat().st_size > 8 * 1024 * 1024:
            raise ValueError(f'Invalid source file: {name}')
        files[name] = path
    toc = files[TOC].read_text(encoding='utf-8-sig')
    versions = re.findall(r'(?m)^## Version: (\d+\.\d+\.\d+)\s*$', toc)
    if len(versions) != 1 or tag != f'v{versions[0]}':
        raise ValueError('Tag must match the single TOC semantic version')
    if re.findall(r'(?m)^## Interface: (\d+)\s*$', toc) != ['16001']:
        raise ValueError('Expected Forever Interface 16001')
    entries = [safe_name(line.strip().replace('\\', '/')) for line in toc.splitlines()
               if line.strip() and not line.lstrip().startswith('#')]
    if len(entries) != len(set(e.casefold() for e in entries)):
        raise ValueError('Duplicate TOC reference')
    if set(files) != METADATA | set(entries):
        raise ValueError('Undeclared source or missing TOC/media/metadata file')
    return versions[0], files


def verify(root, archive, tag):
    _, files = manifest(root, tag)
    expected = {f'{ADDON}/{name}': path for name, path in files.items()}
    with ZipFile(archive) as package:
        entries = package.infolist()
        names = [safe_name(entry.filename) for entry in entries]
        if len(names) != len(set(n.casefold() for n in names)) or set(names) != set(expected):
            raise ValueError('Archive inventory differs from source')
        for entry in entries:
            source = expected[entry.filename]
            canonical = source_bytes(source)
            if entry.file_size != len(canonical) or package.read(entry) != canonical:
                raise ValueError(f'Archive bytes differ: {entry.filename}')
            if (entry.date_time != (1980, 1, 1, 0, 0, 0) or entry.compress_type != ZIP_STORED
                    or entry.create_system != 3 or entry.external_attr != 0o100644 << 16):
                raise ValueError(f'Noncanonical metadata: {entry.filename}')


def build(root, output, tag):
    root, output = root.resolve(), output.resolve()
    addon = root / ADDON
    if output == addon or addon in output.parents:
        raise ValueError('Artifacts cannot be written into addon sources')
    version, files = manifest(root, tag)
    changelog = files['CHANGELOG.md'].read_text(encoding='utf-8')
    heading = f'## [{version}]'
    if heading not in changelog:
        raise ValueError('Current release notes are missing')
    notes_text = changelog.split(heading, 1)[1].split('\n## [', 1)[0].strip()
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f'{ADDON}-{version}.zip'
    with ZipFile(archive, 'w', compression=ZIP_STORED) as package:
        for name, source in sorted(files.items()):
            entry = ZipInfo(f'{ADDON}/{name}', date_time=(1980, 1, 1, 0, 0, 0))
            entry.create_system = 3
            entry.external_attr = 0o100644 << 16
            entry.compress_type = ZIP_STORED
            package.writestr(entry, source_bytes(source))
    verify(root, archive, tag)
    checksum = output / 'SHA256SUMS.txt'
    checksum.write_bytes(f'{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n'.encode('ascii'))
    notes = output / 'release-notes.md'
    notes.write_bytes(f'# {ADDON} {version}\n\n{notes_text}\n'.encode('utf-8'))
    return archive, checksum, notes


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    cli.add_argument('--output', type=Path)
    cli.add_argument('--tag', required=True)
    cli.add_argument('--check', type=Path)
    args = cli.parse_args()
    try:
        if args.check:
            verify(args.root, args.check, args.tag)
            print(f'Verified {args.check}')
        else:
            if args.output is None:
                cli.error('--output is required for packaging')
            for path in build(args.root, args.output, args.tag):
                print(path)
    except (OSError, ValueError, KeyError) as error:
        cli.exit(1, f'Packaging failed: {error}\n')


if __name__ == '__main__':
    main()
