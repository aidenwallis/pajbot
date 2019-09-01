#!/bin/sh
if test -f "/app/configs/$STREAMERNAME.ini"; then
    echo "Config file exists for the given streamer. Execute the bot"
    /usr/bin/supervisord -c /app/docker/supervisord.conf
else 
    echo "Config file does not exist for the given streamer. Running first time setup."
    cp /app/docker/config.ini.template /app/configs/$STREAMERNAME.ini.temp
    #Config generation and DB setup here#
    if [ $STREAMERNAME ]; then
        sed -i 's|<<STREAMER>>|'$(echo "$STREAMERNAME" | awk '{print tolower($0)}')'|g' /app/configs/$STREAMERNAME.ini.temp
        mysql --host=mariadb -uroot -ppenis123 -e "CREATE DATABASE IF NOT EXISTS pb_$STREAMERNAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    else
        echo "Streamer's name missing. Please provide the streamer username via the STREAMERNAME environment variable."
        exit 1
    fi

    if [ $ADMIN ]; then
        sed -i 's|<<ADMIN>>|'$ADMIN'|g' /app/configs/$STREAMERNAME.ini.temp
    else
        echo "Admin user missing. Please provide the admin username via the ADMIN environment variable."
        exit 1
    fi

    if [ $BOTNAME ]; then
        sed -i 's|<<BOTNAME>>|'$BOTNAME'|g' /app/configs/$STREAMERNAME.ini.temp
    else
        echo "Bot name missing. Please provide the bot username via the BOTNAME environment variable."
        exit 1
    fi

    if [ $DOMAIN ]; then
        sed -i 's|<<DOMAIN>>|'$DOMAIN'|g' /app/configs/$STREAMERNAME.ini.temp
    else
        echo "Domain missing. Please provide the domain name via the DOMAIN environment variable."
        exit 1
    fi

    if [ $CLID ] && [ $CLSEC ]; then
        sed -i 's|<<CLID>>|'$CLID'|g' /app/configs/$STREAMERNAME.ini.temp
        sed -i 's|<<CLSEC>>|'$CLSEC'|g' /app/configs/$STREAMERNAME.ini.temp
    else
        echo "Twitch app tokens missing. Please provide the CLID and CLSEC environment variables."
        exit 1
    fi

    if [ $TWKEY ] && [ $TWSECRET ] && [ $TWTOKEN ] && [ $TWTOKENSECRET ]; then
        sed -i 's|<<TWKEY>>|'$TWKEY'|g' /app/configs/$STREAMERNAME.ini.temp
        sed -i 's|<<TWSECRET>>|'$TWSECRET'|g' /app/configs/$STREAMERNAME.ini.temp
        sed -i 's|<<TWTOKEN>>|'$TWTOKEN'|g' /app/configs/$STREAMERNAME.ini.temp
        sed -i 's|<<TWTOKENSECRET>>|'$TWTOKENSECRET'|g' /app/configs/$STREAMERNAME.ini.temp
    else
        sed -i 's|<<TWKEY>>|abc|g' /app/configs/$STREAMERNAME.ini.temp
        sed -i 's|<<TWSECRET>>|abc|g' /app/configs/$STREAMERNAME.ini.temp
        sed -i 's|<<TWTOKEN>>|abc|g' /app/configs/$STREAMERNAME.ini.temp
        sed -i 's|<<TWTOKENSECRET>>|abc|g' /app/configs/$STREAMERNAME.ini.temp
        echo "Twitter tokens missing. Twitter support disabled."
    fi

    if [ $YTKEY ]; then
        sed -i 's|<<YTKEY>>|'$YTKEY'|g' /app/configs/$STREAMERNAME.ini.temp
    else
        sed -i 's|<<YTKEY>>|abc|g' /app/configs/$STREAMERNAME.ini.temp
        echo "YTKEY was not provided."
    fi

    if [ $HUB ]; then
        sed -i 's|<<HUB>>|'$HUB'|g' /app/configs/$STREAMERNAME.ini.temp
    else
        sed -i 's|<<HUB>>|''|g' /app/configs/$STREAMERNAME.ini.temp
        echo "HUB was not provided. Control hub disabled."
    fi

    if [ $REDISHOST ]; then
        sed -i 's|<<REDISHOST>>|'$REDISHOST'|g' /app/configs/$STREAMERNAME.ini.temp
    else
        sed -i 's|<<REDISHOST>>|redis|g' /app/configs/$STREAMERNAME.ini.temp
        echo "Redis host was not provided. Using defaults"
    fi

    mv /app/configs/$STREAMERNAME.ini.temp /app/configs/$STREAMERNAME.ini
    /usr/bin/supervisord -c /app/docker/supervisord.conf

fi
