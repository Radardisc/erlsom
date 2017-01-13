%%% Copyright (C) 2006 - 2011 Willem de Jong
%%%
%%% This file is part of Erlsom.
%%%
%%% Erlsom is free software: you can redistribute it and/or modify
%%% it under the terms of the GNU Lesser General Public License as 
%%% published by the Free Software Foundation, either version 3 of 
%%% the License, or (at your option) any later version.
%%%
%%% Erlsom is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%%% GNU Lesser General Public License for more details.
%%%
%%% You should have received a copy of the GNU Lesser General Public 
%%% License along with Erlsom.  If not, see 
%%% <http://www.gnu.org/licenses/>.
%%%
%%% Author contact: w.a.de.jong@gmail.com

%%% ====================================================================
%%% A couple of functions used by erlsom_sax (for each encoding variant)
%%% ====================================================================

%%% Version: 20-01-2008

-module(erlsom_sax_lib).

-include("erlsom_sax.hrl").
-export([test/0]).
-export([findCycle/4]).
-export([continueFun/3]).
-export([continueFun/4]).
-export([continueFun2/4]).
-export([continueFun/5]).
-export([continueFun/6]).
-export([continueFun2/6]).
-export([mapStartPrefixMappingCallback/3]).
-export([mapEndPrefixMappingCallback/3]).
-export([createStartTagEvent/3]).
-export([translateReference/5]).

%% there are 4 variants of this function, with different numbers of arguments
%% The names of the first arguments aren't really meaningful, they can
%% be anything - they are only there to be passed to 'ParseFun'.
continueFun(V1, V2, V3, T, State, ParseFun) ->
  {Tail, ContinuationState2} = 
    (State#erlsom_sax_state.continuation_fun)(T, State#erlsom_sax_state.continuation_state),
  case Tail of 
    T -> throw({error, "Malformed: Unexpected end of data"});
    _ -> 
      ParseFun(V1, V2, V3, Tail, 
        State#erlsom_sax_state{continuation_state = ContinuationState2})
  end.

continueFun2(T, V1, V2, V3, State, ParseFun) ->
  {Tail, ContinuationState2} = 
    (State#erlsom_sax_state.continuation_fun)(T, State#erlsom_sax_state.continuation_state),
  case Tail of 
    T -> throw({error, "Malformed: Unexpected end of data"});
    _ -> 
      ParseFun(Tail, V1, V2, V3, 
        State#erlsom_sax_state{continuation_state = ContinuationState2})
  end.

continueFun(Prefix, Head, T, State, ParseFun) ->
  {Tail, ContinuationState2} = 
    (State#erlsom_sax_state.continuation_fun)(T, State#erlsom_sax_state.continuation_state),
  case Tail of 
    T -> throw({error, "Malformed: Unexpected end of data"});
    _ -> 
      ParseFun(Prefix, Head, Tail, 
        State#erlsom_sax_state{continuation_state = ContinuationState2})
  end.

continueFun(Head, T, State, ParseFun) ->
  {Tail, ContinuationState2} = 
    (State#erlsom_sax_state.continuation_fun)(T, State#erlsom_sax_state.continuation_state),
  case Tail of 
    T -> throw({error, "Malformed: Unexpected end of data"});
    _ -> 
      ParseFun(Head, Tail, 
        State#erlsom_sax_state{continuation_state = ContinuationState2})
  end.

continueFun2(T, Head, State, ParseFun) ->
  {Tail, ContinuationState2} = 
    (State#erlsom_sax_state.continuation_fun)(T, State#erlsom_sax_state.continuation_state),
  case Tail of 
    T -> throw({error, "Malformed: Unexpected end of data"});
    _ -> 
      ParseFun(Tail, Head,
        State#erlsom_sax_state{continuation_state = ContinuationState2})
  end.

continueFun(T, State, ParseFun) ->
  {Tail, ContinuationState2} = 
    (State#erlsom_sax_state.continuation_fun)(T, State#erlsom_sax_state.continuation_state),
  case Tail of 
    T -> throw({error, "Malformed: Unexpected end of data"});
    _ -> 
      ParseFun(Tail, 
        State#erlsom_sax_state{continuation_state = ContinuationState2})
  end.

 
%% function to call the Callback function for all elements in a list of 'new namespaces'.
%% returns State
mapStartPrefixMappingCallback([{Prefix, Uri} | Tail], State, Callback) ->
  mapStartPrefixMappingCallback(Tail, Callback({startPrefixMapping, Prefix, Uri}, State), Callback);
mapStartPrefixMappingCallback([], State, _Callback) ->
  State.

%% function to call the Callback function for all elements in a list of 'new namespaces'.
%% returns State
mapEndPrefixMappingCallback([{Prefix, _Uri} | Tail], State, Callback) ->
  mapEndPrefixMappingCallback(Tail, Callback({endPrefixMapping, Prefix}, State), Callback);
mapEndPrefixMappingCallback([], State, _Callback) ->
  State.


%% StartTag = {Prefix, LocalName, QualifiedName}
%% Attributes = list of Attribute
%% Attribute = {{Prefix, LocalName} Value}
%%
%% returns: {Name, Attributes2, NewNamespaces}
%% Name = {URI, LocalName, QualifiedName}
%% Attributes2 = list of Attribute2
%% Attribute2 = #attribute
%% NewNamespaces = list of {Prefix, URI} (prefix can be []).
%%
%% Namespaces are in such an order that namespace of the 'closest ancestors' 
%% are in front. That way the right element will be found, even if a prefix is 
%% used more than once in the document.
%%
createStartTagEvent(StartTag, Namespaces, Attributes) ->
  
  %% find the namespace definitions in the attributes
  {NewNamespaces, OtherAttributes} = lookForNamespaces([], [], Attributes),
  AllNamespaces = NewNamespaces ++ Namespaces,

  %% add the Uri to the tag name (if applicable)
  Name = tagNameTuple(StartTag, AllNamespaces),

  %% add the URIs to the attribute names (if applicable)
  Attributes2 = attributeNameTuples([], OtherAttributes, AllNamespaces),

  {Name, Attributes2, NewNamespaces}.

%% returns {Namespaces, OtherAttributes}, where 
%%   Namespaces = a list of tuples {Prefix, URI} 
%%   OtherAttributes = a list of tuples {Name, Value}
%%
lookForNamespaces(Namespaces, OtherAttributes, [Head | Tail]) ->
  {{Prefix, LocalName, _QName}, Value} = Head,
  if 
    Prefix == "xmlns" ->
      lookForNamespaces([{LocalName, Value} | Namespaces], 
                         OtherAttributes, Tail);
    Prefix == [],  LocalName == "xmlns" ->
      lookForNamespaces([{[], Value} | Namespaces], 
                        OtherAttributes, Tail);
    true -> 
      lookForNamespaces(Namespaces, [Head | OtherAttributes], Tail)
  end;
  
lookForNamespaces(Namespaces, OtherAttributes, []) -> 
  {Namespaces, OtherAttributes}.

%% StartTag = {Prefix, LocalName, QualifiedName} 
%% Namespaces = list of {Prefix, URI} (prefix can be []).
%%
%% Returns {Uri, LocalName, Prefix}
%%
%% TODO: error if not found? special treatment of 'xml:lang'?
tagNameTuple(StartTag, Namespaces) ->
  {Prefix, LocalName, _QName} = StartTag,
  case lists:keysearch(Prefix, 1, Namespaces) of
    {value, {Prefix, Uri}} -> {Uri, LocalName, Prefix};
    false -> {[], LocalName, Prefix}
  end.
      

%% Attributes = list of Attribute
%% Attribute = {{Prefix, LocalName} Value}
%% Namespaces = list of {Prefix, URI} (prefix can be []).
%%
%% Returns a list of #attribute records
attributeNameTuples(ProcessedAttributes, 
                    [{AttributeName, Value} | Attributes], Namespaces) ->
  {Uri, LocalName, Prefix} = attributeNameTuple(AttributeName, Namespaces),
  attributeNameTuples([#attribute{localName= LocalName,
                                  prefix = Prefix,
				  uri = Uri,
				  value = Value} | ProcessedAttributes], 
                      Attributes, Namespaces);

attributeNameTuples(ProcessedAttributes, [], _) ->
  ProcessedAttributes.

%% AttributeName = {Prefix, LocalName, QualifiedName}
%% Namespaces = list of {Prefix, URI} (prefix can be []).
%%
%% Returns {Uri, LocalName, Prefix}.
%% Difference with TagNameTuple: attributes without prefix do NOT belong
%% to the default namespace.
attributeNameTuple(AttributeName, Namespaces) ->
  {Prefix, LocalName, _} = AttributeName,
  if 
    Prefix == [] -> {[], LocalName, LocalName};
    true -> 
      case lists:keysearch(Prefix, 1, Namespaces) of
        {value, {Prefix, Uri}} ->
	    {Uri, LocalName, Prefix};
        false ->
            case Prefix of
              "xml" -> {"http://www.w3.org/XML/1998/namespace", LocalName, Prefix};
              _ -> {[], LocalName, Prefix}
            end
      end
  end.

%% simplistic function to find a cycle in a list [{a, b}, {b, c}, ...]
%% or if there is a path longer than MaxDepth.
%% The edge A, B is added; the rest of the graph is known
%% to be acyclical. So we start from B (To) and look for a path
%% to A (Current).
findCycle(To, Current, Edges, MaxDepth) ->
  findCycle(To, Current, Edges, MaxDepth, 1).

findCycle(_To, _Current, [], _MaxD, _CurrentD) ->
  false;
findCycle(To, Current, Edges, MaxD, CurrentD) ->
  %% take the next edge from edge from Current 
  case lists:keyfind(To, 1, Edges) of
    _ when MaxD == CurrentD ->
      max_depth; %% reached Max Depth
    false -> 
      false;
    {_, Current} ->
      cycle; %% found a cycle
    {_, B} ->
      RemainingEdges = lists:keydelete(To, 1, Edges),
      case findCycle(B, Current, RemainingEdges, MaxD, CurrentD + 1) of
        false ->
          findCycle(To, Current, RemainingEdges, MaxD, CurrentD);
        Other ->
          Other
      end
  end.
  
  

%% returns: {Head2, Tail2, State2}
%% Character entities are added to the 'head' (the bit that was parsed already),
%% other entities are added to the tail (they still have to be parsed).
%% The problem here is that we have to make sure that we don't get into an infinite 
%% loop. This solved as follows:
%% We proceed by parsing only the entity (while registring in the state that we 
%% are parsing this particular entity). However, we replace the continuation function 
%% by something that simply returns (in stead of calling the function that it was 
%% working on recursively). We then proceed. 
%% Before starting to work on this entity, we need to check that we are not already 
%% parsing this entity (because that would mean an infinite loop).
translateReference(Encoding, Reference, Context, Tail, State) ->
  %% in the context of a definition, character references have to be replaced
  %% (and others not). 
  case Reference of
    [$#, $x | Tail1] -> %% hex number of char's code point
      %% unfortunately this function accepts illegal values
      %% to do: replace by something that throws an error in case of
      %% an illegal value
      {[httpd_util:hexlist_to_integer(Tail1)], Tail, State};
    [$# | Tail1] -> %% dec number of char's code point
      case catch list_to_integer(Tail1) of
        {'EXIT', _} -> throw({error, "Malformed: Illegal character in reference"});
	%% to do: check on legal character.
	Other -> {[Other], Tail, State}
      end;
    _ -> 
      translateReferenceNonCharacter(Encoding,Reference, Context, Tail, State)
  end.

translateReferenceNonCharacter(Encoding,Reference, Context, Tail, 
  State = #erlsom_sax_state{current_entity = CurrentEntity, 
                            max_entity_depth = MaxDepth,
                            entity_relations = Relations,
                            entity_size_acc = TotalSize,
                            max_expanded_entity_size = MaxSize}) ->
  case Context of 
    definition ->
      case MaxDepth of
        0 -> throw({error, "Entities nested too deep"});
        _ -> ok
      end,
      %% check on circular definition
      NewRelation = {CurrentEntity, Reference},
      case lists:member(NewRelation, Relations) of
        true ->
          Relations2 = Relations;
        false ->
          Relations2 = [NewRelation | Relations],
          case erlsom_sax_lib:findCycle(Reference, CurrentEntity, Relations2, MaxDepth) of
            cycle -> 
              throw({error, "Malformed: Cycle in entity definitions"});
            max_depth -> 
              throw({error, "Entities nested too deep"});
            _ -> ok
          end
      end,
      %% don't replace
      {lists:reverse("&" ++ Reference ++ ";"), Tail, State#erlsom_sax_state{entity_relations = Relations2}};
    _ ->
      {Translation, Type} = finallyTranslateReference(Reference, Context, State),
      NewTotal = TotalSize + length(Translation),
      if
        NewTotal > MaxSize ->
          throw({error, "Too many characters in expanded entities"});
        true ->
          ok
      end,
      case Context of attribute ->
        %% replace, add to the parsed text (head)
        {Translation, Tail, State#erlsom_sax_state{entity_size_acc = NewTotal}};
      _ -> %% element or parameter
        case Type of 
          user_defined ->
            %% replace, encode again and put back into the input stream (Tail)
            TEncoded = encode(Encoding,Translation),
            {[], combine(TEncoded, Tail), State#erlsom_sax_state{entity_size_acc = NewTotal}};
          _ ->
            {Translation, Tail, State#erlsom_sax_state{entity_size_acc = NewTotal}}
        end
      end
  end.
  
  
finallyTranslateReference(Reference, Context, State) ->
  case Reference of
    "amp" -> {[$&], other};
    "lt" -> {[$<], other};
    "gt" -> {[$>], other};
    "apos" -> {[39], other}; %% apostrof
    "quot" -> {[34], other}; %% quote
  _ -> 
    case State#erlsom_sax_state.expand_entities of
      true -> 
        ListOfEntities = case Context of 
          parameter -> State#erlsom_sax_state.par_entities;
          element -> State#erlsom_sax_state.entities
        end,
        case lists:keysearch(Reference, 1, ListOfEntities) of
          {value, {_, EntityText}} -> 
            {EntityText, user_defined};
          _ ->
            throw({error, "Malformed: unknown reference: " ++ Reference})
        end;
      false ->
        throw({error, "Entity expansion disabled, found reference " ++ Reference})
    end
  end.  



combine(Head, Tail) when is_binary(Head), is_binary(Tail) ->
    <<Head/binary, Tail/binary>>;
combine(Head, Tail) when is_list(Head), is_list(Tail) ->
    Head ++ Tail.

%The encoding parameter comes from each of the calling sax files.
encode(utf8,List) ->
  list_to_binary(erlsom_ucs:to_utf8(List));
encode(u16b,List) ->
  list_to_binary(xmerl_ucs:to_utf16be(List));
encode(u16l,List) ->
  list_to_binary(xmerl_ucs:to_utf16le(List));
encode(lat1,List) ->
  list_to_binary(List);
encode(lat9,List) ->
  list_to_binary(List);
encode(list,List) ->
  List.



test() ->
  false = findCycle(b, a, [{a, b}], 2),
  max_depth  = findCycle(b, a, [{a, b}, {b, c}], 2),
  false = findCycle(b, a, [{a, b}, {b, c}], 3),
  false = findCycle(b, a, [{a, b}, {b, c}, {c, d}, {c, e}, 
                   {c, f}, {c, g}, {f, q}, {f, r}, {f, s},
                   {g, z}], 12),
  cycle  = findCycle(b, a, [{a, b}, {c, d}, {b, c}, {c, e}, 
                   {c, f}, {f, q}, {f, r}, {f, s}, {q, s},
                   {g, a}, {c, g}], 12),
  cycle  = findCycle(b, a, [{a, b}, {b, c}, {c, d}, {c, e}, 
                   {c, a}, {c, g}, {f, q}, {f, r}, {f, s},
                   {g, a}], 12).

