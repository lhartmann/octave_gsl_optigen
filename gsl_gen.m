#! /usr/bin/octave --silent
# kate: syntax octave
function s=gsl_gen(name,F,X,CD)
    printf("Generating code:\n");
    s = "";
    s = [s sprintf("#include <iostream>\n")];
	s = [s sprintf("#include <fstream>\n")];
	s = [s sprintf("#include <iomanip>\n")];
	s = [s sprintf("#include <vector>\n")];
	s = [s sprintf("#include <cmath>\n")];
	s = [s sprintf("#include <string>\n")];
	s = [s sprintf("#include <signal.h>\n")];
	s = [s sprintf("#include \"gsl/gsl_multimin.h\"\n")];
	s = [s sprintf("using namespace std;\n")];
	s = [s gsl_gen_datatype("my_",F,X,CD)];
	s = [s gsl_gen_f("my_",F,X,CD)];
	s = [s gsl_gen_df("my_",F,X,CD)];
	s = [s gsl_gen_fdf("my_",F,X,CD)];
	s = [s gsl_gen_caldata_loader("my_",F,X,CD)];
	s = [s gsl_gen_optimize("my_",F,X,CD)];
	s = [s gsl_gen_main("my_",F,X,CD)];
    printf("  Done.\n");
endfunction

function s=gsl_gen_read_vector(vecname, symbols)
    printf("    State vector reader...\n");
    s = "";
    for i=1:length(symbols)
        s = [s sprintf("\tdouble %s = gsl_vector_get(%s, %d);\n", ccode(symbols(i)), vecname, i-1)];
    endfor
endfunction

function s=gsl_gen_f(name, F, X, CD)
    printf("  Objective function...\n");
    s = "";
    s = [s sprintf("static double %sf(const gsl_vector *X, void *param) {\n",name)];
    s = [s sprintf("\tconst vector<%scaldata> &calpointlist = *(const vector<%scaldata> *)param;\n", name, name)];
    
    s = [s gsl_gen_read_vector("X", X)];
    
    printf("    Calibration data loop...\n");
    s = [s sprintf("\tdouble err=0, tmp;\n")];
    s = [s sprintf("\tfor (auto calpoint : calpointlist) {\n")];
    for i=1:length(CD)
        s = [s sprintf("\t\tdouble %s = calpoint.%s;\n", ccode(CD(i)), ccode(CD(i)))];
    endfor
    for iF=1:length(F)
        s = [s sprintf("\t\ttmp = %s;\n", ccode(F(iF)))];
        s = [s sprintf("\t\tif(!isnan(tmp)) err += tmp;\n")];
    endfor
    s = [s sprintf("\t}\n")];
    
    s = [s sprintf("\treturn err;\n")];
    s = [s sprintf("}\n")];
endfunction

function s=gsl_gen_df(name, F, X, CD)
    printf("  Objective function derivatives...\n");
    s = "";
    s = [s sprintf("static void %sdf(const gsl_vector *X, void *param, gsl_vector *DF) {\n",name)];
    s = [s sprintf("\tconst vector<%scaldata> &calpointlist = *(const vector<%scaldata> *)param;\n", name, name)];
		   
    s = [s gsl_gen_read_vector("X", X)];
    
    for i=1:length(X)
        s = [s sprintf("\tdouble dfd%s = 0;\n", ccode(X(i)))];
    endfor
    
    printf("    Calibration data loop...\n");
    s = [s sprintf("\tfor (auto calpoint : calpointlist) {\n")];
        s = [s sprintf("\t\tdouble tmp;\n")];
    for i=1:length(CD)
        s = [s sprintf("\t\tdouble %s = calpoint.%s;\n", ccode(CD(i)), ccode(CD(i)))];
    endfor
    for i=1:length(X)
        printf("    dfd%s...\n", ccode(X(i)));
        for iF=1:length(F)
            s = [s sprintf("\t\ttmp = %s;\n", ccode(diff(F(iF),X(i))))];
            s = [s sprintf("\t\tif(!isnan(tmp)) dfd%s += tmp;\n", ccode(X(i)))];
        endfor
    endfor
    s = [s sprintf("\t}\n")];
    for i=1:length(X)
        s = [s sprintf("\tgsl_vector_set(DF, %d, dfd%s);\n", i-1, ccode(X(i)))];
    endfor
    s = [s sprintf("}\n")];
endfunction

function s=gsl_gen_fdf(name, F, X, CD)
    s = "";
    s = [s sprintf("static void %sfdf(const gsl_vector *X, void *param, double *F, gsl_vector *DF) {\n",name)];
    s = [s sprintf("\t*F = %sf(X, param);\n", name)];
    s = [s sprintf("\t%sdf(X, param, DF);\n", name)];
    s = [s sprintf("}\n")];
endfunction

function s=gsl_gen_datatype(name, F, X, CD)
    printf("  Data structures...\n");
    s = "";
	s = [s sprintf("struct %scaldata {\n", name)];
	for i=1:length(CD)
		s = [s sprintf("\tdouble %s;\n", ccode(CD(i)))];
	endfor
	s = [s sprintf("};\n")];

	s = [s sprintf("struct %sparameters {\n", name)];
	for i=1:length(X)
		s = [s sprintf("\tdouble %s;\n", ccode(X(i)))];
	endfor
	s = [s sprintf("};\n")];
endfunction

function s=gsl_gen_caldata_loader(name, F, X, CD)
    printf("  Calibration data loader...\n");
    s = "";
	s = [s sprintf("static double getDouble(ifstream &in) {\n")];
	s = [s sprintf("\tstring s;\n")];
	s = [s sprintf("\tin >> s;\n")];
	s = [s sprintf("\tif (!in || s == \"NaN\") return NAN;\n")];
	s = [s sprintf("\treturn atof(s.c_str());\n")];
	s = [s sprintf("}\n")];
	
	s = [s sprintf("vector<%scaldata> %scaldata_loadFromFile(const char *fname) {\n",name,name)];
	s = [s sprintf("\tvector<%scaldata> r;\n", name)];
	s = [s sprintf("\t%scaldata d;\n",name)];
	s = [s sprintf("\tifstream in(fname, ios::in);\n")];

	s = [s sprintf("\tif (!in) return r;\n")];
	
	s = [s sprintf("\twhile (true) {\n")];
	for i=1:length(CD)
		s = [s sprintf("\t\td.%s = getDouble(in);\n",ccode(CD(i)))];
	endfor
	s = [s sprintf("\t\tif (!in) break;\n")];
	s = [s sprintf("\t\tr.push_back(d);\n")];
	s = [s sprintf("\t}\n")];

	s = [s sprintf("\treturn r;\n")];
	s = [s sprintf("}\n")];
endfunction

function s = gsl_gen_optimize(name, F, X, CD)
	printf("  Optimization functions...\n");
	s = "";
	
	s = [s sprintf("bool interrupted;\n")];
	s = [s sprintf("void on_interrupt(int) {\n")];
	s = [s sprintf("\tinterrupted=true;\n")];
	s = [s sprintf("}\n")];
	
	s = [s sprintf("bool %soptimize(vector<%scaldata> calpointslist, %sparameters &P, bool verbose=false) {\n", name, name, name)];
	s = [s sprintf("\tgsl_multimin_function_fdf %sgmf;\n", name)];
	s = [s sprintf("\t%sgmf.f   = &%sf;\n",   name, name)];
	s = [s sprintf("\t%sgmf.df  = &%sdf;\n",  name, name)];
	s = [s sprintf("\t%sgmf.fdf = &%sfdf;\n", name, name)];
	s = [s sprintf("\t%sgmf.n   = %d;\n",     name, length(X))];

	s = [s sprintf("\tgsl_vector *%sX  = gsl_vector_calloc(%d);\n", name, length(X))];
	for i=1:length(X)
		s = [s sprintf("\tgsl_vector_set(%sX, %d, P.%s);\n", name, i-1, ccode(X(i)))];
	endfor

	s = [s sprintf("\tauto %smin = gsl_multimin_fdfminimizer_alloc(gsl_multimin_fdfminimizer_conjugate_pr, %d);\n", name, length(X))];
	s = [s sprintf("\tgsl_multimin_fdfminimizer_set(%smin, &%sgmf, %sX, 1, 1);\n", name, name, name)];
	
	s = [s sprintf("\tdouble err = +INFINITY;\n")];
	s = [s sprintf("\tdouble oerr;\n")];

	s = [s sprintf("\tinterrupted = false;\n")];
	s = [s sprintf("\tauto oldhander = signal(SIGINT, on_interrupt);\n")];

	s = [s sprintf("\tsize_t niter = 1000000;\n")];
	s = [s sprintf("\tdo {\n")];
	s = [s sprintf("\t\tgsl_multimin_fdfminimizer_iterate(%smin);\n", name)];

	s = [s sprintf("\t\toerr = err;\n")];
	s = [s sprintf("\t\terr = gsl_multimin_fdfminimizer_minimum(%smin);\n", name)];
	s = [s sprintf("\t\tif (verbose) cout << \"\\r\" << niter << \": err = \" << err << \"\\033[K\"<< flush;\n")];
	s = [s sprintf("\t} while ((fabs(err - oerr) > 1e-12) && --niter && !interrupted);\n")];
	s = [s sprintf("\tif (verbose) cout << endl;\n")];

	s = [s sprintf("\tgsl_vector *X = gsl_multimin_fdfminimizer_x(%smin);\n", name)];
	
	for i=1:length(X)
		s = [s sprintf("\tP.%s = gsl_vector_get(X, %d);\n", ccode(X(i)), i-1)];
	endfor
	
	s = [s sprintf("\tgsl_multimin_fdfminimizer_free(%smin);\n", name)];
	s = [s sprintf("\treturn niter;\n")];
	s = [s sprintf("}\n")];

	# Second version, from file
	s = [s sprintf("bool %soptimize(const char *calfilename, %sparameters &P, bool verbose=false) {\n", name, name)];
	s = [s sprintf("\treturn %soptimize(%scaldata_loadFromFile(calfilename),P,verbose);\n", name, name)];
	s = [s sprintf("}\n")];
endfunction

function s = gsl_gen_main(name, F, X, CD)
    printf("  main()...\n");
    s = "";
	s = [s sprintf("int main(int argc, char *argv[]) {\n")];
	s = [s sprintf("\tif (argc!=2 && argc!=2+%d) {\n", length(X))];
	s = [s sprintf("\t\tcout << \"Use: \" << argv[0] << \" <caldatafile>\" << endl;\n")];
	s = [s sprintf("\t\tcout << \"Use: \" << argv[0] << \" <caldatafile>")];
	for i=1:length(X)
		s = [s sprintf(" %s", ccode(X(i)))];
	endfor
	s = [s sprintf("\" << endl;\n")];
	s = [s sprintf("\t\treturn 0;\n")];
	s = [s sprintf("\t}\n")];
	s = [s sprintf("\t%sparameters P;\n", name)];
	
	s = [s sprintf("\tif (argc==2+%d) {\n", length(X))];
	for i=1:length(X)
		s = [s sprintf("\t\tP.%s = atof(argv[%d]);\n", ccode(X(i)), i+1)];
	endfor
	s = [s sprintf("\t} else {\n")];
	for i=1:length(X)
		s = [s sprintf("\t\tP.%s = %f;\n", ccode(X(i)), i)];
	endfor
	s = [s sprintf("\t}\n")];
	
	s = [s sprintf("\tcout << \"Loading from \" << argv[1] << \"... \" << flush;\n")];
	s = [s sprintf("\tauto calpointslist = %scaldata_loadFromFile(argv[1]);\n",name)];
	s = [s sprintf("\tcout << calpointslist.size() << \" points.\" << endl;\n")];
	s = [s sprintf("\t%soptimize(calpointslist, P, true);\n",name)];
	for i=1:length(X)
		s = [s sprintf("\tcout << \"%s = \" << P.%s << endl;\n", ccode(X(i)), ccode(X(i)))];
	endfor
	s = [s sprintf("\treturn 0;\n")];
	s = [s sprintf("}\n")];
endfunction
