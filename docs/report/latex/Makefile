# Build the final IEEE report with pdflatex and BibTeX.
.PHONY: all clean

all: ../IEEE_Report_SIMD_VPU_Final.pdf

../IEEE_Report_SIMD_VPU_Final.pdf: main.pdf
	cp main.pdf $@

main.pdf: main.tex references.bib IEEEtran.cls IEEEtran.bst $(wildcard figures/*.png)
	pdflatex -halt-on-error -interaction=nonstopmode main.tex
	bibtex main
	pdflatex -halt-on-error -interaction=nonstopmode main.tex
	pdflatex -halt-on-error -interaction=nonstopmode main.tex

clean:
	rm -f main.aux main.bbl main.blg main.fdb_latexmk main.fls main.log main.out main.pdf main.toc
