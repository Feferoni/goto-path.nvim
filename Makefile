.PHONY: test

test:
	nvim --headless --noplugin -u test/minimal_init.lua -c "PlenaryBustedDirectory test/ { minimal_init = 'test/minimal_init.lua' }"
