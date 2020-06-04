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

// class Symbol_Info {
// public:
// 	int type;
// 	int size;
// 	string value;
// 	Symbol_Info(int type, int size) {
		
// 		this->type = type;
// 		this->value = to_string(size);
// 	}
// 	Symbol_Info(int type, string value) {
		
// 		this->type = type;
// 		this->value = value;
// 	}
// };
vector <string> code;
map<string, Element *> symbols;
const int NONE_TYPE = 0;
const int INT_TYPE = 1;
const int FLOAT_TYPE = 2;
const int STRING_TYPE = 3;
const int ARRAY_INT = 4;
const int ARRAY_FLOAT = 5;

int float_num = 0;
int lblCounter = 0;

stack <Element> argstack;
stack <string> logic;
stack <string> labels;
void ifbegin();
void warunek(string logic);
void ifend();
void ifelse();
void make_op(char op, string mnemo);
void insert_symbol(string symbol, int type, int size);
void insert_symbol_s(string symbol, int type, string value1);
void make_print(int type);
void make_print_s(Element e, string value);
void make_input_int(int v);
void make_input_float(float f);
void make_array(string, int, int);
Element find_element(string name);
string getFloatName(string arg);
string gen_load_line(Element e, int regno);
string gen_load_line_f(Element e, int regno);
string gen_load_line_2(string i, int reg_name);
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
%token <text> STRING
%token EQ LT GT NE
%token INT FLOAT
%token INPUTI INPUTF
%token PRINTI PRINTF PRINTS
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
		|	wyrwhile				{;}
		;
wyrwhile	:	while_begin '{' program '}'	{;}
			;
while_begin	:	WHILE '(' warunek ')'		{;}
			;
wyrif	:	if_begin '{' program '}'		{cout << "koniec if\n"; ifend();}
		|	else_begin '{' program '}'		{cout << "koniec else"; ifend();}
		;
else_begin	:	if_begin '{' program '}' ELSE	{ifelse();}
			;
if_begin	:	IF '(' warunek ')'			{cout << "if start\n"; ifbegin();}
			;
warunek		:	wyr wyrlog wyr				{;}
			;
wyrsred	:	wyrprz ';'				{;}
		|	wyrwyp ';'				{;}
		;
wyrwyp	:	PRINTI '(' wyr ')' 		{make_print(INT_TYPE);}
		|	PRINTF '(' wyr ')'		{make_print(FLOAT_TYPE);}
		|	PRINTS '(' STRING ')'	{make_print_s(Element(STRING_TYPE, "str"), $3);}
		;
wyrwpr	:	INPUTI '('')'			{argstack.push(Element(LC, to_string(0)));}
		|	INPUTF '('')'			{argstack.push(Element(LR, to_string(0.0)));}
		;
wyrprz	:	INT ID '=' wyr			{printf("Przypisanie\n"); fprintf(file, "%s =", $2); argstack.push(Element(INT_TYPE, $2)); insert_symbol($2, INT_TYPE, 0);make_op('=', "sw");}
		|	INT ID '=' wyrwpr		{printf("Przypisanie\n"); fprintf(file, "%s =", $2); argstack.push(Element(INT_TYPE, $2)); insert_symbol($2, INT_TYPE, 0);make_op('p', "sw");}
		|	FLOAT ID '=' wyr		{printf("Przypisanie\n"); fprintf(file, "%s =", $2); argstack.push(Element(FLOAT_TYPE, $2)); insert_symbol($2, FLOAT_TYPE, 0);make_op('=', "sw");}
		|	FLOAT ID '=' wyrwpr		{printf("Przypisanie\n"); fprintf(file, "%s =", $2); argstack.push(Element(FLOAT_TYPE, $2)); insert_symbol($2, FLOAT_TYPE, 0);make_op('f', "sw");}
		;
wyrlog	: 	wyr EQ wyr				{logic.push("==");}
		|	wyr NE wyr				{logic.push("!=");}
		| 	wyr LT wyr				{logic.push("<");}
		|	wyr GT wyr				{logic.push(">");}
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
		:	ID						{printf("ID\n"); fprintf(file, " %s ", $1); argstack.push(find_element($1));}
		|	LC						{printf("LC\n"); fprintf(file, " %d ", $1); argstack.push(Element(INT_TYPE, to_string($1)));}
		|	LR						{printf("LR\n"); fprintf(file, " %f", $1); string float_name = "float_val_" + to_string(float_num); float_num++; insert_symbol_s(float_name, FLOAT_TYPE, to_string($1)); argstack.push(Element(FLOAT_TYPE, to_string($1)));}
		|	'(' wyr ')'				{fprintf(file, " ");}
		;
%%
Element find_element(string name) {
	auto el = symbols.find(name);
	if(el == symbols.end()) {
		yyerror("Nie znaleziono tego argumentu. Błąd deklaracji!");
	}
	return &el;
}

void ifbegin() {
	if(argstack.top().type == ID) {
		if(symbols[argstack.top().value]->type == INT_TYPE) code.push_back("lw $t1, " + argstack.top().value);
	}
	else if(argstack.top().type == LC) code.push_back("li $t1, " + argstack.top().value);
	else yyerror("if nie przyjmuje wartości float");

	argstack.pop();

	if(argstack.top().type == ID) {
		if(symbols[argstack.top().value]->type == INT_TYPE) code.push_back("lw $t0, " + argstack.top().value);
	}
	else if(argstack.top().type == LC) code.push_back("li $t0, " + argstack.top().value);
	else yyerror("if nie przyjmuje wartości float");

	warunek(logic.top());
	logic.pop();
	labels.push("label"+to_string(lblCounter));
	lblCounter++;
}

void ifend()
{
	code.push_back(labels.top()+":");
	labels.pop();
}

void ifelse() {
	string tmp ="b label"+to_string(lblCounter+1);
	code.push_back(tmp);
	code.push_back(labels.top() + ":");
	labels.pop();
	lblCounter++;
	labels.push("label"+to_string(lblCounter));
}

void warunek(string logicOp) {
	if(logicOp == "==") code.push_back("bne $t0, $t1, label" + to_string(lblCounter));
	else if(logicOp == "!=") code.push_back("beq $t0, $t1, label" + to_string(lblCounter));
	else if(logicOp == "<") code.push_back("bge $t0, $t1, label" + to_string(lblCounter));
	else if(logicOp == ">") code.push_back("ble $t0, $t1, label" + to_string(lblCounter));
}

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



void make_print_s(Element e, string value) {
	static int strCounter = 0;
	string result_name = "str_" + to_string(strCounter);
	insert_symbol_s(result_name, STRING_TYPE, value);
	string line1 = "# PRINT " + e.value; //"1_ $t0 , __";
	string line2 = gen_load_line_2(to_string(4), "v0"); //"1_ $t1 , __";
	string line3 = gen_load_line_2(e.value, "a0");
	string line4 = "syscal";
	code.push_back(line1);
	code.push_back(line2);
	code.push_back(line3);
	code.push_back(line4);
	strCounter++;
}

string getFloatName(string arg){
	for(auto symbol: symbols)
	{
		if (symbol.second->value == arg)
        return symbol.first;
	}
}

void make_print(int type)
{
	if(type == INT_TYPE)
	{
		if(argstack.top().type == FLOAT_TYPE) yyerror("Błąd, funkcja printi wyświetla tylko liczby całkowite");
			string line1 = "# PRINT " + argstack.top().value;
			string line2 = gen_load_line_2(to_string(1), "v0");
			string line3 = gen_load_line_2(argstack.top().value, "a0");
			string line4 = "syscall";
			code.push_back(line1);
			code.push_back(line2);
			code.push_back(line3);
			code.push_back(line4);
			argstack.pop();
	}
	else if(type == FLOAT_TYPE) {
			if(argstack.top().type == INT_TYPE) yyerror("Błąd, funkcja printi wyświetla tylko liczby zmiennoprzecinkowe");
			string line1 = "# PRINT " + argstack.top().value;
			string line2 = gen_load_line_2(to_string(2), "v0");
			string line3 = "l.s $f12, ";
			if(argstack.top().type == ID) line3 += argstack.top().value;
			else line3 += getFloatName(argstack.top().value);
			string line4 = "syscall";
			code.push_back(line1);
			code.push_back(line2);
			code.push_back(line3);
			code.push_back(line4);
			argstack.pop();
	}
}


void make_input_int(int v) {
	string line1 = "#  inputi " + to_string(v);
	string line2 = ".data\n";
	string line3 = " 0";
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
		symbols[symbol] = new Element(type, to_string(size));
	}
	else yyerror("Dana zmienna już została zadeklarowana!");
}

void insert_symbol_s(string symbol, int type, string value1)
{

	if(symbols.find(symbol) == symbols.end()) {
		
		symbols[symbol] = new Element(type, value1);
	}
	else yyerror("Dana zmienna już została zadeklarowana!");
}

string gen_load_line_f(Element e, int reg_name)
{
	stringstream s;
	s << "l.s $f0" << " , " << e.value;
	return s.str();
}

void make_op(char op, string mnemo)
{
	cout << "Make op\n";
	static int rCounter = 0;
	Element op2=argstack.top();
	argstack.pop();
	Element op1=argstack.top();
	argstack.pop();
	string result_name = "result" + to_string(rCounter);
	stringstream s;
	s << result_name << " <= " << op1.value << op << op2.value;
	cs << s.str() << endl;
	cout << s.str() << endl;
	
	code.push_back("\n# " + s.str());
	if (op == '=')
	{
		cout << "=\n";
			if(op2.type == INT_TYPE && op1.type == INT_TYPE) {
				printf("int do zmiennej int\n");
				string line1 = gen_load_line(op1, 0);//"1_ $t0 , __";
				string line4 = "sw $t0 , " + op2.value;
				code.push_back(line1);
				code.push_back(line4);
			}
			else if(op2.type == FLOAT_TYPE && op1.type == FLOAT_TYPE) {
				string line1 = gen_load_line_f(op1, 0);//"1_ $f0 , __";
				string line4 = "s.s $f0 , " + op2.value;
				code.push_back(line1);
				code.push_back(line4);
			}
			else if(op2.type == FLOAT_TYPE && op1.type == INT_TYPE) {
				string line1 = "li $t0, " + op1.value + "\n";
				string line2 = "mtc1 $t0, $f0\n";
				string line3 = "cvt.s.w $f1, $f0";
				string line4 = "s.s $f1, " + op1.value + "\n";
				code.push_back(line1);
				code.push_back(line2);
				code.push_back(line3);
				code.push_back(line4);
			}
			else yyerror("Błąd przypisania! Zmienne, ktre chcesz przypisać są innego typu niż to możliwe!");
	}
	else if(op == 'p')
	{
		cout << "p\n";
		if(op2.type == INT_TYPE) {
			string line1 = gen_load_line(op1, 5);
			string line2 = "syscall";
			string line3 = "sw $v0 , " + op2.value;
			code.push_back(line1);
			code.push_back(line2);
			code.push_back(line3);
		}
		else yyerror("Błąd. Proba przypisania błędnego typu zmiennej");
	}
	else if(op == 'f') {
		cout << "f\n";
		if(op2.type == FLOAT_TYPE) {
			string line1 = gen_load_line(op1, 6);
			string line2 = "syscall";
			string line3 = "s.s $f0 " + op2.value;
			code.push_back(line1);
			code.push_back(line2);
			code.push_back(line3);
		}
		else yyerror("Błąd. Proba przypisania błędnego typu zmiennej");
	}
	else
	{
		cout << "other\n";

		string reg0 = "f0";
		string reg1 = "f1";
		int type = FLOAT_TYPE;
		int convertedOp = 0;
		if (op1.type == op2.type) {
			if(op1.type == INT_TYPE) {
				type = INT_TYPE;
				reg0 = "t0";
				reg1 = "t1";
			}
		}
		else {
			string destreg;
			Element cop = Element(0, 0);

			if(op1.type == INT_TYPE) {
				cop = op1;
				destreg =  "f0";
				convertedOp = 1;
			}
			else {
				cop = op2;
				destreg = "f1";
				convertedOp = 2;
			}
			string line1= gen_load_line_2(cop.value, "t0");
			string line2= "mtc1 $t0, $f0";
			string line3 = "cvt.s.w $" + destreg + " , $f0";
			code.push_back(line1);
			code.push_back(line2);
			code.push_back(line3);
		}
		insert_symbol(result_name, type, 0);
		argstack.push(Element(type, result_name));
		string line3, line4;
		if(type == FLOAT_TYPE) {
			line3 = mnemo + ".s $" + reg0 + ", $" + reg0 + ", $" + reg0;
			line4 = "s.s $" + reg0 + ", " +result_name; 
		}
		else {
			line3 = mnemo + reg0 + ", $" + reg0 + ", $" + reg0;
			line4 = "sw $" + reg0 + ", " +result_name; 
		}

		if(convertedOp != 1) {
			string line1= gen_load_line_2(op1.value,reg0);
			code.push_back(line1);
		}
		if(convertedOp != 2) {
			string line2= gen_load_line_2(op2.value,reg1);
			code.push_back(line2);
		}
		code.push_back(line3);
		code.push_back(line4);	

		// if(op2.type == INT_TYPE && op1.type == INT_TYPE)
		// {
		// 	cout << "int & int\n";
		// 	Element e = Element(INT_TYPE, result_name);
		// 	argstack.push(e);
		// 	insert_symbol(e.value, INT_TYPE, 0);
		// 	string line1 = gen_load_line(op1, 0); //"1_ $t0 , __";
		// 	string line2 = gen_load_line(op2, 1); //"1_ $t1 , __";
		// 	string line3 = mnemo + " $t0 , $t0 , $t1\n";
		// 	string line4 = "sw $t0 , " + result_name + "\n";

		// 	code.push_back(line1);
		// 	code.push_back(line2);
		// 	code.push_back(line3);
		// 	code.push_back(line4);
		// 	// code.push_back("li $v0 , 4");
		// 	// code.push_back("la $a0 , enter");
		// 	// code.push_back("syscall");
		// }
		// else if(op2.type == FLOAT_TYPE && op1.type == FLOAT_TYPE) {
		// 	cout << "float & float\n";
		// 	Element e = Element(FLOAT_TYPE, result_name);
		// 	argstack.push(e);
		// 	insert_symbol(e.value, FLOAT_TYPE, 0);
		// 	string line1 = gen_load_line_f(op1, 0); //"1_ $t0 , __";
		// 	string line2 = gen_load_line_f(op2, 1);
		// 	string line3 = mnemo + ".s $f0 , $f0 , $f1\n";
		// 	string line4 = "s.s $f0 , " + result_name + "\n";
		// 	code.push_back(line1);
		// 	code.push_back(line2);
		// 	code.push_back(line3);
		// 	code.push_back(line4);
		// }
		// else if(op2.type == FLOAT_TYPE && op1.type == INT_TYPE) {
		// 	cout << "float & int\n";
		// 	Element e = Element(FLOAT_TYPE, result_name);
		// 	argstack.push(e);
		// 	insert_symbol(e.value, FLOAT_TYPE, 0);
		// 	string line1 = "li $t0, " + op1.value + "\n";
		// 	string line2 = "mtc1 $t0, $f0\n";
		// 	string line3 = "cvt.s.w $f1, $f0\n";
		// 	string line4 = "s.s $f1, " + op1.value + "\n";
		// 	string line8 = gen_load_line_f(op1, 1);
		// 	string line5 = gen_load_line_f(op2, 2);
		// 	string line6 = mnemo + ".s $f1 , $f1 , $f2\n";
		// 	string line7 = "s.s $f1 , " + result_name + "\n";
		// 	code.push_back(line1);
		// 	code.push_back(line2);
		// 	code.push_back(line3);
		// 	code.push_back(line4);
		// 	code.push_back(line8);
		// 	code.push_back(line5);
		// 	code.push_back(line6);
		// 	code.push_back(line7);
		// }
		// else if(op2.type == INT_TYPE && op1.type == FLOAT_TYPE) {
		// 	cout << "int & float\n";
		// 	Element e = Element(FLOAT_TYPE, result_name);
		// 	argstack.push(e);
		// 	insert_symbol(e.value, FLOAT_TYPE, 0);
		// 	string line1 = "li $t0, " + op2.value + "\n";
		// 	string line2 = "mtc1 $t0, $f0\n";
		// 	string line3 = "cvt.s.w $f1, $f0\n";
		// 	string line8 = gen_load_line_f(op1, 1);
		// 	string line4 = gen_load_line_f(op2, 2);
		// 	string line5 = "s.s $f1, " + op2.value + "\n";
		// 	string line6 = mnemo + ".s $f1 , $f1 , $f2\n";
		// 	string line7 = "s.s $f1 , " + result_name + "\n";
		// 	code.push_back(line1);
		// 	code.push_back(line2);
		// 	code.push_back(line3);
		// 	code.push_back(line4);
		// 	code.push_back(line8);
		// 	code.push_back(line5);
		// 	code.push_back(line6);
		// 	code.push_back(line7);
		// }
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
		toMars << symbol.first << ": \t\t";
		if(symbol.second->type == 1)
		{
			toMars << " .world " << symbol.second->value << endl;
		}
		else if(symbol.second->type == 2)
		{
			toMars << " .float " << symbol.second->value << endl;
		}
		else if(symbol.second->type == 3)
		{
			toMars << " .asciiz " << symbol.second->value << endl;
		}
	}
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
