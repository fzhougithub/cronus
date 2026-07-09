cat 40-50.sh | parallel -j 10 --joblog=40-50.log --results=40-50_results --eta --progress --line-buffer --keep-order 2>&1 | tee 40-50_master.log 
