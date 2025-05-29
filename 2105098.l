%option noyywrap

%x CHAR_STATE
%x STRING_STATE
%x MULTILINEINSINGLECOMMENT
%x MULTILINECOMMENT
%x ACCEPTCHAR
%x MULTILINESTRING

%{
#include<stdio.h>
#include<stdlib.h>
#include"SymbolTable.cpp"
#include <cstring>  

HashFuncType selectedFunction = SDBMHash;
int bucketSize = 7;
int scopecounter = 1;
SymbolTable* symboltable = new SymbolTable(bucketSize,scopecounter,selectedFunction);
int line_count=1;
int line_count_when_comment=0;
int multiComment_line = 0; //for  //
int multi_line_comment = 0; //for /**/
int error = 0;
string temp = "";
string token_str = "";
string token_char ="";
int string_line = 0 ;

FILE *logout;
FILE *tokenout;

%}

WHITESPACE [ \t\f\r\v]+ 
LETTER [a-zA-Z]
DIGIT [0-9]
DIGITS [0-9]+
EXPONENT ([eE][+-]?{DIGITS})
FLOAT ({DIGITS}?"."{DIGITS}?{EXPONENT}?|{DIGITS}{EXPONENT})
LITERAL ('{LETTER}'|'\\n'|'\\t'|'\\\'|'\\'|'\\a'|'\\f'|'\\r'|'\\b'|'\\v'|'\\0')
ID ({LETTER}({LETTER}|{DIGIT}|_)*|_({LETTER}|{DIGIT}|_)*)
STRING (\"({LETTER}|{DIGIT}|{DIGITS}|{EXPONENT}|{ID}|{FLOAT}|{LITERAL})*\")
NEWLINE \n
MANYDECIMAL ({DIGITS}*(\.)+{DIGITS}*)+
ILLFORMED ({FLOAT}{FLOAT}+)
INVALID ({DIGITS}{ID})
SpecialCharacter \\(n|t|\\|'|a|f|r|b|v|0|\"|\?)

%%

{NEWLINE} {line_count++;}
{WHITESPACE}	{}
{FLOAT}		{
				fprintf(tokenout,"<CONST_FLOAT, %s> ",yytext);
				fprintf(logout,"Line no %d: Token <CONST_FLOAT> Lexeme %s found\n\n",line_count,yytext);
				//insert in symbol table and print symbol table content(only non empty buckets)
				SymbolInfo *symbol = new SymbolInfo(yytext,"CONST_FLOAT");
            	ScopeTable *curr = symboltable->getCurrentScope();
            	int n = curr->getScopeTableNumber();
            	bool show = symboltable->Insert(symbol, n,logout);
				if(show)
					symboltable->PrintAllScopeTables(logout);
				fprintf(logout, "\n");
			}
{INVALID}	{
					error ++;
					fprintf(logout,"Error at line no %d: Invalid prefix on ID or invalid suffix on Number %s\n\n",line_count,yytext);
				}
{MANYDECIMAL}	{
					error ++;
					fprintf(logout,"Error at line no %d: Too many decimal points %s\n\n\n",line_count,yytext);
				}
{ILLFORMED}		{
					error ++;
					fprintf(logout,"Error at line no %d: Ill formed number %s\n\n\n",line_count,yytext);
				}





\'  {
		temp ='\'';
        BEGIN CHAR_STATE;
		printf("in char begin");
    }

<CHAR_STATE>[^\\'\n]  {
                            temp += yytext;
							token_char = yytext;
                            BEGIN ACCEPTCHAR;
                        }
				
<CHAR_STATE>{SpecialCharacter} {
    string tt = yytext;

    if (tt[1] == 'n') {
        token_char = '\n';
        temp += "\\n";
    }
    else if (tt[1] == 't') {
        token_char = '\t';
        temp += "\\t";
    }
    else if (tt[1] == '\\') {
        token_char = '\\';
        temp += "\\\\";
    }
    else if (tt[1] == '\'') {
        token_char = '\'';
        temp += "\\\'";
    }
    else if (tt[1] == 'a') {
        token_char = '\a';
        temp += "\\a";
    }
    else if (tt[1] == 'f') {
        token_char = '\f';
        temp += "\\f";
    }
    else if (tt[1] == 'r') {
        token_char = '\r';
        temp += "\\r";
    }
    else if (tt[1] == 'b') {
        token_char = '\b';
        temp += "\\b";
    }
    else if (tt[1] == 'v') {
        token_char = '\v';
        temp += "\\v";
    }
    else if (tt[1] == '0') {
        token_char = '\0';
        temp += "\\0";
    }
    else if (tt[1] == '\"') {
        token_char = '\"';
        temp += "\\\"";
    }
    else if (tt[1] == '\?') {
        token_char = '\?';
        temp += "\\?";
    }

    BEGIN ACCEPTCHAR;
}




<ACCEPTCHAR>{WHITESPACE}?[^\\'\n]+{WHITESPACE}?\'    {
                            error++;
							temp += yytext;
							fprintf(logout,"Error at line no %d: Multi character constant error %s\n\n\n",line_count,temp.c_str());
							BEGIN INITIAL;
                        }
<ACCEPTCHAR>\'	{
					temp+=yytext;
					fprintf(tokenout,"<CONST_CHAR, %s> ",token_char.c_str());
					fprintf(logout,"Line no %d: Token <CONST_CHAR> Lexeme %s found --> <CONST_CHAR, %s>\n\n",line_count,temp.c_str(),token_char.c_str());
					//insert in symbol table and print symbol table content(only non empty buckets)
					SymbolInfo *symbol = new SymbolInfo(temp.c_str(),"CONST_CHAR");
					ScopeTable *curr = symboltable->getCurrentScope();
					int n = curr->getScopeTableNumber();
					bool show = symboltable->Insert(symbol, n,logout);
					if(show)
					symboltable->PrintAllScopeTables(logout);
					fprintf(logout,"\n");
					BEGIN INITIAL;
				}

<ACCEPTCHAR>\n {
					error++;
					fprintf(logout, "Error at line no %d: Unterminated character %s\n\n\n", line_count,temp.c_str());
					line_count++;
					BEGIN INITIAL;
				}

<CHAR_STATE>\n {
					error++;
					fprintf(logout, "Error at line no %d: Unterminated character %s\n\n\n", line_count,temp.c_str());
					
					line_count++;
					BEGIN INITIAL;
				}



<CHAR_STATE>\' {
					error++;
					fprintf(logout,"Error at line no %d: Empty character constant error ''\n\n\n",line_count);
					temp = "";
					BEGIN INITIAL;
				}

\"  {
        temp = "\"";
		token_str ="";
        string_line = line_count;
        printf("begin string state");
        BEGIN STRING_STATE;
    }

<STRING_STATE>\"    {
                        printf("end of the string, should go back to initial");
                        temp += '\"';
                        fprintf(tokenout,"<STRING, %s> ", token_str.c_str());
                        fprintf(logout,"Line no %d: Token <STRING> Lexeme %s found --> <STRING, %s> \n\n",line_count,temp.c_str(),token_str.c_str());
                        BEGIN INITIAL;
                    }

<STRING_STATE>\\    {
                        temp += '\\';
                        line_count++;
						BEGIN MULTILINESTRING;
                    }
<MULTILINESTRING>[\n]	{
							line_count++;
							BEGIN STRING_STATE ;
						}
<STRING_STATE>\\\n  {
                        line_count++;
                        temp += '\\';
                        temp += '\n';
                    }

<STRING_STATE>\\\"  {
                        temp += '\\';
                        temp += '"';
                        token_str += '"';
                    }
<STRING_STATE>{WHITESPACE}  {
								temp += yytext;
								token_str += yytext;
							}

<STRING_STATE>[\n]	{
						line_count++ ;
						error++;
						fprintf(logout,"Error at line no %d: Unterminated string %s\n\n",string_line,temp.c_str());
						BEGIN INITIAL;
					}
<STRING_STATE>[^\n\"\\]*  {
                            temp += yytext;
                            token_str += yytext;
							// if(strchr(yytext, '\"') == NULL)
							// {
							// 	fprintf(logout,"\nError at line no %d: Unterminated string %s\n",line_count,temp.c_str());
							// 	BEGIN ACCEPT_STRING;
							// }
                        }
<MULTILINESTRING><<EOF>>	{
							error++ ;
							fprintf(logout,"Error at line no %d: Unterminated string %s\n\n",string_line,temp.c_str());
							BEGIN INITIAL;
						}
<STRING_STATE><<EOF>>	{
							error++ ;
							fprintf(logout,"\nError at line no %d: Unterminated string %s\n\n",string_line,temp.c_str());
							BEGIN INITIAL;
						}

"//".*	{
            temp ="";
            if(yytext[yyleng-1] == '\\'){
				multiComment_line = line_count;
                line_count++;
                temp +=yytext;
                temp += '\n';
				BEGIN MULTILINEINSINGLECOMMENT;
			}
            else{
			    fprintf(logout,"Line no %d: Token <COMMENT> Lexeme %s found\n\n",line_count,yytext);
            }
		}

<MULTILINEINSINGLECOMMENT>.*    {
                                    temp += yytext;
                                    if(yytext[yyleng-1] != '\\'){
                                        fprintf(logout,"Line no %d: Token <COMMENT> Lexeme %s found\n\n",line_count,temp.c_str());
				                        BEGIN INITIAL;
			                        }
                                    else{
                                        line_count++;
                                    }
	                        	}


"/*"	{
			BEGIN MULTILINECOMMENT;
            multi_line_comment = line_count;
            temp =yytext;
		}
<MULTILINECOMMENT>"*/"  {
                            temp += yytext;
                            fprintf(logout,"Line no %d: Token <COMMENT> Lexeme %s found\n\n",line_count,temp.c_str());
                            BEGIN INITIAL;
                        }

<MULTILINECOMMENT>.     {
                            temp += yytext;
                        }

<MULTILINECOMMENT>[\n]  {
		                    line_count++;
		                    temp += yytext;
	                    }

<MULTILINECOMMENT><<EOF>>	{
								error++;
								fprintf(logout,"Error at line no %d: Unterminated comment %s \n\n",multi_line_comment,temp.c_str());
								temp = "";
								BEGIN INITIAL;
							}

"if"	{
			fprintf(tokenout,"<IF> ");
			fprintf(logout,"Line no %d: Token <IF> Lexeme %s found\n\n",line_count,yytext);
		}
		
"else"	{
			fprintf(tokenout,"<ELSE> ");
			fprintf(logout,"Line no %d: Token <ELSE> Lexeme %s found\n\n",line_count,yytext);
		}

"goto"	{
			fprintf(tokenout,"<GOTO> ");
			fprintf(logout,"Line no %d: Token <GOTO> Lexeme %s found\n\n",line_count,yytext);
		}

"for"	{
			fprintf(tokenout,"<FOR> ");
			fprintf(logout,"Line no %d: Token <FOR> Lexeme %s found\n\n",line_count,yytext);
		}

"while"	{
			fprintf(tokenout,"<WHILE> ");
			fprintf(logout,"Line no %d: Token <WHILE> Lexeme %s found\n\n",line_count,yytext);
		}

"long"	{
			fprintf(tokenout,"<LONG> ");
			fprintf(logout,"Line no %d: Token <LONG> Lexeme %s found\n\n",line_count,yytext);
		}

"do"	{
			fprintf(tokenout,"<DO> ");
			fprintf(logout,"Line no %d: Token <DO> Lexeme %s found\n\n",line_count,yytext);
		}

"break"	{
			fprintf(tokenout,"<BREAK> ");
			fprintf(logout,"Line no %d: Token <BREAK> Lexeme %s found\n\n",line_count,yytext);
		}

"short"	{
			fprintf(tokenout,"<SHORT> ");
			fprintf(logout,"Line no %d: Token <SHORT> Lexeme %s found\n\n",line_count,yytext);
		}

"int"	{
			fprintf(tokenout,"<INT> ");
			fprintf(logout,"Line no %d: Token <INT> Lexeme %s found\n\n",line_count,yytext);
		}

"char"	{
			fprintf(tokenout,"<CHAR> ");
			fprintf(logout,"Line no %d: Token <CHAR> Lexeme %s found\n\n",line_count,yytext);
		}

"static"	{
			fprintf(tokenout,"<STATIC> ");
			fprintf(logout,"Line no %d: Token <STATIC> Lexeme %s found\n\n",line_count,yytext);
		}

"float"	{
			fprintf(tokenout,"<FLOAT> ");
			fprintf(logout,"Line no %d: Token <FLOAT> Lexeme %s found\n\n",line_count,yytext);
		}

"double"	{
			fprintf(tokenout,"<DOUBLE> ");
			fprintf(logout,"Line no %d: Token <DOUBLE> Lexeme %s found\n\n",line_count,yytext);
		}

"unsigned"	{
			fprintf(tokenout,"<UNSIGNED> ");
			fprintf(logout,"Line no %d: Token <UNSIGNED> Lexeme %s found\n\n",line_count,yytext);
		}

"void"	{
			fprintf(tokenout,"<VOID> ");
			fprintf(logout,"Line no %d: Token <VOID> Lexeme %s found\n\n",line_count,yytext);
		}

"return"	{
			fprintf(tokenout,"<RETURN> ");
			fprintf(logout,"Line no %d: Token <RETURN> Lexeme %s found\n\n",line_count,yytext);
		}

"switch"	{
			fprintf(tokenout,"<SWITCH> ");
			fprintf(logout,"Line no %d: Token <SWITCH> Lexeme %s found\n\n",line_count,yytext);
		}

"case"	{
			fprintf(tokenout,"<CASE> ");
			fprintf(logout,"Line no %d: Token <CASE> Lexeme %s found\n\n",line_count,yytext);
		}

"default"	{
			fprintf(tokenout,"<DEFAULT> ");
			fprintf(logout,"Line no %d: Token <DEFAULT> Lexeme %s found\n\n",line_count,yytext);
		}

"continue"	{
			fprintf(tokenout,"<CONTINUE> ");
			fprintf(logout,"Line no %d: Token <CONTINUE> Lexeme %s found\n\n",line_count,yytext);
		}

"+"		|

"-"		{
			fprintf(tokenout,"<ADDOP, %s> ",yytext);
			fprintf(logout,"Line no %d: Token <ADDOP> Lexeme %s found\n\n",line_count,yytext);
			//insert in symbol table and print symbol table content(only non empty buckets)
			// There is a '|' in "+"'s rule, this means match execute the action for following rule
		}


"*"|"/"|"%"		{
			fprintf(tokenout,"<MULOP, %s> ",yytext);
			fprintf(logout,"Line no %d: Token <MULOP> Lexeme %s found\n\n",line_count,yytext);
			//insert in symbol table and print symbol table content(only non empty buckets)
			// There is a '|' in "+"'s rule, this means match execute the action for following rule
		}

"++"|"--"		{
			fprintf(tokenout,"<INCOP, %s> ",yytext);
			fprintf(logout,"Line no %d: Token <INCOP> Lexeme %s found\n\n",line_count,yytext);
			//insert in symbol table and print symbol table content(only non empty buckets)
			// There is a '|' in "+"'s rule, this means match execute the action for following rule
		}


"<"|">"|">="|"<="|"=="|"!=" 	{
			fprintf(tokenout,"<RELOP, %s> ",yytext);
			fprintf(logout,"Line no %d: Token <RELOP> Lexeme %s found\n\n",line_count,yytext);
			//insert in symbol table and print symbol table content(only non empty buckets)
			// There is a '|' in "+"'s rule, this means match execute the action for following rule
		}

"=" 	{
			fprintf(tokenout,"<ASSIGNOP, %s> ",yytext);
			fprintf(logout,"Line no %d: Token <ASSIGNOP> Lexeme %s found\n\n",line_count,yytext);
			//insert in symbol table and print symbol table content(only non empty buckets)
			// There is a '|' in "+"'s rule, this means match execute the action for following rule
		}


"&&"|"||" 	{
			fprintf(tokenout,"<LOGICOP, %s> ",yytext);
			fprintf(logout,"Line no %d: Token <LOGICOP> Lexeme %s found\n\n",line_count,yytext);
			//insert in symbol table and print symbol table content(only non empty buckets)
			// There is a '|' in "+"'s rule, this means match execute the action for following rule
		}

"!" 	{
			fprintf(tokenout,"<NOT, %s> ",yytext);
			fprintf(logout,"Line no %d: Token <NOT> Lexeme %s found\n\n",line_count,yytext);
			//insert in symbol table and print symbol table content(only non empty buckets)
			// There is a '|' in "+"'s rule, this means match execute the action for following rule
		}

"("		{
			fprintf(tokenout,"<LPAREN, %s> ",yytext);
			fprintf(logout,"Line no %d: Token <LPAREN> Lexeme %s found\n\n",line_count,yytext);
			//insert in symbol table and print symbol table content(only non empty buckets)
			// There is a '|' in "+"'s rule, this means match execute the action for following rule
		}

")" 	{
			fprintf(tokenout,"<RPAREN, %s> ",yytext);
			fprintf(logout,"Line no %d: Token <RPAREN> Lexeme %s found\n\n",line_count,yytext);
			//insert in symbol table and print symbol table content(only non empty buckets)
			// There is a '|' in "+"'s rule, this means match execute the action for following rule
		}

"{" 	{
			fprintf(tokenout,"<LCURL, %s> ",yytext);
			fprintf(logout,"Line no %d: Token <LCURL> Lexeme %s found\n\n",line_count,yytext);
			//insert in symbol table and print symbol table content(only non empty buckets)
			// There is a '|' in "+"'s rule, this means match execute the action for following rule
			//total_scope++;
            scopecounter++;
            ScopeTable *newScope = new ScopeTable(7, scopecounter, selectedFunction);
            symboltable->Enter_Scope(newScope);
			cout << "\tScopeTable# " << newScope->getID() << " created" << endl;
            
		}

"}" 	{
			fprintf(tokenout,"<RCURL, %s> ",yytext);
			fprintf(logout,"Line no %d: Token <RCURL> Lexeme %s found\n\n",line_count,yytext);
			//insert in symbol table and print symbol table content(only non empty buckets)
			// There is a '|' in "+"'s rule, this means match execute the action for following rule
			symboltable->Exit_Scope();
		}


"[" 	{
			fprintf(tokenout,"<LTHIRD, %s> ",yytext);
			fprintf(logout,"Line no %d: Token <LTHIRD> Lexeme %s found\n\n",line_count,yytext);
		}

"]" 	{
			fprintf(tokenout,"<RTHIRD, %s> ",yytext);
			fprintf(logout,"Line no %d: Token <RTHIRD> Lexeme %s found\n\n",line_count,yytext);
		}

"," 	{
			fprintf(tokenout,"<COMMA, %s> ",yytext);
			fprintf(logout,"Line no %d: Token <COMMA> Lexeme %s found\n\n",line_count,yytext);
			//insert in symbol table and print symbol table content(only non empty buckets)
			// There is a '|' in "+"'s rule, this means match execute the action for following rule
		}

";" 	{
			fprintf(tokenout,"<SEMICOLON, %s> ",yytext);
			fprintf(logout,"Line no %d: Token <SEMICOLON> Lexeme %s found\n\n",line_count,yytext);
			//insert in symbol table and print symbol table content(only non empty buckets)
			// There is a '|' in "+"'s rule, this means match execute the action for following rule
		}

			
{DIGIT}+ 	{
				fprintf(tokenout,"<CONST_INT, %s> ",yytext);
				fprintf(logout,"Line no %d: Token <CONST_INT> Lexeme %s found\n\n",line_count,yytext);
				//insert in symbol table and print symbol table content(only non empty buckets)
				SymbolInfo *symbol = new SymbolInfo(yytext,"CONST_INT");
            	ScopeTable *curr = symboltable->getCurrentScope();
            	int n = curr->getScopeTableNumber();
            	bool show = symboltable->Insert(symbol, n,logout);
				if(show){
					symboltable->PrintAllScopeTables(logout);
				}
				fprintf(logout,"\n");
			}



			
{ID}		{
				fprintf(tokenout,"<ID, %s> ",yytext);
				fprintf(logout,"Line no %d: Token <ID> Lexeme %s found\n\n",line_count,yytext);
				//insert in symbol table and print symbol table content(only non empty buckets)
				SymbolInfo *symbol = new SymbolInfo(yytext,"ID");
            	ScopeTable *curr = symboltable->getCurrentScope();
            	int n = curr->getScopeTableNumber();
            	bool show = symboltable->Insert(symbol, n,logout);
				if(show)
					symboltable->PrintAllScopeTables(logout);
				fprintf(logout,"\n");
			}
{STRING}	{
				fprintf(tokenout,"<STRING, %s> ",yytext);
				fprintf(logout,"Line no %d: Token <STRING> Lexeme %s found\n\n",line_count,yytext);
			}
.	{
		error ++;
		fprintf(logout,"Error at line no %d: Unrecognized character %s\n\n",line_count,yytext);
	}

<<EOF>>	{
		symboltable->PrintAllScopeTables(logout);
		fprintf(logout,"\n");
		fprintf(logout,"Total lines: %d\n",line_count);
		fprintf(logout,"Total errors: %d\n",error);
		return 0;
	}

%%

int main(int argc,char *argv[]){
	
	if(argc!=2){
		printf("Please provide input file name and try again\n");
		return 0;
	}
	
	FILE *fin=fopen(argv[1],"r");
	if(fin==NULL){
		printf("Cannot open specified file\n");
		return 0;
	}
	
	logout= fopen("log.txt","w");
	tokenout= fopen("token.txt","w");

	yyin= fin;
	yylex();
	fclose(yyin);
	fclose(tokenout);
	fclose(logout);
	return 0;
}
