require 'nokogiri' 
require 'rubygems'
require 'open-uri'
require "erb"
require 'capybara/poltergeist'
require 'pry'
require 'os'
require 'optparse'

def configure_driver
	Capybara.register_driver :poltergeist do |app|
		options = {
	    debug: false,
	    timeout: 120,
	    window_size: [1280, 1440],
	    phantomjs_options: [
	      '--proxy-type=none', 
	      '--load-images=no', 
	      '--ignore-ssl-errors=yes', 
	      '--ssl-protocol=any',
	      '--web-security=false','--debug=false'
	    ],
	    js_errors: false,
	    default_wait_time: 20,
	    phantomjs_logger: File.open(File::NULL, 'w') #Disable login, OH GOD
	  }
	  Capybara::Poltergeist::Driver.new(app, options)
	end

	# Configure Capybara to use Poltergeist as the driver
	Capybara.default_driver = :poltergeist
	@browser  = Capybara.current_session
end

# Metadata result example
# {:title=>"Kumo Desu ga, Nani ka?",
#  :other_name=>["I'm A Spider, So What?", "蜘蛛ですが、なにか?"],
#  :genre=>["Action", "Adventure", "Comedy", "Drama", "Fantasy", "Mystery", "Sci-fi", "Seinen"],
#  :date_released=>"2015",
#  :views=>"383261",
#  :author=>"Baba Okina",
#  :status=>"Ongoing",
#  :translator=>"Raising the Dead"}
def get_story_metadata metadata_node
	metadata = {
		title: metadata_node.css('.title').text
	}
	metadata_node.css('.infoLabel').each do |row|
		# There are two 'types'
		# - If it has links, it follows the pattern [line jump, attribute name, blank, value1(, ;, value2...)]
		# - If it has NO links, it follows the pattern [line jump, attribute name, value (with line jump added at the end)]
		links = row.parent.children.css('a')
		value = []
		if links.count == 0
			value = row.parent.children.last.text.strip
		elsif links.count == 1
			value = links.last.text.strip
		else
			value = links.map(&:text)
		end
		metadata[row.text.downcase.gsub(':','').gsub(' ','_').to_sym] = value
	end
	metadata
end

###################
# Chapter Methods #
###################

def parse_chapter url
	# Visit and get the SHIT
end


#################
# eBook Methods #
#################

def convert_ebook metadata, content
	# # Convert it using Calibre
	system("ebook-convert \"output/html/#{@novel_file_name}.html\" \"output/mobi/#{@novel_file_name}.mobi\" \
	    --output-profile kindle_dx --no-inline-toc \
	    --title \"#{metadata[:title]}\" --publisher \"#{metadata[:translator]}\" \
	    --language en --authors '#{metadata[:author].count > 1 ? metadata[:author].first : metadata[:author]}' --cover #{@cover}")
end

#############
# Variables #
#############
@browser = nil
@story_url = ARGV.first
@cover = ARGV.last
@base_url, @novel_file_name = @story_url.split('/Novel/')
@novel_file_name.gsub!(/[^a-zA-Z-]/, '')

# Options
OptionParser.new do |parser|
parser.on("-nd", "--no-download", "Skip Downloading") do |v|
    options[:name] = v
  end
end.parse!


configure_driver
@browser.visit @story_url
page_source = @browser.html

while page_source.include?('Make sure to enable cookies and javascript.') do
	sleep 1
	page_source = @browser.html
end

page = Nokogiri::HTML(page_source)
# Get the metadata
metadata_node = page.css('.post-contentDetails')
story_metadata = get_story_metadata metadata_node
chapters = []
begin
	chapter_container = page.xpath('//h3[contains(text(), "Chapter list")]')
	while chapter_container.nil? || chapter_container.empty? do
		sleep 1
		page_source = @browser.html
		page = Nokogiri::HTML(page_source)
		chapter_container = page.xpath('//h3[contains(text(), "Chapter list")]')
	end
	chapters = chapter_container.first.parent.css(".rowChapter")
rescue NoMethodError
	binding.pry
	@browser.save_and_open_page
end

@novel_text = ""
if chapters.count == 0
	puts "No chapters :("
	@browser.save_and_open_page
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
		chapter_url = @base_url + chapter['alink']
		# @driver.navigate.to chapter_url
		# @wait.until { !@driver.page_source.include? "Make sure to enable cookies and javascript." }
		# page_source = @driver.page_source
		page_source = nil
		begin
			@browser.visit chapter_url
			#expect(page).to have_content 'Novel list'
			page_source = @browser.html
		rescue Capybara::Poltergeist::StatusFailError
			@browser.visit chapter_url
			#expect(page).to have_content 'Novel list'
			page_source = @browser.html
		end
		page = Nokogiri::HTML(page_source)
		# Remove ads
		content = page.css('#divReadContent')
		content.search('div').each do |ad|
			ad.remove
		end
		# Get text and add a space at the end
		@novel_text += content.inner_html + "<br />"
	end
end

@content = @novel_text

# render template
template = File.read('./template.html.erb')
result = ERB.new(template).result(binding)

# write result to file
File.open("output/html/#{@novel_file_name}.html", 'w+') do |f|
  f.write result
end

convert_ebook story_metadata, @content

