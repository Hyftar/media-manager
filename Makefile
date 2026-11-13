PHONY: local-deploy remote-deploy dry hardware-config

local-deploy:
	nixos-rebuild switch \
		--no-reexec \
		--flake .#cia \
		--build-host cia-local \
		--target-host cia-local \
		--sudo \
		--ask-sudo-password

remote-deploy:
	nixos-rebuild switch \
		--no-reexec \
		--flake .#cia \
		--build-host cia-remote \
		--target-host cia-remote \
		--sudo \
		--ask-sudo-password

dry:
	nixos-rebuild dry-activate \
		--no-reexec \
		--flake .#cia \
		--build-host cia-local \
		--target-host cia-local \
		--sudo \
		--ask-sudo-password

# Fetch the hardware configuration generated on the server by nixos-generate-config.
hardware-config:
	ssh cia-local cat /etc/nixos/hardware-configuration.nix > hardware-configuration.nix
