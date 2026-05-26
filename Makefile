PHONY: local-deploy remote-deploy dry

local-deploy:
	nixos-rebuild switch \
		--no-reexec \
		--flake .#closet-intelligence-agency \
		--build-host cia-local \
		--target-host cia-local \
		--sudo \
		--ask-sudo-password

remote-deploy:
	nixos-rebuild switch \
		--no-reexec \
		--flake .#closet-intelligence-agency \
		--build-host cia-remote \
		--target-host cia-remote \
		--sudo \
		--ask-sudo-password

dry:
	nixos-rebuild dry-activate \
		--no-reexec \
		--flake .#closet-intelligence-agency \
		--build-host cia-local \
		--target-host cia-local \
		--sudo \
		--ask-sudo-password
