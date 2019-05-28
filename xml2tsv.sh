#!/bin/bash
# First we'll process the iTunes Library.xml to a csv using Nokogiri
ruby parsenoko.rb 'iTunes Library.xml' > library.csv
# Now we need to reformat the csv to tsv
sed -i.bak 's/\", \"/\"	\"/g' library.csv
# remove start and end
sed -i.bak 's/}\]//g' library.csv
sed -i.bak 's/\[{//g' library.csv
# substitute line endings
sed -i.bak 's/}, {/\
/g' library.csv
# now generate headers for 33 columns
seq 33 | { while read num; do x+=column$num\\t; done; echo $x > headers.txt; }
# delimit with tabs
sed -i.bak 's/\\t/	/g' headers.txt
# and append them to the beginning of the tsv
cat headers.txt library.csv > library.tsv
# remove unneeded Files
rm library.csv.bak
rm headers.txt.bak
rm headers.txt
rm library.csv
