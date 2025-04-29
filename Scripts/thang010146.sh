#!/bin/bash

cd /volume1/Downloads/YouTube/thang010146/ && \
	/var/services/homes/Hannibal/bin/yt-dlp \
		--download-archive /volume1/Downloads/YouTube/thang010146.txt \
		--restrict-filenames --compat-options filename,filename-sanitization \
		-i https://www.youtube.com/channel/UCli_RJkGWfZvw4IlDLHNCQg/videos \
		-f b --add-metadata --embed-subs --all-subs -q &&
	chmod 644 ./*.mp4
