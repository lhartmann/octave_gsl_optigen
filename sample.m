#! /usr/bin/octave --silent

# Load symbolic package (Fedora: dnf install octave-symbolic)
pkg load symbolic

# Define all symbols, both for variables and parameters
syms a b c t h

# Define vector containing all unknown parameters.
# These will be calculated by the optimization.
P = [a,b,c]

# Define vector with the measured variables, both inputs and outputs of
# the original function. The order in which they appear here IS important,
# it must match the order in which values appear on data files later.
M = [t,h]

# Error function, lower is better. If F is a vector then each element is
# evaluated independently, and added to the final error only if not NaN.
Err = [
	(a*t^2 + b*t + c - h)^2 
]

code = gsl_gen("my_", Err, P, M);

fid = fopen("sample.cpp", "w");
fwrite(fid, code);


