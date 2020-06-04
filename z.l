%{
#include <stdlib.h>
#include <string.h>
#include "def.tab.hh"
#define INFILE_ERROR 1
#define OUTFILE_ERROR 2
extern int yylineno;
int yyerror(const char *,...);
%}
%%
\+			{return '+';}
\*			{return '*';}
\(			{return '(';}
\)			{return ')';}
\/			{return '/';}
\-			{return '-';}
\^			{return '^';}
\=			{return '=';}
\[			{return '[';}
\]			{return ']';}
\{			{return 'nawiasL';}
\}			{return 'nawiasP';}
\!\=		{return NE;}
\;			{return ';';}
\>			{return '>';}
\<			{return '<';}
\>\=		{return GT;}
\<\=		{return LT;}
"if"		{return IF;}
"else"		{return ELSE;}
"int"		{return INT;}
"float"		{return FLOAT;}
"while"		{return WHILE;}
"printi"	{return PRINTI;}
"printf"	{return PRINTF;}
"prints"	{return PRINTS;}
"inputi"	{return INPUTI;}
"inputf"	{return INPUTF;}
"def"		{return DEF;}
\=\=		{return EQ;}
0|[1-9][0-9]*				{yylval.ival = atoi(yytext);return LC;}
(0|[1-9][0-9]*)\.[0-9]+		{yylval.fval = atof(yytext);return LR;}
[A-Za-z_][A-Za-z0-9_]* 		{yylval.text = strdup(yytext);return ID;}
\"[A-Za-z]*\"				{yylval.text = strdup(yytext);return STRING;}
\ |\t		{;}
\n			{yylineno++;}
.			{yyerror("Blad leksykalny\n");}
%%
int yyerror(const char *msg,...)	{printf("%d: %s\n", yylineno, msg);
														exit(1);}
