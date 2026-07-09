cat 50-60.sh | parallel -j 10 --joblog=50-60.log --results=50-60_results/{1} --eta --progress --line-buffer --keep-order 2>&1 | tee 50-60_master.log 
