# Novelplanet downloader and converter to .mobi

This script downloads all the chapters for a given story in novelplanet.com, saves it as an .html file and converts it to a .mobi file using Calibre-Cli.

## Requirements
This project uses the gem [Nokogiri](http://www.nokogiri.org/) and requires the user to have [calibre-cli installed](https://manual.calibre-ebook.com/generated/en/cli-index.html) (for the conversion)


## Configuring it
There's a couple of variables in the script

```ruby
novel_url # The main url of the novel
novel_title # Name of the novel (will also become the filename)
novel_author # Author of the novel
novel_publisher # Anything, but I tend to put the translating group here
base_url = "https://novelplanet.com"
# Flag if the conversion failed and you want to try again
only_convert = false
```

## Running it
Simply do:

```
ruby scrape.rb
```

And the results will be stored in the output folder.