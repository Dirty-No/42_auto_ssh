#!/bin/sh

# Generates and upload the public key

convert_utf8()
{
	echo "$1"	\
	|	sed 's/%/%25/g'		|	sed 's/\&/%26/g'	|	sed 's/!/%21/g'	\
	|	sed 's/"/%22/g'		|	sed 's/#/%23/g'		|	sed 's/\$/%24/g'	|	sed 's/(/%28/g'		\
	|	sed 's/)/%29/g'		|	sed 's/+/%2B/g'		|	sed 's/,/%2C/g'		|	sed 's/\//%2F/g'	\
	|	sed 's/:/%3A/g'		|	sed 's/;/%3B/g'		|	sed 's/</%3C/g'		|	sed 's/=/%3D/g'		\
	|	sed 's/>/%3E/g'		|	sed 's/?/%3F/g'		|	sed 's/@/%40/g'		|	sed 's/\[/%5B/g'	\
	|	sed 's/]/%5D/g'		|	sed 's/\^/%5E/g'	|	sed 's/`/%60/g'		|	sed 's/{/%7B/g'		\
	|	sed 's/|/%7C/g'		|	sed 's/}/%7D/g'		|	tr ' ' '+'
}

parse_token()
{
	TOKEN=$(echo "$1" |  grep csrf-token | sed 's/<meta name="csrf-token" content="//g' | sed 's/" \/>//g')
	convert_utf8 "$TOKEN"
}

create_key()
{
	printf "\ny\n" | ssh-keygen -t rsa -N '' > /dev/null
	convert_utf8 "$(cat ~/.ssh/id_rsa.pub)"
}

check_session()
{
		#arg 1 is cookie file
		CHECK="$(curl -s -b "$1" https://profile.intra.42.fr/)"
		CHECK=$(echo "$CHECK" | grep "Intra Profile Home")
		if [ -z  "$CHECK" ];
			then echo "false"
			else echo "true"
		fi
}

do_sign_in()
{
		DIR=$(dirname "$0")
		COOKIE_JAR="$DIR/$1"

		printf "Login: "
		read LOGIN

		stty -echo
		printf "Password: "
		read PASSWORD
		stty echo
		printf "\n"

		TOKEN=$(curl -j -s -c $COOKIE_JAR 'https://signin.intra.42.fr/users/sign_in' --compressed)
		TOKEN=$(parse_token "$TOKEN")


		PASSWORD=$(convert_utf8 "$PASSWORD")

		curl -s -c $COOKIE_JAR -b $COOKIE_JAR 'https://signin.intra.42.fr/users/sign_in' \
		--data-raw "utf8=%E2%9C%93&authenticity_token=$TOKEN&user%5Blogin%5D=$LOGIN&user%5Bpassword%5D=$PASSWORD&commit=Sign+in" \
		--compressed > /dev/null

		check_session $COOKIE_JAR
}

COOKIE_JAR="cookies.txt"

if [ "$(check_session cookies.txt)" = "false" ]
then
	echo "You are not logged in"
	do_sign_in "$COOKIE_JAR"
fi


TOKEN_PAGE=$(curl -s -b $COOKIE_JAR -c $COOKIE_JAR "https://profile.intra.42.fr/gitlab_users/new" \
	--compressed)

_USER_ID_=$(echo "$TOKEN_PAGE" | grep -A2 "this._user" | grep -o .[0-9] | tr -d '\n' | tr -d ' ')

_TOKEN_=$(parse_token "$TOKEN_PAGE")

#echo ""
#echo TOKEN "$_TOKEN_"
#echo USER_ID "$_USER_ID_"
#echo SSH_KEY "$_SSH_KEY_"
#echo ""

_SSH_KEY_=$(create_key)

BODY="utf8=%E2%9C%93&authenticity_token=$_TOKEN_&gitlab_user%5Bpublic_key%5D=$_SSH_KEY_&gitlab_user%5Buser_id%5D=$_USER_ID_"

#echo ""
#echo BODY "$BODY"
#echo ""

curl -s -b $COOKIE_JAR -c $COOKIE_JAR 'https://profile.intra.42.fr/gitlab_users' \
	--data-raw "$BODY" \
	--compressed > /dev/null

echo Done.
