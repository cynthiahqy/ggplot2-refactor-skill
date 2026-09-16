---
name: refactor-ggplot-helper
description: >-
  Refactor existing ggplot2 code into a transparent, reusable plot helper
  function using the SEPARATE / EXPOSE / DOCUMENT principles. Elicits design
  decisions from the user, proposes a signature, and only applies the refactor
  after approval. Use when the user says "refactor my ggplot code into a
  function", "turn this plot into a reusable function", "wrap this ggplot in a
  helper", "make my ggplot2 code reusable", "write a plot helper function for
  this chart", "help me turn this into a reusable function", "my plot function
  has too many arguments", "how should I expose ggplot2 layers as arguments",
  "design a ggplot2 wrapper", "one function for two similar charts", "these two
  plots are almost the same", or when they mention transparent plot helpers,
  list arguments for ggplot2 components, or .geom / .scale_coord / .theme style
  arguments.
license: MIT
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash
metadata:
  author: Cynthia A. Huang
  version: 0.2.0
compatibility: >-
  Designed for Claude Code, portable to any coding agent. If AskUserQuestion is
  unavailable, present each decision as a numbered plain-text menu and wait for
  a reply. If Write/Edit are unavailable, stop at Step 7 and output the complete
  refactored code in fenced blocks instead of writing files.
---

# Refactor ggplot2 code into a transparent helper

Turn a one-off ggplot2 script into a helper function that is **convenient to
call** but still **transparent**: the user can see what it does, reach into it,
and keep composing with `+`.

Based on three principles from Cynthia Huang's posit::conf(2026) talk:

- **SEPARATE** — data preparation lives in its own functions, not inside the plot function.
- **EXPOSE** — ggplot2 components are list arguments with real defaults, added via `+`.
- **DOCUMENT** — state what is fixed, what is switchable, what is customisable, and how to change each.

## The rule that matters most

> **Never write or edit any file before the user has explicitly approved the
> plan in Step 7.**

This skill's value is the *design conversation*, not the code generation. A user
can get an auto-refactor from any model; what they cannot get elsewhere is being
walked through the two judgement calls that determine whether the helper is
still usable in six months. Do not skip steps even when the refactor looks
obvious. Do not volunteer a finished function early.

## Capability check (do this first, silently)

- `AskUserQuestion` available → use it for every decision point below.
- Not available → present each decision as a numbered list and wait for a reply.
- `Write`/`Edit` unavailable → run Steps 0–7, then output the full code in fenced
  blocks and stop.

---

## Step 0 — Locate the code

If the user named a file, read it. Otherwise `Glob` for `**/*.R`, `**/*.qmd`,
`**/*.Rmd` and ask which file holds the plot. If the plot lives in a Quarto/Rmd
chunk, note the chunk label — the refactor target is usually a new `R/` file, not
an edit in place.

## Step 1 — Inventory the code (no questions yet)

Classify **every** line into six buckets and print it as a table with line
ranges. This table is the shared artifact every later step refers back to.

| Bucket | Lines | What it does |
|---|---|---|
| Data prep | | reshaping, joins, padding, derived variables |
| Structural mapping | | `ggplot(aes(...))` that only makes sense with the prepped data |
| Layers | | `geom_*`, `stat_*` |
| Scales & coords | | `scale_*`, `coord_*` |
| Facets & labs | | `facet_*`, `labs()` |
| Theme & guides | | `theme*`, `guides()` |

If the author has already grouped layers into named `list()` objects, say so —
that is a strong signal about the grouping they already find natural, and you
should reference it in Step 4.

**Then look for sibling charts.** Scan the rest of the file for other plots
built from the same prepared data. If you find one, inventory it too and diff
the two tables — a component that appears in both buckets with different values
is a `switchable` candidate in Step 3, and the whole refactor may serve several
call sites with one helper. Do not assume the code you were pointed at is the
only caller; ask if you are unsure.

## Step 2 — Decision A: what to modularise (SEPARATE)

Do **not** ask an open question. Derive candidates from the inventory:

> A contiguous data-prep block is a candidate helper if it (i) produces a named
> intermediate used later, and (ii) has a describable purpose independent of the
> plot.

Name each candidate verb-first (`expand_events_to_days()`,
`pad_calendar_months()`, `calc_calendar_vars()`).

State the consequence **before** asking:

> Whatever stays inside the plot helper cannot be inspected, tested, or reused
> without producing a plot.

Then ask (multi-select): *"Which data preparation steps should become separate
functions, called by the plot helper?"* — options are the derived candidates,
each described with its line range and what it returns, plus "Keep all prep
inside the plot helper".

If two or more are selected, follow up: export them all, export only the last,
or keep them internal. **Recommend exporting** — documented, exported prep
functions are what make `@inheritParams` work and let users prep data without
plotting.

## Step 3 — Decision B: fixed / switchable / customisable (EXPOSE, part 1)

Sort every plot-side component into one of three kinds. The axis is **how large
the set of valid values is, and who gets to enumerate it** — not "how much
freedom the user has".

| Kind | Valid values | Enumerated by | Argument shape |
|---|---|---|---|
| **fixed** | one | you | none — hard-coded in the body |
| **switchable** | a small, closed set | you | a constrained scalar (`rlang::arg_match()`) |
| **customisable** | open | the user | a list argument with a default, added via `+` |

Pre-recommend as fixed anything that references internally computed columns,
with the reason stated plainly: *"a user who overrode this would get an error,
not a different plot."*

**Before you finalise any `fixed` verdict, apply the switchable test:**

> Does this component need to differ between two calls the user will actually
> make? If yes, it is **switchable**, not fixed — even though it references a
> computed column.

This test matters because the computed-column rule, applied on its own, gives a
confident wrong answer here rather than no answer. A component that references
internal columns *and* must vary per call site is not a candidate for
hard-coding and not a candidate for a free-form list argument either. Getting
this wrong is what makes an author conclude "these need two separate helpers"
when one would do.

Switchable components take a constrained scalar argument, and the helper maps
that scalar onto every coupled piece at once:

```r
gg_tile_shares <- function(.data, measure = c("pct", "any"), ...) {
  measure  <- rlang::arg_match(measure)
  fill_col <- switch(measure, pct = "pct_isiccomb", any = "any_isiccomb")
  # aes(fill = .data[[fill_col]])        the mapping
  # scale_fill_shares(measure)           the matching scale
  # labs(fill = switch(measure, ...))    the matching legend label
}
```

### A mapping and its scale are one unit

When you classify a mapping, classify its scale with it. `aes(fill = x)` and
`scale_fill_*()` are not independently choosable — the type of `x` decides which
scales are legal. A continuous column with `scale_fill_manual(values = c("TRUE" =
..., "FALSE" = ...))` errors; a logical column with `scale_fill_stepsn()` errors.

So exposing the scale alone, without also selecting the column, hands the user
half of a matched pair and lets them construct states that cannot render. If a
mapping is switchable, its scale and its `labs()` entry are switchable too, and
all of them move together on the one scalar. The same applies to `x`/`scale_x_*`
and any other aesthetic whose scale constructor assumes a data type.

### Exposing parameters of fixed components

A component can stay fixed while its **parameters** become ordinary scalar
arguments — `facet_wrap()` fixed, but `nrow`, `ncol` and `labeller` exposed.
This is how you allow the common customisation without re-implementing every
ggplot2 argument. Unlike a switchable argument, these are unconstrained: you are
forwarding a value, not choosing between designs you have validated.

Note the ordering interaction with Step 4: if Decision C puts a component inside
a list argument, its scalars are reachable there already, and exposing them
separately gives two ways to set one value. Flag any scalar whose fate depends
on Decision C and settle it after Step 4 rather than now.

## Step 4 — Decision C: how to group the list arguments (EXPOSE, part 2)

**This is the decision the skill exists to force.** Never ask it abstractly.
Read [references/grouping-patterns.md](references/grouping-patterns.md) first.

1. **Derive a chart-focused proposal from their actual plot** using the recipe in
   that reference — group by what a *reader of the chart* sees, merging across
   geom boundaries where two geoms draw one visual thing.
2. **Show both complete signatures side by side**, defaults spelled out in full.
3. **Ask**: layer-focused / chart-focused / hybrid / other.
4. **State the cost of whatever they chose** — always, not only when you disagree.
5. **Run the removal-semantics check**: for each group, does setting it to
   `list()` degrade sensibly? Flag any group where it silently produces a wrong
   plot rather than a plainer one, and recommend documenting that.

## Step 5 — Decision D: signature details

Batch these into one question round:

- **Return type** — a ggplot object (recommended; `+` keeps working), a list of
  components, a patchwork, or something else.
- **Escape hatch** — include `.other = list()`? Explain the real benefit: it lets
  users inject components at a *controlled position* in the `+` chain, which
  plain `+` cannot do (e.g. `ggiraph` interactive geoms).
- **Name** — propose 2–3 following the `gg_<verb>_<noun>()` convention.

## Step 6 — Documentation scope (DOCUMENT)

Read [references/documentation.md](references/documentation.md). Ask: full
roxygen / roxygen + runnable `@examples` / skeleton only / none.

Recommend full roxygen, and say why: DOCUMENT is one of the three principles, not
an optional extra. A helper whose customisation points are undocumented is not
transparent, however good its signature is.

## Step 7 — Present the plan, then STOP

Output, in this order:

1. **The proposed signature**, one argument per line, defaults spelled out in
   full — show `geom_tile(color = "grey70", fill = "transparent")`, not a
   placeholder. The user must be able to read the actual defaults.
   One exception: a default that depends on another argument cannot be a
   literal (e.g. `.fill_scale = list(scale_fill_shares(measure))`). Write the
   call, and say in a comment that it is resolved from the switchable argument
   — R evaluates default arguments lazily, so this works, but the argument it
   depends on must be bound in the body *before* the default is forced. Say so
   in a source comment; reordering silently breaks it.
2. **The file plan** — new files, which functions in each, what happens to the original.
3. **The complete roxygen block**.
4. **A before/after of every call site** — each messy chain collapsing into one
   call. If the helper is switchable, show each variant being selected.

Then ask: apply it / change a decision (→ ask which step, loop back) / show the
full code without writing / stop here.

**Do not write anything until this question is answered.**

## Step 8 — Apply

Write data-prep helpers first, then the plot helper, then the roxygen. Leave the
original file untouched unless asked otherwise. If the project is an R package
(there is a `DESCRIPTION`), write into `R/` and mention `devtools::document()`.

## Step 9 — Offer feedback

Read [references/feedback.md](references/feedback.md) and emit the closing block
exactly once. Offer, never nag. Then stop.

---

## Reference files

- [references/grouping-patterns.md](references/grouping-patterns.md) — layer- vs chart-focused list arguments, the derivation recipe, and the design tension behind them
- [references/documentation.md](references/documentation.md) — the roxygen template and rules
- [references/feedback.md](references/feedback.md) — feedback URL construction and closing wording

## Worked example

`examples/before-ggtilecal.R` is a real 124-line travel-calendar script with
interleaved data prep and a monolithic ggplot chain.
`examples/after-gg_facet_wrap_months.R` is the real shipped helper it became, in
the [ggtilecal](https://github.com/cynthiahqy/ggtilecal) package. Use them to
check your own output: the "after" file is what a good run of this skill should
converge on when the user picks the layer-focused grouping.
