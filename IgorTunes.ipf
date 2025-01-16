#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Process data from iTunes Library.xml using bash script and ruby/nokogiri

////////////////////////////////////////////////////////////////////////
// Menu items
////////////////////////////////////////////////////////////////////////
Menu "Macros"
	"Load iTunes Library Data...", /Q, iTunes()
	"Make Algrorithmic Playlist...", /Q, iTunesPlayList()
	"Simple CSV Export", /Q, CSVExport()
End

Function iTunes()
	CleanSlate()
	LoadTSVAndProcess()
	DateRead()
	Predictor()
	LibraryAnalysis()
End

Function iTunesPlaylist()
	CleanSlate()
	LoadTSVAndProcess()
	DateRead()
	Predictor()
	WritePlaylist(50)
End

Function LoadTSVAndProcess()
	// load TSV file (result from bash script)
	LoadWave/N=Column/O/K=2/J/V={"\t"," $",0,0}
	
	String wList = WaveList("Column*",";","")
	String wName = StringFromList(0,wList)
	Wave w0 = $wName
	Variable nTracks = numpnts(w0)
	Variable nWaves = ItemsInList(wList)
	Variable i
	
	//remove first row (contains ColumnA etc.)
	for(i = 0; i < nWaves; i += 1)
		wName = StringFromList(i,wList)
		DeletePoints 0,1, $wName
	endfor
	// Make the waves to hold the data
	Make/O/N=(nTracks) Track_ID
	Make/O/T/N=(nTracks) Name, Artist, Album_Artist, Composer, Album, Genre, Kind
	Make/O/N=(nTracks) Size, Total_Time, Disc_Number, Disc_Count, Track_Number, Track_Count, Year
	Make/O/T/N=(nTracks) Date_Modified, Date_Added
	Make/O/N=(nTracks) Bit_Rate, Sample_Rate, Play_Count
	Make/O/D/N=(nTracks) Play_Date	//needs to be double precision
	Make/O/T/N=(nTracks) Play_Date_UTC
	Make/O/N=(nTracks) Skip_Count
	Make/O/T/N=(nTracks) Skip_Date, Release_Date, Compilation
	Make/O/N=(nTracks) Artwork_Count
	Make/O/T/N=(nTracks) Sort_Album, Sort_Artist, Sort_Name, Persistent_ID, Explicit, Track_Type
	Make/O/T/N=(nTracks) Protected, Purchased, Location
	Make/O/N=(nTracks) File_Folder_Count, Library_Folder_Count, BPM
	Make/O/T/N=(nTracks) File_Type
	
	Concatenate/O/KILL wList,  MatT
	MatrixTranspose MatT
	String exam, colName, val
	// output from nokogiri is "x"=>"y", but we changed it to x___y
	String patn="([[:print:]]+)\_\_\_([[:print:]]+)"
	String regExp="[A-Za-z]"
	Variable j, len
	
	For(i = 0; i < nTracks; i += 1)
		Duplicate/O/T/RMD=[][i,i]/FREE matT, tempW
		Redimension/N=-1 tempW
//		Wave/T tempW
		for(j = 0; j < nWaves; j += 1)
			// examine tempW[j]
			exam = tempW[j]
			if(numtype(strlen(exam)) == 2)
				continue
			endif
			// find which column wave value belongs
			SplitString/E=(patn) exam, colName, val
			colName = ReplaceString(" ",colName,"_")
			// convert if required
			len = strlen(colName)
			if(numtype(len) == 2)
				continue
			elseif(len == 0)
				continue
			elseif(GrepString(val,regExp)==1)	//does it contain text?
				Wave/T/Z colTWave = $colName
				if(!WaveExists(colTWave))
					continue
				endif
				colTWave[i] = val
			else
				Wave/Z colNWave = $colName
				if(!WaveExists(colNWave))
					continue
				endif
				colNWave[i] = str2num(val)
			endif
		endfor
	endfor
	KillWaves/Z MatT
End

Function DateRead()
	WAVE/T/Z Play_Date_UTC, Date_Modified, Date_Added
	Variable nTracks = numpnts(Play_Date_UTC)
	Make/O/D/N=(nTracks) Play_Date_Calc, Date_Modified_Calc, Date_Added_Calc, Since_Played_Calc
	String olddate
	String expr="([[:digit:]]+)\-([[:digit:]]+)\-([[:digit:]]+)T([[:digit:]]+)\:([[:digit:]]+)\:([[:digit:]]+)Z"
	String yr,mh,dy,hh,mm,ss
	Variable currentTime = DateTime // specify as variable for speed and so it's stable
	Variable i

	for(i = 0; i < nTracks; i += 1)
		olddate = Play_Date_UTC[i]
		SplitString/E=(expr) olddate, yr,mh,dy,hh,mm,ss
		Play_Date_Calc[i] = date2secs(str2num(yr),str2num(mh),str2num(dy))+(3600*str2num(hh))+(60*str2num(mm))+str2num(ss)
		Since_Played_Calc[i] = currentTime - Play_Date_Calc[i]
		
		olddate = Date_Modified[i]
		SplitString/E=(expr) olddate, yr,mh,dy,hh,mm,ss
		Date_Modified_Calc[i] = date2secs(str2num(yr),str2num(mh),str2num(dy))+(3600*str2num(hh))+(60*str2num(mm))+str2num(ss)
		
		olddate = Date_Added[i]
		SplitString/E=(expr) olddate, yr,mh,dy,hh,mm,ss
		Date_Added_Calc[i] = date2secs(str2num(yr),str2num(mh),str2num(dy))+(3600*str2num(hh))+(60*str2num(mm))+str2num(ss)
	endfor
	// could offset Since_played_calc to minimum value here
	SetScale d 0, 0, "dat", Play_Date_Calc, Date_Modified_Calc, Date_Added_Calc, Since_Played_Calc
	Edit/N=DateWaves Play_Date_Calc, Date_Modified_Calc, Date_Added_Calc, Since_Played_Calc
	ModifyTable/W=DateWaves format=1 
End

Function Predictor()
	//1 day is 86400 s
	WAVE/Z Play_Count, Play_Date_Calc, Date_Added_Calc
	WAVE/T/Z Play_Date_UTC, Date_Added
	Variable totalCount, firstAdd, lastAdd, libLifetime, playRate
	WaveStats/Q Play_Count
	totalCount = V_Sum
	// get dates
	WaveStats/Q Date_Added_Calc
	firstAdd = V_minRowLoc	//p location of first added to library
	lastAdd = V_maxRowLoc	//p location of last added (was using plays but this didn't work)
	//
	String oldDate
	String expr="([[:digit:]]+)\-([[:digit:]]+)\-([[:digit:]]+)T([[:digit:]]+)\:([[:digit:]]+)\:([[:digit:]]+)Z"
	String yr,mh,dy,hh,mm,ss
	//
	oldDate = Date_Added[firstAdd]
	SplitString/E=(expr) oldDate, yr,mh,dy,hh,mm,ss
	firstAdd = date2secs(str2num(yr),str2num(mh),str2num(dy))	//sec at midnight before library start
	oldDate = Date_Added[lastAdd]
	SplitString/E=(expr) oldDate, yr,mh,dy,hh,mm,ss
	lastAdd = date2secs(str2num(yr),str2num(mh),str2num(dy)) + 86400	//sec at midnight (day after) library end
	//
	libLifetime = (lastAdd - firstAdd) / 86400	//in days
	playRate = totalCount / libLifetime	//plays per day
	//Make Histogram
	Make/N=(liblifetime)/O Date_Added_Calc_Hist	//1 day bin width
	Histogram/CUM/B={firstAdd,86400,libLifetime} Date_Added_Calc, Date_Added_Calc_Hist
	Duplicate/O Date_Added_Calc_Hist, Date_Added_Calc_pHist
	Date_Added_Calc_pHist = 1 / Date_Added_Calc_Hist	//inverse of histogram, probability that a given track is played
	
	Make/O/N=(libLifetime) Novelty_Data
	Novelty_Data = 0.001 * exp(-x / 25) //this is p=0.001 at present day
	// p=0.01 integrated to 12 expected plays at (lowest point) this was too high
	Sort Novelty_Data, Novelty_Data
	SetScale/P x firstadd, 86400, "dat", Novelty_Data
	Duplicate/O Date_Added_Calc_pHist, Date_Added_Calc_pHistAlt 
	//This didn't work because the integrated value for all tracks was then too large.
	//Date_Added_Calc_pHist +=Novelty_Data
	Date_Added_Calc_pHistAlt += Novelty_Data
	
	Variable nTracks = numpnts(Date_Added_Calc)
	Variable trackAdd
	Make/O/N=(nTracks) Expected_Plays
	Variable i
	
	For(i = 0; i < nTracks; i += 1)
		trackAdd = Date_Added_Calc[i]
		if(trackAdd < lastAdd - (365 * 86400))
		// find area under pHist that is limited by trackadd and lastdate
		// this is in seconds, so convert to days, then multiply by playrate
			Expected_Plays[i] = (area(Date_Added_Calc_pHist,trackAdd,lastAdd) / 86400) * playRate
		else
			Expected_Plays[i] = (area(Date_Added_Calc_pHistAlt,trackAdd,lastAdd) / 86400) * playRate
		endif
	endfor
	
	Duplicate/O Play_Count, PERatio
	// correct the Expected_Plays and Play_Count
	Play_Count[] = (Play_Count[p] == 0) ? 1 : Play_Count[p]
	Expected_Plays[] = (Expected_Plays[p] == 0) ? 0.2 : Expected_Plays[p]	//set it to 0.2 if it was 0 or absent it screws up calc
	PERatio[] /= Expected_Plays[p]	//this is plays divided by expected plays. >1 is heavily played.
	
	Wave/T Name
	Duplicate/O PERatio, PERsort, PERindex
	PERindex = x
	Duplicate/O Name, NamePERsort	//just to look at it
	Sort/R PERsort, PERsort,NamePERsort,PERindex
End

Function LibraryAnalysis()
	WAVE/Z Total_Time, Play_Count
	Make/O/D/N=(numpnts(Total_Time)) Cumulative_Time
	Cumulative_Time[] = Total_Time[p] * Play_Count[p]
	WAVE/Z/T Artist
	FindDuplicates/RT=UARaw Artist
	// This gives us a list of Unique Artists, but it is not case-sensitive
	Variable nUniqueArtist = numpnts(UARaw)
	Make/O/N=(nUniqueArtist)/FREE checkW = NaN, countW = NaN
	String UAName
	Variable found = 0, count = 0

	Variable i,j
	
	for(i = 0; i < nUniqueArtist; i += 1)
		UAName = UARaw[i]
		found = 0
		for(j = i; j < nUniqueArtist; j += 1)
			if(numtype(checkW[j]) != 2) // has an integer already been assigned to this row?
				continue
			endif
			if(cmpstr(UAName, UARaw[j]) == 0)
				if(found == 0)
					checkW[j] = i
					found += 1
				elseif(found > 0)
					checkW[j] = -1 // set the other matches to -1
				endif				
			endif
		endfor
	endfor
	countW[] = (checkW >= 0) ? 1 : NaN
	WaveTransform zapnans countW
	Make/O/N=(sum(countW))/T Unique_Artist
	count = 0
	for(i = 0; i < nUniqueArtist; i += 1)
		if(checkW[i] >= 0)
			Unique_Artist[count] = UARaw[i]
			count += 1
		endif
	endfor
	KillWaves/Z UARaw
	
	AccumulateStatsPerArtist()
	
	WAVE/Z UAPlay_Count, UACumulative_Time, UATrack_Count, UATotal_Since_Played
	WAVE/Z/T Unique_Artist
	
	Duplicate/O UAPlay_Count, UAPlay_Count_Sort
	Duplicate/O UACumulative_Time, UACumulative_Time_Sort
	Duplicate/O UATrack_Count, UATrack_Count_Sort
	Duplicate/O Unique_Artist, Unique_Artist_Sort
	Duplicate/O UATotal_Since_Played, UATotal_Since_Played_Sort
	Sort/R UACumulative_Time_Sort, UACumulative_Time_Sort, UAPlay_Count_Sort, UATrack_Count_Sort, Unique_Artist_Sort, UATotal_Since_Played_Sort
	// calculate "Impact factor" average plays per track for Unique Artist
	MatrixOp/O UAImpact_Factor = UAPlay_count / UATrack_Count
	MatrixOp/O UAImpact_Factor_Sort = UAPlay_count_Sort / UATrack_Count_Sort
	// calculate "Recent factor" average time since last played
	MatrixOp/O UARecent_Factor = UATotal_Since_Played / UATrack_Count
	MatrixOp/O UARecent_Factor_Sort = UATotal_Since_Played_Sort / UATrack_Count_Sort
End

STATIC Function AccumulateStatsPerArtist()
	WAVE/Z/T Unique_Artist, Artist
	WAVE/Z Cumulative_Time, Play_Count, Since_Played_Calc
	Variable nUniqueArtist = numpnts(Unique_Artist)
	Variable nTracks = numpnts(Play_Count)
	String artistName
	Make/O/D/N=(nUniqueArtist) UACumulative_Time, UATotal_Since_Played
	Make/O/N=(nUniqueArtist) UAPlay_Count, UATrack_Count
	Make/O/D/N=(nTracks)/FREE UACounter
	
	Variable i
	
	for(i = 0; i < nUniqueArtist; i += 1)
		artistName = Unique_Artist[i]
		UACounter[] = (CmpStr(artistName, Artist[p]) == 0) ? 1 : 0
		UATrack_Count[i] = sum(UACounter)
		UACounter[] = (CmpStr(artistName, Artist[p]) == 0) ? Play_Count[p] : 0
		UAPlay_Count[i] = sum(UACounter)
		UACounter[] = (CmpStr(artistName, Artist[p]) == 0) ? Cumulative_Time[p] : 0
		UACumulative_Time[i] = sum(UACounter)
		UACounter[] = (CmpStr(artistName, Artist[p]) == 0) ? Since_Played_Calc[p] : 0
		UATotal_Since_Played[i] = sum(UACounter)
	endfor
End

Function WritePlaylist(listlen)
	Variable listlen
	WAVE/Z PERindex,Total_Time
	WAVE/T/Z Name,Artist,Location
	
	KillWindow/Z Playlist
	NewNotebook/F=0/N=Playlist
	Notebook Playlist, text="#EXTM3U\r"
	
	String len,tit,art,loc
	Variable trackrow
	
	Variable i
	
	for(i = 0; i < listlen; i += 1)
		trackrow = PERindex[i]
		len = num2str(round(Total_Time(trackrow)/1000))
		tit = Name[trackrow]
		art = Artist[trackrow]
		loc = Location[trackrow]
		loc = ReplaceString("file://localhost/",loc,"")
		loc = ReplaceString("%20",loc," ")
		
		Notebook Playlist, text="#EXTINF:", text=len, text=",", text=tit, text=" - ", text=art, text="\r"
		Notebook Playlist, text=loc, text="\r"
	endfor
	SaveNotebook/I/S=3 Playlist as "Playlist.txt"
End

Function CSVExport()
	WAVE/Z/T Name,Artist,Album,Genre
	WAVE/Z Total_Time,Year,Play_Count
	if(!WaveExists(Name))
		return -1
	else
		Save/J/M="\n"/W Name,Total_Time,Artist,Album,Genre,Year,Play_Count
		return 0
	endif
End

// this function is to identify "Artists_For_Removal"
// works well using a subset of library, i.e. the checked playlist to work out which artists could be removed
Function FindArtistsForRemoval()
	WAVE/Z UAImpact_Factor_Sort, UATrack_Count_Sort, UARecent_Factor_Sort
	WAVE/Z/T Unique_Artist_Sort
	// this wave is in the order of impact factor
	Extract Unique_Artist_Sort, Artists_For_Removal, (UAImpact_Factor_Sort < 3.5 && UATrack_Count_Sort >6)
	// sort by recency
	Extract/FREE UARecent_Factor_Sort, Recency_For_Removal, (UAImpact_Factor_Sort < 3.5 && UATrack_Count_Sort >6)	
	Sort/R Recency_For_Removal, Artists_For_Removal
End

////////////////////////////////////////////////////////////////////////
// Utility functions
////////////////////////////////////////////////////////////////////////

STATIC Function CleanSlate()
	SetDataFolder root:
	String fullList = WinList("*", ";","WIN:65543")
	Variable allItems = ItemsInList(fullList)
	String name
	Variable i
 
	for(i = 0; i < allItems; i += 1)
		name = StringFromList(i, fullList)
		KillWindow/Z $name		
	endfor
	
	// Kill waves in root
	KillWaves/A/Z
	// Look for data folders and kill them
	DFREF dfr = GetDataFolderDFR()
	allItems = CountObjectsDFR(dfr, 4)
	for(i = 0; i < allItems; i += 1)
		name = GetIndexedObjNameDFR(dfr, 4, i)
		if(Stringmatch(name,"*Packages*") != 1)
			KillDataFolder $name		
		endif
	endfor
End