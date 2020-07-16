#
#  Makefile
#
#  Execute 'make help' for a list of build targets.
#

target = template
paper_size ?= a4
pdf_quality ?= printer

all: pdf

##  Rules to generate other output
fig/%.eps: fig/%.fig
	@echo "[35m$< --> $@[0m"
	@fig2dev -L eps -p dummy $< $@

fig/%.eps: fig/%.gif
	@echo  "[35m$< --> $@[0m"
	@giftopnm $< | pnmtops -noturn -rle > $@

fig/%.eps: fig/%.prn
	@echo  "[35m$< --> $@[0m"
	@ps2eps -f $<

fig/%.eps: fig/%.ps
	@echo $(EPS)
	@echo  "[35m$< --> $@[0m"
	@ps2eps -f $<

fig/%.pdf: fig/%.eps
	@echo  "[35m$< --> $@[0m"
	epstopdf $< > $@

clean::
	rm -f $(eps_targets) $(pdf_targets) *.eps git.tex


###########################################################################
eps_targets = $(shell grep '\\epsfig\|\\includegraphics' *.tex | grep -v "\%"  | \
                    sed -e 's/file=//' | sed -e 's/,scale=.*}/}/' | \
                    sed -e 's/.*{\([^{]*\)}.*/\1.eps/;' )
$(target).dvi:: $(target).tex $(target).bib $(eps_targets)

pdf_targets = $(shell grep '\\epsfig\|\\includegraphics' *.tex | grep -v "\%"  | \
                    sed -e 's/file=//' | sed -e 's/,scale=.*}/}/' | \
                    sed -e 's/.*{\([^{]*\)}.*/\1.pdf/;' )
$(target).pdf:: $(target).tex $(target).bib $(pdf_targets)

pdf_target = $(addsuffix .pdf, $(target))
ps_target = $(addsuffix .ps, $(target))
dvi_target = $(addsuffix .dvi, $(target))

pdf: $(pdf_target)
ps: $(ps_target)
dvi: $(dvi_target)

help:
	@echo
	@echo "Automatic build target:"
	@echo "    $(pdf_target)"
	@echo "Other build target:"
	@echo "    $(ps_target)"
	@echo

clean = $(target) $(optional)
tex_deps =

##############################################################################
ifeq ($(wildcard .git),.git)
git_state = $(wildcard .git/index)
tex_deps += git.tex

git.tex: Makefile $(git_state)
	@-commit=`git log -1 --format="%h"` && echo '\renewcommand{\Revision}'"{Revision: $${commit}}" > $@
	@-commitdate=`git log -1 --format="%cd"` && echo '\renewcommand{\RevisionDate}'"{$${commitdate}}" >> $@

endif


##############################################################################

latex = latex -interaction=batchmode $(1)
pdflatex = pdflatex $(1)
bibtex = bibtex $(1)

gs_screen = -dPDFSETTINGS=/screen
gs_printer = -dPDFSETTINGS=/printer
gs_ebook = -dPDFSETTINGS=/ebook
gs_prepress = -dPDFSETTINGS=/prepress

gs2pdf_options = -dCompatibilityLevel=1.4 $(gs_$(pdf_quality))
gs2pdf = gs -q -dSAFER -dNOPAUSE -dBATCH -sOutputFile=$(1) $(gs2pdf_options) -sDEVICE=pdfwrite -c .setpdfwrite -f $(2)

dvipdfm = dvipdfm -p $(paper_size) -o $(1) $(2)
dvips   = dvips -Pdownload35 -Pcmz -Pcmz -Pamz -t $(paper_size)  -G0 -o $(1) $(2)


RERUN = '(There were undefined references|Rerun to get (cross-references|the bars) right)'
RERUNBIB = 'No file.*\.bbl|Citation.*undefined'
UNDEFINED = '((Reference|Citation).*undefined)|(Label.*multiply defined)'
DVIPDFM_SPECIAL = 'pdf:.*docinfo'


%.pdf: %.tex $(pdf_targets) $(tex_deps)
	@echo "====> LaTeX first pass"
	$(call pdflatex,$<) || cat $*.log 
	@if egrep -q $(RERUNBIB) $*.log ; then echo "====> BibTex" && $(call bibtex,$*) && echo "====> LaTeX BibTeX pass" && $(call pdflatex, $<) ; fi
	@if egrep -q $(RERUN) $*.log ; then echo "====> LaTeX rerun" && $(call pdflatex,$<); fi; 
	@if egrep -q $(RERUN) $*.log ; then echo "====> LaTeX rerun" && $(call pdflatex,$<); fi;
	@echo "====> Undefined references and citations:"
	@egrep -i $(UNDEFINED) $*.log || echo "None."
	@echo "====> Dimensions:"
	@grep "dimension:" $*.log || echo "None."


##  Automatically choose the method to convert a DVI into a PDF, favoring
##  dvips since dvipdfm is fragile.
#%.pdf: %.dvi
#	@if egrep -q $(DVIPDFM_SPECIAL) $< ; \
#	 then echo "====> Using dvipdfm" && $(call dvipdfm,$@,$<) ; \
#	 else echo "====> Using dvips" && $(call dvips,$(<:.dvi=.ps),$<) && $(call gs2pdf,$@,$(<:.dvi=.ps)) ; \
#	 fi

##  Build a PDF from PS.  To enable, put this rule before other PDF rules.
#%.pdf: %.ps
#	@echo "====> Converting Postscript to PDF"
#	$(call gs2pdf,$@,$<)

##  Build a Postscript file from the DVI.
%.ps: %.dvi
	@echo "====> Generating Postscript"
	$(call dvips,$@,$<)

%.dvi: %.tex $(tex_deps)
	@echo "====> LaTeX first pass"
	$(call latex,$<) || cat $*.log 
	@if egrep -q $(RERUNBIB) $*.log ; then echo "====> BibTex" && $(call bibtex,$*) && echo "====> LaTeX BibTeX pass" && $(call latex, $<) ; fi
	@if egrep -q $(RERUN) $*.log ; then echo "====> LaTeX rerun" && $(call latex,$<); fi; 
	@if egrep -q $(RERUN) $*.log ; then echo "====> LaTeX rerun" && $(call latex,$<); fi
	@echo "====> Undefined references and citations:"
	@egrep -i $(UNDEFINED) $*.log || echo "None."
	@echo "====> Dimensions:"
	@grep "dimension:" $*.log || echo "None."


clean::
	rm -rf $(addsuffix .pdf, $(clean)) $(addsuffix .ps, $(clean))
	rm -rf $(addsuffix .dvi, $(clean)) $(addsuffix .toc, $(clean))
	rm -rf $(addsuffix .log, $(clean)) $(addsuffix .aux, $(clean))
	rm -rf $(addsuffix .bbl, $(clean)) $(addsuffix .blg, $(clean))
	rm -rf $(addsuffix .out, $(clean))
	rm -rf git.tex
	rm -rf $(tmp_subdirs)
