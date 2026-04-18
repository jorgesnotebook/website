build:
	hugo --minify --gc --cleanDestinationDir

serve:
	hugo serve --disableFastRender

.PHONY: build serve
