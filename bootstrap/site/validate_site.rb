#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"
require "rexml/document"

ROOT = Pathname.new(__dir__).join("../..").expand_path
DOCS = ROOT.join("docs")
BASE_URL = "https://dot.marianposaceanu.com"
REDIRECT_PAGES = ["vim-performance.html"].freeze
WEBSITE = {
  "@context" => "https://schema.org",
  "@type" => "WebSite",
  "@id" => "#{BASE_URL}/#website",
  "url" => "#{BASE_URL}/",
  "name" => "dot-files",
  "alternateName" => "Marian’s macOS dotfiles",
  "publisher" => { "@id" => "https://marianposaceanu.com/#person" }
}.freeze

def canonical_url(path)
  path.basename.to_s == "index.html" ? "#{BASE_URL}/" : "#{BASE_URL}/#{path.basename}"
end

pages = DOCS.glob("*.html").reject { |path| REDIRECT_PAGES.include?(path.basename.to_s) }.sort
abort "No published pages found" if pages.empty?

pages.each do |path|
  html = path.read(encoding: "UTF-8")
  expected_canonical = canonical_url(path)
  canonicals = html.scan(/<link rel="canonical" href="([^"]+)">/).flatten
  abort "#{path}: expected canonical #{expected_canonical}" unless canonicals == [expected_canonical]
  abort "#{path}: obsolete ecosystem navigation found" if html.include?("ecosystem-navigation")
end

homepage = DOCS.join("index.html").read(encoding: "UTF-8")
schemas = homepage.scan(%r{<script type="application/ld\+json">(.*?)</script>}m).map do |json|
  JSON.parse(json.first)
end
abort "Homepage WebSite identity is missing or duplicated" unless schemas.count(WEBSITE) == 1

sitemap = REXML::Document.new(DOCS.join("sitemap.xml").read(encoding: "UTF-8"))
sitemap_urls = REXML::XPath.match(sitemap, "//*[local-name()='loc']").map(&:text)
expected_urls = pages.map { |path| canonical_url(path) }
abort "Sitemap does not match canonical page inventory" unless sitemap_urls == expected_urls
abort "Sitemap contains duplicate URLs" unless sitemap_urls.uniq == sitemap_urls

puts "Published site contract passed for #{pages.length} pages."
