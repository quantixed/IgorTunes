#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//Extract data from iTunes Music Library.xml using ruby/nokogiri
//Script is called parsenoko.rb
//Load in data from tsv using
//LoadWave /N=Column/O/K=2/J/V={"\t"," $",0,0} 

Function iTunes()
	//this works but gives an error of null wave
	String wList=wavelist("Column*",";","")
	String wName=StringFromList(0,wList)
	Wave w0=$wName
	Variable nTracks=numpnts(w0)
	Variable nWaves=itemsinlist(wList)
	Variable i
	
	//remove first row (contains ColumnA etc.)
	For(i=0; i<nWaves; i+=1)
		wName=StringFromList(i,wList)
		DeletePoints 0,1, $wName
	EndFor
	
	Make /O /N=(nTracks) Track_ID
	Make /O /T /N=(nTracks) Name,Artist,Album_Artist,Composer,Album,Genre,Kind
	Make /O /N=(nTracks) Size,Total_Time,Disc_Number,Disc_Count,Track_Number,Track_Count,Year
	Make /O /T /N=(nTracks) Date_Modified,Date_Added
	Make /O /N=(nTracks) Bit_Rate,Sample_Rate,Play_Count
	Make /O /D /N=(nTracks) Play_Date	//needs to be double precision
	Make /O /T /N=(nTracks) Play_Date_UTC
	Make /O /N=(nTracks) Skip_Count
	Make /O /T /N=(nTracks) Skip_Date,Release_Date,Compilation
	Make /O /N=(nTracks) Artwork_Count
	Make /O /T /N=(nTracks) Sort_Album,Sort_Artist,Sort_Name,Persistent_ID,Explicit,Track_Type
	Make /O /T /N=(nTracks) Protected,Purchased,Location
	Make /O /N=(nTracks) File_Folder_Count,Library_Folder_Count
	
	Concatenate /O wList,  MatT
	MatrixTranspose MatT
	String exam,colName,val
	String patn="\"([[:print:]]+)\"\=\>\"([[:print:]]+)\""
	String regExp="[A-Za-z]"
	Variable j,len
	
	For(i=0; i<nTracks; i+=1)
		Duplicate /O /T /R=[][i] matT,w1
		Redimension /N=-1 w1
		Wave /T w1
		For(j=0; j<nWaves; j+=1)
			//examine w1[j]
			exam=w1[j]
			//find which column wave value belongs
			SplitString /E=(patn) exam, colName, val
			colName=ReplaceString(" ",colName,"_")
			//convert if required
			len=strlen(colName)
			If(numtype(len)==2)
				return 0
			ElseIf(GrepString(val,regExp)==1)	//does it contain text?
				Wave /T colTWave=$colName
				colTWave[i]=val
			Else
				Wave colNWave=$colName
				colNWave[i]=str2num(val)
			EndIf
		EndFor
	EndFor
	KillWaves w1,MatT
	//tidy-up
	For(i=0; i<nWaves; i+=1)
		wName=StringFromList(i,wList)
		KillWaves $wName
	EndFor
End

Function DateRead()
	Wave /T Play_Date_UTC, Date_Modified, Date_Added
	Variable nTracks=numpnts(Play_Date_UTC)
	Make/O /D /N=(nTracks) Play_Date_Calc, Date_Modified_Calc, Date_Added_Calc
	String olddate
	String expr="([[:digit:]]+)\-([[:digit:]]+)\-([[:digit:]]+)T([[:digit:]]+)\:([[:digit:]]+)\:([[:digit:]]+)Z"
	String yr,mh,dy,hh,mm,ss
	Variable i

	For(i=0; i<nTracks; i+=1)
		olddate=Play_Date_UTC[i]
		SplitString /E=(expr) olddate, yr,mh,dy,hh,mm,ss
		Play_Date_Calc[i]=date2secs(str2num(yr),str2num(mh),str2num(dy))+(3600*str2num(hh))+(60*str2num(mm))+str2num(ss)
		
		olddate=Date_Modified[i]
		SplitString /E=(expr) olddate, yr,mh,dy,hh,mm,ss
		Date_Modified_Calc[i]=date2secs(str2num(yr),str2num(mh),str2num(dy))+(3600*str2num(hh))+(60*str2num(mm))+str2num(ss)
		
		olddate=Date_Added[i]
		SplitString /E=(expr) olddate, yr,mh,dy,hh,mm,ss
		Date_Added_Calc[i]=date2secs(str2num(yr),str2num(mh),str2num(dy))+(3600*str2num(hh))+(60*str2num(mm))+str2num(ss)
	EndFor
	SetScale d 0, 0, "dat", Play_Date_Calc, Date_Modified_Calc, Date_Added_Calc
	Edit Play_Date_Calc, Date_Modified_Calc, Date_Added_Calc
	modifytable format=1 
End

Function Predictor()
	//1 day is 86400 s
	Wave Play_Count,Play_Date_Calc,Date_Added_Calc
	Wave/T Play_Date_UTC, Date_Added
	Variable totalcount,firstadd,lastadd,liblifetime,playrate
	Wavestats/Q Play_Count
	totalcount=V_Sum
	//get dates
	Wavestats/Q Date_Added_Calc
	firstadd=V_minRowLoc	//p location of first added to library
	lastadd=V_maxRowLoc	//p location of last added (was using plays but this didn't work)
	//
	String olddate
	String expr="([[:digit:]]+)\-([[:digit:]]+)\-([[:digit:]]+)T([[:digit:]]+)\:([[:digit:]]+)\:([[:digit:]]+)Z"
	String yr,mh,dy,hh,mm,ss
	//
	olddate=Date_Added[firstadd]
	SplitString /E=(expr) olddate, yr,mh,dy,hh,mm,ss
	firstadd=date2secs(str2num(yr),str2num(mh),str2num(dy))	//sec at midnight before library start
	olddate=Date_Added[lastadd]
	SplitString /E=(expr) olddate, yr,mh,dy,hh,mm,ss
	lastadd=date2secs(str2num(yr),str2num(mh),str2num(dy))+86400	//sec at midnight (day after) library end
	//
	liblifetime=(lastadd-firstadd)/86400	//in days
	playrate=totalcount/liblifetime	//plays per day
	//Make Histogram
	Make/N=(liblifetime)/O Date_Added_Calc_Hist	//1 day bin width
	Histogram/CUM/B={firstadd,86400,liblifetime} Date_Added_Calc,Date_Added_Calc_Hist
	Duplicate/O Date_Added_Calc_Hist Date_Added_Calc_pHist
	Date_Added_Calc_pHist=1/Date_Added_Calc_Hist	//inverse of histogram, probability that a given track is played
	
	Make/O/N=(liblifetime) Novelty_Data
	Novelty_Data=0.005*exp(-x/25) //this is p=0.005 at present day
	//p=0.01 integrated to 12 expected plays at (lowest point) this was too high
	Sort Novelty_Data Novelty_Data
	SetScale/P x firstadd,86400,"dat", Novelty_Data
	Duplicate/O Date_Added_Calc_pHist Date_Added_Calc_pHistAlt 
	//This didn't work because the integrated value for all tracks was then too large.
	//Date_Added_Calc_pHist +=Novelty_Data
	Date_Added_Calc_pHistAlt +=Novelty_Data
	
	Variable nTracks=numpnts(Date_Added_Calc)
	Variable trackadd
	Make/O/N=(nTracks) Expected_Plays
	Variable i
	
	For(i=0; i<nTracks; i+=1)
		trackadd=Date_Added_Calc[i]
		If(trackadd < lastadd-(365*86400))
		//find area under pHist that is limited by trackadd and lastdate
		//this is in seconds, so convert to days, then multiply by playrate
			Expected_Plays[i]=(area(Date_Added_Calc_pHist,trackadd,lastadd)/86400)*playrate
		Else
			Expected_Plays[i]=(area(Date_Added_Calc_pHistAlt,trackadd,lastadd)/86400)*playrate
		EndIf
	EndFor
	
	Duplicate/O Play_Count PERatio
	//correct the Expected_Plays and Play_Count
	Play_Count = (Play_Count==0) ? 1 : Play_Count
	Expected_Plays = (Expected_Plays==0) ? 0.2 : Expected_Plays	//set it to 0.2 if it was 0 or absent it screws up calc
	PERatio /=Expected_Plays	//this is plays divided by expected plays. >1 is heavily played.
	
	Wave/T Name
	Duplicate/O PERatio PERsort,PERindex
	PERindex=x
	Duplicate/O Name NamePERsort	//just to look at it
	Sort/R PERsort PERsort,NamePERsort,PERindex
End

Function WritePlaylist(listlen)
	Variable listlen
	Wave PERindex,Total_Time
	Wave/T Name,Artist,Location
	
	DoWindow/K/Z Playlist
	NewNotebook/F=0/N=Playlist
	Notebook Playlist, text="#EXTM3U\r"
	
	String len,tit,art,loc
	Variable trackrow
	
	Variable i
	
	For(i=0; i<listlen; i+=1)
		trackrow=PERindex[i]
		len=num2str(round(Total_Time(trackrow)/1000))
		tit=Name[trackrow]
		art=Artist[trackrow]
		loc=Location[trackrow]
		loc=ReplaceString("file://localhost/",loc,"")
		loc=ReplaceString("%20",loc," ")
		
		Notebook Playlist, text="#EXTINF:", text=len, text=",", text=tit, text=" - ", text=art, text="\r"
		Notebook Playlist, text=loc, text="\r"
	EndFor
	SaveNotebook/I/S=3 Playlist as "Playlist.txt"
End