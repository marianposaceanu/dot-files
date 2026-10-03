# Maintaining the static site

Use `tutorial_page.html` as the template for article pages in `docs/`. Read these
instructions before editing the site. Page generation and site review are handled
directly by the editor or LLM; there is no site generator or validator script.

## Sources and outputs

- Tutorial content lives in `tutorials/*.md`. Keep the Markdown and corresponding
  `docs/<slug>.html` page in sync in the same change.
- Derive the slug from the Markdown filename without `.md`: lowercase it, replace
  runs of characters outside `a-z` and `0-9` with `-`, and trim surrounding `-`.
- Some pages have no Markdown source, including the homepage and standalone
  guides. Edit those HTML files directly, retaining their existing layout.
- Shared styles and behavior live in `docs/assets/site.css`, `dotfiles.css`, and
  `site.js`. Preserve relative asset paths, navigation, accessibility attributes,
  fonts, and footer links from the template.

## Article metadata

The first Markdown H1 supplies the title. The opening paragraph supplies the
description. Optional front matter appears before the H1:

```yaml
---
published: 2026-08-08
visible-date: 8th August 2026
category: Shell tutorial
eyebrow: Zsh navigation · frecency · fzf
---
```

Use explicit metadata when adding a new article. When updating an existing page,
preserve its publication date and metadata unless the content change calls for
an intentional update. Historical tutorials without front matter use
`2026-07-20`, `20th July 2026`, `Vim tutorial`, and
`Vim field guide · dot-files`, respectively.

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
| `body` | Article HTML rendered from the Markdown |

Escape text and attributes as HTML, including literal code. Insert `toc` and
`body` as HTML fragments, and `schema` as valid JSON. Escape any literal
`</script>` in JSON string values so it cannot terminate the script element.

## Article structure

- Wrap each H2 section in `<section id="<heading-slug>">`, using the same slug
  rules as filenames. Match the table-of-contents anchors to these IDs; keep them
  unique and in article order. Use H3 for subsections.
- Preserve paragraphs, lists, blockquotes, bold text, inline code, and links.
- Use `<pre><code class="language-...">` for fenced code with a language label;
  omit the class for unlabeled code. Escape code rather than interpreting it.
- Wrap tables in `<div class="table-scroll">`; include `thead`, `tbody`, and
  header cells.
- A fenced `chart` block contains a title followed by rows in the form
  `label | value | width | meta`. Width is an integer from 0 to 1000, measured in
  tenths of a percent. Follow an existing chart's `figure`, `bar-row`, `bar-label`,
  `bar-track`, `bar-fill`, and `bar-meta` markup. Provide its descriptive
  `aria-label`. Ensure `bar-width-<width>` has the corresponding CSS rule in
  `dotfiles.css`; for example, `bar-width-613` means `width: 61.3%`.

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

Before finishing a site change, review the rendered page in a browser, check
links and section anchors, compare it with its Markdown source, and verify the
metadata, JSON-LD, sitemap, and asset hashes described above. Inspect the diff
for unintended changes to other pages.

Run `bb bootstrap/checks/check_configs.clj` for repository configuration checks.
That command does not generate or validate site pages. Report the files changed
and the site checks actually performed.
