#!/usr/bin/env bash
# /bin/bash

hugo 
if [ $? != '0' ]; then
	echo $?
	exit
fi

git status

echo "If Continue, Please input[N/Y]"
read next
if [[ $next != "Y" ]]; then
	echo 'Progress stop! you must input Y if you want to continue'
	exit
fi

git add *
git status

echo "Please input comment to this modify"
read comment
if [ -z $comment ]; then
	echo "the comment must be not empty"
	exit
fi
git commit -m "$comment"

git config credential.helper store
git push
echo "success submit source files"

cd public
git add *
git commit -m "$comment"
git config credential.helper store
git push
echo "success submit blog files"


