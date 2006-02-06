/*
This file is part of OpenModelica.

Copyright (c) 1998-2005, Linkopings universitet, Department of
Computer and Information Science, PELAB

All rights reserved.

(The new BSD license, see also
http://www.opensource.org/licenses/bsd-license.php)


Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

* Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in
  the documentation and/or other materials provided with the
  distribution.

* Neither the name of Linkopings universitet nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
\"AS IS\" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

/*
 * Adrian Pop, adrpo@ida.liu.se, changed the 
 * info field and added more position information.
 * look into Absyn.(rml|mo) for more information: search for: Info|INFO
 * Absyn__INFO(file, isReadOnly, startLine, startColumn, endLine, endColumn)
 **/

header "post_include_hpp" {
	#define null 0

    #include <string.h>
    
    extern std::string modelicafilename; // Global filename string.
    
    extern "C" {
		#include <stdio.h>
		#include "yacclib.h"
    }
    
	#include <cstdlib>
	#include <iostream>
    
	#include "rml.h"
	#include "../Absyn.h"
	#include "../Interactive.h"
	#include <stack>
	#include <string>
	#include "MyAST.h"
    
}

options {
    language = "Cpp";
}



class modelica_tree_parser extends TreeParser;

options {
    ASTLabelType = "RefMyAST";
    buildAST = true;
    importVocab = modelica_parser;
    k = 2;
    defaultErrorHandler = false;
}

tokens {
    INTERACTIVE_STMT;
	INTERACTIVE_ALG;
	INTERACTIVE_EXP;
}
{
    
    typedef std::string mstring;

    
    void* to_rml_str(RefMyAST &t)
    {
        return mk_scon(const_cast<char*>(t->getText().c_str()));
    }

    void* make_inner_outer(RefMyAST &i,RefMyAST &o)
    {
		void *innerouter;
        if (i!=NULL && o != NULL) { innerouter = Absyn__INNEROUTER; }
        else if (i!=NULL) {
			innerouter = Absyn__INNER; 
		} else if (o != NULL) {
			innerouter = Absyn__OUTER;
		} else {
			innerouter = Absyn__UNSPECIFIED;
		}
		return innerouter;
	}
    
    void* make_redeclare_keywords(bool replaceable,bool redeclare)
    {
		void *keywords=0;
        if (replaceable && redeclare) {
            keywords = Absyn__REDECLARE_5fREPLACEABLE;
        } else if (replaceable) {
            keywords = Absyn__REPLACEABLE; 
        } else if (redeclare) {
            keywords = Absyn__REDECLARE;
        } 
		return keywords;
	}

    int str_to_int(mstring const& str)
    {
		return atoi(str.c_str());
    }
    
    double str_to_double(std::string const& str)
    {
        return atof(str.c_str());
    }
    
    typedef std::stack<void*> l_stack;
    
    void* make_rml_list_from_stack(l_stack& s)
    {
        void *l = mk_nil();
        
        while (!s.empty())
        {
            l = mk_cons(s.top(), l);
            s.pop();
        }   
        return l;
    }
    

    struct type_prefix_t
    {
        type_prefix_t():flow(0), variability(0),direction(0){}
        void* flow;
        void* variability;
        void* direction;
    };
    

}

stored_definition returns [void *ast]
{
    void *within = 0;
    void *restr = 0;
    void *imp=0;
    void *c=0;
    void *class_def = 0;
    l_stack el_stack;
}
    :
        #(BEGIN_DEFINITION (e:ENCAPSULATED)? (p:PARTIAL)? 
            restr = class_restriction i:IDENT)
        {
            ast = Absyn__BEGIN_5fDEFINITION(Absyn__IDENT(to_rml_str(i)),
                restr,
                RML_PRIM_MKBOOL(p != 0),
                RML_PRIM_MKBOOL(e != 0));
        }
        |
        #(END_DEFINITION i2:IDENT) 
        {
            ast = Absyn__END_5fDEFINITION(to_rml_str(i2));
        }
        |
        #(COMPONENT_DEFINITION c=component_clause)
        {
            ast = Absyn__COMP_5fDEFINITION(c,mk_none());
        }
        |
        #(IMPORT_DEFINITION imp=import_clause)
        {
            ast = Absyn__IMPORT_5fDEFINITION(imp,mk_none());
        }
        |
        #(STORED_DEFINITION      
            ( within = within_clause )?
            ((f:FINAL )? 
                class_def = class_definition[f != NULL] 
                {
                    if (class_def)
                    {   
                        el_stack.push(class_def);
                    }
                }
            )*
        )
        {
            if (within == 0) { within=Absyn__TOP; }
            ast = Absyn__PROGRAM(make_rml_list_from_stack(el_stack),within);
        }
    ;

interactive_stmt returns [void *ast]
{ 
    void *al=0; 
    void *el=0;
	l_stack el_stack;	
}
    :
		(
			#(INTERACTIVE_ALG (al = algorithm) )
			{
				el_stack.push(Interactive__IALG(al));
			}	
		|	
			#(INTERACTIVE_EXP (el = expression ))
			{
				el_stack.push(Interactive__IEXP(el));
			}
			
		)* (s:SEMICOLON)?
		{
			ast = Interactive__ISTMTS(make_rml_list_from_stack(el_stack), RML_PRIM_MKBOOL(s != 0));
		}
	;

within_clause returns [void *ast]
{
    void * name= 0;
}
    : #(WITHIN (name = name_path)? )	
        {
            ast = Absyn__WITHIN(name);
        }
    ;

class_definition [bool final] returns [ void* ast ]
{
    void* restr = 0;
    void* class_spec = 0;
}
    :
        #(CLASS_DEFINITION 
            (e:ENCAPSULATED )? 
            (p:PARTIAL )?
            (ex:EXPANDABLE)?
            restr = info_position1:class_restriction
            (i:IDENT)?
            class_spec = info_position2:class_specifier
        )
        {   
            if (ex && restr == Absyn__R_5fCONNECTOR ) {
                restr = Absyn__R_5fEXP_5fCONNECTOR;
            }
            ast = Absyn__CLASS(
                i? to_rml_str(i): mk_scon(""),
                RML_PRIM_MKBOOL(p != 0),
                RML_PRIM_MKBOOL(final),
                RML_PRIM_MKBOOL(e != 0), 
                restr,
                class_spec,
                Absyn__INFO(
                  mk_scon((char*)(modelicafilename.c_str())),
                  RML_PRIM_MKBOOL(0), /* false */ 
                  mk_icon(info_position1?info_position1->getLine():0),
                  mk_icon(info_position1?info_position1->getColumn():0),
                  mk_icon(info_position2?info_position2->getLine():0),
                  mk_icon(info_position2?info_position2->getColumn():0)
                  )
            );                
        }
    ;

class_restriction returns [void* ast]
    :
        ( CLASS     { ast = Absyn__R_5fCLASS; }
        | MODEL     { ast = Absyn__R_5fMODEL; }
        | RECORD    { ast = Absyn__R_5fRECORD; }
        | BLOCK     { ast = Absyn__R_5fBLOCK; }
        | CONNECTOR { ast = Absyn__R_5fCONNECTOR; }
        | TYPE      { ast = Absyn__R_5fTYPE; }
        | PACKAGE   { ast = Absyn__R_5fPACKAGE; }
        | FUNCTION  { ast = Absyn__R_5fFUNCTION; }
        )
    ;

class_specifier returns [void* ast]
{
	void *comp = 0;
	void *cmt = 0;
    void *cmod = 0;
}
	:
		( (cmt = string_comment )
			comp = composition		
			{
				ast = Absyn__PARTS(comp,cmt ? mk_some(cmt) : mk_none());
			}
		)
	| #(EQUALS ( ast = derived_class 
            | ast = enumeration 
            | ast = overloading
            | ast = pder )) 
    | #(CLASS_EXTENDS i:IDENT (cmod = class_modification)? 
                        cmt = string_comment comp = composition)
        {
            if (!cmod) { cmod = mk_nil(); }
            ast = Absyn__CLASS_5fEXTENDS(
                to_rml_str(i),
                cmod,
                cmt ? mk_some(cmt) : mk_none(),
                comp);
        }
	;

pder returns [void* ast] 
{
    void* func=0;
    void* var_lst=0;
}
    : #(DER func = name_path var_lst = ident_list)
        {
            ast = Absyn__PDER(func,var_lst);
        }
    ;

ident_list returns [void* ast]
{
    l_stack el_stack;
}
    : #(IDENT_LIST 
            (i:IDENT { el_stack.push(to_rml_str(i)); } )
            (i2:IDENT {el_stack.push(to_rml_str(i2));} )*
        )
        {
            ast = make_rml_list_from_stack(el_stack);
        }
    ;

overloading returns [void *ast]
{
	l_stack el_stack;
	void *el = 0;
	void *cmt = 0;
}
	:
		#(OVERLOAD
			el = name_path
			{ el_stack.push(el); }
			(
				el = name_path
				{ el_stack.push(el); }
				
			)*
			(cmt=comment)?
               )
		{
			ast = Absyn__OVERLOAD(make_rml_list_from_stack(el_stack),		
				cmt ? mk_some(cmt) : mk_none());
		}
	;


derived_class returns [void *ast]
{
	void *p = 0;
	void *as = 0;
	void *cmod = 0;
  	void *cmt = 0;
	void *attr = 0;
	type_prefix_t pfx;
}
	:
		(   type_prefix[pfx]
			p = name_path 
			( as = array_subscripts )? 
			( cmod = class_modification )? 
			(cmt = comment)?
			{
				if (as) { as = mk_some(as); }
				else { as = mk_none(); }
				if (!cmod) { cmod = mk_nil(); }
				attr = Absyn__ATTR(
				pfx.flow,
				pfx.variability,
				pfx.direction,
 				mk_nil());

				ast = Absyn__DERIVED(p, as, attr, cmod, cmt? mk_some(cmt) : mk_none());
			}
		)
	;

enumeration returns [void* ast]
{
	l_stack el_stack;
	void *el = 0;
	void *cmt = 0;
}
    : 
		#(ENUMERATION 
			(
                (el = enumeration_literal
                    { el_stack.push(el); }
                    (
                        el = enumeration_literal
                        { el_stack.push(el); }
                        
                    )*) 
            |
                c:COLON
            )
			(cmt=comment)?
		)
		{
            if (c) {
                ast = Absyn__ENUMERATION(Absyn__ENUM_5fCOLON,
                cmt ? mk_some(cmt) : mk_none());
            } else {
                ast = Absyn__ENUMERATION(Absyn__ENUMLITERALS(make_rml_list_from_stack(el_stack)),
                    cmt ? mk_some(cmt) : mk_none());
            }
		}
	;

enumeration_literal returns [void *ast] :
{
   void *c1=0;
}
		#(ENUMERATION_LITERAL i1:IDENT (c1=comment)?) 
		{
			ast = Absyn__ENUMLITERAL(to_rml_str(i1),c1 ? mk_some(c1) : mk_none());
		}
	;	

composition returns [void* ast]
{
    void* el = 0;
    l_stack el_stack;
    void * ann = 0;	
}
    :
        el = element_list
        {
            el_stack.push(Absyn__PUBLIC(el));
        }
        (
            (	
                el = public_element_list
            |	el = protected_element_list
			|   el = equation_clause
            |	el = algorithm_clause
            )
            {
                el_stack.push(el);
            }
        )*
        (	#(EXTERNAL
				( el = external_function_call)
                (ann = external_annotation) ?
				{ 
					el_stack.push(Absyn__EXTERNAL(el,
                            ann ? mk_some(ann) : mk_none())); 
				}
			)
		)?
        {
            ast = make_rml_list_from_stack(el_stack);
        }
    ;

external_annotation returns [void* ast] 
{
    ast = 0;
}
    :
        #(EXTERNAL_ANNOTATION ast = annotation)
    ;
public_element_list returns [void* ast]
{
    void* el;    
}
    :
        
        #(p:PUBLIC 
            el = element_list
        )
        {
            ast = Absyn__PUBLIC(el);
        }
    ;

protected_element_list returns [void* ast]
{
    void* el;
}
    :
        
        #(p:PROTECTED
            el = element_list
        )
        {
            ast = Absyn__PROTECTED(el);
        }
    ;

external_function_call returns [void* ast]
{
	void* expl=0;
	void* retexp=0;
	void* lang=0;
    void* funcname=0;
    void* ann=0;
	ast = 0;
}
	:
        (s:STRING {lang=mk_some(to_rml_str(s)); } )?
        (#(EXTERNAL_FUNCTION_CALL 
				(
					(i:IDENT (expl = expression_list)?)
					{
						if (i != NULL) {
							funcname = mk_some(to_rml_str(i));
						}
					}
				| #(e:EQUALS retexp = component_reference i2:IDENT ( expl = expression_list)?)
					{
						if (retexp) { retexp = mk_some(retexp); }
						if (i2 != NULL) {
							funcname = mk_some(to_rml_str(i2));
						}
					}
				)
			))? 
        ( ann = annotation)?
		{
			if (!expl) { expl = mk_nil(); }
			if (!retexp) { retexp = mk_none(); } 
			if (!lang) { lang = mk_none(); }
			if (!funcname) { funcname = mk_none(); }
            ann = ann ? mk_some(ann) : mk_none();
			ast = Absyn__EXTERNALDECL(funcname,
					lang, retexp, expl,ann);
        }
    ;

element_list returns [void* ast]
{
    void* e = 0;
    l_stack el_stack;
    void *ann = 0;
}
    :
        (
            (e = element
                {
                    el_stack.push(Absyn__ELEMENTITEM(e));
                })
        | (ann = annotation 
                {
                    el_stack.push(Absyn__ANNOTATIONITEM(ann));
                }
            )              
        )*
        {
            ast = make_rml_list_from_stack(el_stack);
        }
    ;


// returns datatype Element
element returns [void* ast]
{
	void* class_def = 0;
	void* e_spec = 0;
	void* final = 0;
	void* innerouter = 0;
	void* constr = 0;
    void* cmt = 0;
    void* keywords = 0;
    
}

	: 
		( e_spec = i_clause:import_clause
			{                
				ast = Absyn__ELEMENT(RML_FALSE,mk_none(),Absyn__UNSPECIFIED,mk_scon("import"),
                    e_spec, Absyn__INFO(
                              mk_scon((char*)(modelicafilename.c_str())),
                              RML_PRIM_MKBOOL(0), /* false */
                              mk_icon(i_clause->getLine()),
                              mk_icon(i_clause->getColumn()),
                              mk_icon(i_clause->getLine()),
                              mk_icon(i_clause->getColumn())
                              ),mk_none());
			}
		| e_spec = e_clause:extends_clause
			{
				ast = Absyn__ELEMENT(RML_FALSE,mk_none(),Absyn__UNSPECIFIED,mk_scon("extends"),
                    e_spec, Absyn__INFO(
                              mk_scon((char*)(modelicafilename.c_str())),
                              RML_PRIM_MKBOOL(0), /* false */
                              mk_icon(e_clause->getLine()),
                              mk_icon(e_clause->getColumn()),
                              mk_icon(e_clause->getLine()),
                              mk_icon(e_clause->getColumn())
                              ),mk_none());
			}
		| #(decl:DECLARATION 
                (re:REDECLARE)? 
                (f:FINAL)? { final = f!=NULL ? RML_TRUE : RML_FALSE; }
                (i:INNER)?  
                (o:OUTER)? { innerouter = make_inner_outer(i,o); }
				(	(e_spec = component_clause
						{
                            keywords = make_redeclare_keywords(false,re);
							ast = Absyn__ELEMENT(final,
                                keywords ? mk_some(keywords) : mk_none(),
                                innerouter,
								mk_scon("component"),e_spec,
                                Absyn__INFO(
                        			  mk_scon((char*)(modelicafilename.c_str())),
		                              RML_FALSE,
		                              mk_icon(decl->getLine()),
		                              mk_icon(decl->getColumn()),
		                              mk_icon(decl->getLine()),
		                              mk_icon(decl->getColumn())
                                     ),mk_none());
            
						}
					| r:REPLACEABLE 
						e_spec = component_clause 
						( constr = constraining_clause cmt = comment)?
						{
                            keywords = make_redeclare_keywords(r,re);
							ast = Absyn__ELEMENT(final,
								keywords ? mk_some(keywords) : mk_none(),
								innerouter,
								mk_scon("replaceable_component"),e_spec,
                                Absyn__INFO(
                                    mk_scon((char*)(modelicafilename.c_str())),
	                                RML_FALSE,
	                                mk_icon(decl->getLine()),
	                                mk_icon(decl->getColumn()),
	                                mk_icon(decl->getLine()),
	                                mk_icon(decl->getColumn())
                                    ),
								constr? mk_some(Absyn__CONSTRAINCLASS(constr, cmt? mk_some(cmt):mk_none())) : mk_none());
						}
					)
				)
			)
		| #(def:DEFINITION
                (re2:REDECLARE)? 
                (fd:FINAL)? { final = fd!=NULL?RML_TRUE:RML_FALSE; }
                (id:INNER)? (od:OUTER)? { innerouter = make_inner_outer(i,o); }
				(                   
					(
						class_def = class_definition[fd != NULL]
						{
                            keywords = make_redeclare_keywords(false,re2);
                            ast = Absyn__CLASSDEF(RML_PRIM_MKBOOL(0),
								class_def);
							ast = Absyn__ELEMENT(
                                final,
								keywords ? mk_some(keywords) : mk_none(),
                                innerouter,
                                mk_scon("??"),
                                ast,
                                Absyn__INFO(
                                   mk_scon((char*)(modelicafilename.c_str())),
	                               RML_FALSE,
	                               mk_icon(def->getLine()),
	                               mk_icon(def->getColumn()),
	                               mk_icon(def->getLine()),
	                               mk_icon(def->getColumn())
                                   ),mk_none());

						}
					| 
						(rd:REPLACEABLE 
							class_def = class_definition[fd != NULL] 
							(constr = constraining_clause cmt = comment)?
						)
						{
                            keywords = make_redeclare_keywords(rd,re2);
                            ast = Absyn__CLASSDEF(rd ? RML_TRUE : RML_FALSE,
								class_def);
							ast = Absyn__ELEMENT(
                                final,
								keywords ? mk_some(keywords) : mk_none(),
                                innerouter,
								mk_scon("??"),
								ast,
                          Absyn__INFO(
                              mk_scon((char*)(modelicafilename.c_str())),
                              RML_FALSE,
                              mk_icon(def->getLine()),
                              mk_icon(def->getColumn()),
                              mk_icon(def->getLine()),
                              mk_icon(def->getColumn())
                              ),
                                constr ? mk_some(Absyn__CONSTRAINCLASS(constr,cmt ? mk_some(cmt):mk_none())) : mk_none());
						}
					)
				)
			)
		)
	;

// returns ElementSpec
import_clause returns [void* ast]
{
	void* imp = 0;
	void* cmt = 0;
}
	:
		#(i:IMPORT 
			(imp = explicit_import_name
			|imp = implicit_import_name
			) 
			(cmt = comment)?
		)
		{
			ast = Absyn__IMPORT(imp, cmt ? mk_some(cmt) : mk_none());
		}
	;

// returns Import
explicit_import_name returns [void* ast]
{
	void* path;
	void* id;
}
	:
		#(EQUALS i:IDENT path = name_path)	
		{
			id = to_rml_str(i);
			ast = Absyn__NAMED_5fIMPORT(id,path);
		}
	;

implicit_import_name returns [void* ast]
{
	void* path;
}
	:
		(#(UNQUALIFIED path = name_path)
			{
				ast = Absyn__UNQUAL_5fIMPORT(path);
			}
		|#(QUALIFIED path = name_path)
			{
				ast = Absyn__QUAL_5fIMPORT(path);
			}
		)
	;

// ****************************
// returns datatype ElementSpec
// ****************************
extends_clause returns [void* ast]
{
	void* path;
	void* mod = 0;
}
	: 
		(#(e:EXTENDS 
				path = name_path 
				( mod = class_modification )? 
			)
			{
				if (!mod) mod = mk_nil();
				ast = Absyn__EXTENDS(path,mod);
			}
		)
	;

constraining_clause returns [void *ast] :
		(ast = extends_clause)
	;

// returns datatype ElementSpec
component_clause returns [void* ast]
{
	type_prefix_t pfx;
	void* attr = 0;
	void* path = 0;
	void* arr = 0;
	void* comp_list = 0;
}
	:
		type_prefix[pfx] 
		path = type_specifier 
		(arr = array_subscripts)? 
		comp_list = component_list
		{
			if (!arr)
			{
				arr = mk_nil();
			}

			attr = Absyn__ATTR(
				pfx.flow,
				pfx.variability,
				pfx.direction,
 				arr);

			ast = Absyn__COMPONENTS(attr, path, comp_list);
		}
	;

type_prefix [type_prefix_t& prefix]
	:
		(f:FLOW)?
		(d:DISCRETE 
		|p:PARAMETER
		|c:CONSTANT
		)?
		(i:INPUT 
		|o:OUTPUT 
		)?
		{
			if (f != NULL) { prefix.flow = RML_PRIM_MKBOOL(1); }
			else { prefix.flow = RML_PRIM_MKBOOL(0); }

			if (d != NULL) { prefix.variability = Absyn__DISCRETE; }
			else if (p != NULL) { prefix.variability = Absyn__PARAM; }
			else if (c != NULL) { prefix.variability = Absyn__CONST; }
			else { prefix.variability = Absyn__VAR; }

			if (i != NULL) { prefix.direction = Absyn__INPUT; }
			else if (o != NULL) { prefix.direction = Absyn__OUTPUT; }
			else { prefix.direction = Absyn__BIDIR; }
		}
	;

// returns datatype Path
type_specifier returns [void* ast]
	:
		ast = name_path;


// returns datatype Component list
component_list returns [void* ast]
{
	l_stack el_stack;
	void* e=0;
}
	:
		e = component_declaration { el_stack.push(e); }
		(e = component_declaration { el_stack.push(e); } )*
		{
			ast = make_rml_list_from_stack(el_stack);
		}
	;


// returns datatype Component
component_declaration returns [void* ast]
{
	void* cmt = 0;
	void* dec = 0;
    void* cond = 0;

}
	:
		(dec = declaration) (cond = conditional_attribute)? (cmt = comment)?
		{
			ast = Absyn__COMPONENTITEM(
                dec,
                cond ? mk_some(cond): mk_none(),
                cmt ? mk_some(cmt) : mk_none()
            );
		}
	;

conditional_attribute returns [void* ast]
{
    void* expr = 0;
}
    :
        #(IF expr = expression)
        {
            ast = expr;
        }
        ;

// returns datatype Component
declaration returns [void* ast]
{
	void* arr = 0;
	void* mod = 0;
	void* id = 0;
}
	:
		#(i:IDENT (arr = array_subscripts)? (mod = modification)?)
		{
			if (!arr) arr = mk_nil();
			id = to_rml_str(i);
			ast = Absyn__COMPONENT(id, arr, mod ? mk_some(mod) : mk_none());

		}
	;

modification returns [void* ast] 
{
	void* e = 0;
	void* cm = 0;
}
	:
		( cm = class_modification ( e = expression )?
		|#(EQUALS e = expression)
		|#(ASSIGN e = expression)
		)
		{
			if (!e) e = mk_none();
			else e = mk_some(e);

			if (!cm) cm = mk_nil();

			ast = Absyn__CLASSMOD(cm, e);
		}
	;

class_modification returns [void* ast]
{
	ast = 0;
}
	:
		#(CLASS_MODIFICATION (ast = argument_list)?)
		{
			if (!ast) ast = mk_nil();
		}
	;

argument_list returns [void* ast]
{
	l_stack el_stack;
	void* e;
}
	:
		#(ARGUMENT_LIST 
			e = argument { el_stack.push(e); }
			(e = argument { el_stack.push(e); } )*
		)
		{
			ast = make_rml_list_from_stack(el_stack);
		}
	;

argument returns [void* ast]
	:
		#(ELEMENT_MODIFICATION ast = element_modification_or_replaceable)
	|
		#(ELEMENT_REDECLARATION ast = element_redeclaration) 
	;

element_modification_or_replaceable returns [void * ast]
    :
        (e:EACH)?
		(f:FINAL)? 
        (ast = element_modification[e!=NULL,f!=NULL]  
        | ast = element_replaceable[e!=NULL,f!=NULL,false] )
    ;

element_modification [bool each, bool final] returns [void* ast]
    {
	void* cref;
	void* mod=0;
	void* ast_final;
	void* ast_each;
	void* cmt=0; 
} 
	:
		(
            cref = component_reference 
            ( mod = modification )?
            cmt = string_comment
        )
		{
			ast_final = final ? RML_TRUE : RML_FALSE;
			ast_each = each ? Absyn__EACH : Absyn__NON_5fEACH;

			ast = Absyn__MODIFICATION(
                ast_final, 
                ast_each, 
                cref, 
                mod ? mk_some(mod) : mk_none(), 
                cmt ? mk_some(cmt) : mk_none()
            );
		}
	;

element_redeclaration returns [void* ast]
{
	void* class_def = 0;
	void* e_spec = 0; 
	void* final = 0;
	void* each = 0;
    void* keywords = 0;
}
	:
		    (#(REDECLARE (e:EACH)? (f:FINAL)?
                (
                    (
                        (class_def = class_definition[false] 
                            {
                                e_spec = Absyn__CLASSDEF(RML_FALSE,class_def);
                                final = f != NULL ? RML_TRUE : RML_FALSE;
                                each = e != NULL ? Absyn__EACH : Absyn__NON_5fEACH;
                                keywords = make_redeclare_keywords(
                                    false, // not replaceable 
                                    true); // but redeclare
                                
                                ast = Absyn__REDECLARATION(final, keywords,each, e_spec, mk_none());
                            }
                        | e_spec = component_clause1
                            {
                                final = f != NULL ? RML_TRUE : RML_FALSE;
                                each = e != NULL ? Absyn__EACH : Absyn__NON_5fEACH;
                                keywords = make_redeclare_keywords(
                                    false, // not replaceable 
                                    true); // but redeclare
                                ast = Absyn__REDECLARATION(final, keywords, each, e_spec, mk_none());
                            }   
                        )
                    )
                    
                |
                    ( ast = element_replaceable[
                            e!=NULL,
                            f!=NULL,
                            true/*has redeclare keyword */
                        ]
                    )
                )
            )
        )
	;

element_replaceable [bool each, bool final,bool redeclare]  returns [void* ast]
{
	void* class_def = 0;
	void* e_spec = 0; 
	void* constr = 0;
    void* cmt = 0;
	void* ast_final = 0;
	void* ast_each = 0;
    void* keywords = 0;
}
	:
        
        (#(REPLACEABLE 
            (class_def = class_definition[false]                            
            | e_spec = component_clause1
            )
            (constr = constraining_clause cmt = comment)?
            {	
                ast_final = final ? RML_TRUE : RML_FALSE;
                ast_each = each ? Absyn__EACH : Absyn__NON_5fEACH;
                keywords = make_redeclare_keywords(true,redeclare);
                
                if (class_def) 
                    {	
                    e_spec = Absyn__CLASSDEF(RML_TRUE, class_def);
                    
                    ast = Absyn__REDECLARATION(ast_final, keywords, ast_each, e_spec,
                            constr ? mk_some(Absyn__CONSTRAINCLASS(constr,cmt?mk_some(cmt):mk_none())) : mk_none());
                } else {
                    ast = Absyn__REDECLARATION(ast_final, keywords, ast_each, e_spec,
                        constr ? mk_some(Absyn__CONSTRAINCLASS(constr,cmt?mk_some(cmt):mk_none())) : mk_none());
                }   
            }
            )
        )
	;

component_clause1 returns [void* ast]
{
	type_prefix_t pfx;
	void* attr = 0;
	void* path = 0;
	void* arr = 0;
	void* comp_decl = 0;
	void* comp_list = 0;
}
	:
		type_prefix[pfx]
		path = type_specifier 
		comp_decl = component_declaration
		{
			if (!arr)
			{
				arr = mk_nil();
			}
			comp_list = mk_cons(comp_decl,mk_nil());
			attr = Absyn__ATTR(
				pfx.flow,
				pfx.variability,
				pfx.direction,
				arr);

			ast = Absyn__COMPONENTS(attr, path, comp_list);
		}
	;

// Return datatype ClassPart
equation_clause returns [void* ast]
{
	l_stack el_stack;
	void *e = 0;
	void *ann = 0;
} 
	:
		#(EQUATION
			(
				(
					e = equation { el_stack.push(e); }
				| ann = annotation { el_stack.push(Absyn__EQUATIONITEMANN(ann));} 
				)*
				
			)
		)
		{
			ast = Absyn__EQUATIONS(make_rml_list_from_stack(el_stack));
		}
	|
		#(INITIAL_EQUATION
			#(EQUATION
				(
					e = equation { el_stack.push(e); }
				| ann = annotation { el_stack.push(Absyn__EQUATIONITEMANN(ann));} 
				)*
			)
			{
				ast = Absyn__INITIALEQUATIONS(make_rml_list_from_stack(el_stack));
			}
		)
	;	

algorithm_clause returns [void* ast]
{
	l_stack el_stack;
	void* e;
	void* ann;
}
	:
		#(ALGORITHM 
			(e = algorithm { el_stack.push(e); }
			| ann = annotation { el_stack.push(Absyn__ALGORITHMITEMANN(ann)); }
			)*
		)
		{
			ast = Absyn__ALGORITHMS(make_rml_list_from_stack(el_stack));
		}
	|
		#(INITIAL_ALGORITHM
			#(ALGORITHM 
				(e = algorithm { el_stack.push(e); }
				| ann = annotation { el_stack.push(Absyn__ALGORITHMITEMANN(ann)); }
				)*
			)
			{
				ast = Absyn__INITIALALGORITHMS(make_rml_list_from_stack(el_stack));
			}
		)
	;

equation returns [void* ast] 
{
	void *cmt = 0;
}
	:
		#(i:EQUATION_STATEMENT
			(	ast = equality_equation
			|	ast = conditional_equation_e
			|	ast = for_clause_e
			|	ast = when_clause_e
			|	ast = connect_clause
			|  ast = equation_funcall	
			)
			(cmt = comment)?
			{
				ast = Absyn__EQUATIONITEM(ast,cmt ? mk_some(cmt) : mk_none());
			}
		)
	;

equation_funcall returns [void* ast]
{
  void *fcall = 0;
}
	:
		i:IDENT fcall = function_call 
		{ ast = Absyn__EQ_5fNORETCALL(to_rml_str(i),fcall); }
	;

algorithm returns [void* ast]
{
	void* cref;
	void* expr;
	void* tuple;
	void* args;
  	void* cmt=0;
}
	:
		#(ALGORITHM_STATEMENT 
			(#(ASSIGN 
					(cref = component_reference expr = expression
						{
							ast = Absyn__ALG_5fASSIGN(cref,expr);
						}
					|	(tuple = expression_list cref = component_reference args = function_call)
						{
							ast = Absyn__ALG_5fTUPLE_5fASSIGN(Absyn__TUPLE(tuple),Absyn__CALL(cref,args));
						}
					)
				)
			| ast = algorithm_function_call
			| ast = conditional_equation_a
			| ast = for_clause_a
			| ast = while_clause
			| ast = when_clause_a
			)
			(cmt = comment)?
	  		{	
				ast = Absyn__ALGORITHMITEM(ast, cmt ?  mk_some(cmt) : mk_none());
	  		}
		)
	;

algorithm_function_call returns [void* ast]
{
	void* cref;
	void* args;
}
	:
		cref = component_reference args = function_call
		{
			ast = Absyn__ALG_5fNORETCALL(cref,args);
		}
	;

equality_equation returns [void* ast]
{
	void* e1;
	void* e2;
}
	:
		#(EQUALS e1 = simple_expression e2 = expression)
		{
			ast = Absyn__EQ_5fEQUALS(e1,e2);
		}
	;

conditional_equation_e returns [void* ast]
{
	void* e1;
	void* then_b;
	void* else_b = 0;
	void* else_if_b;
	l_stack el_stack;
	void* e;
}
	:
		#(IF
			e1 = expression
			then_b = equation_list
			( e = equation_elseif { el_stack.push(e); } )*
			(ELSE else_b = equation_list)?
		)
		{
			else_if_b = make_rml_list_from_stack(el_stack);
			if (!else_b) else_b = mk_nil();
			ast = Absyn__EQ_5fIF(e1, then_b, else_if_b, else_b);
		}
	;

conditional_equation_a returns [void* ast]
{
	void* e1;
	void* then_b;
	void* else_b = 0;
	void* else_if_b;
	l_stack el_stack;
	void* e;
}
	:
		#(IF
			e1 = expression
			then_b = algorithm_list
			( e = algorithm_elseif { el_stack.push(e); } )*
			( ELSE else_b = algorithm_list)?
		)
		{
			else_if_b = make_rml_list_from_stack(el_stack);
			if (!else_b) else_b = mk_nil();
			ast = Absyn__ALG_5fIF(e1, then_b, else_if_b, else_b);
		}
	;

for_clause_e returns [void* ast] 
{
	void* e;
	void* eq;
	void* id;
}
	:

		#(FOR #(IN i:IDENT
			e = expression )
			eq = equation_list
		)
		{
			id = to_rml_str(i);
			ast = Absyn__EQ_5fFOR(id,e,eq);
		}
	;

for_clause_a returns [void* ast]
{
	void* e;
	void* eq;
	void* id;
}
	:
		#(FOR #(IN i:IDENT
			e = expression )
			eq = algorithm_list
		)
		{
			id = to_rml_str(i);
			ast = Absyn__ALG_5fFOR(id,e,eq);
		}
	;

while_clause returns [void* ast]
{
	void* e;
	void* body;
}
	:
		#(WHILE 
			e = expression 
			body = algorithm_list)
		{
			ast = Absyn__ALG_5fWHILE(e,body);
		}
	;

when_clause_e returns [void* ast]
{
	l_stack el_stack;
	void* e;
	void* body;
	void* el = 0;
}
	:
		#(WHEN 
			e = expression
			body = equation_list
	  		(el = else_when_e { el_stack.push(el); } )*
		)
		{
			ast = Absyn__EQ_5fWHEN_5fE(e,body,make_rml_list_from_stack(el_stack));
		}

	;

else_when_e returns [void *ast]
{ 
	void * expr;
	void * eqn;
}
	:
		#(e:ELSEWHEN expr = expression  eqn = equation_list)
		{
			ast = mk_box2(0,expr,eqn);
		}
	;

when_clause_a returns [void* ast]
{
	l_stack el_stack;
	void* e;
	void* body;
	void* el = 0;
}
	:
		#(WHEN 
			e = expression
			body = algorithm_list 
			(el = else_when_a {el_stack.push(el); })* 
		)
		{
			ast = Absyn__ALG_5fWHEN_5fA(e,body,make_rml_list_from_stack(el_stack));
		}
	;

else_when_a returns [void *ast]
{ 
	void * expr;
	void * alg;
}
	:
		#(e:ELSEWHEN expr = expression  alg = algorithm_list)
		{
			ast = mk_box2(0,expr,alg);
		}
	;

equation_elseif returns [void* ast]
{
	void* e;
	void* eq;
}
	:
		#(ELSEIF 
			e = expression 
			eq = equation_list
		)
		{
			ast = mk_box2(0,e,eq);
		}
	;

algorithm_elseif returns [void* ast]
{
	void* e;
	void* body;
}
	:
		#(ELSEIF 
			e = expression
			body = algorithm_list
		)
		{
			ast = mk_box2(0,e,body);
		}
	;

equation_list returns [void* ast]
{
	void* e;
	l_stack el_stack;
}
	:
		(e = equation { el_stack.push(e); })*
		{
			ast = make_rml_list_from_stack(el_stack);
		}
	;

algorithm_list returns [void* ast]
{
	void* e;
	l_stack el_stack;
}
	:
		(e = algorithm { el_stack.push(e); } )*
		{
			ast = make_rml_list_from_stack(el_stack);
		}
	;

connect_clause returns [void* ast]
{
	void* r1;
	void* r2;
}
	:
		#(CONNECT 
			r1 = connector_ref
			r2 = connector_ref
		)
		{
			ast = Absyn__EQ_5fCONNECT(r1,r2);
		}
	;

connector_ref returns [void* ast]
{
	void* as = 0;
	void* id = 0;
}
	:
		(#(i:IDENT (as = array_subscripts)? )
			{
				if (!as) as = mk_nil();
				id = to_rml_str(i);
				ast = Absyn__CREF_5fIDENT(id,as);
			}
		|#(DOT #(i2:IDENT (as = array_subscripts)?) 
				ast = connector_ref_2)
			{
				if (!as) as = mk_nil();
				id = to_rml_str(i2);
				ast = Absyn__CREF_5fQUAL(id,as,ast);
			}
		)
	;

connector_ref_2 returns [void* ast]
{
	void* as = 0;
	void* id;
}
	:
		#(i:IDENT (as = array_subscripts)? )
		{
			if (!as) as = mk_nil();
			id = to_rml_str(i);
			ast = Absyn__CREF_5fIDENT(id,as);
		}
	;

expression returns [void* ast]
	:
		(	ast = simple_expression
		|	ast = if_expression
		|   ast = code_expression
		)
	;

code_expression returns [void* ast]
	:
		#(CODE_MODIFICATION (ast = modification) )
		{
			ast = Absyn__CODE(Absyn__C_5fMODIFICATION(ast));
		}

	|	#(CODE_EXPRESSION (ast = expression) )
		{
			ast = Absyn__CODE(Absyn__C_5fEXPRESSION(ast));
		}

	|	#(CODE_ELEMENT (ast = element) )
		{
			ast = Absyn__CODE(Absyn__C_5fELEMENT(ast));
		}
		
	|	#(CODE_EQUATION (ast = equation_clause) )
		{
			ast = Absyn__CODE(Absyn__C_5fEQUATIONSECTION(RML_FALSE, 
					RML_FETCH(RML_OFFSET(RML_UNTAGPTR(ast), 1))));
		}
		
	|	#(CODE_INITIALEQUATION (ast = equation_clause) )
		{
			ast = Absyn__CODE(Absyn__C_5fEQUATIONSECTION(RML_TRUE, 
					RML_FETCH(RML_OFFSET(RML_UNTAGPTR(ast), 1))));
		}
	|	#(CODE_ALGORITHM (ast = algorithm_clause) )
		{
			ast = Absyn__CODE(Absyn__C_5fALGORITHMSECTION(RML_FALSE, 
					RML_FETCH(RML_OFFSET(RML_UNTAGPTR(ast), 1))));
		}
	|	#(CODE_INITIALALGORITHM (ast = algorithm_clause) )
		{
			ast = Absyn__CODE(Absyn__C_5fALGORITHMSECTION(RML_TRUE, 
					RML_FETCH(RML_OFFSET(RML_UNTAGPTR(ast), 1))));
		}
	;

if_expression returns [void* ast]
{
	void* cond;
	void* thenPart;
	void* elsePart;
	void* e;
	void* elseifPart;
	l_stack el_stack;
}
	:
		#(IF cond = expression
			thenPart = expression (e=elseif_expression {el_stack.push(e);} )* elsePart = expression
			{
				elseifPart = make_rml_list_from_stack(el_stack);
				ast = Absyn__IFEXP(cond,thenPart,elsePart,elseifPart);
			}
		)
	;

elseif_expression returns [void* ast]
{
	void *cond;
	void *thenPart;
}
	:
		#(ELSEIF cond = expression thenPart = expression
		{
			ast = mk_box2(0,cond,thenPart);
		}
	  )
	;

simple_expression returns [void* ast]
{
	void* e1;
	void* e2;
	void* e3;
}
	:
		(#(RANGE3 e1 = logical_expression 
				e2 = logical_expression 
				e3 = logical_expression)
			{
				ast = Absyn__RANGE(e1,mk_some(e2),e3);
			}
		|#(RANGE2 e1 = logical_expression e3 = logical_expression)
			{
				ast = Absyn__RANGE(e1,mk_none(),e3);
			}
		| ast = logical_expression
		)
	;

logical_expression returns [void* ast]
{
	void* e1;
	void* e2;
}
	: 
		(ast = logical_term
		| #(OR e1 = logical_expression e2 = logical_term)
			{
				ast = Absyn__LBINARY(e1,Absyn__OR, e2);
			}
		)

	;

logical_term returns [void* ast]
{
	void* e1;
	void* e2;
}
	:
		(ast = logical_factor
		| #(AND e1 = logical_term e2 = logical_factor)
			{
				ast = Absyn__LBINARY(e1,Absyn__AND,e2);
			}
		)
	;

logical_factor returns [void* ast]
	:
		#(NOT ast = relation { ast = Absyn__LUNARY(Absyn__NOT,ast); })
	| ast = relation;

relation returns [void* ast]
{
	void* e1;
	void* op = 0;
	void* e2 = 0;
}
	: 
		( ast = arithmetic_expression
		| 
			( #(LESS e1=arithmetic_expression e2=arithmetic_expression)
				{ op = Absyn__LESS; }                    
			| #(LESSEQ e1=arithmetic_expression e2=arithmetic_expression)
				{ op = Absyn__LESSEQ; }                    
			| #(GREATER e1=arithmetic_expression e2=arithmetic_expression)
				{ op = Absyn__GREATER; }                    
			| #(GREATEREQ e1=arithmetic_expression e2=arithmetic_expression)
				{ op = Absyn__GREATEREQ; }                    
			| #(EQEQ e1=arithmetic_expression e2=arithmetic_expression)
				{ op = Absyn__EQUAL; }                    
			| #(LESSGT e1=arithmetic_expression e2=arithmetic_expression )
				{ op = Absyn__NEQUAL; }                    
			)
			{
				ast = Absyn__RELATION(e1,op,e2);
			}
		)
	;

rel_op returns [void* ast]
	:
		( LESS { ast = Absyn__LESS; }
		| LESSEQ { ast = Absyn__LESSEQ; }
		| GREATER { ast = Absyn__GREATER; }
		| GREATEREQ { ast = Absyn__GREATEREQ; }
		| EQEQ { ast = Absyn__EQUAL; }
		| LESSGT { ast = Absyn__NEQUAL; }
		)
	;

arithmetic_expression returns [void* ast]
{
	void* e1;
	void* e2;
}
	:
		(ast = unary_arithmetic_expression
		|#(PLUS e1 = arithmetic_expression e2 = term)
			{
				ast = Absyn__BINARY(e1,Absyn__ADD,e2);
			}
		|#(MINUS e1 = arithmetic_expression e2 = term)
			{
				ast = Absyn__BINARY(e1,Absyn__SUB,e2);
			}
		)
	;

unary_arithmetic_expression returns [void* ast]
	:
		(#(UNARY_PLUS ast = term) { ast = Absyn__UNARY(Absyn__UPLUS,ast); }
		|#(UNARY_MINUS ast = term) { ast = Absyn__UNARY(Absyn__UMINUS,ast); }
		| ast = term
		)
	;

term returns [void* ast]
{
	void* e1;
	void* e2;
}
	:
		(ast = factor
		|#(STAR e1 = term e2 = factor) 
			{
				ast = Absyn__BINARY(e1,Absyn__MUL,e2); 
			}
		|#(SLASH e1 = term e2 = factor)
			{
				ast = Absyn__BINARY(e1,Absyn__DIV,e2); 
			}
		)
	;

factor returns [void* ast]
{
	void* e1;
	void* e2;
}
	:
		(ast = primary
		|#(POWER e1 = primary e2 = primary)
			{
				ast = Absyn__BINARY(e1,Absyn__POW,e2);
			}
		)
	;

primary returns [void* ast]
{
	l_stack el_stack;
	void* e;
    ast = 0;
}
	:
		( ui:UNSIGNED_INTEGER 
			{ 
				ast = Absyn__INTEGER(mk_icon(str_to_int(ui->getText()))); 
			}
		| ur:UNSIGNED_REAL
			{ 
				ast = Absyn__REAL(mk_rcon(str_to_double(ur->getText()))); 
			}
		| str:STRING
			{
				ast = Absyn__STRING(to_rml_str(str));
			}
		| FALSE { ast = Absyn__BOOL(RML_FALSE); }
		| TRUE { ast = Absyn__BOOL(RML_TRUE); }
		| ast = component_reference__function_call
        | #(DER e = function_call)
            {
                ast = Absyn__CALL(Absyn__CREF_5fIDENT(mk_scon("der"), mk_nil()),e);
            }
		| #(LPAR ast = tuple_expression_list)

		| #(LBRACK  e = expression_list { el_stack.push(e); }
				(e = expression_list { el_stack.push(e); } )* )
			{
				ast = Absyn__MATRIX(make_rml_list_from_stack(el_stack));
			}
		| #(LBRACE ( (ast = expression_list) { ast = Absyn__ARRAY(ast); }
                   | #(FOR_ITERATOR ast = for_iterator)
                    {
                        /* create an array constructor as a reduction expression */
                        /* for unified handling in compiler */
                        ast = Absyn__CALL(Absyn__CREF_5fIDENT(mk_scon("array"), mk_nil()),ast);
                    }
                ))
		| END { ast = Absyn__END; }
		)
	;

component_reference__function_call returns [void* ast]
{
	void* cref;
	void* fnc = 0;
}
	:
		(#(FUNCTION_CALL cref = component_reference (fnc = function_call)?)
			{
				if (!fnc) fnc = mk_nil();
				ast = Absyn__CALL(cref,fnc);
			}
		| cref = component_reference
			{
				ast = Absyn__CREF(cref);
			}
		)
		|
		#(INITIAL_FUNCTION_CALL INITIAL )
			{
				ast = Absyn__CALL(Absyn__CREF_5fIDENT(mk_scon("initial"), mk_nil()),Absyn__FUNCTIONARGS(mk_nil(),mk_nil()));
			}
		;
	
name_path returns [void* ast]
{
	void* str;

}
	:
		i:IDENT 
		{
			str = to_rml_str(i);
			ast = Absyn__IDENT(str);
		}
	|#(d:DOT i2:IDENT ast = name_path )
		{
			str = to_rml_str(i2);
			ast = Absyn__QUALIFIED(str, ast);
		}
	;

component_reference	returns [void* ast]
{
	void* arr = 0;
	void* id = 0;
}
	:
		(#(i:IDENT (arr = array_subscripts)?) 
			{
				if (!arr) arr = mk_nil();
				id = to_rml_str(i);
				ast = Absyn__CREF_5fIDENT(
					id,
					arr);

			}
		|#(DOT #(i2:IDENT (arr = array_subscripts)?)  
				ast = component_reference)
			{
				if (!arr) arr = mk_nil();
				id = to_rml_str(i2);
				ast = Absyn__CREF_5fQUAL(
					id,
					arr,
					ast);

			}
		)
	;

function_call returns [void* ast]
	:
		#(FUNCTION_ARGUMENTS ast = function_arguments)
    ;

function_arguments 	returns [void* ast]
{
	l_stack el_stack;
	void* elist=0;
	void* namel=0;
}
	:
        (
            (elist=expression_list)? (namel = named_arguments)?
            {
                if (!namel) namel = mk_nil();
                if (!elist) elist = mk_nil();
                ast = Absyn__FUNCTIONARGS(elist,namel); 		
            }
        |   #(FOR_ITERATOR ast = for_iterator)
        )
	;

named_arguments returns [void* ast]
{
	l_stack el_stack;
	void* n;
} 
	:
		#(NAMED_ARGUMENTS (n = named_argument { el_stack.push(n); }) (n = named_argument { el_stack.push(n); } )*)
		{
			ast = make_rml_list_from_stack(el_stack);
		}
	;

named_argument returns [void* ast]
{
	void* temp;
}
	:
		#(eq:EQUALS i:IDENT temp = expression) 
		{
			ast = Absyn__NAMEDARG(to_rml_str(i),temp);
		}
	;

for_iterator returns [void *ast]
{
    void* expr;
    void* iter;
    void* id;
}
    :
        #(FOR expr = expression #(IN i:IDENT iter=expression))
        {
            id = to_rml_str(i);
            ast = Absyn__FOR_5fITER_5fFARG(expr,id,iter);
        }
    ;

expression_list returns [void* ast]
{
	l_stack el_stack;
	void* e;
}
	: 
		(#(EXPRESSION_LIST 
				e = expression { el_stack.push(e); }
				(e = expression { el_stack.push(e); } )*
			)
		)
		{
			ast = make_rml_list_from_stack(el_stack);
		}
	;

tuple_expression_list returns [void* ast]
{
	l_stack el_stack;
	void* e;
}
	: 
		(#(EXPRESSION_LIST 
				e = expression { el_stack.push(e); }
				(e = expression { el_stack.push(e); } )*
			)
		)
		{
			if (el_stack.size() == 1)
			{
				ast = el_stack.top();
			}
			else
			{
				ast = Absyn__TUPLE(make_rml_list_from_stack(el_stack));
			}
		}
	;

array_subscripts returns [void* ast]
{
	l_stack el_stack;
	void* s = 0;
}
	:
		#(LBRACK s = subscript 
			{
				el_stack.push(s);
			}
			(s = subscript
				{
					el_stack.push(s);
				}
			)* )
		{
			ast = make_rml_list_from_stack(el_stack);
		}
	;

subscript returns [void* ast]
{
	void* e;
}
	:
		(
			e = expression 
			{
				ast = Absyn__SUBSCRIPT(e);
			}
		| c:COLON 
			{
				ast = Absyn__NOSUB;
			}
		)
	;

comment returns [void* ast]
{
	void* ann=0;
	void* cmt=0;
    ast = 0;
}		:
		#(COMMENT cmt=string_comment (ann = annotation)?)
		{
	  		if (ann || cmt) {
				ast = Absyn__COMMENT(ann ? mk_some(ann) : mk_none(), 
		  							 cmt ? mk_some(cmt) : mk_none());
	  		}
		}
	;

string_comment returns [void *ast] :
	{
			void *cmt=0;
	  ast = 0;	   
	}
		#(STRING_COMMENT cmt=string_concatenation)
		{
			ast = cmt;
		}
	|
		{
			ast = 0;
		}
	;

string_concatenation returns [void * ast] :
		{ 
			ast = 0;
		}
		s:STRING {
	  		ast = to_rml_str(s);
		}
	|#(p:PLUS string_concatenation s2:STRING)
		{
			ast = to_rml_str(s2);
		}
	;

annotation returns [ void *ast]
{
    void *cmod=0;
}
    :
        #(a:ANNOTATION cmod = class_modification)
        {
            ast = Absyn__ANNOTATION(cmod);
        }
    ;		


