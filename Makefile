-include .env

ENV ?= virtual-cml-testbed

.PHONY: quality test baseline reconcile-post-shutdown tf-init tf-plan tf-apply

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
