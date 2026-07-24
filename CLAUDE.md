# Project notes

## Copywriting

**Never use em dashes (—) or en dashes (–) in user-facing copy.** That means any
string the user can read: button labels, dialogs, banners, hint text, error
messages, seeded sample data.

Use a colon, a comma, or a full stop instead, whichever reads naturally:

- "Heaviest ever on Bench Press: 225 lbs"
- "Shoulders a bit tight, used closer grip on OHP."
- "Tap Finish instead. A half-done workout still logs."

Hyphens are fine where they belong (pull-ups, half-done, 3-5 reps).

## Icons and symbols

**Never put raw emoji in the UI** (no 🏆, no 💪, no ✅). They render differently
on every platform, ignore the theme, don't scale with text, and look pasted on.

Use `Icons.*` from Material, tinted with a `colorScheme` role, so the symbol
picks up light and dark mode like everything else. If the app truly needs a mark
Material doesn't have, add a proper asset rather than a character in a string.
