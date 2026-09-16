# AFTER (b): chart-focused grouping -- .links / .nodes / .weights / .layout
#
# Decision C took the chart-focused branch: list arguments grouped by what a
# READER OF THE CHART sees, merging across geom boundaries. Note `.links`
# pairs geom_diagonal() with scale_alpha_continuous(), because the alpha
# scale exists only to make edge opacity read as weight -- one visual thing,
# two ggplot2 object types.
#
# Reproduce with:
#   install.packages(c("xmap", "ggforce", "ggrepel"))
library(xmap)
library(dplyr)
library(ggplot2)

# NOTE ON bind_layer_data()
# Same multi-dataset problem as the layer-focused variant, solved differently:
# user-supplied bare geoms are bound to their data and mapping AFTER
# construction. Copying a layer with ggproto(NULL, x) causes a node stack
# overflow; skipping the copy mutates shared state so both node layers bind
# to the same data. Hence the by-hand environment copy.

#' Calculate Node-Link Layout Coordinates for a Crossmap
#'
#' Computes the positions used to draw an `xmap_tbl` as a bipartite node-link
#' diagram, without producing a plot. Source codes are stacked in a left-hand
#' column and target codes in a right-hand column, offset by half a row so the
#' connecting curves read clearly.
#'
#' Returns a named list of four tibbles:
#' - `edges`: one row per link, with `from`, `to`, `weight`, the endpoint
#'   coordinates `from_y` and `to_y`, the flag `is_split` (`weight < 1`), the
#'   derived `curve_linetype` (`"dashed"` for split links, `"solid"` otherwise)
#'   and a unique `id` used to group each curve.
#' - `from_nodes`: distinct source codes with their `from_y` position.
#' - `to_nodes`: distinct target codes with their `to_y` position.
#' - `labels`: the subset of `edges` with `is_split == TRUE`, plus the
#'   annotation positions `label_x` and `label_y`.
#'
#' This function is exported so that the layout maths can be inspected and
#' tested independently of any plotting code. [gg_link_xmap_nodes()] calls it.
#'
#' @param .xmap An `xmap_tbl`, as created by [as_xmap_tbl()].
#'
#' @return A named list of four tibbles: `edges`, `from_nodes`, `to_nodes`,
#'   `labels`.
#'
#' @examples
#' x <- as_xmap_tbl(demo$simple_links, xcode, alphacode, weight)
#' layout <- calc_bigraph_layout(x)
#' layout$from_nodes
#' layout$edges
#'
#' @export
calc_bigraph_layout <- function(.xmap) {
  edges <- tibble::tibble(
    from = .xmap$.from[[1]],
    to = .xmap$.to[[1]],
    weight = .xmap$.weight_by[[1]]
  )

  from_nodes <- dplyr::mutate(
    dplyr::distinct(edges, .data$from),
    from_y = dplyr::row_number()
  )
  to_nodes <- dplyr::mutate(
    dplyr::distinct(edges, .data$to),
    to_y = dplyr::row_number() - 1 + 0.5
  )

  edges <- dplyr::mutate(
    dplyr::left_join(
      dplyr::left_join(edges, from_nodes, by = "from"),
      to_nodes,
      by = "to"
    ),
    is_split = .data$weight < 1,
    curve_linetype = ifelse(.data$is_split, "dashed", "solid"),
    id = dplyr::row_number()
  )

  labels <- dplyr::mutate(
    dplyr::filter(edges, .data$is_split),
    label_x = 0.5,
    label_y = (.data$from_y + .data$to_y) / 2
  )

  list(
    edges = edges,
    from_nodes = from_nodes,
    to_nodes = to_nodes,
    labels = labels
  )
}

#' Draw a Crossmap as a Bipartite Node-Link Diagram
#'
#' Draws the `.from -> .to` structure of an `xmap_tbl` as a node-link diagram by:
#' - Calculating node positions and edge endpoints via [calc_bigraph_layout()]
#' - Returning a ggplot object as per Details.
#'
#' @details
#' Returns a ggplot with the following **fixed** components, which use the
#' calculated layout variables and therefore cannot be supplied by the caller:
#' - `aes()` mapping for the links: `x` is 0, `y` is `from_y`, `xend` is
#'   `1 - arrow_gap`, `yend` is `to_y`, `group` is `id`, `linetype` is
#'   `curve_linetype`, `alpha` is `weight`, `colour` is `from`
#' - `aes()` mapping for the node boxes: `x` is 0 (source) or 1 (target),
#'   `y` is `from_y` or `to_y`, `label` is the code
#' - `aes()` mapping for the weight annotations: `x` is `label_x`, `y` is
#'   `label_y`, `label` is `weight`, `fill` is `from`
#' - `scale_colour_discrete(aesthetics = c("colour", "fill"))`, whose `limits`
#'   are the source codes in appearance order
#'
#' and default **customisable** components:
#' - `.links`: `ggforce::geom_diagonal()` for the connecting curves, with a
#'   closed arrowhead, plus `scale_alpha_continuous(range = c(0.4, 1))` so that
#'   lighter curves read as smaller weights
#' - `.nodes`: `geom_label()` for the code boxes. This single layer
#'   specification is applied twice, once to the source column and once to the
#'   target column
#' - `.weights`: `ggrepel::geom_label_repel()` labelling the weight of every
#'   split link
#' - `.layout`: `scale_y_reverse()` to read top-to-bottom in `.xmap` row order,
#'   and `scale_x_continuous(limits = c(-0.15, 1.15))` to leave room for the
#'   node boxes
#' - `.theme`: `theme_void()` and `theme(legend.position = "none")`
#'
#' To modify components, replace the corresponding list argument; layers you
#' supply inherit the fixed mapping and data described above, so construct them
#' without `data` or `mapping`. To add components, use the ggplot2 `+` function
#' as normal, or pass them to `.other` when you need them inserted at a
#' controlled position in the `+` chain (for example `ggiraph` interactive
#' geoms). To remove any optional component, set its argument to an empty
#' `list()`.
#'
#' **One removal is not safe.** Setting `.layout = list()` drops
#' `scale_y_reverse()`, which silently flips the node order bottom-to-top so the
#' diagram no longer matches `.xmap` row order, and drops the expanded x limits,
#' which clips the outer node labels. Prefer replacing `.layout` over emptying
#' it.
#'
#' @param .xmap An `xmap_tbl`, as created by [as_xmap_tbl()].
#' @param arrow_gap Numeric. Horizontal gap left between the arrowhead and the
#'   target node box, so the head sits beside the label rather than underneath
#'   it. Defaults to `0.08`.
#' @param node_fill Fill colour for the source and target node boxes. Defaults
#'   to `"grey95"`.
#' @param weight_label_size Text size for the weight annotations on split links.
#'   Defaults to `3`.
#' @param seed Random seed passed to `ggrepel::geom_label_repel()` so that the
#'   annotation placement is reproducible. Defaults to `1`.
#' @param .links,.nodes,.weights,.layout,.theme,.other
#'   Customisable lists of ggplot2 components to add to the plot.
#'   An empty `list()` leaves the plot unmodified, except for `.layout` -- see
#'   Details.
#'
#' @return A ggplot object.
#'
#' @seealso [calc_bigraph_layout()] for the layout maths on its own.
#'
#' @examplesIf rlang::is_installed(c("ggplot2", "ggforce", "ggrepel"))
#' x <- as_xmap_tbl(demo$simple_links, xcode, alphacode, weight)
#'
#' # default diagram
#' gg_link_xmap_nodes(x)
#'
#' # customise one visual element, and keep composing with `+`
#' gg_link_xmap_nodes(x, node_fill = "white", .weights = list()) +
#'   ggplot2::theme(legend.position = "right")
#'
#' @export (dropped: standalone script)
gg_link_xmap_nodes <- function(.xmap,
                               arrow_gap = 0.08,
                               node_fill = "grey95",
                               weight_label_size = 3,
                               seed = 1,
                               .links = list(
                                 ggforce::geom_diagonal(
                                   linewidth = 0.6,
                                   n = 100,
                                   arrow = grid::arrow(
                                     length = grid::unit(0.15, "cm"),
                                     type = "closed"
                                   )
                                 ),
                                 ggplot2::scale_alpha_continuous(
                                   range = c(0.4, 1)
                                 )
                               ),
                               .nodes = list(
                                 ggplot2::geom_label(
                                   linewidth = 0,
                                   fill = node_fill
                                 )
                               ),
                               .weights = list(
                                 ggrepel::geom_label_repel(
                                   size = weight_label_size,
                                   label.size = 0,
                                   colour = "white",
                                   seed = seed,
                                   direction = "x",
                                   max.overlaps = Inf,
                                   min.segment.length = 0
                                 )
                               ),
                               .layout = list(
                                 ggplot2::scale_y_reverse(),
                                 ggplot2::scale_x_continuous(
                                   limits = c(-0.15, 1.15)
                                 )
                               ),
                               .theme = list(
                                 ggplot2::theme_void(),
                                 ggplot2::theme(legend.position = "none")
                               ),
                               .other = list()) {
  rlang::check_installed(c("ggplot2", "ggforce", "ggrepel"))

  layout <- calc_bigraph_layout(.xmap)
  xend_pos <- 1 - arrow_gap

  link_aes <- ggplot2::aes(
    x = 0,
    y = .data$from_y,
    xend = .env$xend_pos,
    yend = .data$to_y,
    group = .data$id,
    linetype = I(.data$curve_linetype),
    alpha = .data$weight,
    colour = .data$from
  )
  from_aes <- ggplot2::aes(x = 0, y = .data$from_y, label = .data$from)
  to_aes <- ggplot2::aes(x = 1, y = .data$to_y, label = .data$to)
  weight_aes <- ggplot2::aes(
    x = .data$label_x,
    y = .data$label_y,
    label = .data$weight,
    fill = .data$from
  )

  ggplot2::ggplot() +
    bind_layer_data(.links, layout$edges, link_aes) +
    bind_layer_data(.nodes, layout$from_nodes, from_aes) +
    bind_layer_data(.nodes, layout$to_nodes, to_aes) +
    bind_layer_data(.weights, layout$labels, weight_aes) +
    ggplot2::scale_colour_discrete(
      aesthetics = c("colour", "fill"),
      limits = unique(layout$edges$from)
    ) +
    .layout +
    .theme +
    .other
}

#' Attach fixed data and mapping to the layers in a component list
#'
#' Elements that are not ggplot2 layers (scales, for example) are passed through
#' untouched, so a chart-focused list argument may mix a geom with the scale
#' that gives it meaning.
#'
#' @param components A list of ggplot2 components.
#' @param data A data frame to bind to each layer.
#' @param mapping An `aes()` mapping to bind to each layer.
#'
#' @return A list of ggplot2 components.
#' @noRd
bind_layer_data <- function(components, data, mapping) {
  lapply(components, function(x) {
    if (inherits(x, "LayerInstance") || inherits(x, "Layer")) {
      # layers are ggproto environments, so copy before mutating -- otherwise
      # reusing one list argument for two node columns would rebind both.
      # ggproto(NULL, x) is not usable here: it builds a self-referential
      # `super` chain and overflows the node stack on lookup.
      copy <- list2env(
        as.list.environment(x, all.names = TRUE),
        parent = parent.env(x)
      )
      attributes(copy) <- attributes(x)
      x <- copy
      x$data <- data
      x$mapping <- mapping
    }
    x
  })
}

# ---- call site ------------------------------------------------------------
xm <- as_xmap_tbl(demo$simple_links, xcode, alphacode, weight)

gg_link_xmap_nodes(xm)

# a scalar exposed off a fixed component
gg_link_xmap_nodes(xm, node_fill = "lightblue")

# a bare geom acquires data + mapping via bind_layer_data()
gg_link_xmap_nodes(xm, .links = list(ggforce::geom_diagonal(linewidth = 2)))
