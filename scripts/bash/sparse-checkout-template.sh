#!/bin/bash

#The steps to do a sparse clone are as follows:
mkdir <repo>
cd <repo>
git init
git remote add -f origin <url>

#This creates an empty repository with your remote, and fetches all objects but doesn't check them out. Then do:
git config core.sparseCheckout true


#Now you need to define which files/folders you want to actually check out. This is done by listing them in .git/info/sparse-checkout, eg:
echo "some/dir/" >> .git/info/sparse-checkout
echo "another/sub/tree" >> .git/info/sparse-checkout

#Last but not least, update your empty repo with the state from the remote:
git pull origin main