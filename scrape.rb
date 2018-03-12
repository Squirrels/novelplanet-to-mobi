require 'nokogiri' 
require 'rubygems'
require 'open-uri'
require "erb"
require 'pry'

# Settings
# Disable alarm
#Prawn::Font::AFM.hide_m17n_warning = true

# Ask for the main site
novel_url = "http://novelplanet.com/Novel/I-Was-a-Sword-When-I-Reincarnated"
novel_title = "I-Was-a-Sword-When-I-Reincarnated"
novel_author = "Tanaka Yu"
base_url = "http://novelplanet.com"
page = Nokogiri::HTML(open(novel_url))

# We look for the "Chapter list" text
chapter_list_h3 = page.xpath('//h3[contains(text(), "Chapter list")]')
# Now get the chapters
chapters = chapter_list_h3.first.parent.css(".rowChapter")
novel_text = ""
if chapters.count == 0
	puts "No chapters :("
else
	# Progress
	chapter_total = chapters.count
	p "#{chapter_total} chapters detected!"
	# Reverse it!
	chapters = chapters.reverse
	# Now, for each, do the correct processing
	chapters.each_with_index do |chapter, index|
			p "#{index}/#{chapter_total} \r\n"
			# Build url
			chapter_url = base_url + chapter['alink']
			page = Nokogiri::HTML(open(chapter_url))
			# Get text
			novel_text += page.css('#divReadContent').inner_html + "< /br>"
	end
end

binding.pry
@content = novel_text


# render template
template = File.read('./template.html.erb')
result = ERB.new(template).result(binding)

# write result to file
File.open("#{novel_title}.html", 'w+') do |f|
  f.write result
end


# Convert it using Calibre
# system("ebook-convert #{novel_title}.html #{novel_title}.mobi \
#     --output-profile kindle_dx --no-inline-toc \
#     --title '#{novel_title}' --publisher 'Squirrel' \
#     --language en --authors 'Your Author Name'")
