# Style reference: pastel-stage architecture diagram

This reference defines reusable visual conventions, not a content template.
Derive component names, stage headings, and group membership from the input
diagram or explicit user instructions, never from a previous diagram.

## Observed style tokens

These values come from the reference scene, rather than generic Excalidraw defaults.

| Element/property | Value |
| --- | --- |
| Canvas | White `#ffffff`; visible grid disabled |
| Node borders, connectors, body text | Slate `#334155` |
| Node fill | White `#ffffff` |
| Stroke width | `2` |
| Roughness | `0`: clean lines, not sketchy double strokes |
| Opacity | `100` |
| Fill style | `solid`, not hachure |
| Rectangle roundness | `{ "type": 3 }` |
| Font | Excalifont, `fontFamily: 5` in the reference schema |
| Stage headings | `24`, colored to match the stage border |
| Node labels | `20`, centered |
| Connector labels | `18`, centered within their label box |
| Text line height | `1.25` |
| Ordinary node borders | Solid |
| Stage borders | Dashed |
| Default connectors | Solid, transparent fill, no start head, end head `arrow` |
| Connector corners | Unrounded orthogonal turns where waypoints are needed |

Use the runtime's named font and roundness constants where available. Wait for
Excalifont to load before measurement/export. If unavailable, report the missing
font; do not silently substitute a font with different metrics.

The visual character is **precise shapes plus informal lettering**, not rough
strokes. Avoid gradients, shadows, icons, decorative badges, and rainbow node fills.

## Stage palette

| Palette option | Border and heading | Background |
| --- | --- | --- |
| Blue | Blue `#3b82f6` | Pale blue `#dbeafe` |
| Amber | Amber `#d97706` | Pale amber `#fef3c7` |
| Green | Green `#16a34a` | Pale green `#dcfce7` |

Color belongs primarily to stage panels; service nodes remain white. Color is
reinforced by a visible heading. Palette options have no predefined functional
meaning or security classification. Honor explicit user color mappings; otherwise
use these options to distinguish groups visually, reusing colors when appropriate.
Retain source subgraph names and do not invent stage names to fit the palette.

Panels are dashed rounded rectangles, not clipping frames. Their count, placement,
and membership follow the input graph and any user-provided grouping, not a fixed
stage layout. Prefer left-aligned headings inset from the upper-left corner.

## Layout defaults derived from the reference

These are starting heuristics, not exact constraints or a fixed-size template.
All dimensions are scene units, independent of export resolution.

| Property | Starting point |
| --- | --- |
| Ordinary node width | 190-305; approximately 280 for text-heavy nodes |
| Ordinary node height | 80-110; grow with measured text |
| Inner label padding | At least 12 horizontally; aim for 16 vertically |
| Horizontal gap between ordinary neighbors | About 80-130; increase for edge labels |
| Stage heading inset | About 20-30 |
| Stage heading reservation | At least 50 above content; more for bypass lanes |
| Gap between adjacent panels | About 15-20; expand when needed |
| Cylinder cap height | About 28 for a 210-235 wide cylinder |
| Connector endpoint gap | About 6-8, subject to runtime binding support |
| Label-to-line clearance | Recommended 10-16 |
| Outer export margin | Recommended 40 |

The reference is panoramic, approximately 2,900 by 600 before outer margins.
Preserve its spacious rhythm, not that aspect ratio for every graph. Do not scale
down fonts to fit a slide. Let graph complexity determine the canvas size.

## Editable database cylinders

The reference uses native primitives rather than an image or a native cylinder
element. Each storage node is a group containing:

1. A white body rectangle with no visible stroke, serving as the edge-binding
   anchor. Keep its geometry suitable for left/right endpoint attachment.
2. A white lower ellipse behind the body to complete the bottom fill.
3. Two slate vertical side lines.
4. A slate lower half-ellipse outline, represented by an open curved or sufficiently
   sampled polyline. Do not draw the hidden upper half of the lower ellipse.
5. A white top ellipse with a slate outline, above the body in paint order.
6. A centered text label, below the top cap and inside the body.

Give all parts and the label the same group ID. Map the Mermaid node ID to the
body anchor and retain all group members for moving, sizing, and collision checks.
Use the composite's full visible bounds for layout. Check that group movement
preserves incoming/outgoing bindings. Do not promise automatic composite resizing
unless the implementation supports it.

## Composition and routing

Arrange the primary chain along the input's flow direction. Place secondary
branches in separate rows or columns while preserving the graph's topology.
Size panels around their members and leave room for headings and connector lanes.

Use distinct tracks for opposing edges. Route long bypass connections outside
the main chain, with separate lanes when needed. Place edge labels in clear space
along their segments and keep panel headings clear of those lanes.

## Content preservation

Transfer visual conventions only. Preserve the input's component names,
capitalization, labels, and node boundaries. Do not copy content edits from
another diagram, add labels to unlabeled edges, or split a node into additional
components unless explicitly requested.

Panel headings are decorative grouping labels, not additional semantic nodes.
Use source subgraphs or user-provided mappings; disclose any inferred grouping
and leave ambiguous groups unassigned.

## Acceptance criteria

- Semantic node and edge counts match the input, including parallel edges and
  opposing paths. Edge directions, labels, and meaningful line styles are preserved.
- Unlabeled edges remain unlabeled.
- Source storage cylinders are editable grouped cylinders, not images or plain boxes.
- Pastel panels, when used, reflect the chosen grouping without adding semantic nodes.
- All labels match the Mermaid source after presentational whitespace normalization.
- Clean slate strokes, white nodes, Excalifont, and the observed type hierarchy.
- No clipped text, ambiguous edge direction, or connections through unrelated
  nodes. All graph elements remain individually editable or intentionally grouped.

## Implementation references

- Mermaid conversion API:
  https://docs.excalidraw.com/docs/@excalidraw/mermaid-to-excalidraw/api
- Converter source:
  https://github.com/excalidraw/mermaid-to-excalidraw
- Excalidraw font and appearance constants:
  https://github.com/excalidraw/excalidraw/blob/master/packages/common/src/constants.ts

Check the installed runtime rather than assuming these APIs and enum values are
unchanged. The converter documentation describes cylinder-to-rectangle and
non-flowchart-to-image fallbacks; neither satisfies this skill's editable output
contract without additional handling.
