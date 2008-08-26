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
  Instructions assembleur Sepi
  @author sjrd
  @version 1.0
*}
unit SepiAsmInstructions;

interface

uses
  Windows, Classes, SysUtils, TypInfo, SepiReflectionCore, SepiMembers,
  SepiOpCodes, SepiCompiler, SepiReflectionConsts;

resourcestring
  SMultipleParamsWithSameSepiStackOffset =
    'Plusieurs param�tres ont la m�me valeur de SepiStackOffset';
  SParamsSepiStackOffsetsDontFollow =
    'Les SepiStackOffset des param�tres ne se suivent pas';
  SInvalidDataSize = 'Taille de donn�es invalide';
  SObjectMustHaveASignature = 'L''objet %s n''a pas de signature';

type
  {*
    Param�tres invalide dans une instruction CALL
  *}
  ESepiInvalidParamsError = class(ESepiCompilerError);

  {*
    Taille de donn�es invalide pour un MOVE
  *}
  ESepiInvalidDataSizeError = class(ESepiCompilerError);

  {*
    Instruction NOP
    @author sjrd
    @version 1.0
  *}
  TSepiAsmNope = class(TSepiAsmInstr)
  end;

  {*
    Instruction JUMP
    @author sjrd
    @version 1.0
  *}
  TSepiAsmJump = class(TSepiAsmInstr)
  private
    FDestination: TSepiJumpDest; /// Destination du JUMP
  public
    constructor Create(AMethodCompiler: TSepiMethodCompiler);
    destructor Destroy; override;

    procedure Make; override;
    procedure WriteToStream(Stream: TStream); override;

    property Destination: TSepiJumpDest read FDestination;
  end;

  {*
    Instruction JIT ou JIF (JUMP conditionnel)
    @author sjrd
    @version 1.0
  *}
  TSepiAsmCondJump = class(TSepiAsmInstr)
  private
    FIfTrue: Boolean;            /// True donne un JIT, False donne un JIF
    FDestination: TSepiJumpDest; /// Destination du JUMP
    FTest: TSepiMemoryReference; /// Condition du saut
  public
    constructor Create(AMethodCompiler: TSepiMethodCompiler;
      AIfTrue: Boolean = True);
    destructor Destroy; override;

    procedure Make; override;
    procedure WriteToStream(Stream: TStream); override;

    property IfTrue: Boolean read FIfTrue write FIfTrue;
    property Destination: TSepiJumpDest read FDestination;
    property Test: TSepiMemoryReference read FTest;
  end;

  {*
    Param�tre d'une instruction CALL
    @author sjrd
    @version 1.0
  *}
  TSepiAsmCallParam = class(TObject)
  private
    FName: string;                    /// Nom du param�tre
    FSepiStackOffset: Integer;        /// Offset dans la pile Sepi
    FParamSize: TSepiParamSize;       /// Taille du param�tre
    FStackUsage: Integer;             /// Nombre de DWord utilis�s dans la pile
    FMemoryRef: TSepiMemoryReference; /// R�f�rence m�moire

    FSize: Integer; /// Taille �crite dans le flux
  public
    constructor Create(AMethodCompiler: TSepiMethodCompiler;
      ASepiStackOffset: Integer; AParamSize: TSepiParamSize;
      const AName: string = '');
    destructor Destroy; override;

    procedure Make;
    procedure WriteToStream(Stream: TStream);

    property Name: string read FName;
    property SepiStackOffset: Integer read FSepiStackOffset;
    property ParamSize: TSepiParamSize read FParamSize;
    property StackUsage: Integer read FStackUsage;
    property MemoryRef: TSepiMemoryReference read FMemoryRef;

    property Size: Integer read FSize;
  end;

  {*
    Param�tres d'une instruction CALL
    @author sjrd
    @version 1.0
  *}
  TSepiAsmCallParams = class(TObject)
  private
    FMethodCompiler: TSepiMethodCompiler; /// Compilateur de m�thode

    FParameters: array of TSepiAsmCallParam; /// Param�tres
    FResult: TSepiMemoryReference;           /// R�sultat

    FSize: Integer; /// Taille �crite dans le flux

    procedure SortParameters;

    function GetCount: Integer;
    function GetParameters(Index: Integer): TSepiAsmCallParam;
    function GetParamByName(const Name: string): TSepiMemoryReference;
  public
    constructor Create(AMethodCompiler: TSepiMethodCompiler);
    destructor Destroy; override;

    procedure Prepare(Signature: TSepiSignature);

    function AddParam(SepiStackOffset: Integer;
      ParamSize: TSepiParamSize): TSepiMemoryReference;

    procedure Make;
    procedure WriteToStream(Stream: TStream);

    property MethodCompiler: TSepiMethodCompiler read FMethodCompiler;

    property Count: Integer read GetCount;
    property Parameters[Index: Integer]: TSepiAsmCallParam
      read GetParameters;
    property ParamByName[const Name: string]: TSepiMemoryReference
      read GetParamByName; default;
    property Result: TSepiMemoryReference read FResult;

    property Size: Integer read FSize;
  end;

  {*
    Instruction CALL
    @author sjrd
    @version 1.0
  *}
  TSepiAsmCall = class(TSepiAsmInstr)
  private
    FParameters: TSepiAsmCallParams; /// Param�tres
  public
    constructor Create(AMethodCompiler: TSepiMethodCompiler);
    destructor Destroy; override;

    procedure Prepare(Signature: TSepiSignature); overload; virtual;
    procedure Prepare(Meta: TSepiMeta); overload;
    procedure Prepare(const MetaName: string); overload;

    procedure Make; override;

    property Parameters: TSepiAsmCallParams read FParameters;
  end;

  {*
    Instruction Address CALL
    @author sjrd
    @version 1.0
  *}
  TSepiAsmAddressCall = class(TSepiAsmCall)
  private
    FCallingConvention: TCallingConvention;   /// Convention d'appel
    FRegUsage: Byte;                          /// Utilisation des registres
    FResultBehavior: TSepiTypeResultBehavior; /// Comportement du r�sultat

    FAddress: TSepiMemoryReference; /// Adresse de la m�thode � appeler
  public
    constructor Create(AMethodCompiler: TSepiMethodCompiler);
    destructor Destroy; override;

    procedure Prepare(Signature: TSepiSignature); override;

    procedure Make; override;
    procedure WriteToStream(Stream: TStream); override;

    property CallingConvention: TCallingConvention
      read FCallingConvention write FCallingConvention;
    property RegUsage: Byte read FRegUsage write FRegUsage;
    property ResultBehavior: TSepiTypeResultBehavior
      read FResultBehavior write FResultBehavior;

    property Address: TSepiMemoryReference read FAddress;
  end;

  {*
    Instruction CALL avec une r�f�rence � la m�thode
    @author sjrd
    @version 1.0
  *}
  TSepiAsmRefCall = class(TSepiAsmCall)
  private
    FMethodRef: Integer; /// R�f�rence � la m�thode
  public
    constructor Create(AMethodCompiler: TSepiMethodCompiler);

    procedure SetMethod(Method: TSepiMethod;
      PrepareParams: Boolean = True); overload;
    procedure SetMethod(const MethodName: string;
      PrepareParams: Boolean = True); overload;

    property MethodRef: Integer read FMethodRef write FMethodRef;
  end;

  {*
    Instruction Static CALL
    @author sjrd
    @version 1.0
  *}
  TSepiAsmStaticCall = class(TSepiAsmRefCall)
  public
    constructor Create(AMethodCompiler: TSepiMethodCompiler);

    procedure Make; override;
    procedure WriteToStream(Stream: TStream); override;
  end;

  {*
    Instruction Dynamic CALL
    @author sjrd
    @version 1.0
  *}
  TSepiAsmDynamicCall = class(TSepiAsmRefCall)
  private
    FSelfMem: TSepiMemoryReference; /// R�f�rence m�moire au Self
  public
    constructor Create(AMethodCompiler: TSepiMethodCompiler);
    destructor Destroy; override;

    procedure Make; override;
    procedure WriteToStream(Stream: TStream); override;

    property SelfMem: TSepiMemoryReference read FSelfMem;
  end;

  {*
    Instruction LEA
    @author sjrd
    @version 1.0
  *}
  TSepiAsmLoadAddress = class(TSepiAsmInstr)
  private
    FDestination: TSepiMemoryReference; /// Destination
    FSource: TSepiMemoryReference;      /// Source
  public
    constructor Create(AMethodCompiler: TSepiMethodCompiler);
    destructor Destroy; override;

    procedure Make; override;
    procedure WriteToStream(Stream: TStream); override;

    property Destination: TSepiMemoryReference read FDestination;
    property Source: TSepiMemoryReference read FSource;
  end;

  {*
    Instruction MOVE
    @author sjrd
    @version 1.0
  *}
  TSepiAsmMove = class(TSepiAsmInstr)
  private
    FDataSize: Word;      /// Taille des donn�es � copier
    FDataType: TSepiType; /// Type des donn�es � copier (si requis)

    FDestination: TSepiMemoryReference; /// Destination
    FSource: TSepiMemoryReference;      /// Source
  public
    constructor Create(AMethodCompiler: TSepiMethodCompiler;
      ADataSize: Word); overload;
    constructor Create(AMethodCompiler: TSepiMethodCompiler;
      ADataType: TSepiType); overload;
    destructor Destroy; override;

    procedure Make; override;
    procedure WriteToStream(Stream: TStream); override;

    property DataSize: Word read FDataSize;
    property DataType: TSepiType read FDataType;

    property Destination: TSepiMemoryReference read FDestination;
    property Source: TSepiMemoryReference read FSource;
  end;

  {*
    Instruction CVRT
    @author sjrd
    @version 1.0
  *}
  TSepiAsmConvert = class(TSepiAsmInstr)
  private
    FToType: TSepiBaseType;   /// Type de la destination
    FFromType: TSepiBaseType; /// Type de la source

    FDestination: TSepiMemoryReference; /// Destination
    FSource: TSepiMemoryReference;      /// Source
  public
    constructor Create(AMethodCompiler: TSepiMethodCompiler;
      AToType, AFromType: TSepiBaseType);
    destructor Destroy; override;

    procedure Make; override;
    procedure WriteToStream(Stream: TStream); override;

    property ToType: TSepiBaseType read FToType;
    property FromType: TSepiBaseType read FFromType;

    property Destination: TSepiMemoryReference read FDestination;
    property Source: TSepiMemoryReference read FSource;
  end;

  {*
    Instruction op�ration
    @author sjrd
    @version 1.0
  *}
  TSepiAsmOperation = class(TSepiAsmInstr)
  private
    FVarType: TSepiBaseType; /// Type des variables
    FUseLeft: Boolean;       /// Utilise un op�rande gauche
    FUseRight: Boolean;      /// Utilise un op�rande droit

    FDestination: TSepiMemoryReference; /// Destination
    FLeft: TSepiMemoryReference;        /// Op�rande gauche
    FRight: TSepiMemoryReference;       /// Op�rande droit
  public
    constructor Create(AMethodCompiler: TSepiMethodCompiler;
      AOpCode: TSepiOpCode; AVarType: TSepiBaseType);
    destructor Destroy; override;

    procedure Make; override;
    procedure WriteToStream(Stream: TStream); override;

    property VarType: TSepiBaseType read FVarType;
    property UseLeft: Boolean read FUseLeft;
    property UseRight: Boolean read FUseRight;

    property Destination: TSepiMemoryReference read FDestination;
    property Left: TSepiMemoryReference read FLeft;
    property Right: TSepiMemoryReference read FRight;

    /// Op�rande unique
    property Source: TSepiMemoryReference read FLeft;
  end;

  {*
    Instruction de comparaison
    @author sjrd
    @version 1.0
  *}
  TSepiAsmCompare = class(TSepiAsmInstr)
  private
    FVarType: TSepiBaseType; /// Type des variables

    FDestination: TSepiMemoryReference; /// Destination
    FLeft: TSepiMemoryReference;        /// Op�rande gauche
    FRight: TSepiMemoryReference;       /// Op�rande droit
  public
    constructor Create(AMethodCompiler: TSepiMethodCompiler;
      AOpCode: TSepiOpCode; AVarType: TSepiBaseType);
    destructor Destroy; override;

    procedure Make; override;
    procedure WriteToStream(Stream: TStream); override;

    property VarType: TSepiBaseType read FVarType;

    property Destination: TSepiMemoryReference read FDestination;
    property Left: TSepiMemoryReference read FLeft;
    property Right: TSepiMemoryReference read FRight;
  end;

  {*
    Instruction GTI, GDC ou GMC
    @author sjrd
    @version 1.0
  *}
  TSepiAsmGetRunInfo = class(TSepiAsmInstr)
  private
    FDestination: TSepiMemoryReference; /// Destination
    FReference: Integer;                /// R�f�rence
  public
    constructor Create(AMethodCompiler: TSepiMethodCompiler;
      AOpCode: TSepiOpCode);
    destructor Destroy; override;

    procedure SetReference(Reference: TSepiMeta); overload;
    procedure SetReference(const RefName: string); overload;

    procedure Make; override;
    procedure WriteToStream(Stream: TStream); override;

    property Destination: TSepiMemoryReference read FDestination;
    property Reference: Integer read FReference write FReference;
  end;

  {*
    Instruction IS
    @author sjrd
    @version 1.0
  *}
  TSepiAsmIsClass = class(TSepiAsmInstr)
  private
    FDestination: TSepiMemoryReference; /// Destination
    FMemObject: TSepiMemoryReference;   /// Objet m�moire
    FMemClass: TSepiMemoryReference;    /// Classe m�moire
    FClassRef: Integer;                 /// R�f�rence � une classe (si msZero)
  public
    constructor Create(AMethodCompiler: TSepiMethodCompiler);
    destructor Destroy; override;

    procedure Make; override;
    procedure WriteToStream(Stream: TStream); override;

    property Destination: TSepiMemoryReference read FDestination;
    property MemObject: TSepiMemoryReference read FMemObject;
    property MemClass: TSepiMemoryReference read FMemClass;
    property ClassRef: Integer read FClassRef write FClassRef;
  end;

  {*
    Instruction AS
    @author sjrd
    @version 1.0
  *}
  TSepiAsmAsClass = class(TSepiAsmInstr)
  private
    FMemObject: TSepiMemoryReference; /// Objet m�moire
    FMemClass: TSepiMemoryReference;  /// Classe m�moire
    FClassRef: Integer;               /// R�f�rence � une classe (si msZero)
  public
    constructor Create(AMethodCompiler: TSepiMethodCompiler);
    destructor Destroy; override;

    procedure Make; override;
    procedure WriteToStream(Stream: TStream); override;

    property MemObject: TSepiMemoryReference read FMemObject;
    property MemClass: TSepiMemoryReference read FMemClass;
    property ClassRef: Integer read FClassRef write FClassRef;
  end;

  {*
    Instruction RAISE
    @author sjrd
    @version 1.0
  *}
  TSepiAsmRaise = class(TSepiAsmInstr)
  private
    FExceptObject: TSepiMemoryReference; /// Objet exception
  public
    constructor Create(AMethodCompiler: TSepiMethodCompiler);
    destructor Destroy; override;

    procedure Make; override;
    procedure WriteToStream(Stream: TStream); override;

    property ExceptObject: TSepiMemoryReference read FExceptObject;
  end;

  {*
    Instruction RERS
    @author sjrd
    @version 1.0
  *}
  TSepiAsmReraise = class(TSepiAsmInstr)
  public
    constructor Create(AMethodCompiler: TSepiMethodCompiler);
  end;

  {*
    Instruction TRYE
    @author sjrd
    @version 1.0
  *}
  TSepiAsmTryExcept = class(TSepiAsmInstr)
  private
    FEndOfTry: TSepiJumpDest;            /// Fin du try
    FEndOfExcept: TSepiJumpDest;         /// Fin du except
    FExceptObject: TSepiMemoryReference; /// Objet exception
  public
    constructor Create(AMethodCompiler: TSepiMethodCompiler);
    destructor Destroy; override;

    procedure Make; override;
    procedure WriteToStream(Stream: TStream); override;

    property EndOfTry: TSepiJumpDest read FEndOfTry;
    property EndOfExcept: TSepiJumpDest read FEndOfExcept;
    property ExceptObject: TSepiMemoryReference read FExceptObject;
  end;

  {*
    Instruction TRYF
    @author sjrd
    @version 1.0
  *}
  TSepiAsmTryFinally = class(TSepiAsmInstr)
  private
    FEndOfTry: TSepiJumpDest;     /// Fin du try
    FEndOfFinally: TSepiJumpDest; /// Fin du finally
  public
    constructor Create(AMethodCompiler: TSepiMethodCompiler);
    destructor Destroy; override;

    procedure Make; override;
    procedure WriteToStream(Stream: TStream); override;

    property EndOfTry: TSepiJumpDest read FEndOfTry;
    property EndOfFinally: TSepiJumpDest read FEndOfFinally;
  end;

  {*
    Clause ON d'un MultiOn
    @author sjrd
    @version 1.0
  *}
  TSepiAsmOnClause = record
    ClassRef: Integer;          /// R�f�rence � une classe
    Destination: TSepiJumpDest; /// Destination du ON
  end;

  {*
    Instruction ON
    @author sjrd
    @version 1.0
  *}
  TSepiAsmMultiOn = class(TSepiAsmInstr)
  private
    FExceptObject: TSepiMemoryReference; /// Objet exception

    FOnClauses: array of TSepiAsmOnClause; /// Clauses ON

    function GetOnClauseCount: Integer;
    function GetOnClauses(Index: Integer): TSepiAsmOnClause;
  public
    constructor Create(AMethodCompiler: TSepiMethodCompiler);
    destructor Destroy; override;

    function AddOnClause(AClassRef: Integer): TSepiJumpDest; overload;
    function AddOnClause(SepiClass: TSepiClass): TSepiJumpDest; overload;
    function AddOnClause(const ClassName: string): TSepiJumpDest; overload;

    procedure Make; override;
    procedure WriteToStream(Stream: TStream); override;

    property ExceptObject: TSepiMemoryReference read FExceptObject;

    property OnClauseCount: Integer read GetOnClauseCount;
    property OnClauses[Index: Integer]: TSepiAsmOnClause read GetOnClauses;
  end;

implementation

const
  /// Nombre maximum de param�tres pour avoir un taille en Byte (sinon Word)
  MaxParamCountForByteSize = 255 div 3; // 3 is max param size (Extended)

  /// OpCodes d'op�rations unaires sur soi-m�me
  SelfUnaryOps = [ocSelfInc..ocSelfNeg];

  /// OpCodes d'op�rations binaires sur soi-m�me
  SelfBinaryOps = [ocSelfAdd..ocSelfXor];

  /// OpCodes d'op�rations unaires sur un autre
  OtherUnaryOps = [ocOtherInc..ocOtherNeg];

  /// OpCodes d'op�rations binaires sur un autre
  OtherBinaryOps = [ocOtherAdd..ocOtherXor];

  /// OpCodes d'op�rations
  OperationsOpCodes =
    SelfUnaryOps + SelfBinaryOps + OtherUnaryOps + OtherBinaryOps;

{--------------------}
{ TSepiAsmJump class }
{--------------------}

{*
  Cr�e une instruction JUMP
  @param AMethodCompiler   Compilateur de m�thode
*}
constructor TSepiAsmJump.Create(AMethodCompiler: TSepiMethodCompiler);
begin
  inherited Create(AMethodCompiler);

  FOpCode := ocJump;

  FDestination := TSepiJumpDest.Create(MethodCompiler);
end;

{*
  [@inheritDoc]
*}
destructor TSepiAsmJump.Destroy;
begin
  FDestination.Free;

  inherited;
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmJump.Make;
begin
  Destination.Make;
  FSize := SizeOf(TSepiOpCode) + SizeOf(Smallint);
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmJump.WriteToStream(Stream: TStream);
begin
  inherited;
  Destination.WriteToStream(Stream, EndPosition);
end;

{------------------------}
{ TSepiAsmCondJump class }
{------------------------}

{*
  Cr�e une instruction JIT ou JIF
  @param AMethodCompiler   Compilateur de m�thode
  @param AIfTrue            True donne un JIT plut�t qu'un JIF
*}
constructor TSepiAsmCondJump.Create(AMethodCompiler: TSepiMethodCompiler;
  AIfTrue: Boolean = True);
begin
  inherited Create(AMethodCompiler);

  FIfTrue := AIfTrue;
  FDestination := TSepiJumpDest.Create(MethodCompiler);
  FTest := TSepiMemoryReference.Create(MethodCompiler, aoAcceptAllConsts,
    SizeOf(Boolean));
end;

{*
  [@inheritDoc]
*}
destructor TSepiAsmCondJump.Destroy;
begin
  FTest.Free;
  FDestination.Free;

  inherited;
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmCondJump.Make;
begin
  if IfTrue then
    FOpCode := ocJumpIfTrue
  else
    FOpCode := ocJumpIfFalse;

  Destination.Make;
  Test.Make;

  FSize := SizeOf(TSepiOpCode) + SizeOf(Smallint) + Test.Size;
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmCondJump.WriteToStream(Stream: TStream);
begin
  inherited;

  Destination.WriteToStream(Stream, EndPosition);
  Test.WriteToStream(Stream);
end;

{-------------------------}
{ TSepiAsmCallParam class }
{-------------------------}

{*
  Cr�e un param�tre
  @param AMethodCompiler   Compilateur de m�thode Sepi
  @param ASepiStackOffset   Offset dans la pile Sepi
  @param AParamSize         Taille de param�tre
*}
constructor TSepiAsmCallParam.Create(AMethodCompiler: TSepiMethodCompiler;
  ASepiStackOffset: Integer; AParamSize: TSepiParamSize;
  const AName: string = '');
begin
  inherited Create;

  FName := AName;
  FSepiStackOffset := ASepiStackOffset;
  FParamSize := AParamSize;
  FMemoryRef := TSepiMemoryReference.Create(AMethodCompiler,
    aoAcceptAllConsts, ParamSize);
end;

{*
  [@inheritDoc]
*}
destructor TSepiAsmCallParam.Destroy;
begin
  FMemoryRef.Free;

  inherited;
end;

{*
  Construit le param�tre
*}
procedure TSepiAsmCallParam.Make;
const
  StackUsages: array[0..10] of Integer = (
    1 {address}, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3
  );
begin
  FSepiStackOffset := FSepiStackOffset and $FFFFFFFC;
  FStackUsage := StackUsages[FParamSize];

  MemoryRef.Make;
  FSize := SizeOf(TSepiParamSize) + MemoryRef.Size;
end;

{*
  Ecrit le param�tre dans un flux
  @param Stream   Flux de destination
*}
procedure TSepiAsmCallParam.WriteToStream(Stream: TStream);
begin
  Stream.WriteBuffer(FParamSize, SizeOf(TSepiParamSize));
  MemoryRef.WriteToStream(Stream);
end;

{--------------------------}
{ TSepiAsmCallParams class }
{--------------------------}

{*
  Cr�e une liste de param�tres d'intruction CALL
  @param AMethodCompiler   Compilateur de m�thode
*}
constructor TSepiAsmCallParams.Create(AMethodCompiler: TSepiMethodCompiler);
begin
  inherited Create;

  FMethodCompiler := AMethodCompiler;

  FResult := TSepiMemoryReference.Create(MethodCompiler, [aoZeroAsNil]);
end;

{*
  [@inheritDoc]
*}
destructor TSepiAsmCallParams.Destroy;
var
  I: Integer;
begin
  for I := 0 to Length(FParameters)-1 do
    FParameters[I].Free;

  inherited;
end;

{*
  Trie les param�tres selon l'ordre de leurs propri�t�s SepiStackOffset
*}
procedure TSepiAsmCallParams.SortParameters;
var
  I, J, ParamCount, Index: Integer;
  OrderedParams: array of TSepiAsmCallParam;
  Param, OldParam: TSepiAsmCallParam;
begin
  ParamCount := Length(FParameters);
  SetLength(OrderedParams, 3*ParamCount);
  FillChar(OrderedParams[0], 3*ParamCount*SizeOf(TSepiAsmCallParams), 0);

  // Fill OrderedParams and check for multiple params with same offset

  for I := 0 to ParamCount - 1 do
  begin
    Param := FParameters[I];
    Index := Param.SepiStackOffset div 4;

    for J := Index to Index + Param.StackUsage - 1 do
    begin
      if J >= Length(OrderedParams) then
        raise ESepiInvalidParamsError.CreateRes(
          @SParamsSepiStackOffsetsDontFollow);

      if OrderedParams[J] <> nil then
        raise ESepiInvalidParamsError.CreateRes(
          @SMultipleParamsWithSameSepiStackOffset);

      OrderedParams[J] := Param;
    end;
  end;

  // Rewrite FParameters

  OldParam := nil;
  J := 0;
  for I := 0 to 3 * ParamCount - 1 do
  begin
    Param := OrderedParams[I];
    if Param = nil then
      Break;
    if Param = OldParam then
      Continue;

    FParameters[J] := Param;
    Inc(J);
    OldParam := Param;
  end;

  // Ensure there is no forgotten parameters (it would be a hole in offsets)

  if J < ParamCount then
    raise ESepiInvalidParamsError.CreateRes(
      @SParamsSepiStackOffsetsDontFollow);
end;

{*
  Nombre de param�tres
  @return Nombre de param�tres
*}
function TSepiAsmCallParams.GetCount: Integer;
begin
  Result := Length(FParameters);
end;

{*
  Tableau zero-based des param�tres
  @param Index   Index d'un param�tre
  @return Param�tre � l'index sp�cifi�
*}
function TSepiAsmCallParams.GetParameters(Index: Integer): TSepiAsmCallParam;
begin
  Result := FParameters[Index];
end;

{*
  Tableau des r�f�rences m�moires des param�tres pr�par�s index�s par leurs noms
  @param Name   Nom du param�tre
  @return R�f�rence m�moire du param�tre
  @throws ESepiMetaNotFoundError Le param�tre n'a pas �t� trouv�
*}
function TSepiAsmCallParams.GetParamByName(
  const Name: string): TSepiMemoryReference;
var
  I: Integer;
begin
  for I := 0 to Length(FParameters)-1 do
  begin
    if AnsiSameText(FParameters[I].Name, Name) then
    begin
      Result := FParameters[I].MemoryRef;
      Exit;
    end;
  end;

  raise ESepiMetaNotFoundError.CreateResFmt(@SSepiObjectNotFound, [Name]);
end;

{*
  Pr�pare les param�tres en fonction d'une signature
  Pr�parer les param�tres a de multiples avantages. Il ne faut plus se
  pr�occuper des offsets et des tailles des param�tres, ni de leur �ventuel
  passage par adresse. De plus, pour les r�sultats qui sont pass�s comme
  param�tres, le fait de pr�parer les param�tres assigne � la propri�t� Result
  la r�f�rence m�moire � ce param�tre. Il n'y a donc plus de diff�rences entre
  un r�sultat pass� par adresse ou pas.
  @param Signature   Signature
*}
procedure TSepiAsmCallParams.Prepare(Signature: TSepiSignature);
var
  I: Integer;
  Param: TSepiParam;
  ParamSize: TSepiParamSize;
begin
  for I := 0 to Length(FParameters)-1 do
    FParameters[I].Free;
  SetLength(FParameters, Signature.ActualParamCount);

  for I := 0 to Signature.ActualParamCount-1 do
  begin
    Param := Signature.ActualParams[I];

    if Param.CallInfo.ByAddress then
      ParamSize := psByAddress
    else
      ParamSize := Param.ParamType.Size;

    FParameters[I] := TSepiAsmCallParam.Create(MethodCompiler,
      Param.CallInfo.SepiStackOffset, ParamSize, Param.Name);

    if Param.HiddenKind = hpResult then
      FResult := FParameters[I].MemoryRef;
  end;
end;

{*
  Ajoute un param�tre
  @param SepiStackOffset   Offset dans la pile Sepi
  @param ParamSize         Taille de param�tre
*}
function TSepiAsmCallParams.AddParam(SepiStackOffset: Integer;
  ParamSize: TSepiParamSize): TSepiMemoryReference;
var
  Index: Integer;
begin
  Index := Length(FParameters);
  SetLength(FParameters, Index+1);

  FParameters[Index] := TSepiAsmCallParam.Create(MethodCompiler,
    SepiStackOffset, ParamSize);
  Result := FParameters[Index].MemoryRef;
end;

{*
  Construit la liste des param�tres
*}
procedure TSepiAsmCallParams.Make;
var
  I, ParamCount: Integer;
begin
  // Make parameters
  FSize := 0;
  ParamCount := Length(FParameters);
  for I := 0 to ParamCount-1 do
  begin
    FParameters[I].Make;
    Inc(FSize, FParameters[I].Size);
  end;

  // Order parameters following their SepiStackOffset property
  SortParameters;

  // Make result
  Result.Make;
  Inc(FSize, Result.Size);

  // Head bytes
  if ParamCount > MaxParamCountForByteSize then
    Inc(FSize, SizeOf(Byte) + SizeOf(Word))
  else
    Inc(FSize, 2*SizeOf(Byte));
end;

{*
  Ecrit les param�tres dans un flux
  @param Stream   Flux de destination
*}
procedure TSepiAsmCallParams.WriteToStream(Stream: TStream);
var
  I, ParamCount, ParamsSize: Integer;
begin
  // Parameter count

  ParamCount := Length(FParameters);
  Stream.WriteBuffer(ParamCount, SizeOf(Byte));

  // Parameters size

  if ParamCount = 0 then
    ParamsSize := 0
  else
  begin
    with FParameters[ParamCount-1] do
      ParamsSize := SepiStackOffset div 4 + StackUsage;
  end;

  if ParamCount > MaxParamCountForByteSize then
    Stream.WriteBuffer(ParamsSize, SizeOf(Word))
  else
    Stream.WriteBuffer(ParamsSize, SizeOf(Byte));

  // Parameters

  for I := 0 to ParamCount-1 do
    FParameters[I].WriteToStream(Stream);

  // Result

  FResult.WriteToStream(Stream);
end;

{--------------------}
{ TSepiAsmCall class }
{--------------------}

{*
  Cr�e une instruction CALL
  @param AMethodCompiler   Compilateur de m�thode
*}
constructor TSepiAsmCall.Create(AMethodCompiler: TSepiMethodCompiler);
begin
  inherited Create(AMethodCompiler);

  FParameters := TSepiAsmCallParams.Create(MethodCompiler)
end;

{*
  [@inheritDoc]
*}
destructor TSepiAsmCall.Destroy;
begin
  FParameters.Free;

  inherited;
end;

{*
  Pr�pare les param�tres en fonction d'une signature
  @param Signature   Signature
*}
procedure TSepiAsmCall.Prepare(Signature: TSepiSignature);
begin
  Parameters.Prepare(Signature);
end;

{*
  Pr�pare les param�tres en fonction de la signature d'un meta
  @param Meta   M�thode ou type r�f�rence de m�thode
*}
procedure TSepiAsmCall.Prepare(Meta: TSepiMeta);
begin
  if Meta is TSepiMethod then
    Prepare(TSepiMethod(Meta).Signature)
  else if Meta is TSepiMethodRefType then
    Prepare(TSepiMethodRefType(Meta).Signature)
  else
    raise ESepiCompilerError.CreateResFmt(@SObjectMustHaveASignature,
      [Meta.GetFullName]);
end;

{*
  Pr�pare les param�tres en fonction de la signature d'un meta
  @param Signature   Signature
*}
procedure TSepiAsmCall.Prepare(const MetaName: string);
var
  Meta: TSepiMeta;
begin
  Meta := MethodCompiler.SepiMethod.LookFor(MetaName);

  if Meta = nil then
    raise ESepiMetaNotFoundError.CreateResFmt(@SSepiObjectNotFound,
      [MetaName]);

  Prepare(Meta);
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmCall.Make;
begin
  Parameters.Make;
  FSize := SizeOf(TSepiOpCode) + Parameters.Size;
end;

{---------------------------}
{ TSepiAsmAddressCall class }
{---------------------------}

{*
  Cr�e une instruction Basic CALL
  @param AMethodCompiler   Compilateur de m�thode
*}
constructor TSepiAsmAddressCall.Create(AMethodCompiler: TSepiMethodCompiler);
begin
  inherited Create(AMethodCompiler);

  FOpCode := ocAddressCall;

  FCallingConvention := ccRegister;
  FRegUsage := 0;
  FResultBehavior := rbNone;

  FAddress := TSepiMemoryReference.Create(MethodCompiler);
end;

{*
  [@inheritDoc]
*}
destructor TSepiAsmAddressCall.Destroy;
begin
  FAddress.Free;

  inherited;
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmAddressCall.Prepare(Signature: TSepiSignature);
begin
  inherited;

  CallingConvention := Signature.CallingConvention;
  RegUsage := Signature.RegUsage;
  ResultBehavior := Signature.ReturnType.SafeResultBehavior;
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmAddressCall.Make;
begin
  inherited;

  Address.Make;

  Inc(FSize, SizeOf(TSepiCallSettings));
  Inc(FSize, Address.Size);
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmAddressCall.WriteToStream(Stream: TStream);
var
  CallSettings: TSepiCallSettings;
begin
  inherited;

  CallSettings := CallSettingsEncode(CallingConvention, RegUsage,
    ResultBehavior);
  Stream.WriteBuffer(CallSettings, SizeOf(TSepiCallSettings));

  Address.WriteToStream(Stream);
  Parameters.WriteToStream(Stream);
end;

{-----------------------}
{ TSepiAsmRefCall class }
{-----------------------}

{*
  Cr�e une instruction CALL avec une r�f�rence � la m�thode
  @param AMethodCompiler   Compilateur de m�thode
*}
constructor TSepiAsmRefCall.Create(AMethodCompiler: TSepiMethodCompiler);
begin
  inherited Create(AMethodCompiler);

  FMethodRef := 0;
end;

{*
  Renseigne la m�thode � appeler
  @param Method     M�thode � appeler
  @param APrepare   Si True, pr�pare les param�tres
*}
procedure TSepiAsmRefCall.SetMethod(Method: TSepiMethod;
  PrepareParams: Boolean = True);
begin
  FMethodRef := MethodCompiler.UnitCompiler.MakeReference(Method);

  if PrepareParams then
    Prepare(Method.Signature);
end;

{*
  Renseigne la m�thode � appeler
  @param Method     M�thode � appeler
  @param APrepare   Si True, pr�pare les param�tres
*}
procedure TSepiAsmRefCall.SetMethod(const MethodName: string;
  PrepareParams: Boolean = True);
var
  Method: TSepiMethod;
begin
  Method := MethodCompiler.SepiMethod.LookFor(MethodName) as TSepiMethod;

  if Method = nil then
    raise ESepiMetaNotFoundError.CreateResFmt(@SSepiObjectNotFound,
      [MethodName]);

  SetMethod(Method, PrepareParams);
end;

{--------------------------}
{ TSepiAsmStaticCall class }
{--------------------------}

{*
  Cr�e une instruction Static CALL
  @param AMethodCompiler   Compilateur de m�thode
*}
constructor TSepiAsmStaticCall.Create(AMethodCompiler: TSepiMethodCompiler);
begin
  inherited Create(AMethodCompiler);

  FOpCode := ocStaticCall;
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmStaticCall.Make;
begin
  inherited;

  Inc(FSize, SizeOf(Integer));
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmStaticCall.WriteToStream(Stream: TStream);
begin
  inherited;

  Stream.WriteBuffer(FMethodRef, SizeOf(Integer));

  Parameters.WriteToStream(Stream);
end;

{---------------------------}
{ TSepiAsmDynamicCall class }
{---------------------------}

{*
  Cr�e une instruction Dynamic CALL
  @param AMethodCompiler   Compilateur de m�thode
*}
constructor TSepiAsmDynamicCall.Create(AMethodCompiler: TSepiMethodCompiler);
begin
  inherited Create(AMethodCompiler);

  FOpCode := ocDynamicCall;

  FSelfMem := TSepiMemoryReference.Create(MethodCompiler, [aoAcceptZero]);
end;

{*
  [@inheritDoc]
*}
destructor TSepiAsmDynamicCall.Destroy;
begin
  FSelfMem.Free;

  inherited;
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmDynamicCall.Make;
begin
  inherited;

  SelfMem.Make;

  Inc(FSize, SizeOf(Integer));
  Inc(FSize, SelfMem.Size);
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmDynamicCall.WriteToStream(Stream: TStream);
begin
  inherited;

  Stream.WriteBuffer(FMethodRef, SizeOf(Integer));

  SelfMem.WriteToStream(Stream);
  Parameters.WriteToStream(Stream);
end;

{---------------------------}
{ TSepiAsmLoadAddress class }
{---------------------------}

{*
  Cr�e une instruction LEA
  @param AMethodCompiler   Compilateur de m�thode
*}
constructor TSepiAsmLoadAddress.Create(AMethodCompiler: TSepiMethodCompiler);
begin
  inherited Create(AMethodCompiler);

  FOpCode := ocLoadAddress;

  FDestination := TSepiMemoryReference.Create(MethodCompiler);
  FSource := TSepiMemoryReference.Create(MethodCompiler,
    [aoAcceptAddressedConst]);
end;

{*
  [@inheritDoc]
*}
destructor TSepiAsmLoadAddress.Destroy;
begin
  FSource.Free;
  FDestination.Free;

  inherited;
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmLoadAddress.Make;
begin
  inherited;

  Destination.Make;
  Source.Make;

  Inc(FSize, Destination.Size);
  Inc(FSize, Source.Size);
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmLoadAddress.WriteToStream(Stream: TStream);
begin
  inherited;

  Destination.WriteToStream(Stream);
  Source.WriteToStream(Stream);
end;

{--------------------}
{ TSepiAsmMove class }
{--------------------}

{*
  Cr�e une instruction MOVE non typ�e
  @param AMethodCompiler   Compilateur de m�thode
  @param ADataSize          Taille des donn�es � copier
*}
constructor TSepiAsmMove.Create(AMethodCompiler: TSepiMethodCompiler;
  ADataSize: Word);
const
  SmallDataSizeOpCodes: array[1..10] of TSepiOpCode = (
    ocMoveByte, ocMoveWord, ocMoveSome, ocMoveDWord, ocMoveSome,
    ocMoveSome, ocMoveSome, ocMoveQWord, ocMoveSome, ocMoveExt
  );
begin
  if ADataSize = 0 then
    raise ESepiInvalidDataSizeError.CreateRes(@SInvalidDataSize);

  inherited Create(AMethodCompiler);

  FDataSize := ADataSize;
  FDataType := nil;

  case DataSize of
    1..10: FOpCode := SmallDataSizeOpCodes[DataSize];
    11..255: FOpCode := ocMoveSome;
  else
    FOpCode := ocMoveMany;
  end;

  FDestination := TSepiMemoryReference.Create(MethodCompiler);
  if DataSize <= SizeOf(Variant) then
  begin
    FSource := TSepiMemoryReference.Create(MethodCompiler, aoAcceptAllConsts,
      DataSize);
  end else
  begin
    FSource := TSepiMemoryReference.Create(MethodCompiler,
      [aoAcceptAddressedConst]);
  end;
end;

{*
  Cr�e une instruction MOVE typ�e
  @param AMethodCompiler   Compilateur de m�thode
  @param ADataType          Type des donn�es � copier
*}
constructor TSepiAsmMove.Create(AMethodCompiler: TSepiMethodCompiler;
  ADataType: TSepiType);
begin
  if (not ADataType.NeedInit) and
    (CardinalSize(ADataType.Size) <= SizeOf(Word)) then
  begin
    Create(AMethodCompiler, ADataType.Size);
    Exit;
  end;

  inherited Create(AMethodCompiler);

  FDataSize := ADataType.Size;
  FDataType := ADataType;

  case DataType.Kind of
    tkLString: FOpCode := ocMoveAnsiStr;
    tkWString: FOpCode := ocMoveWideStr;
    tkInterface: FOpCode := ocMoveIntf;
    tkVariant: FOpCode := ocMoveVariant;
  else
    FOpCode := ocMoveOther;
  end;

  FDestination := TSepiMemoryReference.Create(MethodCompiler);

  if DataType.Kind in [tkLString, tkWString] then
  begin
    FSource := TSepiMemoryReference.Create(MethodCompiler,
      aoAcceptNonCodeConsts);
  end else if DataType.Kind in [tkInterface, tkVariant] then
    FSource := TSepiMemoryReference.Create(MethodCompiler, [aoAcceptZero])
  else
    FSource := TSepiMemoryReference.Create(MethodCompiler);
end;

{*
  [@inheritDoc]
*}
destructor TSepiAsmMove.Destroy;
begin
  FSource.Free;
  FDestination.Free;

  inherited;
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmMove.Make;
begin
  inherited;

  case OpCode of
    ocMoveSome: Inc(FSize, SizeOf(Byte));
    ocMoveMany: Inc(FSize, SizeOf(Word));
    ocMoveOther: Inc(FSize, SizeOf(Integer));
  end;

  Destination.Make;
  Source.Make;

  Inc(FSize, Destination.Size);
  Inc(FSize, Source.Size);
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmMove.WriteToStream(Stream: TStream);
var
  DataTypeRef: Integer;
begin
  inherited;

  case OpCode of
    ocMoveSome: Stream.WriteBuffer(FDataSize, SizeOf(Byte));
    ocMoveMany: Stream.WriteBuffer(FDataSize, SizeOf(Word));
    ocMoveOther:
    begin
      DataTypeRef := UnitCompiler.MakeReference(DataType);
      Stream.WriteBuffer(DataTypeRef, SizeOf(Integer));
    end;
  end;

  Destination.WriteToStream(Stream);
  Source.WriteToStream(Stream);
end;

{-----------------------}
{ TSepiAsmConvert class }
{-----------------------}

{*
  Cr�e une instruction CVRT
  @param AMethodCompiler   Compilateur de m�thode
  @param AToType            Type de destination
  @param AFromType          Type de la source
*}
constructor TSepiAsmConvert.Create(AMethodCompiler: TSepiMethodCompiler;
  AToType, AFromType: TSepiBaseType);
begin
  inherited Create(AMethodCompiler);

  FOpCode := ocConvert;

  FToType := AToType;
  FFromType := AFromType;

  FDestination := TSepiMemoryReference.Create(MethodCompiler);
  FSource := TSepiMemoryReference.Create(MethodCompiler, aoAcceptAllConsts,
    BaseTypeConstSizes[FromType]);
end;

{*
  [@inheritDoc]
*}
destructor TSepiAsmConvert.Destroy;
begin
  FSource.Free;
  FDestination.Free;

  inherited;
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmConvert.Make;
begin
  inherited;

  Inc(FSize, 2*SizeOf(TSepiBaseType));

  Destination.Make;
  Source.Make;

  Inc(FSize, Destination.Size);
  Inc(FSize, Source.Size);
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmConvert.WriteToStream(Stream: TStream);
begin
  inherited;

  Stream.WriteBuffer(FToType, SizeOf(TSepiBaseType));
  Stream.WriteBuffer(FFromType, SizeOf(TSepiBaseType));

  Destination.WriteToStream(Stream);
  Source.WriteToStream(Stream);
end;

{-------------------------}
{ TSepiAsmOperation class }
{-------------------------}

{*
  Cr�e une instruction op�ration
  @param AMethodCompiler   Compilateur de m�thode
  @param AOpCode            OpCode de l'instruction (de type op�ration)
  @param AVarType           Type des variables
*}
constructor TSepiAsmOperation.Create(AMethodCompiler: TSepiMethodCompiler;
  AOpCode: TSepiOpCode; AVarType: TSepiBaseType);
begin
  if not (AOpCode in OperationsOpCodes) then
    RaiseInvalidOpCode;

  inherited Create(AMethodCompiler);

  FOpCode := AOpCode;

  FVarType := AVarType;
  FUseLeft := False;
  FUseRight := False;

  FDestination := TSepiMemoryReference.Create(MethodCompiler);

  if OpCode in SelfUnaryOps then
  begin
    FLeft := FDestination;
    FRight := FDestination;
  end else if OpCode in SelfBinaryOps then
  begin
    FUseRight := True;

    FLeft := FDestination;

    if OpCode in [ocSelfShl, ocSelfShr] then
    begin
      FRight := TSepiMemoryReference.Create(MethodCompiler,
        aoAcceptAllConsts, 1);
    end else
    begin
      FRight := TSepiMemoryReference.Create(MethodCompiler, aoAcceptAllConsts,
        BaseTypeConstSizes[VarType]);
    end;
  end else if OpCode in OtherUnaryOps then
  begin
    FUseLeft := True;

    FLeft := TSepiMemoryReference.Create(MethodCompiler, aoAcceptAllConsts,
      BaseTypeConstSizes[VarType]);
    FRight := FLeft;
  end else if OpCode in OtherBinaryOps then
  begin
    FUseLeft := True;
    FUseRight := True;

    FLeft := TSepiMemoryReference.Create(MethodCompiler, aoAcceptAllConsts,
      BaseTypeConstSizes[VarType]);

    if OpCode in [ocOtherShl, ocOtherShr] then
    begin
      FRight := TSepiMemoryReference.Create(MethodCompiler,
        aoAcceptAllConsts, 1);
    end else
    begin
      FRight := TSepiMemoryReference.Create(MethodCompiler, aoAcceptAllConsts,
        BaseTypeConstSizes[VarType]);
    end;
  end;
end;

{*
  [@inheritDoc]
*}
destructor TSepiAsmOperation.Destroy;
begin
  FDestination.Free;
  if FUseLeft then
    FLeft.Free;
  if FUseRight then
    FRight.Free;

  inherited;
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmOperation.Make;
begin
  inherited;

  Inc(FSize, SizeOf(TSepiBaseType));

  Destination.Make;
  Inc(FSize, Destination.Size);

  if UseLeft then
  begin
    Left.Make;
    Inc(FSize, Left.Size);
  end;

  if UseRight then
  begin
    Right.Make;
    Inc(FSize, Right.Size);
  end;
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmOperation.WriteToStream(Stream: TStream);
begin
  inherited;

  Stream.WriteBuffer(FVarType, SizeOf(TSepiBaseType));

  Destination.WriteToStream(Stream);
  if UseLeft then
    Left.WriteToStream(Stream);
  if UseRight then
    Right.WriteToStream(Stream);
end;

{-----------------------}
{ TSepiAsmCompare class }
{-----------------------}

{*
  Cr�e une instruction de comparaison
  @param AMethodCompiler   Compilateur de m�thode
  @param AOpCode            OpCode de l'instruction (de type comparaison)
  @param AVarType           Type des variables
*}
constructor TSepiAsmCompare.Create(AMethodCompiler: TSepiMethodCompiler;
  AOpCode: TSepiOpCode; AVarType: TSepiBaseType);
begin
  if not (AOpCode in [ocCompEquals..ocCompGreaterEq]) then
    RaiseInvalidOpCode;

  inherited Create(AMethodCompiler);

  FOpCode := AOpCode;

  FVarType := AVarType;

  FDestination := TSepiMemoryReference.Create(MethodCompiler);
  FLeft := TSepiMemoryReference.Create(MethodCompiler, aoAcceptAllConsts,
    BaseTypeConstSizes[VarType]);
  FRight := TSepiMemoryReference.Create(MethodCompiler, aoAcceptAllConsts,
    BaseTypeConstSizes[VarType]);
end;

{*
  [@inheritDoc]
*}
destructor TSepiAsmCompare.Destroy;
begin
  FDestination.Free;
  FLeft.Free;
  FRight.Free;

  inherited;
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmCompare.Make;
begin
  inherited;

  Inc(FSize, SizeOf(TSepiBaseType));

  Destination.Make;
  Left.Make;
  Right.Make;

  Inc(FSize, Destination.Size);
  Inc(FSize, Left.Size);
  Inc(FSize, Right.Size);
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmCompare.WriteToStream(Stream: TStream);
begin
  inherited;

  Stream.WriteBuffer(FVarType, SizeOf(TSepiBaseType));

  Destination.WriteToStream(Stream);
  Left.WriteToStream(Stream);
  Right.WriteToStream(Stream);
end;

{---------------------------}
{ TSepiAsmGetRunInfo class }
{---------------------------}

{*
  Cr�e une instruction GTI, GDC ou GMC
  @param AMethodCompiler   Compilateur de m�thode
  @param AOpCode            OpCode de l'instruction (GTI, GDC ou GMC)
*}
constructor TSepiAsmGetRunInfo.Create(AMethodCompiler: TSepiMethodCompiler;
  AOpCode: TSepiOpCode);
begin
  if not (AOpCode in [ocGetTypeInfo, ocGetDelphiClass, ocGetMethodCode]) then
    RaiseInvalidOpCode;

  inherited Create(AMethodCompiler);

  FOpCode := AOpCode;

  FDestination := TSepiMemoryReference.Create(MethodCompiler);
  FReference := 0;
end;

{*
  [@inheritDoc]
*}
destructor TSepiAsmGetRunInfo.Destroy;
begin
  FDestination.Free;

  inherited;
end;

{*
  Assigne la r�f�rence
  @param Reference   R�f�rence
*}
procedure TSepiAsmGetRunInfo.SetReference(Reference: TSepiMeta);
begin
  FReference := MethodCompiler.UnitCompiler.MakeReference(Reference);
end;

{*
  Assigne la r�f�rence
  @param RefName   Nom de la r�f�rence
*}
procedure TSepiAsmGetRunInfo.SetReference(const RefName: string);
begin
  SetReference(MethodCompiler.SepiMethod.LookFor(RefName));
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmGetRunInfo.Make;
begin
  inherited;

  Destination.Make;

  Inc(FSize, Destination.Size);
  Inc(FSize, SizeOf(Integer));
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmGetRunInfo.WriteToStream(Stream: TStream);
begin
  inherited;

  Destination.WriteToStream(Stream);
  Stream.WriteBuffer(FReference, SizeOf(Integer));
end;

{-----------------------}
{ TSepiAsmIsClass class }
{-----------------------}

{*
  Cr�e une instruction IS
  @param AMethodCompiler   Compilateur de m�thode
*}
constructor TSepiAsmIsClass.Create(AMethodCompiler: TSepiMethodCompiler);
begin
  inherited Create(AMethodCompiler);

  FOpCode := ocIsClass;

  FDestination := TSepiMemoryReference.Create(MethodCompiler);
  FMemObject := TSepiMemoryReference.Create(MethodCompiler, [aoAcceptZero]);
  FMemClass := TSepiMemoryReference.Create(MethodCompiler, [aoZeroAsNil]);
  FClassRef := 0;
end;

{*
  [@inheritDoc]
*}
destructor TSepiAsmIsClass.Destroy;
begin
  FDestination.Free;
  FMemObject.Free;
  FMemClass.Free;

  inherited;
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmIsClass.Make;
begin
  inherited;

  Destination.Make;
  MemObject.Make;
  MemClass.Make;

  Inc(FSize, Destination.Size);
  Inc(FSize, MemObject.Size);
  Inc(FSize, MemClass.Size);

  if MemClass.Space = msZero then
    Inc(FSize, SizeOf(Integer));
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmIsClass.WriteToStream(Stream: TStream);
begin
  inherited;

  Destination.WriteToStream(Stream);
  MemObject.WriteToStream(Stream);
  MemClass.WriteToStream(Stream);

  if MemClass.Space = msZero then
    Stream.WriteBuffer(FClassRef, SizeOf(Integer));
end;

{-----------------------}
{ TSepiAsmAsClass class }
{-----------------------}

{*
  Cr�e une instruction AS
  @param AMethodCompiler   Compilateur de m�thode
*}
constructor TSepiAsmAsClass.Create(AMethodCompiler: TSepiMethodCompiler);
begin
  inherited Create(AMethodCompiler);

  FOpCode := ocAsClass;

  FMemObject := TSepiMemoryReference.Create(MethodCompiler, [aoAcceptZero]);
  FMemClass := TSepiMemoryReference.Create(MethodCompiler, [aoZeroAsNil]);
  FClassRef := 0;
end;

{*
  [@inheritDoc]
*}
destructor TSepiAsmAsClass.Destroy;
begin
  FMemObject.Free;
  FMemClass.Free;

  inherited;
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmAsClass.Make;
begin
  inherited;

  MemObject.Make;
  MemClass.Make;

  Inc(FSize, MemObject.Size);
  Inc(FSize, MemClass.Size);

  if MemClass.Space = msZero then
    Inc(FSize, SizeOf(Integer));
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmAsClass.WriteToStream(Stream: TStream);
begin
  inherited;

  MemObject.WriteToStream(Stream);
  MemClass.WriteToStream(Stream);

  if MemClass.Space = msZero then
    Stream.WriteBuffer(FClassRef, SizeOf(Integer));
end;

{---------------------}
{ TSepiAsmRaise class }
{---------------------}

{*
  Cr�e une instruction RAISE
  @param AMethodCompiler   Compilateur de m�thode
*}
constructor TSepiAsmRaise.Create(AMethodCompiler: TSepiMethodCompiler);
begin
  inherited Create(AMethodCompiler);

  FOpCode := ocRaise;

  FExceptObject := TSepiMemoryReference.Create(MethodCompiler);
end;

{*
  [@inheritDoc]
*}
destructor TSepiAsmRaise.Destroy;
begin
  FExceptObject.Free;

  inherited;
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmRaise.Make;
begin
  inherited;

  ExceptObject.Make;

  Inc(FSize, ExceptObject.Size);
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmRaise.WriteToStream(Stream: TStream);
begin
  inherited;

  ExceptObject.WriteToStream(Stream);
end;

{-----------------------}
{ TSepiAsmReraise class }
{-----------------------}

{*
  Cr�e une instruction RERS
  @param AMethodCompiler   Compilateur de m�thode
*}
constructor TSepiAsmReraise.Create(AMethodCompiler: TSepiMethodCompiler);
begin
  inherited Create(AMethodCompiler);

  FOpCode := ocReraise;
end;

{-------------------------}
{ TSepiAsmTryExcept class }
{-------------------------}

{*
  Cr�e une instruction TRYE
  @param AOwner   Liste d'instructions propri�taire
*}
constructor TSepiAsmTryExcept.Create(AMethodCompiler: TSepiMethodCompiler);
begin
  inherited Create(AMethodCompiler);

  FOpCode := ocTryExcept;

  FEndOfTry := TSepiJumpDest.Create(MethodCompiler);
  FEndOfExcept := TSepiJumpDest.Create(MethodCompiler);
  FExceptObject := TSepiMemoryReference.Create(MethodCompiler, [aoZeroAsNil]);
end;

{*
  [@inheritDoc]
*}
destructor TSepiAsmTryExcept.Destroy;
begin
  FExceptObject.Free;
  FEndOfExcept.Free;
  FEndOfTry.Free;

  inherited;
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmTryExcept.Make;
begin
  inherited;

  Inc(FSize, 2*SizeOf(Word));

  EndOfTry.Make;
  EndOfExcept.Make;

  ExceptObject.Make;
  Inc(FSize, ExceptObject.Size);
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmTryExcept.WriteToStream(Stream: TStream);
var
  ClauseSize: Integer;
begin
  inherited;

  ClauseSize := EndOfTry.InstructionRef.Position - EndPosition;
  Stream.WriteBuffer(ClauseSize, SizeOf(Word));

  ClauseSize :=
      EndOfExcept.InstructionRef.Position - EndOfTry.InstructionRef.Position;
  Stream.WriteBuffer(ClauseSize, SizeOf(Word));

  ExceptObject.WriteToStream(Stream);
end;

{--------------------------}
{ TSepiAsmTryFinally class }
{--------------------------}

{*
  Cr�e une instruction TRYF
  @param AMethodCompiler   Compilateur de m�thode
*}
constructor TSepiAsmTryFinally.Create(AMethodCompiler: TSepiMethodCompiler);
begin
  inherited Create(AMethodCompiler);

  FOpCode := ocTryFinally;

  FEndOfTry := TSepiJumpDest.Create(MethodCompiler);
  FEndOfFinally := TSepiJumpDest.Create(MethodCompiler);
end;

{*
  [@inheritDoc]
*}
destructor TSepiAsmTryFinally.Destroy;
begin
  FEndOfFinally.Free;
  FEndOfTry.Free;

  inherited;
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmTryFinally.Make;
begin
  inherited;

  Inc(FSize, 2*SizeOf(Word));

  EndOfTry.Make;
  EndOfFinally.Make;
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmTryFinally.WriteToStream(Stream: TStream);
var
  ClauseSize: Integer;
begin
  inherited;

  ClauseSize := EndOfTry.InstructionRef.Position - EndPosition;
  Stream.WriteBuffer(ClauseSize, SizeOf(Word));

  ClauseSize :=
      EndOfFinally.InstructionRef.Position - EndOfTry.InstructionRef.Position;
  Stream.WriteBuffer(ClauseSize, SizeOf(Word));
end;

{-----------------------}
{ TSepiAsmMultiOn class }
{-----------------------}

{*
  Cr�e une instruction ON
  @param AMethodCompiler   Compilateur de m�thode
*}
constructor TSepiAsmMultiOn.Create(AMethodCompiler: TSepiMethodCompiler);
begin
  inherited Create(AMethodCompiler);

  FOpCode := ocMultiOn;

  FExceptObject := TSepiMemoryReference.Create(MethodCompiler);
end;

{*
  [@inheritDoc]
*}
destructor TSepiAsmMultiOn.Destroy;
begin
  FExceptObject.Free;

  inherited;
end;

{*
  Nombre de clauses ON
  @return Nombre de clauses ON
*}
function TSepiAsmMultiOn.GetOnClauseCount: Integer;
begin
  Result := Length(FOnClauses);
end;

{*
  Tableau zero-based des clauses ON
  @param Index   Index d'une clause
  @return Clause � l'index sp�cifi�
*}
function TSepiAsmMultiOn.GetOnClauses(Index: Integer): TSepiAsmOnClause;
begin
  Result := FOnClauses[Index];
end;

{*
  Ajoute une clause ON
  @param AClassRef   R�f�rence � la classe d'exception
  @return Destination du ON
*}
function TSepiAsmMultiOn.AddOnClause(AClassRef: Integer): TSepiJumpDest;
var
  Index: Integer;
begin
  Index := Length(FOnClauses);
  SetLength(FOnClauses, Index+1);

  with FOnClauses[Index] do
  begin
    ClassRef := AClassRef;
    Destination := TSepiJumpDest.Create(MethodCompiler);
    Result := Destination;
  end;
end;

{*
  Ajoute une clause ON
  @param SepiClass   Classe d'exception
  @return Destination du ON
*}
function TSepiAsmMultiOn.AddOnClause(SepiClass: TSepiClass): TSepiJumpDest;
begin
  Result := AddOnClause(
    MethodCompiler.UnitCompiler.MakeReference(SepiClass));
end;

{*
  Ajoute une clause ON
  @param ClassName   Nom de la classe d'exception
  @return Destination du ON
*}
function TSepiAsmMultiOn.AddOnClause(const ClassName: string): TSepiJumpDest;
var
  SepiClass: TSepiClass;
begin
  SepiClass := MethodCompiler.SepiMethod.LookFor(ClassName) as TSepiClass;

  if SepiClass = nil then
    raise ESepiMetaNotFoundError.CreateResFmt(@SSepiObjectNotFound,
      [ClassName]);

  Result := AddOnClause(SepiClass);
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmMultiOn.Make;
var
  I: Integer;
begin
  inherited;

  ExceptObject.Make;

  for I := 0 to Length(FOnClauses)-1 do
    FOnClauses[I].Destination.Make;

  Inc(FSize, ExceptObject.Size + SizeOf(Byte));
  Inc(FSize, Length(FOnClauses) * (SizeOf(Integer)+SizeOf(Smallint)));
end;

{*
  [@inheritDoc]
*}
procedure TSepiAsmMultiOn.WriteToStream(Stream: TStream);
var
  I, Count: Integer;
begin
  inherited;

  ExceptObject.WriteToStream(Stream);

  Count := Length(FOnClauses);
  Stream.WriteBuffer(Count, SizeOf(Byte));

  for I := 0 to Count-1 do
  begin
    with FOnClauses[I] do
    begin
      Stream.WriteBuffer(ClassRef, SizeOf(Integer));
      Destination.WriteToStream(Stream);
    end;
  end;
end;

end.
