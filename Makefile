%.html: %.md Makefile
	pandoc -f markdown -t html --standalone -5 $< -o $@ 


