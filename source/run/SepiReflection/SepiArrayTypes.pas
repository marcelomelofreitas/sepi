{-------------------------------------------------------------------------------
Sepi - Object-oriented script engine for Delphi
Copyright (C) 2006-2007  S�bastien Doeraene
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
-------------------------------------------------------------------------------}

{*
  D�finit les classes de gestion des types tableau
  @author sjrd
  @version 1.0
*}
unit SepiArrayTypes;

interface

uses
  Classes, SysUtils, SysConst, TypInfo, ScUtils, SepiReflectionCore;

type
  {*
    Informations sur une dimension de tableau
    @author sjrd
    @version 1.0
  *}
  TDimInfo = record
    MinValue: Integer;
    MaxValue: Integer;
  end;

  {*
    Type tableau statique (� N dimensions)
    @author sjrd
    @version 1.0
  *}
  TSepiArrayType = class(TSepiType)
  private
    FDimCount: Integer;             /// Nombre de dimensions
    FDimensions: array of TDimInfo; /// Dimensions
    FElementType: TSepiType;        /// Type des �l�ments

    procedure MakeSize;
    procedure MakeTypeInfo;

    function GetDimensions(Index, Kind: Integer): Integer;
  protected
    procedure ListReferences; override;
    procedure Save(Stream: TStream); override;

    function GetAlignment: Integer; override;
  public
    constructor Load(AOwner: TSepiMeta; Stream: TStream); override;
    constructor Create(AOwner: TSepiMeta; const AName: string;
      const ADimensions: array of Integer; AElementType: TSepiType;
      AIsNative: Boolean = False; ATypeInfo: PTypeInfo = nil); overload;
    constructor Create(AOwner: TSepiMeta; const AName: string;
      const ADimensions: array of Integer; AElementTypeInfo: PTypeInfo;
      AIsNative: Boolean = False; ATypeInfo: PTypeInfo = nil); overload;
    constructor Create(AOwner: TSepiMeta; const AName: string;
      const ADimensions: array of Integer; const AElementTypeName: string;
      AIsNative: Boolean = False; ATypeInfo: PTypeInfo = nil); overload;

    function CompatibleWith(AType: TSepiType): Boolean; override;

    property DimCount: Integer read FDimCount;

    /// Bornes inf�rieures des dimensions
    property MinValues[Index: Integer]: Integer index 1 read GetDimensions;
    /// Bornes sup�rieures des dimensions
    property MaxValues[Index: Integer]: Integer index 2 read GetDimensions;
    /// Nombres d'�l�ments des dimensions
    property Dimensions[Index: Integer]: Integer index 3 read GetDimensions;

    property ElementType: TSepiType read FElementType;
  end;

  {*
    Type tableau dynamique (� une dimension)
    @author sjrd
    @version 1.0
  *}
  TSepiDynArrayType = class(TSepiType)
  private
    FElementType: TSepiType; /// Type des �l�ments

    procedure MakeTypeInfo;
  protected
    procedure ListReferences; override;
    procedure Save(Stream: TStream); override;

    procedure ExtractTypeData; override;
  public
    constructor RegisterTypeInfo(AOwner: TSepiMeta;
      ATypeInfo: PTypeInfo); override;
    constructor Load(AOwner: TSepiMeta; Stream: TStream); override;
    constructor Create(AOwner: TSepiMeta; const AName: string;
      AElementType: TSepiType);

    procedure SetElementType(AElementType: TSepiType); overload;
    procedure SetElementType(const AElementTypeName: string); overload;

    function CompatibleWith(AType: TSepiType): Boolean; override;

    property ElementType: TSepiType read FElementType;
  end;

implementation

type
  PArrayTypeData = ^TArrayTypeData;
  TArrayTypeData = packed record
    Size: Cardinal;
    Count: Cardinal;
    ElemType: PPTypeInfo;
    ElemOffset: Cardinal; // always 0
  end;

const
  // Tailles de structure TTypeData en fonction des types
  ArrayTypeDataLength = SizeOf(TArrayTypeData);
  DynArrayTypeDataLengthBase =
    SizeOf(Longint) + 2*SizeOf(Pointer) + SizeOf(Integer);

{-----------------------}
{ Classe TSepiArrayType }
{-----------------------}

{*
  Charge un type entier depuis un flux
*}
constructor TSepiArrayType.Load(AOwner: TSepiMeta; Stream: TStream);
begin
  inherited;

  FDimCount := 0;
  Stream.ReadBuffer(FDimCount, 1);

  SetLength(FDimensions, FDimCount);
  Stream.ReadBuffer(FDimensions[0], FDimCount*SizeOf(TDimInfo));
  OwningUnit.ReadRef(Stream, FElementType);

  MakeSize;
  FNeedInit := FElementType.NeedInit;
  FParamBehavior.AlwaysByAddress := Size > 4;
  if FParamBehavior.AlwaysByAddress then
    FResultBehavior := rbParameter;

  MakeTypeInfo;
end;

{*
  Cr�e un nouveau type tableau
  @param AOwner         Propri�taire du type
  @param AName          Nom du type
  @param ADimensions    Dimensions du tableau [Min1, Max1, Min2, Max2, ...]
  @param AElementType   Type des �l�ments
  @param AIsNative      Indique si le type tableau est natif
  @param ATypeInfo      RTTI du type tableau natif
*}
constructor TSepiArrayType.Create(AOwner: TSepiMeta; const AName: string;
  const ADimensions: array of Integer; AElementType: TSepiType;
  AIsNative: Boolean = False; ATypeInfo: PTypeInfo = nil);
begin
  inherited Create(AOwner, AName, tkArray);

  FDimCount := Length(ADimensions) div 2;
  SetLength(FDimensions, FDimCount);
  Move(ADimensions[Low(ADimensions)], FDimensions[0],
    FDimCount*SizeOf(TDimInfo));

  FElementType := AElementType;

  MakeSize;
  FNeedInit := FElementType.NeedInit;
  FParamBehavior.AlwaysByAddress := Size > 4;
  if FParamBehavior.AlwaysByAddress then
    FResultBehavior := rbParameter;

  if AIsNative then
    ForceNative(ATypeInfo);
  if ATypeInfo = nil then
    MakeTypeInfo;
end;

{*
  Cr�e un nouveau type tableau
  @param AOwner             Propri�taire du type
  @param AName              Nom du type
  @param ADimensions        Dimensions du tableau [Min1, Max1, Min2, Max2, ...]
  @param AElementTypeInfo   RTTI du type des �l�ments
  @param AIsNative          Indique si le type tableau est natif
  @param ATypeInfo          RTTI du type tableau natif
*}
constructor TSepiArrayType.Create(AOwner: TSepiMeta; const AName: string;
  const ADimensions: array of Integer; AElementTypeInfo: PTypeInfo;
  AIsNative: Boolean = False; ATypeInfo: PTypeInfo = nil);
begin
  Create(AOwner, AName, ADimensions, AOwner.Root.FindType(AElementTypeInfo),
    AIsNative, ATypeInfo);
end;

{*
  Cr�e un nouveau type tableau
  @param AOwner             Propri�taire du type
  @param AName              Nom du type
  @param ADimensions        Dimensions du tableau [Min1, Max1, Min2, Max2, ...]
  @param AElementTypeName   Nom du type des �l�ments
  @param AIsNative          Indique si le type tableau est natif
  @param ATypeInfo          RTTI du type tableau natif
*}
constructor TSepiArrayType.Create(AOwner: TSepiMeta; const AName: string;
  const ADimensions: array of Integer; const AElementTypeName: string;
  AIsNative: Boolean = False; ATypeInfo: PTypeInfo = nil);
begin
  Create(AOwner, AName, ADimensions, AOwner.Root.FindType(AElementTypeName),
    AIsNative, ATypeInfo);
end;

{*
  Calcule la taille du tableau et la range dans FSize
*}
procedure TSepiArrayType.MakeSize;
var
  I: Integer;
begin
  FSize := FElementType.Size;
  for I := 0 to DimCount-1 do
    FSize := FSize * Dimensions[I];
end;

{*
  Construit les RTTI (si besoin)
*}
procedure TSepiArrayType.MakeTypeInfo;
begin
  if not NeedInit then
    Exit;

  AllocateTypeInfo(ArrayTypeDataLength);
  with PArrayTypeData(TypeData)^ do
  begin
    Size := FSize;
    Count := FSize div FElementType.Size;
    ElemType := TSepiArrayType(FElementType).TypeInfoRef;
    ElemOffset := 0;
  end;
end;

{*
  R�cup�re une information sur une dimension
*}
function TSepiArrayType.GetDimensions(Index, Kind: Integer): Integer;
begin
  with FDimensions[Index] do
  begin
    case Kind of
      1: Result := MinValue;
      2: Result := MaxValue;
    else
      Result := MaxValue-MinValue+1;
    end;
  end;
end;

{*
  [@inheritDoc]
*}
procedure TSepiArrayType.ListReferences;
begin
  inherited;
  OwningUnit.AddRef(FElementType);
end;

{*
  [@inheritDoc]
*}
procedure TSepiArrayType.Save(Stream: TStream);
begin
  inherited;
  Stream.WriteBuffer(FDimCount, 1);
  Stream.WriteBuffer(FDimensions[0], FDimCount*SizeOf(TDimInfo));
  OwningUnit.WriteRef(Stream, FElementType);
end;

{*
  [@inheritDoc]
*}
function TSepiArrayType.GetAlignment: Integer;
begin
  Result := ElementType.Alignment;
end;

{*
  [@inheritDoc]
*}
function TSepiArrayType.CompatibleWith(AType: TSepiType): Boolean;
begin
  Result := False;
end;

{--------------------------}
{ Classe TSepiDynArrayType }
{--------------------------}

{*
  Recense un type tableau dynamique natif
*}
constructor TSepiDynArrayType.RegisterTypeInfo(AOwner: TSepiMeta;
  ATypeInfo: PTypeInfo);
begin
  inherited;
  ExtractTypeData;
end;

{*
  Charge un type tableau dynamique depuis un flux
*}
constructor TSepiDynArrayType.Load(AOwner: TSepiMeta; Stream: TStream);
begin
  inherited;

  OwningUnit.ReadRef(Stream, FElementType);

  MakeTypeInfo;
end;

{*
  Cr�e un nouveau type tableau dynamique
  @param AOwner         Propri�taire du type
  @param AName          Nom du type
  @param AElementType   Type des �l�ments
*}
constructor TSepiDynArrayType.Create(AOwner: TSepiMeta; const AName: string;
  AElementType: TSepiType);
begin
  inherited Create(AOwner, AName, tkDynArray);

  FElementType := AElementType;
  MakeTypeInfo;
end;

{*
  Construit les RTTI du type tableau dynamique
*}
procedure TSepiDynArrayType.MakeTypeInfo;
var
  UnitName: ShortString;
  TypeDataLength: Integer;
begin
  UnitName := OwningUnit.Name;
  TypeDataLength := DynArrayTypeDataLengthBase + Length(UnitName) + 1;
  AllocateTypeInfo(TypeDataLength);

  FSize := 4;
  FNeedInit := True;
  FResultBehavior := rbParameter;

  // Element size
  TypeData.elSize := FElementType.Size;

  // Element RTTI, if need initialization
  // Types which need initialization always have got RTTI
  if FElementType.NeedInit then
    TypeData.elType := TSepiDynArrayType(FElementType).TypeInfoRef
  else
    TypeData.elType := nil;

  // OLE Variant equivalent - always set to -1 at the moment
  { TODO 1 -cMetaunit�s : OLE Variant dans les RTTI des dyn array }
  TypeData.varType := -1;

  // Element RTTI, independant of cleanup
  // Whe have to check for nul-RTTI, because of records and static arrays
  if Assigned(FElementType.TypeInfo) then
    TypeData.elType2 := TSepiDynArrayType(FElementType).TypeInfoRef
  else
    TypeData.elType2 := nil;

  // Unit name
  Move(UnitName[0], TypeData.DynUnitName[0], Length(UnitName)+1);
end;

{*
  [@inheritDoc]
*}
procedure TSepiDynArrayType.ListReferences;
begin
  inherited;
  OwningUnit.AddRef(FElementType);
end;

{*
  [@inheritDoc]
*}
procedure TSepiDynArrayType.Save(Stream: TStream);
begin
  inherited;
  OwningUnit.WriteRef(Stream, FElementType);
end;

{*
  [@inheritDoc]
*}
procedure TSepiDynArrayType.ExtractTypeData;
begin
  inherited;

  FSize := 4;
  FNeedInit := True;
  FResultBehavior := rbParameter;

  if Assigned(TypeData.elType2) then
    FElementType := Root.FindType(TypeData.elType2^);
  // Otherwise, the element type should be set with SetElementType
end;

{*
  Renseigne le type des �l�ments
  Cette m�thode ne doit �tre appel�e que pour un tableau dynamique natif, dont
  les �l�ments n'ont pas de RTTI, et juste apr�s le constructeur
  RegisterTypeInfo.
  @param AElementType   Type des �l�ments
*}
procedure TSepiDynArrayType.SetElementType(AElementType: TSepiType);
begin
  Assert(Native and (FElementType = nil));
  FElementType := AElementType;
end;

{*
  Renseigne le type des �l�ments
  Cette m�thode ne doit �tre appel�e que pour un tableau dynamique natif, dont
  les �l�ments n'ont pas de RTTI, et juste apr�s le constructeur
  RegisterTypeInfo.
  @param AElementTypeName   Nom du type des �l�ments
*}
procedure TSepiDynArrayType.SetElementType(const AElementTypeName: string);
begin
  SetElementType(Root.FindType(AElementTypeName));
end;

{*
  [@inheritDoc]
*}
function TSepiDynArrayType.CompatibleWith(AType: TSepiType): Boolean;
begin
  Result := False;
end;

initialization
  SepiRegisterMetaClasses([
    TSepiArrayType, TSepiDynArrayType
  ]);
end.
