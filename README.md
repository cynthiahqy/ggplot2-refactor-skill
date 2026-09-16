# ggplot2-refactor-skill

**Refactor your ggplot2 code into a transparent helper function.** The skill asks
you the design questions instead of guessing at the answers: what should become
its own data-prep function, and how should the customisable ggplot2 components be
grouped into arguments. It only writes code once you approve the plan.

Built on three principles — **SEPARATE**, **EXPOSE**, **DOCUMENT** — from the
posit::conf(2026) talk *Reuse your custom ggplot2 with transparent helper
functions!*

> **v0.1, built for posit::conf(2026).** Expect rough edges. Feedback very
> welcome — see [Feedback](#feedback) below.

## What it does

Turns this:

```r
travel_days <- travel_dates |>
  mutate(nights = interval(startDate, endDate) / days(1)) |>
  arrange(startDate, desc(nights)) |>
  # ... 60 more lines of date expansion and calendar layout maths ...

p <- full_calendar |>
  ggplot(aes(x = Day, y = Month_week)) +
  geom_tile(colour = "grey80", fill = "transparent") +
  geom_text(aes(label = mday), nudge_y = 0.25) +
  geom_text(aes(label = flag), nudge_y = -0.25) +
  scale_y_reverse() +
  coord_fixed(expand = TRUE) +
  facet_wrap(vars(Month), ncol = 3) +
  labs(y = NULL, x = NULL) +
  theme_bw() +
  theme(panel.grid.major = element_blank(), ...)
```

into this:

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

The data prep moved into its own documented functions. Every ggplot2 component
is still visible, still replaceable, and `+` still works.

## Install — Claude Code

```
/plugin marketplace add cynthiahqy/ggplot2-refactor-skill
/plugin install ggplot2-refactor@ggplot2-refactor-skill
```

Then open an R file with a plot in it and say:

> refactor this ggplot into a reusable helper function

## Install — other agents (Codex, Cursor, Cline, …)

```
npx skills add https://github.com/cynthiahqy/ggplot2-refactor-skill/tree/main/plugins/ggplot2-refactor/skills/refactor-ggplot-helper --agent codex
```

Swap `--agent` for `claude-code`, `cursor`, `cline`, or omit it to choose
interactively. Uses [vercel-labs/skills](https://github.com/vercel-labs/skills).

## Install — any agent (copy-paste)

The skill is a single markdown file with no dependencies. Open
[`SKILL.md`](plugins/ggplot2-refactor/skills/refactor-ggplot-helper/SKILL.md),
copy it, and paste it into your agent's rules or instructions file. This always
works, whatever tooling you use.

## Feedback

Two ways, both optional:

- **Quick feedback** — [open a feedback issue](https://github.com/cynthiahqy/ggplot2-refactor-skill/issues/new?template=feedback.yml&labels=feedback).
  Note this is a **public** tracker: your GitHub username and comment are visible
  to anyone.
- **The actual study** — [take the survey](https://survey.ifkw.lmu.de/ggplot2_reuse/) on
  how R users turn ggplot2 code into reusable functions. Anonymous, ~5 minutes.

## Related

- [Design Principles for Plot Helper Functions](https://www.cynthiahqy.com/posts/ggplot-helper-design/) — the blog post this is based on
- [ggtilecal](https://github.com/cynthiahqy/ggtilecal) — the calendar package used as the worked example
- [posit::conf(2026) slides](https://cynthiahqy.github.io/positconf2026/)
- [ggplot-extension-club#157](https://github.com/ggplot2-extenders/ggplot-extension-club/discussions/157) — discussion on grouping list arguments

## License

MIT
