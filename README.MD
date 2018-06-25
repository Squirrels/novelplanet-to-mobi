# Novelplanet downloader and converter to .mobi

This script downloads all the chapters for a given story in novelplanet.com, saves it as individual .html files (per chapter) and converts it to a .mobi file using Calibre-Cli.

## Requirements

This project uses:
- [Nokogiri](http://www.nokogiri.org/)
- [Capybara](https://github.com/teamcapybara/capybara)
- [Poltergeist](https://github.com/teampoltergeist/poltergeist)
- Requires the user to have [calibre-cli installed](https://manual.calibre-ebook.com/generated/en/cli-index.html) (for the conversion)

## Why use Poltergeist/Capybara?

To skip the browser verification in novelplanet.com

## Usage

To run it, just do:

```
ruby scrape.rb <URL_OF_STORY>
```

This will create a folder in the output folder named after the story, where it will store the chapters (as individual .html files), the cover and the metadata.

## Configuration

You can add the following options when running it

```
-f, --force          Forces the scraper to re-download chapters (otherwise, it ignores already downloaded chapters)
-c, --cover <URL>    Specifies the url of an image to use as the eBook cover
```
So, you would do

```
ruby scrape.rb <URL_OF_STORY> -f -c <URL_OF_COVER>
```

If you wanted to re-download all chapters and add a cover image.