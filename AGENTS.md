# AGENTS.md: Dziennik GuestSage

Instructions for coding agents (ChatGPT Codex and others) working on this repository. Read this before changing anything.

## What this is

A private work panel for one hotel-group employee (Great Polonia in Poland, Great Greece in Greece) and a few colleagues. It is used daily, mostly on an iPhone. It tracks:

- **Zgłoszenia**: entries of two kinds: GuestSage faults (`kind = 'usterka'`, reported to the GuestSage software vendor) and notes / to-dos (`kind = 'zadanie'`).
- **Kalendarz**: month calendar of those entries.
- **Dziennik**: a daily work log.
- **Obiekty**: the group's hotels, with a page per hotel listing its entries.
- **Dowody**: evidence (screenshots, videos, PDFs) attached to entries.
- **Prowizje**: commission rows (reservation ID, stay dates, full price, %, total) with a PDF export.

Everything in the user interface is **Polish**. Keep it Polish, short and plain.

Live: https://luq4s13-sys.github.io/dziennik-guestsage/

## Hard constraints

1. **Cost must stay 0 zł per month.** Free tiers only: GitHub Pages, Supabase free plan, public CDNs. Do not add paid APIs, servers, or anything that needs a credit card.
2. **This repository is public.** Never commit personal data: e-mail addresses, photos of people, real reservation data, tokens. The Supabase **publishable** key in `config.js` is public by design. Never add a `service_role` / secret key anywhere.
3. **Data stays private.** Every table uses Row Level Security so a user sees only their own rows. Do not weaken policies. The login-screen photo lives only in `settings.login_photo` (per user) and is cached in that browser's `localStorage`; it must never be a file in this repo (`lucas.jpg` is git-ignored on purpose).
4. **Database changes come before code.** The app loads every table on start-up. If the code reads or writes a column that does not exist yet, loading or saving breaks for the user. So for any schema change:
   - write an idempotent SQL file in `supabase/migrations/` (use `add column if not exists`, etc.) and update `supabase/schema.sql`;
   - tell the owner to run it in the Supabase dashboard (SQL Editor) **and confirm it ran** before the code is merged to `main`;
   - you can check from outside whether a column exists: `GET https://jxconcdojhispfsooshq.supabase.co/rest/v1/<table>?select=<cols>&limit=1` with header `apikey: <publishable key from config.js>`. Error code `42501` (permission denied) means all columns exist; `42703` means a column is missing.
5. **Pushing to `main` deploys.** GitHub Pages serves the repo root of `main`. A merge goes live in 1 to 5 minutes. Work on a branch / pull request and keep `main` deployable.

## Stack and files

No build step, no framework, no package.json. Plain HTML, CSS and JavaScript.

| Path | Purpose |
|---|---|
| `index.html` | The whole app: markup and one inline `<script>` (about 2,400 lines). |
| `style.css` | All styles ("cyberpunk" look, night and day themes). Referenced as `style.css?v=N`; **bump N on every CSS change** so phones do not keep the old file. |
| `config.js` | Supabase URL + publishable key (public). |
| `manifest.webmanifest`, `icon-*.png` | Home-screen app (iPhone "Add to Home Screen"). |
| `gp-logo.svg` | Great Polonia logo (login screen and header). |
| `fonts/` | DejaVu Sans (regular and bold) used only by the PDF export, for Polish letters. Loaded lazily. |
| `.github/workflows/keepalive.yml` | Pings Supabase every 3 days; the free plan pauses a project after 7 idle days. |
| `supabase/schema.sql` | Full schema with RLS policies (idempotent). |
| `supabase/migrations/` | Changes applied after the first deploy, in date order. |
| `tools/` | Local test harness (mock Supabase + static server). |

External scripts (all free CDNs): `@supabase/supabase-js@2.116.0` (jsDelivr), `jspdf 2.5.1` (cdnjs, loaded only for PDF), `tesseract.js@5.1.1` (jsDelivr, loaded only when a screenshot is read; downloads Polish + English language data on first use), Google Fonts (Chakra Petch, Exo 2, JetBrains Mono).

## Data model (Supabase, project `jxconcdojhispfsooshq`)

Database columns are `snake_case`; the app converts them to `camelCase` (`toRow` / `fromRow` in the data layer). All tables have `user_id uuid default auth.uid()` and an "own rows" policy for `authenticated`; `anon` has no grants.

- `tickets`: `num`, `title`, `company` (`GP` | `GG` | `ALL`), `module`, `priority`, `sent_at` (date), `channel`, `gs_ref` (GuestSage ticket number), `status`, `description`, `impact`, `events` (jsonb array of `{id, at, kind, text}`; history), `properties` (jsonb array of object ids), `kind` (`usterka` | `zadanie`), `due_date` (date, calendar day), timestamps.
- `journal`: `date`, `company`, `text`.
- `evidence`: `title`, `date`, `company`, `ticket_id` (nullable, on delete set null), `description`, `files` (jsonb array of `{id: storage path, name, type, size}`), `properties`.
- `commissions`: `reservation_id`, `stay_from`, `stay_to`, `price`, `rate`, `amount` (price * rate / 100, rounded to grosze), `property`.
- `settings` (one row per user): `threshold` (days of silence before "Bez odpowiedzi"), `stale_days`, `login_photo` (data URL, max 400 kB), `commission_name` (name printed on the commission PDF).
- Storage bucket `dowody` (private, 50 MB per file). Paths are `<user_id>/<uuid>.<ext>`; the app shows files through signed URLs.

Statuses (`tickets.status`): `wyslane`, `w_realizacji`, `czeka_na_mnie`, `naprawione`, `odrzucone`, `zamkniete`. They are grouped for the counters: **Aktywne** = `wyslane`; **W trakcie** = `w_realizacji` + `czeka_na_mnie`; **Zakończone** = the rest. Notes (`kind = 'zadanie'`) show `TASK_STATUS` labels (Do zrobienia / W trakcie / Zrobione), never get the "Cisza" (no reply) badge and are excluded from GuestSage statistics (`isFault`).

## Code map (`index.html`, search for the `/* ---------- name ---------- */` banners)

- **constants**: `STATUSES`, `GROUPS`, `PROPERTIES` (the 19 hotels with a `re` regex used to detect a hotel in free text), `propsOf` / `coOf` (saved objects win; otherwise detected from the text; Great Greece = Le Convivial), `VIEWS` (tabs).
- **state**: the single `S` object (data arrays, filters, current view).
- **Supabase data layer**: `DB.fetchAll / insert / update / remove / saveSettings`, `loadAll`, file storage (`Files`, signed-URL cache `patchUrls`).
- **ticket logic**: `silence` (days without a reply), `isStale`, `gsStats`, `ticketRow`, `quickActions`, `boardHTML`.
- **views**: one `render*` function per tab, collected in `RENDER`. `render()` re-renders the current tab on every state change. `withPreserved` keeps input values and focus across re-renders; `S.enter` triggers the entrance animation; `S.listAnim` animates a list after a filter change.
- **calendar**, **commissions** (+ PDF via jsPDF, iOS share sheet in `deliverPdf`), **dialog** (`dlgOpen` / `dlgClose`; closing is animated for about 170 ms and the `close` event ignores a dialog that was re-opened meanwhile), **screen transitions** (`fxPlay` runs a callback while the screen is covered; `decrypt` scrambles a heading in).
- **quick add**: the one-field "+ Zgłoszenie" dialog. Kind and date pickers, optional screenshot: `qtImage` reads text with Tesseract in the browser, `attachShot` saves the image as evidence.
- **ticket from a pasted e-mail**: `parseEmail` (headers, dates in Polish or English, GuestSage number, quoted-thread cut) and `matchTicket` (finds the existing entry a reply belongs to).
- **events**: one delegated `click` handler driven by `data-action`, plus `submit` (`data-form`), `change` (`data-change`), `input` (`data-input`), paste, drag-and-drop.
- **auth**, **login screen** (flying photo and Macarena via an official YouTube embed; the audio is never re-hosted), **theme** (auto / light / dark, stored in `localStorage`).

## Conventions

- Escape every user-provided string with `esc()` before putting it into HTML.
- New UI: reuse the CSS tokens in `style.css` (`--bg`, `--surface`, `--ink`, `--gold`, `--hot`, …), cut-corner shapes and existing components (`.panel`, `.btn`, `.seg`, `.trow`, `.chip`, `.pill`). Both themes must stay readable.
- Mobile first: test at 375 px and 402 px width (iPhone). The page body must never scroll horizontally. Inputs use 16 px text on phones, so iOS does not zoom in.
- Respect `prefers-reduced-motion`: CSS already disables animations; JS effects check `reducedMotion()`.
- Polish plural forms: use `plural(n, one, few, many)`. Money: `money()` gives `4 243,50 zł`. Dates: `fmtDate`, `fmtLong`.
- Keep comments sparse and only where the reason is not obvious.
- Line endings: Git on the owner's Windows machine converts to CRLF; do not reformat whole files.

## Testing

There are no automated tests in CI. Before every pull request:

1. Syntax check of the inline script:
   `node tools/check-syntax.js` (extracts the `<script>` block from `index.html` and runs `node --check`).
2. Run the app against the in-memory mock:
   `node tools/make-test-copy.js` (writes `test-build/` with `index.html` using `tools/mock-supabase.js` instead of the real Supabase), then `node tools/serve.js test-build 5179` and open http://localhost:5179/.
   Log in with any e-mail and the password `test1234`. Data lives in `window.__mockdb` and resets on reload. The mock covers tables, `upsert`, storage upload / signed URLs and auth.
3. Click through the tab you changed on a 375 px wide window, in both themes, and check the browser console for errors.
4. If you touched the schema, follow constraint 4 above.

The real database can be verified only by the owner (or with the owner logged in), because nobody else has a password. A safe pattern the owner can run in the SQL Editor: a `do $$ … $$` block that sets `request.jwt.claims` / `role` to a user, performs writes, checks isolation against a second user and ends with `raise exception` so every change is rolled back.

## Known open points

- The "Cisza" badge starts counting from the day a fault is added, even if it was not yet sent to GuestSage. The owner may want it to start only once the entry is marked as sent.
- The hotel list in `PROPERTIES` was taken from greatpolonia.pl and greatgreecehotels.gr in November 2026 (Camp & Travel, a caravan rental, was left out). Update it if the group changes.
- The Great Polonia logo is in this public repo; the owner was asked to confirm the company is fine with that.
