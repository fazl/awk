 
# gawk script to add up aqsa hours, from input file like so:
#

#250102, 0910-1250, 1315-1410, 1715-2000
#250103
#..{snip}..
#250112, 1000-1500, 1900-2015, +0200
#

#  cd /cygdrive/d/sandbox/qwork/mum/bills/carers/
#  awk -f aqsa-hours.awk < aqsa-hours.txt > out.txt && diff out.txt output.txt |less
#
#  After testing script changes update test file
#  mv out.txt output.txt 

#-----------------
# Cumulate given d_hhmm hours and minutes into given cumHhmm, handling 
# overflow of minutes into hours. Return new cumulative value.
#
function cumulateHhmm( cumHhMm,d_hhmm,   d_hh,d_mm,hh,mm){
    TRACE(sprintf("\n\tIn cumulateHhmm((cumHhMm=%s, d_hhmm=%s)\n", cumHhMm, d_hhmm))
    if(cumHhMm !~ RE_4DIGITS || d_hhmm !~ RE_4DIGITS ){ 
		ERR_QUIT(sprintf("Non hhmm values in cumHhMm='%s' and/or d_hhmm='%s'",cumHhMm,d_hhmm))
	}
	d_hh=substr(d_hhmm, 1, 2)+0
	d_mm=substr(d_hhmm, 3, 2)+0
    
	# mm_idx = length(cumHhMm)-1
	hh	= get_hhh_mm(cumHhMm,"h")
	mm	= get_hhh_mm(cumHhMm,"m")
	#mm	=substr(  cumHhMm, mm_idx, 2)+0
	hh += d_hh
	mm += d_mm
	if(60 <= mm){
		hh++
		mm = mm - 60
	}
	
	cumHhMm = sprintf("%02d%02d", hh, mm)
	TRACE(sprintf("\tNew cumulative hhmm: %s", cumHhMm))
	
	return cumHhMm
}

#-----------------
function get_hhh_mm(hhhmm,h_or_m){
#   TRACE(sprintf("In get_hhh_mm(hhhmm='%s',h_or_m='%s')",hhhmm,h_or_m))
    if(hhhmm !~ RE_HHHMM){ 
	    ERR_QUIT(sprintf("Bad hhhmm value '%s'",hhhmm))
        }
	mm_idx  = length(hhhmm)-1
	hhh	=substr(hhhmm, 1, mm_idx-1)+0
	mm	=substr(hhhmm, mm_idx, 2)+0
	if(h_or_m=="h"){
		return hhh
	}else if(h_or_m=="m"){
		return mm
    }
	ERR_QUIT(sprintf("Bad h_or_m: %s",h_or_m));
}

#-----------------
function strip_all_ws(s){
	return gensub("[ \t]+", "", "g", s)
}

#-----------------
# subtract start time from end time
#
function time_diff(tstart,tend,  hstart,hend,mstart,mend,hdiff,mdiff,hhmmDiff){


    if(tstart !~ RE_4DIGITS || tend !~ RE_4DIGITS ){ 
        ERR_QUIT(sprintf("Bad start '%s' and/or end '%s' time", tstart, tend))
    }

	TRACE(sprintf("\nSubtract %s from %s\n", tstart, tend))
	hstart=substr(tstart, 1, 2)+0
	hend  =substr(tend,   1, 2)+0
	mstart=substr(tstart, 3, 2)+0
	mend  =substr(tend,   3, 2)+0
	
    if( hstart <= hend ){
		hdiff = hend - hstart
	}else{
		ERR_QUIT(sprintf(": start hour %d later than end %d", hstart, hend))
	}
	
	if(mstart <= mend ){
		mdiff = mend - mstart
	}else if(0 < hdiff) {
		mdiff = 60 + (mend - mstart)
		hdiff--
	}else{
        ERR_QUIT(sprintf("mstart %02d later than mend %02d BUT then hstart %02d should be earlier than hend %02d", 
				          mstart, mend, hstart, hend))
	}
	
    TRACE(sprintf("sesh: %02d:%02d-%02d:%02d, ", 
                          hstart, mstart, hend, mend))
	
	hhmmDiff = sprintf("%02d%02d", hdiff, mdiff)
    TRACE(sprintf("calculated hhmmDiff=%s from hdiff=%02d, mdiff=%02d", hhmmDiff, hdiff, mdiff))
	
	return hhmmDiff
}

#-----------------
# - split session e.g. '1520-1540' into start and end times
# - subtract start from end
# - handle siro time e.g. '+0200' specially
# 
function CalcSessionTimeHhmm(d_hhmm,  a,delta){
	TRACE(sprintf("\n\tIn CalcSessionTimeHhmm(d_hhmm=%s)\n", d_hhmm))
	d_hhmm = strip_all_ws(d_hhmm)

	#Session start-end
	if(d_hhmm ~ "[0-9]{4}-[0-9]{4}"){
		split(d_hhmm, a, "-")
		delta = time_diff(a[1], a[2])
	}else 

	#Siro extra time
	if(d_hhmm ~ "+[0-9]{4}"){ 
	    delta = substr(d_hhmm,2)
	}else

	#Bad input
	{
		ERR_QUIT(sprintf("Session field '%s' not 'hhmm-hhmm' nor '+hhmm')",d_hhmm))

	}
	return delta
}

#-----------------
function ERR_QUIT(s){
	printf("ERR_QUIT: %s\n",s)
	exit
}


#-----------------
function TRACE(s){
    if(gTracing){
        printf("%s\n",s)
    }
}

#-----------------
function printField(i){
    printf("%s ",$i)
}


#=================

BEGIN   { 
    FS = "," 
    month_hhmm="0000"
    gTracing=0
    RE_4DIGITS="[0-9]{4}"
    RE_HHHMM="[0-9]{4,}"
    GBPPKR=360
    TRACE( "BEGIN" )
}

/^25[0-9]{4}/	{
	printField(1)
	dayHhmm="0000"
	if(NF>1){ 
		TRACE(sprintf( "%d sessions: \t(", NF-1 ))
		for(i=2; i<=NF; ++i){
			if(gTracing) printf("%s %s ", $i, i<NF ? "|" : "")
			dayHhmm = cumulateHhmm( dayHhmm, CalcSessionTimeHhmm($i) )
		}
        if(gTracing) printf(")\n")
		printf("%s dayHhmm=%s:%s\n", $1, substr(dayHhmm,1,2), substr(dayHhmm,3,2) )
		month_hhmm=cumulateHhmm( month_hhmm, dayHhmm )
		printf("=====\n")
	}else{
		print( "No sessions" )
	}
}

END{ 
    TRACE( "END" )
    printf("Month total hhmm = %s in %d days\n", month_hhmm, NR); 
    hh  = get_hhh_mm(month_hhmm,"h")
    mm  = get_hhh_mm(month_hhmm,"m")
    month_hrs = (hh+mm/60)  
    max_hrs= 7*NR
    printf("Month total hours = %s \n", month_hrs); 
    printf("Max for 7hours a day = %d hours\n", 7*NR); 
    printf("Month missing hours = %s hours\n", max_hrs-month_hrs); 
    printf("Percentage of GBP200 to return = %s%%\n", 100*((max_hrs-month_hrs)/max_hrs)); 
    printf("At GBPPKR=%d, to return is PKR %s\n", GBPPKR, 200*((max_hrs-month_hrs)/max_hrs)*GBPPKR);

}
