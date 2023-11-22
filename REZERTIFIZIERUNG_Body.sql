--------------------------------------------------------
--  File created - Wednesday-November-22-2023   
--------------------------------------------------------
--------------------------------------------------------
--  DDL for Package Body REZERTIFIZIERUNG
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "ZUL"."REZERTIFIZIERUNG" as
  ir             varchar2(20) := translation.translate('TEXT.IR');
  ir_txt         varchar2(120):= translation.translate('TEXT.IR_TXT');
  hk             char         := chr(39);
  bl             varchar2(7)  := '&nbsp;';
  persgif        varchar2(200) := '<span style="padding-left:10px;  display: inline-block; color:#4f81bd; " class="ui-icon ui-icon-users"></span>';
  h28            varchar2(20) := 'height="25"';
  grau           varchar2(7)  := '#CCCCCC';
  hgrau          varchar2(7)  := '#EAEAEA';
  weiss          varchar2(7)  := '#FFFFFF';
  santraend      varchar2(40) := 'Antrag_aendern';

  emailadr     varchar2(40);

  v_statusfarben t_statusfarben;
  v_vstatusfarben t_vstatusfarben;
  v_statusbez    t_statusbez;
  v_instfarben   t_statusfarben;
  v_instbez      t_statusbez;
  v_mandanten    t_mandanten;

 procedure dummyspalte (breite number)
is
begin
	htp.tabledata('<img src="/zul/img/shim.gif" width="'||breite||'" height="1">',cattributes=>'bgcolor="'||weiss||'"');
end;
function dummywert return owa_util.vc_arr
is
 v_vcar owa_util.vc_arr;
begin
  v_vcar(0) := 'dummy';
  return v_vcar;
end;



procedure init_antrstatus
is
begin
	v_statusbez(0) := 'Alle';
	v_statusfarben(0) := grau;
	for ix in (select * from antragsstatus)
	loop
		v_statusbez(ix.status) := ix.bezeichnung;
	  v_statusfarben(ix.status) := ix.farbe;
	end loop;
end;

procedure init_vantrstatus
is
begin
	v_vstatusfarben(' ') := grau;
	v_vstatusfarben('beantragt') := '#C0FFFF';
    v_vstatusfarben('verlängert') := '#80FF80';
    v_vstatusfarben('abgelehnt') := '#FF4040';

end;

procedure init_inststatus
is
begin
	for ix in (select * from inststatus)
	loop
		v_instbez(ix.status) := ix.bezeichnung;
		v_instfarben(ix.status) := ix.farbe;
	end loop;
end;

function system_dz(sid number,kennz varchar2) return number is
  dz_id number;
  tags number;
begin
if kennz='I' then
  select dzi_id into dz_id from egsysteme where systemid=sid;
elsif kennz='E' then
  select dze_id into dz_id from egsysteme where systemid=sid;
else
  select dzs_id into dz_id from egsysteme where systemid=sid;
end if;
select tage into tags from default_zeitraum where id=dz_id;
return tags;
end;
procedure init_mandanten
is
begin
	for ix in (select pmid,kurzbez from produktmandant)
	loop
		v_mandanten(ix.pmid) := ix.kurzbez;
	end loop;
end;

function system_dz_text(sid number,kennz varchar2) return  default_zeitraum.text%type is
  dz_id number;
  dz_text default_zeitraum.text%type;
begin
if kennz='I' then
  select dzi_id into dz_id from egsysteme where systemid=sid;
elsif kennz='E' then
  select dze_id into dz_id from egsysteme where systemid=sid;
else
  select dzs_id into dz_id from egsysteme where systemid=sid;
end if;
select text into dz_text from default_zeitraum where id=dz_id;
return dz_text;
end;
procedure antrag_alle         (anzeigen       varchar2 default 'fbv',
                               status         number   default 0,
                               sysid          number   default 0,
                               abt            varchar2 default null,
                               abtalt         varchar2 default null,
                               pmid           number   default -1,
                               vastatus       varchar2 default 'beantragt',
                               proid          number   default 0,
                               antrsteller    varchar2 default '*',
                               name           varchar2 default null,
                               fbv            varchar2 default null,
                               sort_on        varchar2 default null,
                               sort_dir       number   default null,
                               spezialfilter  number   default 0,
                               ausrufez       number   default 0,
                               vertretung     NUMBER DEFAULT 0,
                               schatten       number   default 0,
                               x              number   default 6,
                               y              number   default 11)
is
  vCursor               sys_refcursor;
  vCursorSys            sys_refcursor;
  vWCursor              sys_refcursor;
  vAmCursor             sys_refcursor;

  vSql                  dbms_sql.varchar2a;
  vSqlSys               dbms_sql.varchar2a;
  vBinds                pa_sql.tBindTbl;
  vBindIdx              pls_integer := 1;
  vBindsSys             pa_sql.tBindTbl;

  vVcTab                vc_arr := vc_arr();

  vMandSql              dbms_sql.varchar2a;
  vMandAnzSql           dbms_sql.varchar2a;
  vMandBinds            pa_sql.tBindTbl;
  vMandBindIdx          pls_integer := 1;

  administrator  boolean      := systemzul.istZULAdmin;

 aanzeigen      varchar2(3);

 colspan        number(2)    := 0;            -- Spaltenanzahl Tabelle
 sel            varchar2(7);                  -- selektierte Eintrag in Pulldown
 asort_on       varchar2(40) := 'antragsid';  -- Sortierkrieterium
 asort_dir      number;                       -- Sortierrichtung

 asort_d1       number;                       -- temp. Sortierrichtung
 atitel         varchar2(60);

 astnr          antraege.antrst7%type;
 aname          varchar2(40);
 astnrper       antraege.antrst7%type;
 astnrfmd       antraege.antrst7%type;
 astnrfbv       antraege.antrst7%type;
 astnrsyg       antraege.antrst7%type;
 astnrzul       antraege.antrst7%type;
 astnrpar       antraege.antrst7%type;
 astnrvor       antraege.antrst7%type;
 aabt           antraege.antrstkz%TYPE;
 aabtalt        antraege.antrstkz%TYPE;
 astatus        varchar2(6);
 asysid         varchar2(6);
 aproid         varchar2(6);
 apmid          varchar2(9);
 apmstat        varchar2(100);
 aspezialfilt   varchar2(100);
 zuviele        number       := 0;
 anzahl         number       := 0;
 anzmax         number       := 50;
 angezeigt      number       := 0;
 anzmand        number       := 0;
 actmand        number:=0;
 v_verfdatum     date;
 v_adpvstat adp_verlaengerung.status%TYPE;
 v_adpvldat adp_verlaengerung.ldatum%TYPE;
 v_adppmid      antragsdatenprofile.pmid%TYPE;
 v_adpvkomm adp_verlaengerung.kommentar%TYPE;
 v_antragsid    antraege.antragsid%type;
 v_antrdatum    date;
 v_antrst       antraege.antrst7%type;
 v_antrstname   varchar2(30);
 v_antrstkz     antraege.antrstkz%TYPE;
 v_sn           varchar2(40);
 v_sid          number(5);
 v_pn           varchar2(40);
 v_pmstatus     number(3);
 v_kurzbez      varchar2(12);
 v_is_vertreter char(1);
 v_is_pm_vertreter char(1);
 v_profilid     number(5);
 v_antrstat     number(3);
 v_kzzakt       antraege.antrstkz%TYPE;

 perloesch      boolean         := false; -- Erlaubnis als Nicht-adm eigene Anträge zu löschen ...

 antrstati      varchar2(50) := ',';      -- String mit Antragsstati, die der User sehen darf
 mandstati      varchar2(50) := ',';      -- String mit Mandantenstati, die der User sehen darf

 v_spez_filt_mand varchar2(100);

 v_antr_select varchar2(500);
 v_antr_from   varchar2(400);
 v_antr_where  varchar2(4000);
 v_antr_group  varchar2(500);
 v_antr_order  varchar2(400);
 v_antr_anz    integer;

 dudarfst      boolean := false;
  ir_ok          boolean := false;
  v_lang t_user_session.user_language%type:=zul_user_session.get_language();


begin
   v_antr_select :=
    'select unique a.antragsid, a.antrdatum, a.antrst7, a.antrstkz, s.name sn, p.name pn, a.profilid, a.status, substr(nachname || '', '' || vorname,1,30) antrstname, NULL  ';


  v_antr_from :=
    'from antraege a, egsysteme s, egsystemprofile p, misall m, antragsdatenprofile adp, adp_verlaengerung adpv ';

  v_antr_where :=
    'where antrst7 = qnummer(+) and a.profilid=p.profilid and s.systemid=p.systemid and a.antragsid=adp.antragsid(+) and adpv.ANTRAGSID(+) = adp.ANTRAGSID and adpv.PMID(+) = adp.pmid and a.status = 500 and adp.verfdatum is not null and adp.status = 500';


  v_antr_order :=
    ' order by ';



  if anzeigen='adm' and not administrator then
    if  systemzul.istZULBeobachter then aanzeigen := 'beo'; end if;
    if  systemzul.istZULSupport then aanzeigen := 'hil'; end if;
  else
    aanzeigen := anzeigen;
  end if;

----------------------------------------------------------------------------
-- Berechtigungsprüfung

    case aanzeigen
      when 'adm' then dudarfst := systemzul.istZULAdmin;
      when 'beo' then dudarfst :=  systemzul.istZULBeobachter;
      when 'hil' then dudarfst :=  systemzul.istZULSupport;
      when 'fbv' then dudarfst :=  systemzul.istZULFbVerant OR  systemzul.istZULStellvertreter;
      when 'vor' then dudarfst :=  systemzul.istZULVorgesetzter;
      when 'syg' then dudarfst :=  systemzul.istZULGenehmiger;
      when 'par' then dudarfst :=  systemzul.istZULAnsprechpartner;
      when 'zul' then dudarfst :=  systemzul.istZULUserEinrichter;
      when 'usr' then dudarfst := true;
      when 'ext' then dudarfst := true;
      else dudarfst:= false;
    end case;

    if not dudarfst then
      systemzul.nicht_berechtigt;
      return;
    end if;

----------------------------------------------------------------------------
   -- String befüllen mit Antragsstati, die der angemeldete User anschauen darf
  for ix in (select status from antragsstatus where instr(zul,substr(aanzeigen,1,1))>0)
  loop
    antrstati := antrstati || to_char(ix.status) || ',';
  end loop;

  -- String befüllen mit Mandantenstati, die der angemeldete User anschauen darf
  for ix in (select status from antragsstatus where instr(mand,substr(aanzeigen,1,1))>0)
  loop
    mandstati := mandstati || to_char(ix.status) || ',';
  end loop;

  select sysemail into emailadr from syszul_prefs where datensatz='aktiv';

  init_antrstatus;
 init_inststatus;
  init_vantrstatus;

  -- Filter Name Antragssteller
  if name = 'NULL' then
      v_antr_where := v_antr_where ||  ' and nachname is null ';
  elsif name = 'NNULL' then
      v_antr_where := v_antr_where || ' and nachname is not null ';
  elsif substr(name,1,1) = '#' then
      v_antr_where := v_antr_where || ' and a.antragsid = :antrid ';
       vBinds(vBindIdx).name := 'antrid';
       vBinds(vBindIdx).val := anydata.ConvertNumber(to_number(substr(name,2,length(name)-1)));
       vBindIdx := vBindIdx + 1;
  elsif substr(name,1,1) = '@' then
      v_antr_where := v_antr_where || ' and a.antrst7 like :antrst7 ';
      vBinds(vBindIdx).name := 'antrst7';
      vBinds(vBindIdx).val := anydata.ConvertVarchar2('%'||substr(name,2,length(name)-1));
      vBindIdx := vBindIdx + 1;
  elsif /*name<>'' or*/ name is not null then
    aname := rtrim(name);
    aname := replace (aname,'*','%');
    aname := replace (aname,' ',null);
    if instr(aname,'%')=0 then aname := aname || '%'; end if;
    v_antr_where := v_antr_where || ' and upper(nachname||'',''||vorname) like :aname ';
    vBinds(vBindIdx).name := 'aname';
    vBinds(vBindIdx).val := anydata.ConvertVarchar2(upper(aname));
    vBindIdx := vBindIdx + 1;
  end if;

  if antrsteller is null then
    --astnr  := substr(fips.user,2,6);
    astnr  := substr(fips.user,1,7);
  else
    astnr  := replace(antrsteller,'*','%');
  end if;


  -- Filter Stammnummer
  if aanzeigen in ('adm','usr','ins','fbv','syg','par','vor','hil','beo') then
    if astnr <> '%' then
      v_antr_where := v_antr_where  || ' and a.antrst7 like :astnr ';
      vBinds(vBindIdx).name := 'astnr';
      vBinds(vBindIdx).val := anydata.ConvertVarchar2(astnr);
      vBindIdx := vBindIdx + 1;
    end if;
  end if;

  -- Filter aktuelles Abt.Kurzzeichen des Antragstellers
  if aanzeigen in ('adm','usr','zul','ext','fbv','syg','par','vor','hil','beo') then
    if abt = 'NULL' then
      v_antr_where := v_antr_where || ' and systemzul.akt_kurzz(a.antrst7) is null ';
    elsif abt = 'NNULL' then
      v_antr_where := v_antr_where || ' and systemzul.akt_kurzz(a.antrst7) is not null ';
    elsif /*abt<>'' or*/ abt is not null then
      aabt := rtrim(abt);
      aabt := replace (aabt,'*','%');
      if substr(aabt,1,1)='!' then
        aabt := substr(aabt,2);
      end if;
      v_antr_where := v_antr_where || ' and upper(systemzul.akt_kurzz(a.antrst7)) ' || case when substr(abt,1,1)='!' then 'not' end || ' like :aabt ';
      vBinds(vBindIdx).name := 'aabt';
      vBinds(vBindIdx).val := anydata.ConvertVarchar2(upper(aabt));
      vBindIdx := vBindIdx + 1;
    end if;
  end if;

  -- Filter Kurzzeichen des Antragstellers bei Antragstellung bzw. altes KZZ
  if aanzeigen in ('adm','usr','zul','ext','fbv','syg','par','vor','hil','beo') then
    if abtalt = 'NULL' then
      v_antr_where := v_antr_where || ' and antrstkz is null ';
    elsif abtalt = 'NNULL' then
      v_antr_where := v_antr_where || ' and antrstkz is not null ';
    elsif /*abtalt<>'' or*/ abtalt is not null then
      aabtalt := rtrim(abtalt);
      aabtalt := replace (aabtalt,'*','%');
      if substr(aabtalt,1,1)='!' then
        aabtalt := substr(aabtalt,2);
      end if;
      v_antr_where := v_antr_where || ' and upper(antrstkz) ' || case when substr(abtalt,1,1)='!' then 'not' end || ' like :aabtalt ';
      vBinds(vBindIdx).name := 'aabtalt';
      vBinds(vBindIdx).val := anydata.ConvertVarchar2(upper(aabtalt));
      vBindIdx := vBindIdx + 1;
    end if;
  end if;


  -- Filter SystemID
  if aanzeigen in ('adm','usr','zul','ext','fbv','syg','par','vor','hil','beo') then
    if (sysid is null) or (sysid=0) then
      asysid := '%';
    else
      asysid := replace(sysid,'*','%');
      zuviele := zuviele + 1;
    end if;
    if asysid <> '%' then
      if instr(asysid,'%') > 0 then
        v_antr_where := v_antr_where || ' and s.systemid like :asysid ';
        vBinds(vBindIdx).name := 'asysid';
        vBinds(vBindIdx).val := anydata.ConvertVarchar2(asysid);
        vBindIdx := vBindIdx + 1;
      else
        v_antr_where := v_antr_where || ' and s.systemid = :asysid ';
        vBinds(vBindIdx).name := 'asysid';
        vBinds(vBindIdx).val := anydata.ConvertNumber(asysid);
        vBindIdx := vBindIdx + 1;
      end if;
    end if;
  end if;

  -- Filter ProfilID
  if aanzeigen in ('adm','usr','zul','ext','fbv','syg','par','vor','hil','beo') then
    if (proid is null) or (proid=0) then
      aproid := '%';
    else
      aproid := replace(proid,'*','%');
      zuviele := zuviele + 1;
    end if;
    if aproid <> '%' then
      if instr(aproid,'%') > 0 then
        v_antr_where := v_antr_where || ' and p.profilid like :aproid ';
        vBinds(vBindIdx).name := 'aproid';
        vBinds(vBindIdx).val := anydata.ConvertVarchar2(aproid);
        vBindIdx := vBindIdx + 1;
      else
        v_antr_where := v_antr_where || ' and p.profilid = :aproid ';
        vBinds(vBindIdx).name := 'aproid';
        vBinds(vBindIdx).val := anydata.ConvertNumber(aproid);
        vBindIdx := vBindIdx + 1;
      end if;
    end if;
  end if;

  -- Filter Antragsstatus
  if aanzeigen in ('adm','usr','zul','ext','fbv','syg','par','vor','hil','beo') then
    if (status is null) or (status=0) then
      astatus := '%';
    else
      astatus := replace(status,'*','%');
      zuviele := zuviele + 1;
    end if;
    if astatus <> '%' then
      v_antr_where := v_antr_where || ' and a.status = :astatus ';
      vBinds(vBindIdx).name := 'astatus';
      vBinds(vBindIdx).val := anydata.ConvertNumber(astatus);
      vBindIdx := vBindIdx + 1;
    end if;
  end if;

  -- Filter Produktmandant
  if aanzeigen in ('adm','usr','zul','ext','fbv','syg','par','vor','hil','beo') then
    if (pmid is null) or (pmid=-1) then
      apmid := '%';
    else
      apmid := replace(pmid,'*','%');
      zuviele := zuviele + 1;
    end if;
    if apmid <> '%' then
      v_antr_where := v_antr_where || ' and adp.pmid = :apmid ';
      vBinds(vBindIdx).name := 'apmid';
      vBinds(vBindIdx).val := anydata.ConvertNumber(apmid);
      vBindIdx := vBindIdx + 1;
    end if;
--    if apmid = '%' then
--   end if;
  end if;



     if aanzeigen in ('fbv', 'vor', 'syg') then
    if (vastatus is null) or (vastatus = '0') then
      apmstat := '%';
    else
      apmstat := replace(vastatus,'*','%');
      zuviele := zuviele + 1;
    end if;
    if apmstat <> '%' then
      v_antr_where := v_antr_where || ' and adpv.status = :apmstat ';
      vBinds(vBindIdx).name := 'apmstat';
      vBinds(vBindIdx).val := anydata.ConvertVarchar2(apmstat);
      vBindIdx := vBindIdx + 1;
    end if;
  end if;

  if aanzeigen = 'beo' then
    v_antr_where := v_antr_where || ' and s.systemid in (select pmid-10000 from antraege a, antragsdatenprofile adp where profilid = 180 and adp.status = 500 and a.antrst7 = :usr and a.antragsid = adp.antragsid) ';
    vBinds(vBindIdx).name := 'usr';
    vBinds(vBindIdx).val := anydata.ConvertVarchar2(substr(fips.user,1,7));
    vBindIdx := vBindIdx + 1;
  end if;

  if spezialfilter <> 0 then
     select sql, sql_mand into aspezialfilt, v_spez_filt_mand from filter_antrag where code=spezialfilter;
     v_antr_where := v_antr_where || ' ' || aspezialfilt || ' ';
     zuviele := zuviele + 1;
  end if;

  if sort_dir is null then
    asort_dir := 2;
  elsif (sort_dir=0) or (sort_dir=1) then
    asort_dir := sort_dir + 1;
  else
    asort_dir := 1;
  end if;

  if sort_on is null then
    asort_on := 'antragsid';
  elsif sort_on in ('antragsid','antrdatum','antrst7','antrstkz','sn','pn','profilid','status','antrstname') then
    asort_on := sort_on;
  end if;
  v_antr_order := v_antr_order || asort_on||' ';

  if aanzeigen='usr' and antrsteller is null then
    astnrper := astnr;
  else
    astnrper := '%';
  end if;

  if aanzeigen = 'ext' then
    astnrfmd := astnr;
  else
    astnrfmd := '%';
  end if;

  if aanzeigen = 'fbv' then
    if fbv is null then
      astnrfbv := substr(fips.user,2,6);
    else
      astnrfbv := fbv;
      if astnrfbv = '*' then astnrfbv := '%'; end if;
    end if;
  end if;

  if aanzeigen = 'vor' then
    astnrvor := eps.mis.q6(fips.user);
  end if;

    if aanzeigen = 'zul' then
    astnrzul := substr(fips.user,2,6);
  end if;

  if aanzeigen = 'syg' then
    astnrsyg := substr(fips.user,2,6);
  end if;

  if aanzeigen = 'par' then
      astnrpar := substr(fips.user,2,6);
  end if;

  if (asort_dir = 2) then
    v_antr_order := v_antr_order || 'desc ';
  end if;

  -- Festlegen variable Cursor für die Listen ...
      if aanzeigen='ext' then -- Anträge für Andere
         v_antr_where := v_antr_where || ' and (antrst7 <> verantw7 or antrst7 is null) and  (antrst7 like :astnrper or antrst7 is null) and verantw7 like '''||astnrfmd||''' ';
         vBinds(vBindIdx).name := 'astnrper';
         vBinds(vBindIdx).val := anydata.ConvertVarchar2(astnrper);
      elsif aanzeigen='zul' then  -- Systemverantwortlicher
         v_antr_where := v_antr_where || ' and s.usereinrichter = :astnrzul ';
         vBinds(vBindIdx).name := 'astnrzul';
         vBinds(vBindIdx).val := anydata.ConvertVarchar2(astnrzul);
      elsif aanzeigen='syg' then  -- Systemgenehmiger
         v_antr_where := v_antr_where || ' and s.genehmiger = :astnrsyg ';
         vBinds(vBindIdx).name := 'astnrsyg';
         vBinds(vBindIdx).val := anydata.ConvertVarchar2(astnrsyg);
      elsif aanzeigen='par' then -- System Ansprech-Partner
         v_antr_where := v_antr_where || '  and s.fbverant = :astnrpar ';
         vBinds(vBindIdx).name := 'astnrpar';
         vBinds(vBindIdx).val := anydata.ConvertVarchar2(astnrpar);
      elsif aanzeigen in ('adm','usr','hil') then -- ZUL-Admin Antragsteller ZUL_Supporter
         v_antr_where := v_antr_where;  -- bleibt hier unverändert
      elsif aanzeigen in ('beo') then -- ZUL-Beobachter
         v_antr_where := v_antr_where;  -- bleibt hier unverändert
      elsif aanzeigen in ('vor') then -- Vorgesetzter
        v_antr_where := v_antr_where || 'and (exists (select null
                                                       from eps.v_zul_vorgesetzter
                                                       where vorgesetzter_q6 = :astnrvor
                                                         and qnummer =  a.antrst7)
                                            or exists (select null
                                                       from eps.v_zul_vorgesetzter vor1, v_vorg_vertreter_akt vert1
                                                       where vert1.qnummer_vertreter = :astnrvor
                                                         and vert1.qnummer = vor1.vorgesetzter_q6
                                                         and vor1.qnummer =  a.antrst7))';
        vBinds(vBindIdx).name := 'astnrvor';
        vBinds(vBindIdx).val := anydata.ConvertVarchar2(astnrvor);
      else --  fbv Fachbereichsverantw
         if anzeigen='fbv' THEN
          v_antr_select :=
            'select a.antragsid, a.antrdatum, a.antrst7, a.antrstkz, s.name sn, p.name pn, a.profilid, a.status, substr(nachname || '', '' || vorname,1,30) antrstname, NULL, instr(LISTAGG(  case when :astnrfbv1 not in (coalesce(upper(pma.genehmiger1),''NOQ''),coalesce(upper(pma.genehmiger2),''NOQ''), coalesce(upper(pma.genehmiger3),''NOQ''))then ''J'' else ''N'' end, '', '') WITHIN GROUP (ORDER BY a.antragsid),''J'') as is_vertreter  ';
            vBinds(vBindIdx).name := 'astnrfbv1';
            vBinds(vBindIdx).val := anydata.ConvertVarchar2(upper(astnrfbv));
            vBindIdx := vBindIdx + 1;
          END IF;
         v_antr_from  := v_antr_from  || ' , V_PROFMAND_VERTRETER pma ';

        IF vertretung<>0 THEN
          v_antr_where := v_antr_where || ' and a.profilid=pma.profilid and adp.pmid=pma.pmid and :astnrfbv2 not in (coalesce(upper(pma.genehmiger1),''NOQ''),coalesce(upper(pma.genehmiger2),''NOQ''), coalesce(upper(pma.genehmiger3),''NOQ''))  and instr(coalesce(pma.vertreter,''''),:astnrfbv2)<>0 ';
          vBinds(vBindIdx).name := 'astnrfbv2';
          vBinds(vBindIdx).val := anydata.ConvertVarchar2(upper(astnrfbv));
        ELSE
          v_antr_where := v_antr_where || ' and a.profilid=pma.profilid and adp.pmid=pma.pmid and (:astnrfbv2 in (coalesce(upper(pma.genehmiger1),''NOQ''),coalesce(upper(pma.genehmiger2),''NOQ''), coalesce(upper(pma.genehmiger3),''NOQ''))  or instr(coalesce(pma.vertreter,''''),:astnrfbv2)<>0) ';
          vBinds(vBindIdx).name := 'astnrfbv2';
          vBinds(vBindIdx).val := anydata.ConvertVarchar2(upper(astnrfbv));
        END IF;
        v_antr_group :=' group by a.antragsid, a.antrdatum, a.antrst7, a.antrstkz, s.name, p.name, a.profilid, a.status, substr(nachname || '', '' || vorname,1,30), NULL';
    end if;

   vSql(1) :=  'select count (unique a.antragsid) ' || v_antr_from || v_antr_where;
   vCursor := pa_sql.getCursor(vBinds,vSql);

   fetch vCursor into v_antr_anz;
   close vCursor;


   vSql(1) := v_antr_select || v_antr_from || v_antr_where || v_antr_group || v_antr_order;
   anzahl      := v_antr_anz;

   -- wenn mind. ein Filter aktiviert ist, wird die Anzahl der angezeigten Zeilen nicht eingeschränkt
    if zuviele > 0 /*and anzeigen not in ('zul','fbv')*/ then
      anzmax := 50000;
    end if;

  htp.htmlopen;
  htp.headopen;
    systemzul.style;
     UTILS.ADD_JQUERRY();
        htp.print('
<script type="text/javascript">
$(function(){

 $("input.datepicker").datepicker({
 dateFormat: "dd.mm.yy",
  minDate: "0",
  changeMonth: true,
  changeYear: true,
    closeText: "schließen",
    prevText: "&#x3c;zurück",
    nextText: "Vor&#x3e;",
    currentText: "heute",
    monthNames: ["Januar","Februar","März","April","Mai","Juni",
    "Juli","August","September","Oktober","November","Dezember"],
    monthNamesShort: ["Jan","Feb","Mär","Apr","Mai","Jun",
    "Jul","Aug","Sep","Okt","Nov","Dez"],
    dayNames: ["Sonntag","Montag","Dienstag","Mittwoch","Donnerstag","Freitag","Samstag"],
    dayNamesShort: ["So","Mo","Di","Mi","Do","Fr","Sa"],
    dayNamesMin: ["So","Mo","Di","Mi","Do","Fr","Sa"],
    weekHeader: "Wo",
    firstDay: 1,
  showOn: "button",
  buttonImage: "/zul/img/kal.gif",
  buttonImageOnly: true

 });

  $("input.edatepicker").datepicker({
 dateFormat: "dd.mm.yy",
  minDate: "0",
  maxDate: "+1Y",
  changeMonth: true,
  changeYear: true,
    closeText: "schließen",
    prevText: "&#x3c;zurück",
    nextText: "Vor&#x3e;",
    currentText: "heute",
    monthNames: ["Januar","Februar","März","April","Mai","Juni",
    "Juli","August","September","Oktober","November","Dezember"],
    monthNamesShort: ["Jan","Feb","Mär","Apr","Mai","Jun",
    "Jul","Aug","Sep","Okt","Nov","Dez"],
    dayNames: ["Sonntag","Montag","Dienstag","Mittwoch","Donnerstag","Freitag","Samstag"],
    dayNamesShort: ["So","Mo","Di","Mi","Do","Fr","Sa"],
    dayNamesMin: ["So","Mo","Di","Mi","Do","Fr","Sa"],
    weekHeader: "Wo",
    firstDay: 1,
  showOn: "button",
  buttonImage: "/zul/img/kal.gif",
  buttonImageOnly: true
 });


 $(".datepicker").change(function() {
 debugger;
          var newDate = $(this).val();
          var id = $(this).attr("id");
          var id_num = $(this).attr("id").match(/\d+$/)[0];
           //alert(id_num);
          document.getElementById("default" + id_num).value = newDate;
          document.getElementById("default" + id_num).selected = true;
          aktualisieren();
});

 $(".edatepicker").change(function() {

          var newDate = $(this).val();
          var id = $(this).attr("id");

          var id_num = id.substring(id.indexOf("_",2)+1,id.length);//$(this).attr("id").match(/\d+$/)[0];
           //alert(id_num);

          document.getElementById("default_" + id_num).value = newDate;
          document.getElementById("default_" + id_num).text=newDate;
          document.getElementById("default_" + id_num).selected = true;
          //aktualisieren();
});




 });


 </script>
 ');
  htp.headclose;

  htp.bodyopen('','onLoad="start('||zuviele||','||anzahl||','||hk||aanzeigen||hk||')"');

  systemzul.hilfe;

    htp.print ('
      <script language="javascript">

      if ('||zuviele||'!==0 &&'||anzahl||'>250 ) {         // &&"'||aanzeigen||'"!="fbv" &&"'||aanzeigen||'"!="zul")  {
          alert('||anzahl||' + " '||translation.translate('TEXT.ALERT.XEINTRAEGEKANNDAUERN')||'...");
      }

      function start(zuviele,anzahl,anzeigen)
      {
    ');

    zul_admin.self_top;

    htp.print('
        if ((zuviele==0 &anzahl>'||anzmax||') || (anzeigen=="fbv" &anzahl>'||anzmax||') || (anzeigen=="zul" &anzahl>'||anzmax||'))  {
          alert("'||translation.translate_ph('TEXT.PH.ALERT.ZUVIELEEINTRAEGE',p1 => anzmax)||'");
        }
      }

      function sortieren(sorton)
      {
        document.filter_form.sort_on.value=sorton;
        document.filter_form.submit();
      }

      function filter()
      {
        document.filter_form.sort_dir.value="";
        document.filter_form.submit()
      }

      function selall(thiselement)
      {
        for ( i=0; i<document.antrid_form.elements.length; i++ ) {
          if ( document.antrid_form.elements[i].name == "antrids" ) {
            document.antrid_form.elements[i].checked = thiselement.checked;
          }
        }
      }
      function verl()
      {



        if ($( "input[name=''antrids'']:checked" ).length==0) {
          alert("'||translation.translate('TEXT.ALERT.KEINANTRAGSELEKTIERT')||'");
          return false;
        }
         document.antrid_form.url.value = url();

       $("select[name=''antrmandidverfdat'']").each(function(){
            var thisSel=this;
               if (!$( "input[id=''c"+thisSel.id+"'']" )[0].checked){
                 thisSel.disabled=true;
              }
          });
        debugger;

        document.antrid_form.submit();
      }

      function checkit()
      {
        j=0;
        for ( i=0; i<document.antrid_form.elements.length; i++ ) {
          if ( document.antrid_form.elements[i].type == "checkbox" ) {
             if (document.antrid_form.elements[i].checked) { j++ }
          }
        }
        if (j==0) {
          alert("'||translation.translate('TEXT.ALERT.KEINANTRAGSELEKTIERT')||'");
          return false;
        }

        if (document.antrid_form.aktion.options[document.antrid_form.aktion.selectedIndex].value==0)
        {
          alert("'||translation.translate('TEXT.ALERT.KEINEAKTIONAUSGW')||'");
          return false;
        }

        if (document.antrid_form.aktion.options[document.antrid_form.aktion.selectedIndex].value==4)
        {
          ok = confirm("'||translation.translate('TEXT.CONFIRM.ANTRAEGELOESCHEN')||'");
          if (ok==false) {
            return false;
          }
        }

        if (document.antrid_form.aktion.options[document.antrid_form.aktion.selectedIndex].value==6)
        {
          ok = confirm("'||translation.translate('TEXT.CONFIRM.WEINTRAEGELOESCHEN')||'");
          if (ok==true) {
            document.antrid_form.aktion.options[document.antrid_form.aktion.selectedIndex].value=61;
          }
        }

        if (document.antrid_form.aktion.options[document.antrid_form.aktion.selectedIndex].value==11)
        {
          pmid_1 = "' || pmid || '";
          pmid_2 = document.filter_form.pmid.options[document.filter_form.pmid.selectedIndex].value;

          if (pmid_2 == "-1") {
            alert("'||translation.translate('TEXT.ALERT.MANDFILTERNICHTBELEGT')||'");
            return false;
          }

          if (pmid_1 !== pmid_2) {
            alert("'||translation.translate('TEXT.ALERT.LISTEERSTNACHMANDFILTERN')||'");
            return false;
          }

          ok = confirm("'||translation.translate('TEXT.CONFIRM.AUSGWMANDLOESCHEN')||'");
          if (ok==false) {
            return false;
          }

          document.antrid_form.pmid.value = pmid_2;
        }

        if (document.antrid_form.aktion.options[document.antrid_form.aktion.selectedIndex].value==12)
        {
          OK = confirm("'||translation.translate('TEXT.CONFIRM.EMAILLISTEDERANTRST')||'");
          if (!OK) { return false; }
        }


        if (document.antrid_form.aktion.options[document.antrid_form.aktion.selectedIndex].value==13)
        {
          if ((document.filter_form.pmid.value<0)||(document.filter_form.pmid.value!='||nvl(pmid,'-1')||'))
          {
            alert("'||translation.translate('TEXT.ALERT.MUSSMIND1MANDAUSGW')||'");
            return;
          }
          OK = confirm("'||translation.translate('TEXT.CONFIRM.P1.ALLE')||' \""+document.filter_form.pmid.options[document.filter_form.pmid.selectedIndex].text+"\"-'||translation.translate('TEXT.CONFIRM.P2.MANDSTORNIEREN')||'");
          if (!OK) { return false; }

          document.antrid_form.pmid.value = document.filter_form.pmid.value;
        }


        if (document.antrid_form.aktion.options[document.antrid_form.aktion.selectedIndex].value==14)
        {
          if ((document.filter_form.pmid.value<0)||(document.filter_form.pmid.value!='||nvl(pmid,'-1')||'))
          {
            alert("'||translation.translate('TEXT.ALERT.MUSSMIND1MANDAUSGW')||'");
            return;
          }
          OK = confirm("'||translation.translate('TEXT.CONFIRM.P1.ALLE')||' \""+document.filter_form.pmid.options[document.filter_form.pmid.selectedIndex].text+"\"-'||translation.translate('TEXT.CONFIRM.P2.MANDZULASSEN')||'");
          if (!OK) { return false; }

          document.antrid_form.pmid.value = document.filter_form.pmid.value;
        }


        if (document.antrid_form.aktion.options[document.antrid_form.aktion.selectedIndex].value==15)
        {
          if (('||spezialfilter||'!=14)||(document.filter_form.spezialfilter.value!=14))
          {
            alert("'||translation.translate('TEXT.ALERT.SPEZIALFILTERVORHERANW')||': \""+document.filter_form.spezialfilter.options[14].text+"\" !");
           return;
          }

          if (document.filter_form.pmid.value!='||nvl(pmid,'-1')||')
          {
            alert("'||translation.translate('TEXT.ALERT.MANDFILTEREINGESTELLT')||'");
            return;
          }

          OK = confirm("'||translation.translate('TEXT.CONFIRM.P1.ALLE')||' \""+document.filter_form.pmid.options[document.filter_form.pmid.selectedIndex].text+"\"-'||translation.translate('TEXT.CONFIRM.P2.MANDVERLAENG')||'");
          if (!OK) { return false; }

          document.antrid_form.pmid.value = document.filter_form.pmid.value;
        }

        document.antrid_form.url.value = url();
        document.antrid_form.submit();
      }

      function url()
      {
        purl = "zul.verlaengerung.antrag_alle" +
              "?anzeigen="      +   document.filter_form.anzeigen.value +
              "&sysid="         +   document.filter_form.sysid.options[document.filter_form.sysid.selectedIndex].value +
              "&abt="           +   document.filter_form.abt.value +
              "&pmid="          +   document.filter_form.pmid.options[document.filter_form.pmid.selectedIndex].value +
              "&vastatus="      +   document.filter_form.vastatus.options[document.filter_form.vastatus.selectedIndex].value +
              "&proid="         +   document.filter_form.proid.options[document.filter_form.proid.selectedIndex].value +
              "&name="          +   document.filter_form.name.value +
              "&antrsteller="   +   document.filter_form.antrsteller.value ;

        if ((document.filter_form.anzeigen.value != "usr") &&(document.filter_form.anzeigen.value != "ext")) {

          purl = purl + "&spezialfilter=" + document.filter_form.spezialfilter.value;
        }
              //"&sort_on="    +   document.filter_form.sort_on.value +
              //"&sort_dir="   +   document.filter_form.sort_dir.value;

        purl = purl.replace(/%/,"*");
        return purl;
      }

      function details(antrid)
      {
        document.detail_form.url.value = url();
        document.detail_form.antrid.value = antrid;

        document.detail_form.submit();

      }
          function allesetzen(){
      var selectedIndexAll=$("select[name=''antrmandidverfdatall'']")[0].selectedIndex;
      var selectedValueAll=$("select[name=''antrmandidverfdatall'']")[0].value;

      $( "input[name=''antrids'']:checked" ).each(function(){

          $("option[id=''default_"+this.value+"'']")[0].parentElement.selectedIndex=selectedIndexAll;
          $("option[id=''default_"+this.value+"'']")[0].parentElement.parentElement.style.backgroundColor=$("select[name=''antrmandidverfdatall'']")[0].options[selectedIndexAll].style.backgroundColor;
          //$("option[id=''default_"+this.value+"'']")[0].style.backgroundColor;
          //debugger;
          if ((selectedIndexAll==0) &&(selectedValueAll!=="")){
              $("option[id=''default_"+this.value+"'']")[0].value=selectedValueAll;
              $("option[id=''default_"+this.value+"'']")[0].text=selectedValueAll;
          }

      });

   }
      </script>');


    systemzul.syszul_kopf;

    htp.tableopen(cattributes=>'border="0" cellspacing="1" cellpadding="2" bordercolor="#FFFFFF" ');

      -- Spaltenbreiten
      htp.tablerowopen(cattributes=>'bgcolor="'||grau||'"');
        dummyspalte(30);  -- ID
        dummyspalte(60);  -- Datum
        dummyspalte(60);  -- Name
        dummyspalte(80);  -- Abt.
        dummyspalte(80);  -- Abt. bei Antragstellung
        dummyspalte(90);  -- System / Status
        dummyspalte(80);  -- Profil
        dummyspalte(80);  -- Mandant1
        if aanzeigen in ('fbv') then
          dummyspalte(10);  -- Vertretung ...
        end if;
        dummyspalte(60);  -- Mandant2 / Status
        dummyspalte(30);
        dummyspalte(60);  -- Details
        dummyspalte(60);  -- Datum
        dummyspalte(30);  -- Mail
        if aanzeigen in ('adm','zul','par','hil','beo') then
          colspan:=15;
        elsif aanzeigen in ('syg') then
          colspan:=13;          
        elsif aanzeigen in ('vor') then
          colspan:=13;
        ELSIF aanzeigen in ('fbv') THEN
          colspan:=14;
        ELSE
         colspan := 10;
        end if;

      htp.tablerowclose;

     
      -- Titelzeile
      htp.tablerowopen(cattributes=>'bgcolor="'||grau||'"');
        if aanzeigen in ('adm','hil') then
          atitel := anzahl||' '||translation.translate('TITLE.ANTRAEGEUEBERBLICK');
        elsif aanzeigen='fbv' then
          --atitel := anzahl||' '||translation.translate('TITLE.ANTRAEGEFACH');
          atitel := anzahl||' '||translation.translate('TITLE.RECERTANTRAEGEFACH');
        elsif aanzeigen='usr' then
          atitel := anzahl||' '||translation.translate('TITLE.ANTRAEGEPERSONLICHE');
        elsif aanzeigen='ext' then
          atitel := anzahl||' '||translation.translate('TITLE.ANTRAEGEPERSFURANDERE');
        elsif aanzeigen='zul' then
          atitel := anzahl||' '||translation.translate('TITLE.ANTRAEGESYSVER');
        elsif aanzeigen='ins' then
          atitel := anzahl||' '||translation.translate('TITLE.ANTRAEGEINSTALLATEUR');
        elsif aanzeigen='syg' then
          atitel := anzahl||' '||translation.translate('TITLE.ANTRAEGESYSGEN');
        elsif aanzeigen='par' then
          atitel := anzahl||' '||translation.translate('TITLE.ANTRAEGESYSANSPRECHP');
        elsif aanzeigen='vor' then
          atitel := anzahl||' '||translation.translate('TITLE.ANTRAEGEVORGESETZTER');
        elsif aanzeigen='beo' then
          atitel := anzahl||' '||translation.translate('TITLE.ANTRAEGEZULBEOB');
        end if;

        htp.tabledata('<b>'||atitel,ccolspan=>colspan-5);

        htp.tabledata(bl, cattributes=>'colspan="5"');

      htp.tablerowclose;

htp.formopen('zul.rezertifizierung.antrag_alle','post',cattributes=>'name="filter_form" onsubmit="filter()"');

      htp.formhidden('anzeigen',aanzeigen);
      htp.formhidden('antrsteller',antrsteller);


      -- Spaltenköpfe mit Sortiersymbolen
      htp.tablerowopen(cattributes=>'bgcolor="'||grau||'"');
        htp.tabledata('ID',cattributes=>'valign="top"');

       -- htp.tabledata('Datum');
          if asort_on='antragsid' then
            asort_d1 := asort_dir;
          else
            asort_d1 := 0;
          end if;
          htp.tabledata(translation.translate('SPALTE.DATUM')||' <a href="javascript:sortieren(''antragsid'')"><img src="/zul/img/sort_up'||to_char(asort_d1)||'.gif"border="0" alt="Sortieren ..."></a>',cattributes=>'bgcolor="'||grau||'"');

        --htp.tabledata('Name');
         if asort_on='antrstname' then
            asort_d1 := asort_dir;
          else
            asort_d1 := 0;
          end if;
          htp.tabledata(translation.translate('SPALTE.NAMEVORNAME')||' <a href="javascript:sortieren(''antrstname'')"><img src="/zul/img/sort_up'||to_char(asort_d1)||'.gif"border="0" alt="Sortieren ..."></a>',cattributes=>'bgcolor="'||grau||'"');
       
         --htp.tabledata('Abt. akt.',cattributes=>'valign="top"');
         if asort_on='mitarbeiter.kurzz(antrst7)' then
            asort_d1 := asort_dir;
          else
            asort_d1 := 0;
          end if;
          htp.tabledata(translation.translate('SPALTE.ABTEILUNGAKT')||' <a href="javascript:sortieren(''mitarbeiter.kurzz(antrst7)'')"><img src="/zul/img/sort_up'||to_char(asort_d1)||'.gif"border="0" alt="Sortieren ..."></a>',cattributes=>'bgcolor="'||grau||'"');

        htp.formhidden('sort_on','');
        htp.formhidden('sort_dir',asort_dir);

        if aanzeigen in ('adm','zul','fbv','syg','par','vor','hil','beo') then
         if asort_on='antrstkz,antrstname' then
            asort_d1 := asort_dir;
          else
            asort_d1 := 0;
          end if;
          htp.tabledata(translation.translate('SPALTE.ABTEILUNGALT')||' <a href="javascript:sortieren(''antrstkz,antrstname'')"><img src="/zul/img/sort_up'||to_char(asort_d1)||'.gif"border="0" alt="Sortieren ..."></a>',cattributes=>'bgcolor="'||grau||'"');
        end if;

        htp.tabledata('System',cattributes=>'valign="top"');

        htp.tabledata(translation.translate('SPALTE.PROFIL'),cattributes=>'valign="top"');
        htp.tabledata(translation.translate('SPALTE.MANDANT'),cattributes=>'valign="top"');
        if aanzeigen in ('fbv') then
              htp.tabledata(persgif,calign=>'center');
          end if;

          htp.tabledata(translation.translate('NAVI.RECERTIFICATIONS'),cattributes=>'bgcolor="'||grau||'"');
          htp.tabledata('Info',cattributes=>'valign="top"');
          htp.tabledata(translation.translate('SPALTE.ABLAUFDATUMAKT'),cattributes=>'bgcolor="'||grau||'"');
          htp.tabledata(translation.translate('SPALTE.ABLAUFDATUMNEU'),cattributes=>'bgcolor="'||grau||'"');
        htp.tabledata(translation.translate('SPALTE.AUSW'), cattributes=>'align="center" valign="top"');
      htp.tablerowclose;

      -- Spaltenköpfe mit Pulldownmenüs zum Filtern
      htp.tablerowopen(cattributes=>'bgcolor="'||grau||'"');
          htp.tabledata(bl);
          htp.tabledata(bl);

          -- Eingabefeld Name
          if aanzeigen<>'usr' then
            htp.print('<td bgcolor="'||grau||'">');
               htp.print('<input type="text" name="name" class="eingabe" size="15" value="'||zul_admin.check_str(name)||'" maxlength="30">');
            htp.print('</td>');
          else
            htp.tabledata(bl);
            htp.formhidden('name','');
          end if;

          -- Eingabefeld Abteilung
          if aanzeigen<>'usr' then
            htp.print('<td bgcolor="'||grau||'"><p>');
              htp.print('<input type="text" name="abt" class="eingabe" size="12" value="'||zul_admin.check_str(abt)||'" maxlength="20">');
            htp.print('</p></td>');
          else
            htp.tabledata(bl);
            htp.formhidden('abt','');
          end if;

          if aanzeigen in ('adm','zul','fbv','syg','par','vor','hil','beo') then
            htp.print('<td bgcolor="'||grau||'"><p>');
              htp.print('<input type="text" name="abtalt" class="eingabe" size="12" value="'||zul_admin.check_str(abtalt)||'" maxlength="20">');
            htp.print('</p></td>');
            --htp.tabledata(bl);

          end if;

          -- Pulldown System
          if aanzeigen = 'zul' then
            vSqlSys(1) := 'select systemid,name from egsysteme where usereinrichter like :astnrzul order by upper(name)';
            vBindsSys(1).name := 'astnrzul';
            vBindsSys(1).val := anydata.ConvertVarchar2(astnrzul);
          elsif aanzeigen='syg' then
            vSqlSys(1) := 'select systemid,name from egsysteme where genehmiger like :astnrsyg order by upper(name)';
            vBindsSys(1).name := 'astnrsyg';
            vBindsSys(1).val := anydata.ConvertVarchar2(astnrsyg);
          elsif aanzeigen='par' then
            vSqlSys(1) := 'select systemid,name from egsysteme where fbverant like :astnrpar order by upper(name)';
            vBindsSys(1).name := 'astnrpar';
            vBindsSys(1).val := anydata.ConvertVarchar2(astnrpar);
          elsif aanzeigen='beo' then
            vSqlSys(1) := 'select systemid, name from egsysteme where systemid in (select pmid-10000 from antraege a, antragsdatenprofile adp where profilid=180 and adp.status=500 and a.antrst7 = :usr and a.antragsid=adp.antragsid) order by upper(name)';
            vBindsSys(1).name := 'usr';
            vBindsSys(1).val := anydata.ConvertVarchar2(substr(fips.user,1,7));
          else
            vSqlSys(1) := 'select systemid,name from egsysteme order by upper(name)';
          end if;

          vCursorSys := pa_sql.getCursor(vBindsSys,vSqlSys);
          htp.print('<td bgcolor="'||grau||'"><p>');
            htp.formselectopen('sysid',cattributes=>'class="eingabe"');
              htp.formSelectOption(translation.translate('SELECT.ALLE'),'','value="0"');

              loop
                fetch vCursorSys into v_sid, v_sn;
                EXIT WHEN vCursorSys%NOTFOUND;
                if sysid = v_sid
                  then sel := '1';
                  else sel := NULL;
                end if;
                htp.formSelectOption(zul_admin.check_str(v_sn),sel,'value="'||v_sid||'"');
              end loop;

            htp.formselectclose;
          htp.print('</p></td>');
          close vCursorSys;


          -- Pulldown Profil
          htp.print('<td bgcolor="'||grau||'"><p>');
            htp.formselectopen('proid',cattributes=>'class="eingabe"');
              htp.formSelectOption(translation.translate('SELECT.ALLE'),'','value="0"');
              for iy in (select profilid,name from egsystemprofile where systemid like asysid order by name)
                loop
                if proid = iy.profilid
                  then sel := '1';
                  else sel := NULL;
                end if;
                htp.formSelectOption(zul_admin.check_str(iy.name),sel,'value="'||iy.profilid||'"');
              end loop;
            htp.formselectclose;
          htp.print('</p></td>');

          -- Pulldown Mandant
          htp.print('<td bgcolor="'||grau||'"><p>');
            htp.formselectopen('pmid',cattributes=>'class="eingabe"');
              htp.formSelectOption(translation.translate('SELECT.ALLE'),'','value="-1"');
              --for iy in (select pmid,kurzbez from produktmandant where aktiv='1' order by kurzbez)
              for iy in (SELECT unique prfm.pmid ppmid,kurzbez
                            FROM PROFILMANDANT prfm, produktmandant prdm, egsystemprofile egs
                               WHERE prfm.PROFILID LIKE aproid and egs.systemid like asysid
                                   and prfm.profilid = egs.profilid and prfm.pmid=prdm.pmid
                                     order by kurzbez)
              loop
                if pmid = iy.ppmid
                  then sel := '1';
                  else sel := NULL;
                end if;
                htp.formSelectOption(zul_admin.check_str(iy.kurzbez),sel,'value="'||iy.ppmid||'"');
              end loop;
            htp.formselectclose;
          htp.print('</p></td>');

          --htp.tabledata('<a href="javascript:filter()"><img src="/zul/img/lupe.gif"border="0" alt="Filtern ..."></a>',calign=>'center',cattributes=>'bgcolor="'||grau||'"');

          if aanzeigen in ('fbv') THEN
               if vertretung=1 then sel := 'checked'; else sel := null; end if;
              htp.print('<TD align="center"><p><input type="checkbox" name="vertretung" value="1" '|| sel ||'></p></TD>');
          end if;
           htp.print('<td bgcolor="'||grau||'" ><p>');
              htp.formselectopen('vastatus',cattributes=>'class="eingabe"');

                htp.formSelectOption(translation.translate('SELECT.ALLE'),'','value="0"');
                htp.formSelectOption(translation.translate('SELECT.ZERTIFIZIERT'),CASE WHEN vastatus='beantragt' THEN '1' ELSE '' END,'value="beantragt"');
                htp.formSelectOption(translation.translate('SELECT.NICHTZERTIFIZIERT'),CASE WHEN vastatus='verlängert' THEN '1' ELSE '' END,'value="verlängert"');
                htp.formSelectOption(translation.translate('SELECT.ZERTIFIZIERUNGABGELAUFEN'),CASE WHEN vastatus='abgelehnt' THEN '1' ELSE '' END,'value="abgelehnt"');
               /* htp.formSelectOption(translation.translate('SELECT.BEANTRAGT'),CASE WHEN vastatus='beantragt' THEN '1' ELSE '' END,'value="beantragt"');
                htp.formSelectOption(translation.translate('SELECT.VERLAENGERT'),CASE WHEN vastatus='verlängert' THEN '1' ELSE '' END,'value="verlängert"');
                htp.formSelectOption(translation.translate('SELECT.ABGELEHNT'),CASE WHEN vastatus='abgelehnt' THEN '1' ELSE '' END,'value="abgelehnt"');*/
                     
                

              htp.formselectclose;
            htp.print('</p></td>');
          htp.tabledata('<input type="image" src="/zul/img/lupe.gif">', cattributes=>'align="center"');
 htp.tabledata(bl);
          htp.tabledata(bl);          
 htp.tabledata(bl);
        htp.tablerowclose;


         if aanzeigen in ('adm','zul','fbv','syg','par','hil','beo','vor') then
            htp.tablerowopen(cattributes=>'bgcolor="'||grau||'"');
              htp.tabledata(translation.translate('LABEL.SPEZIALFILTER'),ccolspan=>colspan-7, calign=>'right');
              htp.print('<td >');
                htp.formselectopen('spezialfilter',cattributes=>'class="eingabe"');
                  for ix in (select code,filter from FILTER_ANTRAG WHERE code IN (0,15,16)order by code)
                  loop
                    if spezialfilter = ix.code then sel := 1; else sel := NULL; end if;
                    htp.formSelectOption(zul_admin.check_str(translation.translate('SELECT.FILTER.'||ix.code)),sel,'value="'||ix.code||'"');
                  end loop;
                htp.formselectclose;
              htp.print('</td>');
              htp.tabledata(bl);  htp.tabledata(bl); htp.tabledata(bl); htp.tabledata(bl); htp.tabledata(bl); htp.tabledata(bl);
            htp.tablerowclose;
         end if;

htp.formclose;  -- filter_form


htp.formopen('zul.rezertifizierung.verantr_save?','post',cattributes=>'name="antrid_form" onsubmit="return checkit()"');

--htp.print('<br>'||aanzeigen||'<br>'||v_antr_curs);

      vCursor := pa_sql.getCursor(vBinds,vSql);
      loop
        if aanzeigen = 'fbv' then
           fetch vCursor into v_antragsid, v_antrdatum, v_antrst, v_antrstkz, v_sn, v_pn, v_profilid, v_antrstat, v_antrstname, v_kzzakt,  v_is_vertreter;
        else
           fetch vCursor into v_antragsid, v_antrdatum, v_antrst, v_antrstkz, v_sn, v_pn, v_profilid, v_antrstat, v_antrstname, v_kzzakt;
        end if;
        EXIT WHEN vCursor%NOTFOUND;

        IF vertretung<>0 AND  v_is_vertreter!='1' THEN
            continue;
        END IF;

if instr(antrstati, ','||v_antrstat||',') > 0  then

        -- user kann einen eigenen Antrag löschen
        perloesch := aanzeigen='usr' or aanzeigen='ext';

        -- Abfrage für FBV's
        if aanzeigen = 'fbv' then
            if apmstat <> '%' then
              vVcTab := pa_sql.getVcTabFromList(apmstat,',');
            end if;

            OPEN vWcursor FOR
            'select pm.kurzbez, adp.status, adp.verfdatum, adp.pmid, adpv.status, adpv.LDATUM, adpv.kommentar
                   ,case when :astnrfbv not in (coalesce(upper(pfm.genehmiger1),''NOQ''),coalesce(upper(pfm.genehmiger2),''NOQ''), coalesce(upper(pfm.genehmiger3),''NOQ'')) then ''J'' else ''N'' end as is_vertreter
             from antragsdatenprofile adp, produktmandant pm, v_profmand_vertreter pfm, adp_verlaengerung adpv
             where adpv.antragsid(+) = adp.antragsid
               and adpv.pmid(+) = adp.pmid
               and adp.antragsid = :v_antragsid
               and adp.pmid=pm.pmid and adp.pmid like :apmid
               and (:apmstatstr = ''%'' or adpv.status in (select column_value from table(:apmstat)))
               and adp.pmid = pfm.pmid
               and adp.status = 500
               and adp.verfdatum is not null
               and pfm.profilid = :v_profilid '||v_spez_filt_mand||'
               and (:astnrfbv in(coalesce(upper(pfm.genehmiger1),''NOQ''),coalesce(upper(pfm.genehmiger2),''NOQ''), coalesce(upper(pfm.genehmiger3),''NOQ'')) or instr(coalesce(pfm.vertreter,''''),:astnrfbv) <> 0)
             order by kurzbez'
            using upper(astnrfbv), v_antragsid, apmid, apmstat, vVcTab, v_profilid, upper(astnrfbv), upper(astnrfbv);

            OPEN vAmCursor FOR
            'select count(adp.pmid)
             from antragsdatenprofile adp, produktmandant pm, v_profmand_vertreter pfm, adp_verlaengerung adpv
             where adpv.antragsid(+) = adp.antragsid
               and adpv.pmid(+) = adp.pmid
               and adp.antragsid = :v_antragsid
               and adp.pmid = pm.pmid
               and adp.pmid like :apmid
               and (:apmstatstr = ''%'' or adpv.status in (select column_value from table(:apmstat)))
               and adp.pmid = pfm.pmid
               and adp.status = 500
               and adp.verfdatum is not null
               and pfm.profilid = :v_profilid '||v_spez_filt_mand||'
               and (:astnrfbv in(coalesce(upper(pfm.genehmiger1),''NOQ''),coalesce(upper(pfm.genehmiger2),''NOQ''), coalesce(upper(pfm.genehmiger3),''NOQ'')) or instr(coalesce(pfm.vertreter,''''),:astnrfbv) <> 0)
             order by kurzbez'
            using v_antragsid, apmid, apmstat, vVcTab, v_profilid, upper(astnrfbv), upper(astnrfbv);
         else
           -- Abfrage allgemein
          vMandSql(1) := ' select pm.kurzbez, adp.status, adp.verfdatum, adp.pmid, adpv.status, adpv.LDATUM, adpv.kommentar from antragsdatenprofile adp left join produktmandant pm
                            on adp.pmid = pm.pmid left join ADP_VERLAENGERUNG adpv on adpv.antragsid=adp.ANTRAGSID and adpv.pmid=adp.pmid where adp.verfdatum is not null  and adp.antragsid = :v_antragsid';
          vMandAnzSql(1) := 'select count(adp.pmid) from antragsdatenprofile adp left join produktmandant pm
                            on adp.pmid=pm.pmid left join ADP_VERLAENGERUNG adpv on adpv.antragsid=adp.ANTRAGSID and adpv.pmid=adp.pmid
                            where adp.antragsid = :v_antragsid and adp.verfdatum is not null';

          vMandBinds(vMandBindIdx).name := 'v_antragsid';
          vMandBinds(vMandBindIdx).val := anydata.ConvertNumber(v_antragsid);
          vMandBindIdx := vMandBindIdx + 1;
          if apmid <> '%' then
            vMandSql(1) := vMandSql(1) || ' and adp.pmid = :apmid';
            vMandAnzSql(1) := vMandAnzSql(1) || ' and adp.pmid = :apmid';

            vMandBinds(vMandBindIdx).name := 'apmid';
            vMandBinds(vMandBindIdx).val := anydata.ConvertNumber(apmid);
            vMandBindIdx := vMandBindIdx + 1;
          end if;


           if apmstat <> '%' THEN
             vVcTab := pa_sql.getVcTabFromList(apmstat,',');
             vMandSql(1) := vMandSql(1) || ' and adpv.status in (select column_value from table(:apmstat))';
             vMandAnzSql(1) := vMandAnzSql(1) || ' and adpv.status in (select column_value from table(:apmstat))';
             vMandBinds(vMandBindIdx).name := 'apmstat';
             vMandBinds(vMandBindIdx).val := anydata.ConvertCollection(vVcTab);
             vMandBindIdx := vMandBindIdx + 1;
           end if;

           vMandSql(1) := vMandSql(1) || ' and adp.status in (500)';
           vMandAnzSql(1) := vMandAnzSql(1) || ' and adp.status in (500)';
           vMandSql(1) := vMandSql(1) || ' order by kurzbez';

           vWCursor := pa_sql.getCursor(vMandBinds,vMandSql);
           vAmCursor := pa_sql.getCursor(vMandBinds,vMandAnzSql);
          end if;

        angezeigt := angezeigt + 1;
        exit when angezeigt > anzmax;

       fetch vAmCursor into anzmand;
       close vAmCursor;

        htp.tablerowopen(cattributes=>'bgcolor="'||hgrau||'"');
         htp.tabledata(v_antragsid||'    <a href="javascript:details('||v_antragsid||');"><img height="10px" src="/zul/img/edit.gif"border="0" alt="Details ..."></a>',cattributes=>h28, crowspan=>anzmand);

          htp.tabledata(to_char(v_antrdatum,'DD.MM.YY'), crowspan=>anzmand);
          htp.tabledata(v_antrstname||' ('||mis.extkennz(v_antrst)||')', crowspan=>anzmand);
          htp.tabledata(systemzul.akt_kurzz(v_antrst), crowspan=>anzmand);

          if aanzeigen in ('adm','zul','fbv','syg','par','vor','hil','beo') then
            htp.tabledata(v_antrstkz, crowspan=>anzmand);
          end if;
          htp.tabledata(zul_admin.check_str(v_sn),cattributes=>'bgcolor="'||v_statusfarben(v_antrstat)||'"', crowspan=>anzmand);

          htp.tabledata(zul_admin.check_str(substr(v_pn,1,15)), crowspan=>anzmand);
                actmand := 0;
                  loop
                    if aanzeigen = 'fbv' then
                       fetch vWCursor into v_kurzbez, v_pmstatus, v_verfdatum,  v_adppmid, v_adpvstat, v_adpvldat, v_adpvkomm,v_is_pm_vertreter;
                    else
                       fetch vWCursor into v_kurzbez, v_pmstatus, v_verfdatum,  v_adppmid, v_adpvstat, v_adpvldat, v_adpvkomm;
                    end if;
                    EXIT WHEN vWCursor%NOTFOUND;
                    if instr(mandstati, ','||v_pmstatus||',') > 0 then

                    if actmand <>0 then htp.tablerowclose(); htp.tablerowopen(cattributes=>'bgcolor="'||hgrau||'"'); end if;
                   if aanzeigen = 'fbv' then
                    IF v_is_pm_vertreter='J' then
                      htp.print('<td width="60" title="in Vertretung" bgcolor="'|| v_statusfarben(v_pmstatus) || '" style="color:#4f81bd; ">' || zul_admin.check_str(v_kurzbez) ||'</td>');
                      ELSE
                      htp.print('<td width="60" bgcolor="'|| v_statusfarben(v_pmstatus) || '">' || zul_admin.check_str(v_kurzbez) || '</td>');
                      END IF;

                      IF v_is_pm_vertreter='J' then
                  htp.tabledata(persgif, calign=>'center');  -- Vertretung ...
                  ELSE
                  htp.tabledata(bl);
                  END IF;
                  else
                    htp.print('<td width="60" bgcolor="'|| v_statusfarben(v_pmstatus) || '">' || zul_admin.check_str(v_kurzbez) || '</td>');
                  end if;
                      htp.tabledata(CASE v_adpvstat
                              WHEN 'beantragt' THEN translation.translate('SELECT.BEANTRAGT')
                              WHEN 'verlängert' THEN translation.translate('SELECT.VERLAENGERT')
                              WHEN 'abgelehnt' THEN   translation.translate('SELECT.ABGELEHNT')
					                    END ,cattributes => 'bgcolor="'||
                          CASE v_adpvstat
                              WHEN '' THEN grau
                              WHEN 'beantragt' THEN '#C0FFFF'
                              WHEN 'verlängert' THEN '#80FF80'
                              WHEN 'abgelehnt' THEN   '#FF4040'
                           END || '"');

                     htp.tabledata(CASE WHEN v_adpvstat IS NOT NULL THEN '<img src="/zul/img/info1.gif" border="0" title="'||v_adpvkomm||'" onclick="alert('''||replace(v_adpvkomm,chr(10),'\n')||''');">' END, cattributes => h28||' align="center" bgcolor="'||hgrau||'"');

                     htp.tabledata(to_char(v_verfdatum,'DD.MM.YY'));
                      htp.print('<TD  colspan="1">');
                       htp.formselectopen('antrmandidverfdat',cattributes => 'id="'||v_antragsid||'_'||v_adppmid||'" style="width: 80%;" onChange="this.parentElement.style.backgroundColor=this[this.selectedIndex].style.backgroundColor; "');
                     for iy in (select id,text, CASE WHEN text='abgelehnt' THEN '01.01.0001' ELSE to_char(sysdate+tage,'DD.MM.YY') END  dat from mand_verfall where instr(ies,'V')>0 and id>0 order by order_num )
                       loop
                          htp.formSelectOption(translation.translate('SELECT.MANDVERFALL.'||iy.id,v_lang),sel, CASE WHEN iy.text='abgelehnt' THEN 'style="background-color:#FF4040;"' ELSE 'style="background-color:#80FF80;"' END ||' value="'||iy.dat||'"' || case when iy.dat IS NULL AND iy.text<>'abgelehnt' then ' id="default_'||v_antragsid||'_'||v_adppmid||'"' end);
                          ir_ok := (iy.text=ir and sel=1) or ir_ok;
                          sel := null;
                       end loop;
                       -- Kalender-Button, maxTage wird bei ext.MA mitgegeben

                       htp.print('<input name="antrverfdats" id="h_vondatum_'||v_antragsid||'_'||v_adppmid||'" type="hidden" class="edatepicker" disabled>');

                       htp.print('</TD>');

             htp.print('<TD align="center" ><p>');
               htp.print('<input type="checkbox" name="antrids" id="c'||v_antragsid||'_'||v_adppmid||'" value="'||v_antragsid||'_'||v_adppmid||'">');
             htp.print('</p></TD>');

                      actmand := actmand + 1;
                     end if;
                  end loop;
                  close vWCursor;
        htp.tablerowclose;
end if;
      end loop;
      close vCursor;


  if aanzeigen in ('adm','zul','fbv','ext','usr','syg','par','hil','beo','vor') then



           htp.tablerowopen(cattributes=>'bgcolor="'||grau||'"');
             htp.tabledata(ir || ': ' || ir_txt, ccolspan=>colspan,calign=>'center');
           htp.tablerowclose;

        htp.tablerowopen(cattributes=>'bgcolor="'||hgrau||'"');
          htp.tabledata(bl,ccolspan=>3);
          htp.tabledata(translation.translate('LABEL.AUSGEWAEHLTEVERLSETZEN')
,ccolspan=>3);
            htp.print('<TD  colspan="1">');
                       htp.formselectopen('antrmandidverfdatall',cattributes => 'style="width: 80%;"');--,cattributes => 'onChange="this.parentElement.style.backgroundColor=this[this.selectedIndex].style.backgroundColor; this.style.backgroundColor=this[this.selectedIndex].style.backgroundColor;"');
                     for iy in (select id,text, CASE WHEN text='abgelehnt' THEN '01.01.0001' ELSE to_char(sysdate+tage,'DD.MM.YY') END  dat from mand_verfall where instr(ies,'V')>0 and id>0 order by order_num )
                       loop
                          htp.formSelectOption(translation.translate('SELECT.MANDVERFALL.'||iy.id,v_lang),sel, CASE WHEN iy.text='abgelehnt' THEN 'style="background-color:#FF4040;"' ELSE 'style="background-color:#80FF80;"' END ||' value="'||iy.dat||'"' || case when iy.dat IS NULL AND iy.text<>'abgelehnt' then ' id="default_all"' end);
                end loop;
                       -- Kalender-Button, maxTage wird bei ext.MA mitgegeben
                       htp.print('<input name="antrverfdats" id="h_vondatum_all" type="hidden" class="edatepicker" disabled>');

                       htp.print('</TD>');
          htp.print('<TD colspan='||to_Char(colspan-10)||'  bgcolor="'||hgrau||'">');

         htp.print('<input type="button" name="auswählen" value="'||translation.translate('BUTTON.FUERAUSWAHLUEBERN')||'" onClick="allesetzen()">');
          htp.print('</td>');
          htp.tabledata(bl,ccolspan=>2);

          htp.tabledata('<input type="checkbox" onclick="selall(this)">',cattributes=>'align="center"');
       htp.tablerowclose;
  end if;

  if aanzeigen in ('adm','fbv','vor','syg') then
    htp.tablerowopen(cattributes=>'bgcolor="'||hgrau||'"');
      htp.tabledata(bl, ccolspan=>3);
      if aanzeigen = 'vor' then
         htp.tabledata(translation.translate('LABEL.KOMMENTAR'), ccolspan=>2);
      else
         htp.tabledata(translation.translate('LABEL.KOMMENTAR'), ccolspan=>3);
      end if;
      htp.print('<TD bgcolor="'||hgrau||'" valign="top" colspan="'|| case when aanzeigen='adm' then '8' else '6' end||'">');
        htp.print('<input type="text" name="komment" class="eingabe" size="100" value="" maxlength="100">');
      htp.print('</TD>');
      htp.tabledata(bl);
      htp.tabledata(bl);
    htp.tablerowclose;

   htp.tablerowopen(cattributes=>'bgcolor="'||grau||'"');

          htp.tabledata(bl,ccolspan=>6);
          htp.print('<TD colspan='||to_Char(colspan-8)||'  bgcolor="'||grau||'">');

            htp.print('<input type="button" name="verlaengern" value="'||translation.translate('BUTTON.SPEICHERN')||'" onClick="verl()">');
          htp.print('</td>');
          htp.tabledata(bl); htp.tabledata(bl);

       htp.tablerowclose;


  end if;

    htp.formhidden('url','');
    htp.formhidden('anzeigen',aanzeigen);

    htp.formhidden('pmid','');


htp.formclose; -- antrid_form

htp.formopen('','post',cattributes=>'name="sel_form"');
      htp.formhidden('selwen','1');
htp.formclose();  -- sel_form

htp.formopen('zul.systemzul.antrag_detail','get',cattributes=>'name="detail_form"');
  htp.formhidden('anzeigen',aanzeigen);
  htp.formhidden('antrid','');
  htp.formhidden('url','');

htp.formclose;
    htp.tableclose;

  htp.bodyclose;
  htp.htmlclose;

end;


procedure verantr_usr         (anzeigen       varchar2 default 'usr',
                               status         number   default 0,
                               sysid          number   default 0,
                               abt            varchar2 default null,
                               abtalt         varchar2 default null,
                               pmid           number   default -1,
                               vastatus       varchar2 default 0,
                               proid          number   default 0,
                               antrsteller    varchar2 default null,
                               name           varchar2 default null,
                               fbv            varchar2 default null,
                               sort_on        varchar2 default null,
                               sort_dir       number   default null,
                               spezialfilter  number   default 0,
                               ausrufez       number   default 0,
                               vertretung     NUMBER DEFAULT 0,
                               schatten       number   default 0,
                               x              number   default 6,
                               y              number   default 11)
is
   vCursor        sys_refcursor;
   vSysCursor     sys_refcursor;
   vProfCursor    sys_refcursor;
   vWCursor       sys_refcursor;
   vAmCursor      sys_refcursor;

   vSql           dbms_sql.varchar2a;
   vSysSql        dbms_sql.varchar2a;
   vProfSql       dbms_sql.varchar2a;
   vBinds         pa_sql.tBindTbl;
   vBindIdx       pls_integer := 1;

   vMandSql       dbms_sql.varchar2a;
   vMandAnzSql    dbms_sql.varchar2a;
   vMandBinds     pa_sql.tBindTbl;
   vMandBindIdx   pls_integer := 1;
   aanzeigen      varchar2(3);

   colspan        number(2)    := 0;            -- Spaltenanzahl Tabelle
   sel            varchar2(7);                  -- selektierte Eintrag in Pulldown
   asort_on       varchar2(40) := 'antragsid';  -- Sortierkrieterium
   asort_dir      number;                       -- Sortierrichtung

   asort_d1       number;                       -- temp. Sortierrichtung
   atitel         varchar2(60);

   astnr          antraege.antrst7%type; -- varchar2(6);
   aname          varchar2(40);
   aabt           antraege.antrstkz%TYPE;
   asysid         varchar2(6);
   aproid         varchar2(6);
   apmid          varchar2(9);
   apmstat        varchar2(100);
   aspezialfilt   varchar2(100);
   zuviele        number       := 0;
   anzahl         number       := 0;
   anzmax         number       := 50;
   angezeigt      number       := 0;
   anzmand        number       := 0;
   actmand        number:=0;
   v_verfdatum     date;
   v_adpvstat adp_verlaengerung.status%TYPE;
   v_adpvldat adp_verlaengerung.ldatum%TYPE;
   v_adpkomm adp_verlaengerung.kommentar%TYPE;

   v_antragsid    antraege.antragsid%type; --number(9);
   v_antrdatum    date;
   v_antrst       antraege.antrst7%type; -- varchar2(6);
   v_antrstname   varchar2(30);
   v_antrstkz     antraege.antrstkz%TYPE;
   v_sn           varchar2(40);
   v_sid          number(5);
    v_pname       egsystemprofile.name%TYPE;
   v_pid          egsystemprofile.profilid%TYPE;
   v_pn           varchar2(40);
   v_pmstatus     number(3);
   v_kurzbez      varchar2(12);
   v_is_pm_vertreter char(1);
   v_profilid     number(5);
   v_antrstat     number(3);
   v_kzzakt       antraege.antrstkz%TYPE;
   v_adppmid      antragsdatenprofile.pmid%TYPE;

   perloesch      boolean         := false; -- Erlaubnis als Nicht-adm eigene Anträge zu löschen ...

   antrstati      varchar2(50) := ',';      -- String mit Antragsstati, die der User sehen darf
   mandstati      varchar2(50) := ',';      -- String mit Mandantenstati, die der User sehen darf

   v_spez_filt_mand           varchar2(100);

   v_antr_select varchar2(500);
   v_antr_from   varchar2(400);
   v_antr_where  varchar2(800);
   v_antr_group  varchar2(500);
   v_antr_order  varchar2(400);
   v_antr_anz    integer;

   dudarfst      boolean := false;
begin
    v_antr_select :=
    'select unique a.antragsid, a.antrdatum, a.antrst7, a.antrstkz, s.name sn, p.name pn, a.profilid, a.status, substr(nachname || '', '' || vorname,1,30) antrstname, NULL  ';


  v_antr_from :=
    'from antraege a, egsysteme s, egsystemprofile p, misall m, antragsdatenprofile adp, adp_verlaengerung adpv ';

  v_antr_where :=
    'where antrst7 = qnummer(+) and a.profilid = p.profilid and s.systemid = p.systemid and a.antragsid = adp.antragsid(+) and adpv.ANTRAGSID(+)=adp.ANTRAGSID and adpv.PMID(+)=adp.pmid and a.status=500 and adp.verfdatum is not null and adp.status=500';

  v_antr_order :=
    ' order by ';

    aanzeigen := anzeigen;
----------------------------------------------------------------------------
-- Berechtigungsprüfung

    case aanzeigen
      when 'usr' then dudarfst := true;
      when 'ext' then dudarfst := true;
      else dudarfst := false;
    end case;

    if not dudarfst then
      systemzul.nicht_berechtigt;
      return;
    end if;
----------------------------------------------------------------------------
   -- String befüllen mit Antragsstati, die der angemeldete User anschauen darf
  for ix in (select status from antragsstatus where instr(zul,substr(aanzeigen,1,1))>0)
  loop
    antrstati := antrstati || to_char(ix.status) || ',';
  end loop;

  -- String befüllen mit Mandantenstati, die der angemeldete User anschauen darf
  for ix in (select status from antragsstatus where instr(mand,substr(aanzeigen,1,1))>0)
  loop
    mandstati := mandstati || to_char(ix.status) || ',';
  end loop;

  select sysemail into emailadr from syszul_prefs where datensatz='aktiv';

  init_antrstatus;
 init_inststatus;

  --astnr  := substr(fips.user,2,6);
  astnr  := substr(fips.user,1,7);


  -- Filter Name Antragssteller
  if name = 'NULL' then
    v_antr_where := v_antr_where ||  ' and nachname is null ';
  elsif name = 'NNULL' then
    v_antr_where := v_antr_where || ' and nachname is not null ';
  elsif substr(name,1,1) = '#' then
    v_antr_where := v_antr_where || ' and a.antragsid= :antragsid ';
    vBinds(vBindIdx).name := 'antragsid';
    vBinds(vBindIdx).val := anydata.ConvertNumber(substr(name,2,length(name)-1));
    vBindIdx := vBindIdx + 1;
  elsif substr(name,1,1) = '@' then
    v_antr_where := v_antr_where || ' and a.antrst7 like :antrst7 ';
    vBinds(vBindIdx).name := 'antrst7';
    vBinds(vBindIdx).val := anydata.ConvertVarchar2(substr(name,2,length(name)-1));
    vBindIdx := vBindIdx + 1;
  elsif name is not null then
    aname := rtrim(name);
    aname := replace (aname,'*','%');
    aname := replace (aname,' ',null);
    if instr(aname,'%')=0 then aname := aname || '%'; end if;
    v_antr_where := v_antr_where || ' and upper(nachname||'',''||vorname) like :aname ';
    vBinds(vBindIdx).name := 'aname';
    vBinds(vBindIdx).val := anydata.ConvertVarchar2(upper(aname));
    vBindIdx := vBindIdx + 1;
  end if;

	-- Filter Stammnummer
  if aanzeigen in ('adm','usr','ins','fbv','syg','par','vor','hil','beo') then
	  if astnr <> '%' then
      v_antr_where := v_antr_where  || ' and (a.antrst7 like :astnr or a.verantw7 like :astnr) ';
      vBinds(vBindIdx).name := 'astnr';
      vBinds(vBindIdx).val := anydata.ConvertVarchar2(astnr);
      vBindIdx := vBindIdx + 1;
    end if;
	end if;

  -- Filter aktuelles Abt.Kurzzeichen des Antragstellers
  if aanzeigen in ('adm','usr','zul','ext','fbv','syg','par','vor','hil','beo') then
    if abt = 'NULL' then
      v_antr_where := v_antr_where || ' and systemzul.akt_kurzz(a.antrst7) is null ';
    elsif abt = 'NNULL' then
      v_antr_where := v_antr_where || ' and systemzul.akt_kurzz(a.antrst7) is not null ';
    elsif abt is not null then
      aabt := rtrim(abt);
      aabt := replace (aabt,'*','%');
      if substr(aabt,1,1)='!' then
        aabt := substr(aabt,2);
      end if;
      v_antr_where := v_antr_where || ' and upper(systemzul.akt_kurzz(a.antrst7)) ' || case when substr(abt,1,1)='!' then 'not' end || ' like :aabt ';
      vBinds(vBindIdx).name := 'aabt';
      vBinds(vBindIdx).val := anydata.ConvertVarchar2(upper(aabt));
      vBindIdx := vBindIdx + 1;
    end if;
  end if;

  -- Filter SystemID
  if aanzeigen in ('adm','usr','zul','ext','fbv','syg','par','vor','hil','beo') then
    if (sysid is null) or (sysid=0) then
    	asysid := '%';
    else
	    asysid := replace(sysid,'*','%');
  	  zuviele := zuviele + 1;
    end if;

    if asysid <> '%' then
      if instr(asysid,'%') > 0 then
        v_antr_where := v_antr_where || ' and s.systemid like :asysid ';
        vBinds(vBindIdx).name := 'asysid';
        vBinds(vBindIdx).val := anydata.ConvertVarchar2(asysid);
        vBindIdx := vBindIdx + 1;
	    else
        v_antr_where := v_antr_where || ' and s.systemid = :asysid ';
        vBinds(vBindIdx).name := 'asysid';
        vBinds(vBindIdx).val := anydata.ConvertNumber(asysid);
        vBindIdx := vBindIdx + 1;
	    end if;
	  end if;
  end if;

  -- Filter ProfilID
  if aanzeigen in ('adm','usr','zul','ext','fbv','syg','par','vor','hil','beo') then
    if (proid is null) or (proid=0) then
  	  aproid := '%';
    else
	    aproid := replace(proid,'*','%');
  	  zuviele := zuviele + 1;
    end if;
    if aproid <> '%' then
      if instr(aproid,'%') > 0 then
        v_antr_where := v_antr_where || ' and p.profilid like :aproid ';
        vBinds(vBindIdx).name := 'aproid';
        vBinds(vBindIdx).val := anydata.ConvertVarchar2(aproid);
        vBindIdx := vBindIdx + 1;
      else
        v_antr_where := v_antr_where || ' and p.profilid = :aproid ';
        vBinds(vBindIdx).name := 'aproid';
        vBinds(vBindIdx).val := anydata.ConvertNumber(aproid);
        vBindIdx := vBindIdx + 1;
	    end if;
	  end if;
	end if;



  -- Filter Produktmandant
  if aanzeigen in ('adm','usr','zul','ext','fbv','syg','par','vor','hil','beo') then
    if (pmid is null) or (pmid=-1) then
  	  apmid := '%';
    else
	    apmid := replace(pmid,'*','%');
  	  zuviele := zuviele + 1;
    end if;
    if apmid <> '%' then
      v_antr_where := v_antr_where || ' and adp.pmid = :apmid ';
      vBinds(vBindIdx).name := 'apmid';
      vBinds(vBindIdx).val := anydata.ConvertNumber(apmid);
      vBindIdx := vBindIdx + 1;
	  end if;
  end if;

  -- Filter Status Produktmandant
  if aanzeigen in ('usr') then
    if (vastatus is null) or (vastatus = '0') then
  	  apmstat := '%';
    else
  	  apmstat := replace(vastatus,'*','%');
  	  zuviele := zuviele + 1;
    end if;
    if apmstat <> '%' then
      v_antr_where := v_antr_where || ' and adpv.status = :apmstat ';
      vBinds(vBindIdx).name := 'apmstat';
      vBinds(vBindIdx).val := anydata.ConvertVarchar2(apmstat);
    end if;
	end if;

	if spezialfilter <> 0 then
	   select sql, sql_mand into aspezialfilt,  v_spez_filt_mand from FILTER_ANTRAG where code=spezialfilter;
     v_antr_where := v_antr_where || ' ' || aspezialfilt || ' ';
	   zuviele := zuviele + 1;
	end if;

	if sort_dir is null then
		asort_dir := 2;
	elsif (sort_dir=0) or (sort_dir=1) then
		asort_dir := sort_dir + 1;
	else
		asort_dir := 1;
	end if;

	if sort_on is null then
		asort_on := 'antragsid';
	elsif sort_on in ('antragsid','antrdatum','antrst7','antrstkz','sn','pn','profilid','status','antrstname') then
		asort_on := sort_on;
	end if;

  v_antr_order := v_antr_order || asort_on||' ';

	if (asort_dir = 2) then
   	v_antr_order := v_antr_order || 'desc ';
  end if;


   vSql(1) :=  'select count (unique a.antragsid) ' || v_antr_from || v_antr_where;
   vCursor := pa_sql.getCursor(vBinds,vSql);

   fetch vCursor into v_antr_anz;
   close vCursor;


   vSql(1) := v_antr_select || v_antr_from || v_antr_where || v_antr_group || v_antr_order;
   anzahl      := v_antr_anz;

   -- wenn mind. ein Filter aktiviert ist, wird die Anzahl der angezeigten Zeilen nicht eingeschränkt
    if zuviele > 0 then
      anzmax := 50000;
    end if;

	htp.htmlopen;
  htp.headopen;
    systemzul.style;
    UTILS.ADD_JQUERRY();
  htp.headclose;

  htp.bodyopen('','onLoad="start('||zuviele||','||anzahl||','||hk||aanzeigen||hk||')"');

  systemzul.hilfe;

    htp.print ('
      <script language="javascript">


      if ('||zuviele||'!==0 &&'||anzahl||'>250 ) {         // &&"'||aanzeigen||'"!="fbv" &&"'||aanzeigen||'"!="zul")  {
          alert('||anzahl||' + " '||translation.translate('TEXT.ALERT.XEINTRAEGEKANNDAUERN')||' ...");
      }

      function start(zuviele,anzahl,anzeigen)
      {
    ');

    zul_admin.self_top;

    htp.print('
        if ((zuviele==0 &anzahl>'||anzmax||') || (anzeigen=="fbv" &anzahl>'||anzmax||') || (anzeigen=="zul" &anzahl>'||anzmax||'))  {
          alert("'||translation.translate_ph('TEXT.PH.ALERT.ZUVIELEEINTRAEGE',p1 =>anzmax )||'");
        }
      }

      function sortieren(sorton)
      {
        document.filter_form.sort_on.value=sorton;
        document.filter_form.submit();
      }

      function filter()
      {
        document.filter_form.sort_dir.value="";
        document.filter_form.submit()
      }

      function selall(thiselement)
      {
        for ( i=0; i<document.antrid_form.elements.length; i++ ) {
          if ( document.antrid_form.elements[i].name == "antrids" ) {
            document.antrid_form.elements[i].checked = thiselement.checked;
          }
        }
      }

      function verl()
      {
        j=0;
        for ( i=0; i<document.antrid_form.elements.length; i++ ) {
          if ( document.antrid_form.elements[i].type == "checkbox" ) {
             if (document.antrid_form.elements[i].checked) { j++ }
          }
        }
        if (j==0) {
          alert("'||translation.translate('TEXT.ALERT.KEINANTRAGSELEKTIERT')||'");
          return false;
        }

        document.antrid_form.url.value = url();
        document.antrid_form.submit();
      }

      function checkit()
      {
        j=0;
        for ( i=0; i<document.antrid_form.elements.length; i++ ) {
          if ( document.antrid_form.elements[i].type == "checkbox" ) {
             if (document.antrid_form.elements[i].checked) { j++ }
          }
        }
        if (j==0) {
          alert("'||translation.translate('TEXT.ALERT.KEINANTRAGSELEKTIERT')||'");
          return false;
        }

        if (document.antrid_form.aktion.options[document.antrid_form.aktion.selectedIndex].value==0)
        {
          alert("'||translation.translate('TEXT.ALERT.KEINEAKTIONAUSGW')||'");
          return false;
        }

        if (document.antrid_form.aktion.options[document.antrid_form.aktion.selectedIndex].value==4)
        {
          ok = confirm("'||translation.translate('TEXT.CONFIRM.ANTRAEGELOESCHEN')||'");
          if (ok==false) {
            return false;
          }
        }

        if (document.antrid_form.aktion.options[document.antrid_form.aktion.selectedIndex].value==6)
        {
          ok = confirm("'||translation.translate('TEXT.CONFIRM.WEINTRAEGELOESCHEN')||'");
          if (ok==true) {
            document.antrid_form.aktion.options[document.antrid_form.aktion.selectedIndex].value=61;
          }
        }

        if (document.antrid_form.aktion.options[document.antrid_form.aktion.selectedIndex].value==11)
        {
          pmid_1 = "' || pmid || '";
          pmid_2 = document.filter_form.pmid.options[document.filter_form.pmid.selectedIndex].value;

          if (pmid_2 == "-1") {
            alert("'||translation.translate('TEXT.ALERT.MANDFILTERNICHTBELEGT')||'");
            return false;
          }

          if (pmid_1 !== pmid_2) {
            alert("'||translation.translate('TEXT.ALERT.LISTEERSTNACHMANDFILTERN')||'");
            return false;
          }

          ok = confirm("'||translation.translate('TEXT.CONFIRM.AUSGWMANDLOESCHEN')||'");
          if (ok==false) {
            return false;
          }

          document.antrid_form.pmid.value = pmid_2;
        }

        if (document.antrid_form.aktion.options[document.antrid_form.aktion.selectedIndex].value==12)
        {
          OK = confirm("'||translation.translate('TEXT.CONFIRM.EMAILLISTEDERANTRST')||'");
          if (!OK) { return false; }
        }


        if (document.antrid_form.aktion.options[document.antrid_form.aktion.selectedIndex].value==13)
        {
          if ((document.filter_form.pmid.value<0)||(document.filter_form.pmid.value!='||nvl(pmid,'-1')||'))
          {
            alert("'||translation.translate('TEXT.ALERT.MUSSMIND1MANDAUSGW')||'");
            return;
          }
          OK = confirm("'||translation.translate('TEXT.CONFIRM.P1.ALLE')||' \""+document.filter_form.pmid.options[document.filter_form.pmid.selectedIndex].text+"\"-'||translation.translate('TEXT.CONFIRM.P2.MANDSTORNIEREN')||'");
          if (!OK) { return false; }

          document.antrid_form.pmid.value = document.filter_form.pmid.value;
        }


        if (document.antrid_form.aktion.options[document.antrid_form.aktion.selectedIndex].value==14)
        {
          if ((document.filter_form.pmid.value<0)||(document.filter_form.pmid.value!='||nvl(pmid,'-1')||'))
          {
            alert("'||translation.translate('TEXT.ALERT.MUSSMIND1MANDAUSGW')||'");
            return;
          }
          OK = confirm("'||translation.translate('TEXT.CONFIRM.P1.ALLE')||' \""+document.filter_form.pmid.options[document.filter_form.pmid.selectedIndex].text+"\"-'||translation.translate('TEXT.CONFIRM.P2.MANDZULASSEN')||'");
          if (!OK) { return false; }

          document.antrid_form.pmid.value = document.filter_form.pmid.value;
        }


        if (document.antrid_form.aktion.options[document.antrid_form.aktion.selectedIndex].value==15)
        {
          if (('||spezialfilter||'!=14)||(document.filter_form.spezialfilter.value!=14))
          {
            alert("'||translation.translate('TEXT.ALERT.SPEZIALFILTERVORHERANW')||': \""+document.filter_form.spezialfilter.options[14].text+"\" !");
            return;
          }

          if (document.filter_form.pmid.value!='||nvl(pmid,'-1')||')
          {
            alert("'||translation.translate('TEXT.ALERT.MANDFILTEREINGESTELLT')||'");
            return;
          }

          OK = confirm("'||translation.translate('TEXT.CONFIRM.P1.ALLE')||' \""+document.filter_form.pmid.options[document.filter_form.pmid.selectedIndex].text+"\"-'||translation.translate('TEXT.CONFIRM.P2.MANDVERLAENG')||'");
          if (!OK) { return false; }

          document.antrid_form.pmid.value = document.filter_form.pmid.value;
        }

        document.antrid_form.url.value = url();
        document.antrid_form.submit();
      }

      function url()
      {
        purl = "zul.verlaengerung.verantr_usr" +
              "?anzeigen="      +   document.filter_form.anzeigen.value +
              "&sysid="         +   document.filter_form.sysid.options[document.filter_form.sysid.selectedIndex].value +
              "&abt="           +   document.filter_form.abt.value +
              "&pmid="          +   document.filter_form.pmid.options[document.filter_form.pmid.selectedIndex].value +
              "&proid="         +   document.filter_form.proid.options[document.filter_form.proid.selectedIndex].value +
              "&name="          +   document.filter_form.name.value +
              "&antrsteller="   +   document.filter_form.antrsteller.value;

        if ((document.filter_form.anzeigen.value != "usr") &&(document.filter_form.anzeigen.value != "ext")) {
          if (document.filter_form.ausrufez.checked) {
            purl = purl +  "&ausrufez=1"
          }
          purl = purl + "&spezialfilter=" + document.filter_form.spezialfilter.value;
        }
              //"&sort_on="    +   document.filter_form.sort_on.value +
              //"&sort_dir="   +   document.filter_form.sort_dir.value;

        purl = purl.replace(/%/,"*");
        return purl;
      }

      function details(antrid)
      {
        document.detail_form.url.value = url();
        document.detail_form.antrid.value = antrid;

        document.detail_form.submit();

      }

      </script>');

    systemzul.syszul_kopf;

    htp.tableopen(cattributes=>'border="0" cellspacing="1" cellpadding="2" bordercolor="#FFFFFF" ');

      -- Spaltenbreiten
      htp.tablerowopen(cattributes=>'bgcolor="'||grau||'"');
        dummyspalte(30);  -- ID
        dummyspalte(60);  -- Datum
        dummyspalte(60);  -- Name
        dummyspalte(80);  -- Abt.


        dummyspalte(90);  -- System

        dummyspalte(80);  -- Profil
        dummyspalte(80);  -- Mandant1
        dummyspalte(40);  -- Mandant2 / Status
         dummyspalte(20);  -- Info
        dummyspalte(60);  -- Details
        dummyspalte(60);  -- Datum
        dummyspalte(30);  -- Mail

         colspan := 11;


      htp.tablerowclose;


      -- Titelzeile
      htp.tablerowopen(cattributes=>'bgcolor="'||grau||'"');
        if  aanzeigen='usr' then
        	atitel := anzahl||' '||translation.translate('TITLE.ANTRAEGEPERSONLICHE');
        elsif aanzeigen='ext' then
        	atitel := anzahl||' '||translation.translate('TITLE.ANTRAEGEPERSFURANDERE');

        end if;

        htp.tabledata('<b>'||atitel,ccolspan=>colspan-5);

        htp.tabledata(bl, cattributes=>'colspan="5"');

      htp.tablerowclose;

htp.formopen('zul.verlaengerung.verantr_usr','post',cattributes=>'name="filter_form" onsubmit="filter()"');

      htp.formhidden('anzeigen',aanzeigen);
      htp.formhidden('antrsteller',antrsteller);
      htp.formhidden('schatten',schatten);

      -- Spaltenköpfe mit Sortiersymbolen
      htp.tablerowopen(cattributes=>'bgcolor="'||grau||'"');
        htp.tabledata('ID',cattributes=>'valign="top"');

          htp.tabledata(translation.translate('SPALTE.DATUM')||' <a href="javascript:sortieren(''antragsid'')"><img src="/zul/img/sort_up'||to_char(asort_d1)||'.gif"border="0" alt="Sortieren ..."></a>',cattributes=>'bgcolor="'||grau||'"');

          htp.tabledata(translation.translate('SPALTE.NAMEVORNAME'),cattributes=>'bgcolor="'||grau||'"');

          htp.tabledata(translation.translate('SPALTE.ABTEILUNGAKT'),cattributes=>'bgcolor="'||grau||'"');

        htp.formhidden('sort_on','');
        htp.formhidden('sort_dir',asort_dir);


        htp.tabledata('System',cattributes=>'valign="top"');

        htp.tabledata(translation.translate('SPALTE.PROFIL'),cattributes=>'valign="top"');
        htp.tabledata(translation.translate('SPALTE.MANDANT'),cattributes=>'valign="top"');
          htp.tabledata(translation.translate('SPALTE.VERLAENGERUNG'),cattributes=>'bgcolor="'||grau||'"');
htp.tabledata('Info',cattributes=>'bgcolor="'||grau||'"');
          htp.tabledata(translation.translate('SPALTE.ABLAUFDATUMAKT'),cattributes=>'bgcolor="'||grau||'"');




        htp.tabledata(translation.translate('SPALTE.AUSW'), cattributes=>'align="center" valign="top"');
      htp.tablerowclose;

      -- Spaltenköpfe mit Pulldownmenüs zum Filtern
      htp.tablerowopen(cattributes=>'bgcolor="'||grau||'"');
          htp.tabledata(bl);
          htp.tabledata(bl);

          -- Eingabefeld Name
          if aanzeigen='usr' then
            htp.print('<td bgcolor="'||grau||'">');
               htp.print('<input type="text" name="name" class="eingabe" size="15" value="'||zul_admin.check_str(NAME)||'" maxlength="30">');
            htp.print('</td>');
          else
            htp.tabledata(bl);
            htp.formhidden('name','');
          end if;

          -- Eingabefeld Abteilung
          if aanzeigen='usr' then
            htp.print('<td bgcolor="'||grau||'"><p>');
              htp.print('<input type="text" name="abt" class="eingabe" size="12" value="'||zul_admin.check_str(abt)||'" maxlength="20">');
            htp.print('</p></td>');
          else
            htp.tabledata(bl);
            htp.formhidden('abt','');
          end if;





          vSysSql(1) := 'select distinct s.systemid,s.name '||v_antr_from||v_antr_where|| ' order by upper(name)';

          vSysCursor := pa_sql.getCursor(vBinds,vSysSql);
          htp.print('<td bgcolor="'||grau||'"><p>');
            htp.formselectopen('sysid',cattributes=>'class="eingabe"');
              htp.formSelectOption('Alle','','value="0"');

              loop
                fetch vSysCursor into v_sid, v_sn;
                EXIT WHEN vSysCursor%NOTFOUND;
                if sysid = v_sid
                  then sel := '1';
                  else sel := NULL;
                end if;
                htp.formSelectOption(zul_admin.check_str(v_sn),sel,'value="'||v_sid||'"');
              end loop;
              close vSysCursor;
            htp.formselectclose;
          htp.print('</p></td>');
          -- Pulldown Profil cursor
          vProfSql(1) := 'select distinct   p.profilid, p.NAME '||v_antr_from||v_antr_where|| ' order by upper(name)';

          vProfCursor := pa_sql.getCursor(vBinds,vProfSql);
          htp.print('<td bgcolor="'||grau||'"><p>');
            htp.formselectopen('proid',cattributes=>'class="eingabe"');
              htp.formSelectOption('Alle','','value="0"');

              loop
                fetch vProfCursor into v_pid, v_pname;
                EXIT WHEN vProfCursor%NOTFOUND;
                if proid = v_pid
           	 	 	  then sel := '1';
                  else sel := NULL;
             	 	end if;
                htp.formSelectOption(zul_admin.check_str(v_pname),sel,'value="'||v_pid||'"');
              end loop;
              close vProfCursor;

            htp.formselectclose;
          htp.print('</p></td>');

          -- Pulldown Mandant
          htp.print('<td bgcolor="'||grau||'"><p>');
            htp.formselectopen('pmid',cattributes=>'class="eingabe"');
              htp.formSelectOption('Alle','','value="-1"');
              for iy in (SELECT unique prfm.pmid ppmid,kurzbez
                            FROM PROFILMANDANT prfm, produktmandant prdm, egsystemprofile egs
                               WHERE prfm.PROFILID LIKE aproid and egs.systemid like asysid
                                   and prfm.profilid = egs.profilid and prfm.pmid=prdm.pmid
                                     order by kurzbez)
              loop
             	 	if pmid = iy.ppmid
           	 	 	  then sel := '1';
                  else sel := NULL;
             	 	end if;
                htp.formSelectOption(zul_admin.check_str(iy.kurzbez),sel,'value="'||iy.ppmid||'"');
              end loop;
            htp.formselectclose;
          htp.print('</p></td>');

           htp.print('<td bgcolor="'||grau||'" ><p>');
              htp.formselectopen('vastatus',cattributes=>'class="eingabe"');

                htp.formSelectOption(translation.translate('SELECT.ALLE'),'','value="0"');
                htp.formSelectOption(translation.translate('SELECT.BEANTRAGT'),CASE WHEN vastatus='beantragt' THEN '1' ELSE '' END,'value="beantragt"');
                htp.formSelectOption(translation.translate('SELECT.VERLAENGERT'),CASE WHEN vastatus='verlängert' THEN '1' ELSE '' END,'value="verlängert"');
                htp.formSelectOption(translation.translate('SELECT.ABGELEHNT'),CASE WHEN vastatus='abgelehnt' THEN '1' ELSE '' END,'value="abgelehnt"');


              htp.formselectclose;
            htp.print('</p></td>');
htp.tabledata('<input type="image" src="/zul/img/lupe.gif">', cattributes=>'align="center"');
htp.tabledata(bl);


 htp.tabledata(bl);
        htp.tablerowclose;

--if anzeigen not in ('zul','zul') then



            htp.tablerowopen(cattributes=>'bgcolor="'||grau||'"');
              htp.tabledata(translation.translate('LABEL.SPEZIALFILTER'),ccolspan=>colspan-5, calign=>'right');
              htp.print('<td >');
                htp.formselectopen('spezialfilter',cattributes=>'class="eingabe"');
                  for ix in (select code,filter from FILTER_ANTRAG WHERE code IN (0,15,16) order by code)
                  loop
                    if spezialfilter = ix.code then sel := 1; else sel := NULL; end if;
                    htp.formSelectOption(zul_admin.check_str(ix.filter),sel,'value="'||ix.code||'"');
                  end loop;
                htp.formselectclose;
              htp.print('</td>');
             htp.tabledata(bl);   htp.tabledata(bl); htp.tabledata(bl); htp.tabledata('<input type="checkbox" onclick="selall(this)">',cattributes=>'align="center"');
            htp.tablerowclose;


htp.formclose;  -- filter_form


htp.formopen('zul.verlaengerung.verantr_aktion?','post',cattributes=>'name="antrid_form" onsubmit="return checkit()"');

      vCursor := pa_sql.getCursor(vBinds,vSql);
      loop
        fetch vCursor into v_antragsid, v_antrdatum, v_antrst, v_antrstkz, v_sn, v_pn, v_profilid, v_antrstat, v_antrstname, v_kzzakt ;
        EXIT WHEN vCursor%NOTFOUND;

if instr(antrstati, ','||v_antrstat||',') > 0  then
        -- user kann einen eigenen Antrag löschen
        perloesch := aanzeigen='usr' or aanzeigen='ext';
        -- Abfrage für FBV's
           -- Abfrage allgemein
           vMandSql(1) := ' select pm.kurzbez, adp.status, adp.verfdatum, adp.pmid, adpv.status, adpv.LDATUM, adpv.kommentar from antragsdatenprofile adp left join produktmandant pm
                            on adp.pmid=pm.pmid left join ADP_VERLAENGERUNG adpv on adpv.antragsid=adp.ANTRAGSID and adpv.pmid=adp.pmid where adp.verfdatum is not null  and adp.antragsid = :v_antragsid ';
           vMandAnzSql(1) := 'select count(adp.pmid) from antragsdatenprofile adp left join produktmandant pm
                            on adp.pmid=pm.pmid left join ADP_VERLAENGERUNG adpv on adpv.antragsid=adp.ANTRAGSID and adpv.pmid=adp.pmid
                            where adp.antragsid = :v_antragsid and adp.verfdatum is not null';

           vMandBinds(vMandBindIdx).name := 'v_antragsid';
           vMandBinds(vMandBindIdx).val := anydata.ConvertNumber(v_antragsid);
           vMandBindIdx := vMandBindIdx + 1;

           if apmid <> '%' then
             vMandSql(1) := vMandSql(1) || ' and adp.pmid = :apmid ';
             vMandAnzSql(1) := vMandAnzSql(1) || ' and adp.pmid = :apmid ';
             vMandBinds(vMandBindIdx).name := 'apmid';
             vMandBinds(vMandBindIdx).val := anydata.ConvertNumber(apmid);
             vMandBindIdx := vMandBindIdx + 1;
           end if;

    if apmstat <> '%' THEN
      vMandSql(1) := vMandSql(1) || ' and adpv.status in (select column_value from table(:apmstat))';
      vMandAnzSql(1) := vMandAnzSql(1) || ' and adpv.status in (select column_value from table(:apmstat))';

      vMandBinds(vMandBindIdx).name := 'apmstat';
      vMandBinds(vMandBindIdx).val := anydata.ConvertCollection(pa_sql.getVcTabFromList(apmstat,','));
    end if;

    vMandSql(1) := vMandSql(1) || ' and adp.status in (500)';
    vMandAnzSql(1) := vMandAnzSql(1) || ' and adp.status in (500)';

    vMandSql(1) := vMandSql(1) || ' order by kurzbez';

    vWCursor := pa_sql.getCursor(vMandBinds,vMandSql);
    vAmCursor := pa_sql.getCursor(vMandBinds,vMandAnzSql);

        angezeigt := angezeigt + 1;
        exit when angezeigt > anzmax;

       fetch vAmCursor into anzmand;
       close vAmCursor;

        htp.tablerowopen(cattributes=>'bgcolor="'||hgrau||'"');
          htp.tabledata(v_antragsid||'    <a href="javascript:details('||v_antragsid||');"><img height="10px" src="/zul/img/edit.gif"border="0" alt="Details ..."></a>',cattributes=>h28, crowspan=>anzmand);
          htp.tabledata(to_char(v_antrdatum,'DD.MM.YY'), crowspan=>anzmand);
          htp.tabledata(v_antrstname, crowspan=>anzmand);
          htp.tabledata(systemzul.akt_kurzz(v_antrst), crowspan=>anzmand);

          htp.tabledata(zul_admin.check_str(v_sn),cattributes=>'bgcolor="'||v_statusfarben(v_antrstat)||'"', crowspan=>anzmand);

          htp.tabledata(zul_admin.check_str(substr(v_pn,1,15)), crowspan=>anzmand);
                actmand := 0;
                  loop
                    fetch vWCursor into v_kurzbez, v_pmstatus, v_verfdatum,  v_adppmid, v_adpvstat, v_adpvldat, v_adpkomm;
                    EXIT WHEN vWCursor%NOTFOUND;
                    if instr(mandstati, ','||v_pmstatus||',') > 0 then
                    if actmand <>0 then htp.tablerowclose(); htp.tablerowopen(cattributes=>'bgcolor="'||hgrau||'"'); end if;
                    IF v_is_pm_vertreter='J' then
                      htp.print('<td width="60" title="in Vertretung" bgcolor="'|| v_statusfarben(v_pmstatus) || '" style="color:#4f81bd; ">' || zul_admin.check_str(v_kurzbez) ||'</td>');
                  	  ELSE
                      htp.print('<td width="60" bgcolor="'|| v_statusfarben(v_pmstatus) || '">' || zul_admin.check_str(v_kurzbez) || '</td>');
                      END IF;

                      htp.tabledata(CASE v_adpvstat
                              WHEN 'beantragt' THEN translation.translate('SELECT.BEANTRAGT')
                              WHEN 'verlängert' THEN translation.translate('SELECT.VERLAENGERT')
                              WHEN 'abgelehnt' THEN   translation.translate('SELECT.ABGELEHNT')
					                    END ,cattributes => 'bgcolor="'||
                          CASE v_adpvstat
                              WHEN '' THEN grau
                              WHEN 'beantragt' THEN '#C0FFFF'
                              WHEN 'verlängert' THEN '#80FF80'
                              WHEN 'abgelehnt' THEN   '#FF4040'
                           END || '"');
                     htp.tabledata(CASE WHEN v_adpvstat IS NOT NULL THEN '<img src="/zul/img/info1.gif" border="0" title="'||v_adpkomm||'"  onclick="alert('''||replace(v_adpkomm,chr(10),'\n')||''');">' END, cattributes => h28||' align="center" bgcolor="'||hgrau||'"');
                     htp.tabledata(to_char(v_verfdatum,'DD.MM.YY'));

             htp.print('<TD align="center" ><p>');
               htp.print('<input type="checkbox" name="antrids" value="'||v_antragsid||'_'||v_adppmid||'">');
             htp.print('</p></TD>');

                  	  actmand := actmand + 1;
                     end if;
                  end loop;
                  close vWCursor;
        htp.tablerowclose;
end if;
      end loop;
      close vCursor;

    htp.tablerowopen();
    htp.tabledata(bl,cattributes=>'colspan="'||colspan||'" bgcolor="'||grau||'"');
    htp.tablerowclose;

    htp.tablerowopen(cattributes=>'bgcolor="'||hgrau||'"');
      htp.tabledata(bl, ccolspan=>4);
      htp.tabledata(translation.translate('LABEL.KOMMENTAR'));
      htp.print('<TD bgcolor="'||hgrau||'" valign="top" colspan="4">');
        htp.print('<input type="text" name="komment" class="eingabe" size="100" value="" maxlength="100">');
      htp.print('</TD>');
      htp.tabledata(bl);
      htp.tabledata(bl);
    htp.tablerowclose;

        htp.tablerowopen(cattributes=>'bgcolor="'||grau||'"');

          htp.tabledata(bl,ccolspan=>5);
          htp.print('<TD colspan='||to_Char(colspan-7)||'  bgcolor="'||grau||'">');

            htp.print('<input type="button" name="verlaengern" value="'||translation.translate('BUTTON.ANTRAGVERLAENGERUNG')||'" onClick="verl()">');
          htp.print('</td>');
          htp.tabledata(bl); htp.tabledata(bl);
       htp.tablerowclose;

    htp.formhidden('url','');
    htp.formhidden('anzeigen',aanzeigen);

    htp.formhidden('pmid','');

htp.formclose; -- antrid_form

htp.formopen('','post',cattributes=>'name="sel_form"');
      htp.formhidden('selwen','1');
htp.formclose();  -- sel_form

htp.formopen('zul.systemzul.antrag_detail','get',cattributes=>'name="detail_form"');
  htp.formhidden('anzeigen','ext');
  htp.formhidden('antrid','');
  htp.formhidden('url','');
htp.formclose;

    htp.tableclose;

  htp.bodyclose;
  htp.htmlclose;
end;

procedure verantr_aktion    (antrids   owa_util.vc_arr default dummywert,
                                      aktion    varchar2 default null,
                                      komment   varchar2 default NULL,
                                      anzeigen  varchar2 default null,
                                      url       varchar2 default null,
                                      pmid      varchar2 default null)
is
cntverl NUMBER(2);
  astnr antraege.antrst7%type; --    varchar2(6);
  v_antragsid antraege.antragsid%type;
  v_antrpmid antragsdatenprofile.pmid%TYPE;

  v_pmid varchar2(5) := case when pmid='-1' then '%' else pmid end;

  cu antraege.lbearb%type := systemzul.cur_user(ohne_Q => 0);
  aadpkomm adp_verlaengerung.kommentar%TYPE;
  v_adpkomm adp_verlaengerung.kommentar%TYPE;
  v_antrkomm kommentare.kommentar%TYPE;
  v_mand_kbez produktmandant.kurzbez%TYPE;

begin
  astnr  := substr(fips.user,1,7);

  -- FBV Mandanten verlängern
  if aktion='15' then
    if not ( systemzul.istZulAdmin )
    then
      systemzul.nicht_berechtigt;
      return;
    end if;
    htp.print('pmid = '||v_pmid);
    for a in antrids.first .. antrids.last
    loop
      htp.print('<br>'||antrids(a));
      for m in
      (
         select a.antragsid, a.profilid, adp.pmid, kurzbez, adp.verfdatum, adp.status
           from antraege a, antragsdatenprofile adp, profilmandant pm, produktmandant m
             where a.antragsid=adp.antragsid and a.profilid=pm.profilid and pm.pmid=adp.pmid and pm.pmid=m.pmid
               and pm.aktiv=1 and adp.status=500 and adp.verfdatum<sysdate+30
                 and substr(astnr,2,6) in (genehmiger1, genehmiger2, genehmiger3) and a.antragsid=antrids(a)
                   and adp.pmid like v_pmid
      )
      loop
         htp.print('<br>  - '||m.pmid||' - '||m.verfdatum);
      end loop;
    end loop;
    return;
  end if;

    for a in antrids.first .. antrids.last
    LOOP
        v_antragsid:=substr(antrids(a),1,instr(antrids(a),'_')-1);
        v_antrpmid:=substr(antrids(a),instr(antrids(a),'_')+1);
        select kurzbez into v_mand_kbez from produktmandant where pmid=v_antrpmid;
        --v_mand_kbez
      SELECT COUNT (*) INTO cntverl FROM adp_verlaengerung adpv WHERE adpv.antragsid=v_antragsid AND adpv.pmid=v_antrpmid;
       v_adpkomm:=to_char(SYSDATE,'DD.MM.YY HH24:MI')||', '||mis.nachname(cu)||': beantragt';
       v_antrkomm:='Verlängerung beantragt für Mandant: '||v_mand_kbez;

       v_adpkomm:=v_adpkomm||'
Kommentar: '||komment;
       v_antrkomm:=v_antrkomm||'
Kommentar: '||komment;
      IF cntverl>0 THEN
        SELECT adpv.kommentar INTO aadpkomm FROM adp_verlaengerung adpv WHERE  adpv.antragsid=v_antragsid AND adpv.pmid=v_antrpmid;
        IF aadpkomm IS NOT NULL THEN
            v_adpkomm:=v_adpkomm||'
--------
';
        END IF;
        v_adpkomm:=v_adpkomm||aadpkomm;

        UPDATE adp_verlaengerung SET antrdatum=SYSDATE, antrsteller=astnr, ldatum=SYSDATE, lbearb=astnr, status='beantragt', kommentar=v_adpkomm WHERE antragsid=v_antragsid AND pmid=v_antrpmid;
      ELSE
          INSERT INTO adp_verlaengerung VALUES (VERLAENGERUGSID.nextval,v_antragsid,v_antrpmid,SYSDATE,astnr,'beantragt',SYSDATE,astnr,v_adpkomm );
      END IF;
      --Kommentar auch in Antrag hinzufügen
      insert into kommentare (kommentarid, antragsid, kommentar, lbearb,ldatum) values ( kommentar_seq.nextval, v_antragsid, v_antrkomm, substr(cu,1,7), sysdate);
    end loop;


  htp.print('
        <script language="javascript">
            location.href="'||url||'";
        </script>
     ');
end;
procedure verantr_save    (ANTRMANDIDVERFDAT owa_util.vc_arr   default dummywert,
                            ANTRVERFDATS owa_util.vc_arr   default dummywert,
    antrids   owa_util.vc_arr   default dummywert,
                                      ANTRMANDIDVERFDATALL    varchar2 default null,
                                      komment   varchar2 default null,

                                      anzeigen  varchar2 default null,
                                      url       varchar2 default null,
                                      pmid      varchar2 default null)
is
cntverl NUMBER(2);
  asysid number(5);
  kzz_alt antraege.antrstkz%TYPE;
  astnr antraege.antrst7%type; --    varchar2(6);
  v_antragsid antraege.antragsid%type;
  v_antrpmid antragsdatenprofile.pmid%TYPE;
  v_antrverf antragsdatenprofile.verfdatum%TYPE;

    aantrverf antragsdatenprofile.verfdatum%TYPE;
  v_status adp_verlaengerung.status%TYPE;

  cu antraege.lbearb%type := systemzul.cur_user(ohne_Q => 0);
  aadpkomm adp_verlaengerung.kommentar%TYPE;
  v_adpkomm adp_verlaengerung.kommentar%TYPE;
  v_antrkomm kommentare.kommentar%TYPE;
  aastnr antraege.antrst7%type;
  aastnrext varchar2(1);
  asysdz number;
  v_mand_kbez produktmandant.kurzbez%TYPE;
  santraend      varchar2(40) := translation.translate('TITLE.santraend');
begin
  astnr  := substr(fips.user,1,7);


for ix in antrids.first .. antrids.last
    LOOP
        v_antragsid:=substr(antrids(ix),1,instr(antrids(ix),'_')-1);
        v_antrpmid:=substr(antrids(ix),instr(antrids(ix),'_')+1);
        select kurzbez into v_mand_kbez from produktmandant where pmid=v_antrpmid;

         select egp.systemid into asysid from antraege a, egsystemprofile egp where a.antragsid=v_antragsid and a.profilid=egp.profilid;
         select a.antrst7 into aastnr from antraege a where a.antragsid=v_antragsid;
         aastnrext:=mis.extkennz(aastnr);
         asysdz:=system_dz(asysid,aastnrext);

         v_antrverf:=nvl(to_date(ANTRMANDIDVERFDAT(ix),'DD.MM.YY'),SYSDATE+asysdz);

        IF ANTRMANDIDVERFDAT(ix)='01.01.0001' THEN
            v_status:='abgelehnt';
        ELSE
             v_status:='verlängert';
        END IF;

        SELECT COUNT (*) INTO cntverl FROM adp_verlaengerung adpv WHERE adpv.antragsid=v_antragsid AND adpv.pmid=v_antrpmid;
        v_adpkomm:=to_char(SYSDATE,'DD.MM.YY HH24:MI')||', '||mis.nachname(cu)||': '||v_status;
        v_antrkomm:='Antrag für Mandant '||v_mand_kbez||' wurde '||v_status;

        IF  v_status='verlängert' THEN

            SELECT  adp.verfdatum  INTO aantrverf FROM antragsdatenprofile adp WHERE adp.antragsid=v_antragsid AND adp.pmid=v_antrpmid;
            v_adpkomm:=v_adpkomm||'
Details: von '||to_char(aantrverf,'DD.MM.YY')||' bis '||to_char(v_antrverf,'DD.MM.YY');
            v_adpkomm:=v_adpkomm||'
Kommentar: '||komment;
            v_antrkomm:=v_antrkomm||'
Details: von '||to_char(aantrverf,'DD.MM.YY')||' bis '||to_char(v_antrverf,'DD.MM.YY');
            v_antrkomm:=v_antrkomm||'
Kommentar: '||komment;
            IF cntverl>0 THEN
                SELECT adpv.kommentar INTO aadpkomm FROM adp_verlaengerung adpv WHERE  adpv.antragsid=v_antragsid AND adpv.pmid=v_antrpmid;
                IF aadpkomm IS NOT NULL THEN
                    v_adpkomm:=v_adpkomm||'
--------
';
                END IF;
                v_adpkomm:=v_adpkomm||aadpkomm;
                UPDATE adp_verlaengerung adpv SET adpv.status=v_status, adpv.ldatum=SYSDATE, adpv.lbearb=astnr, adpv.kommentar=v_adpkomm  WHERE adpv.antragsid=v_antragsid AND adpv.pmid=v_antrpmid;
            ELSE
                INSERT INTO adp_verlaengerung VALUES (VERLAENGERUGSID.nextval,v_antragsid,v_antrpmid,SYSDATE,astnr,v_status,SYSDATE,astnr,v_adpkomm );
            END IF;
            select nvl(antrstkz,'-') into kzz_alt from antraege where antragsid=v_antragsid;
            UPDATE antragsdatenprofile adp SET adp.verfdatum=v_antrverf WHERE adp.antragsid=v_antragsid AND adp.pmid=v_antrpmid;        
            if kzz_alt!=mis.kurzz_l(aastnr) then
              update antraege set antrstkz=mis.kurzz_l(aastnr) where antragsid=v_antragsid;
              v_antrkomm:=v_antrkomm||'
Info: Kurzzeichen wurde beim Verlängerung aktualisiert, von '||kzz_alt||' zu '||mis.kurzz_l(aastnr);
            end if;
         ELSE
             v_adpkomm:=v_adpkomm||'
Details: Ablaufdatum nicht geändert
Kommentar: '||komment;
             v_antrkomm:=v_antrkomm||'
Details: Ablaufdatum nicht geändert
Kommentar: '||komment;
            IF cntverl>0 THEN
                SELECT adpv.kommentar INTO aadpkomm FROM adp_verlaengerung adpv WHERE  adpv.antragsid=v_antragsid AND adpv.pmid=v_antrpmid;
                IF aadpkomm IS NOT NULL THEN
                    v_adpkomm:=v_adpkomm||'
--------
';
                END IF;
                v_adpkomm:=v_adpkomm||aadpkomm;
                UPDATE adp_verlaengerung adpv SET adpv.status=v_status, adpv.ldatum=SYSDATE, adpv.lbearb=astnr, adpv.kommentar=v_adpkomm  WHERE adpv.antragsid=v_antragsid AND adpv.pmid=v_antrpmid;

            ELSE
                v_adpkomm:=v_adpkomm||'
Kommentar: '||komment;
                INSERT INTO adp_verlaengerung VALUES (VERLAENGERUGSID.nextval,v_antragsid,v_antrpmid,SYSDATE,astnr,v_status,SYSDATE,astnr,v_adpkomm );
            END IF;
         END IF;
         --Kommentar auch in Antrag hinzufügen
         insert into kommentare (kommentarid, antragsid, kommentar, lbearb,ldatum) values ( kommentar_seq.nextval, v_antragsid, v_antrkomm, substr(cu,1,7), sysdate);
         systemzul.zul_mail_neu(antragsid=>v_antragsid, antrmandid_alt=>dummywert, command=>santraend, komm=>v_antrkomm, anzeigen=>'usr');
         END LOOP;
  htp.print('
        <script language="javascript">
            location.href="'||url||'";
        </script>
     ');
end;



procedure usr (anzeigen       varchar2 default null)
is
arem_user varchar2(7) :=systemzul.cur_user(ohne_Q => 0);
begin

  htp.print('
    <HTML>
      <HEAD>
        <TITLE>ZUL'||zul_defs.zul_umgebung||'</TITLE>
      </HEAD>
      <frameset rows="113, *">
        <frame name="meta" src="zul.systemzul.head" scrolling="no" frameborder="0" marginheight="0" marginwidth="0" noresize>
        <frameset cols="180,*,0" frameborder="0">
           <frame name="navi"   src="zul.systemzul.navileiste"      scrolling="auto" frameborder="0" marginheight="2" marginwidth="0">
			  	 <frame name="main"   src="zul.verlaengerung.verantr_usr?name='||mis.nachname(arem_user)||'%2C+'||mis.vorname(arem_user)||'" scrolling="auto" frameborder="0" marginheight="0" marginwidth="4" noresize>

           <frame name="hidden" src="/zul/zul_leer.html"                scrolling="auto" frameborder="1"                  marginwidth="0" >
        </frameset>
      </frameset>

      <noframes></noframes>
    </HTML>
  ');


end;

procedure gen (anzeigen       varchar2 default null)
is
begin

  htp.print('
    <HTML>
      <HEAD>
        <TITLE>ZUL'||zul_defs.zul_umgebung||'</TITLE>
      </HEAD>
      <frameset rows="113, *">
        <frame name="meta" src="zul.systemzul.head" scrolling="no" frameborder="0" marginheight="0" marginwidth="0" noresize>
        <frameset cols="180,*,0" frameborder="0">
           <frame name="navi"   src="zul.systemzul.navileiste"      scrolling="auto" frameborder="0" marginheight="2" marginwidth="0">
			  	 <frame name="main"   src="zul.verlaengerung.antrag_alle" scrolling="auto" frameborder="0" marginheight="0" marginwidth="4" noresize>

           <frame name="hidden" src="/zul/zul_leer.html"                scrolling="auto" frameborder="1"                  marginwidth="0" >
        </frameset>
      </frameset>

      <noframes></noframes>
    </HTML>
  ');


end;

  end;

/

  GRANT EXECUTE ON "ZUL"."REZERTIFIZIERUNG" TO "APACHE";
  GRANT EXECUTE ON "ZUL"."REZERTIFIZIERUNG" TO "MPR";
