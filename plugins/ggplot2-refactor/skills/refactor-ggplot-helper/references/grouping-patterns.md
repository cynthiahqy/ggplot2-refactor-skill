# Grouping the list arguments

The customisable ggplot2 components have to be grouped into named list
arguments. There are two defensible ways to do it, and the choice is a real
design decision with real costs either way. This is the heart of the skill: make
the user choose deliberately rather than defaulting silently.

Background discussion:
[ggplot2-extenders/ggplot-extension-club#157](https://github.com/ggplot2-extenders/ggplot-extension-club/discussions/157)

## Layer-focused

Group by **ggplot2 component type**.

```r
gg_facet_wrap_months(
  .events_long, date_col,
  nrow = NULL, ncol = NULL,
  .geom = list(
    geom_tile(color = "grey70", fill = "transparent"),
    geom_text(nudge_y = 0.25)
  ),
  .scale_coord = list(
    scale_y_reverse(),
    scale_x_discrete(position = "top"),
    coord_fixed(expand = TRUE)
  ),
  .theme = list(theme_bw_tilecal()),
  .other = list()
)
```

**For:** predictable for anyone who knows ggplot2. The same argument names work
across every helper you write, so users learn the convention once. Easy to
document generically.

**Against:** a user who wants to change only the day labels must re-supply the
*whole* `.geom` list, including the tile they didn't want to touch. Mitigate by
documenting the default list verbatim so it can be copy-pasted and edited.

## Chart-focused

Group by **what a reader of the chart sees**.

```r
gg_facet_wrap_months(
  .events_long, date_col,
  nrow = NULL, ncol = NULL,
  .day_tiles  = list(geom_tile(color = "grey70", fill = "transparent")),
  .day_labels = list(geom_text(nudge_y = 0.25)),
  .calendar_layout = list(
    scale_y_reverse(),
    scale_x_discrete(position = "top"),
    coord_fixed(expand = TRUE)
  ),
  .theme = list(theme_bw_tilecal())
)
```

**For:** more intuitive for this specific chart — "change the day labels" maps to
one argument. Gets you closer to designing a proper ggplot2 extension, because
you are naming the chart's *semantic elements* rather than its implementation.

**Against:** these names exist only in your package. Users cannot guess that
`.calendar_layout` holds both scales *and* a coord. Every helper invents its own
vocabulary, so there is nothing to transfer between them.

## Hybrid

Semantic names for the chart-specific parts, generic `.theme` and `.other` for
the rest. Often the pragmatic answer.

## Derivation recipe (run this before asking)

Do not present the chart-focused option as an abstraction. Derive a **concrete**
proposal from the user's own plot:

1. For each customisable layer, ask: *what does this draw, in the chart's own
   vocabulary?*
2. **Merge layers that draw the same visual element**, even if they are different
   geoms or repeated calls of the same geom.
3. Name each group after that element, prefixed with `.`.
4. Anything with no semantic home stays in `.theme` / `.other`.

### Worked derivation — the travel calendar

The source has two separate `geom_text()` calls: one draws the day-of-month
number, one draws a country flag emoji. Layer-focused grouping puts both in
`.geom` alongside the tile. Chart-focused grouping asks what the *reader* sees:

| Group | Contains | Why |
|---|---|---|
| `.day_tiles` | `geom_tile()` | the cell itself |
| `.day_labels` | *both* `geom_text()` calls | one visual idea — "what's written in the day" |
| `.calendar_layout` | `scale_y_reverse()`, `scale_x_discrete()`, `coord_fixed()` | all three exist to make it look like a wall calendar |
| `.theme` | `theme_bw_tilecal()` | no semantic home |

Note that `.day_labels` **merges across** the layer-focused boundary while
`.calendar_layout` **merges scales with a coord**. That crossing is exactly what
makes this a genuine choice rather than a renaming exercise.

## Removal semantics (check every time)

Each group should degrade sensibly when set to `list()` — the plot gets plainer,
not wrong.

Check each group and flag the ones that fail. In the calendar example
`.calendar_layout = list()` removes `scale_y_reverse()`, which silently flips the
calendar upside down — days run bottom-to-top. That is a footgun, not a plainer
plot. When you find one:

- tell the user which group misbehaves and how,
- recommend documenting it explicitly, or
- suggest splitting the offending component out into its own argument or into the
  fixed set.
