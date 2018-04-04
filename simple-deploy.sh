# /bin/bash

hugo 
if [ $? != '0' ]; then
	echo $?
	exit
fi

git status 
echo "========================="
echo "If Continue, Please input[N/Y]"

read next
if [ $next != "Y" ]; then
	echo 'Progress stop!'
	exit
fi

git add *

git status
echo "========================="
echo "Please input comment to this modify"

read comment
if [ -z $comment ]; then
	comment='common commit'
fi
git commit -m "$comment"

git config credential.helper store
git push
echo "Finish Part 1"

cd public
git add *
git commit -m "$comment"
git config credential.helper store
git push
echo "Finish Part 2"


