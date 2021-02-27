#!/usr/bin/env ruby

# A script to convert README.md to html,
# with html parsing so I automatically can plug in links
# to Wikipedia, RottenTomatoes, etc.

require 'tempfile'
require 'cgi'
require 'nokogiri'
require './src/anchor'

SOURCE = 'README.md'
OUTPUT = 'index.html'
TEMPLATE = 'src/template.html'


def main
  # method 1: try to replicate GitHub's md to html conversion
  # but it has issues:
  # - some anchors don't work
  # - markdown converion replaces '_' in urls with <em>, so it breaks plaintext urls
  #   and we can't easily linkify them after
  #
  # text = File.read(SOURCE)
  # text = to_markdown text
  # text = linkify text
  # text = with_template text

  # method 2: using GitHub api
  text = convert_with_grip

  # common processing
  doc = Nokogiri::HTML text

  add_summary_anchor doc
  a_with_target_blank doc
  create_id_for_anchors doc

  File.open(OUTPUT, 'w+') do |file|
    file.write doc.to_s
  end
end

private

# Rewrite https:// links with a <a> tag
# if they are not in a markdown []() tag
def linkify text
  Anchored::Linker.auto_link text
end

def to_markdown text
  temp = Tempfile.new
  File.write(temp, text, mode: 'w+')
  `markdown #{SOURCE} > #{temp.path}` # brew install markdown
  File.read(temp.path)
end

def with_template text
  File.open(TEMPLATE, 'r') do |file|
    template = file.read
    return template.sub('BODY') { text }
  end
end

def convert_with_grip
  `grip #{SOURCE} --export #{OUTPUT}`
  File.read(OUTPUT)
end

def add_summary_anchor doc
  doc.css('h2, h3, h4')[5..].each do |title|
    title << " <a href='#top'>↑</a>"
  end
end

def a_with_target_blank doc
  doc.css('a').each do |link|
    next unless link['href'].include? 'https://' # don't process anchor links

    link['target'] = '_blank'
    link['rel'] = 'noopener'
  end
end

# Some anchors with accents (ex: '#comédies')
# dot not work when markdown converted with GitHub api.
#
# So we need to create our own `id` attributes, like
#   <h3 id="comédies" ...
#
def create_id_for_anchors doc
  doc.css('h2, h3, h4')[5..].each do |title|
    title['id'] = to_anchor title.content
  end
end

def to_anchor s
  s = s.gsub(/[^0-9a-z éèàç]/i, '').downcase.strip
  s = s.gsub(' ', '-')
end


main
