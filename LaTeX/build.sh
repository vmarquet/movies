#!/bin/bash

if [[ ! -d tmp ]]; then
	mkdir tmp
fi

pdflatex -output-directory=tmp main.tex
mv tmp/main.pdf ./

exit 0
