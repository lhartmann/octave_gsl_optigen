all: run

run: sample sample.data
	./sample sample.data

sample: sample.cpp
	g++ -lgsl -lgslcblas -o $@ $<

sample.cpp: sample.m gsl_gen.m
	./sample.m

clean:
	rm -f sample sample.cpp
