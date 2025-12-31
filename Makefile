.PHONY: test

test:
	$(MAKE) -C tests/gf2_rref
	$(MAKE) -C tests/enumerate_solutions
