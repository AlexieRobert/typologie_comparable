/********************************************************************************************************************************************/
/* Programme de création d'une typologie de trajectoires professionnelles comparables entre plusieurs cohortes								*/
/* Auteurs : Zora Mazari et Alexie Robert																									*/
/* Données mobilisées : Enquêtes Génération 1998, 2004 et 2010 sur les 7 premières années de vie active 									*/
/* Méthode : Voir ouvrage Céreq études n°39 "Construction et usages de typologies de trajectoires dans une perspective comparative :		*/
/* 			 Le cas des enquêtes Génération 1998, 2004 et 2010" écrit par Zora MAZARI et Alexie ROBERT                                      */
/********************************************************************************************************************************************/

libname baseentree "[]" ; /* remplacer [] par dossier contenant les bases d'analyses comparables */
libname basesortie "[]";  /* remplacer [] par dossier où l'on veut sauvegarder certaines bases de résultats */

libname macro "[]"  ; /*mettre à la place de [] le nom du dossier contenant les macros de l'Insee à télécharger https://www.insee.fr/fr/information/2021906*/
options sasmstore = macro mstored ;


/***************************************************************************************************************************/
/* Préparation de la base d'analyse pour la Génération 1998 (dilatation du calendrier pour la gestion du service national) */
/***************************************************************************************************************************/

* isoler les individus ayant une séquence de service national (emploi+non emploi);
proc sort data=baseentree.g987seqcomp;by ident nseq;run; /*base de description des séquences d'emploi */
proc sort data=baseentree.g987noncomp;by ident nseq;run; /* base des séquences de non-emploi (chômage, inactivité, reprise d'études, etc.) */

data duree_sn98 (rename=(duree=dursn98) drop=cal nseq);
	set baseentree.g987noncomp (keep=ident duree cal nseq);
	where cal="19"; /* séquences de service national */
	nbseqsn=nseq; 
run;

proc sort data=duree_sn98 nodupkey dupout=a;by ident;run;

data sn98;
	merge baseentree.g987seqcomp baseentree.g987noncomp;
	by ident nseq;
run;

proc sort data=sn98;by ident nseq;run;
proc sort data=duree_sn98;by ident;run;
data sn98_v1;
	merge sn98 duree_sn98;
	by ident;
	if ident="R0344651" then dursn98=31; /*seul individu qui avait deux séquences de SN qu'on rassemble en une */
	if dursn98 ne . then output;
run; * 12 342 séquences // 2 127 individus;

data sn98_v2;
	set sn98_v1;
	if cal="19" then delete;
run;

proc sort data=sn98_v2;by ident nseq;run;
data sn98_v3;
	set sn98_v2;
	by ident nseq;
	if first.ident then nseq2=1;
	else if first.nseq then nseq2+1;
	nseq3=compress("0"||nseq2);
run;

data nmtot (keep=ident nmtot id);
	set baseentree.G987INDCOMP (keep=ident nmcho nmemp nmetu nmfor nmina nmsn id if_05);
	nmtot=if_05-id+1;
	nmtot2=nmcho+nmemp+nmetu+nmfor+nmina+nmsn;
run;

proc sort data=sn98_v3;by ident nseq2;run;
proc sort data=nmtot;by ident;run;
data sn98_v4;
	merge sn98_v3 (in=a) nmtot;
	by ident; if a;
run;

data sn98_v5;
	set sn98_v4;
	duree2=((duree*nmtot)/(nmtot-dursn98));
	duree3=round((duree*nmtot)/(nmtot-dursn98));
run;

proc sort data=sn98_v5;by ident nseq2;run;
data sn98_v5b; set sn98_v5; by ident; run;

data sn98_v6 (keep=ident nseq nseq3 cal duree3 idnc2 debut2 fin2 /);
	set sn98_v5b (keep= ident nseq nseq2 cal debut fin duree2 duree3 duree idnc id nmtot nbseqsn nseq3);
    by ident;

	* cas d'un sn déclaré en première séquence;
	retain nb1 debut_ fin_ 0;
	if debut ne id then do;
		if nseq2=1 then do;
			debut_=id;
			fin_=debut_+duree-1;
			nb1 = 0;
		end;
		nb1 + 1;
		if nb1 > 1 then do;
			debut_=fin_+1;
			fin_=debut_+duree-1;
		end;
		if nbseqsn="01" then do ; 
			debut=debut_; 
			fin=fin_;
		end; 
	end; 
	
	* recalcul du calendrier;
    retain fin2 nb 0;
	if first.ident then do;
		debut2=debut;
		fin2=debut2+duree3-1;
		nb = 0;
	end;
	nb + 1;
    if nb > 1 then do;
       debut2=fin2+1;
	   fin2=debut2+duree3-1;
	   idnc2=debut2+(idnc-debut);
	end;
	*si changement de contrat au dernier mois du calendrier initial alors on fixe l'idnc à la date de fin du nouveau calendrier;
	if idnc2>94 then idnc2=fin2;
run;

data basesortie.sn98_emploi;
	set sn98_v6;
	if cal in ("01" "02" "03" "04" "20") then output; /* si séquences d'emploi */
run;
data basesortie.sn98_nonemploi;
	set sn98_v6;
	if cal not in ("01" "02" "03" "04" "20") then output;
run;

/* remplacement dans la table individus du calendrier mensuel d'activité par un nouveau pour les jeunes passés par un service national */
proc sort data=sn98_v6; by ident nseq3;run;
data basesortie.sn98_calend (keep=ident calsn1-calsn98);
	set sn98_v6;
/*créer un calendrier mensuel qui s'appelle calsnX*/
	by ident nseq3;
		length calsn1-calsn98 $ 4;
		array calsn(98) calsn1-calsn98 ;
		retain calsn1-calsn98;
		if first.ident then do;
	    	do i=1 to 98;
	        	calsn(i)="";
	        end;
		end;
		do i=debut2 to fin2;
	  		calsn(i)=strip(compress(cal||nseq3)); * on concatene la variable cal (type de situation) et le numéro de la séquence;
		end; 
		if last.ident then output;
run;

data basesortie.indiv_98; 
merge  baseentree.g987indcomp basesortie.sn98_calend ; 
by ident ;

/*on remplace les valeurs des variables moisX avec les infos du nouveau calendrier pour les gens qui ont fait un service national */
array calsn(98) calsn1-calsn98 ;
array mois(98) MOIS1-MOIS98 ;                                                                                                                         

*retain calsn1-calsn98 mois1-mois98 ;
if first.ident then do ;
        do i=1 to 98 ;
        	if calsn(i)^="" then MOIS(i)=calsn(i) ; 
        end ;
end; 
drop calsn1-calsn98;
run; 


/********************************************************************************************************************************************/                                                                                                                                                                                            
/*  Séquencage du calendrier mensuel de l'enquête Génération 1998 avec pour chaque mois les informations sur lesquelles va être construite	 */
/*	la typologie (chômage, formation, inactivité, emploi à durée indéterminée, emploi à durée déterminée)									 */                                                                                          
/*********************************************************************************************************************************************/ 

/* Creation de la table des séquences d'emploi */ 
proc sort data=baseentree.g987seqcomp; by ident nseq; run; 
proc sort data=basesortie.sn98_emploi; by ident nseq; run; 
data emplois98 ; 
	merge baseentree.g987seqcomp  basesortie.sn98_emploi; 
	by ident nseq; 
	if nseq3^="" then NSEQ=nseq3;
	if debut2^=. then DEBUT=debut2 ; 
	if fin2^=. then FIN=fin2; 
	if idnc2^=. then IDNC=idnc2; 
	if duree3^=. then DUREE=duree3;  
	drop nseq3 debut2 fin2 idnc2 duree3; 
run ;

/* Division en deux séquences au lieu d'une si il y a un changement de contrat dans la séquence */
data preparation98;     
set emplois98
            (keep =  IDENT NSEQ debut fin  duree stat_emb stat_fin cal idnc ) ;
length statcal st_inter $ 2 vectidnc $ 3 dad daf durcal datchgt1 datchgt2 datchgt3 3. ;

if (cal ="20") then stat_emb = '16' ;
if (cal ="20") then stat_fin = '16' ;

/*Il n'y a qu'une variable idnc (date de changement de contrat) donc le code est plus simplifié par rapport aux deux autres générations */
idnct = (idnc ne .) ;
datchgt1 = . ;
st_inter = '00' ;

if idnct = 1 then datchgt1 = idnc ;

if idnct = 1 then do ;

    dad=debut;
    daf=datchgt1 - 1 ;
    statcal=put(input(stat_emb,2.),z2.) ;
    durcal = daf - dad + 1 ;
    output ;

    dad=datchgt1 ;
    daf=fin  ;
    statcal=put(input(stat_fin,2.),z2.) ;
    durcal = daf - dad + 1 ;
    output ;

end ;

if idnct = 0 then do ;

    dad=debut ;
    daf=fin ;
    statcal=put(input(stat_fin,2.),z2.) ;
    durcal = daf - dad + 1 ;
    output ;

end ;
run ;

/* Complétion du calendrier avec les situations d'emploi */
proc sort data=preparation98 ; by ident dad ; run ;

data calcontrat98 (keep=ident mm1-mm98 m1-m98) ;
set preparation98 ;
by ident dad ;

length m1-m98 $2 mm1-mm98 3. ;

array m(98) m1-m98 ;
array mm(98) mm1-mm98 ;                                                                                                                         

retain m1-m98 mm1-mm98 ;

if first.ident then do ;
        do i=1 to 98 ;
        m(i)="" ; 
        end ;
end ;

do i=dad to daf ;

      	m(i)=statcal ;

        if m(i) in ('01','03','04')                            then mm(i) = 1 ; /*EDI : emploi à durée indéterminée */                                    
        if m(i) not in ('01','03','04','06', '08','')          then mm(i) = 2 ; /*EDD (emploi à durée déterminée) hors alternance */  
        if m(i) in ('06')                                      then mm(i) = 3 ; /*Apprentissage*/                                  
        if m(i) in ('08')                                      then mm(i) = 4 ; /*Contrat Pro*/ 
end ;
                                                                                                                                               
drop i  ;   
if last.ident then output ;
run ;

/* Complétion du calendrier avec les situations autre que de l'emploi */
proc sort data=calcontrat98 ; by ident ; run ;
proc sort data=basesortie.indiv_98 ; by ident ; run ;

data calendar98_7 ; 
merge basesortie.indiv_98 (in=a) calcontrat98 ; by ident ; if a ;

length c1-c98 3. ;
array c(98) c1-c98 ;
array m(98) m1-m98 ;
array mm(98) mm1-mm98 ; /* contenant les dictinctions entre les différents types de contrats dans les séquences d'emploi*/
array mois(98) mois1-mois98 ;

/* Création du nouveau calendrier c(i) */
do i=1 to 98 ;
c(i)=0 ;
if mm(i) ne . then c(i)=mm(i) ;
if substr(mois(i),1,2) in ('05','06','11','12','21')                  then c(i) = 7 ; /*chomage ou vacances*/         
if substr(mois(i),1,2) in ('07','08','13','14')                       then c(i) = 8 ; /*inactivité*/         
if substr(mois(i),1,2) in ('09','10','15','16')                       then c(i) = 6 ; /*formations */   
if substr(mois(i),1,2) in ('17','18')                                 then c(i) = 5 ; /*repr etudes */    
end ;

gener="98"; 
identif="98"!!ident;
run;


/********************************************************************************************************************************************/                                                                                                                                                                                            
/*  Séquencage du calendrier mensuel de l'enquête Génération 2004 avec pour chaque mois les informations sur lesquelles va être construite	 */
/*	la typologie (chômage, formation, inactivité, emploi à durée indéterminée, emploi à durée déterminée)									 */                                                                                          
/*********************************************************************************************************************************************/ 

/* Division des séquences si il y a eu des changements de contrats au cours de la séquence */
data preparation04 
			(keep = ident nseq statcal dad daf durcal  datchgt1 datchgt2 
					idnc idnc1 idnc2 idnc3 vectidnc check st_inter) ;
set baseentree.G047SEQCOMP
			(keep =  ident nseq debut fin duree stat_emb stat_fin 
					ep25_0407 ep25_0709 ep25_0911 cal stat_07 stat_09
					idnc1 idnc2 idnc3 idnc) ;

length statcal st_inter $ 2 vectidnc $ 3 dad daf durcal datchgt1 datchgt2 3. ; 


if (cal ="20") then stat_emb = '16' ;
if (cal ="20") then stat_fin = '16' ;

vectidnc = compress((idnc1 ne '')!!(idnc2 ne '')!!(idnc3 ne '')) ;

datchgt1 = . ;
datchgt2 = . ;
st_inter = '00' ;

if idnc = 2 and idnc1 ne . then do ;  datchgt1 = idnc1 ; datchgt2 = max(1*idnc2,1*idnc3) ; 
									   st_inter = stat_07 ; end ;
if idnc = 2 and idnc1 = . then do ; datchgt1 = idnc2 ; datchgt2 = idnc3 ; 
										st_inter = stat_09 ; end ;
if idnc = 1 then datchgt1 = max(1*idnc1,1*idnc2,1*idnc3) ; 

/****************************************************************************/

if idnc = 2 then do ; 

	dad=debut;
	daf=datchgt1 - 1 ;
	statcal=put(input(stat_emb,2.),z2.) ; 
	durcal = daf - dad + 1 ; 
	output ;

	dad=datchgt1 ;
	daf=datchgt2 - 1  ;
	statcal=put(input(st_inter,2.),z2.) ;
	durcal = daf - dad + 1 ; 
	output ;

	dad=datchgt2 ;
	daf=fin  ;
	statcal=put(input(stat_fin,2.),z2.) ;
	durcal = daf - dad + 1 ; 
	output ;
end ;

if idnc = 1 then do ; 

	dad=debut;
	daf=datchgt1 - 1 ;
	statcal=put(input(stat_emb,2.),z2.) ; 
	durcal = daf - dad + 1 ; 
	output ;

	dad=datchgt1 ;
	daf=fin  ;
	statcal=put(input(stat_fin,2.),z2.) ;
	durcal = daf - dad + 1 ; 
	output ;

end ;

if idnc = . then do ;

	dad=debut ;
	daf=fin ;
	statcal=put(input(stat_fin,2.),z2.) ;
	durcal = daf - dad + 1 ; 
	output ;
end ;
run ;
/* Pour information : on passe de 36500 à 41400 séquences d'emplois en scindant celles contenant un ou deux changements de contrat */

/* Complétion du calendrier avec les situations d'emploi */
proc sort data=preparation04 ; by ident dad ; run ;
data calcontrat04 (keep=ident m1-m98 mm1-mm98);
set preparation04 ;
by ident dad ;

length m1-m98 $2 ;
array m(98) m1-m98 ;
array mm(98) mm1-mm98 ;

retain m1-m98 mm1-mm98 ; 

if first.ident then do ;
        do i=1 to 98 ;
        m(i)="" ; 
        end ;
end ;

do i=dad to daf ; 
      m(i)=statcal ;
	    if m(i) in ('01','03','04')                            then mm(i) = 1 ; /*EDI*/                                    
        if m(i) not in ('01','03','04','06', '08','')          then mm(i) = 2 ; /*EDD hors alternance */  
        if m(i) in ('06')                                      then mm(i) = 3 ; /*Apprentissage*/                                  
        if m(i) in ('08')                                      then mm(i) = 4 ; /*Contrat Pro*/ 
end ; 
if last.ident then output ; 
run ;

proc sort data=calcontrat04 ; by ident ;
 
data ind04_7 ; set baseentree.G047indcomp ; run ;                                                                                                
proc sort data=ind04_7 ; by ident ; run ;

/* Complétion du calendrier avec les situations autre que de l'emploi */
data ind04_chr ; merge ind04_7 (in=a) calcontrat04 (in=b) ; by ident ; if a ; run ;
 
data calendar04_7 ;                                                                                                                                
set ind04_chr ;
 
length default = 3 ;                                                                                                              
                                                                                                                                               
array c(98) c1-c98 ;
array m(*) m1-m98 ;                                                                                                                   
array mois(*) mois1-mois98 ;                                                                                                                   
array mm(*) mm1-mm98 ;                                                                                                                         
                                                                                                                                               
do i = 1 to 98 ;       

		c(i)=0 ;
		if mm(i) ne . then c(i)=mm(i) ;                                                                                                                                           
				if substr(mois(i),1,2) in ('05','06','11','12','21') 	then c(i) = 7 ; /*chômage ou vacances*/         
       		    if substr(mois(i),1,2) in ('07','08','13','14')		    then c(i) = 8 ; /*inactivité*/                  
        		if substr(mois(i),1,2) in ('09','10','15','16')         then c(i) = 6 ; /*formations */   
        		if substr(mois(i),1,2) in ('17','18')                   then c(i) = 5 ; /*reprises d'etudes */    
end ;                                                                                                                                           
                                                                                                                                       
drop i tape ;
gener="04" ; 
identif="04"!!ident ;                                                                                                                                      
run ;                                                                                                                                          

/********************************************************************************************************************************************/                                                                                                                                                                                            
/*  Séquencage du calendrier mensuel de l'enquête Génération 2010 avec pour chaque mois les informations sur lesquelles va être construite	 */
/*	la typologie (chômage, formation, inactivité, emploi à durée indéterminée, emploi à durée déterminée)									 */                                                                                          
/*********************************************************************************************************************************************/                                                                                                                                                                                                   

data emplois10 ; set baseentree.g107seqcomp; run ;

/* Division des séquences si il y a eu des changements de contrats au cours de la séquence */
data preparation10 ; 
            
set emplois10
            (keep =  IDENT NSEQ debut fin  duree stat_emb stat_fin
                    cal stat_13 stat_15 idnc_13 idnc_15 idnc_17 ) ;

length statcal st_inter $ 2 dad daf durcal datchgt1 datchgt2 datchgt3 3. ;

/* IDNC est la date de changement en cours de séquence. idnc_13: si changement (DANS UNE MEME SEQUENCE) a eu lieu
pendant l'enquête à 3 ans. idnc_15: changement a eu lieu pendant la 2e vague. idnc_17 idem.
idnc peut être vide quand il n'y a eu aucun changement, dans ce cas pas de division de séquence.
Une séquence peut être au maximum divisée en trois.
Dans le cas le plus compliqué on prend stat_15 quand on n'a pas stat_fin. */


if (cal ="20") then stat_emb = '16' ;
if (cal ="20") then stat_fin = '16' ;

idnct = (idnc_13 ne .)+(idnc_15 ne .)+(idnc_17 ne .) ;

debut=1*debut ;
fin=1*fin ;
checktime=fin-debut+1 ;

datchgt1 = . ;
datchgt2 = . ;
datchgt3 = . ;
st_inter = '00' ;

if idnct = 3 then do ;  datchgt1 = idnc_13 ; datchgt2 = idnc_15 ;  datchgt3 = idnc_17 ; st_inter1 = stat_13 ; st_inter2 = stat_15 ; end ;
if idnct = 2 and idnc_13 ne . and idnc_15 ne . then do ;  datchgt1 = idnc_13 ; datchgt2 = idnc_15 ;  st_inter1 = stat_13 ; end ;
if idnct = 2 and idnc_15 ne . and idnc_17 ne . then do ;  datchgt1 = idnc_15 ; datchgt2 = idnc_17 ;  st_inter1 = stat_15 ; end ;
if idnct = 2 and idnc_13 ne . and idnc_17 ne . then do ;  datchgt1 = idnc_13 ; datchgt2 = idnc_17 ;  st_inter1 = stat_15 ; end ;
if idnct = 1 then datchgt1 = max(1*idnc_13,1*idnc_15,1*idnc_17) ;

if datchgt1<=debut then datchgt1=debut+1 ;

if idnct = 3 then do ;

    dad=debut;
    daf=datchgt1 - 1 ;
    statcal=put(input(stat_emb,2.),z2.) ;
    durcal = daf - dad + 1 ;
    output ;

    dad=datchgt1 ;
    daf=datchgt2 - 1  ;
    statcal=put(input(st_inter1,2.),z2.) ;
    durcal = daf - dad + 1 ;
    output ;

	dad=datchgt2 ;
    daf=datchgt3 - 1  ;
    statcal=put(input(st_inter2,2.),z2.) ;
    durcal = daf - dad + 1 ;
    output ;

    dad=datchgt3 ;
    daf=fin  ;
    statcal=put(input(stat_fin,2.),z2.) ;
    durcal = daf - dad + 1 ;
    output ;

end ;

if idnct = 2 then do ;

    dad=debut;
    daf=datchgt1 - 1 ;
    statcal=put(input(stat_emb,2.),z2.) ;
    durcal = daf - dad + 1 ;
    output ;

    dad=datchgt1 ;
    daf=datchgt2 - 1  ;
    statcal=put(input(st_inter1,2.),z2.) ;
    durcal = daf - dad + 1 ;
    output ;

    dad=datchgt2 ;
    daf=fin  ;
    statcal=put(input(stat_fin,2.),z2.) ;
    durcal = daf - dad + 1 ;
    output ;

end ;


if idnct = 1 then do ;

    dad=debut;
    daf=datchgt1 - 1 ;
    statcal=put(input(stat_emb,2.),z2.) ;
    durcal = daf - dad + 1 ;
    output ;

    dad=datchgt1 ;
    daf=fin  ;
    statcal=put(input(stat_fin,2.),z2.) ;
    durcal = daf - dad + 1 ;
    output ;

end ;


if idnct = 0 then do ;

    dad=debut ;
    daf=fin ;
    statcal=put(input(stat_fin,2.),z2.) ;
    durcal = daf - dad + 1 ;
    output ;

end ;
run ;

/* vérification au cas où : */
data preparation10 ; set preparation10 ;
if durcal<=0 then delete ;
run ;

/* Complétion du calendrier avec les situations d'emploi */
proc sort data=preparation10 ; by ident dad ; run ;

data calcontrat10 (keep=ident mm1-mm98 m1-m98) ;
set preparation10 ;
by ident dad ;

length m1-m98 $2 mm1-mm98 3. ;

array m(98) m1-m98 ;
array mm(98) mm1-mm98 ;                                                                                                                         

retain m1-m98 mm1-mm98 ;

if first.ident then do ;
        do i=1 to 98 ;
        m(i)="" ; mm(i) = . ;
        end ;
end ;

do i=dad to daf ;

      	m(i)=statcal ;

        if m(i) in ('01','03','04')                            then mm(i) = 1 ; /*EDI*/                                    
        if m(i) not in ('01','03','04','06', '08','')          then mm(i) = 2 ; /*EDD hors alternance*/  
        if m(i) in ('06')                                      then mm(i) = 3 ; /*Apprentissage*/                                  
        if m(i) in ('08')                                      then mm(i) = 4 ; /*Contrat Pro*/ 
end ;
                                                                                                                                               
drop i  ;   
if last.ident then output ;
run ;

/* Complétion du calendrier avec les situations autre que de l'emploi */
proc sort data=calcontrat10 ; by ident ; run ;
proc sort data=baseentree.g107indcomp ; by ident ; run ;

data /*basesortie.*/calendar10_7 ; 
merge baseentree.g107indcomp (in=a) calcontrat10 ; by ident ; if a ;

length c1-c98 3. ;

array c(98) c1-c98 ;
array m(98) m1-m98 ;
array mm(98) mm1-mm98 ; 
array mois(98) mois1-mois98 ;

do i=1 to 98 ;
c(i)=0 ;
if mm(i) ne . then c(i)=mm(i) ;
if substr(mois(i),1,2) in ('05','06','11','12','21')                  then c(i) = 7 ; /*chomage ou vacances*/         
if substr(mois(i),1,2) in ('07','08','13','14')                       then c(i) = 8 ; /*inactivité*/         
if substr(mois(i),1,2) in ('09','10','15','16')                       then c(i) = 6 ; /*formations */   
if substr(mois(i),1,2) in ('17','18')                                 then c(i) = 5 ; /*repr etudes */   
end ;

if ident in ("N0000386") then delete ;
gener="10" ;
identif="10"!!ident ;
run ;

proc format ;

value $moisc
" 0" = "probl"
" 1" = "Edi "
" 2" = "Edd hors alt"
" 3" = "apprentiss"
" 4" = "contrats pros"
" 5" = "repr études"
" 6" = "formation"
" 7" = "chômage"
" 8" = "autres inact" ;

value moiscn
0 = "probl"
1 = "Edi "
2 = "Edd hors alt"
3 = "apprentiss"
4 = "contrats pros"
5 = "repr études"
6 = "formation"
7 = "chômage"
8 = "autres inact" ;

value sit1_f
0,9 = "probl ou vide"
1 = "EDI"
2,3,4 = "EDD"
5,6 = "Form Repetu"
7 = "chomdu"
8 = "inact"
;
run ;

/*********************************************************************************************/
/* Rassemblement des calendriers harmonisés des trois enquêtes dans une même base de données */
/*********************************************************************************************/
data basesortie.forclassif ; 

set calendar10_7 calendar04_7 calendar98_7 (drop=TAPE LASSITUDE RAIFINAN TROUVEMP ATNIVO REFUSE AUTRERAI);

id=1*id ; 
pondef_corr=round(pondefcomp7) ; /* pondération arrondie */
if gener ne "10" then pondef_corr = -1*pondef_corr ; /*pour mettre les individus des enquêtes Génération 2004 et 2010 en supplémentaire dans l'ACM */

array c c1-c98 ;
array cn cn1-cn98 ;

do i=id to 98 ;
	cn(i-id+1)=c(i) ;
end ;

do i =1 to 98 ;
	if cn(i) in (3,4) then cn(i)=2 ;
	if cn(i) in (5,6) then cn(i)=3 ; /*formation-reprise d'études */
	if cn(i) in (7) then cn(i)=4 ; /*chomâge */
	if cn(i) in (8) then cn(i)=5 ; /*inactivité */
end ;

run ;


/*proc freq data=forclassif ; table c15 c18 c20 c24 c26 cn1 cn2 cn3 cn6 cn10 cn12 cn14 cn15 cn80 cn82 cn83 cn84 cn85; run ; 
proc freq data=forclassif;
	table gener*cn83/list;
run;
on choisi la de s'arreter à cn82 car pas de 0 dans les modalités par mois, ne pas aller au delà de cn82 */

/* Création du calendrier disjonctif complet */
data dichotg (keep = identif m1-m410 cn1-cn82 pondef_corr gener) ; 
set basesortie.forclassif (keep = identif cn1-cn82 pondef_corr gener) ;

length m1-m410 3. ;

array cn cn1-cn82 ;
array m m1-m410 ;
 
do k = 1 to 410 ; /* 410 = 82*5 */
m(k) = 0 ;
end ;

do i = 1 to 82 ; /* 82 mois */
	do j = 1 to 5 ; /* 5 situations possibles */
	m(i*5+(j-1)-4) = (cn(i) = j) ;
	end ;
end ;

drop i j k ;

run ;

/******************************************/
/* Analyse des correspondances multiples */
/*****************************************/
title "ACM sur variables non dichotomisées" ;
proc corresp data=dichotg noprint out=acm1 dimens = 320 ;
var m1-m410 ; 
id identif ; /*identifiant des individus */
weight pondef_corr ;
run ;

/* Macro de l'insee pour visualiser les résultats */
%Aideacm(data=acm1, datainit=dichotg, analyse=tables, id=identif, iva=2, ioa=15, weight=pondef_corr ,
			varact=cn1-cn82,
			nbmodact= 	5 5 5 5 5 5 5 5 5 5 
						5 5 5 5 5 5 5 5 5 5
						5 5 5 5 5 5 5 5 5 5 
						5 5 5 5 5 5 5 5 5 5
						5 5 5 5 5 5 5 5 5 5
						5 5 5 5 5 5 5 5 5 5 
						5 5 5 5 5 5 5 5 5 5
						5 5 5 5 5 5 5 5 5 5
						5 5 ) ; 
run ;

/* 32 axes récupèrent 85.32% de l'inertie */

data acm2 ;  
set acm1 (where=(_TYPE_ in ('OBS' 'SUPOBS'))) ; 
run ;

proc sort data=acm2 ; 
by identif ; run ;

proc sort data=dichotg ; 
by identif ; run ;

data acm3 ; merge acm2(in=a) dichotg(in=b keep=identif pondef_corr gener); 
by identif ; if a and b ; run ;

/* création d'une variable de poids normalisée à utiliser dans la macro partnum pour que les tests soient corrects */
proc means noprint data=acm3 (where=(gener='10')) ; 
var pondef_corr ;
output out=acm3b mean=moyenne ;
run ;
title "ACM3 : moyenne de EFF récupérée pour normaliser les poids avant classif (sur gene2010)" ;
proc print data=acm3b;
run ;

data acm4 ; set acm3 (drop=_TYPE_);
if _n_=1 then set acm3b ; /*permet de récupérer la moyenne de toutes les observations*/
poidsmil=round((pondef_corr/moyenne)*1000) ;
run ;

data basesortie.acm4v2 ; set acm4 ; run ;

/*****************************************************/
/* Méthode de classification ascendante hiérarchique */
/*****************************************************/

/*** Classification sur les axes de l'ACM constituant l'essentiel de l'inertie, donc classification sur variables numériques ***/
%let ls=125 ;
title "CAH sur 32 axes après ACM (récupèrant 85.32% de l'inertie)" ;
%cahnum(data=basesortie.acm4v2 , 
			id=identif, reduc=non, /*poids=poidsmil,*/ var=dim1-dim32, arbre=non,ccc=oui) ; run ; /* macro de l'Insee à télécharger voir lien en haut du programme */

/* choix de faire une typolgie en 8 classes  */
title "partition en 8 classes " ;
%partnum(data=basesortie.acm4v2, id=identif, reduc=non, consolid=oui, poids=poidsmil, var=dim1-dim32,
			ncl=8, affect=oui, outpart=classif8cl, varclass=cl8, obssup=oui) ; /* macro de l'Insee à télécharger voir lien en haut du programme */
run ;

proc freq data=classif8cl; table cl8; run; 

proc sort data=classif8cl (keep=identif cl8) ; by identif ; run ;
proc sort data=forclassif  ; by identif ; run ;

/***********************************************/
/* Description des trajectoires types obtenues */
/***********************************************/

/* Pour réaliser ensuite les chronogrammes par classe : on reprend la table de données intiale avec le calendrier intial pour lequel une case correspond
au même mois pour tous les individus alors que dans les calenriers construits précédement les numéros des mois correspondaient à un temps depuis 
la fin de formation initiale */
data basesortie.laclassif ; merge forclassif classif8cl ; by identif ;

array c(98) c1-c98 ;
array cr(98) cr1-cr98 ;
do i=1 to 98 ;
cr(i)=c(i) ;
end ;

do i =1 to 98 ;
if cr(i) in (3,4) then cr(i)=2 ; /* emploi */
if cr(i) in (5,6) then cr(i)=3 ; /* formation-reprise d'études */
if cr(i) in (7) then cr(i)=4 ; /* chômage */
if cr(i) in (8) then cr(i)=5 ; /* inactivité */
if cr(i) in (9) then cr(i)=0 ; /* formation initiale */
end ;

length suitecn $98. ;
array cn(98) cn1-cn98 ;
suitecn = "" ;
do i=1 to 98 ;
suitecn = compress(suitecn!!cn(i)) ;
end ;

class8=1*cl8 ;
class1=1 ;
run ;

/* Représentation graphique à l'aide de chronogrammes uniquement sur la Génération 2010 car c'est sur cette base qu'on était construites 
les trajectoires */
data basesortie.laclassifg10;
	set basesortie.laclassif ;
	where gener="10";
run;

proc format; 
value sit1b_f
0 = "form ini"
1 = "EDI"
2 = "EDD"
3 = "Form Repetu"
4 = "chomdu"
5 = "inact"
;
run ;

/* Macro pour créer les chronogrammes */
%macro chrono(base,N) ;                                                                                                                        
                                                                                                                                               
data finalsur&N; set _null_;run;                                                                                                               
                                                                                                                                               
%do j=1 %to &N ;                                                                                                                               
data extrait&j ; set &base (where=((class&N = &j))) ;                                                                                          
run ;                                                                                                                                          
                                                                                                                                               
data fusion&j ; set _null_ ; run ;                                                                                                             
data fusion&j ; situ=0;                                                                                                                        
run ;                                                                                                                                          
                                                                                                                                               
%do i=1 %to 98 ;                                                                                                                               
proc freq data = extrait&j ;                                                                                                                   
tables cr&i / missing list nofreq nocum out=out&i ;                                                                                            
weight pondefcomp7;                                                                                                                                 
title " ensemble" ;                                                                                                                            
                                                                                                                                               
data t&i ;                                                                                                                                     
set out&i (keep = cr&i percent) ;                                                                                                              
rename  percent = mois&i                                                                                                                       
        cr&i = situ ;                                                                                                                  
run;                                                                                                                                           
                                                                                                                                               
data fusion&j ;                                                                                                                                
merge fusion&j t&i; by situ;                                                                                                                   
format situ sit1b_f.;                                                                                                                           
run;                                                                                                                                           
%end ;                                                                                                                                         
                                                                                                                                               
data classe&j.sur&N ;                                                                                                                          
length situation $20 ;                                                                                                                         
set fusion&j ;                                                                                                                                 
situation=compress('CL')!!compress(&j.)!!put(situ,sit1b_f.);                                                                                    
drop situ;                                                                                                                                     
run ;                                                                                                                                          
%end ;                                                                                                                                         
                                                                                                                                               
%do p=1 %to &N ;                                                                                                                               
data finalsur&N ; set finalsur&N classe&p.sur&N ; run ;                                                                                        
%end ;                                                                                                                                         
                                                                                                                                               
%mend ;  
 
%chrono(basesortie.laclassifg10,8) ;

* Proportion des individus par classe;
proc freq data=basesortie.laclassifg10;
	tables class8/ missing;
	weight pondefcomp7;
run;

  /*   
								                                         Fréquence    Pourcentage
                                  class8    Fréquence     Pourcentage     cumulée        cumulé
                                  ---------------------------------------------------------------
                                       1      227055         33.66         227055        33.66   => EDI rapide
                                       2    125516.2         18.61       352571.2        52.27   => EDD durable
                                       3    142841.2         21.18       495412.4        73.45   => EDI différé
                                       4    85957.95         12.74       581370.4        86.19   => chômage durable
                                       5    19008.05          2.82       600378.4        89.01   => inactivité durable
                                       6    23140.56          3.43         623519        92.44   => reprise d'études milieu et fin
                                       7    39161.66          5.81       662680.6        98.24   => reprise d'études milieu
                                       8    11843.02          1.76       674523.6       100.00   => inactivité fin*/
 

/* Regroupement en 6 trajectoires au lieu de 8 pour ne pas garder des classes à trop faibles effectifs : 
regroupement de deux trajectoires de reprises d'études et de deux trajectoires d'inactivité */
data basesortie.laclassif_agr (keep=ident class6 class8 pondefcomp7 gener cr1-cr98);
	set basesortie.laclassif;
	if class8=1 then class6=1; 
	if class8=2 then class6=3;
	if class8=3 then class6=2;
	if class8=4 then class6=4;
	if class8=5 or class8=8 then class6=6;	
	if class8=6 or class8=7 then class6=5;
run;

/* Visualisation des classes finales */ 
%chrono(basesortie.laclassif_agr,6) ; 

/* Format de la typologie obtenue */
proc format;
value typo7_f		1 = "Stabilisation rapide en emploi à durée indéterminée (EDI)"
					2 = "Stabilisation différée en emploi à durée indéterminée (EDI)"
					3 = "Emploi à durée déterminée (EDD) dominant, durable ou récurrent"
					4 = "Chômage persistant ou recurrent"
					5 = "Longue(s) période(s) en formation ou reprise d'études"
					6 = "Inactivité durable";
run;