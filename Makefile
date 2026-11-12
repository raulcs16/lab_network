BASHTON := ssh console-server

ex-config:
	$(BASHTON) "ansible-config init --disabled > example.cfg"
cat-config:
	$(BASHTON) "cat example.cfg"

.PHONY: ex-config cat-config
