run-local:
	hugo server -D

build:
	hugo -D --destination ./publishing_source
