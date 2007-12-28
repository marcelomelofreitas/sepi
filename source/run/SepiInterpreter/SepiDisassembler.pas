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
  D�sassembleur Sepi
  @author sjrd
  @version 1.0
*}
unit SepiDisassembler;

interface

uses
  SysUtils, Classes, ScClasses, SepiReflectionCore, SepiMembers, SepiOpCodes,
  SepiRuntime;

type
  {*
    D�sassembleur Sepi
    @author sjrd
    @version 1.0
  *}
  TSepiDisassembler = class(TObject)
  private
    RuntimeUnit: TSepiRuntimeUnit;       /// Unit� d'ex�cution
    Instructions: TAbsoluteMemoryStream; /// Instructions � d�sassembler

    // Op-code functions

    function UnknownOpCode(OpCode: TSepiOpCode): string;

    function OpCodeNope(OpCode: TSepiOpCode): string;
    function OpCodeJump(OpCode: TSepiOpCode): string;
    function OpCodeJumpIf(OpCode: TSepiOpCode): string;

    function OpCodePrepareParams(OpCode: TSepiOpCode): string;
    function OpCodeBasicCall(OpCode: TSepiOpCode): string;
    function OpCodeSignedCall(OpCode: TSepiOpCode): string;
    function OpCodeStatDynaCall(OpCode: TSepiOpCode): string;

    function OpCodeLoadAddress(OpCode: TSepiOpCode): string;
    function OpCodeSimpleMove(OpCode: TSepiOpCode): string;
    function OpCodeMoveFixed(OpCode: TSepiOpCode): string;
    function OpCodeMoveOther(OpCode: TSepiOpCode): string;
    function OpCodeConvert(OpCode: TSepiOpCode): string;

    function OpCodeSelfUnaryOp(OpCode: TSepiOpCode): string;
    function OpCodeSelfBinaryOp(OpCode: TSepiOpCode): string;
    function OpCodeOtherUnaryOp(OpCode: TSepiOpCode): string;
    function OpCodeOtherBinaryOp(OpCode: TSepiOpCode): string;

    function OpCodeCompare(OpCode: TSepiOpCode): string;

    function OpCodeGetRuntimeInfo(OpCode: TSepiOpCode): string;

    function OpCodeIsClass(OpCode: TSepiOpCode): string;
    function OpCodeAsClass(OpCode: TSepiOpCode): string;

    function OpCodeRaise(OpCode: TSepiOpCode): string;
    function OpCodeReraise(OpCode: TSepiOpCode): string;
    function OpCodeTryExcept(OpCode: TSepiOpCode): string;
    function OpCodeTryFinally(OpCode: TSepiOpCode): string;
    function OpCodeMultiOn(OpCode: TSepiOpCode): string;

    // Other methods

    function ReadRef: string;
    function ReadBaseAddress(ConstSize: Integer;
      MemorySpace: TSepiMemorySpace): string;
    procedure ReadAddressOperation(var Address: string);
    function ReadAddress(ConstSize: Integer = 0): string;
    function ReadClassValue: string;
    function ReadJumpDest(out Offset: Integer; out Memory: string;
      AllowAbsolute: Boolean = False): Boolean;

    function DisassembleInstruction: string;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Disassemble(Code: Pointer; Result: TStrings;
      RunUnit: TSepiRuntimeUnit; CodeSize, MaxInstructions: Integer);
  end;

implementation

type
  /// Mn�monique d'un OpCode
  TOpCodeName = string[5];

type
  /// M�thode de traitement d'un OpCode
  TOpCodeArgsFunc = function(Self: TSepiDisassembler;
    OpCode: TSepiOpCode): string;

var
  /// Tableau des m�thodes de traitement des OpCodes
  OpCodeArgsFuncs: array[TSepiOpCode] of TOpCodeArgsFunc;

const
  ConstAsNil = Integer($80000000); /// Constante prise comme nil

const
  MaxKnownOpCode = ocMultiOn; /// Plus grand OpCode connu

  /// Nom des OpCodes
  { Don't localize any of these strings! }
  OpCodeNames: array[ocNope..MaxKnownOpCode] of TOpCodeName = (
    // No category
    'NOP', 'EXT',
    // Flow control
    'JUMP', 'JIT', 'JIF', 'RET', 'JRET',
    // Calls
    'PRPA', 'CALL', 'CALL', 'SCALL', 'DCALL', '', '', '', '',
    // Memory moves
    'LEA', 'MOVB', 'MOVW', 'MOVD', 'MOVQ', 'MOVE', 'MOVAS', 'MOVWS', 'MOVV',
    'MOVI', 'MOVS', 'MOVM', 'MOVO', 'CVRT', '', '',
    // Self dest unary operations
    'INC', 'DEC', 'NOT', 'NEG',
    // Self dest binary operations
    'ADD', 'SUB', 'MUL', 'DIV', 'IDV', 'MOD', 'SHL', 'SHR', 'SAR',
    'AND', 'OR', 'XOR',
    // Other dest unary operations
    'INC', 'DEC', 'NOT', 'NEG',
    // Other dest binary operations
    'ADD', 'SUB', 'MUL', 'DIV', 'IDV', 'MOD', 'SHL', 'SHR', 'SAR',
    'AND', 'OR', 'XOR',
    // Comparisons
    'EQ', 'NEQ', 'LT', 'GT', 'LE', 'GE',
    '', '', '', '', '', '', '', '', '', '',
    // Compile time objects which must be read at runtime in Sepi
    'GTI', 'GDC', 'GMC',
    // is and as operators
    'IS', 'AS', '', '', '', '', '', '', '', '', '', '', '',
    // Exception handling
    'RAISE', 'RERS', 'TRYE', 'TRYF', 'ON'
  );

  /// Virgule
  Comma = ', '; {don't localize}

  /// Nom des conventions d'appel
  CallingConventionNames: array[TCallingConvention] of string = (
    'register', 'cdecl', 'pascal', 'stdcall', 'safecall' {don't localize}
  );

  /// Nom des comportements de r�sultat
  ResultBehaviorNames: array[TSepiTypeResultBehavior] of string = (
    'none', 'ordinal', 'int64', 'single', 'double', 'extended', 'currency',
    'parameter'
  );

  /// Nom des types de donn�es de base de Sepi
  BaseTypeNames: array[TSepiBaseType] of string = (
    'Boolean', 'Byte', 'Word', 'DWord', 'QWord', 'Shortint', 'Smallint',
    'Longint', 'Int64', 'Single', 'Double', 'Extended', 'Comp', 'Currency',
    'AnsiStr', 'WideStr', 'Variant'
  );

{*
  Initialise les OpCodeArgsFuncs
*}
procedure InitOpCodeArgsFuncs;
var
  I: TSepiOpCode;
begin
  for I := $00 to $FF do
    @OpCodeArgsFuncs[I] := @TSepiDisassembler.UnknownOpCode;

  // No category
  @OpCodeArgsFuncs[ocNope]     := @TSepiDisassembler.OpCodeNope;
  @OpCodeArgsFuncs[ocExtended] := @TSepiDisassembler.UnknownOpCode;

  // Flow control
  @OpCodeArgsFuncs[ocJump]          := @TSepiDisassembler.OpCodeJump;
  @OpCodeArgsFuncs[ocJumpIfTrue]    := @TSepiDisassembler.OpCodeJumpIf;
  @OpCodeArgsFuncs[ocJumpIfFalse]   := @TSepiDisassembler.OpCodeJumpIf;
  @OpCodeArgsFuncs[ocReturn]        := @TSepiDisassembler.OpCodeNope;
  @OpCodeArgsFuncs[ocJumpAndReturn] := @TSepiDisassembler.OpCodeJump;

  // Calls
  @OpCodeArgsFuncs[ocPrepareParams] := @TSepiDisassembler.OpCodePrepareParams;
  @OpCodeArgsFuncs[ocBasicCall]     := @TSepiDisassembler.OpCodeBasicCall;
  @OpCodeArgsFuncs[ocSignedCall]    := @TSepiDisassembler.OpCodeSignedCall;
  @OpCodeArgsFuncs[ocStaticCall]    := @TSepiDisassembler.OpCodeStatDynaCall;
  @OpCodeArgsFuncs[ocDynamicCall]   := @TSepiDisassembler.OpCodeStatDynaCall;

  // Memory moves
  @OpCodeArgsFuncs[ocLoadAddress] := @TSepiDisassembler.OpCodeLoadAddress;
  for I := ocMoveByte to ocMoveIntf do
    @OpCodeArgsFuncs[I] := @TSepiDisassembler.OpCodeSimpleMove;
  @OpCodeArgsFuncs[ocMoveSome]  := @TSepiDisassembler.OpCodeMoveFixed;
  @OpCodeArgsFuncs[ocMoveMany]  := @TSepiDisassembler.OpCodeMoveFixed;
  @OpCodeArgsFuncs[ocMoveOther] := @TSepiDisassembler.OpCodeMoveOther;
  @OpCodeArgsFuncs[ocConvert]   := @TSepiDisassembler.OpCodeConvert;

  // Self dest unary operations
  for I := ocSelfInc to ocSelfNeg do
    @OpCodeArgsFuncs[I] := @TSepiDisassembler.OpCodeSelfUnaryOp;

  // Self dest binary operations
  for I := ocSelfAdd to ocSelfXor do
    @OpCodeArgsFuncs[I] := @TSepiDisassembler.OpCodeSelfBinaryOp;

  // Other dest unary operations
  for I := ocOtherInc to ocOtherNeg do
    @OpCodeArgsFuncs[I] := @TSepiDisassembler.OpCodeOtherUnaryOp;

  // Other dest binary operations
  for I := ocOtherAdd to ocOtherXor do
    @OpCodeArgsFuncs[I] := @TSepiDisassembler.OpCodeOtherBinaryOp;

  // Comparisons
  for I := ocCompEquals to ocCompGreaterEq do
    @OpCodeArgsFuncs[I] := @TSepiDisassembler.OpCodeCompare;

  // Compile time objects which must be read at runtime in Sepi
  @OpCodeArgsFuncs[ocGetTypeInfo]    := @TSepiDisassembler.OpCodeGetRuntimeInfo;
  @OpCodeArgsFuncs[ocGetDelphiClass] := @TSepiDisassembler.OpCodeGetRuntimeInfo;
  @OpCodeArgsFuncs[ocGetMethodCode]  := @TSepiDisassembler.OpCodeGetRuntimeInfo;

  // is and as operators
  @OpCodeArgsFuncs[ocIsClass] := @TSepiDisassembler.OpCodeIsClass;
  @OpCodeArgsFuncs[ocAsClass] := @TSepiDisassembler.OpCodeAsClass;

  // Exception handling
  @OpCodeArgsFuncs[ocRaise]      := @TSepiDisassembler.OpCodeRaise;
  @OpCodeArgsFuncs[ocReraise]    := @TSepiDisassembler.OpCodeReraise;
  @OpCodeArgsFuncs[ocTryExcept]  := @TSepiDisassembler.OpCodeTryExcept;
  @OpCodeArgsFuncs[ocTryFinally] := @TSepiDisassembler.OpCodeTryFinally;
  @OpCodeArgsFuncs[ocMultiOn]    := @TSepiDisassembler.OpCodeMultiOn;
end;

{-------------------------}
{ TSepiDisassembler class }
{-------------------------}

{*
  Cr�e un d�sassembleur Sepi
*}
constructor TSepiDisassembler.Create;
begin
  inherited Create;

  Instructions := TAbsoluteMemoryStream.Create;
end;

{*
  [@inheritDoc]
*}
destructor TSepiDisassembler.Destroy;
begin
  Instructions.Free;

  inherited;
end;

{*
  OpCode inconnu
  @param OpCode   OpCode
*}
function TSepiDisassembler.UnknownOpCode(OpCode: TSepiOpCode): string;
begin
  RaiseInvalidOpCode;
  Result := ''; // avoid compiler warning
end;

{*
  OpCode Nope
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeNope(OpCode: TSepiOpCode): string;
begin
  Result := '';
end;

{*
  OpCode Jump
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeJump(OpCode: TSepiOpCode): string;
var
  Offset: Integer;
  Memory: string;
begin
  if ReadJumpDest(Offset, Memory, True) then
    Result := Memory
  else
    Result := '$' + IntToHex(Instructions.Position + Offset, 8);
end;

{*
  OpCode Jump If (True or False)
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeJumpIf(OpCode: TSepiOpCode): string;
var
  IsMemory: Boolean;
  Offset: Integer;
  Memory: string;
  TestPtr: string;
begin
  IsMemory := ReadJumpDest(Offset, Memory, True);
  TestPtr := ReadAddress(SizeOf(Boolean));

  if IsMemory then
    Result := Memory
  else
    Result := '$' + IntToHex(Instructions.Position + Offset, 8);

  Result := Result + Comma + TestPtr;
end;

{*
  OpCode PrepareParams
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodePrepareParams(OpCode: TSepiOpCode): string;
var
  Size: Word;
begin
  Instructions.ReadBuffer(Size, SizeOf(Word));
  Result := IntToStr(Size);
end;

{*
  OpCode BasicCall
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeBasicCall(OpCode: TSepiOpCode): string;
var
  CallSettings: TSepiCallSettings;
  CallingConvention: TCallingConvention;
  RegUsage: Byte;
  ResultBehavior: TSepiTypeResultBehavior;
  AddressPtr: string;
  ResultPtr: string;
begin
  // Read the instruction
  Instructions.ReadBuffer(CallSettings, 1);
  CallSettingsDecode(CallSettings, CallingConvention,
    RegUsage, ResultBehavior);
  AddressPtr := ReadAddress;
  ResultPtr := ReadAddress(ConstAsNil);

  // Format arguments
  if ResultPtr <> '' then
    ResultPtr := Comma + ResultPtr;
  Result := Format('(%s, %d, %s) %s%s', {don't localize}
    [CallingConventionNames[CallingConvention], RegUsage,
    ResultBehaviorNames[ResultBehavior], AddressPtr, ResultPtr]);
end;

{*
  OpCode SignedCall
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeSignedCall(OpCode: TSepiOpCode): string;
var
  Signature: string;
  AddressPtr: string;
  ResultPtr: string;
begin
  // Read the instruction
  Signature := ReadRef;
  AddressPtr := ReadAddress;
  ResultPtr := ReadAddress(ConstAsNil);

  // Format arguments
  if ResultPtr <> '' then
    ResultPtr := Comma + ResultPtr;
  Result := Format('(%s) %s%s', {don't localize}
    [Signature, AddressPtr, ResultPtr]);
end;

{*
  OpCode StaticCall ou DynamicCall
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeStatDynaCall(OpCode: TSepiOpCode): string;
var
  Method: string;
  ResultPtr: string;
begin
  // Read the instruction
  Method := ReadRef;
  ResultPtr := ReadAddress(ConstAsNil);

  // Format arguments
  if ResultPtr <> '' then
    ResultPtr := Comma + ResultPtr;
  Result := Format('%s%s', {don't localize}
    [Method, ResultPtr]);
end;

{*
  OpCode LoadAddress
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeLoadAddress(OpCode: TSepiOpCode): string;
var
  DestPtr: string;
  SourcePtr: string;
begin
  DestPtr := ReadAddress;
  SourcePtr := ReadAddress;

  Result := DestPtr + Comma + SourcePtr;
end;

{*
  OpCode Move
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeSimpleMove(OpCode: TSepiOpCode): string;
const
  ConstSizes: array[ocMoveByte..ocMoveIntf] of Integer = (
    1, 2, 4, 8, 10, 4, 4, 0, 4
  );
var
  DestPtr: string;
  SourcePtr: string;
begin
  DestPtr := ReadAddress;
  SourcePtr := ReadAddress(ConstSizes[OpCode]);

  Result := DestPtr + Comma + SourcePtr;
end;

{*
  OpCode MoveSome et MoveMany
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeMoveFixed(OpCode: TSepiOpCode): string;
var
  Count: Integer;
  DestPtr: string;
  SourcePtr: string;
begin
  // Read count
  Count := 0;
  if OpCode = ocMoveSome then
    Instructions.ReadBuffer(Count, 1)
  else
    Instructions.ReadBuffer(Count, 2);

  // Read dest and source
  DestPtr := ReadAddress;
  SourcePtr := ReadAddress(Count);

  // Format arguments
  Result := Format('%d, %s, %s', {don't localize}
    [Count, DestPtr, SourcePtr]);
end;

{*
  OpCode MoveOther
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeMoveOther(OpCode: TSepiOpCode): string;
var
  VarType: string;
  DestPtr: string;
  SourcePtr: string;
begin
  // Read instruction
  VarType := ReadRef;
  DestPtr := ReadAddress;
  SourcePtr := ReadAddress{(SepiType.Size)};

  // Format arguments
  Result := Format('%s, %s, %s', {don't localize}
    [VarType, DestPtr, SourcePtr]);
end;

{*
  OpCode Convert
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeConvert(OpCode: TSepiOpCode): string;
var
  ToType, FromType: TSepiBaseType;
  DestPtr, SourcePtr: string;
begin
  Instructions.ReadBuffer(ToType, SizeOf(TSepiBaseType));
  Instructions.ReadBuffer(FromType, SizeOf(TSepiBaseType));
  DestPtr := ReadAddress;
  SourcePtr := ReadAddress(BaseTypeConstSizes[FromType]);

  Result := Format('(%s, %s), %s, %s', {don't localize}
    [BaseTypeNames[ToType], BaseTypeNames[FromType], DestPtr, SourcePtr]);
end;

{*
  Op�rations unaires sur soi-m�me
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeSelfUnaryOp(OpCode: TSepiOpCode): string;
var
  VarType: TSepiBaseType;
  VarPtr: string;
begin
  Instructions.ReadBuffer(VarType, SizeOf(TSepiBaseType));
  VarPtr := ReadAddress;

  Result := Format('(%s) %s', {don't localize}
    [BaseTypeNames[VarType], VarPtr]);
end;

{*
  Op�rations binaires sur soi-m�me
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeSelfBinaryOp(OpCode: TSepiOpCode): string;
var
  VarType: TSepiBaseType;
  VarPtr, ValuePtr: string;
begin
  Instructions.ReadBuffer(VarType, SizeOf(TSepiBaseType));
  VarPtr := ReadAddress;
  if OpCode in [ocSelfShl, ocSelfShr, ocSelfSar] then
    ValuePtr := ReadAddress(1)
  else
    ValuePtr := ReadAddress(BaseTypeConstSizes[VarType]);

  Result := Format('(%s) %s, %s', {don't localize}
    [BaseTypeNames[VarType], VarPtr, ValuePtr]);
end;

{*
  Op�rations unaires sur un autre
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeOtherUnaryOp(OpCode: TSepiOpCode): string;
var
  VarType: TSepiBaseType;
  DestPtr, ValuePtr: string;
begin
  Instructions.ReadBuffer(VarType, SizeOf(TSepiBaseType));
  DestPtr := ReadAddress;
  ValuePtr := ReadAddress(BaseTypeConstSizes[VarType]);

  Result := Format('(%s) %s, %s', {don't localize}
    [BaseTypeNames[VarType], DestPtr, ValuePtr]);
end;

{*
  Op�rations binaires sur un autre
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeOtherBinaryOp(OpCode: TSepiOpCode): string;
var
  VarType: TSepiBaseType;
  DestPtr, LeftPtr, RightPtr: string;
begin
  Instructions.ReadBuffer(VarType, SizeOf(TSepiBaseType));
  DestPtr := ReadAddress;
  LeftPtr := ReadAddress(BaseTypeConstSizes[VarType]);
  if OpCode in [ocOtherShl, ocOtherShr, ocOtherSar] then
    RightPtr := ReadAddress(1)
  else
    RightPtr := ReadAddress(BaseTypeConstSizes[VarType]);

  Result := Format('(%s) %s, %s, %s', {don't localize}
    [BaseTypeNames[VarType], DestPtr, LeftPtr, RightPtr]);
end;

{*
  OpCode de comparaison
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeCompare(OpCode: TSepiOpCode): string;
var
  VarType: TSepiBaseType;
  DestPtr, LeftPtr, RightPtr: string;
begin
  Instructions.ReadBuffer(VarType, SizeOf(TSepiBaseType));
  DestPtr := ReadAddress;
  LeftPtr := ReadAddress(BaseTypeConstSizes[VarType]);
  RightPtr := ReadAddress(BaseTypeConstSizes[VarType]);

  Result := Format('(%s) %s, %s, %s', {don't localize}
    [BaseTypeNames[VarType], DestPtr, LeftPtr, RightPtr]);
end;

{*
  OpCode GetTypeInfo, GetDelphiClass ou GetMethodCode
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeGetRuntimeInfo(OpCode: TSepiOpCode): string;
var
  DestPtr: string;
  Reference: string;
begin
  DestPtr := ReadAddress;
  Reference := ReadRef;

  Result := Format('%s, %s', {don't localize}
    [DestPtr, Reference]);
end;

{*
  OpCode IsClass
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeIsClass(OpCode: TSepiOpCode): string;
var
  DestPtr: string;
  ObjectPtr: string;
  DelphiClass: string;
begin
  DestPtr := ReadAddress;
  ObjectPtr := ReadAddress(4);
  DelphiClass := ReadClassValue;

  Result := Format('%s, %s, %s', {don't localize}
    [DestPtr, ObjectPtr, DelphiClass]);
end;

{*
  OpCode AsClass
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeAsClass(OpCode: TSepiOpCode): string;
var
  ObjectPtr: string;
  DelphiClass: string;
begin
  ObjectPtr := ReadAddress(4);
  DelphiClass := ReadClassValue;

  Result := Format('%s, %s', {don't localize}
    [ObjectPtr, DelphiClass]);
end;

{*
  OpCode Raise
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeRaise(OpCode: TSepiOpCode): string;
begin
  Result := ReadAddress;
end;

{*
  OpCode Reraise
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeReraise(OpCode: TSepiOpCode): string;
begin
  Result := '';
end;

{*
  OpCode BeginTryExcept
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeTryExcept(OpCode: TSepiOpCode): string;
var
  Offset: Integer;
  Memory: string;
  ExceptObjectPtr: string;
  ExceptCode: Pointer;
begin
  // Read instruction
  ReadJumpDest(Offset, Memory);
  ExceptObjectPtr := ReadAddress(ConstAsNil);
  ExceptCode := Pointer(Instructions.Position + Offset);

  // Format arguments
  Result := '$'+IntToHex(Cardinal(ExceptCode), 8); {don't localize}
  if ExceptObjectPtr <> '' then
    Result := Result + Comma + ExceptObjectPtr;
end;

{*
  OpCode BeginTryFinally
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeTryFinally(OpCode: TSepiOpCode): string;
var
  Offset: Integer;
  Memory: string;
  FinallyCode: Pointer;
begin
  // Read instruction
  ReadJumpDest(Offset, Memory);
  FinallyCode := Pointer(Instructions.Position + Offset);

  // Format arguments
  Result := '$'+IntToHex(Cardinal(FinallyCode), 8); {don't localize}
end;

{*
  OpCode MultiOn
  @param OpCode   OpCode
*}
function TSepiDisassembler.OpCodeMultiOn(OpCode: TSepiOpCode): string;
const
  OffsetSizes: array[TSepiJumpDestKind] of Integer = (1, 2, 4, 0);
var
  ObjectPtr: string;
  Count: Integer;
  DestKind: TSepiJumpDestKind;
  OffsetSize: Integer;
begin
  // Read object pointer and count
  ObjectPtr := ReadAddress;
  Count := 0;
  Instructions.ReadBuffer(Count, 1);

  // Classes
  Instructions.Seek(4*Count, soFromCurrent);

  // Read offset size
  Instructions.ReadBuffer(DestKind, SizeOf(TSepiJumpDestKind));
  if not (DestKind in [jdkShortint, jdkSmallint, jdkLongint]) then
    RaiseInvalidOpCode;
  OffsetSize := OffsetSizes[DestKind];

  // Dests
  Instructions.Seek(OffsetSize*Count, soFromCurrent);

  // Format arguments
  Result := ObjectPtr;
end;

{*
  Lit une r�f�rence depuis les instructions
*}
function TSepiDisassembler.ReadRef: string;
var
  Meta: TSepiMeta;
  Ref: Integer;
begin
  if Assigned(RuntimeUnit) then
  begin
    RuntimeUnit.ReadRef(Instructions, Meta);
    Result := Meta.GetFullName;
  end else
  begin
    Instructions.ReadBuffer(Ref, 4);
    Result := IntToStr(Ref);
  end;
end;

{*
  Lit une adresse de base depuis les instructions
  @param ConstSize   Taille d'une constante (0 n'accepte pas les constantes)
  @param MemPlace    Espace d'adressage
  @return Adresse de base lue
*}
function TSepiDisassembler.ReadBaseAddress(ConstSize: Integer;
  MemorySpace: TSepiMemorySpace): string;
const // don't localize
  LocalsName = 'LO:';
  ParamsName = 'PA:';
  PreparedParamsName = 'PR:';
  BaseName = '0';
var
  I: Integer;
  ByteOffset: Byte;
  WordOffset: Word;
begin
  // Read base address
  case MemorySpace of
    mpConstant:
    begin
      if ConstSize = ConstAsNil then
      begin
        // Treat constant as nil return value
        Result := '';
      end else
      begin
        // Read the constant directly into the code
        if ConstSize <= 0 then
          RaiseInvalidOpCode;

        Result := '$'; {don't localize}
        for I := 0 to ConstSize-1 do
        begin
          Instructions.ReadBuffer(ByteOffset, 1);
          Result := Result + IntToHex(ByteOffset, 2);
        end;
      end;
    end;
    mpLocalsBase:
    begin
      // Local variables, no offset
      Result := LocalsName + BaseName;
    end;
    mpLocalsByte:
    begin
      // Local variables, byte-offset
      Instructions.ReadBuffer(ByteOffset, 1);
      Result := LocalsName + IntToStr(ByteOffset);
    end;
    mpLocalsWord:
    begin
      // Local variables, word-offset
      Instructions.ReadBuffer(WordOffset, 2);
      Result := LocalsName + IntToStr(WordOffset);
    end;
    mpParamsBase:
    begin
      // Parameters, no offset
      Result := ParamsName + BaseName;
    end;
    mpParamsByte:
    begin
      // Parameters, byte-offset
      Instructions.ReadBuffer(ByteOffset, 1);
      Result := ParamsName + IntToStr(ByteOffset);
    end;
    mpParamsWord:
    begin
      // Parameters, word-offset
      Instructions.ReadBuffer(WordOffset, 2);
      Result := ParamsName + IntToStr(WordOffset);
    end;
    mpPreparedParamsBase:
    begin
      // Prepared params, no offset
      Result := PreparedParamsName + BaseName;
    end;
    mpPreparedParamsByte:
    begin
      // Prepared params, byte-offset
      Instructions.ReadBuffer(ByteOffset, 1);
      Result := PreparedParamsName + IntToStr(ByteOffset);
    end;
    mpPreparedParamsWord:
    begin
      // Prepared params, word-offset
      Instructions.ReadBuffer(WordOffset, 2);
      Result := PreparedParamsName + IntToStr(WordOffset);
    end;
    mpGlobalConst:
    begin
      // Reference to TSepiConstant
      if ConstSize <= 0 then
        RaiseInvalidOpCode;
      Result := ReadRef;
    end;
    mpGlobalVar:
    begin
      // Reference to TSepiVariable
      Result := ReadRef;
    end;
  else
    RaiseInvalidOpCode;
    Result := ''; // avoid compiler warning
  end;
end;

{*
  Lit une op�ration sur une adresse et l'applique � une adresse donn�e
  @param Address   Adresse � modifier
*}
procedure TSepiDisassembler.ReadAddressOperation(var Address: string);
var
  IntAddress: Integer absolute Address;
  AddrDerefAndOp: TSepiAddressDerefAndOp;
  AddrDereference: TSepiAddressDereference;
  AddrOperation: TSepiAddressOperation;
  ShortOffset: Shortint;
  SmallOffset: Smallint;
  LongOffset: Longint;
  OffsetPtr: string;
  ShortFactor: Shortint;
begin
  // Read deref and op
  Instructions.ReadBuffer(AddrDerefAndOp, SizeOf(TSepiAddressDerefAndOp));
  AddressDerefAndOpDecode(AddrDerefAndOp, AddrDereference, AddrOperation);

  // Handle dereference
  case AddrDereference of
    adNone: ;
    adSimple: Address := '('+Address+')^';  {don't localize}
    adDouble: Address := '('+Address+')^^'; {don't localize}
  else
    RaiseInvalidOpCode;
  end;

  // Handle operation
  case AddrOperation of
    aoNone: ;
    aoPlusConstShortint:
    begin
      // Read a Shortint from code, and add it to the address
      Instructions.ReadBuffer(ShortOffset, 1);
      Address := Address + '+' + IntToStr(ShortOffset);
    end;
    aoPlusConstSmallint:
    begin
      // Read a Smallint from code, and add it to the address
      Instructions.ReadBuffer(SmallOffset, 1);
      Address := Address + '+' + IntToStr(SmallOffset);
    end;
    aoPlusConstLongint:
    begin
      // Read a Longint from code, and add it to the address
      Instructions.ReadBuffer(LongOffset, 1);
      Address := Address + '+' + IntToStr(LongOffset);
    end;
    aoPlusMemShortint:
    begin
      // Read a Shortint from memory, and add it to the address
      OffsetPtr := ReadAddress(SizeOf(Shortint));
      Address := Address + '+(' + OffsetPtr + ')';
    end;
    aoPlusMemSmallint:
    begin
      // Read a Smallint from memory, and add it to the address
      OffsetPtr := ReadAddress(SizeOf(Smallint));
      Address := Address + '+(' + OffsetPtr + ')';
    end;
    aoPlusMemLongint:
    begin
      // Read a Longint from memory, and add it to the address
      OffsetPtr := ReadAddress(SizeOf(Longint));
      Address := Address + '+(' + OffsetPtr + ')';
    end;
    aoPlusConstTimesMemShortint:
    begin
      { Read a Shortint from code and a Shortint from memory. Then, multiply
        them and add the result to the address. }
      Instructions.ReadBuffer(ShortFactor, 1);
      OffsetPtr := ReadAddress(SizeOf(Shortint));
      Address := Address + '+' + IntToStr(ShortFactor) + '*(' + OffsetPtr + ')';
    end;
    aoPlusConstTimesMemSmallint:
    begin
      { Read a Shortint from code and a Smallint from memory. Then, multiply
        them and add the result to the address. }
      Instructions.ReadBuffer(ShortFactor, 1);
      OffsetPtr := ReadAddress(SizeOf(Smallint));
      Address := Address + '+' + IntToStr(ShortFactor) + '*(' + OffsetPtr + ')';
    end;
    aoPlusConstTimesMemLongint:
    begin
      { Read a Shortint from code and a Longint from memory. Then, multiply
        them and add the result to the address. }
      Instructions.ReadBuffer(ShortFactor, 1);
      OffsetPtr := ReadAddress(SizeOf(Longint));
      Address := Address + '+' + IntToStr(ShortFactor) + '*(' + OffsetPtr + ')';
    end;
  else
    RaiseInvalidOpCode;
  end;
end;

{*
  Lit l'adresse d'une zone m�moire depuis le flux d'instructions
  @param ConstSize   Taille d'une constante (0 n'accepte pas les constantes)
*}
function TSepiDisassembler.ReadAddress(ConstSize: Integer = 0): string;
var
  MemoryRef: TSepiMemoryRef;
  MemorySpace: TSepiMemorySpace;
  OpCount: Integer;
  I: Integer;
begin
  // Read memory reference
  Instructions.ReadBuffer(MemoryRef, SizeOf(TSepiMemoryRef));
  MemoryRefDecode(MemoryRef, MemorySpace, OpCount);

  // Read base address
  Result := ReadBaseAddress(ConstSize, MemorySpace);

  // Check for nil result
  if Result = '' then
  begin
    if OpCount <> 0 then
      RaiseInvalidOpCode;
    Exit;
  end;

  // Handle operations
  for I := 0 to OpCount-1 do
    ReadAddressOperation(Result);
end;

{*
  Lit une valeur de type classe (TClass)
  @return Classe lue
*}
function TSepiDisassembler.ReadClassValue: string;
begin
  Result := ReadAddress(ConstAsNil);

  if Result = '' then
    Result := ReadRef;
end;

{*
  Lit une destination de Jump
  @param Offset          En sortie : valeur de d�placement si relatif
  @param Memory          En sortie : adresse m�moire si absolue
  @param AllowAbsolute   True autorise une adresse de code absolue
  @return True si c'est une adresse absolue, False si c'est une relative
*}
function TSepiDisassembler.ReadJumpDest(out Offset: Integer;
  out Memory: string; AllowAbsolute: Boolean = False): Boolean;
var
  DestKind: TSepiJumpDestKind;
  ShortintOffset: Shortint;
  SmallintOffset: Smallint;
begin
  Instructions.ReadBuffer(DestKind, SizeOf(TSepiJumpDestKind));

  case DestKind of
    jdkShortint:
    begin
      Instructions.ReadBuffer(ShortintOffset, 1);
      Offset := ShortintOffset;
      Result := False;
    end;
    jdkSmallint:
    begin
      Instructions.ReadBuffer(SmallintOffset, 2);
      Offset := SmallintOffset;
      Result := False;
    end;
    jdkLongint:
    begin
      Instructions.ReadBuffer(Offset, 4);
      Result := False;
    end;
    jdkMemory:
    begin
      if not AllowAbsolute then
        RaiseInvalidOpCode;
      Memory := ReadAddress(SizeOf(Pointer));
      Result := True;
    end;
  else
    RaiseInvalidOpCode;
    Result := False; // avoid compiler warning
  end;
end;

{*
  D�sassemble une instruction
*}
function TSepiDisassembler.DisassembleInstruction: string;
var
  OpCode: TSepiOpCode;
  Name, Args: string;
begin
  // Read OpCode
  Instructions.ReadBuffer(OpCode, SizeOf(TSepiOpCode));

  // Get arguments and name
  Args := OpCodeArgsFuncs[OpCode](Self, OpCode);
  Name := OpCodeNames[OpCode];

  // Format result
  if Args = '' then
    Result := Name
  else
    Result := Format('%-8s%s', [Name, Args]); {don't localize}
end;

{*
  D�sassemble un code
  Vous pouvez passer 0 comme param�tre CodeSize (resp. MaxInstructions) pour
  lever la limitation de taille de code (resp. de nombre d'instructions).
  En sortie, la liste de cha�nes Result a une entr�e suppl�mentaire pour chaque
  instruction d�sassembl�e : la cha�ne est une version textuelle de
  l'instructions, l'objet est l'adresse de d�but de l'instruction.
  @param Code              Pointeur sur le code � d�sassembler
  @param Result            Liste de cha�nes o� stocker le r�sultat
  @param RunUnit           Unit� d'ex�cution
  @param CodeSize          Taille maximum du code � d�sassembler
  @param MaxInstructions   Nombre maximum d'instructions � d�sassembler
*}
procedure TSepiDisassembler.Disassemble(Code: Pointer; Result: TStrings;
  RunUnit: TSepiRuntimeUnit; CodeSize, MaxInstructions: Integer);
var
  MaxCode: Pointer;
  InstructionPos: Pointer;
begin
  // Read parameters
  if CodeSize <= 0 then
    MaxCode := Pointer($FFFFFFFF)
  else
    MaxCode := Pointer(Integer(Code) + CodeSize);

  if MaxInstructions <= 0 then
    MaxInstructions := MaxInt;

  RuntimeUnit := RunUnit;
  Instructions.PointerPos := Code;

  // Disassemble
  try
    while (Cardinal(Instructions.PointerPos) < Cardinal(MaxCode)) and
      (MaxInstructions > 0) do
    begin
      InstructionPos := Instructions.PointerPos;
      Result.AddObject(DisassembleInstruction, TObject(InstructionPos));
    end;
  except
    on Error: ESepiInvalidOpCode do;
  end;
end;

initialization
  InitOpCodeArgsFuncs;
end.
