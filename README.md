# IgorTunes

### Parse iTunes Library xml and algorithmically determine a "favourite songs" playlist 

Shell script will extract data from `iTunes Library.xml` using ruby/nokogiri and then clean it for importing into Igor Pro.

You import the data using:

`LoadWave /N=Column/O/K=2/J/V={"\t"," $",0,0}`

and then run

- `iTunes()`
- `DateRead()`
- `Predictor()`
- `WritePlayList(50) //whatever length of playlist you'd like`

Save as *.m3u file and drag back into iTunes.
