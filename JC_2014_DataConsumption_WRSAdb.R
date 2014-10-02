#-------------------------------------------------------INPUTS--------------------------------------------------------#
#In the ideal world, users should only need to put inputs here and be able to get results out of the 'black box' below using existing functions.
DBpassword=''#Always leave blank when saving for security and because changes annually. Contact Sarah Judson for current password.
DBuser=''#ditto as with DBpassword
DBserver=''#ditto as with DBpassword
#this is a change#SWJ annotate to allow branch access

#FILTERS
##from most to least specific
AllData='N'#set to 'Y' (meaning 'yes') if you want to query all sites (note this is quite time consuming and large, use provided filters wherever possible)
sitecodes=''#c('EL-LS-8134','EL-SS-8127','MN-LS-1004','MN-SS-1104','MS-SS-3103','XE-RO-5086','XN-LS-4016','XN-SS-4128','XS-LS-6029' )#QAduplicateSites#c('AR-LS-8003','AR-LS-8007', 'TP-LS-8240')#sites for NorCalTesting
years=c('2013')#as character, not number
dates=''##example:c('05/05/2005')
projects=c('WRSA')# most useful for separating NorCal and WRSA, note that abbreviations differ between Access and SQL/FM
protocols=c('WRSA14')#for separating differences in overall protocol, may not be relevant for some parameters
hitchs=c('')#NOT WORKING YET, hitch and crew level generally maintained by Access not SQL
crews=c('R1')#NOT WORKING YET, hitch and crew level generally maintained by Access not SQL
filter=''#custom filter (need working knowledge of Parameter:Result pairs and SQL structure; example: "(Parameter='ANGLE' and Result>50) OR (Parameter='WETWID' and Result<=0.75))"
UIDs='BLANK'#custom filter (need working knowledge of primary keys)
#NorCal settings: years=c('2013','2014');projects='NorCal';protocols=c('WRSA14','NRSA13')

#PARAMETERS
#specify if desired (will make queries less intensive):
AllParam='Y'#set to 'Y' (meaning 'yes') if you want to query all parameters
testP=c('ANGLE','APPEALING','ALGAE')#test, one from each level of table
bankP=c('ANGLE','UNDERCUT','EROSION','COVER','STABLE')



#--------------------------------------------------------SETUP--------------------------------------------------------#
#LOAD required packages#
requiredPACKAGES=c('reshape', 'RODBC','ggplot2','grid','gridExtra','xlsx','sqldf')
for (r in 1:length(requiredPACKAGES)){
  if ((requiredPACKAGES[r] %in% installed.packages()[,1])==FALSE){install.packages(requiredPACKAGES[r])}#auto-install if not present
  library(requiredPACKAGES[r],character.only = TRUE)
}

#default working directory is the location of the Rproject which is custom to each collaborator and should automatically be set when project is loaded
#setwd('\\\\share1.bluezone.usu.edu\\miller\\buglab\\Research Projects\\BLM_WRSA_Stream_Surveys\\Technology\\Output\\WRSA')#SWJ to do: map more dynamically but securely
#setwd('C:\\Users\\Sarah\\Desktop\\NAMCdevelopmentLocal\\WRSA')##Sarah desktop



##Establish an ODBC connection##
#the db was created in SQL Server Manager on 11/19/2013 by Sarah Judson#
wrsaConnectSTR=sprintf("Driver={SQL Server Native Client 10.0};Server=%s;Database=WRSAdb;Uid=%s; Pwd=%s;",DBserver,DBuser, DBpassword)
wrsa1314=odbcDriverConnect(connection = wrsaConnectSTR)
#SWJ to do: throw this into a function that also prompts for server and password if missing (='')
#SWJ to do: throw the function into a separate referenced script because multiple files are using this

options(stringsAsFactors=F,"scipen"=50)#general option, otherwise default read is as factors which assigns arbitrary number behind the scenes to most columns

#SQL assistance functions
#loaded from a separate R script
source('FNC_tblRetrievePVT.R')
#common sQL strings that need to be incorporated:
##(select * from tblVERIFICATION where PARAMETER='site_id') v on v.UID=tblPOINT.uid

#-------------------------------------------------------Jennifer's custom code-------------------------------------------#
tbl2=addKEYS(tblRetrieve(Parameter='INCISED',Projects='NORCAL',Years='2013'),Columns=C('SITE_ID','UID')
tblRetrieve(Parameter='CONDUCTIVITY',Projects='NORCAL',Years='2013')
cast(tbl,'SITE_ID+UID~PARAMETER',value='RESULT',fun.aggregate='mean')# '' are around the entire rows #default to counts if more than one result for each row # can add mean as I did here
             
             
trial<-sqlQuery(wrsa1314,"select * from tblPOINT where PARAMETER='slope'") #basic select query must use "
getmeta<-sqlQuery(wrsa1314,"select * from tblMETADATA")#### getting the metadata table
             

#--------------------------------------------------------SQL RETRIEVE--------------------------------------------------------#
#SQL tables are created and imports managed via an independent R scripts (createNRSA1314db_SWJ.r)
dbTBL=sqlTables(wrsa1314, tableType="TABLE")#all possible tables
dbCOL=sqlColumns(wrsa1314,"tblPOINT")#column names (similar structure for each tbl since flat)
dbPARAM=sqlQuery(wrsa1314,"Select SAMPLE_TYPE, PARAMETER, LABEL,VAR_TYPE from tblMETADATA where ACTIVE='TRUE'")#parameter names (SWJ to do: iterate over Sample_Type groups to generate pivots)
tmpTYPE=as.character(unique(dbPARAM$SAMPLE_TYPE))
dbTYPE=substr(tmpTYPE,1,nchar(tmpTYPE) - 1)#substr to get rid of the random "x" at the end of each name

#select samples
UIDs=UIDselect(ALL=AllData,Filter=filter,UIDS='',SiteCodes=sitecodes,Dates=dates,Years=years,Projects=projects,Protocols=protocols)
#SWJ to do: add additional filters
#SWJ to do: prompt for data entry (mini-GUI)


#retrieve all data as a single list table
UnionTBL=tblRetrieve(Table='',Parameters='',ALLp=AllParam,UIDS=UIDs,ALL=AllData,Filter=filter,SiteCodes=sitecodes,Dates=dates,Years=years,Projects=projects,Protocols=protocols)


Sites=subset(UnionTBL,select=c(UID,RESULT),subset=PARAMETER=='SITE_ID'); colnames(Sites)=c('UID','SITE_ID')#!append sitecode instead of UID to make the table more readable --> migrate this into tblRetrieve or some kind of "convert" function
UnionTBL=merge(UnionTBL,Sites)
UnionTBL$SITE_ID=as.character(UnionTBL$SITE_ID)
UnionTBL1=merge(UnionTBL,UIDs)#limit by UIDs ("select samples)

#retrieve desired tables
#EXAMPLES of tblRetrieve function# (note: parameter lists were specified in the "Inputs" section at the beginning of this script)
tblREACH=tblRetrieve('tblREACH')#not specifying parameters will retrieve the entire table
tblREACHtest=tblRetrieve('tblREACH',testP)
tblPOINTbank=tblRetrieve('tblPOINT',bankP)
#SWJ to do - could add GIS tables (pull from PilotDB if possible)
#SWJ to do - could add logistics tables (pull from UTBLM.accdb)


#retrieve all possible tables by protocol groups and pivot
#for exploratory purposes to review data and determine expected values, not intended to replace modular SQL solutions for multiple tools
tblCOL=c('UID', 'PARAMETER','RESULT')
pvtCOL='UID %s ~ PARAMETER';pvtCOLdefault=sprintf(pvtCOL,'')
AggLevel='Site'#options = Site, All
params_N=subset(dbPARAM, subset=VAR_TYPE=='NUMERIC')
params_C=subset(dbPARAM, subset=VAR_TYPE=='CHARACTER')#also used in boxplot QA (with some modifications)
for (t in 1:nrow(dbTBL)){
  tblNAME=dbTBL$TABLE_NAME[t]
  tbl=tblRetrieve(tblNAME)#could simplify and use UnionTBL
  if(min(c('SAMPLE_TYPE',tblCOL) %in% colnames(tbl))==1){#if minimum needed columns are present, proceed, otherwise assume it is a pivoted or otherwise human readable table
      if(tblNAME=='tblPOINT'){tblCOL2=append(tblCOL,c('TRANSECT','POINT'), after=1); pvtCOL2=sprintf(pvtCOL,'+ TRANSECT + POINT')
  } else if (tblNAME=='tblTRANSECT'){tblCOL2=append(tblCOL,'TRANSECT', after=1); pvtCOL2=sprintf(pvtCOL,'+ TRANSECT')
  } else {tblCOL2=tblCOL; pvtCOL2=pvtCOLdefault}
  for(s in 1:length(dbTYPE)){#this hits it with a hammer, could narrow down via xwalk to only the relevant sample_types
    #raw data (one value per pivot cell which is per transect/point per parameter)
    tblTYPE=subset(tbl,select=tblCOL2, subset=SAMPLE_TYPE %in% dbTYPE[s])
    tblPVT=cast(tblTYPE, eval(parse(text=pvtCOL2)))#very predictable structure except for the input table and whether transect and point need to be included in the columns = possibly plug into function
    if(nrow(tblPVT)>1 & is.na(tblPVT$UID)==FALSE){#only assign pivot to variable if not empty and only dive into subsequent if not empty
      assign(sprintf('%s_pvt_%s',tblNAME,dbTYPE[s]),tblPVT) 
    #missing data checks (counted values per pivot cell which is per site per parameter)
    tblPVTm=cast(tblTYPE, eval(parse(text=pvtCOLdefault)),fun.aggregate='length')
      assign(sprintf('%s_pvtMISSINGcnt_%s',tblNAME,dbTYPE[s]),tblPVTm)
      #missing context of expected number of values...need to compare to metadata
    #summarized categorical data (counted values per pivot cell which is per site per parameter+result)
    tblCAT=subset(tblTYPE,subset=PARAMETER %in% params_C$PARAMETER)
      if(nrow(tblCAT)>1){#only assign pivot to variable if not empty and only dive into subsequent if not empty
        pvtCOL3=paste(pvtCOLdefault,"+ RESULT")
        tblCAT$CNT=1
        tblPVTc=cast(tblCAT, eval(parse(text=pvtCOL3)),fun.aggregate='length', value='CNT')
        assign(sprintf('%s_pvtCATdistb_%s',tblNAME,dbTYPE[s]),tblPVTc)
      }
    #summarzied quantitative data (average values per pivot cell which is per site per parameter)
    tblNUM=subset(tblTYPE,subset=PARAMETER %in% params_N$PARAMETER )
      if(nrow(tblNUM)>1){#only assign pivot to variable if not empty and only dive into subsequent if not empty
        if(AggLevel=='Site'){pvtCOL4='UID + PARAMETER ~.'; pvtCOL5='RESULT~UID + PARAMETER'; colUID='tblPVTnSUM2$UID';nameUID=c('UID','PARAMETER','Quant1','Quant2')} else if (AggLevel=='All') {pvtCOL4='PARAMETER ~.';pvtCOL5='RESULT~PARAMETER';colUID='';nameUID=c('PARAMETER','Quant1','Quant2')}
        tblNUM$RESULT=as.numeric(tblNUM$RESULT)
        tblNUM=subset(tblNUM,subset= is.na(RESULT)==FALSE)#apparently not removing NAs during pivot aggregation, so done manually because causing errors - have to do after conversion to number
        tblPVTn=cast(tblNUM, eval(parse(text=pvtCOLdefault)),fun.aggregate='mean')#pivot reach average by site
        tblPVTnSUM1=cast(tblNUM, eval(parse(text=pvtCOL4)),fun.aggregate=c(length,mean,median,min,max,sd),fill='NA') # pivot summary stats by all sites combined or individual sites
        tblPVTnSUM2=aggregate(eval(parse(text=pvtCOL5)),data=tblNUM,FUN='quantile',probs=c(0.25,0.75),names=FALSE)
        tblPVTnSUM2=data.frame(cbind(eval(parse(text=colUID)),tblPVTnSUM2$PARAMETER,tblPVTnSUM2$RESULT[,1],tblPVTnSUM2$RESULT[,2]));colnames(tblPVTnSUM2)=nameUID
        tblPVTnSUM=merge(tblPVTnSUM1,tblPVTnSUM2,by=setdiff(nameUID,c('Quant1','Quant2')))
        #need to do this by UID for WRSA13 QA duplicate comparison
        assign(sprintf('%s_pvtQUANTmean_%s',tblNAME,dbTYPE[s]),tblPVTn)
        assign(sprintf('%s_pvtSUMMARYn_%s_%s',tblNAME,dbTYPE[s],AggLevel),tblPVTnSUM)
        
      }
    }
  }
}
}

#export results
QUANTtbls=grep('pvtQUANTmean',ls(),value=T)
for (t in 1:length(QUANTtbls)){
  write.csv(eval(parse(text=QUANTtbls[t])),sprintf('%s.csv',QUANTtbls[t]))#could merge-pvtQUANTmean_, but I like them grouped by categories
}
#could export _pvtCATdistrb_, but I find the Categorical variables not to be readily interpretable (also didn't make a summary table for them yet because of this)
rm(pvtSUMMARYn)
nSUMtbls=grep('pvtSUMMARYn',ls(),value=T)
nSUMtbls=grep(AggLevel,nSUMtbls,value=T)
for (t in 1:length(nSUMtbls)){
  tblPVTnSUM=eval(parse(text=nSUMtbls[t]))
  if( ncol(tblPVTnSUM)==1) {} else{
    if (t==1) {pvtSUMMARYn=tblPVTnSUM} else {pvtSUMMARYn=rbind(pvtSUMMARYn,tblPVTnSUM)}
  }
  write.csv(pvtSUMMARYn,sprintf('pvtSUMMARYn_%s.csv',AggLevel))
}



#why is tblPOINt_pvt_BANKW coming thru with just ones?

#Close ODBC connection when done talking to SQL Server
odbcClose(wrsa1314); rm(DBpassword); rm(DBserver); rm(DBuser)

#--------------------------------------------------------CUSTOM PIVOT VIEWS--------------------------------------------------------#
##RESHAPE to PIVOT## 
#EXAMPLES of both methods#
#SQL option ('View' creation to copy/paste)
bankPVTstr=PVTconstruct(parameters=bankP,tblTYPE='tblPOINT', filter="POINT in ('LF','RT')");print(bankPVTstr)#- need permission from Sarah Judson and to reopen ODBC before saving Views for permanent use in SQL Server
  #retrieve said query from SQL
    wrsa1314_2=odbcDriverConnect(connection = wrsaConnectSTR)
    tblPOINTbankPVTs=sqlQuery(wrsa1314_2,bankPVTstr)
    odbcClose(wrsa1314_2)
#R option (cast)
tblPOINTbankPVTr=cast(subset(tblPOINTbank,select=c(UID, TRANSECT,POINT,PARAMETER,RESULT)), UID + TRANSECT + POINT ~ PARAMETER)#very predictable structure except for the input table and whether transect and point need to be included in the columns = possibly plug into function


#--------------------------------------------------------ANALYSIS--------------------------------------------------------#
##AGGREGATION##
#EXAMPLES#
#count number of records per parameter to check for missing data
qastatsBANK_CNTcast=cast(tblPOINTbank, UID ~ PARAMETER, value='RESULT', fun.aggregate=length)#should this filter out NULLs or flags? does EPA write a line for each record even if no value recorded?
qastatsBANK_CNTagg=aggregate(tblPOINTbank,FUN='length', by=list(tblPOINTbank$UID,tblPOINTbank$TRANSECT,tblPOINTbank$POINT))
#cast seems like the more elegant solution
#convert numerics before performing stats
tblPOINTbankNUM=subset(tblPOINTbank,subset= is.na(as.numeric(as.character(tblPOINTbank$RESULT)))==FALSE);tblPOINTbankNUM$RESULT=as.numeric(as.character(tblPOINTbankNUM$RESULT))
qastatsBANK_MEANcast=cast(tblPOINTbankNUM, UID ~ PARAMETER, value='RESULT', fun.aggregate=mean)

#iteration example
list=c(1,2,4,6,7)
for (i in 1:length(list)){
  if(list[i]<5){
    print(list[i] + 2)
  } else {print(list[i] *5 )}
}


##QA checks##
##!QA checks moved to DataQA_WRSA


##GRTS adjusted weights##
#TBD# Pull from UTBLM

##EPA aquamet##
#TBD# Pull from aquamet 1.0 provided by Tom Kincaid and Curt Seegler via Marlys Cappaert
#go to NRSAmetrics_SWJ.R

##OE computation##
#TBD# Pull from VanSickle

#Predicted WQ##
#TBD#  Pull from UTBLM, John Olson/Ryan Hill

##NMDS##
#TBD#

##GIS connections##
#TBD#


#--------------------------------------------------------REPORTING--------------------------------------------------------#
##Figures and Tables##
#TBD# Pull from UTBLM

##SWEAVE##
#TBD#

##BibTex##
#TBD#


#--------------------------------------------------------sarah's Gibberish-------------------------------------------------------#
# #pseudocode - consume data from flat db
# #ODBC connection to SQL server WRSAdb
# #import via SQL string call - include filters on data (i.e. hitch, project, crew)
# #mash (merge) tables (?) OR pvt for viewing (?) -- SQL: view, Access: Query
# ##ex (old): merge(EVENT3,subset(original,select=selectCOLparse),by="SampleID")
# ##demonstrate complexity of calling by column name vs. parameter text in both SQL and R
# ###SQL: filter query --> possibly PIVOT to view --> aggregate query
# ###R: filter strings, apply across multiple --> PVT to view --> aggregate OR run predefined(EPA,R)/custom functions
# ###common: convert numerics
# ###differences: null handling, reproducability and documentation
# ###leaning (SWJ): R for dynamic queries/code, reproducability and 'instant' documentation; in either mode, PIVOTS should be treated as temporary views for scanning data, not basis for subsequent queries because they will then be tied to column names 
# ##ex: library('reshape'); cast(data, x~y)
# #separate numbers and characters (will R autodetect?) -- SQL: Cast/Convert
# #filter by parameter and run metric  -- SQL: sub-queries
# ##ex: subset(tblPOINT, subset=Parameter=='Angle')
# ##could set it up so that user doesn't even need to which table
# ##set up to easily call the parameters table and other metadata (crew, hitch) tables --> will we store crew and hitch info in sampletracking access or SQL server?
# #aggregate by site and crew  -- SQL: group by (aggregate) query
# ##ex (old): aggregate(x=as.numeric(sampDATAin$SampleID),FUN=agg3,by=list(sampDATAin$SamplingEvent,sampDATAin$Station,sampDATAin$WaterYear))
# #report -- R SWEAVE vs. Access report vs. Crystal Reports
# 
# #check for existing packages
# #install.packages('reshape')
# library('reshape')
# 
# #establish an ODBC connection#
# #the db was created in SQL Server Manager on 11/19/2013
# #manually set up the database (WRSAdb) and the odcb connection (WRSAconnect)
# library("RODBC")
# user='feng'
# #ENTER DB PASSWORD
# print ("Please enter Password")
# password='Something~Clever!@'#("Enter Password")#raw_input() in python, not sure of R equivalent #http://rosettacode.org/wiki/Dynamic_variable_names#R
# nrsa1314<-odbcConnect("WRSAconnect",uid=user,pwd=password)
# #SQL assistance functions
# #inLOOP: concatenate list objects into an "IN" string for insertion into queries
# inLOOP=function(inSTR) {
#   inSTR=unlist(inSTR)
#   for (i in 1:length(inSTR)){
#     comma=ifelse(i==length(inSTR),'',',')
#     STRl=sprintf("'%s'%s",inSTR[i],comma)
#     if(i==1){loopSTR=STRl} else{loopSTR=paste(loopSTR,STRl)}
#   }   
#   return(loopSTR) 
# }
# #tblRetrieve: standard retrieval query
# tblRetrieve=function(table, parameters=''){
#   if(parameters==''){parameters=sqlQuery(nrsa1314,sprintf("select distinct parameter from %s", table))}
#   sqlTABLE=sqlQuery(nrsa1314, sprintf('select * from %s where UID in (%s) and parameter in (%s)',table, inLOOP(UIDs),inLOOP(parameters)))
#   return(sqlTABLE)#could auto return the pivoted view, but currently assuming that is for on the fly viewing and is not the easiest way to perform metrics
# }
# 
# 
# #FILTERS
# ##from most to least specific
# sitecodes=c('AR-LS-8003','AR-LS-8007', 'TP-LS-8240')
# dates=c('05/05/2005')
# hitchs=c('')
# crews=c('R1')
# projects=c('NRSA')
# 
# 
# 
# #select samples
# UIDs=sqlQuery(nrsa1314, sprintf("select distinct UID from tblVERIFICATION 
#                                 where (active='TRUE') 
#                                 AND ((Parameter='SITE_ID' and Result in (%s)) OR (Parameter='DATE_COL' and Result in (%s)))"
#                                 ,inLOOP(sitecodes),inLOOP(dates)))
# #SWJ to do: add additional filters
# #SWJ to do: prompt for data entry (mini-GUI)
# 
# #PARAMETERS
# #specify if desired (will make queries less intensive):
# testP=c('ANGLE','APPEALING','ALGAE')#test, one from each level of table
# bankP=c('ANGLE','UNDERCUT','EROSION','COVER','STABLE')
# 
# #retrieve desired tables
# tblREACH=tblRetrieve('tblREACH')#not specifying parameters will retrieve the entire table
# tblREACHtest=tblRetrieve('tblREACH',testP)
# tblPOINTbank=tblRetrieve('tblPOINT',bankP)
# 
# #pivot tables for viewing
# tblPOINTbankPVT=cast(subset(tblPOINTbank,select=c(UID, TRANSECT,POINT,PARAMETER,RESULT)), UID + TRANSECT + POINT ~ PARAMETER)#very predictable structure except for the input table and whether transect and point need to be included in the columns = possibly plug into function
# 
# #further subset data in custom ways
# 
# #compute aggregate statistics
# #count number of records per parameter to check for missing data
# qastatsBANK_CNTcast=cast(tblPOINTbank, UID ~ PARAMETER, value='RESULT', fun.aggregate=length)#should this filter out NULLs or flags? does EPA write a line for each record even if no value recorded?
# qastatsBANK_CNTagg=aggregate(tblPOINTbank,FUN='length', by=list(tblPOINTbank$UID,tblPOINTbank$TRANSECT,tblPOINTbank$POINT))
# #cast seems like the more elegant solution
# #convert numerics before performing stats
# tblPOINTbankNUM=subset(tblPOINTbank,subset= is.na(as.numeric(as.character(tblPOINTbank$RESULT)))==FALSE);tblPOINTbankNUM$RESULT=as.numeric(as.character(tblPOINTbankNUM$RESULT))
# qastatsBANK_MEANcast=cast(tblPOINTbankNUM, UID ~ PARAMETER, value='RESULT', fun.aggregate=mean)
# 
# #plugging into aquamet
# 
# #end ODBC connection#
# odbcClose(nrsa1314)