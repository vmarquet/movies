#!/usr/bin/env ruby

# A script to convert README.md to html,
# with html parsing so I automatically can plug in links
# to Wikipedia, RottenTomatoes, etc.

require 'tempfile'
require 'cgi'
require 'nokogiri'
require 'yaml'
require 'json'
require 'net/http'
require 'httparty'
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
  add_movie_poster doc
  # add_awards_links doc

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

def add_poster_css doc
  head = doc.css('head')[0]
  head << """
<style>
  img.poster {
    position: fixed;
    top: 0px;
    right: 0px;
    max-height: 600px;
    border-radius: 0px 0px 0px 3px;
  }
</style>

<script>
  function setPosterPath(path) {
    var image = document.querySelector('img.poster');
    image.src = path;
  }
</script>
"""
end

def add_poster_div doc
  body = doc.css('body')[0]
  body << """
<img class='poster' src='' />
"""
end

def add_movie_poster doc
  add_poster_css doc
  add_poster_div doc

  keys = YAML.load_file('secrets.yml')
  tmdb_api_key = keys['tmdb']['api_key']

  if tmdb_api_key.nil?
    puts "Could not find tmdb api key"
    return
  else
    puts "Found tmdb api key"
  end

  puts "Loading movie posters..."
  posters_file = 'scripts/movie_posters_database.json'
  posters_db = JSON.parse File.read(posters_file)
  puts "Found #{posters_db.keys.size} posters in #{posters_file}"

  doc.css('li').each do |li|
    next if li.text.strip.empty?
    next if li.text.strip.start_with?('pas vu')
    next if li.text.strip.start_with?('bof')

    title = li.text.split('(')[0].split(':')[0].split('#')[0]
    title = title.tr('éèê', 'e')
    title = title.gsub(/[^0-9a-z' ]/i, '') # remove all emojis
    title = title.strip
    next if title.size > 35
    next if ["1960", "1970", "1980", "1990", "2000", "2010", "2020", "ScienceFiction", "https", "Now You See It", "The Closer Look"].include?(title)

    if posters_db.key?(title)
      poster_path = "https://image.tmdb.org/t/p/original/#{posters_db[title]}"
    else
      url = "https://api.themoviedb.org/3/search/movie?api_key=#{tmdb_api_key}&language=en-US&query=#{CGI.escape title}&page=1&include_adult=false"

      # HTTP non S
      # response = Net::HTTP.get_response('api.themoviedb.org', "/3/search/movie?api_key=#{tmdb_api_key}&language=en-US&query=#{title}&page=1&include_adult=false")
      
      # net = Net::HTTP.new('api.themoviedb.org', 443)
      # net.use_ssl = true
      # net.get_response("/3/search/movie?api_key=#{tmdb_api_key}&language=en-US&query=#{title}&page=1&include_adult=false")

      puts "Searching movie #{title} : #{url}"
      response = HTTParty.get(url)

      data = JSON.parse response.body
      next if data['results'].empty?

      rel_poster_path = data['results'][0]['poster_path']
      next if rel_poster_path.nil?

      poster_path = "https://image.tmdb.org/t/p/original/#{rel_poster_path}"
      # poster_path = "https://image.tmdb.org/t/p/original/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg"
      puts "Found new poster at #{rel_poster_path}"

      posters_db[title] = rel_poster_path

      sleep 0.1
    end

    File.write(posters_file, JSON.pretty_generate(posters_db))

    li['onmouseover'] = "console.log(\"#{poster_path}\"); setPosterPath(\"#{poster_path}\");"
    li['onmouseleave'] = "setPosterPath(\"\");"
  end
end

def add_awards_links doc
  # byebug

  # https://www.w3schools.com/css/css_tooltip.asp
  head = doc.css('head')[0]
  head << """
<style>
/* Tooltip container */
.tooltip {
  position: relative;
}

/* Tooltip text */
.tooltip .tooltiptext {
  visibility: hidden;
  width: 120px;
  background-color: black;
  color: #fff;
  text-align: center;
  padding: 5px 0;
  border-radius: 6px;
 
  /* Position the tooltip text - see examples below! */
  position: absolute;
  z-index: 1;
}

/* Show the tooltip text when you mouse over the tooltip container */
.tooltip:hover .tooltiptext {
  visibility: visible;
}
</style>
"""

  keys = YAML.load_file('secrets.yml')
  tmdb_api_key = keys['tmdb']['api_key']

  doc.css('li').each do |li|
    title = doc.css('li')[500].text.tr('💙❤️🎥🏆✨🌿☀️🧸🌐🎭🍅📰', '').split('(')[0].strip
    title = 'matrix'

    url = "https://api.themoviedb.org/3/search/movie?api_key=#{tmdb_api_key}&language=en-US&query=#{title}&page=1&include_adult=false"


    # HTTP non S
    # response = Net::HTTP.get_response('api.themoviedb.org', "/3/search/movie?api_key=#{tmdb_api_key}&language=en-US&query=#{title}&page=1&include_adult=false")
    
    # net = Net::HTTP.new('api.themoviedb.org', 443)
    # net.use_ssl = true
    # net.get_response("/3/search/movie?api_key=#{tmdb_api_key}&language=en-US&query=#{title}&page=1&include_adult=false")

    puts url
    response = HTTParty.get(url)

    data = JSON.parse response.body

    li['class'] = (li['class'] || '') << " tooltip"
    li << '<span class="tooltiptext">Tooltip text</span>'
  end


  doc.css('h2, h3, h4')[5..].each do |title|
    text = title.content.gsub(/[^0-9]/i, '').strip.to_i
    next unless text.to_i >= 1900 && text.to_i <= Time.now.year

    year = text.to_i

    if (1933..(Time.now.year - 1)).include? year
      ceremony_number = year - 1927
      title << " <a href='#{wikipedia_award_url ceremony_number, 'Oscars'}' #{target_blank}>🏆</a>"
    end

    if (1975..(Time.now.year - 1)).include? year
      ceremony_number = year - 1975 + 1
      title << " <a href='#{wikipedia_award_url ceremony_number, 'César'}' #{target_blank}>✨</a>"
    end

    if (1946..Time.now.year).include? year
      title << " <a href='https://fr.wikipedia.org/wiki/Festival_de_Cannes_#{year}#S%C3%A9lection_officielle' #{target_blank}>🌿</a>"
    end

    if (2011..Time.now.year).include? year
      ceremony_number = year - 2011 + 26
      title << " <a href='#{wikipedia_award_url ceremony_number, 'Goyas'}' #{target_blank}>🇪🇸</a>"
    end
  end
end

def wikipedia_award_url ceremony_number, award
  x_ieme = ceremony_number == 1 ? '1re' : "#{ceremony_number}e"
  "https://fr.wikipedia.org/wiki/#{x_ieme}_cérémonie_des_#{award}#Meilleur_film"
end

def target_blank
  ' target="_blank" rel="noopener" '
end


main
