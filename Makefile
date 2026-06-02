-include .env

ENV ?= virtual-cml-testbed
SCENARIO ?= link-shutdown-r1r2

.PHONY: help quality test baseline learn-pre-change learn-post-shutdown \
	reconcile-post-shutdown clean-parameters \
	pre-change shutdown post-shutdown normalize post-normalize \
	tf-init tf-plan tf-apply

help:
	@echo ""
	@echo "  ENV=$(ENV)  SCENARIO=$(SCENARIO)"
	@echo ""
	@echo "  End-to-End"
	@echo "    make baseline          Learn expected state (all phases)"
	@echo "    make test              Run the full test plan"
	@echo ""
	@echo "  Phase-by-Phase"
	@echo "    make learn-pre-change  Learn expected pre-change state"
	@echo "    make pre-change        Verify pre-change baseline"
	@echo "    make shutdown          Execute link shutdown action"
	@echo "    make post-shutdown     Verify post-shutdown state"
	@echo "    make normalize         Execute link restore action"
	@echo "    make post-normalize    Verify post-normalize state"
	@echo ""
	@echo "  Reconciliation"
	@echo "    make learn-post-shutdown      Learn post-shutdown state"
	@echo "    make reconcile-post-shutdown  Reconcile parameters to post-shutdown"
	@echo "    make clean-parameters         Delete learned parameters"
	@echo ""
	@echo "  Infrastructure as Code"
	@echo "    make tf-init           Initialize Terraform"
	@echo "    make tf-plan           Preview configuration changes"
	@echo "    make tf-apply          Apply configuration to devices"
	@echo ""
	@echo "  Code Quality"
	@echo "    make quality           Run ruff format, ruff check, ty check"
	@echo ""

quality:
	uv run ruff format
	uv run ruff check --fix
	uv run ty check

test:
	PYTHONPATH=. uv run huginn run -m testing \
		-t $(ENV)/testbed.yaml \
		-p $(ENV)/test_plan/ \
		--parameters-dir $(ENV)/parameters/

baseline:
	PYTHONPATH=. uv run huginn run -m learning \
		-t $(ENV)/testbed.yaml \
		-p $(ENV)/test_plan/ \
		--parameters-dir $(ENV)/parameters/

learn-pre-change:
	PYTHONPATH=. uv run huginn run -m learning \
		-t $(ENV)/testbed.yaml \
		-p $(ENV)/test_plan/ \
		--parameters-dir $(ENV)/parameters/ \
		--scenario $(SCENARIO) --phase pre-change

pre-change:
	PYTHONPATH=. uv run huginn run -m testing \
		-t $(ENV)/testbed.yaml \
		-p $(ENV)/test_plan/ \
		--parameters-dir $(ENV)/parameters/ \
		--scenario $(SCENARIO) --phase pre-change

shutdown:
	PYTHONPATH=. uv run huginn run -m testing \
		-t $(ENV)/testbed.yaml \
		-p $(ENV)/test_plan/ \
		--parameters-dir $(ENV)/parameters/ \
		--scenario $(SCENARIO) --phase shutdown

post-shutdown:
	PYTHONPATH=. uv run huginn run -m testing \
		-t $(ENV)/testbed.yaml \
		-p $(ENV)/test_plan/ \
		--parameters-dir $(ENV)/parameters/ \
		--scenario $(SCENARIO) --phase post-shutdown

normalize:
	PYTHONPATH=. uv run huginn run -m testing \
		-t $(ENV)/testbed.yaml \
		-p $(ENV)/test_plan/ \
		--parameters-dir $(ENV)/parameters/ \
		--scenario $(SCENARIO) --phase normalize

post-normalize:
	PYTHONPATH=. uv run huginn run -m testing \
		-t $(ENV)/testbed.yaml \
		-p $(ENV)/test_plan/ \
		--parameters-dir $(ENV)/parameters/ \
		--scenario $(SCENARIO) --phase post-normalize

clean-parameters:
	find $(ENV)/parameters/ -name '*.json' \
		! -name 'ACTION-*' ! -name 'GATE-*' -delete

learn-post-shutdown:
	PYTHONPATH=. uv run huginn run -m learning \
		-t $(ENV)/testbed.yaml \
		-p $(ENV)/test_plan/ \
		--parameters-dir $(ENV)/parameters/ \
		--scenario $(SCENARIO) --phase post-shutdown

reconcile-post-shutdown:
	PYTHONPATH=. uv run huginn reconcile \
		-p $(ENV)/test_plan/ \
		--parameters-dir $(ENV)/parameters/ \
		--phase post-shutdown

tf-init:
	./$(ENV)/xeac/run_tf.sh init

tf-plan:
	./$(ENV)/xeac/run_tf.sh plan

tf-apply:
	./$(ENV)/xeac/run_tf.sh apply
