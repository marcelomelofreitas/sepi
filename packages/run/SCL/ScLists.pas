unit ScLists;

interface

uses
  SysUtils, Classes;

type
  {*
    Exception d�clench�e lors d'une erreur de liste d'entiers
  *}
  EIntListError = class(EListError);

  {*
    Rend publique la m�thode CompareStrings afin de pouvoir l'utiliser pour
    comparer deux cha�nes en respectant les r�gles de comparaison d'une liste.
    Cette classe ne doit pas �tre utilis�e dans une autre optique.
  *}
  TCompareStrings = class(TStrings)
  public
    function CompareStrings(const S1, S2 : string) : integer; override;
  end;

  {*
    Propose une s�rie de m�thodes pouvant �tre appliqu�e � des instances de
    TStrings (toutes les m�thodes de recherche respectent les r�gles de
    comparaison de la liste concern�e)
  *}
  StringsOps = class
  public
    class function IndexOf(Strings : TStrings; const Str : string;
      BeginSearchAt : integer = 0; EndSearchAt : integer = -1) : integer;

    class function FindText(Strings : TStrings; const Str : string;
      BeginSearchAt : integer = 0; EndSearchAt : integer = -1) : integer;
    class function FindFirstWord(Strings : TStrings; const Word : string;
      BeginSearchAt : integer = 0; EndSearchAt : integer = -1) : integer;
    class function FindAtPos(Strings : TStrings; const SubStr : string;
      Position : integer = 1; BeginSearchAt : integer = 0;
      EndSearchAt : integer = -1) : integer;

    class procedure CopyFrom(Strings : TStrings; Source : TStrings;
      Index : integer = 0; Count : integer = -1);
    class procedure AddFrom(Strings : TStrings; Source : TStrings;
      Index : integer = 0; Count : integer = -1);

    class procedure FromString(Strings : TStrings; const Str, Delim : string;
      const NotIn : string = '');
    class procedure AddFromString(Strings : TStrings; const Str, Delim : string;
      const NotIn : string = '');
  end;

  {*
    Am�lioration de TStringList pour lui ajouter les m�thodes de StringsOps
    ainsi qu'un index interne permettant de parcourir ais�ment toutes les
    cha�nes dans l'ordre
  *}
  TScStrings = class(TStringList)
  private
    FIndex : integer; /// Index interne

    function GetHasMoreString : boolean;
    procedure SetIndex(New : integer);
  public
    constructor Create;
    constructor CreateFromFile(const FileName : TFileName);
    constructor CreateFromString(const Str, Delim : string;
      const NotIn : string = '');
    constructor CreateAssign(Source : TPersistent);

    function IndexOfEx(const Str : string; BeginSearchAt : integer = 0;
      EndSearchAt : integer = -1) : integer;

    function FindText(const Str : string; BeginSearchAt : integer = 0;
      EndSearchAt : integer = -1) : integer;
    function FindFirstWord(const Word : string; BeginSearchAt : integer = 0;
      EndSearchAt : integer = -1) : integer;
    function FindAtPos(const SubStr : string; Position : integer = 1;
      BeginSearchAt : integer = 0; EndSearchAt : integer = -1) : integer;

    procedure CopyFrom(Source : TStrings; Index : integer = 0;
      Count : integer = -1);
    procedure AddFrom(Source : TStrings; Index : integer = 0;
      Count : integer = -1);

    procedure FromString(const Str, Delim : string;
      const NotIn : string = '');
    procedure AddFromString(const Str, Delim : string;
      const NotIn : string = '');

    procedure Reset;
    function NextString : string;

    property HasMoreString : boolean read GetHasMoreString;
    property Index : integer read FIndex write SetIndex;
  end;

  TScList = class;
  TScListClass = class of TScList;

  {*
    Classe de base pour les listes dont les �l�ments sont de taille homog�ne
    Ne cr�ez pas d'instance de TScList, mais cr�ez plut�t des instances de
    ses classes descendantes.
    Ne pas utiliser pour des listes de cha�nes, de pointeurs ou d'objets ;
    dans ces cas, utiliser respectivement TStringList (unit� Classes), TList
    (unit� Classes) et TObjectList (unit� Contnrs).
  *}
  TScList = class(TPersistent)
  private
    FStream : TMemoryStream;
    FItemSize : integer;

    function GetCount : integer;
    procedure SetCount(New : integer);
    function GetHasMoreValue : boolean;
    function GetIndex : integer;
    procedure SetIndex(New : integer);
  protected
    procedure DefineProperties(Filer : TFiler); override;

    procedure AssignTo(Dest : TPersistent); override;

    // Renvoie True si ScListClass est une classe d'assignation
    function IsAssignClass(ScListClass : TScListClass) : boolean; virtual;

    // Les m�thodes suivantes doivent �tre appell�es par les m�thodes de m�me
    // nom (sans le _) des descendants
    procedure _Read(var Buffer);
    procedure _Write(var Buffer);
    procedure _GetItems(AIndex : integer; var Buffer);
    procedure _SetItems(AIndex : integer; var Buffer);
    function _Add(var Buffer) : integer;
    function _Insert(AIndex : integer; var Buffer) : integer;
    procedure _Delete(AIndex : integer; var Buffer);

    property ItemSize : integer read FItemSize;
  public
    constructor Create(ItemSize : integer);
    destructor Destroy; override;

    procedure Assign(Source : TPersistent); override;
    procedure Clear;
    procedure Reset;

    procedure LoadFromStream(Stream : TStream);
    procedure SaveToStream(Stream : TStream);
    procedure LoadFromFile(const FileName : TFileName);
    procedure SaveToFile(const FileName : TFileName);

    property Count : integer read GetCount write SetCount;
    property HasMoreValue : boolean read GetHasMoreValue;
    property Index : integer read GetIndex write SetIndex;
  end;

  {*
    G�re une liste d'entiers sign�s
  *}
  TIntegerList = class(TScList)
  private
    function GetItems(Index : integer) : Int64;
    procedure SetItems(Index : integer; New : Int64);
    procedure MakeItGood(var Value : Int64);
  protected
    procedure AssignTo(Dest : TPersistent); override;

    function IsAssignClass(ScListClass : TScListClass) : boolean; override;
  public
    constructor Create(IntSize : integer = 4);
    constructor CreateAssign(Source : TPersistent; IntSize : integer = 4);

    procedure Assign(Source : TPersistent); override;

    function Read : Int64;
    procedure Write(New : Int64);
    function Add(New : Int64) : integer;
    function Insert(Index : integer; New : Int64) : integer;
    function Delete(Index : integer) : Int64;

    property Items[index : integer] : Int64 read GetItems write SetItems; default;
  end;

  {*
    G�re une liste d'entiers non sign�s
  *}
  TUnsignedIntList = class(TScList)
  private
    function GetItems(Index : integer) : LongWord;
    procedure SetItems(Index : integer; New : LongWord);
    procedure MakeItGood(var Value : LongWord);
  protected
    procedure AssignTo(Dest : TPersistent); override;

    function IsAssignClass(ScListClass : TScListClass) : boolean; override;
  public
    constructor Create(IntSize : integer = 4);
    constructor CreateAssign(Source : TPersistent; IntSize : integer = 4);

    procedure Assign(Source : TPersistent); override;

    function Read : LongWord;
    procedure Write(New : LongWord);
    function Add(New : LongWord) : integer;
    function Insert(Index : integer; New : LongWord) : integer;
    function Delete(Index : integer) : LongWord;

    property Items[index : integer] : LongWord read GetItems write SetItems; default;
  end;

  {*
    G�re une liste de Extended
  *}
  TExtendedList = class(TScList)
  private
    function GetItems(Index : integer) : Extended;
    procedure SetItems(Index : integer; New : Extended);
  protected
    procedure AssignTo(Dest : TPersistent); override;

    function IsAssignClass(ScListClass : TScListClass) : boolean; override;
  public
    constructor Create;
    constructor CreateAssign(Source : TPersistent);

    procedure Assign(Source : TPersistent); override;

    function Read : Extended;
    procedure Write(New : Extended);
    function Add(New : Extended) : integer;
    function Insert(Index : integer; New : Extended) : integer;
    function Delete(Index : integer) : Extended;

    property Items[index : integer] : Extended read GetItems write SetItems; default;
  end;

var
  AppParams : TScStrings; /// Liste des param�tres envoy�s � l'application

implementation

uses
  ScUtils, ScStrUtils, ScConsts;

//////////////////////////////
/// Classe TCompareStrings ///
//////////////////////////////

{*
  Compare deux cha�nes de caract�res
  @param S1   Premi�re cha�ne de caract�res
  @param S2   Seconde cha�ne de caract�res
  @return 0 si les cha�nes sont �quivalente, un nombre positif si la premi�re
          est sup�rieure � la seconde, un nombre n�gatif dans le cas inverse
*}
function TCompareStrings.CompareStrings(const S1, S2 : string) : integer;
begin
  Result := (inherited CompareStrings(S1, S2));
end;

{$REGION 'Classe StringsOps'}

/////////////////////////
/// Classe StringsOps ///
/////////////////////////

{*
  Recherche une cha�ne dans une liste de cha�nes
  Recherche une cha�ne dans une liste de cha�nes, en d�butant et s'arr�tant �
  des index sp�cifi�s.
  @param Strings         Liste de cha�nes concern�e
  @param Str             Cha�ne � rechercher
  @param BeginSearchAt   Index � partir duquel chercher
  @param EndSearchAt     Index jusqu'auquel chercher (jusqu'� la fin si -1)
  @return Index de la premi�re cha�ne correspondant � Str, ou -1 si non trouv�e
*}
class function StringsOps.IndexOf(Strings : TStrings; const Str : string;
  BeginSearchAt : integer = 0; EndSearchAt : integer = -1) : integer;
begin
  with TCompareStrings(Strings) do
  begin
    // On s'assure que BeginSearchAt et EndSearchAt sont des entr�es correctes
    if BeginSearchAt < 0 then BeginSearchAt := 0;
    if (EndSearchAt < 0) or (EndSearchAt >= Count) then EndSearchAt := Count-1;

    Result := BeginSearchAt;
    while Result <= EndSearchAt do
    begin
      if CompareStrings(Str, Strings[BeginSearchAt]) = 0 then exit else
        inc(BeginSearchAt);
    end;
    Result := -1;
  end;
end;

{*
  Recherche un texte � l'int�rieur des cha�nes d'une liste
  Recherche un texte � l'int�rieur des cha�nes d'une liste, en d�butant et
  s'arr�tant � des index sp�cifi�s.
  @param Strings         Liste de cha�nes concern�e
  @param Str             Texte � rechercher
  @param BeginSearchAt   Index � partir duquel chercher
  @param EndSearchAt     Index jusqu'auquel chercher (jusqu'� la fin si -1)
  @return Index de la premi�re cha�ne contenant Str, ou -1 si non trouv�e
*}
class function StringsOps.FindText(Strings : TStrings; const Str : string;
  BeginSearchAt : integer = 0; EndSearchAt : integer = -1) : integer;
var I, Len : integer;
begin
  with TCompareStrings(Strings) do
  begin
    // On s'assure que BeginSearchAt et EndSearchAt sont des entr�es correctes
    if BeginSearchAt < 0 then BeginSearchAt := 0;
    if (EndSearchAt < 0) or (EndSearchAt >= Count) then EndSearchAt := Count-1;

    Len := Length(Str);
    Result := BeginSearchAt;
    while Result <= EndSearchAt do
    begin
      for I := Length(Strings[Result])-Len+1 downto 1 do
        if CompareStrings(Str, Copy(Strings[Result], I, Len)) = 0 then exit;
      inc(Result);
    end;
    Result := -1;
  end;
end;

{*
  Recherche un mot en premi�re position d'une cha�ne d'une liste
  Recherche un mot plac� en premi�re position d'une cha�ne d'une liste (des
  espaces peuvent se trouver devant), en d�butant et s'arr�tant � des index
  sp�cifi�s.
  @param Strings         Liste de cha�nes concern�e
  @param Word            Mot � rechercher
  @param BeginSearchAt   Index � partir duquel chercher
  @param EndSearchAt     Index jusqu'auquel chercher (jusqu'� la fin si -1)
  @return Index de la premi�re cha�ne contenant Word, ou -1 si non trouv�e
*}
class function StringsOps.FindFirstWord(Strings : TStrings; const Word : string;
  BeginSearchAt : integer = 0; EndSearchAt : integer = -1) : integer;
begin
  with TCompareStrings(Strings) do
  begin
    // On s'assure que BeginSearchAt et EndSearchAt sont des entr�es correctes
    if BeginSearchAt < 0 then BeginSearchAt := 0;
    if (EndSearchAt < 0) or (EndSearchAt >= Count) then EndSearchAt := Count-1;

    Result := BeginSearchAt;
    while Result <= EndSearchAt do
    begin
      if CompareStrings(Word, GetXWord(Trim(Strings[Result]), 1)) = 0 then
        exit
      else
        inc(Result);
    end;
    Result := -1;
  end;
end;

{*
  Recherche une sous-cha�ne � une position sp�cifi�e les cha�nes d'une liste
  Recherche une sous-cha�ne d�butant � une position sp�cifi�e dans les cha�nes
  d'une liste, en d�butant et s'arr�tant � des index sp�cifi�s.
  @param Strings         Liste de cha�nes concern�e
  @param SubStr          Sous-cha�ne � rechercher
  @param Position        Position dans les cha�nes o� chercher la sous-cha�ne
  @param BeginSearchAt   Index � partir duquel chercher
  @param EndSearchAt     Index jusqu'auquel chercher (jusqu'� la fin si -1)
  @return Index de la premi�re cha�ne contenant Word, ou -1 si non trouv�e
*}
class function StringsOps.FindAtPos(Strings : TStrings; const SubStr : string;
  Position : integer = 1; BeginSearchAt : integer = 0;
  EndSearchAt : integer = -1) : integer;
var Len : integer;
begin
  with TCompareStrings(Strings) do
  begin
    // On s'assure que BeginSearchAt et EndSearchAt sont des entr�es correctes
    if BeginSearchAt < 0 then BeginSearchAt := 0;
    if (EndSearchAt < 0) or (EndSearchAt >= Count) then EndSearchAt := Count-1;

    Len := Length(SubStr);
    Result := BeginSearchAt;
    while Result <= EndSearchAt do
    begin
      if CompareStrings(SubStr, Copy(Strings[Result], Position, Len)) = 0 then
        exit
      else
        inc(Result);
    end;
    Result := -1;
  end;
end;

{*
  Remplit une liste de cha�nes avec des cha�nes d'une autre liste
  Remplit une liste de cha�nes avec les cha�nes d'une autre liste depuis un
  index et sur un nombre sp�cifi�s.
  @param Strings   Liste de cha�nes concern�e
  @param Source    Liste de cha�nes � partir de laquelle recopier les cha�nes
  @param Index     Index o� commencer la copie
  @param Count     Nombre de cha�nes � copier
*}
class procedure StringsOps.CopyFrom(Strings : TStrings; Source : TStrings;
  Index : integer = 0; Count : integer = -1);
begin
  Strings.Clear;
  AddFrom(Strings, Source, Index, Count);
end;

{*
  Ajoute � une liste de cha�nes des cha�nes d'une autre liste
  Ajoute � une liste de cha�nes les cha�nes d'une autre liste depuis un index et
  sur un nombre sp�cifi�s.
  @param Strings   Liste de cha�nes concern�e
  @param Source    Liste de cha�nes � partir de laquelle recopier les cha�nes
  @param Index     Index o� commencer la copie
  @param Count     Nombre de cha�nes � copier
*}
class procedure StringsOps.AddFrom(Strings : TStrings; Source : TStrings;
  Index : integer = 0; Count : integer = -1);
var I, EndAt : integer;
begin
  // On s'assure que Index et Count sont des entr�es correctes
  if Index < 0 then exit;
  if (Count < 0) or (Index+Count > Source.Count) then
    EndAt := Source.Count-1
  else
    EndAt := Index+Count-1;

  // On recopie les cha�nes
  for I := Index to EndAt do
    Strings.Append(Source[I]);
end;

{*
  D�coupe une cha�ne en sous-cha�nes et remplit une liste de ces sous-cha�nes
  D�coupe une cha�ne en sous-cha�nes d�limit�es par des caract�res sp�cifi�s, et
  remplit une liste de cha�nes avec ces sous-cha�nes.
  @param Strings   Liste de cha�nes dans laquelle copier les sous-cha�nes
  @param Str       Cha�ne � d�couper
  @param Delim     Caract�res qui d�limitent deux sous-cha�nes
  @param NotIn     Paires de caract�res �chappant les d�limiteurs
  @raise EListError NotIn contient un nombre impair de caract�res
  @raise EListError Delim et NotIn contiennent un m�me caract�re
*}
class procedure StringsOps.FromString(Strings : TStrings;
  const Str, Delim : string; const NotIn : string = '');
begin
  Strings.Clear;
  AddFromString(Strings, Str, Delim, NotIn);
end;

{*
  D�coupe une cha�ne en sous-cha�nes et ajoute ces sous-cha�nes � une liste
  D�coupe une cha�ne en sous-cha�nes d�limit�es par des caract�res sp�cifi�s, et
  ajoute ces sous-cha�nes � une liste de cha�nes.
  @param Strings   Liste de cha�nes � laquelle ajouter les sous-cha�nes
  @param Str       Cha�ne � d�couper
  @param Delim     Caract�res qui d�limitent deux sous-cha�nes
  @param NotIn     Paires de caract�res �chappant les d�limiteurs
  @raise EListError NotIn contient un nombre impair de caract�res
  @raise EListError Delim et NotIn contiennent un m�me caract�re
*}
class procedure StringsOps.AddFromString(Strings : TStrings;
  const Str, Delim : string; const NotIn : string = '');
var I, J, Len : integer;
    NotIn1, NotIn2 : string;
    C : Char;
begin
  with Strings do
  begin
    // On v�rifie que NotIn contient un nombre pair de caract�res
    if Odd(Length(NotIn)) then
      raise EListError.Create(sScNotInMustPairsOfChars);

    // On v�rifie qu'il n'y a pas d'interf�rence entre Delim et NotIn
    for I := 1 to Length(NotIn) do if Pos(NotIn[I], Delim) > 0 then
      raise EListError.Create(sScDelimMustDifferentThanNotIn);

    // S�paration de NotIn en NotIn1 et NotIn2
    NotIn1 := '';
    NotIn2 := '';
    for I := 1 to Length(NotIn) do if (I mod 2) = 1 then
      NotIn1 := NotIn1+NotIn[I] else NotIn2 := NotIn2+NotIn[I];

    Len := Length(Str);

    I := 1;
    while True do
    begin
      // On boucle jusqu'� trouver un caract�re qui n'est pas dans Delim
      // On ignore de ce fait plusieurs caract�res de Delim � la suite
      while (I <= Len) and (Pos(Str[I], Delim) <> 0) do inc(I);
      if (I > Len) then Break;

      // On recherche le caract�re de Delim suivant
      J := I;
      while (J <= Len) and (Pos(Str[J], Delim) = 0) do
      begin
        // Si on trouve un caract�re de NotIn1, on boucle jusqu'� trouver le
        // caract�re correspondant de NotIn2
        if Pos(Str[J], NotIn1) > 0 then
        begin
          C := NotIn2[Pos(Str[J], NotIn1)];
          inc(J);
          while (J <= Len) and (Str[J] <> C) do inc(J);
        end;
        inc(J);
      end;

      // On ajoute la sous-cha�ne rep�r�e par les caract�res de Delim
      Add(Copy(Str, I, J-I));
      I := J;
    end;
  end;
end;

{$ENDREGION}

{$REGION 'Classe TScStrings'}

/////////////////////////
/// Classe TScStrings ///
/////////////////////////

{*
  Cr�e une nouvelle instance de TScStrings
*}
constructor TScStrings.Create;
begin
  inherited Create;
  FIndex := 0;
end;

{*
  Cr�e une nouvelle instance de TScStrings charg�e � partir d'un fichier
  @param FileName   Nom du fichier � partir duquel charger la liste de cha�nes
*}
constructor TScStrings.CreateFromFile(const FileName : TFileName);
begin
  Create;
  LoadFromFile(FileName);
end;

{*
  Cr�e une nouvelle instance de TScStrings � partir d'une cha�ne d�coup�e
  @param Str       Cha�ne � d�couper
  @param Delim     Caract�res qui d�limitent deux sous-cha�nes
  @param NotIn     Paires de caract�res �chappant les d�limiteurs
  @raise EListError NotIn contient un nombre impair de caract�res
  @raise EListError Delim et NotIn contiennent un m�me caract�re
*}
constructor TScStrings.CreateFromString(const Str, Delim : string;
  const NotIn : string = '');
begin
  Create;
  FromString(Str, Delim, NotIn);
end;

{*
  Cr�e une nouvelle instance de TScStrings assign�e � partir d'une source
  @param Source   Objet source � copier dans la liste de cha�nes
*}
constructor TScStrings.CreateAssign(Source : TPersistent);
begin
  Create;
  Assign(Source);
end;

{*
  Indique s'il y a encore des cha�nes � lire
  @return True s'il y a encore des cha�nes � lire, False sinon
*}
function TScStrings.GetHasMoreString : boolean;
begin
  Result := Index < Count;
end;

{*
  Modifie l'index interne
  @param New   Nouvelle valeur de l'index interne
*}
procedure TScStrings.SetIndex(New : integer);
begin
  if New >= 0 then FIndex := New;
end;

{*
  Recherche une cha�ne dans la liste de cha�nes
  Recherche une cha�ne dans la liste de cha�nes, en d�butant et s'arr�tant �
  des index sp�cifi�s.
  @param Str             Cha�ne � rechercher
  @param BeginSearchAt   Index � partir duquel chercher
  @param EndSearchAt     Index jusqu'auquel chercher (jusqu'� la fin si -1)
  @return Index de la premi�re cha�ne correspondant � Str, ou -1 si non trouv�e
*}
function TScStrings.IndexOfEx(const Str : string; BeginSearchAt : integer = 0;
  EndSearchAt : integer = -1) : integer;
begin
  Result := StringsOps.IndexOf(Self, Str, BeginSearchAt, EndSearchAt);
end;

{*
  Recherche un texte � l'int�rieur des cha�nes de la liste
  Recherche un texte � l'int�rieur des cha�nes de la liste, en d�butant et
  s'arr�tant � des index sp�cifi�s.
  @param Str             Texte � rechercher
  @param BeginSearchAt   Index � partir duquel chercher
  @param EndSearchAt     Index jusqu'auquel chercher (jusqu'� la fin si -1)
  @return Index de la premi�re cha�ne contenant Str, ou -1 si non trouv�e
*}
function TScStrings.FindText(const Str : string; BeginSearchAt : integer = 0;
  EndSearchAt : integer = -1) : integer;
begin
  Result := StringsOps.FindText(Self, Text, BeginSearchAt, EndSearchAt);
end;

{*
  Recherche un mot en premi�re position d'une cha�ne de la liste
  Recherche un mot plac� en premi�re position d'une cha�ne de la liste (des
  espaces peuvent se trouver devant), en d�butant et s'arr�tant � des index
  sp�cifi�s.
  @param Word            Mot � rechercher
  @param BeginSearchAt   Index � partir duquel chercher
  @param EndSearchAt     Index jusqu'auquel chercher (jusqu'� la fin si -1)
  @return Index de la premi�re cha�ne contenant Word, ou -1 si non trouv�e
*}
function TScStrings.FindFirstWord(const Word : string;
  BeginSearchAt : integer = 0; EndSearchAt : integer = -1) : integer;
begin
  Result := StringsOps.FindFirstWord(Self, Word, BeginSearchAt, EndSearchAt);
end;

{*
  Recherche une sous-cha�ne � une position sp�cifi�e les cha�nes de la liste
  Recherche une sous-cha�ne d�butant � une position sp�cifi�e dans les cha�nes
  de la liste, en d�butant et s'arr�tant � des index sp�cifi�s.
  @param SubStr          Sous-cha�ne � rechercher
  @param Position        Position dans les cha�nes o� chercher la sous-cha�ne
  @param BeginSearchAt   Index � partir duquel chercher
  @param EndSearchAt     Index jusqu'auquel chercher (jusqu'� la fin si -1)
  @return Index de la premi�re cha�ne contenant Word, ou -1 si non trouv�e
*}
function TScStrings.FindAtPos(const SubStr : string; Position : integer = 1;
  BeginSearchAt : integer = 0; EndSearchAt : integer = -1) : integer;
begin
  Result := StringsOps.FindAtPos(Self, SubStr, Position, BeginSearchAt,
    EndSearchAt);
end;

{*
  Remplit la liste de cha�nes avec des cha�nes d'une autre liste
  Remplit la liste de cha�nes avec les cha�nes d'une autre liste depuis un index
  et sur un nombre sp�cifi�s.
  @param Source    Liste de cha�nes � partir de laquelle recopier les cha�nes
  @param Index     Index o� commencer la copie
  @param Count     Nombre de cha�nes � copier
*}
procedure TScStrings.CopyFrom(Source : TStrings; Index : integer = 0;
  Count : integer = -1);
begin
  StringsOps.CopyFrom(Self, Source, Index, Count);
end;

{*
  Ajoute � la liste de cha�nes des cha�nes d'une autre liste
  Ajoute � la liste de cha�nes les cha�nes d'une autre liste depuis un index et
  sur un nombre sp�cifi�s.
  @param Source    Liste de cha�nes � partir de laquelle recopier les cha�nes
  @param Index     Index o� commencer la copie
  @param Count     Nombre de cha�nes � copier
*}
procedure TScStrings.AddFrom(Source : TStrings; Index : integer = 0;
  Count : integer = -1);
begin
  StringsOps.AddFrom(Self, Source, Index, Count);
end;

{*
  D�coupe une cha�ne en sous-cha�nes et remplit la liste de ces sous-cha�nes
  D�coupe une cha�ne en sous-cha�nes d�limit�es par des caract�res sp�cifi�s, et
  remplit la liste de cha�nes avec ces sous-cha�nes.
  @param Str       Cha�ne � d�couper
  @param Delim     Caract�res qui d�limitent deux sous-cha�nes
  @param NotIn     Paires de caract�res �chappant les d�limiteurs
  @raise EListError NotIn contient un nombre impair de caract�res
  @raise EListError Delim et NotIn contiennent un m�me caract�re
*}
procedure TScStrings.FromString(const Str, Delim : string;
  const NotIn : string = '');
begin
  StringsOps.FromString(Self, Str, Delim, NotIn);
end;

{*
  D�coupe une cha�ne en sous-cha�nes et ajoute ces sous-cha�nes � la liste
  D�coupe une cha�ne en sous-cha�nes d�limit�es par des caract�res sp�cifi�s, et
  ajoute ces sous-cha�nes � la liste de cha�nes.
  @param Str       Cha�ne � d�couper
  @param Delim     Caract�res qui d�limitent deux sous-cha�nes
  @param NotIn     Paires de caract�res �chappant les d�limiteurs
  @raise EListError NotIn contient un nombre impair de caract�res
  @raise EListError Delim et NotIn contiennent un m�me caract�re
*}
procedure TScStrings.AddFromString(const Str, Delim : string;
  const NotIn : string = '');
begin
  StringsOps.AddFromString(Self, Str, Delim, NotIn);
end;

{*
  Remet � 0 l'index interne
*}
procedure TScStrings.Reset;
begin
  FIndex := 0;
end;

{*
  Lit la cha�ne suivante dans la liste de cha�ne
  @return La cha�ne suivante
*}
function TScStrings.NextString : string;
begin
  if HasMoreString then Result := Strings[Index] else Result := '';
  inc(FIndex);
end;

{$ENDREGION}

{$REGION 'Classe TScList'}

//////////////////////
/// Classe TScList ///
//////////////////////

constructor TScList.Create(ItemSize : integer);
begin
  FStream := TMemoryStream.Create;
  FItemSize := ItemSize;
end;

destructor TScList.Destroy;
begin
  FStream.Free;
  inherited Destroy;
end;

function TScList.GetCount : integer;
begin
  // Le nombre d'�l�ments est la taille du flux divis�es la taille d'un �l�ment
  Result := FStream.Size div FItemSize;
end;

procedure TScList.SetCount(New : integer);
begin
  // La taille du flux est le nombre d'�l�ments multipli� par leur taille
  if New <= 0 then FStream.SetSize(0) else
    FStream.SetSize(New*FItemSize);
end;

function TScList.GetHasMoreValue : boolean;
begin
  // Il y a encore une ou plusieurs valeurs � lire ssi la position du flux
  // est inf�rieure � sa taille
  Result := FStream.Position < FStream.Size;
end;

function TScList.GetIndex : integer;
begin
  // L'index est la position du flux divis� par la taille des �l�ments
  Result := FStream.Position div FItemSize;
end;

procedure TScList.SetIndex(New : integer);
begin
  // On v�rifie que New est bien un index correct
  if (New < 0) or (New > Count) then
    raise EListError.CreateFmt(sScIndexOutOfRange, [New]);
  // La position du flux est l'index multipli� par la taille des �l�ments
  FStream.Position := New*FItemSize;
end;

procedure TScList.DefineProperties(Filer : TFiler);
begin
  inherited;
  // La ligne suivante cr�e une propri�t� publi�e inexistante qui permet
  // d'enregistrer le contenu via WriteComponent et de le lire via
  // ReadComponent
  Filer.DefineBinaryProperty('Items', LoadFromStream, SaveToStream, True);
end;

procedure TScList.AssignTo(Dest : TPersistent);
begin
  // On autorise l'assignation ssi Dest.ClassType fait partie de la liste des
  // Classes d'assignation et que les tailles d'�lements sont les m�mes
  if (Dest is TScList) and
     (TScList(Dest).FItemSize = FItemSize) and
     IsAssignClass(TScListClass(Dest.ClassType)) then
  begin
    TScList(Dest).FStream.LoadFromStream(FStream);
  end else
  inherited;
end;

function TScList.IsAssignClass(ScListClass : TScListClass) : boolean;
begin
  // Si on remonte jusqu'ici, c'est que ce n'est une classe d'assignation
  Result := False;
end;

procedure TScList._Read(var Buffer);
begin
  // Lit un �l�ment � la position courante
  FStream.ReadBuffer(Buffer, FItemSize);
end;

procedure TScList._Write(var Buffer);
begin
  // �crit l'�l�ment � la position courante
  FStream.WriteBuffer(Buffer, FItemSize);
end;

procedure TScList._GetItems(AIndex : integer; var Buffer);
begin
  // On v�rifie que AIndex est un index correct
  if (AIndex < 0) or (AIndex >= Count) then
    raise EListError.CreateFmt(sScIndexOutOfRange, [AIndex]);
  // On se place au bon endroit pour lire l'�l�ment
  Index := AIndex;
  // On lit l'�l�ment
  _Read(Buffer);
end;

procedure TScList._SetItems(AIndex : integer; var Buffer);
begin
  // On v�rifie que AIndex est un index correct
  if (AIndex < 0) or (AIndex >= Count) then
    raise EListError.CreateFmt(sScIndexOutOfRange, [AIndex]);
  // On se place au bon endroit pour �crire l'�l�ment
  Index := AIndex;
  // On �crit l'�l�ment
  _Write(Buffer);
end;

function TScList._Add(var Buffer) : integer;
begin
  // Le r�sultat est l'index du nouvel �l�ment, soit le nombre d'�l�ments actuel
  Result := Count;
  // On se place � la fin du flux
  Index := Result;
  // On �crit l'�l�ment ; comme c'est un flux m�moire, cela agrandira
  // automatiquemnt le flux de fa�on � accepter les nouvelles donn�es
  _Write(Buffer);
end;

function TScList._Insert(AIndex : integer; var Buffer) : integer;
var Temp : TMemoryStream;
begin
  // On v�rifie que AIndex est un index correct
  if (AIndex < 0) or (AIndex > Count) then
    raise EListError.CreateFmt(sScIndexOutOfRange, [AIndex]);

  // Si AIndex vaut Count, on appelle _Add, sinon, on effectue le traitement
  if AIndex = Count then Result := _Add(Buffer) else
  begin
    Temp := TMemoryStream.Create;
    Result := AIndex; // La valeur de retour est l'index du nouvel �l�ment

    // On copie tous les �l�ments � partir de AIndex dans Temp
    Index := AIndex;
    Temp.CopyFrom(FStream, FStream.Size-FStream.Position);

    // On agrandi la liste
    Count := Count+1;

    // On �crit le nouvel �l�ment et � sa suite le contenu de Temp
    Index := AIndex;
    _Write(Buffer);
    FStream.CopyFrom(Temp, 0);

    Temp.Free;
  end;
end;

procedure TScList._Delete(AIndex : integer; var Buffer);
var Temp : TMemoryStream;
begin
  // On v�rifie que AIndex est un index correct
  if (AIndex < 0) or (AIndex >= Count) then
    raise EListError.CreateFmt(sScIndexOutOfRange, [AIndex]);

  Temp := TMemoryStream.Create;

  // On lit la valeur de retour � l'emplacement qui va �tre supprim�
  Index := AIndex;
  _Read(Buffer);

  // On copie tous les �l�ments apr�s celui-l� dans Temp
  if FStream.Position <> FStream.Size then // Pour �viter le CopyFrom(..., 0)
    Temp.CopyFrom(FStream, FStream.Size-FStream.Position);

  // On r�duit la liste
  Count := Count-1;

  // On recopie le contenu de Temp � partir de l'emplacement qui a �t� supprim�
  Index := AIndex;
  FStream.CopyFrom(Temp, 0);

  Temp.Free;
end;

procedure TScList.Assign(Source : TPersistent);
begin
  // On autorise l'assignation ssi Source.ClassType fait partie de la liste des
  // classes d'assignation et que les tailles d'�lements sont les m�mes
  if (Source is TScList) and
     (TScList(Source).FItemSize = FItemSize) and
     IsAssignClass(TScListClass(Source.ClassType)) then
  begin
    FStream.LoadFromStream(TScList(Source).FStream);
  end else
  inherited;
end;

procedure TScList.Clear;
begin
  Count := 0;
end;

procedure TScList.Reset;
begin
  Index := 0;
end;

procedure TScList.LoadFromStream(Stream : TStream);
var Size : Int64;
begin
  // On lit la taille sur 8 octets (Int64)
  Stream.Read(Size, 8);
  FStream.Size := 0;
  // Si la taille est plus grande que 0, on fait un CopyFrom
  if Size > 0 then
    FStream.CopyFrom(Stream, Size);
end;

procedure TScList.SaveToStream(Stream : TStream);
var Size : Int64;
begin
  // On �crit la taille sur 8 octets (Int64)
  Size := FStream.Size;
  Stream.Write(Size, 8);
  // Si la taille est plus grande que 0, on fait un CopyFrom
  if Size > 0 then
    Stream.CopyFrom(FStream, 0);
end;

procedure TScList.LoadFromFile(const FileName : TFileName);
var FileStream : TFileStream;
begin
  FileStream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    LoadFromStream(FileStream);
  finally
    FileStream.Free;
  end;
end;

procedure TScList.SaveToFile(const FileName : TFileName);
var FileStream : TFileStream;
begin
  FileStream := TFileStream.Create(FileName, fmCreate or fmShareDenyNone);
  try
    SaveToStream(FileStream);
  finally
    FileStream.Free;
  end;
end;

{$ENDREGION}

{$REGION 'Classe TIntegerList'}

///////////////////////////
/// Classe TIntegerList ///
///////////////////////////

constructor TIntegerList.Create(IntSize : integer = 4);
begin
  // On v�rifie que IntSize est entre 1 et 8 inclus
  if (IntSize < 1) or (IntSize > 8) then
    raise EIntListError.CreateFmt(sScWrongIntSize, [IntSize]);
  inherited Create(IntSize);
end;

constructor TIntegerList.CreateAssign(Source : TPersistent; IntSize : integer = 4);
begin
  Create(IntSize);
  Assign(Source);
end;

function TIntegerList.GetItems(Index : integer) : Int64;
begin
  _GetItems(Index, Result);
  MakeItGood(Result);
end;

procedure TIntegerList.SetItems(Index : integer; New : Int64);
begin
  _SetItems(Index, New);
end;

procedure TIntegerList.MakeItGood(var Value : Int64);
// Cette proc�dure remplis les octets non stock�s de mani�re � transformer
// un entier sur un nombre quelconque d'octets en Int64 (sur 8 octets)
type
  TRecVal = record
    case integer of
      1 : (Int : Int64);
      2 : (Ints : array[1..8] of Shortint);
  end;
var RecVal : TRecVal;
    I : integer;
    Remplis : Shortint;
begin
  RecVal.Int := Value;
    // On initialise RecVal.Int (et donc aussi RecVal.Ints)
  if RecVal.Ints[ItemSize] < 0 then Remplis := -1 else Remplis := 0;
    // Si le Shortint � la position ItemSize (c-�-d l'octet de poids le plus
    // fort stock�) est n�gatif (c-�-d si le nombre complet est n�gatif),
    // on remplit les suivant avec -1 (11111111b) et sinon avec 0 (00000000b)
  for I := ItemSize+1 to 8 do RecVal.Ints[I] := Remplis;
    // On remplit les les octets non stock�s avec la valeur de Remplis
  Value := RecVal.Int;
    // On r�actualise Value
end;

procedure TIntegerList.AssignTo(Dest : TPersistent);
var DestStrings : TStrings;
begin
  // Si Dest est un TStrings on le remplit avec les formes cha�nes des �l�ments
  if Dest is TStrings then
  begin
    DestStrings := TStrings(Dest);
    DestStrings.Clear;
    // Le principe "Reset-HasMoreValue-Read" �tant plus rapide que
    // "for 0 to Count-1" avec TScList, on l'utilise pour remplire le TStrings
    Reset;
    while HasMoreValue do
      DestStrings.Append(IntToStr(Read));
  end else
  inherited;
end;

function TIntegerList.IsAssignClass(ScListClass : TScListClass) : boolean;
begin
  if ScListClass.InheritsFrom(TIntegerList) then Result := True else
  Result := inherited IsAssignClass(ScListClass);
end;

procedure TIntegerList.Assign(Source : TPersistent);
var SourceStrings : TStrings;
    I : integer;
begin
  // Si Source est un TStrings, on convertit les cha�nes en entiers
  if Source is TStrings then
  begin
    SourceStrings := TStrings(Source);
    Clear;
    for I := 0 to SourceStrings.Count-1 do
      Add(StrToInt64(SourceStrings[I]));
  end else
  inherited;
end;

function TIntegerList.Read : Int64;
begin
  _Read(Result);
  MakeItGood(Result);
end;

procedure TIntegerList.Write(New : Int64);
begin
  _Write(New);
end;

function TIntegerList.Add(New : Int64) : integer;
begin
  Result := _Add(New);
end;

function TIntegerList.Insert(Index : integer; New : Int64) : integer;
begin
  Result := _Insert(Index, New);
end;

function TIntegerList.Delete(Index : integer) : Int64;
begin
  _Delete(Index, Result);
  MakeItGood(Result);
end;

{$ENDREGION}

{$REGION 'Classe TUnsignedIntList'}

///////////////////////////////
/// Classe TUnsignedIntList ///
///////////////////////////////

constructor TUnsignedIntList.Create(IntSize : integer = 4);
begin
  // On v�rifie que IntSize est entre 1 et 4 inclus
  if (IntSize < 1) or (IntSize > 4) then
    raise EIntListError.CreateFmt(sScWrongIntSize, [IntSize]);
  inherited Create(IntSize);
end;

constructor TUnsignedIntList.CreateAssign(Source : TPersistent; IntSize : integer = 4);
begin
  Create(IntSize);
  Assign(Source);
end;

function TUnsignedIntList.GetItems(Index : integer) : LongWord;
begin
  _GetItems(Index, Result);
  MakeItGood(Result);
end;

procedure TUnsignedIntList.SetItems(Index : integer; New : LongWord);
begin
  _SetItems(Index, New);
end;

procedure TUnsignedIntList.MakeItGood(var Value : LongWord);
// Cette proc�dure remplis les octets non stock�s de mani�re � transformer
// un entier sur un nombre quelconque d'octets en LongWord (sur 4 octets)
type
  TRecVal = record
    case integer of
      1 : (Int : LongWord);
      2 : (Ints : array[1..4] of Byte);
  end;
var RecVal : TRecVal;
    I : integer;
begin
  RecVal.Int := Value;
    // On initialise RecVal.Int (et donc aussi RecVal.Ints)
  for I := ItemSize+1 to 4 do RecVal.Ints[I] := 0;
    // On remplit les octets non stock�s avec des 0
  Value := RecVal.Int;
    // On r�actualise Value
end;

procedure TUnsignedIntList.AssignTo(Dest : TPersistent);
var DestStrings : TStrings;
begin
  // Si Dest est un TStrings on le remplit avec les formes cha�nes des �l�ments
  if Dest is TStrings then
  begin
    DestStrings := TStrings(Dest);
    DestStrings.Clear;
    // Le principe "Reset-HasMoreValue-Read" �tant plus rapide que
    // "for 0 to Count-1" avec TScList, on l'utilise pour remplire le TStrings
    Reset;
    while HasMoreValue do
      DestStrings.Append(IntToStr(Read));
  end else
  inherited;
end;

function TUnsignedIntList.IsAssignClass(ScListClass : TScListClass) : boolean;
begin
  if ScListClass.InheritsFrom(TUnsignedIntList) then Result := True else
  Result := inherited IsAssignClass(ScListClass);
end;

procedure TUnsignedIntList.Assign(Source : TPersistent);
var SourceStrings : TStrings;
    I : integer;
    Val : Int64;
begin
  // Si Source est un TStrings, on convertit les cha�nes en entiers
  if Source is TStrings then
  begin
    SourceStrings := TStrings(Source);
    Clear;
    for I := 0 to SourceStrings.Count-1 do
    begin
      Val := StrToInt64(SourceStrings[I]);
      // On v�rifie que Val est bien un LongWord
      if (Val < 0) or (Val > High(LongWord)) then
        raise EConvertError.CreateFmt(sScWrongLongWord, [SourceStrings[I]]);
      Add(Val);
    end;
  end else
  inherited;
end;

function TUnsignedIntList.Read : LongWord;
begin
  _Read(Result);
  MakeItGood(Result);
end;

procedure TUnsignedIntList.Write(New : LongWord);
begin
  _Write(New);
end;

function TUnsignedIntList.Add(New : LongWord) : integer;
begin
  Result := _Add(New);
end;

function TUnsignedIntList.Insert(Index : integer; New : LongWord) : integer;
begin
  Result := _Insert(Index, New);
end;

function TUnsignedIntList.Delete(Index : integer) : LongWord;
begin
  _Delete(Index, Result);
  MakeItGood(Result);
end;

{$ENDREGION}

{$REGION 'Classe TExtendedList'}

////////////////////////////
/// Classe TExtendedList ///
////////////////////////////

constructor TExtendedList.Create;
begin
  inherited Create(sizeof(Extended));
end;

constructor TExtendedList.CreateAssign(Source : TPersistent);
begin
  Create;
  Assign(Source);
end;

function TExtendedList.GetItems(Index : integer) : Extended;
begin
  _GetItems(Index, Result);
end;

procedure TExtendedList.SetItems(Index : integer; New : Extended);
begin
  _SetItems(Index, New);
end;

procedure TExtendedList.AssignTo(Dest : TPersistent);
var DestStrings : TStrings;
begin
  // Si Dest est un TStrings on le remplit avec les formes cha�nes des �l�ments
  if Dest is TStrings then
  begin
    DestStrings := TStrings(Dest);
    DestStrings.Clear;
    // Le principe "Reset-HasMoreValue-Read" �tant plus rapide que
    // "for 0 to Count-1" avec TScList, on l'utilise pour remplire le TStrings
    Reset;
    while HasMoreValue do
      DestStrings.Append(FloatToStr(Read));
  end else
  inherited;
end;

function TExtendedList.IsAssignClass(ScListClass : TScListClass) : boolean;
begin
  if ScListClass.InheritsFrom(TExtendedList) then Result := True else
  Result := inherited IsAssignClass(ScListClass);
end;

procedure TExtendedList.Assign(Source : TPersistent);
var SourceStrings : TStrings;
    I : integer;
begin
  // Si Source est un TStrings, on convertit les cha�nes en nombres flottants
  if Source is TStrings then
  begin
    Clear;
    SourceStrings := TStrings(Source);
    for I := 0 to SourceStrings.Count-1 do
      Write(StrToFloat(SourceStrings[I]));
  end else
  inherited;
end;

function TExtendedList.Read : Extended;
begin
  _Read(Result);
end;

procedure TExtendedList.Write(New : Extended);
begin
  _Write(New);
end;

function TExtendedList.Add(New : Extended) : integer;
begin
  Result := _Add(New);
end;

function TExtendedList.Insert(Index : integer; New : Extended) : integer;
begin
  Result := _Insert(Index, New);
end;

function TExtendedList.Delete(Index : integer) : Extended;
begin
  _Delete(Index, Result);
end;

{$ENDREGION}

//////////////////////////////////////
/// Initialization et Finalization ///
//////////////////////////////////////

var I : integer;

initialization
  AppParams := TScStrings.Create;
  // On remplit AppParams avec les param�tres envoy�s � l'application
  for I := 1 to ParamCount do AppParams.Append(ParamStr(I));
finalization
  AppParams.Free;
end.
