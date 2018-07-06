require 'nokogiri' 
require 'rubygems'
require 'open-uri'
require 'erb'
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

def get_story_cover url
	cover_path = "output/html/#{@novel_file_name}/cover.png"
	unless File.exists?(cover_path)
		File.open(cover_path, 'wb') do |fo|
		  fo.write open(url).read 
		end
	end
end

def save_or_update_metadata metadata
	File.open("output/html/#{@novel_file_name}/metadata.json", 'w+') do |f|
	  f.write metadata
	end
end


#################
# eBook Methods #
#################

def convert_ebook metadata, content
	# Get the data
	title = metadata[:title]
	publisher = metadata[:translator]
	authors = (metadata[:author].kind_of?(Array) && metadata[:author].count > 1) ? metadata[:author].first : metadata[:author]
	tags = "NovelPlanet"
	description = metadata[:description]
	cover_path = "output/html/#{@novel_file_name}/cover.png"
	cover = File.exists?(cover_path) ? ("--cover \"" + cover_path + "\"") : ''
	# Convert it using Calibre
	system("ebook-convert \"output/html/#{@novel_file_name}.html\" \"output/mobi/#{@novel_file_name}.mobi\" \
	    --output-profile kindle_dx \
	    --title \"#{title}\" --publisher \"#{publisher}\" --tags \"#{tags}\" --comments \"#{description}\"\
	    --language en --authors \"#{authors}\" #{cover}")
end

#############
# Variables #
#############
@browser = nil
@story_url = ARGV.first
@base_url, @novel_file_name = @story_url.split('/Novel/')
@novel_file_name.gsub!(/[^a-zA-Z-]/, '')

# Options
@options = {}
@options[:force] = false
OptionParser.new do |parser|
	parser.on("-c", "--cover C", "Specify cover url for the image for the story") do |c|
    @options[:cover] = c
  end
	parser.on("-f", "--force", "Force redownload all chapters") do |force|
    @options[:force] = true
  end
end.parse!

# Configuration
configure_driver
@browser.visit @story_url
page_source = @browser.html

while page_source.include?('Make sure to enable cookies and javascript.') do
	sleep 1
	page_source = @browser.html
end

page = Nokogiri::HTML(page_source)

# Create folder (unless it exists)
directory_name = "output/html/#{@novel_file_name}"
Dir.mkdir(directory_name) unless File.exists?(directory_name)

# Get existing
downloaded_chapters = Dir.entries(directory_name).select{ |e| e.include? "html" }.sort_by(&:to_i)
# Scrape stage

get_story_cover(@options[:cover]) unless @options[:cover].nil?

# Get the metadata
metadata_node = page.css('.post-contentDetails')
while metadata_node.empty? do
	# Wait until it appears
	sleep 1
	page_source = @browser.html
	page = Nokogiri::HTML(page_source)
	metadata_node = page.css('.post-contentDetails')
end
story_metadata = get_story_metadata metadata_node
story_metadata[:description] = page.css('.post-contentDetails + div + div').nil? ? "" : page.css('.post-contentDetails + div + div').text
save_or_update_metadata story_metadata

# Chapters
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
		# Check if we already downloaded it
		if downloaded_chapters.include?("#{index+1}.html") && !@options[:force]
			p "#{index+1}/#{chapter_total} - Already downloaded"
			next
		else
			p "#{index+1}/#{chapter_total}"
		end
		# Build url
		# Escape to fix url if it has special characters
		chapter_url = URI.escape(@base_url + chapter['alink'])
		
		# @driver.navigate.to chapter_url
		# @wait.until { !@driver.page_source.include? "Make sure to enable cookies and javascript." }
		# page_source = @driver.page_source
		page_source = ""
		begin
			while page_source.empty? do
				@browser.visit chapter_url
				#expect(page).to have_content 'Novel list'
				page_source = @browser.html
			end
		rescue Capybara::Poltergeist::StatusFailError
			@browser.visit chapter_url
			#expect(page).to have_content 'Novel list'
			page_source = @browser.html
		end
		page = Nokogiri::HTML(page_source)
		# Remove ads
		content = page.css('#divReadContent')
		content.search('div > iframe').each do |ad|
			ad.remove
		end
		# Save chapter content in a chapter file
		File.open("output/html/#{@novel_file_name}/#{index+1}.html", 'w+') do |f|
		  f.write "<h2>Chapter #{index+1}</h2><br>" + content.inner_html.strip
		end
		downloaded_chapters << "#{index+1}.html"
	end
end

# Convert stage
# Read files in order
@content = ""
downloaded_chapters.sort_by(&:to_i).each do |chapter|
	@content += File.read("output/html/#{@novel_file_name}/#{chapter}")
end

# render template
template = File.read('./template.html.erb')
result = ERB.new(template).result(binding)

# write result to file
File.open("output/html/#{@novel_file_name}.html", 'w+') do |f|
  f.write result
end

convert_ebook story_metadata, @content

