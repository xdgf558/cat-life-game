Furniture assets — 2026-10-31

Generated with built-in image_gen.imagegen only, one request per asset.
Source reference: ../room-background.png. Original background was not changed.
Full request prompts: prompts.json. Exact generator output paths: generation-manifest.json.
Selected original generator PNG bytes were copied unchanged into this folder and matching CatLife/Assets.xcassets imagesets. No Python drawing, background removal, alpha editing, cropping, scaling or other pixel processing was performed. Pillow was used only to inspect dimensions/alpha and measure registration bounds.

room-empty.png is the opaque clean room plate, 1024x1536, with the original architectural window, trim, wood floor, platform and step. The eight furniture PNGs contain real RGBA transparency. Some image viewers expose hidden RGB values in fully transparent pixels as a glow/black backdrop; sampled glow-region alpha values are zero, so a correct RGBA compositor does not render them.

registration.json reports image dimensions, alpha bounds at 1/32/128/250, bottom silhouette bands, suggested bottom-center sprite anchors and SHA256. Use alpha>=128 for stable object registration. Band rectangles are pixel measurements, NOT precise physical support footprints. Cabinet/stool perspective legs and broad cat-tree/bed bases need deliberately chosen floor collision rectangles; wall pictures use wall placement rather than floor feet.

All furniture silhouettes are complete, without original room-edge cropping. The bed includes its yellow gingham insert and blue fish plush as one asset; the cat tree includes the hanging ball. Cabinet top is empty.
