--------------------------------------------------------
--  File created - Wednesday-November-22-2023   
--------------------------------------------------------
--------------------------------------------------------
--  DDL for Package REZERTIFIZIERUNG
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE PACKAGE "ZUL"."REZERTIFIZIERUNG" as
TYPE t_numbers is VARRAY(20) of NUMBER(5); 

TYPE t_statusfarben is TABLE of varchar2(7) index by binary_integer;
TYPE t_vstatusfarben is TABLE of varchar2(7) index by VARCHAR2(10);  

TYPE t_statusbez    is TABLE of varchar2(20) index by binary_integer;

TYPE t_stati is TABLE of number(5) index by binary_integer;

TYPE t_mandanten is TABLE of varchar2(12) index by binary_integer; 

TYPE t_QNRTable is table of varchar2(40);       


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
                               y              number   default 11);
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
                               y              number   default 11);
function dummywert return owa_util.vc_arr;
   procedure verantr_aktion    (antrids   owa_util.vc_arr   default dummywert,
                                      aktion    varchar2 default null,
                                      komment   varchar2 default NULL,
                                      anzeigen  varchar2 default null,
                                      url       varchar2 default null,
                                      pmid      varchar2 default null);

procedure verantr_save   (ANTRMANDIDVERFDAT owa_util.vc_arr   default dummywert,
                            ANTRVERFDATS owa_util.vc_arr   default dummywert,
    antrids   owa_util.vc_arr   default dummywert,
                                      ANTRMANDIDVERFDATALL    varchar2 default null,
                                      komment   varchar2 default null,

                                      anzeigen  varchar2 default null,
                                      url       varchar2 default null,
                                      pmid      varchar2 default null);
procedure usr (anzeigen       varchar2 default null);      
procedure gen (anzeigen       varchar2 default null);                                
                                      end;

/

  GRANT EXECUTE ON "ZUL"."REZERTIFIZIERUNG" TO "APACHE";
  GRANT EXECUTE ON "ZUL"."REZERTIFIZIERUNG" TO "MPR";
