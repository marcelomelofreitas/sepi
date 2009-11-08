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
  �tend les informations et les routines propos�es par l'unit� TypInfo
  @author sjrd
  @version 1.0
*}
unit ScTypInfo;

interface

uses
  TypInfo;

const
  /// Types qui requi�rent une initialisation
  { tkArray and tkRecord are listed here, though static arrays and record don't
    always need initialization, because these types have got RTTI if and only
    if the particular type needs initialization. }
  NeedInitTypeKinds = [
    tkLString, tkWString, tkVariant, tkArray, tkRecord, tkInterface, tkDynArray
  ];

type
  /// Pointeur vers TRecordField
  PRecordField = ^TRecordField;

  {*
    Champ d'un record (qui requiert une initialisation)
    @author sjrd
    @version 1.0
  *}
  TRecordField = packed record
    TypeInfo: PPTypeInfo; /// RTTI du type du champ
    Offset: Integer;      /// Offset du champ dans le record
  end;

  /// Pointeur vers TRecordTypeData
  PRecordTypeData = ^TRecordTypeData;

  {*
    Donn�es d'un type record
    @author sjrd
    @version 1.0
  *}
  TRecordTypeData = packed record
    Size: Integer;                       /// Taille du type
    FieldCount: Integer;                 /// Nombre de champs
    Fields: array[0..0] of TRecordField; /// Champs (0..FieldCount-1)
  end;

  /// Pointeur vers TArrayTypeData
  PArrayTypeData = ^TArrayTypeData;

  {*
    Donn�es d'un type tableau statique
    @author sjrd
    @version 1.0
  *}
  TArrayTypeData = packed record
    Size: Integer;      /// Taille du type
    Count: Integer;     /// Nombre d'�l�ments (lin�aris�s)
    ElType: PPTypeInfo; /// RTTI du type des �l�ments
  end;

function TypeSize(TypeInfo: PTypeInfo): Integer;

procedure CopyData(const Source; var Dest; Size: Integer;
  TypeInfo: PTypeInfo); overload;
procedure CopyData(const Source; var Dest; TypeInfo: PTypeInfo); overload;

function AreInitFinitCompatible(Left, Right: PTypeInfo): Boolean;

implementation

uses
  ScCompilerMagic;

{*
  D�termine la taille d'un type � partir de ses RTTI
  Le seul cas dans lequel TypeSize est incapable de d�terminer la taille du
  type (et donc renvoie -1), est si TypeInfo.Kind = tkUnknown, ce qui ne
  devrait jamais arriver.
  @param TypeInfo   RTTI du type
  @return Taille du type, ou -1 si c'est impossible � d�terminer
*}
function TypeSize(TypeInfo: PTypeInfo): Integer;
const
  TypeKindToSize: array[TTypeKind] of Integer = (
    -1, 0, 1, 0, 0, 0, 0, 4, 8, 2, 4, 4, 16, 0, 0, 4, 8, 4
  );
  OrdTypeToSize: array[TOrdType] of Integer = (1, 1, 2, 2, 4, 4);
  FloatTypeToSize: array[TFloatType] of Integer = (4, 8, 10, 8, 8);
var
  TypeData: PTypeData;
begin
  Result := TypeKindToSize[TypeInfo.Kind];

  if Result = 0 then
  begin
    TypeData := GetTypeData(TypeInfo);
    case TypeInfo.Kind of
      tkInteger,
      tkEnumeration: Result := OrdTypeToSize[TypeData.OrdType];
      tkFloat: Result := FloatTypeToSize[TypeData.FloatType];
      tkString: Result := TypeData.MaxLength+1;
      tkArray: Result := PArrayTypeData(TypeData).Size;
      tkRecord: Result := PRecordTypeData(TypeData).Size;

      { Though tkSet has also the OrdType field, it isn't always reliable,
        since it can be out of range for large sets. }
      tkSet:
      begin
        with GetTypeData(TypeData.CompType^)^ do
          Result := (MaxValue - MinValue) div 8 + 1;
        if Result = 3 then
          Result := 4;
      end;
    end;
  end;
end;

{*
  Copie une variable
  Le param�tre TypeInfo n'est requis que si le type de donn�es requiert une
  initialisation. Mais ce n'est pas une erreur de le renseigner m�me dans les
  autres cas.
  @param Source     Variable source
  @param Dest       Variable destination
  @param Size       Taille du type de la variable
  @param TypeInfo   RTTI du type de la variable (si requiert une initialisation)
*}
procedure CopyData(const Source; var Dest; Size: Integer;
  TypeInfo: PTypeInfo);
begin
  if Assigned(TypeInfo) and (TypeInfo.Kind in NeedInitTypeKinds) then
    CopyData(Source, Dest, TypeInfo)
  else
    Move(Source, Dest, Size);
end;

{*
  Copie une variable dont le type poss�de des RTTI
  Utilisez cette variante de CopyData si vous ne connaissez pas la taille du
  type de donn�es. En revanche, vous devez fournir des RTTI non-nulles du type.
  @param Source     Variable source
  @param Dest       Variable destination
  @param TypeInfo   RTTI du type de la variable
*}
procedure CopyData(const Source; var Dest; TypeInfo: PTypeInfo);
begin
  case TypeInfo.Kind of
    tkLString: AnsiString(Dest) := AnsiString(Source);
    tkWString: WideString(Dest) := WideString(Source);
    tkVariant: Variant(Dest) := Variant(Source);
    tkArray:
      with PArrayTypeData(GetTypeData(TypeInfo))^ do
        CopyArray(@Dest, @Source, ElType^, Count);
    tkRecord: CopyRecord(@Dest, @Source, TypeInfo);
    tkInterface: IInterface(Dest) := IInterface(Source);
    tkDynArray: DynArrayAsg(Pointer(Dest), Pointer(Source), TypeInfo);
  else
    Move(Source, Dest, TypeSize(TypeInfo));
  end;
end;

{*
  Teste si deux types tableau statique sont compatibles init/finit
  @param Left    Premier type
  @param Right   Second type
  @return True s'ils sont compatibles, False sinon
*}
function AreArraysInitFinitCompatible(Left, Right: PArrayTypeData): Boolean;
begin
  Result := (Left.Size = Right.Size) and (Left.Count = Right.Count) and
    AreInitFinitCompatible(Left.ElType^, Right.ElType^);
end;

{*
  Teste si deux types record sont compatibles init/finit
  @param Left    Premier type
  @param Right   Second type
  @return True s'ils sont compatibles, False sinon
*}
function AreRecordsInitFinitCompatible(Left, Right: PRecordTypeData): Boolean;
var
  I: Integer;
begin
  Result := False;

  if Left.FieldCount <> Right.FieldCount then
    Exit;

  for I := 0 to Left.FieldCount-1 do
  begin
    if Left.Fields[I].Offset <> Right.Fields[I].Offset then
      Exit;
    if not AreInitFinitCompatible(
      Left.Fields[I].TypeInfo^, Right.Fields[I].TypeInfo^) then
      Exit;
  end;

  Result := True;
end;

{*
  Teste si deux types tableau dynamique sont compatibles init/finit
  @param Left    Premier type
  @param Right   Second type
  @return True s'ils sont compatibles, False sinon
*}
function AreDynArraysInitFinitCompatible(Left, Right: PTypeData): Boolean;
begin
  Result := (Left.elSize = Right.elSize) and
    AreInitFinitCompatible(Left.elType^, Right.elType^);
end;

{*
  Teste si deux types sont compatibles au niveau de leur initialisation
  Deux types sont compatibles si et seulement si initialiser/finaliser une
  variable d'un des deux types avec les RTTI de l'autre type est valide.
  Notez que les tailles des types n'ont pas besoin d'�tre �gales. En
  particulier, deux types de tailles quelconques et diff�rentes sont compatibles
  s'ils ne n�cessitent aucune initialisation.
  Un cas tr�s particulier n'est pas trait� parfaitement dans cette
  impl�mentation : celui ou un type record a la m�me structure qu'un tableau
  statique. Est alors renvoy� False au lieu de True.
  @param Left    Premier type
  @param Right   Second type
  @return True s'ils sont compatibles, False sinon
*}
function AreInitFinitCompatible(Left, Right: PTypeInfo): Boolean;
var
  LeftData, RightData: Pointer;
begin
  if ((Left = nil) or (not (Left.Kind in NeedInitTypeKinds))) and
    ((Right = nil) or (not (Right.Kind in NeedInitTypeKinds))) then
    Result := True
  else if (Left = nil) or (Right = nil) then
    Result := False
  else if Left.Kind <> Right.Kind then
    Result := False
  else
  begin
    LeftData := GetTypeData(Left);
    RightData := GetTypeData(Right);

    case Left.Kind of
      tkArray:
        Result := AreArraysInitFinitCompatible(LeftData, RightData);
      tkRecord:
        Result := AreRecordsInitFinitCompatible(LeftData, RightData);
      tkDynArray:
        Result := AreDynArraysInitFinitCompatible(LeftData, RightData);
    else
      Result := True;
    end;
  end;
end;

end.

