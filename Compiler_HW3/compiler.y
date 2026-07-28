
%{
    #include "compiler_common.h" //Extern variables that communicate with lex
    // #define YYDEBUG 1
    // int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    int yylex_destroy ();
    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    /* Used to generate code */
    /* As printf; the usage: CODEGEN("%d - %s\n", 100, "Hello world"); */
    /* We do not enforce the use of this macro */
    #define CODEGEN(...) \
        do { \
            for (int i = 0; i < g_indent_cnt; i++) { \
                fprintf(fout, "\t"); \
            } \
            fprintf(fout, __VA_ARGS__); \
        } while (0)

    SymbolTable *current_scope = NULL;
    int current_scope_level = 0;
    int global_address_counter = 0;

    //Label計數
    int g_label_count = 0;
    
    void enter_scope();
    void exit_scope();
    int lookup_symbol_addr(char *name);
    char *lookup_symbol_type(char *name);
    int lookup_symbol_mutability(char *name);
    void insert_symbol_to_table(char *name, char *type, int is_mutable, int lineno);
    void create_symbol();
    void dump_symbol();

    /* Global variables */
    bool g_has_error = false;
    FILE *fout = NULL;
    int g_indent_cnt = 0;
%}



/* Use variable or self-defined structure to represent
 * nonterminal and token type
 *  - you can add new fields if needed.
 */
%union {
    int i_val;
    float f_val;
    char *s_val;
    /* ... */
}

/* Token without return */
%token LET MUT NEWLINE
%token INT FLOAT BOOL STR
%token TRUE FALSE
%token GEQ LEQ EQL NEQ LOR LAND
%token ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN DIV_ASSIGN REM_ASSIGN
%token IF ELSE WHILE
%token PRINT PRINTLN
%token FUNC
%token AS LSHIFT

/* Token with return, which need to sepcify type */
%token <s_val> IDENT
%token <s_val> STRING_LIT
%token <i_val> INT_LIT
%token <f_val> FLOAT_LIT

/* Nonterminal with return, which need to sepcify type */
%type <s_val> Type Expr Factor
%type <s_val> LORExpr LANDExpr EqExpr RelExpr AddExpr MulExpr UnaryExpr ShiftExpr

%left LOR
%left LAND
%left EQL NEQ
%left '<' '>' GEQ LEQ
%left '+' '-'
%left '*' '/' '%'
%right '!' '~'


/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%

Program
    : GlobalStatementList
;

GlobalStatementList
    : GlobalStatementList GlobalStatement
    | GlobalStatement
;

GlobalStatement
    : FunctionDeclStmt
    | Block
    | NEWLINE
;

FunctionDeclStmt
    : FUNC IDENT '(' ')' {
        if (strcmp($2, "main") == 0) {
            CODEGEN(".method public static main([Ljava/lang/String;)V\n");
            CODEGEN(".limit stack 100\n");
            CODEGEN(".limit locals 100\n");
        }
        insert_symbol_to_table($2, "func", -1, yylineno); 
    }
    Block {
        if (strcmp($2, "main") == 0) {
            CODEGEN("return\n");
            CODEGEN(".end method\n");
        }
        dump_symbol();
    }
;

Block
    : '{' { enter_scope(); } StatementList '}' { exit_scope(); }
;

StatementList
    : StatementList Statement
    | /* empty */
;

Statement
    : VarDeclStmt
    | AssignStmt
    | PrintStmt
    | IfStmt
    | WhileStmt
    | Block
    | NEWLINE
;

VarDeclStmt
    : LET IDENT ':' Type '=' Expr ';' { 
        insert_symbol_to_table($2, $4, 0, yylineno);
        int addr = lookup_symbol_addr($2);
        char *type = $4;
        if (strcmp(type, "i32") == 0) {
            CODEGEN("istore %d\n", addr);
        } else if (strcmp(type, "f32") == 0) {
            CODEGEN("fstore %d\n", addr);
        } else if (strcmp(type, "str") == 0) {
            CODEGEN("astore %d\n", addr);
        } else if (strcmp(type, "bool") == 0) {
            CODEGEN("istore %d\n", addr);
        }
    }
    | LET MUT IDENT ':' Type '=' Expr ';' { 
        if (strcmp($5, $7) != 0 && strcmp($7, "undefined") != 0) {
            printf("error:%d: type mismatch: declared %s but assigned %s\n", yylineno, $5, $7);
        }
        insert_symbol_to_table($3, $5, 1, yylineno); 
        int addr = lookup_symbol_addr($3);
        char *type = $5;
        // !!!這裡要補store!!!
        if (strcmp(type, "i32") == 0) {
            CODEGEN("istore %d\n", addr);
        } else if (strcmp(type, "f32") == 0) {
            CODEGEN("fstore %d\n", addr);
        } else if (strcmp(type, "str") == 0) {
            CODEGEN("astore %d\n", addr);
        } else if (strcmp(type, "bool") == 0) {
            CODEGEN("istore %d\n", addr);
        } 
    }
    | LET IDENT ':' Type ';' { insert_symbol_to_table($2, $4, 0, yylineno); }
    | LET MUT IDENT ':' Type ';' { insert_symbol_to_table($3, $5, 1, yylineno); }
    | LET IDENT '=' Expr ';' { insert_symbol_to_table($2, $4, 0, yylineno); int addr = lookup_symbol_addr($2);
        char *type = $4;
        if (strcmp(type, "i32") == 0) {
            CODEGEN("istore %d\n", addr);
        } else if (strcmp(type, "f32") == 0) {
            CODEGEN("fstore %d\n", addr);
        } else if (strcmp(type, "str") == 0) {
            CODEGEN("astore %d\n", addr);
        } else if (strcmp(type, "bool") == 0) {
            CODEGEN("istore %d\n", addr);
        }
    }
    | LET MUT IDENT '=' Expr ';' { insert_symbol_to_table($3, $5, 1, yylineno); int addr = lookup_symbol_addr($3);
        char *type = $5;
        if (strcmp(type, "i32") == 0) {
            CODEGEN("istore %d\n", addr);
        } else if (strcmp(type, "f32") == 0) {
            CODEGEN("fstore %d\n", addr);
        } else if (strcmp(type, "str") == 0) {
            CODEGEN("astore %d\n", addr);
        } else if (strcmp(type, "bool") == 0) {
            CODEGEN("istore %d\n", addr);
        }
    }
;

AssignStmt
    : IDENT '=' Expr ';' {
        int addr = lookup_symbol_addr($1);
        int is_mutable = lookup_symbol_mutability($1);
        int err_flag = 0;
        if (addr == -1) {
            printf("error:%d: undefined: %s\n", yylineno, $1);
            err_flag = 1;
        } else {
            char *declared_type = lookup_symbol_type($1);
            if (strcmp(declared_type, $3) != 0 && strcmp($3, "undefined") != 0) {
                printf("error:%d: invalid operation: ASSIGN (mismatched types %s and %s)\n", yylineno, declared_type, $3);
                err_flag = 1;
            }
        }
        if (addr != -1 && is_mutable == 0) {
            printf("ASSIGN\n");
            printf("error:%d: cannot borrow immutable borrowed content `%s` as mutable\n", yylineno, $1);
            err_flag = 1;
        }
        if(!err_flag) {
            char *declared_type = lookup_symbol_type($1);
            if (strcmp(declared_type, "i32") == 0 || strcmp(declared_type, "bool") == 0) {
                CODEGEN("istore %d\n", addr);
            } else if (strcmp(declared_type, "f32") == 0) {
                CODEGEN("fstore %d\n", addr);
            } else if (strcmp(declared_type, "str") == 0) {
                CODEGEN("astore %d\n", addr);
            }
        }
    }
    | IDENT ADD_ASSIGN Expr ';'  {
        int addr = lookup_symbol_addr($1);
        int err_flag = 0;
        if (addr == -1) {
            err_flag = 1;
            printf("error:%d: undefined: %s\n", yylineno, $1);
            
        } else if (lookup_symbol_mutability($1) == 0) {
            err_flag = 1;
            printf("error:%d: cannot borrow immutable borrowed content `%s` as mutable\n", yylineno, $1);
            
        } else {
            char *declared_type = lookup_symbol_type($1);
            if (strcmp(declared_type, $3) != 0 && strcmp($3, "undefined") != 0) {
                err_flag = 1;
                printf("error:%d: invalid operation: ADD_ASSIGN (mismatched types %s and %s)\n", yylineno, declared_type, $3);
                
            }
        }
        if (!err_flag) {
            char *declared_type = lookup_symbol_type($1);
            if (strcmp(declared_type, "i32") == 0) {
                CODEGEN("iload %d\n", addr);
                CODEGEN("iadd\n");
                CODEGEN("istore %d\n", addr);
            } else if (strcmp(declared_type, "f32") == 0) {
                CODEGEN("fload %d\n", addr);
                CODEGEN("fadd\n");
                CODEGEN("fstore %d\n", addr);
            }
        }
    }
    | IDENT SUB_ASSIGN Expr ';' {
        int addr = lookup_symbol_addr($1);
        int err_flag = 0;
        if (addr == -1) {
            err_flag = 1;
            printf("error:%d: undefined: %s\n", yylineno, $1);
            
        } else if (lookup_symbol_mutability($1) == 0) {
            err_flag = 1;
            printf("error:%d: cannot borrow immutable borrowed content `%s` as mutable\n", yylineno, $1);
            
        } else {
            char *declared_type = lookup_symbol_type($1);
            if (strcmp(declared_type, $3) != 0 && strcmp($3, "undefined") != 0) {
                err_flag = 1;
                printf("error:%d: invalid operation: SUB_ASSIGN (mismatched types %s and %s)\n", yylineno, declared_type, $3);
                
            }

        }
        if (!err_flag) {
            char *declared_type = lookup_symbol_type($1);
            if (strcmp(declared_type, "i32") == 0) {
            	CODEGEN("iload %d\n", addr); // stack: n, x
                CODEGEN("swap\n");           // stack: x, n
                CODEGEN("isub\n");
                CODEGEN("istore %d\n", addr);
        } else if (strcmp(declared_type, "f32") == 0) {
                CODEGEN("fload %d\n", addr);
                CODEGEN("swap\n");
                CODEGEN("fsub\n");
                CODEGEN("fstore %d\n", addr);
            }
        } 
    }
    | IDENT MUL_ASSIGN Expr ';' {
        int addr = lookup_symbol_addr($1);
        int err_flag = 0;
        if (addr == -1) {
            err_flag = 1;
            printf("error:%d: undefined: %s\n", yylineno, $1);
            
        } else if (lookup_symbol_mutability($1) == 0) {
            err_flag = 1;
            printf("error:%d: cannot borrow immutable borrowed content `%s` as mutable\n", yylineno, $1);
            
        } else {
            char *declared_type = lookup_symbol_type($1);
            if (strcmp(declared_type, $3) != 0 && strcmp($3, "undefined") != 0) {
                err_flag = 1;
                printf("error:%d: invalid operation: MUL_ASSIGN (mismatched types %s and %s)\n", yylineno, declared_type, $3);
                
            }
        }
        if (!err_flag) {
            char *declared_type = lookup_symbol_type($1);
            if (strcmp(declared_type, "i32") == 0) {
                CODEGEN("iload %d\n", addr);
                CODEGEN("imul\n");
                CODEGEN("istore %d\n", addr);
            } else if (strcmp(declared_type, "f32") == 0) {
                CODEGEN("fload %d\n", addr);
                CODEGEN("fmul\n");
                CODEGEN("fstore %d\n", addr);
            }
        }
    }
    | IDENT DIV_ASSIGN Expr ';'  {
        int addr = lookup_symbol_addr($1);
        int err_flag = 0;
        if (addr == -1) {
            err_flag = 1;
            printf("error:%d: undefined: %s\n", yylineno, $1);
            
        } else if (lookup_symbol_mutability($1) == 0) {
            err_flag = 1;
            printf("error:%d: cannot borrow immutable borrowed content `%s` as mutable\n", yylineno, $1);
        
        } else {
            char *declared_type = lookup_symbol_type($1);
            if (strcmp(declared_type, $3) != 0 && strcmp($3, "undefined") != 0) {
                err_flag = 1;
                printf("error:%d: invalid operation: DIV_ASSIGN (mismatched types %s and %s)\n", yylineno, declared_type, $3);
            }
        }
        if (!err_flag) {
            char *declared_type = lookup_symbol_type($1);
            if (strcmp(declared_type, "i32") == 0) {
                // Expr 會把 n 先產生 (stack: n)
                CODEGEN("iload %d\n", addr); // stack: n, x
                CODEGEN("swap\n");           // stack: x, n
                CODEGEN("idiv\n");           // stack: x-n
                CODEGEN("istore %d\n", addr);
            } else if (strcmp(declared_type, "f32") == 0) {
                CODEGEN("fload %d\n", addr);
                CODEGEN("swap\n");
                CODEGEN("fdiv\n");
                CODEGEN("fstore %d\n", addr);
            }
        }
    }
    | IDENT REM_ASSIGN Expr ';'  {
        int addr = lookup_symbol_addr($1);
        int err_flag = 0;
        if (addr == -1) {
            err_flag = 1;
            printf("error:%d: undefined: %s\n", yylineno, $1);
            
        } else if (lookup_symbol_mutability($1) == 0) {
            err_flag = 1;
            printf("error:%d: cannot borrow immutable borrowed content `%s` as mutable\n", yylineno, $1);
            
        } else {
            char *declared_type = lookup_symbol_type($1);
            if (strcmp(declared_type, $3) != 0 && strcmp($3, "undefined") != 0) {
                err_flag = 1;
                printf("error:%d: invalid operation: REM_ASSIGN (mismatched types %s and %s)\n", yylineno, declared_type, $3);
                
            }
        }
        if (!err_flag) {
            char *declared_type = lookup_symbol_type($1);
            if (strcmp(declared_type, "i32") == 0) {
                CODEGEN("iload %d\n", addr);
                CODEGEN("swap\n");
                CODEGEN("irem\n");
                CODEGEN("istore %d\n", addr);
            }
        // f32 沒有餘數
        }
    }
;



PrintStmt
    : PRINTLN '(' IDENT '[' INT_LIT ']' ')' ';' {
          int addr = lookup_symbol_addr($3);
          if (addr == -1) {
              printf("error:%d: undefined: %s\n", yylineno, $3);
          } else {
              printf("IDENT (name=%s, address=%d)\n", $3, addr);
              printf("INT_LIT %d\n", $5);
              printf("PRINTLN array\n");
          }
      }
    | PRINTLN '(' Expr ')' ';' {
        char *type = $3;
        if (strcmp(type, "i32") == 0) {
            CODEGEN("getstatic java/lang/System/out Ljava/io/PrintStream;\n");
            // 上面已經將運算結果壓到 stack
            // （假設已經在Expr產生iload/iadd/...）
            CODEGEN("swap\n");
            CODEGEN("invokevirtual java/io/PrintStream/println(I)V\n");
        } else if (strcmp(type, "f32") == 0) {
            CODEGEN("getstatic java/lang/System/out Ljava/io/PrintStream;\n");
            CODEGEN("swap\n");
            CODEGEN("invokevirtual java/io/PrintStream/println(F)V\n");
        } else if (strcmp(type, "str") == 0) {
            CODEGEN("getstatic java/lang/System/out Ljava/io/PrintStream;\n");
            CODEGEN("swap\n");
            CODEGEN("invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");
        } else if (strcmp(type, "bool") == 0) {
            // 輸出 true/false (你可以先處理成string)
            CODEGEN("getstatic java/lang/System/out Ljava/io/PrintStream;\n");
            CODEGEN("swap\n");
            CODEGEN("invokevirtual java/io/PrintStream/println(Z)V\n");
        }
    }
    | PRINT   '(' Expr ')' ';'{
        char *type = $3;
        if (strcmp(type, "i32") == 0) {
            CODEGEN("getstatic java/lang/System/out Ljava/io/PrintStream;\n");
            // 上面已經將運算結果壓到 stack
            // （假設已經在Expr產生iload/iadd/...）
            CODEGEN("swap\n");
            CODEGEN("invokevirtual java/io/PrintStream/print(I)V\n");
        } else if (strcmp(type, "f32") == 0) {
            CODEGEN("getstatic java/lang/System/out Ljava/io/PrintStream;\n");
            CODEGEN("swap\n");
            CODEGEN("invokevirtual java/io/PrintStream/print(F)V\n");
        } else if (strcmp(type, "str") == 0) {
            CODEGEN("getstatic java/lang/System/out Ljava/io/PrintStream;\n");
            CODEGEN("swap\n");
            CODEGEN("invokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n");
        } else if (strcmp(type, "bool") == 0) {
            // 輸出 true/false (你可以先處理成string)
            CODEGEN("getstatic java/lang/System/out Ljava/io/PrintStream;\n");
            CODEGEN("swap\n");
            CODEGEN("invokevirtual java/io/PrintStream/print(Z)V\n");
        }
    }
;



IfStmt
    : IF Expr Block {
        int end_label = g_label_count++;
        CODEGEN("ifeq L%d\n", end_label); // == 0 跳過 then
        // then block code
        // Block 已經產生
        CODEGEN("L%d:\n", end_label);
    }
    | IF Expr Block ELSE Block {
        int else_label = g_label_count++;
        int end_label = g_label_count++;
        CODEGEN("ifeq L%d\n", else_label); // == 0 跳 else
        // then block code
        // Block 已經產生
        CODEGEN("goto L%d\n", end_label);
        CODEGEN("L%d:\n", else_label);
        // else block code
        // Block 已經產生
        CODEGEN("L%d:\n", end_label);
    }
;
WhileStmt
    : WHILE Expr Block { }
;

Type
    : INT   { $$ = "i32"; }
    | FLOAT { $$ = "f32"; }
    | BOOL  { $$ = "bool"; }
    | STR   { $$ = "str"; }
    | '&' STR { $$ = "str"; }
    | '[' Type ';' INT_LIT ']' { printf("INT_LIT %d\n", $4); $$ = "array"; }

;

Expr      : LORExpr ;

LORExpr   : LORExpr LOR LANDExpr   { 
                // OR: 只要有一個是 1 就 1
                CODEGEN("iadd\n");
                int label_true = g_label_count++;
                int label_end = g_label_count++;
                CODEGEN("ifgt L%d\n", label_true); // >0 則為 true
                CODEGEN("iconst_0\n");
                CODEGEN("goto L%d\n", label_end);
                CODEGEN("L%d:\n", label_true);
                CODEGEN("iconst_1\n");
                CODEGEN("L%d:\n", label_end);
                $$ = "bool";

            }
          | LANDExpr
          ;

LANDExpr  : LANDExpr LAND EqExpr   { 
                // AND: 只要有一個是 0 就 0
                CODEGEN("imul\n");
                $$ = "bool"; 
            }
          | EqExpr
          ;

EqExpr    : EqExpr EQL RelExpr {
                if (strcmp($1, $3) != 0 && strcmp($1, "undefined") != 0 && strcmp($3, "undefined") != 0) {
                    printf("error:%d: invalid operation: EQL (mismatched types %s and %s)\n", yylineno, $1, $3);
                }
                int label_true = g_label_count++;
                int label_end = g_label_count++;
                if (strcmp($1, "i32") == 0 || strcmp($1, "bool") == 0) {
                    CODEGEN("isub\n");
                    CODEGEN("ifeq L%d\n", label_true);   // 等於就跳
                } else if (strcmp($1, "f32") == 0) {
                    CODEGEN("fcmpl\n");
                    CODEGEN("ifeq L%d\n", label_true);
                } else if (strcmp($1, "str") == 0) {
                    CODEGEN("invokevirtual java/lang/String/equals(Ljava/lang/Object;)Z\n");
                    CODEGEN("ifne L%d\n", label_true);
                }
                CODEGEN("iconst_0\n");
                CODEGEN("goto L%d\n", label_end);
                CODEGEN("L%d:\n", label_true);
                CODEGEN("iconst_1\n");
                CODEGEN("L%d:\n", label_end);
                $$ = "bool";
            }
          | EqExpr NEQ RelExpr     { 
                if (strcmp($1, $3) != 0 && strcmp($1, "undefined") != 0 && strcmp($3, "undefined") != 0) {
                    printf("error:%d: invalid operation: NEQ (mismatched types %s and %s)\n", yylineno, $1, $3);
                }
                int label_true = g_label_count++;
                int label_end = g_label_count++;
                if (strcmp($1, "i32") == 0 || strcmp($1, "bool") == 0) {
                    CODEGEN("isub\n");
                    CODEGEN("ifne L%d\n", label_true);   // 不等於就跳
                } else if (strcmp($1, "f32") == 0) {
                    CODEGEN("fcmpl\n");
                    CODEGEN("ifne L%d\n", label_true);
                } else if (strcmp($1, "str") == 0) {
                    CODEGEN("invokevirtual java/lang/String/equals(Ljava/lang/Object;)Z\n");
                    CODEGEN("ifeq L%d\n", label_true);
                }
                CODEGEN("iconst_0\n");
                CODEGEN("goto L%d\n", label_end);
                CODEGEN("L%d:\n", label_true);
                CODEGEN("iconst_1\n");
                CODEGEN("L%d:\n", label_end);
                $$ = "bool";
            }
          | RelExpr
          ;

RelExpr   : RelExpr '>' ShiftExpr {
                if ((strcmp($1, "undefined") == 0 || strcmp($3, "undefined") == 0) ||
                (strcmp($1, $3) != 0 && strcmp($1, "undefined") != 0 && strcmp($3, "undefined") != 0)) {
                    printf("error:%d: invalid operation: GTR (mismatched types %s and %s)\n", yylineno, $1, $3);
                }
                int label_true = g_label_count++;
                int label_end = g_label_count++;
                if (strcmp($1, "i32") == 0) {
                    CODEGEN("isub\n");
                    CODEGEN("ifgt L%d\n", label_true);   // >0 就是大於
                } else if (strcmp($1, "f32") == 0) {
                    CODEGEN("fcmpl\n");
                    CODEGEN("ifgt L%d\n", label_true);
                }
                CODEGEN("iconst_0\n");
                CODEGEN("goto L%d\n", label_end);
                CODEGEN("L%d:\n", label_true);
                CODEGEN("iconst_1\n");
                CODEGEN("L%d:\n", label_end);
                $$ = "bool";
            }
          | RelExpr '<' ShiftExpr  {  
                if (strcmp($1, $3) != 0 && strcmp($1, "undefined") != 0 && strcmp($3, "undefined") != 0) {
                    printf("error:%d: invalid operation: LSS (mismatched types %s and %s)\n", yylineno, $1, $3);
                }
                int label_true = g_label_count++;
                int label_end = g_label_count++;
                if (strcmp($1, "i32") == 0) {
                    CODEGEN("isub\n");
                    CODEGEN("iflt L%d\n", label_true);   // <0
                } else if (strcmp($1, "f32") == 0) {
                    CODEGEN("fcmpl\n");
                    CODEGEN("iflt L%d\n", label_true);
                }
                CODEGEN("iconst_0\n");
                CODEGEN("goto L%d\n", label_end);
                CODEGEN("L%d:\n", label_true);
                CODEGEN("iconst_1\n");
                CODEGEN("L%d:\n", label_end);
                $$ = "bool"; 
            }
          | RelExpr GEQ ShiftExpr  { /* printf("GEQ\n"); */ $$ = "bool"; }
          | RelExpr LEQ ShiftExpr  { /* printf("LEQ\n"); */ $$ = "bool"; }
          | ShiftExpr
          ;


ShiftExpr : ShiftExpr LSHIFT AddExpr {
                int is_type_ok = 0;
                if (strcmp($1, "i32") == 0 && strcmp($3, "i32") == 0) is_type_ok = 1;
                if (!is_type_ok) {
                    printf("error:%d: invalid operation: LSHIFT (mismatched types %s and %s)\n", yylineno, $1, $3);
                }
                printf("LSHIFT\n");
                $$ = $1;
            }
          | AddExpr
          ;

AddExpr   : AddExpr '+' MulExpr    {
                if(strcmp($1, "i32") == 0){
                    CODEGEN("iadd\n");
                    $$ = "i32";
                }else if(strcmp($1, "f32") == 0){
                    CODEGEN("fadd\n");
                    $$ = "f32";
                }
            }
          | AddExpr '-' MulExpr {
                if(strcmp($1, "i32") == 0){
                    CODEGEN("isub\n"); $$ = "i32";
                }else if(strcmp($1, "f32") == 0){
                    CODEGEN("fsub\n"); $$ = "f32";
                }
            }
          | MulExpr {$$ = $1;}
          ;

MulExpr   : MulExpr '*' UnaryExpr  {
                if(strcmp($1, "i32") == 0){
                    CODEGEN("imul\n"); $$ = "i32";
                }else if(strcmp($1, "f32") == 0){
                    CODEGEN("fmul\n"); $$ = "f32";
                }
            }
          | MulExpr '/' UnaryExpr  {
                if(strcmp($1, "i32") == 0){
                    CODEGEN("idiv\n"); $$ = "i32";
                }else if(strcmp($1, "f32") == 0){
                    CODEGEN("fdiv\n"); $$ = "f32";
                }
            }
          | MulExpr '%' UnaryExpr  {
                if(strcmp($1, "i32") == 0){
                    CODEGEN("irem\n"); $$ = "i32";
                }
                // f32 沒有餘數
            }
          | UnaryExpr {$$ = $1;}
          ;

UnaryExpr : '!' UnaryExpr          { 
                CODEGEN("iconst_1\n");
                CODEGEN("ixor\n");
                $$ = "bool";
            }
          | '-' UnaryExpr          { 
                // 對於 int 負號
                if (strcmp($2, "i32") == 0) {
                    CODEGEN("ineg\n");
                    $$ = "i32";
                }
                // 對於 float 負號
                else if (strcmp($2, "f32") == 0) {
                    CODEGEN("fneg\n");
                    $$ = "f32";
                }
                else {
                    $$ = $2;
                } 
            }
          | '~' UnaryExpr          { $$ = $2; }
          | Factor
          | UnaryExpr AS Type      {
                if (strcmp($1, $3) == 0) {
                    $$ = $3;
                } else if (strcmp($1, "i32") == 0 && strcmp($3, "f32") == 0) {
                    CODEGEN("i2f\n");   // JVM int → float
                    $$ = "f32";
                } else if (strcmp($1, "f32") == 0 && strcmp($3, "i32") == 0) {
                    CODEGEN("f2i\n");   // JVM float → int
                    $$ = "i32";
                } else {
                    printf("error:%d: invalid cast: %s as %s\n", yylineno, $1, $3);
                    $$ = $3;
                }
            }
          ;

Factor    : INT_LIT    { CODEGEN("ldc %d\n", $1); $$ = "i32"; }
          | FLOAT_LIT  { CODEGEN("ldc %f\n", $1); $$ = "f32"; }
          | STRING_LIT { CODEGEN("ldc \"%s\"\n", $1); $$ = "str"; }
          | TRUE       { CODEGEN("iconst_1\n"); $$ = "bool"; }
          | FALSE      { CODEGEN("iconst_0\n"); $$ = "bool"; }
          | IDENT      {
                            int addr = lookup_symbol_addr($1);
                            if (addr == -1) {
                                printf("error:%d: undefined: %s\n", yylineno, $1);
                                $$ = "undefined";
                            } else {
                                char *type = lookup_symbol_type($1);
                                if (strcmp(type, "i32") == 0) {
                                    CODEGEN("iload %d\n", addr);
                                } else if (strcmp(type, "f32") == 0) {
                                    CODEGEN("fload %d\n", addr);
                                } else if (strcmp(type, "str") == 0) {
                                    CODEGEN("aload %d\n", addr);
                                } else if (strcmp(type, "bool") == 0) {
                                    CODEGEN("iload %d\n", addr);
                                }
                                $$ = type;
            }
                        }
          | '(' Expr ')' { $$ = $2; }
          | '[' ArrayInitList ']' { $$ = "array"; }
          | IDENT '[' Expr ']' { 
                // 不印任何東西
                int addr = lookup_symbol_addr($1);
                if (addr == -1) {
                    printf("error:%d: undefined: %s\n", yylineno, $1);
                    $$ = "undefined";
                } else {
                    $$ = "array";
                }
            } 
          

        ;


ArrayInitList
    : Expr               // 第1個元素，Expr會自己印 INT_LIT
    | ArrayInitList ',' Expr   // 逗號分隔，Expr會印
    ;



%%

/* C code section */
int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }
    if (!yyin) {
        printf("file `%s` doesn't exists or cannot be opened\n", argv[1]);
        exit(1);
    }

    /* Codegen output init */
    char *bytecode_filename = "hw3.j";
    fout = fopen(bytecode_filename, "w");
    CODEGEN(".source hw3.j\n");
    CODEGEN(".class public Main\n");
    CODEGEN(".super java/lang/Object\n");

    /* Symbol table init */
    // Add your code

    yylineno = 1;

    // 建立全域 scope 0
    current_scope_level = 0;
    current_scope = malloc(sizeof(SymbolTable));
    current_scope->count = 0;
    current_scope->level = current_scope_level;
    current_scope->parent = NULL;
    create_symbol();

    yyparse();

    printf("Total lines: %d\n", yylineno);

    fclose(fout);
    if (current_scope != NULL) free(current_scope);
    if (yyin != NULL && yyin != stdin) {
        fclose(yyin);
    }


    if (g_has_error) {
        remove(bytecode_filename);
    }
    yylex_destroy();
    return 0;
}

void enter_scope() {
    current_scope_level++;
    if (current_scope_level > 0) {
        SymbolTable *new_scope = malloc(sizeof(SymbolTable));
        new_scope->count = 0;
        new_scope->level = current_scope_level;
        new_scope->parent = current_scope;
        current_scope = new_scope;
        create_symbol();
    }
}

void exit_scope() {
    if (current_scope != NULL) {
        if (current_scope->parent != NULL) // 只有非 global scope 才 dump
            dump_symbol();
        SymbolTable *old_scope = current_scope;
        current_scope = current_scope->parent;
        current_scope_level--;
        for (int i = 0; i < old_scope->count; i++) {
            free(old_scope->symbols[i].name);
            free(old_scope->symbols[i].type);
            free(old_scope->symbols[i].func_sig);
        }
        free(old_scope);
    }
}

int lookup_symbol_addr(char *name) {
    SymbolTable *scope = current_scope;
    while (scope != NULL) {
        for (int i = 0; i < scope->count; i++) {
            if (strcmp(scope->symbols[i].name, name) == 0) {
                return scope->symbols[i].address;
            }
        }
        scope = scope->parent;
    }
    return -1;
}

char *lookup_symbol_type(char *name) {
    SymbolTable *scope = current_scope;
    while (scope != NULL) {
        for (int i = 0; i < scope->count; i++) {
            if (strcmp(scope->symbols[i].name, name) == 0) {
                return scope->symbols[i].type;
            }
        }
        scope = scope->parent;
    }
    return "undefined";
}

int lookup_symbol_mutability(char *name) {
    SymbolTable *scope = current_scope;
    while (scope != NULL) {
        for (int i = 0; i < scope->count; i++) {
            if (strcmp(scope->symbols[i].name, name) == 0) {
                return scope->symbols[i].is_mutable;
            }
        }
        scope = scope->parent;
    }
    return -1;
}

void insert_symbol_to_table(char *name, char *type, int is_mutable, int lineno) {
    if (current_scope != NULL && current_scope->count < 100) {
        Symbol *sym = &current_scope->symbols[current_scope->count];
        sym->index = current_scope->count;
        sym->name = strdup(name);
        sym->type = strdup(type);
        sym->is_mutable = is_mutable;
        // 這裡要修正：slot 不能每層從 0，要全域唯一
        sym->address = (strcmp(type, "func") == 0 ? -1 : global_address_counter++);
        sym->lineno = lineno;
        sym->func_sig = strdup(strcmp(type, "func") == 0 ? "(V)V" : "-");
        current_scope->count++;
        printf("> Insert `%s` (addr: %d) to scope level %d\n", name, sym->address, current_scope_level);
    }
}


void create_symbol() {
    printf("> Create symbol table (scope level %d)\n", current_scope_level);
}

void dump_symbol() {
    printf("\n> Dump symbol table (scope level: %d)\n", current_scope_level);
    printf("%-10s%-10s%-10s%-10s%-10s%-10s%-10s\n",
           "Index", "Name", "Mut", "Type", "Addr", "Lineno", "Func_sig");
    if (current_scope != NULL) {
        for (int i = 0; i < current_scope->count; i++) {
            Symbol* sym = &current_scope->symbols[i];
            printf("%-10d%-10s%-10d%-10s%-10d%-10d%-10s\n",
                   sym->index, sym->name, sym->is_mutable, sym->type,
                   sym->address, sym->lineno, sym->func_sig);
        }
    }
}