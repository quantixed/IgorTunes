# IgorTunes
Parse iTunes xml and algorithmically determine a "favourite songs" playlist 
--
Working on a copy of 'iTunes Music Library.xml' run the parsenoko.rb script using<br />

` find . -name "*.xml" -exec ruby parsenoko.rb {} playlist.tsv \;`<br />
<br />
This file needs to be cleaned slightly before importing into Igor see [this blog post](http://wp.me/p4Ir7n-95).<br />
You import the data using:<br />
`LoadWave /N=Column/O/K=2/J/V={"\t"," $",0,0}`<br />
and then run<br />
`iTunes()`<br />
`DateRead()`<br />
`Predictor()`<br />
`WritePlayList(50) //whatever length of playlist you'd like`<br />
Save as *.m3u file and drag back into iTunes.
