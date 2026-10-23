import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from package import build_release


EXPECTED_FILES = (
    "PressToGroup.toc", "Locale.lua", "Filters.lua", "Input.lua", "Engine.lua",
    "UI.lua", "WoW.lua", "Bindings.xml", "README.md", "README.ru.md", "Media/Icon.tga", "LICENSE",
)
VERSION = "0.1.29-beta.1"


class PackageTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "source"
        self.output = Path(self.temporary.name) / "dist"
        for name in EXPECTED_FILES:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(f"Fixture for {name}\n".encode())
        (self.root / "PressToGroup.toc").write_text(
            f"## Interface: 120105\n## Version: {VERSION}\n\n"
            "Locale.lua\nFilters.lua\nInput.lua\nEngine.lua\nUI.lua\nWoW.lua\n",
            encoding="utf-8",
        )
        for name in ("README.md", "README.ru.md"):
            (self.root / name).write_text(f"# PressToGroup {VERSION}\n", encoding="utf-8")
        (self.root / "WoW.lua").write_text(
            f'function PTG:PrintLog()\n    print("PressToGroup {VERSION}: " .. self.state)\nend\n',
            encoding="utf-8",
        )

    def test_archive_contains_only_release_files_and_valid_checksum(self):
        for name in (".env", "userdata/token", "docs/notes", "tests/test.lua", "tools/script.py", ".git/config"):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("must never ship", encoding="utf-8")
        archive_path, digest = build_release(self.root, self.output)
        self.assertEqual(archive_path.name, f"PressToGroup-{VERSION}.zip")
        self.assertEqual(digest, hashlib.sha256(archive_path.read_bytes()).hexdigest())
        self.assertEqual(
            archive_path.with_suffix(".zip.sha256").read_bytes(),
            f"{digest}  {archive_path.name}\n".encode("ascii"),
        )
        with zipfile.ZipFile(archive_path) as archive:
            self.assertEqual(archive.namelist(), [f"PressToGroup/{name}" for name in EXPECTED_FILES])
            for name in EXPECTED_FILES:
                self.assertEqual(archive.read(f"PressToGroup/{name}"), (self.root / name).read_bytes())
            for entry in archive.infolist():
                self.assertEqual(entry.date_time, (1980, 1, 1, 0, 0, 0))
                self.assertEqual(entry.create_system, 3)
                self.assertEqual(entry.external_attr >> 16, 0o100644)
                self.assertEqual(entry.compress_type, zipfile.ZIP_DEFLATED)

    def test_versions_must_agree(self):
        for name in ("README.md", "README.ru.md", "WoW.lua"):
            with self.subTest(name=name):
                path = self.root / name
                original = path.read_bytes()
                path.write_bytes(original.replace(VERSION.encode(), b"0.1.28"))
                with self.assertRaisesRegex(ValueError, "version|Version"):
                    build_release(self.root, self.output)
                self.assertFalse(self.output.exists())
                path.write_bytes(original)

    def test_missing_and_empty_required_files_are_rejected(self):
        for name in EXPECTED_FILES:
            with self.subTest(name=name):
                path = self.root / name
                original = path.read_bytes()
                path.unlink()
                with self.assertRaises(FileNotFoundError):
                    build_release(self.root, self.output)
                path.write_bytes(b"")
                with self.assertRaisesRegex(ValueError, "empty"):
                    build_release(self.root, self.output)
                self.assertFalse(self.output.exists())
                path.write_bytes(original)

    def test_toc_rejects_missing_extra_reordered_and_unsafe_paths(self):
        toc = self.root / "PressToGroup.toc"
        original = toc.read_text(encoding="utf-8")
        for entry in ("Missing.lua", "../outside.lua", "..\\outside.lua", "/outside.lua", "C:\\outside.lua"):
            with self.subTest(entry=entry):
                toc.write_text(original.replace("Input.lua", entry), encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "TOC"):
                    build_release(self.root, self.output)
        for content in (original + "Extra.lua\n", original.replace("Input.lua\n", ""),
                        original.replace("Locale.lua\nFilters.lua", "Filters.lua\nLocale.lua")):
            with self.subTest(content=content):
                toc.write_text(content, encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "TOC"):
                    build_release(self.root, self.output)
        self.assertFalse(self.output.exists())

    def test_unsafe_or_duplicate_version_is_rejected(self):
        toc = self.root / "PressToGroup.toc"
        original = toc.read_text(encoding="utf-8")
        for value in ("../bad", "1.0.0/bad", "1.0.0:bad", "", VERSION + "\n## Version: 0.1.28"):
            with self.subTest(value=value):
                toc.write_text(original.replace(VERSION, value), encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "version"):
                    build_release(self.root, self.output)

    def test_rebuild_ignores_mtime_and_preserves_existing_artifacts(self):
        first_path, first_digest = build_release(self.root, self.output)
        first_bytes = first_path.read_bytes()
        for name in EXPECTED_FILES:
            os.utime(self.root / name, (1_600_000_000, 1_600_000_000))
        second_path, second_digest = build_release(self.root, self.output / "second")
        self.assertEqual(second_path.read_bytes(), first_bytes)
        self.assertEqual(second_digest, first_digest)
        self.assertEqual(build_release(self.root, self.output), (first_path, first_digest))
        self.assertEqual(sorted(path.name for path in self.output.iterdir()),
                         [first_path.name, first_path.name + ".sha256", "second"])

    def test_conflicting_release_is_not_replaced(self):
        archive_path, _ = build_release(self.root, self.output)
        original_archive = archive_path.read_bytes()
        checksum = archive_path.with_suffix(".zip.sha256")
        original_checksum = checksum.read_bytes()
        (self.root / "Locale.lua").write_bytes(b"changed release\n")
        with self.assertRaises(FileExistsError):
            build_release(self.root, self.output)
        self.assertEqual(checksum.read_bytes(), original_checksum)
        self.assertEqual(archive_path.read_bytes(), original_archive)

    def test_failed_publication_removes_new_artifacts(self):
        operation = "rename" if os.name == "nt" else "link"
        real_publish = getattr(os, operation)
        calls = 0

        def fail_second_publication(source, destination):
            nonlocal calls
            calls += 1
            if calls == 2:
                raise OSError("Simulated checksum publication failure")
            real_publish(source, destination)

        with mock.patch(f"package.os.{operation}", side_effect=fail_second_publication):
            with self.assertRaisesRegex(OSError, "Simulated"):
                build_release(self.root, self.output)
        self.assertEqual(list(self.output.iterdir()), [])

    def test_external_symlink_is_rejected(self):
        outside = Path(self.temporary.name) / "outside.lua"
        outside.write_text("outside source", encoding="utf-8")
        source = self.root / "Locale.lua"
        source.unlink()
        try:
            source.symlink_to(outside)
        except OSError as error:
            self.skipTest(f"Symlink creation unavailable: {error}")
        with self.assertRaisesRegex(ValueError, "inside"):
            build_release(self.root, self.output)
        self.assertFalse(self.output.exists())

    def test_cli_locates_source_independently_of_working_directory(self):
        tools_dir = self.root / "tools"
        tools_dir.mkdir()
        script = Path(__file__).resolve().parents[1] / "tools" / "package.py"
        copied_script = tools_dir / "package.py"
        copied_script.write_bytes(script.read_bytes())
        result = subprocess.run(
            [sys.executable, str(copied_script), "--output", str(self.output)],
            cwd=self.temporary.name, capture_output=True, text=True, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("12 files; SHA256 ", result.stdout)
        self.assertTrue((self.output / f"PressToGroup-{VERSION}.zip").is_file())


if __name__ == "__main__":
    unittest.main()
