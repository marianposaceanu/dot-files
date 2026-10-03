# Maintaining the static site

Use `tutorial_page.html` as the template for article pages in `docs/`. Read these
instructions before editing the site. Page generation and site review are handled
directly by the editor or LLM; there is no site generator or validator script.

## Content and layout

- `docs/*.html` is the single source of truth for published articles and guides.
  Edit the HTML directly; there are no separate Markdown tutorial sources.
- Use `tutorial_page.html` when adding an article. Keep the homepage and standalone
  guides in their existing layouts.
- Choose a lowercase filename that describes the article, using hyphens between
  words. Preserve existing filenames and section IDs when editing published pages
  so external links and bookmarks continue to work.
- Shared styles and behavior live in `docs/assets/site.css`, `dotfiles.css`, and
  `site.js`. Preserve relative asset paths, navigation, accessibility attributes,
  fonts, and footer links from the template.
- Check commands, paths, shortcuts, and behavior against the current first-party
  configuration before describing them. Keep historical measurements tied to
  their recorded versions, hardware, and build modes.

## Article metadata

Use the visible H1 as the title. The introductory subtitle supplies the description
for the meta tag and JSON-LD. Choose a publication date, visible date label,
category, and eyebrow when adding an article; preserve them when editing an
existing page. For example, `2026-08-08` corresponds to `8th August 2026`.

Fill every template placeholder; no `{{...}}` markers may remain in published
HTML:

| Placeholder | Value |
| --- | --- |
| `title` | Article title, used in the document title and H1 |
| `description` | Introductory description, used in the meta tag and subtitle |
| `canonical` | `https://dot.marianposaceanu.com/<slug>.html` |
| `published`, `visible-date` | ISO publication date and its visible label |
| `category`, `eyebrow` | Article category and introductory label |
| `schema` | Article JSON-LD matching the visible metadata |
| `css-hash`, `dotfiles-hash`, `js-hash` | Asset hashes described below |
| `toc` | Links to the article's H2 sections |
| `body` | Article HTML written directly |

Escape text and attributes as HTML, including literal code. Insert `toc` and
`body` as HTML fragments, and `schema` as valid JSON. Escape any literal
`</script>` in JSON string values so it cannot terminate the script element.

## Article structure

- Wrap each H2 section in `<section id="<heading-slug>">`, using the same slug
  rules as filenames. Match the table-of-contents anchors to these IDs; keep them
  unique and in article order. Use H3 for subsections.
- Use semantic paragraphs, lists, blockquotes, emphasis, inline code, and links.
- Use `<pre><code class="language-...">` for code examples with a language label;
  omit the class for unlabeled code. Escape code rather than interpreting it.
- Wrap tables in `<div class="table-scroll">`; include `thead`, `tbody`, and
  header cells.
- For charts, follow an existing chart's `figure`, `bar-row`, `bar-label`,
  `bar-track`, `bar-fill`, and `bar-meta` markup. Preserve the visible values,
  units, comparison labels, and descriptive `aria-label`. Ensure
  `bar-width-<width>` has the corresponding CSS rule in `dotfiles.css`; for
  example, `bar-width-613` means `width: 61.3%`.

## Identity and discovery

Every content page needs one canonical link, an author meta tag for
`Marian Posăceanu`, and one linked byline in its metadata list. Retain the
byline and author URLs from the template.

Article pages contain exactly one JSON-LD object with these fields:

- `@context`: `https://schema.org`
- `@type`: `TechArticle` (`Article` for `m4-low-power-mode-performance.html`)
- `mainEntityOfPage`: `{"@type":"WebPage","@id":"<canonical URL>"}`
- `headline`, `description`, `datePublished`: match the visible page and metadata
- `author`: the existing Person identity, with `@id`
  `https://marianposaceanu.com/#person`, name `Marian Posăceanu`, and URL
  `https://marianposaceanu.com/home/about`

The homepage canonical URL is `https://dot.marianposaceanu.com/`. Preserve its
single WebSite JSON-LD identity, including its name, alternate name, and publisher.

When adding, removing, or renaming a page, update relevant homepage links and
`docs/sitemap.xml`. Include each content page's canonical URL once, in HTML
filename order. Exclude the redirect page `vim-performance.html`; preserve its
redirect behavior.

## Asset hashes and review

Asset query parameters use the first 12 lowercase hexadecimal characters of the
file's SHA-256 digest. Compute them from the actual files:

```sh
shasum -a 256 docs/assets/site.css docs/assets/dotfiles.css docs/assets/site.js
```

Use the first 12 characters of each result for its matching placeholder. When an
asset changes, update that asset's query parameter across the published pages.

Before finishing a site change, review the rendered page in a browser at desktop
and mobile widths. Check links and section anchors, check examples against their
configuration, and verify the metadata, JSON-LD, sitemap, and asset hashes
described above. Keep shared assets free of terminal formatting and refresh their
hashes when they change. Inspect the diff for unintended changes to other pages.

Run `bb bootstrap/checks/check_configs.clj` for repository configuration checks.
That command does not generate or validate site pages. Report the files changed
and the site checks actually performed.
