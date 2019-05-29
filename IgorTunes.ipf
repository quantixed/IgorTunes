#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Process data from iTunes Library.xml using bash script and ruby/nokogiri

////////////////////////////////////////////////////////////////////////
// Menu items
////////////////////////////////////////////////////////////////////////
Menu "Macros"
	"Load iTunes Library Data...", /Q, iTunes()
	"Make Algrorithmic Playlist...", /Q, iTunesPlayList()
End

Function iTunes()
	CleanSlate()
	LoadTSVAndProcess()
	DateRead()
	Predictor()
End

Function iTunesPlaylist()
	CleanSlate()
	LoadTSVAndProcess()
	DateRead()
	Predictor()
	WritePlaylist(50)
End

Function LoadTSVAndProcess()
	// load TSV file (result from bash script
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
	// Doing it this way because other methods, e.g. wave reference wave would be slower(?)
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
	Make/O/D/N=(nTracks) Play_Date_Calc, Date_Modified_Calc, Date_Added_Calc
	String olddate
	String expr="([[:digit:]]+)\-([[:digit:]]+)\-([[:digit:]]+)T([[:digit:]]+)\:([[:digit:]]+)\:([[:digit:]]+)Z"
	String yr,mh,dy,hh,mm,ss
	Variable i

	for(i = 0; i < nTracks; i += 1)
		olddate = Play_Date_UTC[i]
		SplitString/E=(expr) olddate, yr,mh,dy,hh,mm,ss
		Play_Date_Calc[i] = date2secs(str2num(yr),str2num(mh),str2num(dy))+(3600*str2num(hh))+(60*str2num(mm))+str2num(ss)
		
		olddate = Date_Modified[i]
		SplitString/E=(expr) olddate, yr,mh,dy,hh,mm,ss
		Date_Modified_Calc[i] = date2secs(str2num(yr),str2num(mh),str2num(dy))+(3600*str2num(hh))+(60*str2num(mm))+str2num(ss)
		
		olddate = Date_Added[i]
		SplitString/E=(expr) olddate, yr,mh,dy,hh,mm,ss
		Date_Added_Calc[i] = date2secs(str2num(yr),str2num(mh),str2num(dy))+(3600*str2num(hh))+(60*str2num(mm))+str2num(ss)
	endfor
	SetScale d 0, 0, "dat", Play_Date_Calc, Date_Modified_Calc, Date_Added_Calc
	Edit/N=DateWaves Play_Date_Calc, Date_Modified_Calc, Date_Added_Calc
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
	Novelty_Data = 0.005 * exp(-x / 25) //this is p=0.005 at present day
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