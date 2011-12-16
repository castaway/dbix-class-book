html: $(addsuffix .html,$(basename $(wildcard chapters/*.md)))

%.html: %.md Makefile
	pandoc -f markdown -t html --standalone -5 $< -o $@ 


