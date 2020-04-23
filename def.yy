%{
#include <string>
#include <cctype>
#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <stack>
#include <sstream>
#include <vector>
#include <map>
#include <fstream>
#define INFILE_ERROR 1
#define OUTFILE_ERROR 2

using namespace std;

class Element {
public:
	int type;
	string value;
	Element(int type, string value) {
		this->type = type;
		this->value = value;
	}
};

class Symbol_Info {
public:
	int type;
	int size;
	Symbol_Info(int type, int size) {
		this->type = type;
		this->size = size;
	}
};
vector <string> code;
map<string, Symbol_Info *> symbols;
const int NONE_TYPE = 0;
const int INT_TYPE = 1;
const int FLOAT_TYPE = 2;

stack <Element> argstack;
void make_op(char op, string mnemo);
void insert_symbol(string symbol, int type, int size);
void make_print_int(int v);
void make_array(string, int, int);
string gen_load_line(Element e, int regno);
string gen_load_line_2(string i, string reg_name);
stringstream cs;

FILE *file;
extern FILE *yyin;
extern "C" int yylex();
extern "C" int yyerror(const char *msg);
%}
%union
{char *text;
int	ival; float fval;};
%type <text> wyr
%token <text> ID
%token <ival> LC
%token <fval> LR
%token EQ LT GT NE
%token INT DOUBLE
%token INPUTI INPUTD
%token PRINTI PRINTD
%token IF ELSE WHILE
%token DEF
%left '+' '-'
%left '*' '/'
//%start wyr
%%
program	: 	linia					{;}
		|	program linia			{;}
		;
linia	:	wyrsred					{;}
		|	wyrif					{;}
		;
wyrif	:	IF '(' wyrlog ')' '{' program '}'		{;}
		;
wyrsred	:	wyrprz ';'				{;}
		;
wyrprz	:	ID '=' wyr				{fprintf(file, "%s =", $1); argstack.push(Element(ID, $1)); insert_symbol($1, INT_TYPE, 0);make_op('=', "sw");}
		;
wyrlog	: 	wyr EQ wyr				{;}
		|	wyr NE wyr				{;}
		| 	wyr LT wyr				{;}
		|	wyr GT wyr				{;}
		;	
wyr
		:	wyr '+' skladnik		{fprintf(file, " + "); make_op('+', "add");}
		|	wyr '-' skladnik		{fprintf(file, " - "); make_op('-', "sub");}
		|	skladnik				{fprintf(file," "); }
		;
skladnik
		:	skladnik '*' czynnik	{fprintf(file, " * "); make_op('*', "mul");}
		|	skladnik '/' czynnik	{fprintf(file, " / "); make_op('/', "div");}
		|	czynnik					{fprintf(file, " ");}
		;
czynnik
		:	ID						{fprintf(file, " %s ", $1); argstack.push(Element(ID, $1));}
		|	LC						{fprintf(file, " %d ", $1); argstack.push(Element(LC, to_string($1)));}
		|	LR						{fprintf(file, " %f", $1); argstack.push(Element(LR, to_string($1)));}
		|	'(' wyr ')'				{fprintf(file, " ");}
		;
%%
string gen_load_line_2(string i, string reg_name)
{
	stringstream s;
	s << "l";
	if(isdigit(i[0]))
	{
		s << "i ";
	}
	else
	{
		s << "w ";
	}
	s << "$" << reg_name << " , " << i;
	return s.str();
}

void make_print_int(int v) {
	string line1 = "# printi " + to_string(v); //"1_ $t0 , __";
	string line2 = gen_load_line_2(to_string(1), "v0"); //"1_ $t1 , __";
	string line3 = gen_load_line_2(to_string(v), "a0");
	string line4 = "syscal";
	code.push_back(line1);
	code.push_back(line2);
	code.push_back(line3);
	code.push_back(line4);
}

string gen_load_line(Element e, int regno)
{
	stringstream s;
	s << "l";
	if(isdigit(e.value[0]))
	{
		s << "i ";
	}
	else
	{
		s << "w ";
	}
	s << "$t" << regno << " , " << e.value;
	return s.str();
}

void insert_symbol(string symbol, int type, int size)
{
	if(symbols.find(symbol) == symbols.end()) {
		symbols[symbol] = new Symbol_Info(type, size);
	}
}

void make_op(char op, string mnemo)
{
	static int rCounter = 0;
	Element op2=argstack.top();
	argstack.pop();
	Element op1=argstack.top();
	argstack.pop();
	string result_name = "result" + to_string(rCounter);
	stringstream s;
	s << result_name << " <= " << op1.value << op << op2.value;
	cs << s.str() << endl;

	code.push_back("\n# " + s.str());
	if (op == '=')
	{
		string line1 = gen_load_line(op1, 0);//"1_ $t0 , __";
		string line4 = "sw $t0 , " + op2.value;
		code.push_back(line1);
		code.push_back(line4);
	}
	else
	{
		Element e = Element(ID, result_name);
		argstack.push(e);
		insert_symbol(e.value, INT_TYPE, 1);
		string line1 = gen_load_line(op1, 0); //"1_ $t0 , __";
		string line2 = gen_load_line(op2, 1); //"1_ $t1 , __";
		string line3 = mnemo + " $t0 , $t0 , $t1";
		string line4 = "sw $t0 , " + result_name;

		code.push_back(line1);
		code.push_back(line2);
		code.push_back(line3);
		code.push_back(line4);
		code.push_back("li $v0 , 4");
		code.push_back("la $a0 , enter");
		code.push_back("syscall");
	}
	rCounter++;

}

int main(int argc, char *argv[])
{
	if(argc>1)
	{
		yyin=fopen(argv[1],"r");//otwieramy pliki yyout, yyin
	}
	if((file = fopen("rpn.txt","w")) == NULL)
	{
		printf("Nie mozna utworzyc pliku rpn.txt");
		exit(1);
	}
	yyparse();
	stringstream toMars;
	toMars << ".data\n";
	for(auto symbol:symbols)
	{
		toMars << symbol.first << ": " << symbol.second->type << " -- " << symbol.second->size << endl;
	}
	toMars << "enter: .asciiz : \n";
	toMars << ".text\n";
	for(auto line: code)
	{
		toMars << line << endl;
	}
	ofstream symbole("symbols.txt");
	symbole << toMars.str();
	symbole.close();
	ofstream trojki("trojki.txt");
	trojki << cs.str();
	trojki.close();
	return 0;
}
