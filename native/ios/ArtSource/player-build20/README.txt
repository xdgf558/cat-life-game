0.4.1 / build 20 — Player artwork from the user's reference
Artwork prepared 2026-11-02. This document records asset provenance; build,
test and device-delivery evidence is linked in the status section below.

Reference
user-reference.jpg is the local copy of the image supplied by the user:
<USER_HOME>/Downloads/IMG_1160.jpg
The copied reference is byte-identical to the supplied file. SHA-256:
5cc38774874c1d7d3105cab0f03a6028a040aec80e72b20e1e5f37a436b104bf
The six characters are arranged as three rows, with male characters on
the left and female characters on the right.

Process
Each character is extracted independently from the reference using the
built-in image_gen.imagegen tool with a transparent background. The source
image is the edit target; the intended result preserves the corresponding
character's face, hairstyle, clothing, colors, footwear, and pose. Other
characters, labels, sheet background, and floor shadows are removed.
The bottom-right scholarly female wears wide-leg cropped trousers; retain
the two trouser legs rather than turning the garment into a skirt.

Asset mapping (existing save IDs and all six display names are retained)
male_sunny       / 晴日男生 / player-male-sunny.png       / top left
male_forest      / 森系男生 / player-male-forest.png      / middle left
male_scholarly   / 书卷男生 / player-male-scholarly.png   / bottom left
female_sunny     / 晴日女生 / player-female-sunny.png     / top right
female_forest    / 森系女生 / player-female-forest.png    / middle right
female_scholarly / 书卷女生 / player-female-scholarly.png / bottom right
Traditional Chinese and English names also retain their existing strings.

All six selected PNG sources are present in this directory. Each source
is copied without pixel changes to the matching runtime catalog path:
../../CatLife/Assets.xcassets/<asset-name>.imageset/<asset-name>.png
Here <asset-name> is the PNG filename above without its extension.
prompts-male.json and prompts-female.json record the individual prompts,
original generated output paths, and source/runtime provenance.
Final file checks on 2026-11-02 confirmed all six expected filenames,
both three-character prompt manifests, and byte-identical source/runtime
copies. Every PNG is 1254 x 1254 RGBA with alpha values ranging from 0 to
255. asset-validation.json records the detailed image validation.

Scope and compatibility
Only the six player illustrations are replaced. The existing avatar IDs,
saved appearance choice, attributes, owned items, and equipped items are
retained. Equipment remains a set of separate inventory icons; these
portraits are not clothing layers that visually change with equipment.
Room and cat artwork, layout, and size are unchanged.

Validation and delivery status
The six-file source/runtime mapping has been checked. Simulator and signed
0.4.1 (20) device builds and codesign verification passed. The three targeted
UI executions passed without failures; Core was unchanged and its build-19
129-test / 11-suite evidence was retained without a new Core run. Actual SE
and Pro character/profile screenshots were reviewed at normal display size.
Detailed validation evidence is in ../../QA/avatar-verification.json.

On 2026-11-02, 0.4.1 (20) was installed in place on iPhone Air after the prior
connection block was resolved. Installed version/build were queried, and the
3572-byte normal save was byte-identical before the first new launch (SHA256
44ad5c0519351d5a366acdcf763fc60194761333b4a4cf4148c081a7fffdb729).
Normal launch without test/reset arguments succeeded; PID <REDACTED> was verified
in the new installation directory 00000000-0000-0000-0000-000000000018.
No uninstall, save reset or save edit occurred. Delivery and launch are
confirmed; user acceptance remains pending. Device evidence is recorded in
../../QA/build20-device-update.json.
