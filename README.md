# IgorTunes

### Parse iTunes Library xml and algorithmically determine a "favourite songs" playlist 

Shell script will extract data from `iTunes Library.xml` using ruby/nokogiri and then clean it for importing into Igor Pro.

Place xml file in the same directory as `parsenoko.rb` and `xml2csv.sh` and run the shell script (requires ruby/nokogiri). The XML file will be processed into a tsv called `library.tsv`.

Now in Igor, using `IgorTunes.ipf`, run the menu command to simply load the data or to load the data and make an algorithmically perfect playlist of fifty songs. Igor offers to save this as `playlist.txt`. Save as *.m3u file and drag back into iTunes.

The details of the first version of this project are [here](https://quantixed.org/2015/08/13/your-favorite-thing-algorithmically-perfect-playlist/).
