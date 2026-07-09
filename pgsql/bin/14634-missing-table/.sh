cat 50-60.sh | parallel -j 10 --joblog=50-60.log --results= --eta --progress --line-buffer --keep-order 2>&1 | tee .log 
