require 'nokogiri' 
require 'rubygems'
require 'open-uri'
require "erb"

require 'selenium-webdriver'
require 'pry'
require 'os'

#Selenium::WebDriver.logger.level = :debug

# OS X version
# if OS.mac?
# 	caps = Selenium::WebDriver::Remote::Capabilities.chrome("desiredCapabilities" => {"takesScreenshot" => true}, "chromeOptions" => {"binary" => "/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary"})
# end
# # Windows version
# if OS.windows?
# 	Selenium::WebDriver::Chrome.driver_path = 'C:\development\tools\chromedriver.exe'
# 	caps = Selenium::WebDriver::Remote::Capabilities.chrome("desiredCapabilities" => {"takesScreenshot" => true}, "chromeOptions" => {"binary" => 'C:\Users\Squirrel\AppData\Local\Google\Chrome SxS\Application\chrome.exe'})
# end

# browser = Selenium::WebDriver.for :chrome, desired_capabilities: caps, switches: %w[--headless --no-sandbox --disable-gpu --remote-debugin-port=9222 --screen-size=1200x3000]
# # Selenium::WebDriver.logger.output = 'selenium.log'

# browser.navigate.to "https://novelplanet.com/Novel/Kumo-Desu-ga-Nani-ka"

# wait = Selenium::WebDriver::Wait.new(:timeout => 15)

# # Login
# input = wait.until {
#     element = browser.find_element(:id, "d_rut")
#     element if element.displayed?
# }

## PHANTOM
# Require the gems
require 'capybara/poltergeist'



def configure_driver
	Selenium::WebDriver::Chrome.path ="/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary"
	options = Selenium::WebDriver::Chrome::Options.new

	options.add_argument('--ignore-certificate-errors')
	options.add_argument('--disable-popup-blocking')
	options.add_argument('--disable-translate')
	options.add_argument('--headless')
	options.add_argument('--no-sandbox')
	options.add_argument('--disable-gpu')
	#options.add_argument('--screen-size=1200x3000')
	@driver = Selenium::WebDriver.for :chrome, options: options
	@wait = Selenium::WebDriver::Wait.new(:timeout => 15)
end

def stop_driver
	@driver.quit
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
	    --language en --authors '#{metadata[:author].count > 1 ? metadata[:author].first : metadata[:author]}'")
end



#############
# Variables #
#############
@driver, @wait = nil
@story_url = "https://novelplanet.com/Novel/I-Was-a-Sword-When-I-Reincarnated-LN" #|| ARGV.first
@base_url, @novel_file_name = @story_url.split('/Novel/')
@novel_file_name.gsub!(/[^a-zA-Z-]/, '')


# configure_driver
# @driver.navigate.to @story_url
# # Bot check skip!
# #@wait.until { @driver.find_element(:class => "txtSearchTop") }
# #@driver.save_screenshot("./before.png")
# # Wait until the warning message vanishes
# @wait.until { !@driver.page_source.include? "Make sure to enable cookies and javascript." }
# #@driver.save_screenshot("./after.png")

# # begin
# #   @wait.until { @driver.find_element(:id, 'message').displayed? } #check if message received
# # rescue
# #   ##this block get's executed if there is any kind of exception error
# #   stop_driver
# # end

# # Pass everything to Nokogiri
# page_source = @driver.page_source


# Configure Poltergeist to not blow up on websites with js errors aka every website with js
# See more options at https://github.com/teampoltergeist/poltergeist#customization
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
    phantomjs_logger: File.open(File::NULL, 'w')
  }
  Capybara::Poltergeist::Driver.new(app, options)
  #Capybara::Poltergeist::Driver.new(app, js_errors: false)
end

# Configure Capybara to use Poltergeist as the driver
Capybara.default_driver = :poltergeist
browser = Capybara.current_session
#url = "https://novelplanet.com/Novel/I-Was-a-Sword-When-I-Reincarnated-LN"#"https://github.com/jnicklas/capybara"

browser.visit @story_url
#expect(page).to have_content 'Novel list'
sleep 8
page_source = browser.html

page = Nokogiri::HTML(page_source)
# Get the metadata
metadata_node = page.css('.post-contentDetails')
story_metadata = get_story_metadata metadata_node
chapters = page.xpath('//h3[contains(text(), "Chapter list")]').first.parent.css(".rowChapter")

@novel_text = ""
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
		chapter_url = @base_url + chapter['alink']
		# @driver.navigate.to chapter_url
		# @wait.until { !@driver.page_source.include? "Make sure to enable cookies and javascript." }
		# page_source = @driver.page_source
		page_source = nil
		begin
			browser.visit chapter_url
			#expect(page).to have_content 'Novel list'
			page_source = browser.html
		rescue Capybara::Poltergeist::StatusFailError
			browser.visit chapter_url
			#expect(page).to have_content 'Novel list'
			page_source = browser.html
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

#####

# # Configuration
# novel_url = "https://novelplanet.com/Novel/Kumo-Desu-ga-Nani-ka"
# novel_title = "Kumo Desu ga, Nani ka?"
# novel_author = "Baba Okina"
# novel_publisher = "Raising the Dead"
# base_url = "https://novelplanet.com"
# # Flag if the conversion failed and you want to try again
# only_convert = false


#stop_driver

# Story data = div.post-contentDetails
# story_data = []
# driver.navigate.to "http://google.com"

# element = driver.find_element(name: 'q')
# element.send_keys "Hello WebDriver!"
# element.submit

# puts driver.title
# binding.pry

# Has text "Please wait 5 seconds..."
# 
# Please wait 5 seconds...
# Make sure to enable cookies and javascript.
# This site does not work with "Mini browsers" (e.g. UC mini, Opera mini...)

# Check that the form exists
# blerp = wait.until {
#     element = driver.find_element(:link, "Novel List")
#     element if element.displayed?
# }
 
# When it has Novel list, we're in the right place
# xpath => //*[@id="nav"]/ul/li[2]/a
# Selector - #nav > ul > li:nth-child(2) > a

# Another idea: search bar
# #nav > ul > li.liHideFloatNav > input
# //*[@id="nav"]/ul/li[4]/input

# input .txtSearchTop con placeholder = Search




