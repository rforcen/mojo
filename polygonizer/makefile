fast:
	@mojo -O3 polygonizer.mojo
	@f3d ply/Blob.ply 
dbg:
	@mojo build -g -debug-level=line-tables polygonizer.mojo
# 	@f3d polygonizer.ply

# python binding
PY_VER="python3"
PY_SUFFIX = $(shell $(PY_VER)-config --extension-suffix)

py: $(SOURCES)
	@mojo build -O3 polygonizer.mojo --emit shared-lib -o polygonizer$(PY_SUFFIX) $(MOJO_LINK)
	@python3 -c "import polygonizer as p; v,n,f=p.polygonize(1,30,0.05); print(v); print(n); print(f)"
	@python3 poly_ui.py
ui:
	@python3 poly_ui.py