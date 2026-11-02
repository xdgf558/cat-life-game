0.4.0 / build 19 — Player and starter equipment artwork
Created 2026-11-02 using the built-in image_gen tool, not CLI/API fallback.

Final player assets (transparent whole-body illustrations):
player-male-sunny.png / player-female-sunny.png — sunny ivory and apricot
player-male-forest.png / player-female-forest.png — calm sage and oatmeal
player-male-scholarly.png / player-female-scholarly.png — dusty blue and beige

Final equipment assets (transparent inventory icons):
gear-starter-cap.png — cream and mint paw cap
gear-starter-jacket.png — cream work jacket with mint trim
gear-starter-sneakers.png — cream and mint comfortable sneakers
gear-starter-charm.png — orange plush paw with mint strap

All ten selected originals are copied without pixel edits into matching
CatLife/Assets.xcassets/<asset-name>.imageset directories. The asset names are
the filenames above without .png. Each generated PNG is 1254 x 1254 RGBA with
actual transparency. Source and catalog copies are byte-identical.

Characters share a roughly three-heads-tall chibi proportion, standing pose,
adult-inspired casual styling and soft refined 3D cartoon rendering. Their
heads are near y=75–100 and shoes near y=1190; the generous horizontal alpha
clearance is intentional. Use aspect-fit for whole-body cards. A circular
face avatar requires a deliberate display viewport rather than fitting the
entire figure into a small circle. No image pixels were cropped or resized.

Equipment pictures are inventory icons, not clothing layers registered to
the character body. Character illustrations depict their baseline clothes.

prompts-and-provenance.json contains the exact prompt set, generation mode,
original output paths, and proportion-reference history. The taller first
sunny-male concept is preserved as male-sunny-initial-tall-concept.png and is
not referenced by the app. asset-validation.json records dimensions, alpha
bounds, byte sizes and SHA256 values for all selected assets.

Visual inspection: all six figures and four objects are fully visible;
styles and palettes match; no added labels, watermarks, cats or backgrounds.
