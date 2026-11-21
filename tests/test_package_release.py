import hashlib
import importlib.util
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from zipfile import ZipFile, ZipInfo, ZIP_STORED

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('package_release', ROOT / 'tools/package_release.py')
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)


class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)
        self.root = self.base / 'repo'
        shutil.copytree(ROOT / package.ADDON, self.root / package.ADDON)
        toc = (self.root / package.ADDON / package.TOC).read_text(encoding='utf-8')
        self.tag = 'v' + next(line.split(': ', 1)[1] for line in toc.splitlines() if line.startswith('## Version:'))

    def tearDown(self):
        self.temp.cleanup()

    def build(self, name='one'):
        return package.build(self.root, self.base / name, self.tag)

    def test_repeat_mtime_and_lf_crlf_are_byte_identical(self):
        first, checksum, notes = self.build()
        expected = first.read_bytes()
        for path in (self.root / package.ADDON).rglob('*'):
            if path.is_file():
                os.utime(path, (1800000000, 1800000000))
                if path.suffix in {'.lua', '.xml', '.md', '.toc'} or path.name == 'LICENSE':
                    path.write_bytes(package.source_bytes(path).replace(b'\n', b'\r\n'))
        second, _, _ = self.build('two')
        self.assertEqual(expected, second.read_bytes())
        self.assertEqual(checksum.read_text().split()[0], hashlib.sha256(expected).hexdigest())
        self.assertIn('DruidActionBarPager', notes.read_text())
        with ZipFile(first) as z:
            self.assertTrue(all(e.compress_type == ZIP_STORED for e in z.infolist()))
            self.assertNotIn(b'\r', z.read('DruidActionBarPager/Core/Constants.lua'))

    def test_wrong_tag_missing_reference_media_and_extra_source_fail(self):
        with self.assertRaises(ValueError):
            package.build(self.root, self.base / 'bad', 'v999.0.0')
        addon = self.root / package.ADDON
        for relative in ['icon.tga', 'Bindings.xml', 'Core/Conditions.lua']:
            source = addon / relative
            data = source.read_bytes()
            source.unlink()
            with self.assertRaises((ValueError, KeyError)):
                self.build()
            source.write_bytes(data)
        (addon / 'unreviewed.lua').write_text('return true')
        with self.assertRaises(ValueError):
            self.build()

    def test_bad_archive_inventory_and_drift_are_rejected(self):
        archive, _, _ = self.build()
        with ZipFile(archive, 'a') as z:
            z.writestr('DruidActionBarPager/../escaped.lua', 'bad')
        with self.assertRaises(ValueError):
            package.verify(self.root, archive, self.tag)
        archive, _, _ = self.build('clean')
        source = self.root / package.ADDON / 'Core/Conditions.lua'
        source.write_bytes(source.read_bytes() + b'\n-- changed\n')
        with self.assertRaises(ValueError):
            package.verify(self.root, archive, self.tag)

    def test_case_alias_and_noncanonical_metadata_are_rejected(self):
        archive, _, _ = self.build()
        with ZipFile(archive, 'a') as z:
            z.writestr('druidactionbarpager/icon.tga', b'alias')
        with self.assertRaises(ValueError):
            package.verify(self.root, archive, self.tag)
        archive, _, _ = self.build('clean')
        with ZipFile(archive) as z:
            data = [(e.filename, z.read(e)) for e in z.infolist()]
        with ZipFile(archive, 'w') as z:
            for name, contents in data:
                z.writestr(ZipInfo(name), contents)
        with self.assertRaises(ValueError):
            package.verify(self.root, archive, self.tag)

    def test_linked_source_is_rejected(self):
        target = self.root / package.ADDON / 'linked.lua'
        try:
            target.symlink_to(self.root / package.ADDON / 'Core/Conditions.lua')
        except OSError as error:
            self.skipTest(f'Symlink capability unavailable: {error}')
        with self.assertRaises(ValueError):
            self.build()

    def test_safe_paths_and_source_output_boundary(self):
        for name in ['../bad', '/bad', 'A/./B', 'A//B', 'C:bad', 'A\\B', 'A./B']:
            with self.assertRaises(ValueError):
                package.safe_name(name)
        with self.assertRaises(ValueError):
            package.build(self.root, self.root / package.ADDON / 'dist', self.tag)

    def test_publication_is_gated_and_never_clobbers(self):
        workflow = (ROOT / '.github/workflows/package-addon-release.yml').read_text()
        self.assertNotIn('types: [published]', workflow)
        self.assertNotIn('--clobber', workflow)
        self.assertIn('needs: [verify, windows-parity]', workflow)
        self.assertIn('gh release view', workflow)
        self.assertIn('sha256sum -c SHA256SUMS.txt', workflow)
        self.assertIn('cmp "dist/DruidActionBarPager-', workflow)
        self.assertIn('refs/tags/$TAG^{commit}', workflow)


if __name__ == '__main__':
    unittest.main()
