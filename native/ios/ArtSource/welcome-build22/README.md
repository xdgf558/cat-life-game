# Welcome artwork — build 22

The supplied reference is retained as `reference.png`. Its UI text, badges, button, and version were removed with the built-in image generation editor to produce `welcome-arrival-background.png` (851 × 1847). Native SwiftUI draws the localized title and interactive loading/entry controls separately.

`welcome-arrival-compact-background.png` (941 × 1672, approximately 9:16) is a second built-in image edit for compact iPhone screens such as iPhone SE at 375 × 667 points. The edit extends the scenery to the left and right so the image fills the wider screen without blurred sidebars or visible seams. The person's head remains around 20% of image height and the front shoe around 78%; the cat and person remain fully visible, with the bottom region available for native controls.

The two exact prompts are retained as `welcome-arrival.prompt.txt` and `welcome-arrival-compact.prompt.txt`. Both outputs were visually inspected. Image generation may slightly reconstruct the artwork; pixel-identical subject preservation is not claimed.

Runtime assets are JPEG encodings at quality 92 with the original generated pixel dimensions:

- `CatLife/Assets.xcassets/welcome-arrival.imageset/welcome-arrival.jpg`
- `CatLife/Assets.xcassets/welcome-arrival-compact.imageset/welcome-arrival-compact.jpg`

No UI text or system/device chrome is baked into either runtime background.
