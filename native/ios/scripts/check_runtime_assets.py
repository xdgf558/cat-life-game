#!/usr/bin/env python3
"""Fail before generation/build when required runtime media are absent or LFS pointers."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


LFS_HEADER = b"version https://git-lfs.github.com/spec/v1"
RUNTIME_DIRECTORIES = ("CatLife/Assets.xcassets", "CatLife/Audio")
MANIFEST = "scripts/runtime_assets.json"
SANDBOX_INPUTS = "scripts/runtime_assets.xcfilelist"
DOWNLOAD_COMMAND = 'git lfs pull --include="native/ios/CatLife/**"'


def validate_media(path: Path) -> str | None:
    if not path.is_file():
        return "missing runtime resource"
    try:
        with path.open("rb") as stream:
            header = stream.read(256)
    except OSError:
        return "unreadable runtime resource"
    if header.startswith(LFS_HEADER):
        return "Git LFS pointer; the media has not been downloaded"
    if not header:
        return "empty runtime resource"
    # This is an early hydration/header check, not an image or audio decoder.
    suffix = path.suffix.lower()
    if suffix == ".png" and (len(header) < 24 or not header.startswith(b"\x89PNG\r\n\x1a\n")):
        return "invalid or truncated PNG header"
    if suffix in (".jpg", ".jpeg") and not header.startswith(b"\xff\xd8\xff"):
        return "invalid JPEG header"
    if suffix == ".caf" and (len(header) < 8 or not header.startswith(b"caff\x00\x01")):
        return "invalid or truncated CAF header"
    return None


def relative_resource(value: object) -> str:
    if not isinstance(value, str):
        raise ValueError("resource paths must be strings")
    path = Path(value)
    if path.is_absolute() or ".." in path.parts or not any(
        value.startswith(directory + "/") for directory in RUNTIME_DIRECTORIES
    ):
        raise ValueError("resource path is outside the runtime directories")
    return value


def inspect(root: Path, *, updating_manifest: bool = False) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    required: set[str] = set()
    if not updating_manifest:
        try:
            manifest = json.loads((root / MANIFEST).read_text())
            entries = manifest["resources"]
            if manifest.get("schemaVersion") != 1 or not isinstance(entries, list) or not entries:
                raise ValueError("expected a nonempty schema 1 resource list")
            required.update(relative_resource(item) for item in entries)
        except (OSError, ValueError, KeyError, TypeError) as error:
            errors.append(f"{MANIFEST}: invalid or missing runtime inventory ({type(error).__name__})")

    for directory in RUNTIME_DIRECTORIES:
        if not (root / directory).is_dir():
            errors.append(f"{directory}: missing runtime directory")
    catalog = root / RUNTIME_DIRECTORIES[0]
    for metadata in (catalog / "Contents.json", catalog / "AppIcon.appiconset/Contents.json"):
        if not metadata.is_file():
            errors.append(f"{metadata.relative_to(root).as_posix()}: missing asset catalog metadata")
    # Include every declared catalog file, including newly added assets which
    # have not yet been added to the inventory. The inventory also catches a
    # whole imageset/audio file being deleted, which a directory scan cannot.
    for metadata in sorted(catalog.rglob("Contents.json")):
        try:
            content = json.loads(metadata.read_text())
            for collection in ("images", "data"):
                for item in content.get(collection, []):
                    filename = item.get("filename")
                    if filename is None:
                        continue
                    if not isinstance(filename, str) or Path(filename).name != filename:
                        raise ValueError("asset filenames must be simple relative names")
                    required.add(relative_resource((metadata.parent / filename).relative_to(root).as_posix()))
        except (OSError, ValueError, TypeError, AttributeError) as error:
            errors.append(f"{metadata.relative_to(root).as_posix()}: invalid catalog metadata ({type(error).__name__})")
    for directory in RUNTIME_DIRECTORIES:
        required.update(path.relative_to(root).as_posix() for path in (root / directory).rglob("*")
                        if path.is_file() and path.name != "Contents.json" and not path.name.startswith("."))
    if not required:
        errors.append("runtime resource inventory is empty")
    for relative in sorted(required):
        problem = validate_media(root / relative)
        if problem:
            errors.append(f"{relative}: {problem}")
    return sorted(required), errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent,
                        help="native/ios directory (defaults to the script's parent)")
    parser.add_argument("--update-manifest", action="store_true",
                        help="record a deliberate runtime asset addition/removal after validating all present media")
    args = parser.parse_args(argv)
    resources, errors = inspect(args.root, updating_manifest=args.update_manifest)
    if errors:
        print("error: CatLife runtime assets are not ready; generation/build stopped.", file=sys.stderr)
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        print("error: From the repository root, install Git LFS and run:", file=sys.stderr)
        print("error:   git lfs install", file=sys.stderr)
        print(f"error:   {DOWNLOAD_COMMAND}", file=sys.stderr)
        print("error: If a tracked resource or metadata file was deleted locally, restore that file from Git.", file=sys.stderr)
        print("error: Re-run python3 native/ios/scripts/check_runtime_assets.py before building.", file=sys.stderr)
        return 1
    if args.update_manifest:
        (args.root / MANIFEST).write_text(json.dumps({"schemaVersion": 1, "resources": resources}, indent=2) + "\n")
        # Xcode's script sandbox needs concrete file-read entries. Directory
        # inputs alone do not authorize opening every descendant's contents.
        inputs = set(resources)
        for directory in RUNTIME_DIRECTORIES:
            inputs.add(directory)
            inputs.update(path.relative_to(args.root).as_posix()
                          for path in (args.root / directory).rglob("*")
                          if not path.name.startswith("."))
        (args.root / SANDBOX_INPUTS).write_text("\n".join("$(SRCROOT)/" + path for path in sorted(inputs)) + "\n")
    print(f"CatLife runtime asset preflight passed: {len(resources)} hydrated files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
