-include .env

ENV ?= virtual-cml-testbed
SCENARIO ?= link-shutdown-r1r2

.PHONY: quality test baseline learn-pre-change learn-post-shutdown \
	reconcile-post-shutdown clean-parameters \
	pre-change shutdown post-shutdown normalize post-normalize \
	tf-init tf-plan tf-apply

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
