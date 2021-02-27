#!/usr/bin/env ruby

# A script to convert README.md to html,
# with html parsing so I automatically can plug in links
# to Wikipedia, RottenTomatoes, etc.

require 'tempfile'
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

  File.open(OUTPUT, 'w+') do |file|
    file.write text
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

main
