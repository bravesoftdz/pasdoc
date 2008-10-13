{ @abstract(Provides HTML document generator object.)
  @author(Johannes Berg <johannes@sipsolutions.de>)
  @author(Ralf Junker (delphi@zeitungsjunge.de))
  @author(Alexander Lisnevsky (alisnevsky@yandex.ru))
  @author(Erwin Scheuch-Heilig (ScheuchHeilig@t-online.de))
  @author(Marco Schmidt (marcoschmidt@geocities.com))
  @author(Hendy Irawan (ceefour@gauldong.net))
  @author(Wim van der Vegt (wvd_vegt@knoware.nl))
  @author(Thomas Mueller (www.dummzeuch.de))
  @author(David Berg (HTML Layout) <david@sipsolutions.de>)
  @author(Grzegorz Skoczylas <gskoczylas@rekord.pl>)
  @author(Michalis Kamburelis)
  @author(Richard B. Winston <rbwinst@usgs.gov>)
  @author(Ascanio Pressato)
  @author(Hans-Peter Diettrich <DrDiettrich1@aol.com>)
  @cvs($Date$)

  Implements an object to generate HTML documentation, overriding many of
  @link(TDocGenerator)'s virtual methods. }

unit PasDoc_GenFullHtml;

interface

uses
  Classes,
  PasDoc_Utils,
  PasDoc_Gen,
  PasDoc_Items,
  PasDoc_Languages,
  PasDoc_StringVector,
  PasDoc_GenHTML,
  PasDoc_Types;

type
//available sections for an item
  TSectionSet = set of TTranslationID;
  TSectionsInMenu = array[0..6] of TTranslationID;

  { @abstract(generates HTML documentation)
    Extends @link(TDocGenerator) and overwrites many of its methods to generate
    output in HTML (HyperText Markup Language) format. }
  TFullHTMLDocGenerator = class(TGenericHTMLDocGenerator)
  protected
  //the current output file name
    CurFile: string;
  (* Collect all available sections for an item.
    Could become a item method?
  *)
    function  FindSections(item: TDescriptionItem): TSectionSet;
  //get menu entries, based on item
    function  GetSectionsInMenu(item: TBaseItem): TSectionsInMenu; virtual;
  //Return anchor string, based on a translation ID.
    function  GetSectionAnchor(tid: TTranslationID): string;
    procedure WriteDescriptionSectionHeading(const Caption: TTranslationID);
    { Writes heading S to output, at heading level I.
      Write optional section anchor.
      For HTML, only levels 1 to 6 are valid, so that values smaller
      than 1 will be set to 1 and arguments larger than 6 are set to 6.
      The String S will then be enclosed in an element from H1 to H6,
      according to the level. }
    procedure WriteSectionHeading(HL: integer; const CssClass: string;
      tid: TTranslationID);

    procedure WriteSectionMenu(AItem: TBaseItem);

    procedure WriteMemberSummary(Items: TDescriptionItem; ShowVisibility: boolean;
      HL: Integer);

    procedure WriteMembersDetailed(Items: TDescriptionItem; ShowVisibility: boolean;
      HL: Integer);

    { Writes dates (Created and LastMod) at heading level HL to output. }
    procedure WriteDate(const HL: integer; ADate: TDescriptionItem);
    //write PasItem abstract+details
    procedure WriteDescription(HL: integer; AItem: TPasItem);
    { Writes authors to output, at heading level HL. Will not write anything
      if collection of authors is not assigned or empty. }
    //procedure WriteAuthors(HL: integer; Authors: TStringVector);
    procedure WriteAuthors(HL: integer; Authors: TDescriptionItem);
    procedure WriteSeeAlso(SeeAlso: TDescriptionItem; AItem: TPasItem); //TPasScope);

    { Writes the Item's short description, into a table cell.
      This is either the explicit AbstractDescription (@@abstract)
      or the (abbreviated) DetailedDescription. }
    procedure WriteItemShortDescription(const AItem: TPasItem);

    (*Writes the Item's AbstractDescription followed by DetailedDescription.
      Include further descriptions, depening on item kind (parameters...).

      If OpenCloseParagraph then code here will open and close paragraph
      for itself. So you shouldn't
      surround it inside WriteStart/EndOfParagraph, like
      @longcode(#
        { BAD EXAMPLE }
        WriteStartOfParagraph;
        WriteItemLongDescription(Item, true);
        WriteEndOfParagraph;
      #)

      While you can pass OpenCloseParagraph = @false, do it with caution,
      and note that long description has often such large content that it
      really should be separated by paragraph. Passing
      OpenCloseParagraph = @false is sensible only if you will wrap this
      anyway inside some paragraph or similar block level element.

      While the item found is the full description (abstract+detailed),
      more information will be presented (attributes, non-self-contained items)
    *)
  {$IFDEF old}
    procedure WriteItemLongDescription(HL: integer; AItem: TPasItem;
      OpenCloseParagraph: boolean = true);
  {$ELSE}
  //Write all description items of an item. A simple loop over all items.
    procedure WriteAllSections(HL: integer; Items: TDescriptionItem; PasItem: TPasItem);
  {$ENDIF}

  //Write complete PasItem description, handling output files.
    procedure WriteItem(HL: integer; AItem: TPasItem);

  //Write an description item
    procedure WriteDescriptionItem(HL: integer; AItem: TDescriptionItem; PasItem: TPasItem);

    procedure WriteOverviewFiles;

    { Writes a single class, interface or object CIO to output, at heading
      level HL. }
    procedure WriteCIO(HL: integer; const CIO: TPasCio);

    { Calls @link(WriteCIO) with each element in the argument collection C,
      using heading level HL. }
    procedure WriteCIOs(HL: integer; c: TPasItems);

    procedure WriteCIOSummary(HL: integer; c: TPasItems);

    procedure WriteUnit(const HL: integer; const U: TPasUnit); override;

    procedure WriteExternalCore(const ExternalItem: TExternalItem;
      const Id: TTranslationID); override;

  public
    { The method that does everything - writes documentation for all units
      and creates overview files. }
    procedure WriteDocumentation; override;
  end;

implementation

uses
  SysUtils,
  StrUtils, { if you are using Delphi 5 or fpc 1.1.x you must add ..\component\strutils to your search path }
  PasDoc_Base,
  PasDoc_ObjectVector,
  PasDoc_Tipue,
  PasDoc_Aspell;

{ TFullHTMLDocGenerator }

function  TFullHTMLDocGenerator.FindSections(item: TDescriptionItem): TSectionSet;
var
  i, j: integer;
  d: TDescriptionItem;
  SectionsAvailable: TSectionSet;
begin
  SectionsAvailable := [];
  for i := 0 to item.Count - 1 do begin
    d := item.ItemAt(i);
    Include(SectionsAvailable, d.ID);
    if d.id = trOverview then begin
      for j := 0 to d.Count - 1 do begin
        Include(SectionsAvailable, d.Items[j].ID);
      end;
    end;
  end;
  Result := SectionsAvailable;
end;

procedure TFullHTMLDocGenerator.WriteSectionMenu(AItem: TBaseItem);
var
  SectionsInMenu: TSectionsInMenu;
  SectionsAvailable: TSectionSet;
  Section: integer;
  tid: TTranslationID;
  s: string;
begin
  SectionsInMenu := GetSectionsInMenu(AItem);
  if SectionsInMenu[0] = trNoTrans then
    exit;
  SectionsAvailable := FindSections(AItem);
  if not WriteUsesClause then
    Exclude(SectionsAvailable, trUses);
//write menu bar
  WriteStartOfTable('sections');
  WriteDirectLine('<tr>');
  for Section := Low(SectionsInMenu) to High(SectionsInMenu) do begin
    tid := SectionsInMenu[section];
    if tid = trNoTrans then
      break;
    WriteDirect('<td>');
      s := FLanguage.Translation[tid];
      if tid in SectionsAvailable then
        //WriteLink('#'+SectionAnchors[Section], s, 'section')
        WriteLink(GetSectionAnchor(tid), s, 'section')
      else
        WriteConverted(s);
    WriteDirect('</td>');
  end;
  WriteDirectLine('</tr></table>');
end;

function  TFullHTMLDocGenerator.GetSectionAnchor(tid: TTranslationID): string;
begin
  Result := '#%40' + IntToStr(ord(tid));
end;

procedure TFullHTMLDocGenerator.WriteSectionHeading(HL: integer; const CssClass: string;
      tid: TTranslationID);
begin
  WriteHeading(HL, CssClass, FLanguage.Translation[tid], GetSectionAnchor(tid));
end;

procedure TFullHTMLDocGenerator.WriteAuthors(HL: integer; Authors: TDescriptionItem);
var
  i: Integer;
  s, S1, S2: string;
  Address: string;
begin
  if IsEmpty(Authors) then Exit;

  if (Authors.Count = 1) then
    WriteHeading(HL, 'authors', FLanguage.Translation[trAuthor])
  else
    WriteHeading(HL, 'authors', FLanguage.Translation[trAuthors]);

  WriteDirectLine('<ul class="authors">');
  for i := 0 to Authors.Count - 1 do begin
    s := Authors.GetString(i);
    WriteDirect('<li>');

    if ExtractEmailAddress(s, S1, S2, Address) then begin
      WriteConverted(S1);
      WriteLink('mailto:' + Address, ConvertString(Address), '');
      WriteConverted(S2);
    end else if ExtractWebAddress(s, S1, S2, Address) then begin
      WriteConverted(S1);
      WriteLink('http://' + Address, ConvertString(Address), '');
      WriteConverted(S2);
    end else begin
      WriteConverted(s);
    end;

    WriteDirectLine('</li>');
  end;
  WriteDirectLine('</ul>');
end;

procedure TFullHTMLDocGenerator.WriteCIO(HL: integer; const CIO: TPasCio);
type
  TSections = (dsDescription, dsHierarchy, dsFields, dsMethods, dsProperties);
const
//ordered menu entries
  //SectionsInMenu: array[TSections] of TTranslationID = (
  SectionsInMenu: TSectionsInMenu = (
    trDescription, trHierarchy, trFields, trMethods, trProperties,
    trNoTrans, trNoTrans
  );

  { writes an ancestor }
  procedure WriteAncestor(Item: TDescriptionItem);
  var
    CIO: TPasItem;
  begin
    CIO := Item.PasItem;
    if not Assigned(CIO) then begin
      WriteDirectLine('<li class="ancestor">' + Item.Name + '</li>');
      { recursion ends here, when the item is an external class }
    end else begin
      WriteDirectLine('<li class="ancestor">' +
        MakeItemLink(CIO, CIO.Name, lcNormal) + '</li>')
    end;
  end;

{$IFDEF old}
var
  s: string;
  SectionsAvailable: TSectionSet;
  i, j: integer;
  d: TDescriptionItem;
{$ELSE}
{$ENDIF}
begin //WriteCIO
  if not Assigned(CIO) then Exit;

{$IFDEF old}

(* When the description is written to an distinct file, provide:
  - a section menu
  - a unit reference
*)
  if CIO.OutputFileName <> '' then begin
    SectionsAvailable := FindSections(CIO);

    s := GetCIOTypeName(CIO.MyType) + ' ' + CIO.Name;

    WriteStartOfDocument(CIO.MyUnit.Name + ': ' + s);

    WriteAnchor(CIO.Name);
    WriteHeading(HL, 'cio', s);

  {$IFDEF old}
    WriteSectionMenu(SectionsInMenu, SectionsAvailable);
  {$ELSE}
    WriteSectionMenu(CIO);
  {$ENDIF}

  //these exceptions should be removed. Create description items in CIOs.

  (* Every item knows about its unit, but doesn't know whether it has to provide
    the unit as a description item.
    A unit reference has to be shown for all those items,
    which are displayed in their own description file.
  *)
  //write unit link
    //if not (CIO is TPasUnit) then begin
    if True then begin
      WriteSectionHeading(HL+1, 'unit', trUnit);
      WriteStartOfParagraph('unitlink');
        WriteLink(CIO.MyUnit.FullLink, ConvertString(CIO.MyUnit.Name), '');
      WriteEndOfParagraph;
    end;
  end;

{$IFDEF old}
//write declaration link
  if not (trDeclaration in SectionsAvailable) then begin
    WriteSectionHeading(HL + 1, 'declaration', trDeclaration);
    WriteStartOfParagraph('declaration');
      WriteStartOfCode;
        WriteConverted(CIO.FullDeclaration);
      WriteEndOfCode;
    WriteEndOfParagraph;
  end;
{$ELSE}
  //description item created
{$ENDIF}

  for i := 0 to CIO.Count - 1 do begin
    d := CIO.ItemAt(i);
    case d.ID of
    trUnit:
      begin
        WriteSectionHeading(HL+1, 'unit', trUnit);
        WriteStartOfParagraph('unitlink');
          WriteLink(d.PasItem.FullLink, ConvertString(d.Name), '');
        WriteEndOfParagraph;
      end;
    trDeclaration: //IS declaration item
      begin
        WriteSectionHeading(HL + 1, 'declaration', trDeclaration);
        WriteStartOfParagraph('declaration');
          WriteStartOfCode;
            WriteConverted(d.Caption);  //(CIO.FullDeclaration);
          WriteEndOfCode;
        WriteEndOfParagraph;
      end;
    trDescription:  //IS description
      begin
        WriteSectionHeading(HL + 1, 'description', trDescription);
        //WriteItemLongDescription(CIO);
        WriteItemLongDescription(d.PasItem);
      end;
    trHierarchy:
      begin
        WriteSectionHeading(HL + 1, 'hierarchy', trHierarchy);
        WriteDirect('<ul class="hierarchy">');
          for j := 0 to d.Count - 1 do begin
            WriteAncestor(d.Items[j]);
          end;
        WriteDirect('</ul>');
      end;
    trOverview:
      begin
        WriteHeading(HL + 1, 'overview', FLanguage.Translation[trOverview]);
        for j := 0 to d.Count - 1 do begin
          WriteMemberSummary(d.ItemAt(j), CIO.ShowVisibility, HL+1);
        end;

        WriteHeading(HL + 1, 'description', FLanguage.Translation[trDescription]);
        for j := 0 to d.Count - 1 do begin
          WriteMembersDetailed(d.ItemAt(j), CIO.ShowVisibility, HL+1);
        end;
      end;
    trAuthors:
      WriteAuthors(HL + 1, d);  // CIO.Authors);
    trCreated, trLastModified:
      WriteDate(HL + 1, d);  //CIO.Created, CIO.LastMod);
    trSeeAlso:
      WriteSeeAlso(d, CIO);
    else
    end;
  end;

  WriteFooter;
  WriteAppInfo;
  WriteEndOfDocument;
{$ELSE}
  WriteItem(HL, CIO);
{$ENDIF}
end;

procedure TFullHTMLDocGenerator.WriteCIOs(HL: integer; c: TPasItems);
var
  i: Integer;
  p: TPasCio;
begin
  if c = nil then Exit;

  for i := 0 to c.Count - 1 do begin
    p := TPasCio(c.PasItemAt[i]);

    if (p.MyUnit <> nil) and
       p.MyUnit.FileNewerThanCache(DestinationDirectory + p.OutputFileName) then
    begin
      DoMessage(3, pmtInformation, 'Data for "%s" was loaded from cache, '+
        'and output file of this item exists and is newer than cache, '+
        'skipped.', [p.Name]);
      Continue;
    end;

  {$IFDEF old}
    case CreateStream(p.OutputFileName, true) of
      csError: begin
          DoMessage(1, pmtError, 'Could not create Class/Interface/Object documentation file.', []);
          Continue;
        end;
      csCreated: begin
          DoMessage(3, pmtInformation, 'Creating Class/Interface/Object file for "%s"...', [p.Name]);
          WriteCIO(HL, p);
        end;
    end;
  //CloseStream; - in WriteCIO
  {$ELSE}
    WriteItem(HL, p);
  {$ENDIF}
  end;
  //CloseStream;
end;

{ ---------------------------------------------------------------------------- }

procedure TFullHTMLDocGenerator.WriteCIOSummary(HL: integer; c: TPasItems);
var
  j: Integer;
  p: TPasCio;
begin
  if IsEmpty(c) then Exit;

  WriteSectionHeading(HL, 'cio', trCio);
  WriteStartOfTable2Columns('classestable', FLanguage.Translation[trName], FLanguage.Translation[trDescription]);
  for j := 0 to c.Count - 1 do begin
    p := TPasCio(c.PasItemAt[j]);
    WriteStartOfTableRow('');
    { name of class/interface/object and unit }
    WriteStartOfTableCell('itemname');
    WriteConverted(GetCIOTypeName(p.MyType));
    WriteDirect('&nbsp;');
    WriteLink(p.FullLink, CodeString(p.Name), 'bold');
    WriteEndOfTableCell;

    { Description of class/interface/object }
    WriteStartOfTableCell('itemdesc');
    WriteItemShortDescription(p);

    WriteEndOfTableCell;
    WriteEndOfTableRow;
  end;
  WriteEndOfTable;
end;

{ ---------------------------------------------------------------------------- }

procedure TFullHTMLDocGenerator.WriteDate(const HL: integer;
  ADate: TDescriptionItem);
begin
  if assigned(ADate) and (ADate.Name <> '') then begin
    WriteHeading(HL, 'date', FLanguage.Translation[ADate.ID]);
    WriteStartOfParagraph;
      WriteDirectLine(ADate.Name);
    WriteEndOfParagraph;
  end;
end;

procedure TFullHTMLDocGenerator.WriteMemberSummary(Items: TDescriptionItem; ShowVisibility: boolean;
      HL: Integer);
var
  i: Integer;
begin
  if IsEmpty(Items) then Exit; //should never happen

  WriteAnchor(GetSectionAnchor(Items.ID));
  WriteHeading(HL + 1, 'summary', FLanguage.Translation[Items.id]);
  WriteStartOfTable1Column('summary');

  for i := 0 to Items.Count - 1 do
    WriteItemTableRow(Items.PasItemAt(i), ShowVisibility, true, false);

  WriteEndOfTable;
end;

procedure TFullHTMLDocGenerator.WriteMembersDetailed(Items: TDescriptionItem; ShowVisibility: boolean;
  HL: Integer);
var
  Item: TDescriptionItem;
  PasItem: TPasItem;
  i: Integer;
  ColumnsCount: Cardinal;
  grouped: boolean;
begin
(* Expect a list of items (PasItems).
  Lists of other than PasItems (params...) need appropriate handling!

  To be called only for Details of Overview!
  Exclude items (CIO...) in different files
*)
  if IsEmpty(Items) then Exit;

  Item := Items.ItemAt(0);
  grouped := Item.ID = trDescriptions; //or: all member lists with explicit name?
  if not grouped then begin
  //ordinary member list
    PasItem := Item.PasItem;
    if (PasItem = nil) then
      exit; //wrong list?
    if (PasItem.OutputFileName <> '') and (PasItem.OutputFileName <> CurFile) then
      exit; //assume all members reside in their own files (CIO...)
  end;

  if HL = 1 then
    WriteHeading(HL + 1, 'detail', FLanguage.Translation[Items.id]);

  if Items.PasItemAt(0) = nil then begin
  //sublist of non-PasItems
  end else begin
  //immediate list of PasItems
  end;
//calculate ColumnsCount
  ColumnsCount := 1;
  if ShowVisibility then Inc(ColumnsCount);

  for i := 0 to Items.Count - 1 do begin
    Item := Items.ItemAt(i);
    PasItem := item.PasItem;

    if PasItem = nil then begin
    //non-PasItem in member list?
      WriteDescriptionItem(HL, Item, PasItem);
      WriteDirectLine(Item.Name + '=' + Item.Value + ': ???');
    end else if (PasItem.OutputFileName <> '') and (PasItem.OutputFileName <> CurFile) then begin
      //do nothing - must be written into it's own file
    end else begin
      WriteStartOfTable('detail');
        WriteItemTableRow(PasItem, ShowVisibility, false, true);
        { Using colspan="0" below would be easier, but Konqueror and IE
          can't handle it correctly. It seems that they treat it as colspan="1" ? }
        WriteDirectLine(Format('<tr><td colspan="%d">', [ColumnsCount]));
          //WriteItemLongDescription(HL, Item);
          WriteAllSections(HL+1, item, PasItem);
        WriteDirectLine('</td></tr>');
      WriteEndOfTable;
    end;
  end;
end;

procedure TFullHTMLDocGenerator.WriteDescriptionSectionHeading(const Caption: TTranslationID);
begin
  WriteHeading(6, 'description_section', FLanguage.Translation[Caption]);
end;

procedure TFullHTMLDocGenerator.WriteItemShortDescription(const AItem: TPasItem);
begin
//no spell checking, short description can be truncated
  if AItem <> nil then
    WriteDirect(AItem.ShortDescription);
end;

{$IFDEF old}

procedure TFullHTMLDocGenerator.WriteItemLongDescription(HL: integer;
  AItem: TPasItem; OpenCloseParagraph: boolean);
(* Used to write sub-items (of a scope)!!!
*)

  { writes the parameters or exceptions list }
  procedure WriteParamsOrRaises(Func: TPasMethod; const Caption: TTranslationID;
    List: TDescriptionItem; LinkToParamNames: boolean;
    const CssListClass: string);

    procedure WriteParameter(const ParamName: string; const Desc: string);
    begin
      { Note that <dt> and <dd> below don't need any CSS class,
        they can be accessed via "dl.parameters dt" or "dl.parameters dd"
        (assuming that CssListClass = 'parameters'). }
      WriteDirect('<dt>');
      WriteDirect(ParamName);
      WriteDirectLine('</dt>');
      WriteDirect('<dd>');
      WriteSpellChecked(Desc);
      WriteDirectLine('</dd>');
    end;

  var
    i: integer;
    ParamName: string;
  begin
    if IsEmpty(List) then
      Exit;

    WriteDescriptionSectionHeading(Caption);
    WriteDirectLine('<dl class="' + CssListClass + '">');
    for i := 0 to List.Count - 1 do begin
      ParamName := List.Items[i].Name;

      if LinkToParamNames then
       ParamName := SearchLink(ParamName, Func, '', true);

      WriteParameter(ParamName, List.Items[i].Value);
    end;
    WriteDirectLine('</dl>');
  end;

  procedure WriteReturnDesc(Func: TPasMethod; ReturnDesc: TDescriptionItem);
  begin
    if (ReturnDesc = nil) or (ReturnDesc.Text = '') then
      exit;
    WriteDescriptionSectionHeading(trReturns);
    WriteDirect('<p class="return">');
    WriteSpellChecked(ReturnDesc.Text);
    WriteDirect('</p>');
  end;

var
  AItemMethod: TPasMethod absolute AItem;
  PasEnum:  TPasEnum absolute AItem;
begin
  if AItem = nil then
    exit;

  WriteDescription(HL, AItem);

(* Write additional descriptions, of items residing in the same file.
*)
  if AItem is TPasMethod then begin
    WriteParamsOrRaises(AItemMethod, trParameters,
      AItemMethod.Params, false, 'parameters');
    WriteReturnDesc(AItemMethod, AItemMethod.Returns);
    WriteParamsOrRaises(AItemMethod, trExceptionsRaised,
      AItemMethod.Raises, true, 'exceptions_raised');
  end;

  //WriteSeeAlso(AItem.SeeAlso, AItem.MyOwner);

  if AItem is TPasEnum then begin
    WriteDescriptionSectionHeading(trValues);
    WriteDirectLine('<ul>');
    for i := 0 to PasEnum.Members.Count - 1 do begin
      WriteDirectLine('<li>');
      WriteConverted(PasEnum.Members.PasItemAt[i].FullDeclaration);
      WriteConverted(': ');
      WriteItemLongDescription(HL+1, PasEnum.Members.PasItemAt[i], false);
      WriteDirectLine('</li>');
    end;
    WriteDirectLine('</ul>');
  end;
end;
{$ELSE}

procedure TFullHTMLDocGenerator.WriteAllSections(HL: integer;
  Items: TDescriptionItem; PasItem: TPasItem);
var
  d: TDescriptionItem;
  i: integer;
begin
  if IsEmpty(Items) then exit;

  for i := 0 to Items.Count - 1 do begin
    d := Items.ItemAt(i);
    //if OpenCloseParagraph then ...?
    WriteDescriptionItem(HL, d, PasItem);
  end;
end;
{$ENDIF}

procedure TFullHTMLDocGenerator.WriteDescription(HL: integer; AItem: TPasItem);
var
  attrs: TPasItemAttributes;
  OpenCloseParagraph: boolean;

  procedure WriteHintDirective(const S: string; attr: TPasItemAttribute);
  begin
    WriteDirect('<p class="hint_directive">');
    WriteConverted(FLanguage.Translation[trWarning] + ': ' + S + '.');
    WriteDirect('</p>');
    Exclude(attrs, attr);
    OpenCloseParagraph := True;
  end;

{$IFDEF old}
var
  i: Integer;
{$ELSE}
{$ENDIF}
{$IFDEF new}
var
  ia: TPasItemAttribute;
{$ELSE}
{$ENDIF}
begin //WriteItemLongDescription
(* Write whole item description.

  Could write declaration?
*)
  if not Assigned(AItem) then Exit;

  attrs := AItem.Attributes;

  OpenCloseParagraph := (HL < 2) or (AItem.AbstractDescription <> '') and (AItem.DetailedDescription <> '');

  if AItem.HasAttribute[SD_DEPRECATED] then
    WriteHintDirective(FLanguage.Translation[trDeprecated], SD_DEPRECATED);
  if AItem.HasAttribute[SD_PLATFORM] then
    WriteHintDirective(FLanguage.Translation[trPlatformSpecific], SD_PLATFORM);
  if AItem.HasAttribute[SD_LIBRARY_] then
    WriteHintDirective(FLanguage.Translation[trLibrarySpecific], SD_Library_);

{$IFDEF new}
  if attrs <> [] then begin
  //write section heading?
    WriteSectionHeading(HL+1, '', 'Directives');
    for ia := low(ia) to high(ia) do begin
      if ia in attrs then begin
      //format?
        WriteDirect(DirectiveNames[ia], True);
      end;
    end;
  end;
{$ELSE}
{$ENDIF}

(* Write Abstract and Description, if not empty.
  Inheritable descriptions already have been resolved by the items.

  Abstract and Detailed have been introduced in TBaseItem.
  Use of description item? External items?
*)
  OpenCloseParagraph := (HL < 2) or (AItem.AbstractDescription <> '') and (AItem.DetailedDescription <> '');
  if AItem.AbstractDescription <> '' then begin
    if OpenCloseParagraph then
      WriteStartOfParagraph;
    WriteSpellChecked(AItem.AbstractDescription);
    if OpenCloseParagraph then
      WriteEndOfParagraph;
  end;
  if AItem.DetailedDescription <> '' then begin
    if OpenCloseParagraph then
      WriteStartOfParagraph;
    WriteSpellChecked(AItem.DetailedDescription);
    if OpenCloseParagraph then
      WriteEndOfParagraph;
  end;
end;

procedure TFullHTMLDocGenerator.WriteSeeAlso(SeeAlso: TDescriptionItem; AItem: TPasItem);
var
  i: integer;
  item: TDescriptionItem;
  SeeAlsoItem: TBaseItem;
  SeeAlsoLink: string;
  scope: TPasScope;
begin
  if IsEmpty(SeeAlso) then Exit;

  if AItem is TPasScope then
    scope := TPasScope(AItem)
  else
    scope := nil;

  WriteDescriptionSectionHeading(trSeeAlso);
  WriteDirectLine('<dl class="see_also">');
  for i := 0 to SeeAlso.Count - 1 do begin
    item := SeeAlso.ItemAt(i);
    SeeAlsoLink := SearchLink(item.Name, scope, item.Value, true, SeeAlsoItem);
    WriteDirect('  <dt>');
      if SeeAlsoItem <> nil then
        WriteDirect(SeeAlsoLink)
      else
        WriteConverted(item.Name);
    WriteDirectLine('</dt>');

    WriteDirect('  <dd>');
      //if (SeeAlsoItem <> nil) and (SeeAlsoItem is TPasItem) then begin
      if (SeeAlsoItem is TPasItem) then begin
      //direct write???
        WriteConverted(TPasItem(SeeAlsoItem).ShortDescription, False);
        //WriteDirect(TPasItem(SeeAlsoItem).AbstractDescription);
      end;
    WriteDirectLine('</dd>');
  end;
  WriteDirectLine('</dl>');
end;

{ ---------- }

procedure TFullHTMLDocGenerator.WriteOverviewFiles;

  function CreateOverviewStream(Overview: TCreatedOverviewFile): boolean;
  var
    BaseFileName, Headline: string;
  begin
    BaseFileName := OverviewFilesInfo[Overview].BaseFileName;
    Result := CreateStream(BaseFileName + GetFileExtension, True) <> csError;

    if not Result then
    begin
      DoMessage(1, pmtError, 'Error: Could not create output file "' +
        BaseFileName + '".', []);
      Exit;
    end;

    DoMessage(3, pmtInformation, 'Writing overview file "' +
      BaseFileName + '" ...', []);

    Headline := FLanguage.Translation[
      OverviewFilesInfo[Overview].TranslationHeadlineId];
    WriteStartOfDocument(Headline);
    WriteHeading(1, 'allitems', Headline);
  end;

  { Creates an output stream that lists up all units and short descriptions. }
  procedure WriteUnitOverviewFile;
  var
    c: TPasItems;
    Item: TPasItem;
    j: Integer;
  begin
    c := Units;

    if not CreateOverviewStream(ofUnits) then
      Exit;

    if Assigned(c) and (c.Count > 0) then begin
      WriteStartOfTable2Columns('unitstable', FLanguage.Translation[trName],
        FLanguage.Translation[trDescription]);
      for j := 0 to c.Count - 1 do begin
        Item := c.PasItemAt[j];
        WriteStartOfTableRow('');
        WriteStartOfTableCell('itemname');
        WriteLink(Item.FullLink, Item.Name, 'bold');
        WriteEndOfTableCell;

        WriteStartOfTableCell('itemdesc');
        WriteItemShortDescription(Item);
        WriteEndOfTableCell;
        WriteEndOfTableRow;
      end;
      WriteEndOfTable;
    end;
    WriteFooter;
    WriteAppInfo;
    WriteEndOfDocument;
    CloseStream;
  end;

  { Writes a Hierarchy list - this is more useful than the simple class list }
  procedure WriteHierarchy;
  { todo -o twm: Make this recursive to handle closing </li> easily }

    procedure WriteLevel(lst: TDescriptionItem);
    var
      i: integer;
      item: TDescriptionItem;
    begin
      if IsEmpty(lst) then
        exit;
      WriteDirectLine('<ul class="hierarchylevel">');
      for i := 0 to lst.Count - 1 do begin
        WriteDirect('<li>');
        item := lst.ItemAt(i);
        if Item.PasItem = nil then
          WriteConverted(item.Name)
        else
          WriteLink(Item.PasItem.FullLink, ConvertString(item.Name), 'bold');
        WriteLevel(item);
        WriteDirectLine('</li>');
      end;
      WriteDirectLine('</ul>');
    end;

  begin
    CreateClassHierarchy;

    if not CreateOverviewStream(ofClassHierarchy) then
      Exit;

    if IsEmpty(FClassHierarchy) then begin
      WriteStartOfParagraph;
      WriteConverted(FLanguage.Translation[trNoCIOsForHierarchy]);
      WriteEndOfParagraph;
    end else begin
      WriteLevel(FClassHierarchy);
    end;

    WriteFooter;
    WriteAppInfo;
    WriteEndOfDocument;

    CloseStream;
  end;

  procedure WriteItemsOverviewFile(Overview: TCreatedOverviewFile;
    Items: TPasItems);
  var
    Item: TPasItem;
    j: Integer;
  begin
    if not CreateOverviewStream(Overview) then Exit;
    
    if not ObjectVectorIsNilOrEmpty(Items) then 
    begin
      WriteStartOfTable3Columns('itemstable',
        FLanguage.Translation[trName], 
        FLanguage.Translation[trUnit],
        FLanguage.Translation[trDescription]);

      Items.SortShallow;

      for j := 0 to Items.Count - 1 do
      begin
        Item := Items.PasItemAt[j];
        WriteStartOfTableRow('');

        WriteStartOfTableCell('itemname');
        WriteLink(Item.FullLink, Item.Name, 'bold');
        WriteEndOfTableCell;

        WriteStartOfTableCell('itemunit');
        WriteLink(Item.MyUnit.FullLink, Item.MyUnit.Name, 'bold');
        WriteEndOfTableCell;

        WriteStartOfTableCell('itemdesc');
        WriteItemShortDescription(Item);
        WriteEndOfTableCell;

        WriteEndOfTableRow;
      end;
      WriteEndOfTable;
    end else
    begin
      WriteStartOfParagraph;
      WriteConverted(FLanguage.Translation[
        OverviewFilesInfo[Overview].NoItemsTranslationId]);
      WriteEndOfParagraph;
    end;

    WriteFooter;
    WriteAppInfo;
    WriteEndOfDocument;
    CloseStream;
  end;

var
  ItemsToCopy: TPasItems;
  PartialItems: TPasItems;
  TotalItems: TPasItems; // Collect all Items for final listing.
  PU: TPasUnit;
  Overview: TCreatedOverviewFile;
  j: Integer;
begin //WriteOverviewFiles
  WriteUnitOverviewFile;
  WriteHierarchy;

  // Make sure we don't free the Items when we free the container.
  TotalItems := TPasItems.Create(False);
  try
    for Overview := ofCios to HighCreatedOverviewFile do begin
      // Make sure we don't free the Items when we free the container.
      PartialItems := TPasItems.Create(False);
      try
        for j := 0 to Units.Count - 1 do begin
          PU := Units.UnitAt[j];
          case Overview of
            ofCIos                  : ItemsToCopy := PU.CIOs;
            ofTypes                 : ItemsToCopy := PU.Types;
            ofVariables             : ItemsToCopy := PU.Variables;
            ofConstants             : ItemsToCopy := PU.Constants;
            ofFunctionsAndProcedures: ItemsToCopy := PU.FuncsProcs;
          else
            ItemsToCopy := nil;
          end;
          PartialItems.InsertItems(ItemsToCopy);
        end;

        WriteItemsOverviewFile(Overview, PartialItems);

        TotalItems.InsertItems(PartialItems);
      finally PartialItems.Free end;
    end;

    WriteItemsOverviewFile(ofIdentifiers, TotalItems);
  finally TotalItems.Free end;
end;

{ ---------------------------------------------------------------------------- }

procedure TFullHTMLDocGenerator.WriteDocumentation;
begin
(* Problem: skip inherited GenHTML!
  Solution: made method WriteDocumentationGen.
*)
  StartSpellChecking('sgml');
  WriteDocumentationGen; //bypass inherited WriteDocumentation
  WriteUnits(1); //calls WriteUnit() for every unit.
  WriteBinaryFiles;
  WriteOverviewFiles;
  WriteVisibilityLegendFile;
  WriteIntroduction;
  WriteConclusion;
  WriteFramesetFiles;
  if UseTipueSearch then begin
    DoMessage(2, pmtInformation,
      'Writing additional files for tipue search engine', []);
    TipueAddFiles(Units, Introduction, Conclusion, MetaContentType,
      DestinationDirectory);
  end;
  EndSpellChecking;
end;

{$IFDEF old}
procedure TFullHTMLDocGenerator.WriteUnit(const HL: integer; const U: TPasUnit);
type
(* Menu bar entries.
*)
  TSections = (dsDescription, dsUses, dsClasses, dsFuncsProcs,
    dsTypes, dsConstants, dsVariables);
  TSectionAnchors = array[TSections] of string;
const
//ordered menu entries
  //SectionIDs: array[TSections] of TTranslationID = (
  SectionIDs: TSectionsInMenu = (
    trDescription, trUses, trClasses, trFunctionsAndProcedures,
    trTypes, trConstants, trVariables
  );

  procedure WriteUnitDescription(HL: integer; U: TPasUnit);
  begin
    WriteHeading(HL, 'description', FLanguage.Translation[trDescription]);
    WriteItemLongDescription(1, U);
  end;

  procedure WriteUnitUses(const HL: integer; U: TPasUnit);
  var
    i: Integer;
    ULink: TPasItem;
  begin
  (* Write section (anchor+caption), and list of links (merge with WriteSeeAlso?)
    Added: write section anchor.
  *)
    if WriteUsesClause and not IsEmpty(U.UsesUnits) then begin
      //WriteHeading(HL, 'uses', FLanguage.Translation[trUses], SectionAnchors[dsUses]);
      WriteSectionHeading(HL, 'uses', trUses);
      WriteDirect('<ul class="useslist">');
      for i := 0 to U.UsesUnits.Count-1 do begin
        WriteDirect('<li>');
        ULink := u.UsesUnits.PasItemAt(i);
        if ULink <> nil then begin
          WriteLink(ULink.FullLink, U.UsesUnits.Items[i].Name, '');
        end else begin
          WriteConverted(U.UsesUnits.Items[i].Name);
        end;
        WriteDirect('</li>');
      end;
      WriteDirect('</ul>');
    end;
  end;

{$IFDEF old}
var
  i, j: integer;
  SectionsAvailable: TSectionSet;
  d: TDescriptionItem;
{$ELSE}
{$ENDIF}
begin
{$IFDEF old}
  case CreateStream(U.OutputFileName, true) of
    csError: begin //DoError?
      DoMessage(1, pmtError, 'Could not create HTML unit doc file for unit %s.', [U.Name]);
      Exit;
    end;
  end;

  DoMessage(2, pmtInformation, 'Writing Docs for unit "%s"', [U.Name]);
  WriteStartOfDocument(U.Name);
  WriteHeading(HL, 'unit', FLanguage.Translation[U.id] + ' ' + U.Name);

{$IFDEF old}
  SectionsAvailable := FindSections(U);
  if not WriteUsesClause then
    Exclude(SectionsAvailable, trUses);
  WriteSectionMenu(SectionIDs, SectionsAvailable);
{$ELSE}
  WriteSectionMenu(U);
{$ENDIF}

  for i := 0 to U.Count - 1 do begin
    d := U.ItemAt(i);
    case d.ID of
    trDescription:
      begin
      {$IFDEF old}
        WriteAnchor(SectionAnchors[dsDescription]);
        WriteUnitDescription(HL + 1, U);
      {$ELSE}
      //= WriteUnitDescription
        WriteSectionHeading(HL, 'description', trDescription);
        WriteItemLongDescription(U);  //d.PasItem); - description item!
      {$ENDIF}
      end;
    trOverview:
      begin
        WriteHeading(HL + 1, 'overview', FLanguage.Translation[trOverview]);
        for j := 0 to d.Count - 1 do begin
          WriteMemberSummary(d.ItemAt(j), False, HL+1); //+2?
        end;

        WriteHeading(HL + 1, 'description', FLanguage.Translation[trDescription]);
        for j := 0 to d.Count - 1 do begin
        //exclude CIOs from details!
          if d.Items[j].ID <> trClasses then
            WriteMembersDetailed(d.ItemAt(j), False, HL+2);
        end;
      end;
    trUses:
      begin
        //WriteAnchor(SectionAnchors[dsUses]);
        WriteUnitUses(HL + 1, U);
      end;
    trAuthors:
      WriteAuthors(HL + 1, d);  // CIO.Authors);
    trCreated, trLastModified:
      WriteDate(HL + 1, d);  //CIO.Created, CIO.LastMod);
    trSeeAlso:
      WriteSeeAlso(d, U);
    else
    end;
  end;

  WriteFooter;
  WriteAppInfo;
  WriteEndOfDocument;
  CloseStream;
{$ELSE}
  WriteItem(1, U);
{$ENDIF}
  WriteCIOs(HL, U.CIOs);
end;
{$ELSE}
procedure TFullHTMLDocGenerator.WriteUnit(const HL: integer; const U: TPasUnit);
{$IFDEF new}
var
  i: integer;
  p: TPasItem;
{$ELSE}
{$ENDIF}
begin
//called from?
  //if u.ToBeExcluded then exit;
  WriteItem(1, U);
{ TODO : Write all members with an distinct output filename }
{$IFnDEF new}
  WriteCIOs(1, U.CIOs);
{$ELSE}
  for i := 0 to u.Members.Count - 1 do begin
    p := u.Members.PasItemAt(i);
    if p.OutputFileName <> '' then
      WriteCIO(1, p); //deserve specialized file formatting!
  end;
{$ENDIF}
end;
{$ENDIF}

{ ---------------------------------------------------------------------------- }

procedure TFullHTMLDocGenerator.WriteExternalCore(
  const ExternalItem: TExternalItem;
  const Id: TTranslationID);
var
  HL: integer;
begin
  case CreateStream(ExternalItem.OutputFileName, true) of
    csError: begin
      DoMessage(1, pmtError, 'Could not create HTML unit doc file '
        + 'for the %s file %s.', [FLanguage.Translation[Id], ExternalItem.Name]);
      Exit;
    end;
  end;

  WriteStartOfDocument(ExternalItem.ShortTitle);

  HL := 1;

  WriteHeading(HL, 'externalitem', ExternalItem.Title);

  WriteSpellChecked(ExternalItem.DetailedDescription);

  WriteAuthors(HL + 1, ExternalItem.Authors);
  WriteDates(HL + 1, ExternalItem.Created, ExternalItem.LastMod);
  WriteFooter;
  WriteAppInfo;
  WriteEndOfDocument;
  CloseStream;
end;

procedure TFullHTMLDocGenerator.WriteDescriptionItem(HL: integer;
  AItem: TDescriptionItem; PasItem: TPasItem);
var
  item: TDescriptionItem;
  InTable: boolean; //parameter?

//write an ancestor
  procedure WriteAncestor(Item: TDescriptionItem);
  var
    CIO: TPasItem;
  begin
    CIO := Item.PasItem;
    if not Assigned(CIO) then begin
      WriteDirectLine('<li class="ancestor">' + Item.Name + '</li>');
      { recursion ends here, when the item is an external class }
    end else begin
      WriteDirectLine('<li class="ancestor">' +
        MakeItemLink(CIO, CIO.Name, lcNormal) + '</li>')
    end;
  end;

//writes the parameters or exceptions list
  procedure WriteParamsOrRaises(Func: TPasMethod; //Caption: TTranslationID;
    List: TDescriptionItem; LinkToParamNames: boolean;
    const CssListClass: string);

    procedure WriteParameter(const ParamName: string; const Desc: string);
    begin
    //Write definition list entry
      { Note that <dt> and <dd> below don't need any CSS class,
        they can be accessed via "dl.parameters dt" or "dl.parameters dd"
        (assuming that CssListClass = 'parameters'). }
      WriteDirect('<dt>');
        WriteDirect(ParamName);
      WriteDirectLine('</dt>');
      WriteDirect('<dd>');
        WriteSpellChecked(Desc);
      WriteDirectLine('</dd>');
    end;

  var
    i: integer;
    ParamName: string;
    p: TDescriptionItem;
  begin
    if IsEmpty(List) then
      Exit;

    //WriteDescriptionSectionHeading(Caption);
    WriteDescriptionSectionHeading(List.ID);
    WriteDirectLine('<dl class="' + CssListClass + '">');
    for i := 0 to List.Count - 1 do begin
      p := List.ItemAt(i);
      ParamName := p.Name;

      if LinkToParamNames then
       ParamName := SearchLink(ParamName, Func, '', true);

      WriteParameter(ParamName, p.Value);
    end;
    WriteDirectLine('</dl>');
  end;

  procedure WriteReturnDesc(ReturnDesc: TDescriptionItem);
  var
    s: string;
  begin
    if (ReturnDesc = nil) then
      exit;
    s := ReturnDesc.Text;
    if s = '' then
      exit;
    WriteDescriptionSectionHeading(ReturnDesc.ID);
    WriteDirect('<p class="return">');
      WriteSpellChecked(s); //(ReturnDesc.Text);
    WriteDirect('</p>');
  end;

//write unit uses list
  procedure WriteUnitUses;
  var
    i: Integer;
    ULink: TPasItem;
  begin
  (* Write section (anchor+caption), and list of links (merge with WriteSeeAlso?)
    Added: write section anchor.
  *)
    WriteSectionHeading(HL+1, 'uses', trUses);
    WriteDirect('<ul class="useslist">');
    for i := 0 to AItem.Count-1 do begin
      WriteDirect('<li>');
        ULink := AItem.PasItemAt(i);
        if ULink <> nil then begin
          WriteLink(ULink.FullLink, AItem.Items[i].Name, '');
        end else begin
          WriteConverted(AItem.Items[i].Name);
        end;
      WriteDirect('</li>');
    end;
    WriteDirect('</ul>');
  end;

  procedure WriteValueList(HL: integer; Items: TDescriptionItem);
  var
    i: integer;
    s: string;
  begin //enum
  //grouped!?
    s := FLanguage.Translation[Items.id];
    if items.Name <> '' then
      s := s + ' - ' + Items.Name;
    //WriteDescriptionSectionHeading(Items.ID);
    WriteHeading(HL+1, 'description_section', s);
    WriteDirectLine('<ul>');
    for i := 0 to Items.Count - 1 do begin
      WriteDirectLine('<li>');
      WriteConverted(Items.PasItemAt(i).FullDeclaration);
      WriteConverted(': ');
      //WriteItemLongDescription(Items.PasItemAt(i), false);
      WriteDescription(HL+1, Items.PasItemAt(i));
      WriteDirectLine('</li>');
    end;
    WriteDirectLine('</ul>');
  end;

var
  i: integer;
begin //WriteDescriptionItem
  InTable := HL > 2;
  case AItem.ID of
  trUnit: //see above, depending on file type
    begin
      WriteSectionHeading(HL+1, 'unit', trUnit);
      WriteStartOfParagraph('unitlink');
        WriteLink(AItem.PasItem.FullLink, ConvertString(AItem.Name), '');
      WriteEndOfParagraph;
    end;
  trUses: //units only
    begin
      WriteUnitUses;  //(HL + 1, U);
    end;
  trDeclaration: //IS declaration item
    if InTable then
      //declaration is table heading
    else begin
      WriteSectionHeading(HL + 1, 'declaration', trDeclaration);
      WriteStartOfParagraph('declaration');
        WriteStartOfCode;
          WriteConverted(AItem.Caption);
        WriteEndOfCode;
      WriteEndOfParagraph;
    end;
  trDescription:  //IS description, but only containing abstract+detailed description
    begin
      if not InTable then
        WriteSectionHeading(HL + 1, 'description', trDescription);
    //todo: both items, for abstract+details + other info (attributes...)
      //WriteItemLongDescription(HL+1, PasItem);
      WriteDescription(HL+1, PasItem);
    end;
  trHierarchy:  //class types only
    begin
      WriteSectionHeading(HL + 1, 'hierarchy', trHierarchy);
      WriteDirect('<ul class="hierarchy">');
        for i := 0 to AItem.Count - 1 do begin
          WriteAncestor(AItem.Items[i]);
        end;
      WriteDirect('</ul>');
    end;
  trOverview: //scoped types, depending on file type
  //enums and procs should not have trOverview for their members!
  //write details depending on project type! (PasDoc: here, Help: distinct files)
    if InTable then begin
      for i := 0 to AItem.Count - 1 do begin
        item := AItem.ItemAt(i); //expect: Classes, Variables...
        WriteMembersDetailed(item, PasItem.Kind in CIOClassTypes, HL+1);
      end;
    end else begin
      WriteHeading(HL + 1, 'overview', FLanguage.Translation[trOverview]);
      for i := 0 to AItem.Count - 1 do begin
        WriteMemberSummary(AItem.ItemAt(i), PasItem.Kind in CIOClassTypes, HL+1);
      end;

      WriteHeading(HL + 1, 'description', FLanguage.Translation[trDescription]);
      for i := 0 to AItem.Count - 1 do begin
        item := AItem.ItemAt(i); //expect: Classes, Variables...
        WriteMembersDetailed(item, PasItem.Kind in CIOClassTypes, HL+1);
      end;
    end;
{$IFDEF new}
  trSubroutine: //special overview?
    //WriteMembersDetailed(AItem, false, HL+1);
    WriteAllSections(HL+1, AItem);
{$ELSE}
{$ENDIF}
  trExceptionsRaised:
    WriteParamsOrRaises(PasItem as TPasMethod, AItem, True, 'raises');
  trParameters:
    WriteParamsOrRaises(PasItem as TPasMethod, AItem, False, 'parameters');
  trReturns:
    WriteReturnDesc(AItem);
  trValues:
    begin
    {$IFDEF old}
     //assume immediate member list. todo: segmented list
      //WriteMembersDetailed(AItem, False, HL);
      WriteValueList(HL, AItem);
    {$ELSE}
    //ignore top level list, containing member groups.
      for i := 0 to AItem.Count - 1 do begin
        item := AItem.ItemAt(i); //expect: trValues, anonymous or named
        //WriteMembersDetailed(item, PasItem.Kind in CIOClassTypes, HL+1);
        WriteValueList(HL, item);
      end;
    {$ENDIF}
    end;
  trAuthors:
    WriteAuthors(HL + 1, AItem);  // AItem.Authors);
  trCreated, trLastModified:
    WriteDate(HL + 1, AItem);  //AItem.Created, AItem.LastMod);
  trSeeAlso:
    WriteSeeAlso(AItem, PasItem);
  else  //case
  //write dump
    WriteHeading(HL+1, '', FLanguage.Translation[AItem.id]);
    WriteStartOfParagraph;
      WriteDirect(AItem.Name);
      WriteDirect('<b>');
      if AItem.Value <> '' then
        WriteConverted(AItem.Value, True);
    WriteEndOfParagraph;
    if AItem.Count > 0 then begin
      for i := 0 to AItem.Count - 1 do begin
        item := AItem.ItemAt(i);
        WriteStartOfParagraph;
          WriteDescriptionItem(HL+1, item, PasItem);
        WriteEndOfParagraph;
      end;
    end;
  end;
end;

procedure TFullHTMLDocGenerator.WriteItem(HL: integer; AItem: TPasItem);
var
  //InFile: boolean;
  //SectionsAvailable: TSectionSet;
  s, t: string;
  i: integer;
  d: TDescriptionItem;
begin //from WriteCIO
  if not Assigned(AItem) then Exit;

(* When the description is written to an distinct file, provide:
  - a section menu
  - a unit reference
(when HL=1?)
*)
  //if AItem.OutputFileName <> '' then begin
  if AItem.OutputFileName <> '' then begin
    case CreateStream(AItem.OutputFileName, true) of
      csError: begin //DoError?
        DoMessage(1, pmtError, 'Could not create HTML doc file for %s.', [AItem.Name]);
        Exit;
      end;
    end;
    CurFile := AItem.OutputFileName;
    DoMessage(2, pmtInformation, 'Writing Docs for "%s"', [AItem.Name]);
  //write file header
  {$IFDEF old}
    s := GetCIOTypeName(AItem.Kind) + ' ' + AItem.Name;
    WriteStartOfDocument(AItem.MyUnit.Name + ': ' + s);
    WriteHeading(HL, 'AItem', s);
    WriteAnchor(AItem.Name);
    SectionsAvailable := FindSections(AItem);
    WriteSectionMenu(GetSectionsInMenu(AItem), SectionsAvailable);

  (* Every item knows about its unit, but doesn't know whether it has to provide
    the unit as a description item.
    A unit reference has to be shown for all those items,
    which are displayed in their own description file.
  *)
  //write unit link
    if not (AItem is TPasUnit) then begin
      WriteSectionHeading(HL+1, 'unit', trUnit);
      WriteStartOfParagraph('unitlink');
        WriteLink(AItem.MyUnit.FullLink, ConvertString(AItem.MyUnit.Name), '');
      WriteEndOfParagraph;
    end;
  {$ELSE}
    HL := 1;  //top level of file
    //if not (AItem is TPasUnit) then
    s := FLanguage.Translation[AItem.id] + ' ' + AItem.Name;
    if Title = '' then
      t := AItem.MyUnit.Name + ': ' + s
    else
      t := s;
    WriteStartOfDocument(t);
  //anchor for best compatibility?
    WriteHeading(HL, 'AItem', s, AItem.Name);
    //WriteAnchor(AItem.Name);
    WriteSectionMenu(AItem);
  {$ENDIF}
  end;

  for i := 0 to AItem.Count - 1 do begin
    d := AItem.ItemAt(i);
    WriteDescriptionItem(HL, d, AItem);
  end;

//eventually finish file
  if AItem.OutputFileName <> '' then begin
    WriteFooter;
    WriteAppInfo;
    WriteEndOfDocument;
    CloseStream;
  end;
end;

function TFullHTMLDocGenerator.GetSectionsInMenu(
  item: TBaseItem): TSectionsInMenu;
const
  NoMenu: TSectionsInMenu = (
    trNoTrans, trNoTrans, trNoTrans, trNoTrans,
    trNoTrans, trNoTrans, trNoTrans
  );
  UnitMenu: TSectionsInMenu = (
    trDescription, trUses, trClasses, trFunctionsAndProcedures,
    trTypes, trConstants, trVariables
  );
  CIOmenu: TSectionsInMenu = (
    trDescription, trHierarchy, trFields, trMethods, trProperties,
    trNoTrans, trNoTrans
  );
begin
  if item is TPasUnit then
    Result := UnitMenu
  else if item is TPasCio then
    Result := CIOmenu
  else
    Result := NoMenu;
end;

end.

