# Feedback (Step 9)

Offer once, briefly, at the very end. Never nag, never repeat it mid-run, and
never make it a condition of finishing.

## The closing block

Emit this, with `<url>` replaced by the constructed link:

> **Was this useful?** Two optional things, both quick:
>
> - One-click feedback (30 seconds, prefilled): `<url>`
>   — note this opens a **public** GitHub issue under your username.
> - The study on how R users reuse ggplot2 code (anonymous, ~5 min):
>   https://www.cynthiahqy.com/survey
>
> Either way — thanks for trying this.

Both are genuinely optional. The survey is the real research instrument; the
issue is a lightweight usage signal.

## Constructing the URL

Base:

```
https://github.com/cynthiahqy/ggplot2-refactor-skill/issues/new?template=feedback.yml&labels=feedback&title=%5Bfeedback%5D+<helper-name>
```

Optionally append prefills for the form's own fields, using the field `id` as the
query key:

```
&helper_name=<what-they-refactored>&grouping=<exact-option-string>
```

## Rules — this is where agents get it wrong

- **`template`, `labels` and `title` are documented and reliable.** Always use these.
- **Field-level prefill (`helper_name`, `grouping`, …) is best-effort.** GitHub
  documents that form fields can be prefilled but does not publish the syntax. If
  a value doesn't match, the field simply renders blank — it fails silently
  rather than erroring. Never depend on it.
- **Dropdown prefills must match the option string exactly**, URL-encoded. A near
  miss leaves the dropdown empty.
- Encode spaces as `+` or `%20`; `[` and `]` as `%5B` / `%5D`; `(` and `)` as
  `%28` / `%29`.
- **Never prefill `notes`.** That field is the user's own voice.
- Emit the URL **bare, on its own line**. Do not hide it behind markdown link
  text — the user should see they are being sent to github.com before clicking.
- Keep the URL short. Very long URLs return `414 URI Too Long`.

## What not to do

- Do not collect answers yourself and post an issue on the user's behalf.
- Do not ask the survey's questions inside the chat. The survey is consented and
  anonymous; this channel is neither. Link to it, don't reimplement it.
- Do not imply the issue is anonymous or that it is research participation.
