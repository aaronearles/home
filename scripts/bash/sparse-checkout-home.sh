#!/bin/bash

#The steps to do a sparse clone are as follows:
mkdir ~/home
cd ~/home
git init
git remote add -f origin git@github.com:aaronearles/home.git #Requires appropriate ~/.ssh/id_rsa

#This creates an empty repository with your remote, and fetches all objects but doesn't check them out. Then do:
git config core.sparseCheckout true


#Now you need to define which files/folders you want to actually check out. This is done by listing them in .git/info/sparse-checkout, eg:
echo "iac/201_docker-dmz" >> .git/info/sparse-checkout
# echo "another/sub/tree" >> .git/info/sparse-checkout

#Last but not least, update your empty repo with the state from the remote:
git pull origin main