#!/usr/bin/env python3
"""Import game art while preserving the separately maintained AppIcon asset set."""
import json
import shutil
from pathlib import Path

root = Path(__file__).resolve().parent.parent
source = root / "ArtSource"
catalog = root / "CatLife" / "Assets.xcassets"
catalog.mkdir(parents=True, exist_ok=True)
(catalog / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
game_images = [image for image in sorted(source.rglob("*.png")) if not image.stem.startswith("app-icon")]
names = [image.stem for image in game_images]
if len(names) != len(set(names)):
    raise ValueError("Runtime image names must be unique across ArtSource subdirectories")
for image in game_images:
    item = catalog / (image.stem + ".imageset")
    item.mkdir(exist_ok=True)
    shutil.copy2(image, item / image.name)
    (item / "Contents.json").write_text(json.dumps({
        "images": [{"filename": image.name, "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": False}
    }, indent=2) + "\n")

# AppIcon.appiconset is maintained directly so importing art cannot replace its appearances.
# These obsolete generated image sets were never referenced by the app UI.
for obsolete in (catalog / "app-icon.imageset", catalog / "app-icon-v2.imageset"):
    if obsolete.exists():
        shutil.rmtree(obsolete)
accent = catalog / "AccentColor.colorset"
accent.mkdir(exist_ok=True)
(accent / "Contents.json").write_text(json.dumps({
    "colors": [{"idiom": "universal", "color": {"color-space": "srgb", "components": {
        "alpha": "1.000", "red": "0.200", "green": "0.680", "blue": "0.540"
    }}}], "info": {"author": "xcode", "version": 1}
}, indent=2) + "\n")
print("Imported", len(game_images), "game assets into", catalog, "(AppIcon unchanged)")
