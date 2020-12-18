%% $Id: commonDB.hrl 720 2010-03-05 08:08:19Z ethrbh $

-ifndef(COMMONDB_HRL).
-define(COMMONDB_HRL,true).

-define(R2CTAB, rec2colTable).
-define(FI(R), {{R, record_info(fields, R)}, commonDB:fieldIndexes(R, record_info(fields, R))}).

-endif.