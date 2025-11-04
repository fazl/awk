# TODO Understand / test why total worked hours can be 3 digits or more without breaking code
# TODO Factor out helper functions from longer ones
# TODO Find an elegant replacement for TRACE using an array argument

#03/11/2025 Convenience: Allow sessions of form hhmm-MM (if hour part same)

 
# gawk script to add up aqsa hours, from input file like so:
#

#250102, 0910-1250, 1315-1410, 1715-2000
#250103
#..{snip}..
#250112, 1000-1500, 1900-2015, +0200
#

#  cd /cygdrive/d/sandbox/qwork/mum/bills/carers/awk
#  awk -f aqsa-hours.awk < aqsa-hours.txt > out.txt && diff out.txt output.txt |less
#
#  After testing script changes update test file
#  mv out.txt output.txt 

#-----------------
# Cumulate given d_hhmm hours and minutes into given cumHhmm, handling 
# overflow of minutes into hours. Return new cumulative value.
#
function cumulateHhmm( cum_hhmm,d_hhmm,   d_hh,d_mm,hh,mm){
    TRACE(sprintf("\n\tIn cumulateHhmm((cum_hhmm=%s, d_hhmm=%s)\n", cum_hhmm, d_hhmm))
    if(cum_hhmm !~ RE_4DIGITS || d_hhmm !~ RE_4DIGITS ){ 
        ERR_QUIT(sprintf("Non hhmm values in cum_hhmm='%s' and/or d_hhmm='%s'",cum_hhmm,d_hhmm))
    }
    d_hh=substr(d_hhmm, 1, 2)+0
    d_mm=substr(d_hhmm, 3, 2)+0
    
    # mm_idx = length(cum_hhmm)-1
    hh  = get_hhh_mm(cum_hhmm,"h")
    mm  = get_hhh_mm(cum_hhmm,"m")
    #mm =substr(  cum_hhmm, mm_idx, 2)+0
    hh += d_hh
    mm += d_mm
    if(60 <= mm){
        hh++
        mm = mm - 60
    }
    
    cum_hhmm = sprintf("%02d%02d", hh, mm)
    TRACE(sprintf("\tNew cumulative hhmm: %s", cum_hhmm))
    
    return cum_hhmm
}

#-----------------
function get_hhh_mm(hhhmm,h_or_m){
#   TRACE(sprintf("In get_hhh_mm(hhhmm='%s',h_or_m='%s')",hhhmm,h_or_m))
    if(hhhmm !~ RE_HHHMM){ 
        ERR_QUIT(sprintf("Bad hhhmm value '%s'",hhhmm))
        }
    mm_idx  = length(hhhmm)-1
    hhh =substr(hhhmm, 1, mm_idx-1)+0
    mm  =substr(hhhmm, mm_idx, 2)+0
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
# subtract start time from end time, both hhmm format
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
function CalcSessionTimeHhmm(session,  a,delta){
    TRACE(sprintf("\n\tIn CalcSessionTimeHhmm(session=%s)\n", session))
    session = strip_all_ws(session)

    #Session hhmm-hhmm (1st must precede 2nd)
    if(session ~ "[0-9]{4}-[0-9]{4}"){
        split(session, a, "-")
        delta = time_diff(a[1], a[2])
    }else 

    #Session hhmm-mm (convenience: 1st mm must precede 2nd)
    if(session ~ "[0-9]{4}-[0-9]{2}"){
        #same as prior but in a[2]:
        # 1) assume hh same as in a[1]
        # 2) mm must not precede a[1]
        split(session, a, "-")
        begin_mm = substr(a[1],3)+0 
        end_mm   = substr(a[2],1)+0 
        if(end_mm < begin_mm ){
            ERR_QUIT(sprintf("MM precedes mm for 'hhmm-MM' type session '%s'",session))
        }
        
        #prepend same hh to session end time
        begin_hh = substr(a[1],1,2) 
        end_hhmm = sprintf( "%s%s", begin_hh, a[2])
        TRACE(sprintf("begin_hh = %s", begin_hh))
        TRACE(sprintf("end_hhmm = %s", end_hhmm))
        
        
        delta = time_diff(a[1], end_hhmm)
                
    }else
    
    #Siro extra time eg +0130
    if(session ~ "+[0-9]{4}"){ 
        delta = substr(session,2)
    }else

    #Bad input
    {
        ERR_QUIT(sprintf("Unknown session type '%s' not 'hhmm-hhmm' nor 'hhmm-mm' nor '+hhmm')",session))

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
    gTracing=0                              #set to 1 for debugging
    FS = ","            
    workedHhmm="0000"
    RE_4DIGITS="[0-9]{4}"   
    RE_HHHMM="[0-9]{4,}"
    GBPPKR=360
    TRACE( "BEGIN" )
}

# Found FX rate
/^GBPPKR/   {
    equals_idx = index($0, "=")
    GBPPKR =substr($0, equals_idx+1)+0      #+0 converts string to num
    printf( "Rate PROVIDED: %d\n", GBPPKR )
    NR--                                    #ignore FX rate from rowcount     
}

# Data rows begin with date (YYMMDD)followed by session list (0700-0730, ...)
/^25[0-9]{4}/   {
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
        workedHhmm=cumulateHhmm( workedHhmm, dayHhmm )
        printf("=====\n")
    }else{
        print( "No sessions" )
    }
}

END{ 
    TRACE( "END" )
    printf("Month total hhmm = %s in %d days\n", workedHhmm, NR); 
    hh  = get_hhh_mm(workedHhmm,"h")
    mm  = get_hhh_mm(workedHhmm,"m")
    month_hrs = (hh+mm/60)  
    max_hrs= 7*NR
    printf("Month total hours = %s \n", month_hrs); 
    printf("Max for 7hours a day = %d hours\n", 7*NR); 
    printf("Month missing hours = %.3g hours\n", (max_hrs-month_hrs)+0);
    PERC=100*((max_hrs-month_hrs)/max_hrs);
    printf("Percentage of GBP200 to return = %.2f%%, or GBP %.2f\n", PERC, PERC*2); 
    printf("At GBPPKR=%d, to return is PKR %s\n", GBPPKR, 200*((max_hrs-month_hrs)/max_hrs)*GBPPKR);

}
