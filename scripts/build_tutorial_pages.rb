#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "digest"
require "fileutils"
require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
SOURCE_DIR = ROOT.join("tutorials")
OUTPUT_DIR = ROOT.join("docs")
PUBLISHED_DATE = "2026-07-20"
VISIBLE_DATE = "20th July 2026"

def slug(text)
  text.downcase
    .gsub(/[^a-z0-9]+/, "-")
    .gsub(/\A-| -?\z/, "")
    .sub(/-\z/, "")
end

def inline(text)
  tokens = []
  tokenized = text.gsub(/`([^`\n]+)`/) do
    token = "INLINECODE#{tokens.length}TOKEN"
    tokens << "<code>#{CGI.escapeHTML(Regexp.last_match(1))}</code>"
    token
  end

  tokenized = tokenized.gsub(/\[([^\]]+)\]\(([^)]+)\)/) do
    token = "INLINELINK#{tokens.length}TOKEN"
    label = CGI.escapeHTML(Regexp.last_match(1))
    href = CGI.escapeHTML(Regexp.last_match(2))
    tokens << %(<a href="#{href}">#{label}</a>)
    token
  end

  html = CGI.escapeHTML(tokenized)
    .gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>')

  tokens.each_with_index do |value, index|
    html = html.gsub("INLINECODE#{index}TOKEN", value)
      .gsub("INLINELINK#{index}TOKEN", value)
  end
  html
end

def table_separator?(line)
  cells = line.strip.delete_prefix("|").delete_suffix("|").split("|")
  !cells.empty? && cells.all? { |cell| cell.strip.match?(/\A:?-{3,}:?\z/) }
end

def table_cells(line)
  line.strip.delete_prefix("|").delete_suffix("|").split("|").map(&:strip)
end

def structural_line?(lines, index)
  line = lines[index]
  stripped = line.strip
  return true if stripped.empty? || stripped == "---"
  return true if stripped.start_with?("#", "```", "> ")
  return true if stripped.match?(/\A[-*] /) || stripped.match?(/\A\d+\. /)
  return true if stripped.start_with?("|") && lines[index + 1] && table_separator?(lines[index + 1])

  false
end

def render_markdown(lines)
  output = []
  sections_open = 0
  index = 0

  while index < lines.length
    line = lines[index]
    stripped = line.strip

    if stripped.empty? || stripped == "---"
      index += 1
      next
    end

    if stripped.start_with?("## ")
      output << "      </section>" if sections_open.positive?
      heading = stripped.delete_prefix("## ")
      output << %(      <section id="#{slug(heading)}">)
      output << "        <h2>#{inline(heading)}</h2>"
      sections_open += 1
      index += 1
      next
    end

    if stripped.start_with?("### ")
      output << "        <h3>#{inline(stripped.delete_prefix("### "))}</h3>"
      index += 1
      next
    end

    if stripped.start_with?("```")
      language = stripped.delete_prefix("```").strip
      code = []
      index += 1
      while index < lines.length && !lines[index].strip.start_with?("```")
        code << lines[index]
        index += 1
      end
      index += 1
      class_name = language.empty? ? "" : %( class="language-#{CGI.escapeHTML(language)}")
      output << "        <pre><code#{class_name}>#{CGI.escapeHTML(code.join("\n"))}</code></pre>"
      next
    end

    if stripped.start_with?("|") && lines[index + 1] && table_separator?(lines[index + 1])
      header = table_cells(line)
      rows = []
      index += 2
      while index < lines.length && lines[index].strip.start_with?("|")
        rows << table_cells(lines[index])
        index += 1
      end
      output << "        <div class=\"table-scroll\">"
      output << "          <table>"
      output << "            <thead><tr>#{header.map { |cell| "<th>#{inline(cell)}</th>" }.join}</tr></thead>"
      output << "            <tbody>"
      rows.each do |row|
        output << "              <tr>#{row.map { |cell| "<td>#{inline(cell)}</td>" }.join}</tr>"
      end
      output << "            </tbody>"
      output << "          </table>"
      output << "        </div>"
      next
    end

    if stripped.match?(/\A[-*] /)
      items = []
      while index < lines.length && lines[index].strip.match?(/\A[-*] /)
        items << lines[index].strip.sub(/\A[-*] /, "")
        index += 1
      end
      output << "        <ul>"
      items.each { |item| output << "          <li>#{inline(item)}</li>" }
      output << "        </ul>"
      next
    end

    if stripped.match?(/\A\d+\. /)
      items = []
      while index < lines.length && lines[index].strip.match?(/\A\d+\. /)
        items << lines[index].strip.sub(/\A\d+\. /, "")
        index += 1
      end
      output << "        <ol>"
      items.each { |item| output << "          <li>#{inline(item)}</li>" }
      output << "        </ol>"
      next
    end

    if stripped.start_with?("> ")
      quote = []
      while index < lines.length && lines[index].strip.start_with?("> ")
        quote << lines[index].strip.delete_prefix("> ")
        index += 1
      end
      output << "        <blockquote><p>#{inline(quote.join(" "))}</p></blockquote>"
      next
    end

    paragraph = [stripped]
    index += 1
    while index < lines.length && !structural_line?(lines, index)
      paragraph << lines[index].strip
      index += 1
    end
    output << "        <p>#{inline(paragraph.join(" "))}</p>"
  end

  output << "      </section>" if sections_open.positive?
  output.join("\n")
end

def page_for(path, css_hash, dotfiles_hash)
  lines = path.read(encoding: "UTF-8").lines(chomp: true)
  title = lines.first.to_s.delete_prefix("# ").strip
  abort "Missing H1 in #{path}" if title.empty?

  intro_lines = []
  index = 1
  index += 1 while lines[index]&.strip == ""
  while lines[index] && !["", "---"].include?(lines[index].strip)
    intro_lines << lines[index].strip
    index += 1
  end
  description = intro_lines.join(" ")
  body_lines = lines[(index + 1)..] || []
  headings = body_lines.filter_map do |line|
    line.strip.delete_prefix("## ") if line.strip.start_with?("## ")
  end
  filename = "#{slug(path.basename(".md").to_s)}.html"

  <<~HTML
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>#{CGI.escapeHTML(title)} - dot-files</title>
      <meta name="description" content="#{CGI.escapeHTML(description)}">
      <meta name="author" content="Marian Posaceanu">
      <meta name="robots" content="index, follow">
      <link rel="canonical" href="https://dot.marianposaceanu.com/#{filename}">
      <link rel="preload" href="fonts/lora-v24-latin-ext_latin-regular.woff2" as="font" type="font/woff2" crossorigin>
      <link rel="preload" href="fonts/Fira_Sans_500.woff2" as="font" type="font/woff2" crossorigin>
      <link rel="icon" href="favicon.ico" sizes="any">
      <link rel="stylesheet" href="assets/site.css?v=#{css_hash}">
      <link rel="stylesheet" href="assets/dotfiles.css?v=#{dotfiles_hash}">
    </head>
    <body>
      <header class="site-header">
        <nav class="main-navigation" aria-label="Main navigation">
          <a class="nav-home" href="index.html">dot-files</a>
          <a href="https://marianposaceanu.com/">marianposaceanu.com</a>
        </nav>
      </header>

      <main class="page" id="top">
        <header class="hero" aria-labelledby="page-title">
          <p class="eyebrow">Vim field guide · dot-files</p>
          <h1 id="page-title">#{CGI.escapeHTML(title)}</h1>
          <p class="subtitle">#{CGI.escapeHTML(description)}</p>
          <ul class="meta" aria-label="Article metadata">
            <li>Vim tutorial</li>
            <li><time class="article-date" datetime="#{PUBLISHED_DATE}">#{VISIBLE_DATE}</time></li>
          </ul>
        </header>

        <nav class="toc" aria-label="Table of contents">
          <h2>On this page</h2>
          <ol>
    #{headings.map { |heading| %(        <li><a href="##{slug(heading)}">#{inline(heading)}</a></li>) }.join("\n")}
          </ol>
        </nav>

        <article class="article article-flow">
    #{render_markdown(body_lines)}
        </article>
      </main>

      <footer class="page-footer">
        <p><a class="home-link" href="index.html">Back to dot-files</a></p>
        <p><a href="https://github.com/marianposaceanu/dot-files">Browse the configuration source</a></p>
      </footer>
    </body>
    </html>
  HTML
end

FileUtils.mkdir_p(OUTPUT_DIR)
css_hash = Digest::SHA256.file(OUTPUT_DIR.join("assets/site.css")).hexdigest[0, 12]
dotfiles_hash = Digest::SHA256.file(OUTPUT_DIR.join("assets/dotfiles.css")).hexdigest[0, 12]

sources = SOURCE_DIR.glob("*.md").sort
abort "No Markdown tutorials found in #{SOURCE_DIR}" if sources.empty?

sources.each do |source|
  output = OUTPUT_DIR.join("#{slug(source.basename(".md").to_s)}.html")
  output.write(page_for(source, css_hash, dotfiles_hash), encoding: "UTF-8")
  puts "built #{output.relative_path_from(ROOT)}"
end
