# Build the report:  make        (needs pdflatex + bibtex, e.g. TeX Live / MiKTeX)
main.pdf: main.tex references.bib figures/*.png
	latexmk -pdf -interaction=nonstopmode main.tex
clean:
	latexmk -C
