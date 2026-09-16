# Documenting a transparent helper

A helper whose customisation points are undocumented is not transparent, however
good its signature is. The roxygen block has four required parts.

This template is derived from the real `gg_facet_wrap_months()` documentation in
[ggtilecal](https://github.com/cynthiahqy/ggtilecal) — see
`examples/after-gg_facet_wrap_months.R`.

## The four required parts

### 1. What it does, including which prep functions it calls

Name the helpers by name. This is how SEPARATE becomes visible to the reader.

```r
#' Make Monthly Calendar Facets
#'
#' Generates calendar with monthly facets by:
#' - Padding event list with any missing days via `fill_missing_units()`
#' - Calculating variables for calendar layout via `calc_calendar_vars()`
#' - Returning a ggplot object as per Details.
```

### 2. The FIXED components

State exactly what the user cannot change, and why it exists.

```r
#' Returns a ggplot with the following fixed components
#' using calculated layout variables:
#' - `aes()` mapping:
#'    - `x` is day of week,
#'    - `y` is week in month,
#'    - `label` is day of month
#' - `facet_wrap()` by month
#' - `labs()` to remove axis labels for calculated layout variables
```

### 2b. The SWITCHABLE components

If the helper has a switchable scalar (Step 3), document **every accepted value
and what each one selects**. The user cannot discover this from the signature
alone, because one argument is moving several coupled components at once.

```r
#' @param measure Which share to draw. One of:
#'   - `"pct"` — fills by `pct_isiccomb` (continuous 0-1) with a stepped
#'     orange scale, legend "Fraction of `isic` derived from `isiccomb`"
#'   - `"any"` — fills by `any_isiccomb` (logical) with a two-colour manual
#'     scale, legend "Crossmap involves at least 1 `isiccomb` split"
#'   The mapping, its scale and its legend label move together; they cannot be
#'   set independently, because a scale that does not match the column's type
#'   will error.
```

State the coupling explicitly. A user who sees `.fill_scale` in the signature
will otherwise assume they can pass any scale to it.

### 3. The DEFAULT CUSTOMISABLE components

List every default **by name**. Do not summarise as "sensible defaults" — the
user needs to know what is actually there in order to replace it.

```r
#' and default customisable components:
#' - `geom_tile()`, `geom_text()` to label each day which inherit calculated variables
#' - `scale_y_reverse()` to order day in month correctly
#' - `scale_x_discrete()` to position weekday labels
#' - `coord_fixed()` to square each tile
#' - `theme_bw_tilecal()` to apply sensible theme defaults
```

### 4. How to MODIFY, ADD, and REMOVE

The part most helpers omit, and the part that makes it transparent.

```r
#' To modify components alter the `.geom` and `.scale_coord`,
#' which inherit the calculated layout mapping by default
#' (via the ggplot2 `inherit.aes` argument).
#'
#' To add components use the ggplot `+` function as normal,
#' or pass components to the `.other` argument.
#' This can be used to add interactive geoms (e.g. from `ggiraph`)
#'
#' To modify the theme, use the ggplot `+` function as normal,
#' or add additional elements to the list in `.theme`.
#'
#' To remove any of the optional components, set the argument to an empty `list()`
```

## The list-argument `@param` idiom

Document the list arguments together, and state the empty-list rule:

```r
#' @param .geom,.scale_coord,.theme,.other
#'    Customisable lists of ggplot2 components to add to the plot.
#'    An empty `list()` leaves the plot unmodified.
```

## Chaining to the prep functions

If the prep helpers are exported, inherit their parameter docs rather than
restating them — this only reads well when those functions are themselves
documented, which is the argument for exporting them:

```r
#' @inheritParams ggplot2::facet_wrap
#' @inheritParams fill_missing_units
#' @inheritParams calc_calendar_vars
```

## Also include

- `@return ggplot`
- `@export`
- `@examples` — a runnable call showing one customisation, ideally demonstrating
  composition with `+` so readers see that it still works
- `@importFrom` listing every ggplot2 function used internally — **but only if
ggplot2 is in `Imports`**. If the plotting packages are in `Suggests` (common
for a package whose plots are optional), `@importFrom` on them is an
`R CMD check` error. Use `::` calls throughout, guard the function body with
`rlang::check_installed()`, and write examples under `@examplesIf
rlang::is_installed(...)` rather than `\dontrun{}`

## Document the footguns

If the removal-semantics check found a group that produces a *wrong* plot rather
than a plainer one when set to `list()`, say so here explicitly. For example: the
calendar's `.scale_coord` contains `scale_y_reverse()`, so emptying it flips the
calendar upside down rather than merely unstyling it.
