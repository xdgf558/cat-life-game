# Build 61 room materials

`room-floor-wood` is a new opaque, straight-down honey oak floor material for the projected 2.5D room plane. `room-empty.png` was inspected for palette only; no existing artwork was changed. Generated with the built-in `image_gen` tool, then resampled from 1254×1254 to 1024×1024 with macOS `sips`.

- Runtime: `CatLife/Assets.xcassets/room-floor-wood.imageset/room-floor-wood.png` (1024×1024 PNG, no alpha).
- Original: `/Volumes/AI作品素材/软件开发/猫游戏原生产物/0.20.0-61/art/room-floor-wood-original.png` (1254×1254).
- Original SHA-256: `9896e89ba7b4ff9325a0d466d4792a4bd71a2427cad491d73f1eb25b996228fa`.
- Runtime SHA-256: `a1963d1b709233cc07e76e782eca3902aebf8874dc5d37d3ae29c91e13b99464`.

## Generation prompt

```text
Use case: stylized-concept
Asset type: seamless square albedo material texture for the floor plane of a cozy 2.5D cat-care game.
Primary request: Generate one new 1024 x 1024 pixel warm light honey oak wooden floor texture, viewed perfectly straight down in orthographic top view. Full image is filled edge to edge with parallel equal-width wooden floor planks, aligned vertically, staggered end joints, with gentle subtle flowing wood grain. Pale golden apricot honey oak colors, restrained variations between planks, softly hand-painted polished game-art finish compatible with a warm sunny cozy room.
Composition/framing: flat material swatch, no perspective, no depth or horizon; all planks exactly equal width, straight parallel edges; seamless tiling horizontally and vertically with continuous edge patterns.
Lighting/mood: uniform neutral diffuse baked color only; no sunlight patches, directional illumination, cast shadows, ambient occlusion, highlights, vignette, or dark edges.
Constraints: Only wood flooring, a true full-bleed square surface texture. Fine narrow low-contrast join lines. No walls, skirting, windows, furniture, objects, borders, framing, text, symbols, watermarks or transparency. No herringbone, no diagonals, no perspective distortion. Opaque background.
```

## Wall and window materials

Both assets were generated with the built-in `image_gen` tool after inspecting the original `room-empty.png` and the first device screenshot `F0995AAB-F106-48B9-AFA0-5289E0590CE8.png`. They add depth to the procedurally projected room while retaining the original warm handcrafted 3D cartoon style. The window received two additional built-in image edits to reduce stray edge colors. Export processing used only macOS `sips` resizing; window alpha is preserved.

| Asset | Runtime dimensions | Alpha | Original dimensions |
| --- | --- | --- | --- |
| `room-wall-plaster` | 1024×1024 | none | 1254×1254 |
| `room-window-arched` | 768×1024 | transparent exterior, glazed scene retained | 1086×1448 |

Runtime files are under `CatLife/Assets.xcassets/<asset>.imageset/<asset>.png`. Originals are archived outside the repository under `/Volumes/AI作品素材/软件开发/猫游戏原生产物/0.20.0-61/art/` as `room-wall-plaster-original.png` and `room-window-arched-original.png`.

| File | SHA-256 |
| --- | --- |
| wall original | `7721af43ff06bbb3e6f38510840d791edf607a96145fc778482925b0ea44ff6f` |
| wall runtime | `0e091acabd1b21d8471a0d180339ebcc80da94074de3a122905f5c39c13277db` |
| window original (selected final edit) | `e0417ed2914a4bd88322848dd83455d62f441a6513678e80d181c3652956a0c3` |
| window runtime | `8647a57e30b129049c474eeedf8f675c387323dad7aebd69729834f171acd5c6` |

### Wall generation prompt

```text
Use case: stylized-concept
Asset type: seamless opaque square wall albedo material for a cozy 2.5D cat-care game.
Primary request: A new 1024 x 1024 pixel front-facing flat swatch of very pale warm cream beige limewashed plaster with a fine handmade paper-like microtexture. Cozy refined handcrafted 3D cartoon material finish, softly tactile and restrained, matching a sunny room with honey oak flooring.
Composition/framing: Perfectly flat front elevation, no perspective; the entire image filled edge to edge by one continuous uniform plaster surface. Seamlessly tileable on all four sides, no framing or edge darkening.
Lighting/mood: Very soft warm neutral diffuse light. Almost uniform color, only the faintest natural tonal variation and tiny surface relief, no obvious large gradient.
Materials/textures: Fine delicate limestone plaster / paper micrograin, low contrast, very light ivory cream with a subtle peach-beige warmth.
Constraints: Material texture only. No wall corners, seams, joints, skirting, windows, bricks, furniture, objects, cracks, stains, shadows, sunlight patches, text, symbols, borders, watermark or transparency. No room scene, no mockup.
```

### Window generation prompt

```text
Use case: stylized-concept
Asset type: isolated transparent-background front elevation window sprite for projection onto a 2.5D game wall.
Primary request: One complete tall arched honey oak wooden window, straight-on front elevation, in a warm exquisite handcrafted 3D cartoon style for a cozy sunny cat-care room. Full rounded arch at the top, thick softly beveled golden honey wooden surround, substantial softly rounded wooden sill extending slightly beyond both lower corners. Fine subtle wood grain and warmly polished hand-carved material.
Subject: A single closed arched window with exactly four glass panes: one central vertical wooden mullion and one horizontal wooden crossbar dividing the opening into two upper arched panes and two lower panes. Through the glass show a charming sunny outdoor view of clear pastel blue sky, soft white clouds, and lush blurred green treetops. Subtle gentle glass sheen while keeping the bright outdoor view visible.
Composition/framing: Perfect straight-on orthographic front elevation. Symmetrical complete arch, both sides vertical and parallel, no isometric skew, no camera rotation or slant. The entire window and sill fully visible with a small clear transparent margin on every side. Portrait composition about 3:4. Centered single object.
Lighting/mood: Soft warm daylight, rounded dimensional highlights and gentle self-shading on the thick wooden frame. Bright inviting old-fashioned sunny-room feeling.
Constraints: Genuine transparent alpha outside the full window silhouette. Keep the sky and trees inside the glazed opening opaque. No wall, wall patch, floor, scene surroundings, wall shadow, background color, rectangle backdrop, checkerboard, text, logos, watermark, curtains, flower pots, handles or extra decoration. No perspective distortion.
```

### Window boundary cleanup prompts

```text
Use case: precise-object-edit
Asset type: transparent front elevation window sprite for a 2.5D game.
Edit target: the supplied arched honey oak window image.
Primary request: Repair ONLY the cutout boundary and exterior transparency. Remove every stray red, orange-red or yellow pixel, jagged colored fringe, isolated speckle and residue outside the actual wood window silhouette. Produce a pristine smooth softly antialiased alpha edge with clean genuinely transparent exterior on all sides. At the lower edge of the wooden sill especially, remove the red strip completely. No red or yellow outlines. A small completely transparent margin should surround the complete silhouette.
Invariants: Keep the exact same complete straight-on symmetrical four-pane arched honey oak window, thick rounded frame and sill, wood grain, dimensions and composition, blue sky, white clouds and green trees. Keep the rich handcrafted warm 3D cartoon style and all interior details. The glass/outdoor scene and wood should be opaque; only the exterior is transparent.
Constraints: Change only boundary cleanup and transparency; do not add, remove or redesign any window parts. No wall or backdrop, no checkerboard, no text, no watermark, no cropped sill.
```

```text
Use case: precise-object-edit
Edit target: supplied arched wooden window cutout.
Primary request: Rebuild a perfectly clean cutout boundary by trimming away the entire outermost 8-pixel contaminated rim around the window and sill, then smoothing the remaining golden wood contour. In particular erase the thin bright red residue below the sill completely into transparency. Also erase every floating pixel outside the window. The outer edge must be made exclusively of ordinary honey-colored wood meeting a clean transparent alpha background, with no colored stroke.
Keep the existing front elevation four-pane arched wooden window and its opaque blue-sky/cloud/tree view, warm 3D cartoon design, thick wood frame and complete sill. Only the outer rim may become very slightly smaller to remove the contamination. The rest of the image remains unchanged. Transparent exterior, no shadows or glow outside the object.
```
