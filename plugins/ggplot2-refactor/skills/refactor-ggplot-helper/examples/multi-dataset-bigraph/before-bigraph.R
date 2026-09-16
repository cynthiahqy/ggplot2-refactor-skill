# BEFORE: a one-off multi-dataset ggplot2 chain
#
# A node-link (bipartite graph) view of an xmap crossmap: source codes in a
# left-hand column, target codes on the right, one arrow per link. Dashed
# arrows are fractional splits, labelled with their weight.
#
# Reproduce with:
#   install.packages(c("xmap", "ggforce", "ggrepel"))
library(xmap)
library(dplyr)
library(ggplot2)

xm <- as_xmap_tbl(demo$simple_links, xcode, alphacode, weight)

# ---- the code to refactor -------------------------------------------------
# Note what makes this different from `before-ggtilecal.R`:
#   * `ggplot()` is EMPTY -- there is no top-level data or mapping
#   * four separate datasets (edges, from_nodes, to_nodes, labels)
#   * four separate `aes()` blocks, each with its own `data =`
# Nothing inherits. See README.md for why that matters.

plot_xmap_bigraph <- function(.xmap) {
  edges <- tibble::tibble(
    from = .xmap$.from[[1]],
    to = .xmap$.to[[1]],
    weight = .xmap$.weight_by[[1]]
  )

  from_nodes <- distinct(edges, from) |> mutate(from_y = row_number())
  to_nodes <- distinct(edges, to) |> mutate(to_y = row_number() - 1 + 0.5)

  edges <- edges |>
    left_join(from_nodes, by = "from") |>
    left_join(to_nodes, by = "to") |>
    mutate(
      is_split = weight < 1,
      curve_linetype = ifelse(is_split, "dashed", "solid"),
      id = row_number()
    )

  labels <- edges |>
    filter(is_split) |>
    mutate(label_x = 0.5, label_y = (from_y + to_y) / 2)

  ggplot2::ggplot() +
    ggforce::geom_diagonal(
      data = edges,
      ggplot2::aes(
        # stop short of x = 1 so the arrowhead sits beside the .to label
        # rather than underneath it
        x = 0,
        y = from_y,
        xend = 0.92,
        yend = to_y,
        group = id,
        linetype = I(curve_linetype),
        alpha = weight,
        colour = from
      ),
      linewidth = 0.6,
      n = 100,
      arrow = grid::arrow(
        length = grid::unit(0.15, "cm"),
        type = "closed"
      )
    ) +
    ggplot2::geom_label(
      data = from_nodes,
      ggplot2::aes(x = 0, y = from_y, label = from),
      linewidth = 0,
      fill = "grey95"
    ) +
    ggplot2::geom_label(
      data = to_nodes,
      ggplot2::aes(x = 1, y = to_y, label = to),
      linewidth = 0,
      fill = "grey95"
    ) +
    ggrepel::geom_label_repel(
      data = labels,
      ggplot2::aes(x = label_x, y = label_y, label = weight, fill = from),
      size = 3,
      label.size = 0,
      colour = "white",
      seed = 1,
      direction = "x",
      max.overlaps = Inf,
      min.segment.length = 0
    ) +
    ggplot2::scale_colour_discrete(
      aesthetics = c("colour", "fill"),
      limits = unique(edges$from)
    ) +
    ggplot2::scale_y_reverse() +
    ggplot2::scale_alpha_continuous(range = c(0.4, 1)) +
    ggplot2::scale_x_continuous(limits = c(-0.15, 1.15)) +
    ggplot2::theme_void() +
    ggplot2::theme(legend.position = "none")
}

# ---- call site ------------------------------------------------------------
plot_xmap_bigraph(xm)
