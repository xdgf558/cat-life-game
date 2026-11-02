#!/usr/bin/env python3
"""Small fixture-only checks; never mutate the app's actual media or Git checkout."""
import contextlib
import io
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from check_runtime_assets import DOWNLOAD_COMMAND, LFS_HEADER, MANIFEST, SANDBOX_INPUTS, inspect, main


class RuntimeAssetPreflightTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="catlife-asset-preflight-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.png = self.root / "CatLife/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
        self.caf = self.root / "CatLife/Audio/bgm-home.caf"
        self.png.parent.mkdir(parents=True)
        self.caf.parent.mkdir(parents=True)
        (self.root / "scripts").mkdir()
        # Header fixtures are sufficient: the preflight deliberately does not decode media.
        self.png.write_bytes(b"\x89PNG\r\n\x1a\n" + bytes(24))
        self.caf.write_bytes(b"caff\x00\x01\x00\x00" + bytes(24))
        (self.png.parent / "Contents.json").write_text(json.dumps({"images": [{"filename": self.png.name}]}))
        (self.png.parent.parent / "Contents.json").write_text('{"info":{"version":1}}')
        (self.root / MANIFEST).write_text(json.dumps({"schemaVersion": 1, "resources": [
            self.png.relative_to(self.root).as_posix(), self.caf.relative_to(self.root).as_posix()
        ]}))

    def test_hydrated_resources_pass(self):
        resources, errors = inspect(self.root)
        self.assertEqual(len(resources), 2)
        self.assertEqual(errors, [])

    def test_image_and_audio_pointers_fail_with_download_instructions(self):
        for path in (self.png, self.caf):
            with self.subTest(path=path.name):
                original = path.read_bytes()
                path.write_bytes(LFS_HEADER + b"\noid sha256:" + b"0" * 64 + b"\nsize 100\n")
                stderr = io.StringIO()
                with contextlib.redirect_stderr(stderr):
                    self.assertEqual(main(["--root", str(self.root)]), 1)
                self.assertIn(path.name, stderr.getvalue())
                self.assertIn("Git LFS pointer", stderr.getvalue())
                self.assertIn(DOWNLOAD_COMMAND, stderr.getvalue())
                path.write_bytes(original)

    def test_missing_image_and_audio_are_reported(self):
        self.png.unlink()
        self.caf.unlink()
        _, errors = inspect(self.root)
        self.assertEqual(sum("missing runtime resource" in value for value in errors), 2)

    def test_inventory_catches_an_entire_deleted_imageset(self):
        self.png.unlink()
        (self.png.parent / "Contents.json").unlink()
        self.png.parent.rmdir()
        _, errors = inspect(self.root)
        self.assertTrue(any("AppIcon.png: missing runtime resource" in value for value in errors))

    def test_new_catalog_reference_is_checked_before_inventory_refresh(self):
        metadata = self.png.parent / "Contents.json"
        metadata.write_text('{"images":[{"filename":"new-image.png"}]}')
        _, errors = inspect(self.root)
        self.assertTrue(any("new-image.png: missing runtime resource" in value for value in errors))

    def test_empty_or_invalid_headers_fail(self):
        self.png.write_bytes(b"")
        self.caf.write_bytes(b"not a CAF")
        _, errors = inspect(self.root)
        self.assertTrue(any("empty runtime resource" in value for value in errors))
        self.assertTrue(any("invalid or truncated CAF header" in value for value in errors))

    def test_catalog_paths_cannot_escape_runtime_assets(self):
        (self.png.parent / "Contents.json").write_text('{"images":[{"filename":"../../../private.png"}]}')
        _, errors = inspect(self.root)
        self.assertTrue(any("invalid catalog metadata" in value for value in errors))

    def test_missing_inventory_fails_without_silently_regenerating_it(self):
        (self.root / MANIFEST).unlink()
        _, errors = inspect(self.root)
        self.assertTrue(any("invalid or missing runtime inventory" in value for value in errors))
        self.assertFalse((self.root / MANIFEST).exists())

    def test_explicit_refresh_does_not_record_unhydrated_media(self):
        before = (self.root / MANIFEST).read_bytes()
        self.caf.write_bytes(LFS_HEADER)
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(main(["--root", str(self.root), "--update-manifest"]), 1)
        self.assertEqual((self.root / MANIFEST).read_bytes(), before)

    def test_generator_rejects_pointers_before_replacing_an_existing_project(self):
        scripts = Path(__file__).resolve().parent
        for filename in ("generate_project.rb", "check_runtime_assets.py"):
            (self.root / "scripts" / filename).write_bytes((scripts / filename).read_bytes())
        project = self.root / "CatLife.xcodeproj/project.pbxproj"
        project.parent.mkdir()
        project.write_text("existing project must remain untouched\n")
        before = project.read_bytes()
        self.png.write_bytes(LFS_HEADER)
        result = subprocess.run(["ruby", str(self.root / "scripts/generate_project.rb")],
                                capture_output=True, text=True, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(DOWNLOAD_COMMAND, result.stderr)
        self.assertIn("the Xcode project was not changed", result.stderr)
        self.assertEqual(project.read_bytes(), before)

    def test_refresh_declares_concrete_media_metadata_and_directory_sandbox_inputs(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(main(["--root", str(self.root), "--update-manifest"]), 0)
        inputs = set((self.root / SANDBOX_INPUTS).read_text().splitlines())
        for path in [self.png, self.caf, self.png.parent / "Contents.json",
                     self.png.parent, self.png.parent.parent, self.caf.parent]:
            self.assertIn("$(SRCROOT)/" + path.relative_to(self.root).as_posix(), inputs)


if __name__ == "__main__":
    unittest.main()
