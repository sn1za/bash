while read p; do
      #check if qa domain unavailable then not send to prometheus
      if [[ $p == *"fxexpertsnetwork"* ]]; then
          echo "$p - qa domain!"
         status=$(curl -o /dev/null -s -w "%{http_code}\n" https://$p)
         echo "$status"
       if [ "$status" -eq "404" ]; then
            echo "site unavailable";
            continue;
       fi
      fi
   if [ ! -f /var/lib/jenkins/scripts/logs/$p.txt ]; then
     echo 'robots:' > /var/lib/jenkins/scripts/logs/$p.txt
     curl -Ss https://$p/robots.txt >> /var/lib/jenkins/scripts/logs/$p.txt
     echo -en '\n====================\n\n tag:'
     curl https://$p/ -L | grep "<meta name='robots' content=" | awk -F "meta name=\'robots\'" '{print $2}' | awk -F "/>" '{print $1}' >> /var/lib/jenkins/scripts/logs/$p.txt

   else
    echo 'robots:' > /var/lib/jenkins/scripts/logs/$p.now.txt
    curl -Ss https://$p/robots.txt >> /var/lib/jenkins/scripts/logs/$p.now.txt
    echo -en '\n====================\n\n tag:' >> /var/lib/jenkins/scripts/logs/$p.now.txt
    curl -sSL https://$p/ | grep "<meta name='robots' content=" | awk -F "meta name=\'robots\'" '{print $2}' | awk -F "/>" '{print $1}' >> /var/lib/jenkins/scripts/logs/$p.now.txt
    DIFF=$(diff /var/lib/jenkins/scripts/logs/$p.txt /var/lib/jenkins/scripts/logs/$p.now.txt)
    if [ "$DIFF" != "" ]
     then
       echo "The file was modified"
       echo "check_robots 1" | curl --data-binary @- https://prometheus-pushgateway.xcritical.com/metrics/job/Pushgateway/site/$p
       curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X POST --data "{\"content\": null,\"embeds\": [{\"description\": \"The robots.txt file on $p has been changed \`\`\`$(cat /var/lib/jenkins/scripts/logs/$p.now.txt | sed ':a;N;$!ba;s/\n/\\n/g') \`\`\` \",\"color\": 14626049}]}" 'https://discord.com/api/webhooks/1090978803234381844/h75_zodzeSht0zOxg6ksScyrMlVs_w8LZWLuJ_HRs56PAVWokwVxGWxXANWsAG7r5aEH'
     else
       echo "The file not modified"
       echo "check_robots 0" | curl --data-binary @- https://prometheus-pushgateway.xcritical.com/metrics/job/Pushgateway/site/$p
    fi
    mv /var/lib/jenkins/scripts/logs/$p.now.txt /var/lib/jenkins/scripts/logs/$p.txt
   fi
done </var/lib/jenkins/scripts/domains.txt
