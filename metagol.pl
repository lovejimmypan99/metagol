:- module(metagol,[learn/4,pprint/1,member/2]).

:- use_module(library(lists)).


:- user:discontiguous(prim/1).
:- user:discontiguous(primcall/1).
:- user:discontiguous(primtest/1).

user:term_expansion(prim(P/A),[prim(P/A),primtest(List),(primcall(List):-Call)]):-
    functor(Call,P,A),
    Call=..List.

:- dynamic(functional/0).
:- dynamic(min_clauses/1).
:- dynamic(max_clauses/1).

default(min_clauses(1)).
default(max_clauses(6)).

get_option(X):-call(X),!.
get_option(X):-default(X).

learn(Name,Pos1,Neg1,G):-
  atom_to_list(Pos1,Pos2),
  atom_to_list(Neg1,Neg2),
  proveall(Name,Pos2,PS,G),
  nproveall(Name,Neg2,PS,G),
  (get_option(functional) -> check_functions(Pos2,PS,G); true).

proveall(Name,Atoms,PS,G):-
  iterator(N,M),
  format('% clauses: ~d invented predicates: ~d\n',[N,M]),
  init_sig(Name,M,PS),
  prove(Atoms,PS,N,[],G).

prove([],_,_,G,G).

prove(['@'(Atom)|Atoms],PS,MaxN,G1,G2):-
  !,
  user:call(Atom),
  prove(Atoms,PS,MaxN,G1,G2).

%% prim
prove([Atom|Atoms],PS,MaxN,G1,G2):-
  user:primtest(Atom),!,
  user:primcall(Atom),
  prove(Atoms,PS,MaxN,G1,G2).

%% use existing
prove([Atom|Atoms],PS1,MaxN,G1,G2):-
  Atom=[P|_],
  member(sub(Name,P,MetaSub),G1),
  once(user:metarule(Name,MetaSub,(Atom :- Body),_)),
  prove(Body,PS1,MaxN,G1,G3),
  prove(Atoms,PS1,MaxN,G3,G2).

%% use new
prove([Atom|Atoms],PS1,MaxN,G1,G2):-
  length(G1,L),
  L < MaxN,
  Atom=[P|Args],
  length(Args,A),
  append(_,[P/A|PS2],PS1),!, % slicing of signature
  user:metarule(Name,MetaSub,(Atom :- Body),PS2),
  not(memberchk(sub(Name,P,MetaSub),G1)),
  prove(Body,PS1,MaxN,[sub(Name,P,MetaSub)|G1],G3),
  prove(Atoms,PS1,MaxN,G3,G2).

inv_preds(0,_Name,[]) :- !.
inv_preds(M,Name,[Sk/_|PS]) :-
  atomic_list_concat([Name,'_',M],Sk),
  succ(Prev,M),
  inv_preds(Prev,Name,PS).

init_sig(Name,M,[Name/_|PS]):-
  inv_preds(M,Name,InvPreds),
  findall(Prim, user:prim(Prim), Prims),
  append(InvPreds,Prims,PS).

nproveall(_Name,[],_PS,_G).
nproveall(Name,[Atom|T],PS,G):-
  length(G,N),
  not(prove([Atom],PS,N,G,G)),
  nproveall(Name,T,PS,G).

iterator(N,M):-
  get_option(min_clauses(MIN)),
  get_option(max_clauses(MAX)),!,
  between(MIN,MAX,N),
  succ(MaxM,N),
  between(0,MaxM,M).

pprint([]).
pprint([sub(Name,_P,MetaSub)|T]):-
  user:metarule(Name,MetaSub,Clause,_),
  copy_term(Clause,X),
  numbervars(X,0,_),
  format('~q.~n', [X]),
  pprint(T).

atom_to_list([],[]).
atom_to_list([Atom|T],[AtomAsList|Out]):-
  Atom =..AtomAsList,
  atom_to_list(T,Out).

check_functions([],_PS,_G).

check_functions([Atom|Atoms],PS,G) :-
  check_function(Atom,PS,G),
  check_functions(Atoms,PS,G).

check_function([Head|Args],PS,G):-
  length(G,N),
  append(FuncArgs,[OrigReturn],Args),
  append(FuncArgs,[TestReturn],TestArgs),
  not((prove([[Head|TestArgs]],PS,N,G,G),TestReturn \= OrigReturn)).

%% expand metarules?
%% user:term_expansion(metarule(Name,Subs,(Head:-Body)),
%%   (
%%     metarule(Name,Subs,(Head:-Body),PS) :-
%%       Head = [P|_],
%%       selectchk(P,Subs,ToBind),
%%       metagol:bind_metasubs(ToBind,PS)
%%   )).

%% bind_metasubs([],_).
%% bind_metasubs([P|T],PS):-
%%   member(P/_,PS),
%%   bind_metasubs(T,PS).