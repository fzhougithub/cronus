#!/usr/bin/expect
spawn sudo -u postgres /usr/bin/psql -t -c 'show timezone();'
expect "password for"
send "Todayisagoodday25$\r"
expect eof
