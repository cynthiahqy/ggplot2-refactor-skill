# AFTER (a): layer-focused grouping -- .geom / .scale_coord / .theme
#
# Decision C took the layer-focused branch: list arguments grouped by ggplot2
# object type, the same shape as `after-gg_facet_wrap_months.R`.
#
# Reproduce with:
#   install.packages(c("xmap", "ggforce", "ggrepel"))
library(xmap)
library(dplyr)
library(ggplot2)

# NOTE ON THE DEFAULTS BELOW
# Because `ggplot()` is empty and each layer carries its own `data =`, the
# `.geom` defaults cannot be bare geoms -- there is nothing to inherit from.
# They reference `.layout`, which is bound in the function body BEFORE the
# `+` chain forces the lazily-evaluated defaults. Moving that binding below
# the `+` chain breaks the function with an unhelpful error.

#' Calculate Node-Link Layout for an Crossmap Bigraph
#'
#' Computes the plotting coordinates for a node-link (bipartite graph) diagram
#' of an `xmap_tbl`, without drawing anything. Source codes are placed in a
#' left-hand column and target codes in a right-hand column, each ordered by
#' first appearance, with the target column offset by half a row so the links
#' fan out visibly.
#'
#' Returns a named list of four tibbles:
#' - `edges`: one row per link, with `from`, `to`, `weight`, the joined
#'   `from_y`/`to_y` positions, `is_split` (a fractional weight), a
#'   `curve_linetype` of `"dashed"` for splits and `"solid"` otherwise, and an
#'   `id` used to group each curve.
#' - `from_nodes`: distinct source codes with their `from_y` positions.
#' - `to_nodes`: distinct target codes with their `to_y` positions.
#' - `labels`: the split links only, with `label_x`/`label_y` midpoints for
#'   annotating the weight.
#'
#' This is exported separately from [gg_diagonal_bigraph()] so the layout can be
#' inspected and tested without producing a plot, and so that users overriding
#' the `.geom` or `.scale_coord` arguments of [gg_diagonal_bigraph()] can obtain
#' the same data frames the defaults use.
#'
#' @param .xmap An `xmap_tbl`, as created by [as_xmap_tbl()].
#'
#' @return A named `list` of four tibbles: `edges`, `from_nodes`, `to_nodes`,
#'   `labels`.
#' @export (dropped: standalone script)
#'
#' @examples
#' xm <- as_xmap_tbl(demo$simple_links, xcode, alphacode, weight)
#' layout <- calc_bigraph_layout(xm)
#' layout$from_nodes
#' layout$edges
calc_bigraph_layout <- function(.xmap) {
  edges <- tibble::tibble(
    from = .xmap$.from[[1]],
    to = .xmap$.to[[1]],
    weight = .xmap$.weight_by[[1]]
  )

  from_nodes <- dplyr::mutate(
    dplyr::distinct(edges[, "from"]),
    from_y = dplyr::row_number()
  )
  to_nodes <- dplyr::mutate(
    dplyr::distinct(edges[, "to"]),
    to_y = dplyr::row_number() - 1 + 0.5
  )

  edges <- edges |>
    dplyr::left_join(from_nodes, by = "from") |>
    dplyr::left_join(to_nodes, by = "to") |>
    dplyr::mutate(
      is_split = .data[["weight"]] < 1,
      curve_linetype = ifelse(.data[["is_split"]], "dashed", "solid"),
      id = dplyr::row_number()
    )

  labels <- edges |>
    dplyr::filter(.data[["is_split"]]) |>
    dplyr::mutate(
      label_x = 0.5,
      label_y = (.data[["from_y"]] + .data[["to_y"]]) / 2
    )

  list(
    edges = edges,
    from_nodes = from_nodes,
    to_nodes = to_nodes,
    labels = labels
  )
}

#' Draw a Crossmap as a Node-Link Bigraph
#'
#' Draws the `.from -> .to` structure of an `xmap_tbl` as a bipartite node-link
#' diagram, with source codes on the left, target codes on the right, and a
#' curved arrow per link. Fractional weights are drawn as dashed, partly
#' transparent curves and annotated with a repelled label.
#'
#' The plot is built by:
#' - Computing node positions and link geometry via [calc_bigraph_layout()]
#' - Returning a ggplot object as per Details.
#'
#' @details
#' Returns a ggplot with the following **fixed** components, which use the
#' computed layout variables and therefore cannot be supplied by the caller
#' without first calling [calc_bigraph_layout()] themselves:
#' - each layer's `data` argument, taken from the list returned by
#'   [calc_bigraph_layout()]
#' - the `aes()` mappings, which reference the computed columns `from_y`,
#'   `to_y`, `label_x`, `label_y`, `id` and `curve_linetype`
#' - the horizontal geometry: source nodes at `x = 0`, target nodes at `x = 1`,
#'   and arrowheads stopping short at `xend = 0.92` so they sit beside the
#'   target label rather than underneath it
#'
#' and the following **default customisable** components:
#' - `ggforce::geom_diagonal()` to draw each link as a curve, with
#'   `linewidth = 0.6`, `n = 100` and a closed `grid::arrow()` of length
#'   `0.15cm`
#' - `ggplot2::geom_label()` twice, for the source and target node labels, each
#'   with `linewidth = 0` and `fill = "grey95"`
#' - `ggrepel::geom_label_repel()` to annotate fractional weights, with
#'   `size = 3`, `label.size = 0`, `colour = "white"`, `seed = 1`,
#'   `direction = "x"`, `max.overlaps = Inf` and `min.segment.length = 0`
#' - `ggplot2::scale_colour_discrete(aesthetics = c("colour", "fill"))` limited
#'   to the source codes, so link colour and weight-label fill agree
#' - `ggplot2::scale_y_reverse()` so the first source code appears at the top
#' - `ggplot2::scale_alpha_continuous(range = c(0.4, 1))` so lighter links mean
#'   smaller weights
#' - `ggplot2::scale_x_continuous(limits = c(-0.15, 1.15))` so the node label
#'   boxes are not clipped at the panel edge
#' - `ggplot2::theme_void()` and `ggplot2::theme(legend.position = "none")`
#'
#' To **modify** components, re-supply the whole of `.geom`, `.scale_coord` or
#' `.theme`. These layers do not use `inherit.aes`: the plot is built on an
#' empty `ggplot2::ggplot()` and each layer carries its own `data` and `aes()`.
#' A replacement `.geom` must therefore supply those too, which is what
#' [calc_bigraph_layout()] is exported for. The defaults are reproduced in full
#' in the argument list so they can be copy-pasted and edited.
#'
#' To **add** components, use the ggplot2 `+` function as normal, or pass
#' components to `.other`, which are added after the theme and so can override
#' it. This is the place for interactive geoms (e.g. from `ggiraph`).
#'
#' To **remove** any of the optional components, set the argument to an empty
#' `list()`.
#'
#' @section Removing `.scale_coord`:
#' Unlike `.geom` and `.theme`, emptying `.scale_coord` does not simply give a
#' plainer plot. It has three separate effects, one of them silent:
#' - dropping `scale_y_reverse()` flips the diagram vertically, so codes run
#'   bottom-to-top;
#' - dropping `scale_x_continuous(limits = ...)` clips the node label boxes at
#'   the panel edge;
#' - dropping `scale_colour_discrete(aesthetics = c("colour", "fill"),
#'   limits = ...)` de-synchronises the colour and fill palettes, so a link and
#'   its weight label may no longer share a colour. The plot still renders and
#'   still looks plausible; it just no longer means what it did.
#'
#' If you want to restyle only part of `.scale_coord`, copy the default list and
#' edit it rather than replacing it with a shorter one.
#'
#' @inheritParams calc_bigraph_layout
#' @param .geom,.scale_coord,.theme,.other
#'   Customisable lists of ggplot2 components to add to the plot. An empty
#'   `list()` leaves the plot unmodified, except for `.scale_coord` — see
#'   "Removing `.scale_coord`".
#'
#' @return A `ggplot` object.
#' @export (dropped: standalone script)
#'
#' @examplesIf rlang::is_installed(c("ggplot2", "ggforce", "ggrepel"))
#' xm <- as_xmap_tbl(demo$simple_links, xcode, alphacode, weight)
#'
#' gg_diagonal_bigraph(xm)
#'
#' # still composes with `+`
#' gg_diagonal_bigraph(xm) +
#'   ggplot2::theme(legend.position = "right")
#'
#' # drop the weight annotations and the node boxes, keeping only the links
#' layout <- calc_bigraph_layout(xm)
#' gg_diagonal_bigraph(
#'   xm,
#'   .geom = list(
#'     ggforce::geom_diagonal(
#'       data = layout$edges,
#'       ggplot2::aes(
#'         x = 0, y = from_y, xend = 1, yend = to_y,
#'         group = id, alpha = weight, colour = from
#'       )
#'     )
#'   )
#' )
gg_diagonal_bigraph <- function(
  .xmap,
  .geom = list(
    ggforce::geom_diagonal(
      data = .layout$edges,
      ggplot2::aes(
        x = 0,
        y = .data[["from_y"]],
        xend = 0.92,
        yend = .data[["to_y"]],
        group = .data[["id"]],
        linetype = I(.data[["curve_linetype"]]),
        alpha = .data[["weight"]],
        colour = .data[["from"]]
      ),
      linewidth = 0.6,
      n = 100,
      arrow = grid::arrow(
        length = grid::unit(0.15, "cm"),
        type = "closed"
      )
    ),
    ggplot2::geom_label(
      data = .layout$from_nodes,
      ggplot2::aes(x = 0, y = .data[["from_y"]], label = .data[["from"]]),
      linewidth = 0,
      fill = "grey95"
    ),
    ggplot2::geom_label(
      data = .layout$to_nodes,
      ggplot2::aes(x = 1, y = .data[["to_y"]], label = .data[["to"]]),
      linewidth = 0,
      fill = "grey95"
    ),
    ggrepel::geom_label_repel(
      data = .layout$labels,
      ggplot2::aes(
        x = .data[["label_x"]],
        y = .data[["label_y"]],
        label = .data[["weight"]],
        fill = .data[["from"]]
      ),
      size = 3,
      label.size = 0,
      colour = "white",
      seed = 1,
      direction = "x",
      max.overlaps = Inf,
      min.segment.length = 0
    )
  ),
  .scale_coord = list(
    ggplot2::scale_colour_discrete(
      aesthetics = c("colour", "fill"),
      limits = unique(.layout$edges$from)
    ),
    ggplot2::scale_y_reverse(),
    ggplot2::scale_alpha_continuous(range = c(0.4, 1)),
    ggplot2::scale_x_continuous(limits = c(-0.15, 1.15))
  ),
  .theme = list(
    ggplot2::theme_void(),
    ggplot2::theme(legend.position = "none")
  ),
  .other = list()
) {
  rlang::check_installed(
    c("ggplot2", "ggforce", "ggrepel"),
    reason = "to draw an xmap bigraph."
  )

  ## `.layout` is referenced by the defaults of `.geom` and `.scale_coord`,
  ## which are lazily evaluated in this frame, so it must be bound before
  ## those arguments are forced by the `+` chain below.
  .layout <- calc_bigraph_layout(.xmap)

  ggplot2::ggplot() +
    .geom +
    .scale_coord +
    .theme +
    .other
}

# ---- call site ------------------------------------------------------------
xm <- as_xmap_tbl(demo$simple_links, xcode, alphacode, weight)

gg_diagonal_bigraph(xm)

# still composable
gg_diagonal_bigraph(xm) + theme(legend.position = "right")

# prep is reusable without plotting
str(calc_bigraph_layout(xm), max.level = 1)
