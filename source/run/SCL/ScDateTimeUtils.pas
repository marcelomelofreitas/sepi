{-------------------------------------------------------------------------------
Sepi - Object-oriented script engine for Delphi
Copyright (C) 2006-2009  S�bastien Doeraene
All Rights Reserved

This file is part of Sepi.

Sepi is free software: you can redistribute it and/or modify it under the terms
of the GNU General Public License as published by the Free Software Foundation,
either version 3 of the License, or (at your option) any later version.

Sepi is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
Sepi.  If not, see <http://www.gnu.org/licenses/>.

Linking this library statically or dynamically with other modules is making a
combined work based on this library.  Thus, the terms and conditions of the GNU
General Public License cover the whole combination.

As a special exception, the copyright holders of this library give you
permission to link this library with independent modules to produce an
executable, regardless of the license terms of these independent modules, and
to copy and distribute the resulting executable under terms of your choice,
provided that you also meet, for each linked independent module, the terms and
conditions of the license of that module.  An independent module is a module
which is not derived from or based on this library.  If you modify this
library, you may extend this exception to your version of the library, but you
are not obligated to do so.  If you do not wish to do so, delete this exception
statement from your version.
-------------------------------------------------------------------------------}

{*
  D�finit quelques routines de dates et heures
  @author sjrd
  @version 1.0
*}
unit ScDateTimeUtils;

interface

function GetMonthName(Month: Integer; Maj: Boolean = True): string;

implementation

uses
  ScConsts;

{*
  Renvoie le nom d'un mois
  @param Month   Mois bas� sur 1
  @param Maj     Indique si la premi�re lettre doit �tre une majuscule
  @return Le nom du mois Month, avec une majuscule si Maj vaut True
*}
function GetMonthName(Month: Integer; Maj: Boolean = True): string;
begin
  case Month of
    1: Result := sJanuary;
    2: Result := sFebruary;
    3: Result := sMarch;
    4: Result := sApril;
    5: Result := sMay;
    6: Result := sJune;
    7: Result := sJuly;
    8: Result := sAugust;
    9: Result := sSeptember;
    10: Result := sOctober;
    11: Result := sNovember;
    12: Result := sDecember;
  else
    Result := '';
  end;
  if Maj and (Result <> '') then
    Dec(Result[1], 32);
end;

end.

