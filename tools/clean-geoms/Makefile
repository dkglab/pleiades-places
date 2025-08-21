PYTHON := ./venv/bin/python
PIP := ./venv/bin/python -m pip

.PHONY: all clean

all: clean-geoms

clean:
	rm -rf venv clean-geoms

$(PYTHON):
	python3 -m venv venv
	$(PIP) install --upgrade pip
	$(PIP) install rdflib geomet

clean-geoms: $(PYTHON)
	echo "./tools/clean-geoms/venv/bin/python ./tools/clean-geoms/clean-geoms.py \$$1" > $@
	chmod +x $@
