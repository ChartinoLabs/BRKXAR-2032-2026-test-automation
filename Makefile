.PHONY: quality test baseline tf-init tf-plan tf-apply

quality:
	uv run ruff format
	uv run ruff check --fix
	uv run ty check

test:
	PYTHONPATH=. uv run huginn run -m testing -t testbed.yaml -p test_plan/

baseline:
	PYTHONPATH=. uv run huginn run -m learning -t testbed.yaml -p test_plan/

tf-init:
	./xeac/run_tf.sh init

tf-plan:
	./xeac/run_tf.sh plan

tf-apply:
	./xeac/run_tf.sh apply
