require 'nokogiri' 
require 'rubygems'
require 'open-uri'
# require "pdfkit"
# require "prawn"
# require "loofah"
require "erb"

# Settings
# Disable alarm
#Prawn::Font::AFM.hide_m17n_warning = true

novel_url = "http://novelplanet.com/Novel/Re-Monster/Volume-1-Chapter-1"

page = Nokogiri::HTML(open(novel_url))
novel_text = page.css('#divReadContent').inner_html
#cleaned_text = Loofah.fragment(novel_text).scrub!(:strip).text

# Now apply filters
#cleaned_text.gsub!("&#13;","\n")
# cleaned_text.gsub!("<h3>","[title]").gsub!("</h3>","[/title]")
# cleaned_text.gsub!("<strong>","[bold]").gsub!("</strong>","[/bold]")

# Store it in a temp html
@content = novel_text


# render template
template = File.read('./template.html.erb')
result = ERB.new(template).result(binding)

# write result to file
File.open('filename.html', 'w+') do |f|
  f.write result
end


# Convert it using Calibre
system("ebook-convert filename.html my-project.mobi \
    --output-profile kindle_dx --no-inline-toc \
    --title 'Your Book Title' --publisher 'Your Name' \
    --language en --authors 'Your Author Name'")

# Prawn::Document.generate("hello.pdf") do
#   #text novel_text
#   # Line by line, apply style filters
#   novel_text.each_line do |line|
# 	   if line.include? "<h3>"
# 	   	text Loofah.fragment(line).scrub!(:strip).text.gsub!("&#13;","\n"), size: 20
# 	   elsif line.include? "<strong>"
# 	   	text Loofah.fragment(line).scrub!(:strip).text.gsub!("&#13;","\n"), style: :bold
# 	   else
# 	   	text Loofah.fragment(line).scrub!(:strip).text.gsub!("&#13;","\n")
# 	   end
# 	end
# end