#!/bin/bash
#parameters from jenkins: URL  KEYWORD ACTION (CREATE|DELETE)
for URL in $URLS
do
	#checks and corrections
	if [ $(echo "$URL" | tail -c 2) == '/' ]; then
		URL="${URL::-1}"
		echo 'True'
	fi

	if [ -z "$URL" ]; then
		echo "url is empty, aborting"; exit 0   ##add if end with /, remove /
	elif [[ $URL == *"http"* ]]; then 
		echo "URL"
	else URL="https://$URL"
		echo "$URL"
	fi

	# #get last page of monitors:
	Last=$(curl -sL --request GET \
		--url https://betteruptime.com/api/v2/monitors?page=1 \
		--header "Authorization: Bearer $TOKEN" | \
		jq .pagination.last | tail -c 4 | head -c 2)

	#get list of monitors
	for arg1 in $(seq 1 "$Last")
	do
	   LIST=$(curl -sL --request GET \
	   --url https://betteruptime.com/api/v2/monitors?page="$arg1" \
	   --header "Authorization: Bearer $TOKEN" | jq . )

	   FullList+="
	$LIST"
	done


	if [ "$ACTION" = CREATE ]; then
	###################################################
	############start block of create##################
	###################################################
	#create monitors in betteruptime
	if [ $CreateKeywordsMonitors == "true" ]; then
		if [ -z "$KEYWORD" ]; then
			KEYWORD=$(curl -sL "$URL" | grep '<h1' | awk -F '<h1' '{print $2}' | head -n1 | cut -d'>' -f 2 | awk -F '</h1' '{print $1}' | cut -d' ' -f-5)
		fi
		if [ -z "$KEYWORD" ]; then
			KEYWORD=$(curl -sL "$URL" | grep '<h2' | awk -F '<h2' '{print $2}' | head -n1 | cut -d'>' -f 2 | awk -F '</h2' '{print $1}' | cut -d' ' -f-5)
		fi
		if [ -z "$KEYWORD" ]; then
			KEYWORD=$(curl -sL "$URL" | grep '<p>' |head -n1 | awk -F '<p>' '{print $2}' | cut -d'<' -f1 | cut -d' ' -f-5)
		fi
		echo "keyword is /// $KEYWORD ///"
	fi

		if [[ $FullList == *"$URL"* ]]; then
			echo "The Url $URL is monitored, aborting adding to betteruptime"
		else

			P_NAME=$(echo "$URL" | cut -d'/' -f 3)

			curl -sL --request POST \
			  --url https://betteruptime.com/api/v2/monitors \
			  --header "Authorization: Bearer $TOKEN" \
			  --header 'Content-Type: application/json' \
			  --data '{
			    "monitor_type": "status",
			    "url": "'"$URL"'",
			    "pronounceable_name": "'"$P_NAME"'",
			    "email": false,
			    "sms": false,
			    "call": false,
			    "push": false,
			    "recovery_period": 180,
			    "check_frequency": 30,
			    "domain_expiration": 7,
			    "ssl_expiration": 7,
			    "request_timeout": 30,
			    "follow_redirects": true,
			    "remember_cookies": true,
			        "regions": [
			          "us",
			          "eu",
			          "as",
			          "au"
			        ]
			}' | jq .

			if [ -n "$KEYWORD" ] && [ $CreateKeywordsMonitors == "true" ] ; then
			curl -sL --request POST \
			  --url https://betteruptime.com/api/v2/monitors \
			  --header "Authorization: Bearer $TOKEN" \
			  --header 'Content-Type: application/json' \
			  --data '{
			    "monitor_type": "keyword",
			    "url": "'"$URL"'",
			    "pronounceable_name": "'"$P_NAME"-keyword'",
			    "required_keyword": "'"$KEYWORD"'",
			    "email": false,
			    "sms": false,
			    "call": false,
			    "push": false,
			    "recovery_period": 180,
			    "check_frequency": 1800,
			    "domain_expiration": null,
			    "verify_ssl": false,
			    "request_timeout": 30,
			    "follow_redirects": true,
			    "remember_cookies": true,
			            "regions": [
			          "us",
			          "eu",
			          "as",
			          "au"
			        ]
			}' | jq .
		    fi
		fi

		#create domain in domainmod
		NEW_DOMAIN_ID=$(curl https://domainmod.devshell.site/ops/api/read.php | jq ".data[] | select(.domain==\"$P_NAME\") | .id")
		if [ -z "$NEW_DOMAIN_ID" ]; then

			case "$CAT_ID" in
			    null)
			        CATEG_ID=1        ;;
			    forex)
			        CATEG_ID=2        ;;
			    seo)
			        CATEG_ID=3        ;;
			    landings)
			        CATEG_ID=4        ;;
			    satellites)
			        CATEG_ID=5        ;;
			    other)
			        CATEG_ID=16       ;;
			esac

			EXPAIR=$(whois "${P_NAME}" | grep -iE 'exp|paid|free' | grep 202 | head -n1 | cut -d':' -f2 | sed 's/^[[:space:]]*//g' | cut -d' ' -f1 | cut -d'T' -f1 | sed 's/^[[:space:]]*//g' )
			if [ -z "$EXPAIR" ]; then
				EXPAIR=$(curl -sL -H "X-Api-Key:BnlgKzRByCSl6fpfTj4Q4g==m4gEqZnZPCsi0Do9" https://api.api-ninjas.com/v1/whois?domain="${P_NAME}" | jq '.expiration_date - 10800' 2>/dev/null | xargs -I{} date -d @{} "+%Y-%m-%d")
			fi
			if [ -z "$EXPAIR" ]; then
				echo "WRONG EXPAIR DATE!!!"
				EXPAIR='2020-01-01'
			fi
			
			REGISTAR=$(whois eaxy.com | grep egistrar | head -n1 | awk -F'.' '{print $(NF-1)}')
			 if [[ $REGISTAR == *"godaddy"* ]]; then
			 	registrar_id=8
			 	account_id=10
			 elif [[ $REGISTAR == *"Active"* ]]; then
			 	registrar_id=21
			 	account_id=27
			 else 
			 	registrar_id=1
			 	account_id=1
			 fi


			echo "domain name is $P_NAME"
			echo "expiration  is $EXPAIR"
			echo "category id is $CAT_ID $CATEG_ID"
			echo "registrar is $REGISTART registrar_id is $registrar_id account_id is $account_id"

			#cat_id = category (1-null, 2 - forex, 3 - seo, 4 - landings, 5 - satellites, 16 - other)
			#fee_id = provider id (1 - namecheap.com; 8 - godaddy  )

		    curl -L --request POST \
		    --url https://domainmod.devshell.site/ops/api/create.php \
		    --header 'Content-Type:application/json' \
		    --data '{
		    	"domain": "'"$P_NAME"'",
		    	"registrar_id": "'"$registrar_id"'",
		    	"account_id": "'"$account_id"'",
		    	"active": 1,
		    	"cat_id": "'"$CATEG_ID"'",
		    	"tld": "site",
		    	"fee_id": 9,
		    	"total_cost": 0,
		    	"notes": "",
		    	"expiry_date": "'"$EXPAIR"'"
		    }'

		    NEW_DOMAIN_ID=$(curl https://domainmod.devshell.site/ops/api/read.php | jq ".data[] | select(.domain==\"$P_NAME\") | .id")

			echo https://domainmod.devshell.site/domains/edit.php?did="$NEW_DOMAIN_ID"
			if [[ $EXPAIR == '2020-01-01' ]]; then
				echo "WRONG EXPAIR DATE!!! Check manualy:"
				echo https://domainmod.devshell.site/domains/edit.php?did="$NEW_DOMAIN_ID"
			fi
		else 

			echo "domain $P_NAME was in domainmod, dont added"
			echo https://domainmod.devshell.site/domains/edit.php?did="$NEW_DOMAIN_ID"
		fi


	elif [ "$ACTION" = DELETE ]; then
	###################################################
	############start block for delete#################
	###################################################
		if [[ $FullList == *"$URL"* ]]; then
			echo "The Url is monitored"
		else	echo "The Url is NOT monitored"; exit 1
		fi

		id_to_delete=$(echo "$FullList" | jq ".data[] | select(.attributes.url==\"$URL\") | .id")

		for arg2 in ${id_to_delete[@]}
		do
			arg2="${arg2:1:-1}"
			echo "delete monitor number $arg2"
			curl -sL --request DELETE \
			  --url https://betteruptime.com/api/v2/monitors/"$arg2" \
			  --header "Authorization: Bearer $TOKEN"
		done
	else echo 'Wrong action, aborting'
	fi
done
