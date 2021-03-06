%{
%}

%token EOF NEWLINE SEMICOLON
%token AT ATD FIX OP_PAR CL_PAR OP_BRA CL_BRA COMMA DOT TYPE LAR OP_CUR CL_CUR JOIN FREE
%token <Tools.pos> LOG PLUS MULT MINUS AND OR GREATER SMALLER EQUAL PERT INTRO DELETE DO SET UNTIL TRUE FALSE OBS KAPPA_RAR TRACK CPUTIME CONFIG REPEAT DIFF
%token <Tools.pos> KAPPA_WLD KAPPA_SEMI SIGNATURE INFINITY TIME EVENT ACTIVITY NULL_EVENT PROD_EVENT INIT LET DIV PLOT SINUS COSINUS TAN ATAN COIN RAND_N SQRT EXPONENT POW ABS MODULO 
%token <Tools.pos> EMAX TMAX RAND_1 ALL FLUX ASSIGN ASSIGN2 TOKEN KAPPA_LNK PIPE KAPPA_LRAR PRINT PRINTF /*CAT VOLUME*/ MAX MIN
%token <int*Tools.pos> INT 
%token <string*Tools.pos> ID LABEL KAPPA_MRK NAME
%token <float*Tools.pos> FLOAT 
%token <string*Tools.pos> STRING
%token <Tools.pos> STOP SNAPSHOT

%token <Tools.pos> COMPARTMENT C_LINK TRANSPORT USE

%left MINUS PLUS MIN MAX
%left MULT DIV 10 
%left MODULO
%right POW 
%nonassoc LOG SQRT EXPONENT SINUS COSINUS ABS TAN

%left OR
%left AND

%start start_rule
%type <unit> start_rule 

%% /*Grammar rules*/

newline:
| NEWLINE start_rule
	{$2}
| EOF
	{()}
;

start_rule:
| newline
  {$1}
| rule_expression newline
	{let rule_label,r = $1 in Ast.result_glob := 
 		{!Ast.result_glob with Ast.rules_g = 
 			(rule_label,{r with Ast.use_id = List.length !Ast.result_glob.Ast.use_expressions})::!Ast.result_glob.Ast.rules_g} ; $2}
| instruction newline 
	{
		let inst = $1 in
		begin 
			match inst with
				| Ast.SIG (ag,pos) -> 
						(Ast.result_glob:={!Ast.result_glob with 
 						Ast.signatures_g=(ag,pos)::!Ast.result_glob.Ast.signatures_g}
						)
				| Ast.TOKENSIG (str,pos) -> 
						(Ast.result_glob:={!Ast.result_glob with 
 						Ast.tokens_g=(str,pos)::!Ast.result_glob.Ast.tokens_g}
						)
				(*| Ast.VOLSIG (vol_type,vol,vol_param) -> (Ast.result_glob := {
					!Ast.result_glob with 
						Ast.volumes_g=
							(vol_type,vol,vol_param,List.length !Ast.result_glob.Ast.use_expressions)::!Ast.result_glob.Ast.volumes_g})*)
				| Ast.INIT (opt_vol,init_t,pos) -> (Ast.result_glob := {
					!Ast.result_glob with 
						Ast.init_g=
						(opt_vol,init_t,pos,List.length !Ast.result_glob.Ast.use_expressions)::!Ast.result_glob.Ast.init_g})
				| Ast.DECLARE var ->
					(Ast.result_glob := 
						{!Ast.result_glob with 
							Ast.variables_g = !Ast.result_glob.Ast.variables_g @ [var,List.length !Ast.result_glob.Ast.use_expressions]}
					)
				| Ast.OBS var -> (*for backward compatibility, shortcut for %var + %plot*)
					let expr =
						match var with
							| Ast.VAR_KAPPA (_,lab) -> Ast.OBS_VAR lab 
							| Ast.VAR_ALG (_,lab) -> Ast.OBS_VAR lab
					in					 
					(Ast.result_glob := {!Ast.result_glob with 
						Ast.variables_g = !Ast.result_glob.Ast.variables_g @ [var,List.length !Ast.result_glob.Ast.use_expressions] ; 
						Ast.observables_g = expr::!Ast.result_glob.Ast.observables_g}
					)
				| Ast.PLOT expr ->
					(Ast.result_glob := {!Ast.result_glob with Ast.observables_g = expr::!Ast.result_glob.Ast.observables_g})
				| Ast.PERT (pre,effect,pos,opt) ->
					(Ast.result_glob := {!Ast.result_glob with 
						Ast.perturbations_g = 
							((pre,effect,pos,opt),List.length !Ast.result_glob.Ast.use_expressions)::!Ast.result_glob.Ast.perturbations_g})
				| Ast.CONFIG (param_name,value_list) ->
					(Ast.result_glob := {!Ast.result_glob with 
						Ast.configurations_g = (param_name,value_list)::!Ast.result_glob.Ast.configurations_g})
				| Ast.COMPART comp	-> (Ast.result_glob := {
					!Ast.result_glob with 
						Ast.compartments = 
						let ((name, _), index,_), exp, pos = comp
						in (*TODO error doble declaracion*)
							Hashtbl.add !Ast.result_glob.Ast.compartments name (index,exp,pos);
							!Ast.result_glob.Ast.compartments
					})
				| Ast.C_LNK link	-> (Ast.result_glob := {
					!Ast.result_glob
						with Ast.links = 
							let ( (nom,pos1), orig, arrow, dest, time , pos) = link in
							let float_time = match time with
								|Ast.FLOAT(x,p) -> x
								|Ast.INT (i,p) -> float_of_int i
								| _ -> raise (ExceptionDefn.Syntax_Error (Some pos1,"Travel time can only be constant int or float."))
							in
							let is_bidirectional = match arrow with |Ast.RAR _ -> false | Ast.LRAR _ -> true in
							Hashtbl.add !Ast.result_glob.Ast.links nom (orig,dest,is_bidirectional,float_time,pos);

							!Ast.result_glob.Ast.links
					})				
				| Ast.TRANSP transp	-> (
					Ast.result_glob := 
						{!Ast.result_glob with Ast.transports = transp::!Ast.result_glob.Ast.transports})
				| Ast.USE_C c_selected	-> (
					Ast.result_glob := {!Ast.result_glob with Ast.use_expressions = 
						let comp = match c_selected with
							| [] -> None
							| selected_list -> Some selected_list
						in !Ast.result_glob.Ast.use_expressions @ [comp]
					})
		end ; $2 
	}
| error 
	{raise (ExceptionDefn.Syntax_Error (None, "Syntax error"))}
;

instruction:
 /* */
 
 | COMPARTMENT comp_expr alg_expr
 	{Ast.COMPART ($2,$3,$1)}
 | C_LINK LABEL comp_expr arrow comp_expr ATD constant
 	{Ast.C_LNK ($2,$3,$4,$5,$7,$1)}
 | TRANSPORT join LABEL mixture AT alg_expr
 	{Ast.TRANSP ($3,$4,$6,$2,$1)}
 | USE comp_list
 	{Ast.USE_C ($2)}
 	
 
 /* */
| SIGNATURE agent_expression  
	{Ast.SIG ($2,$1)}
| TOKEN ID
	{let str,pos = $2 in Ast.TOKENSIG (str,pos)}
/*| VOLUME ID volume_param 
	{let vol,param = $3 in Ast.VOLSIG ($2,vol,param)}*/
| SIGNATURE error
	{raise (ExceptionDefn.Syntax_Error (Some $1,"Malformed agent signature, I was expecting something of the form '%agent: A(x,y~u~v,z)'"))}
| INIT init_declaration 
	{let (opt_vol,init) = $2 in Ast.INIT (opt_vol,init,$1)}
| INIT error
 {let pos = $1 in raise (ExceptionDefn.Syntax_Error (Some pos,"Malformed initial condition"))}
| LET variable_declaration 
	{Ast.DECLARE $2}
| OBS variable_declaration
	{Ast.OBS $2}
| PLOT alg_expr 
	{Ast.PLOT $2}
| PLOT error 
	{raise (ExceptionDefn.Syntax_Error (Some $1,"Malformed plot instruction, I was expecting an algebraic expression of variables"))}
| PERT perturbation_declaration {let (bool_expr,mod_expr_list,pos) = $2 in Ast.PERT (bool_expr,mod_expr_list,pos,None)}
| PERT REPEAT perturbation_declaration UNTIL bool_expr 
	{let (bool_expr,mod_expr_list,pos) = $3 in 
	 if List.exists 
		(fun effect -> 
			match effect with 
				| (Ast.CFLOW _ | Ast.CFLOWOFF _ | Ast.FLUX _ | Ast.FLUXOFF _) -> true 
				| _ -> false
		) mod_expr_list
	 then (ExceptionDefn.warning ~with_pos:$1 "Perturbation need not be applied repeatedly") ;
	Ast.PERT (bool_expr,mod_expr_list,pos,Some $5)}
| CONFIG STRING value_list 
	{Ast.CONFIG ($2,$3)}  
| PERT bool_expr DO effect_list UNTIL bool_expr /*for backward compatibility*/
	{ExceptionDefn.warning ~with_pos:$1 "Deprecated perturbation syntax: use the 'repeat ... until' construction" ; 
	Ast.PERT ($2,$4,$1,Some $6)}
;

init_declaration:
| multiple non_empty_mixture 
	{(None,Ast.INIT_MIX ($1,$2))}
| ID LAR multiple {(None,Ast.INIT_TOK ($3,$1))}
| ID OP_CUR init_declaration CL_CUR {let _,init = $3 in (Some $1,init)}
;

/*(*volume_param:
| OP_CUR FLOAT CL_CUR opt_param {let f,_ = $2 in (f,$4)}
| OP_CUR INT CL_CUR opt_param {let n,_ = $2 in (float_of_int n,$4)}
;

opt_param:
| (*empty*) {("passive",Tools.no_pos)}
| ID {$1}
*)*/

/*SPATIAL*/
join:
	/*empty*/
	{true}
|	JOIN
	{true}
|	FREE
	{false}

comp_expr: LABEL dimension where_expr
	{$1,$2,$3}
;

dimension: 
	/*empty*/
	{[]}
|	OP_BRA index_expr CL_BRA dimension
	{$2 :: $4}
;

index_expr:
	INT
	{let i,p = $1 in Ast.INT_I(i,p)}
|	ID /*iter var*/
	{let n,p = $1 in Ast.NAME(n,p)}
|	OP_PAR index_expr CL_PAR 
	{$2}
| 	index_expr MULT index_expr
	{Ast.MULT_I ($1,$3,$2)}
|	index_expr PLUS index_expr
	{Ast.SUM_I ($1,$3,$2)}
| 	index_expr DIV index_expr
	{Ast.DIV_I ($1,$3,$2)}
| 	index_expr MINUS index_expr
	{Ast.MINUS_I ($1,$3,$2)}
| 	index_expr POW index_expr
	{Ast.POW_I ($1,$3,$2)}
| 	index_expr MODULO index_expr
	{Ast.MODULO_I ($1,$3,$2)}	
;

value_list: 
| STRING 
	{[$1]}
| STRING value_list 
	{$1::$2}
;

comp_list:
		{[]}
	| ALL
	  	{[]}
	| comp_expr
		{[$1]}
	| comp_expr comp_list
		{$1::$2}
	| comp_expr COMMA comp_list
		{$1::$3}
;

where_expr: 
	/* empty */
		{None}
	| OP_CUR bool_expr CL_CUR
		{Some $2}
;

perturbation_declaration:
| OP_PAR perturbation_declaration CL_PAR {$2}
| bool_expr DO effect_list {($1,$3,$2)}
| bool_expr SET effect_list {ExceptionDefn.warning ~with_pos:$2 "Deprecated perturbation syntax: 'set' keyword is replaced by 'do'" ; ($1,$3,$2)} /*For backward compatibility*/
;

effect_list:
| OP_PAR effect_list CL_PAR {$2}
| effect {[$1]}
| effect SEMICOLON effect_list {$1::$3}
;

effect:
| LABEL ASSIGN alg_expr /*updating the rate of a rule -backward compatibility*/
	{let _ = ExceptionDefn.warning ~with_pos:$2 "Deprecated syntax, use $UPDATE perturbation instead of the ':=' assignment (see Manual)" in 
	Ast.UPDATE ($1,$3)}
| ASSIGN2 LABEL alg_expr /*updating the rate of a rule*/
	{Ast.UPDATE ($2,$3)}
| TRACK LABEL boolean 
	{let ast = if $3 then (fun x -> Ast.CFLOW x) else (fun x -> Ast.CFLOWOFF x) in ast ($2,$1)}
| FLUX opt_string boolean 
	{let ast = if $3 then (fun (x,y) -> Ast.FLUX (x,y)) else (fun (x,y) -> Ast.FLUXOFF (x,y)) in 
	match $2 with
		| (None,None) -> ast ([],$1)
		| (Some file,_) -> ast ([Ast.Str_pexpr file],$1)
		| (None, Some pexpr) -> ast (pexpr,$1)
	}
| INTRO multiple_mixture 
	{let (alg,mix) = $2 in Ast.INTRO (alg,mix,$1)}
| INTRO error
	{raise (ExceptionDefn.Syntax_Error (Some $1, "Malformed perturbation instruction, I was expecting '$ADD alg_expression kappa_expression'"))}
| DELETE multiple_mixture 
	{let (alg,mix) = $2 in Ast.DELETE (alg,mix,$1)}
| DELETE error
	{raise (ExceptionDefn.Syntax_Error (Some $1,"Malformed perturbation instruction, I was expecting '$DEL alg_expression kappa_expression'"))}
| ID LAR alg_expr /*updating the value of a token*/
	{Ast.UPDATE_TOK ($1,$3)}
| SNAPSHOT opt_string
	{match $2 with
		| (None,None) -> Ast.SNAPSHOT ([],$1)
		| (Some file,_) -> Ast.SNAPSHOT ([Ast.Str_pexpr file],$1)
		| (None, Some pexpr) -> Ast.SNAPSHOT (pexpr,$1)
		}
| STOP opt_string
	{match $2 with
		| (None,None) -> Ast.STOP ([],$1)
		| (Some file,_) -> Ast.STOP ([Ast.Str_pexpr file],$1)
		| (None, Some pexpr) -> Ast.STOP (pexpr,$1)
		}
| PRINT SMALLER print_expr GREATER {(Ast.PRINT ([],$3,$1))}
| PRINTF string_or_pr_expr SMALLER print_expr GREATER 
	{match $2 with
		| (None,None) -> Ast.PRINT ([],$4,$1)
		| (Some file,_) -> Ast.PRINT ([Ast.Str_pexpr file],$4,$1)
		| (None, Some pexpr) -> Ast.PRINT (pexpr,$4,$1) 
	}
;

print_expr:
/*empty*/ {[]}
| STRING {[Ast.Str_pexpr $1]}
| alg_expr {[Ast.Alg_pexpr $1]}
| STRING DOT print_expr {(Ast.Str_pexpr $1)::$3}
| alg_expr DOT print_expr {(Ast.Alg_pexpr $1)::$3}
;

boolean:
| TRUE {true}
| FALSE {false}
;

variable_declaration:
| LABEL non_empty_mixture {Ast.VAR_KAPPA ($2,$1)}
| LABEL alg_expr {Ast.VAR_ALG ($2,$1)}
| LABEL error 
	{let str,pos = $1 in
		raise 
		(ExceptionDefn.Syntax_Error (Some pos,
		(Printf.sprintf "Variable '%s' should be either a pure kappa expression or an algebraic expression on variables" str))
		) 
	}
;

bool_expr:
| OP_PAR bool_expr CL_PAR 
	{$2}
| bool_expr AND bool_expr 
	{Ast.AND ($1,$3,$2)}
| bool_expr OR bool_expr 
	{Ast.OR ($1,$3,$2)}
| alg_expr GREATER alg_expr 
	{Ast.GREATER ($1,$3,$2)}
| alg_expr SMALLER alg_expr 
	{Ast.SMALLER ($1,$3,$2)}
| alg_expr EQUAL alg_expr 
	{Ast.EQUAL ($1,$3,$2)}
| alg_expr DIFF alg_expr  
	{Ast.DIFF ($1,$3,$2)}
| TRUE
	{Ast.TRUE $1}
| FALSE
	{Ast.FALSE $1}
;

opt_string:
/*empty*/ {None,None}
| STRING {Some $1,None}
| SMALLER print_expr GREATER {None, Some $2}
;

string_or_pr_expr:
| STRING {Some $1,None}
| SMALLER print_expr GREATER {None, Some $2}
;


multiple:
| INT {let int,pos=$1 in Ast.INT (int,pos) }
| FLOAT {let x,pos=$1 in Ast.FLOAT (x,pos) }
| LABEL {let str,pos = $1 in Ast.OBS_VAR (str,pos)}
;

rule_label: 
/*empty */
	{{Ast.lbl_nme = None ; Ast.lbl_ref = None}}
| LABEL 
	{let lab,pos = $1 in {Ast.lbl_nme=Some (lab,pos) ; Ast.lbl_ref = None}}
;

lhs_rhs:
mixture token_expr {($1,$2)}
;

token_expr:
/*empty*/ {[]}
| PIPE sum_token {$2} 
| PIPE error 
	{let pos = $1 in 
	raise (ExceptionDefn.Syntax_Error (Some pos, "Malformed token expression, I was expecting a_0 t_0 + ... + a_n t_n, where t_i are tokens and a_i any algebraic formula"))}
;

sum_token:
| OP_PAR sum_token CL_PAR 
	{$2} 
| alg_expr TYPE ID 
	{[($1,$3)]}
| alg_expr TYPE ID PLUS sum_token 
	{let l = $5 in ($1,$3)::l}

mixture:
/*empty*/ 
	{Ast.EMPTY_MIX}
| non_empty_mixture 
	{$1}
;

/*(**  **)*/

rate_sep:
| AT {false}
| FIX {true}

/*(**  **)*/

rule_expression:
| rule_label lhs_rhs arrow lhs_rhs rate_sep rate 
	{ let pos = match $3 with Ast.RAR pos | Ast.LRAR pos -> pos in
		let (k2,k1,kback) = $6 in
		let _ =
			match (kback,$3) with
				| (None,Ast.LRAR pos) | (Some _,Ast.RAR pos) -> raise (ExceptionDefn.Syntax_Error (Some pos,"Malformed bi-directional rule expression"))
				| _ -> ()
		in
		let lhs,token_l = $2 and rhs,token_r = $4 in 
		($1,{Ast.rule_pos = pos ;
			Ast.lhs=lhs; 
			Ast.rm_token = token_l ; 
			Ast.arrow=$3; 
			Ast.rhs=rhs; 
			Ast.add_token = token_r; 
			Ast.k_def=k2; 
			Ast.k_un=k1; 
			Ast.k_op=kback; 
			Ast.use_id = -1; 
			Ast.transport_to = None; 
			Ast.fixed = $5})
	}
| rule_label lhs_rhs arrow lhs_rhs 
	{let pos = match $3 with Ast.RAR pos | Ast.LRAR pos -> pos in
	let lhs,token_l = $2 and rhs,token_r = $4 in 
		ExceptionDefn.warning ~with_pos:pos "Rule has no kinetics. Default rate of 0.0 is assumed." ; 
		($1,{Ast.rule_pos = pos ;
		 Ast.lhs=lhs; 
		 Ast.rm_token = token_l; 
		 Ast.arrow=$3; 
		 Ast.rhs=rhs; 
		 Ast.add_token = token_r; 
		 Ast.k_def=Ast.FLOAT (0.0,Tools.no_pos); 
		 Ast.k_un=None ;
		 Ast.k_op=None; 
		 Ast.use_id = -1; 
		 Ast.transport_to = None; Ast.fixed = true })
	}
;

arrow:
| KAPPA_RAR 
	{Ast.RAR $1}
| KAPPA_LRAR
	{Ast.LRAR $1}
;

constant:
| INFINITY
	{Ast.INFINITY $1}
| FLOAT
	{let f,pos = $1 in Ast.FLOAT (f,pos)}
| INT 
	{let i,pos = $1 in Ast.INT (i,pos)}
| EMAX
	{let pos = $1 in Ast.EMAX pos}
| TMAX
	{let pos = $1 in Ast.TMAX pos}
| CPUTIME
	{let pos = $1 in Ast.CPUTIME pos}
;

variable:
| PIPE ID PIPE 
	{let str,pos = $2 in Ast.TOKEN_ID (str,pos)}
| LABEL 
	{let str,pos = $1 in Ast.OBS_VAR (str,pos)}
| TIME
	{Ast.TIME_VAR $1}
| EVENT
	{Ast.EVENT_VAR $1}
| NULL_EVENT
	{Ast.NULL_EVENT_VAR $1}
| PROD_EVENT
	{Ast.PROD_EVENT_VAR $1}
| ACTIVITY
	{Ast.ACTIVITY_VAR $1}
;

alg_expr:
| OP_PAR alg_expr CL_PAR 
	{$2}
| constant 
	{$1}
| variable
	{$1}
| ID
	{Ast.OBS_VAR $1}
| alg_expr MULT alg_expr
	{Ast.MULT ($1,$3,$2)}
| alg_expr PLUS alg_expr
	{Ast.SUM ($1,$3,$2)}
| alg_expr DIV alg_expr
	{Ast.DIV ($1,$3,$2)}
| alg_expr MINUS alg_expr
	{Ast.MINUS ($1,$3,$2)}
| alg_expr POW alg_expr
	{Ast.POW ($1,$3,$2)}
| alg_expr MODULO alg_expr
	{Ast.MODULO ($1,$3,$2)}	
| MAX alg_expr alg_expr
	{Ast.MAX ($2,$3,$1)}
| MIN alg_expr alg_expr
	{Ast.MIN ($2,$3,$1)}
| EXPONENT alg_expr 
	{Ast.EXP ($2,$1)}
| SINUS alg_expr 
	{Ast.SINUS ($2,$1)}
| COSINUS alg_expr 
	{Ast.COSINUS ($2,$1)}
| TAN alg_expr 
	{Ast.TAN ($2,$1)}
| ABS alg_expr 
	{Ast.ABS ($2,$1)}
| SQRT alg_expr 
	{Ast.SQRT ($2,$1)}
| LOG alg_expr
	{Ast.LOG ($2,$1)}
/*(***)*/
| ATAN alg_expr 
	{Ast.ATAN ($2,$1)}
| COIN alg_expr
	{Ast.COIN ($2,$1)}
| RAND_N alg_expr
	{Ast.RAND_N ($2,$1)}
| RAND_1
	{Ast.RAND_1 $1}
;

rate:
| alg_expr OP_PAR alg_with_radius CL_PAR 
	{($1,Some $3,None)}
| alg_expr 
	{($1,None,None)}
| alg_expr COMMA alg_expr 
	{($1,None,Some $3)}
;

alg_with_radius:
| alg_expr {($1,None)}
| alg_expr TYPE alg_expr {($1,Some $3)}
;

multiple_mixture:
| alg_expr non_empty_mixture /*conflict here because ID (blah) could be token non_empty mixture or mixture...*/
	{($1,$2)}
| non_empty_mixture 
	{(Ast.FLOAT (1.,Tools.no_pos),$1)}
;

non_empty_mixture:
| OP_PAR non_empty_mixture CL_PAR
	{$2}
| agent_expression COMMA non_empty_mixture  
	{Ast.COMMA ($1,$3)}
| agent_expression 
	{Ast.COMMA($1,Ast.EMPTY_MIX)}
;

agent_expression:
| ID OP_PAR interface_expression CL_PAR 
	{let (id,pos) = $1 in {Ast.ag_nme=id; Ast.ag_intf=$3; Ast.ag_pos=pos}}
| ID error 
	{let str,pos = $1 in raise (ExceptionDefn.Syntax_Error (Some pos,Printf.sprintf "Malformed agent '%s'" str))}
;

interface_expression:
/*empty*/ 
	{Ast.EMPTY_INTF}
| ne_interface_expression 
	{$1}
;

ne_interface_expression:
| port_expression COMMA ne_interface_expression 
	{Ast.PORT_SEP($1,$3)}
| port_expression  
	{Ast.PORT_SEP($1,Ast.EMPTY_INTF)}
;


port_expression:
| ID internal_state link_state 
	{let (id,pos) = $1 in {Ast.port_nme=id; Ast.port_int=$2; Ast.port_lnk=$3; Ast.port_pos=pos}}
;

internal_state:
/*empty*/ {[]}
| KAPPA_MRK internal_state 
	{let m,pos = $1 in m::$2}
| error 
	{raise (ExceptionDefn.Syntax_Error (None,"Invalid internal state"))}
;

link_state:
/*empty*/ 
	{Ast.FREE}
| KAPPA_LNK INT 
	{Ast.LNK_VALUE $2}
| KAPPA_LNK KAPPA_SEMI 
	{Ast.LNK_SOME $2}
| KAPPA_LNK ID DOT ID
	{Ast.LNK_TYPE ($2,$4)}
| KAPPA_WLD 
	{Ast.LNK_ANY $1}
| KAPPA_LNK error 
	{let pos = $1 in raise (ExceptionDefn.Syntax_Error (Some pos,"Invalid link state"))}
;

%%
