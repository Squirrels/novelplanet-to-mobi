require 'nokogiri' 
require 'rubygems'
require 'open-uri'
require "erb"


# Configuration
novel_url = "https://novelplanet.com/Novel/Url-Of-Novel"
novel_title = "Name of Novel"
novel_author = "Author of Novel"
novel_publisher = "Anything, really"
base_url = "https://novelplanet.com"
# Flag if the conversion failed and you want to try again
only_convert = false

unless only_convert
	page = Nokogiri::HTML(open(novel_url))
	#We look for the "Chapter list" text
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
				p "#{index+1}/#{chapter_total}"
				# Build url
				chapter_url = base_url + chapter['alink']
				page = Nokogiri::HTML(open(chapter_url))
				# Remove ads
				content = page.css('#divReadContent')
				content.search('div').each do |ad|
					ad.remove
				end
				# Get text and add a space at the end
				novel_text += content.inner_html + "<br />"
		end
	end

	@content = novel_text

	# render template
	template = File.read('./template.html.erb')
	result = ERB.new(template).result(binding)

	# write result to file
	File.open("output/html/#{novel_title}.html", 'w+') do |f|
	  f.write result
	end

end

# Convert it using Calibre
system("ebook-convert \"output/html/#{novel_title}.html\" \"output/mobi/#{novel_title}.mobi\" \
    --output-profile kindle_dx --no-inline-toc \
    --title \"#{novel_title}\" --publisher \"#{novel_publisher}\" \
    --language en --authors '#{novel_author}'")
